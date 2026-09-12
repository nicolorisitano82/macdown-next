//
//  MPRenderer.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPRenderer.h"
#import <limits.h>
#import <hoedown/html.h>
#import <hoedown/document.h>
#import <HBHandlebars/HBHandlebars.h>
#import "hoedown_html_patch.h"
#import "NSJSONSerialization+File.h"
#import "NSObject+HTMLTabularize.h"
#import "NSString+Lookup.h"
#import "MPAttributedSpans.h"
#import "MPUtilities.h"
#import "MPAsset.h"
#import "MPPreferences.h"

static NSString * const kMPPrismScriptDirectory = @"Prism/components";
static NSString * const kMPPrismThemeDirectory = @"Prism/themes";
static NSString * const kMPPrismPluginDirectory = @"Prism/plugins";
static size_t kMPRendererNestingLevel = SIZE_MAX;
static int kMPRendererTOCLevel = 6;  // h1 to h6.


NS_INLINE NSURL *MPExtensionURL(NSString *name, NSString *extension)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:name withExtension:extension
                           subdirectory:@"Extensions"];
    return url;
}

/** Whether a preview style takes care of the dark appearance on its own.
 *
 * Styles live in Application Support and are user-editable, so this is
 * answered by looking at the file rather than by keeping a list of names.
 * Results are cached per path: -stylesheets runs on every render, and the
 * answer only changes when the user edits the style, which takes effect on
 * the next launch anyway.
 */
NS_INLINE BOOL MPStyleHandlesDarkAppearance(NSString *path)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    if (!path)
        return NO;

    @synchronized(cache) {
        NSNumber *cached = cache[path];
        if (cached)
            return cached.boolValue;

        NSString *content = MPReadFileOfPath(path);
        BOOL handled = ([content rangeOfString:@"prefers-color-scheme"].location
                        != NSNotFound);
        cache[path] = @(handled);
        return handled;
    }
}

NS_INLINE NSURL *MPPrismPluginURL(NSString *name, NSString *extension)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *dirPath =
        [NSString stringWithFormat:@"%@/%@", kMPPrismPluginDirectory, name];

    NSString *filename = [NSString stringWithFormat:@"prism-%@.min", name];
    NSURL *url = [bundle URLForResource:filename withExtension:extension
                           subdirectory:dirPath];
    if (url)
        return url;

    filename = [NSString stringWithFormat:@"prism-%@", name];
    url = [bundle URLForResource:filename withExtension:extension
                    subdirectory:dirPath];
    return url;
}

NS_INLINE NSArray *MPPrismScriptURLsForLanguage(NSString *language)
{
    NSURL *baseUrl = nil;
    NSURL *extraUrl = nil;
    NSBundle *bundle = [NSBundle mainBundle];

    language = [language lowercaseString];
    NSString *baseFileName =
        [NSString stringWithFormat:@"prism-%@", language];
    NSString *extraFileName =
        [NSString stringWithFormat:@"prism-%@-extras", language];

    for (NSString *ext in @[@"min.js", @"js"])
    {
        if (!baseUrl)
        {
            baseUrl = [bundle URLForResource:baseFileName withExtension:ext
                                subdirectory:kMPPrismScriptDirectory];
        }
        if (!extraUrl)
        {
            extraUrl = [bundle URLForResource:extraFileName withExtension:ext
                                 subdirectory:kMPPrismScriptDirectory];
        }
    }

    NSMutableArray *urls = [NSMutableArray array];
    if (baseUrl)
        [urls addObject:baseUrl];
    if (extraUrl)
        [urls addObject:extraUrl];
    return urls;
}

NS_INLINE NSString *MPHTMLFromMarkdown(
    NSString *text, int flags, BOOL smartypants, NSString *frontMatter,
    hoedown_renderer *htmlRenderer, hoedown_renderer *tocRenderer)
{
    // `[testo]{style="color:#c00"}` becomes a span before hoedown sees it:
    // hoedown has never heard of attributes, and what it is handed instead
    // is inline HTML, which it has always passed through. Both passes get
    // the same text, so the table of contents says what the page says.
    text = MPMarkdownWithAttributedSpans(text);
    NSData *inputData = [text dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_document *document = hoedown_document_new(
        htmlRenderer, flags, kMPRendererNestingLevel);
    hoedown_buffer *ob = hoedown_buffer_new(64);
    hoedown_document_render(document, ob, inputData.bytes, inputData.length);
    if (smartypants)
    {
        hoedown_buffer *ib = ob;
        ob = hoedown_buffer_new(64);
        hoedown_html_smartypants(ob, ib->data, ib->size);
        hoedown_buffer_free(ib);
    }
    NSString *result = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];
    hoedown_document_free(document);
    hoedown_buffer_free(ob);

    if (tocRenderer)
    {
        document = hoedown_document_new(
            tocRenderer, flags, kMPRendererNestingLevel);
        ob = hoedown_buffer_new(64);
        hoedown_document_render(
            document, ob, inputData.bytes, inputData.length);
        NSString *toc = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];

        static NSRegularExpression *tocRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *pattern = @"<p.*?>\\s*\\[TOC\\]\\s*</p>";
            NSRegularExpressionOptions ops = NSRegularExpressionCaseInsensitive;
            tocRegex = [[NSRegularExpression alloc] initWithPattern:pattern
                                                            options:ops
                                                              error:NULL];
        });
        NSRange replaceRange = NSMakeRange(0, result.length);
        result = [tocRegex stringByReplacingMatchesInString:result options:0
                                                      range:replaceRange
                                               withTemplate:toc];
        hoedown_document_free(document);
        hoedown_buffer_free(ob);
    }
    if (frontMatter)
        result = [NSString stringWithFormat:@"%@\n%@", frontMatter, result];
    
    return result;
}

NS_INLINE NSString *MPGetHTML(
    NSString *title, NSString *body, NSArray *styles, MPAssetOption styleopt,
    NSArray *scripts, MPAssetOption scriptopt)
{
    NSMutableArray *styleTags = [NSMutableArray array];
    NSMutableArray *scriptTags = [NSMutableArray array];
    for (MPStyleSheet *style in styles)
    {
        NSString *s = [style htmlForOption:styleopt];
        if (s)
            [styleTags addObject:s];
    }
    for (MPScript *script in scripts)
    {
        NSString *s = [script htmlForOption:scriptopt];
        if (s)
            [scriptTags addObject:s];
    }

    MPPreferences *preferences = [MPPreferences sharedInstance];

    static NSString *f = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:preferences.htmlTemplateName
                              withExtension:@".handlebars"
                               subdirectory:@"Templates"];
        f = [NSString stringWithContentsOfURL:url
                                     encoding:NSUTF8StringEncoding error:NULL];
    });
    NSCAssert(f.length, @"Could not read template");

    NSString *titleTag = @"";
    if (title.length)
        titleTag = [NSString stringWithFormat:@"<title>%@</title>", title];

    NSDictionary *context = @{
        @"title": title ? title : @"",
        @"titleTag": titleTag ? titleTag : @"",
        @"styleTags": styleTags ? styleTags : @[],
        @"body": body ? body : @"",
        @"scriptTags": scriptTags ? scriptTags : @[],
    };
    NSString *html = [HBHandlebars renderTemplateString:f withContext:context
                                                  error:NULL];
    return html;
}

NS_INLINE BOOL MPAreNilableStringsEqual(NSString *s1, NSString *s2)
{
    // The == part takes care of cases where s1 and s2 are both nil.
    return ([s1 isEqualToString:s2] || s1 == s2);
}


@interface MPRenderer ()

@property (strong) NSMutableArray *currentLanguages;
@property (readonly) NSArray *baseStylesheets;
@property (readonly) NSArray *prismStylesheets;
@property (readonly) NSArray *prismScripts;
@property (readonly) NSArray *mathjaxScripts;
@property (readonly) NSArray *mermaidStylesheets;
@property (readonly) NSArray *mermaidScripts;
@property (readonly) NSArray *graphvizScripts;
@property (readonly) NSArray *stylesheets;
@property (readonly) NSArray *scripts;
@property (copy) NSString *currentHtml;
@property (strong) NSOperationQueue *parseQueue;
@property int extensions;
@property BOOL smartypants;
@property BOOL TOC;
@property (copy) NSString *styleName;
@property BOOL frontMatter;
@property BOOL syntaxHighlighting;
@property BOOL mermaid;
@property BOOL graphviz;
@property MPCodeBlockAccessoryType codeBlockAccesory;
@property BOOL lineNumbers;
@property BOOL manualRender;
@property (copy) NSString *highlightingThemeName;

@end


NS_INLINE void add_to_languages(
    NSString *lang, NSMutableArray *languages, NSDictionary *languageMap)
{
    // Move language to root of dependencies.
    NSUInteger index = [languages indexOfObject:lang];
    if (index != NSNotFound)
        [languages removeObjectAtIndex:index];
    [languages insertObject:lang atIndex:0];

    // Add dependencies of this language.
    id require = languageMap[lang][@"require"];
    if ([require isKindOfClass:[NSString class]])
    {
        add_to_languages(require, languages, languageMap);
    }
    else if ([require isKindOfClass:[NSArray class]])
    {
        for (NSString *lang in require)
            add_to_languages(lang, languages, languageMap);
    }
    else if (require)
    {
        NSLog(@"Unknown Prism langauge requirement "
              @"%@ dropped for unknown format", require);
    }
}


NS_INLINE hoedown_buffer *language_addition(
    const hoedown_buffer *language, void *owner)
{
    MPRenderer *renderer = (__bridge MPRenderer *)owner;
    NSString *lang = [[NSString alloc] initWithBytes:language->data
                                              length:language->size
                                            encoding:NSUTF8StringEncoding];

    static NSDictionary *aliasMap = nil;
    static NSDictionary *languageMap = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:@"syntax_highlighting"
                              withExtension:@"json"];
        NSDictionary *info =
            [NSJSONSerialization JSONObjectWithFileAtURL:url options:0
                                                   error:NULL];

        aliasMap = info[@"aliases"];

        url = [bundle URLForResource:@"components" withExtension:@"js"
                        subdirectory:@"Prism"];
        NSString *code = [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
        NSDictionary *comp = MPGetObjectFromJavaScript(code, @"components");
        languageMap = comp[@"languages"];
    });

    // Try to identify alias and point it to the "real" language name.
    hoedown_buffer *mapped = NULL;
    if ([aliasMap objectForKey:lang])
    {
        lang = [aliasMap objectForKey:lang];
        NSData *data = [lang dataUsingEncoding:NSUTF8StringEncoding];
        mapped = hoedown_buffer_new(64);
        hoedown_buffer_put(mapped, data.bytes, data.length);
    }

    // Walk dependencies to include all required scripts.
    add_to_languages(lang, renderer.currentLanguages, languageMap);
    
    return mapped;
}

NS_INLINE hoedown_renderer *MPCreateHTMLRenderer(MPRenderer *renderer)
{
    int flags = renderer.rendererFlags;
    hoedown_renderer *htmlRenderer = hoedown_html_renderer_new(
        flags, kMPRendererTOCLevel);
    htmlRenderer->blockcode = hoedown_patch_render_blockcode;
    htmlRenderer->listitem = hoedown_patch_render_listitem;
    
    hoedown_html_renderer_state_extra *extra =
        hoedown_malloc(sizeof(hoedown_html_renderer_state_extra));
    extra->language_addition = language_addition;
    extra->owner = (__bridge void *)renderer;

    ((hoedown_html_renderer_state *)htmlRenderer->opaque)->opaque = extra;
    return htmlRenderer;
}

NS_INLINE hoedown_renderer *MPCreateHTMLTOCRenderer()
{
    hoedown_renderer *tocRenderer =
        hoedown_html_toc_renderer_new(kMPRendererTOCLevel);
    tocRenderer->header = hoedown_patch_render_toc_header;
    return tocRenderer;
}

NS_INLINE void MPFreeHTMLRenderer(hoedown_renderer *htmlRenderer)
{
    hoedown_html_renderer_state_extra *extra =
        ((hoedown_html_renderer_state *)htmlRenderer->opaque)->opaque;
    if (extra)
        free(extra);
    hoedown_html_renderer_free(htmlRenderer);
}


@implementation MPRenderer

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.currentHtml = @"";
    self.currentLanguages = [NSMutableArray array];
    self.parseQueue = [[NSOperationQueue alloc] init];
    self.parseQueue.maxConcurrentOperationCount = 1; // Serial queue

    return self;
}

#pragma mark - Accessor

- (NSArray *)baseStylesheets
{
    NSMutableArray *stylesheets = [NSMutableArray array];

    NSString *defaultStyleName =
        MPStylePathForName([self.delegate rendererStyleName:self]);
    if (defaultStyleName)
    {
        NSURL *defaultStyle = [NSURL fileURLWithPath:defaultStyleName];
        [stylesheets addObject:[MPStyleSheet CSSWithURL:defaultStyle]];
    }

    // After the chosen style, and part of every export that carries styles:
    // a picture is never wider than what holds it, whatever the style the
    // reader picked has to say about it.
    [stylesheets addObject:
        [MPStyleSheet CSSWithURL:MPExtensionURL(@"images", @"css")]];
    return stylesheets;
}

- (NSArray *)prismStylesheets
{
    NSString *name = [self.delegate rendererHighlightingThemeName:self];
    MPAsset *stylesheet =
        [MPStyleSheet CSSWithURL:MPHighlightingThemeURLForName(name)];

    NSMutableArray *stylesheets = [NSMutableArray arrayWithObject:stylesheet];

    if (self.rendererFlags & HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS)
    {
        NSURL *url = MPPrismPluginURL(@"line-numbers", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    if ([self.delegate rendererCodeBlockAccesory:self]
        == MPCodeBlockAccessoryLanguageName)
    {
        NSURL *url = MPPrismPluginURL(@"show-language", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }

    return stylesheets;
}

- (NSArray *)prismScripts
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:@"prism-core.min" withExtension:@"js"
                           subdirectory:kMPPrismScriptDirectory];
    MPAsset *script = [MPScript javaScriptWithURL:url];
    NSMutableArray *scripts = [NSMutableArray arrayWithObject:script];
    for (NSString *language in self.currentLanguages)
    {
        for (NSURL *url in MPPrismScriptURLsForLanguage(language))
            [scripts addObject:[MPScript javaScriptWithURL:url]];
    }

    if (self.rendererFlags & HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS)
    {
        NSURL *url = MPPrismPluginURL(@"line-numbers", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([self.delegate rendererCodeBlockAccesory:self]
        == MPCodeBlockAccessoryLanguageName)
    {
        NSURL *url = MPPrismPluginURL(@"show-language", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    return scripts;
}

/** MathJax, from the bundle rather than a CDN.
 *
 * It used to load the version 2 loader off cdnjs, with the local copy of
 * MathJax.js swapped in by a resource-load delegate. That only ever half
 * worked: MathJax 2 is a loader, it takes its base path from the script it
 * was loaded as, and it then fetched config, jax and fonts over the network.
 * Maths therefore needed an internet connection.
 *
 * The single-file SVG build carries everything, fonts included as glyph
 * outlines, so there is nothing left to fetch. The es5 build is the one to
 * take: it is the version that does not assume a current JavaScript engine,
 * which matters in the legacy web view.
 *
 * No configuration script goes with it. MathJax 3 already looks for exactly
 * the delimiters hoedown emits — \( \) inline and \[ \] display — and a
 * configuration script would have to run before the library, which an inline
 * script cannot be relied on to do here: the preview is refreshed by
 * assigning innerHTML, and scripts inserted that way never execute.
 */
- (NSArray *)mathjaxScripts
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"tex-svg"
                                         withExtension:@"js"
                                          subdirectory:@"MathJax"];
    if (!url)
        return @[];
    return @[[MPScript javaScriptWithURL:url]];
}

/** Layout only; mermaid themes the diagrams themselves.
 *
 * The bundled mermaid.forest.css is a light-only theme and outranks the
 * styles mermaid injects into each diagram, so it would pin every diagram to
 * the light palette whatever the appearance. mermaid.init.js picks the theme
 * instead, and this sheet is limited to placement and the parse-error box.
 */
- (NSArray *)mermaidStylesheets
{
    NSURL *url = MPExtensionURL(@"diagram", @"css");
    return @[[MPStyleSheet CSSWithURL:url]];
}

/** Whether this document has a fence in any of `languages`.
 *
 * currentLanguages is filled while the Markdown is rendered, and the scripts
 * are gathered afterwards, so by now it says what the document actually
 * contains. Mermaid alone is nearly three megabytes: worth reading off disk
 * for a document with a diagram in it, worth skipping for one without.
 */
- (BOOL)documentUsesAnyLanguage:(NSArray<NSString *> *)languages
{
    for (NSString *used in self.currentLanguages)
    {
        for (NSString *wanted in languages)
        {
            if ([used caseInsensitiveCompare:wanted] == NSOrderedSame)
                return YES;
        }
    }
    return NO;
}

- (NSArray *)mermaidScripts
{
    // TODO
    NSMutableArray *scripts = [NSMutableArray array];

    {
        NSURL *url = MPExtensionURL(@"mermaid.min", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    {
        NSURL *url = MPExtensionURL(@"mermaid.init", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    
    return scripts;
}

- (NSArray *)graphvizScripts
{
    NSMutableArray *scripts = [NSMutableArray array];

    {
        NSURL *url = MPExtensionURL(@"viz", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    {
        NSURL *url = MPExtensionURL(@"viz.init", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    
    return scripts;
}

- (NSArray *)stylesheets
{
    id<MPRendererDelegate> delegate = self.delegate;

    NSMutableArray *stylesheets = [self.baseStylesheets mutableCopy];
    if ([delegate rendererHasSyntaxHighlighting:self])
        [stylesheets addObjectsFromArray:self.prismStylesheets];
    // One sheet for both kinds of diagram: it is layout and zoom chrome, and
    // carries no colours of its own.
    if ([delegate rendererHasMermaid:self] || [delegate rendererHasGraphviz:self])
        [stylesheets addObjectsFromArray:self.mermaidStylesheets];

    // WikiLink styling. Bundle-only, so it cannot be shadowed by a stale copy
    // in Application Support the way a preview style can.
    [stylesheets addObject:
        [MPStyleSheet CSSWithURL:MPExtensionURL(@"wikilink", @"css")]];

    if ([delegate rendererCodeBlockAccesory:self] == MPCodeBlockAccessoryCustom)
    {
        NSURL *url = MPExtensionURL(@"show-information", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }

    // Last, so it overrides the selected style. Skipped for styles that
    // declare their own dark rules.
    NSString *stylePath = MPStylePathForName([delegate rendererStyleName:self]);
    if (!MPStyleHandlesDarkAppearance(stylePath))
    {
        NSURL *url = MPExtensionURL(@"dark-mode", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    return stylesheets;
}

- (NSArray *)scripts
{
    id<MPRendererDelegate> d = self.delegate;
    NSMutableArray *scripts = [NSMutableArray array];
    if (self.rendererFlags & HOEDOWN_HTML_USE_TASK_LIST)
    {
        NSURL *url = MPExtensionURL(@"tasklist", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([d rendererHasSyntaxHighlighting:self])
        [scripts addObjectsFromArray:self.prismScripts];

    // Diagrams are their own feature: they were nested inside the syntax
    // highlighting branch, which meant turning highlighting off silently
    // disabled them even with their own preference switched on.
    BOOL mermaid = [d rendererHasMermaid:self]
        && [self documentUsesAnyLanguage:@[@"mermaid"]];
    BOOL graphviz = [d rendererHasGraphviz:self]
        && [self documentUsesAnyLanguage:@[@"dot", @"neato", @"fdp", @"circo",
                                           @"twopi", @"osage"]];
    if (mermaid || graphviz)
    {
        // Before either bootstrap, which both call into it.
        [scripts addObject:[MPScript javaScriptWithURL:
            MPExtensionURL(@"diagram-zoom", @"js")]];
    }
    if (mermaid)
        [scripts addObjectsFromArray:self.mermaidScripts];
    if (graphviz)
        [scripts addObjectsFromArray:self.graphvizScripts];
    if ([d rendererHasMathJax:self])
        [scripts addObjectsFromArray:self.mathjaxScripts];
    return scripts;
}

#pragma mark - Public
    
- (void)parseAndRenderWithMaxDelay:(NSTimeInterval)maxDelay {
    [self.parseQueue cancelAllOperations];
    [self.parseQueue addOperationWithBlock:^{
        // Fetch the markdown (from the main thread)
        __block NSString *markdown;
        dispatch_sync(dispatch_get_main_queue(), ^{
            markdown = [[self.dataSource rendererMarkdown:self] copy];
        });

        // Parse in backgound
        [self parseMarkdown:markdown];
        
        // Wait untils is renderer has finished loading OR until the maxDelay has passed
        // This should result in overall faster update times
        NSDate *start = [NSDate date];
        __block BOOL rendererIsLoading = true;
        while (rendererIsLoading || [start timeIntervalSinceNow] >= maxDelay) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                rendererIsLoading = [self.dataSource rendererLoading];
            });
        }
        
        // Render on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self render];
        });
    }];
}

- (void)parseAndRenderNow
{
    [self parseAndRenderWithMaxDelay:0];
}

- (void)parseAndRenderLater
{
    [self parseAndRenderWithMaxDelay:0.5];
}

- (void)parseIfPreferencesChanged
{
    id<MPRendererDelegate> delegate = self.delegate;
    if ([delegate rendererExtensions:self] != self.extensions
            || [delegate rendererHasSmartyPants:self] != self.smartypants
            || [delegate rendererRendersTOC:self] != self.TOC
            || [delegate rendererDetectsFrontMatter:self] != self.frontMatter)
    {
        [self parseMarkdown:[self.dataSource rendererMarkdown:self]];
    }
}

- (void)parseMarkdown:(NSString *)markdown {
    [self.currentLanguages removeAllObjects];
    
    id<MPRendererDelegate> delegate = self.delegate;
    int extensions = [delegate rendererExtensions:self];
    BOOL smartypants = [delegate rendererHasSmartyPants:self];
    BOOL hasFrontMatter = [delegate rendererDetectsFrontMatter:self];
    BOOL hasTOC = [delegate rendererRendersTOC:self];
    
    id frontMatter = nil;
    if (hasFrontMatter)
    {
        NSUInteger offset = 0;
        frontMatter = [markdown frontMatter:&offset];
        markdown = [markdown substringFromIndex:offset];
    }
    hoedown_renderer *htmlRenderer = MPCreateHTMLRenderer(self);
    hoedown_renderer *tocRenderer = NULL;
    if (hasTOC)
    tocRenderer = MPCreateHTMLTOCRenderer();
    self.currentHtml = MPHTMLFromMarkdown(
                                          markdown, extensions, smartypants, [frontMatter HTMLTable],
                                          htmlRenderer, tocRenderer);
    if (tocRenderer)
    hoedown_html_renderer_free(tocRenderer);
    MPFreeHTMLRenderer(htmlRenderer);
    
    self.extensions = extensions;
    self.smartypants = smartypants;
    self.TOC = hasTOC;
    self.frontMatter = hasFrontMatter;
}

- (void)renderIfPreferencesChanged
{
    BOOL changed = NO;
    id<MPRendererDelegate> d = self.delegate;
    if ([d rendererHasSyntaxHighlighting:self] != self.syntaxHighlighting)
        changed = YES;
    else if ([d rendererHasMermaid:self] != self.mermaid)
        changed = YES;
    else if ([d rendererHasGraphviz:self] != self.graphviz)
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [d rendererHighlightingThemeName:self], self.highlightingThemeName))
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [d rendererStyleName:self], self.styleName))
        changed = YES;
    else if ([d rendererCodeBlockAccesory:self] != self.codeBlockAccesory)
        changed = YES;

    if (changed)
        [self render];
}

- (void)render
{
    id<MPRendererDelegate> delegate = self.delegate;

    NSString *title = [self.dataSource rendererHTMLTitle:self];
    NSString *html = MPGetHTML(
        title, self.currentHtml, self.stylesheets, MPAssetFullLink,
        self.scripts, MPAssetFullLink);
    [delegate renderer:self didProduceHTMLOutput:html];

    self.styleName = [delegate rendererStyleName:self];
    self.syntaxHighlighting = [delegate rendererHasSyntaxHighlighting:self];
    self.mermaid = [delegate rendererHasMermaid:self];
    self.graphviz = [delegate rendererHasGraphviz:self];
    self.highlightingThemeName = [delegate rendererHighlightingThemeName:self];
    self.codeBlockAccesory = [delegate rendererCodeBlockAccesory:self];
}

- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting
{
    MPAssetOption stylesOption = MPAssetNone;
    MPAssetOption scriptsOption = MPAssetNone;
    NSMutableArray *styles = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];

    if (withStyles)
    {
        stylesOption = MPAssetEmbedded;
        [styles addObjectsFromArray:self.baseStylesheets];
    }
    if (withHighlighting)
    {
        stylesOption = MPAssetEmbedded;
        scriptsOption = MPAssetEmbedded;
        [styles addObjectsFromArray:self.prismStylesheets];
        [scripts addObjectsFromArray:self.prismScripts];
        if ([self.delegate rendererHasGraphviz:self])
            [scripts addObjectsFromArray:self.graphvizScripts];
    }

    // Mermaid is deliberately absent here, and not because it was forgotten.
    //
    // It used to sit inside the branch above, so a diagram only survived an
    // export if you also asked for syntax highlighting. And when it did come
    // along, MPAssetEmbedded inlined the whole 1.1 MB library into every
    // exported file, which then had to re-render the diagrams on open.
    //
    // The diagrams are already drawn in the preview, so MPDocument swaps the
    // finished SVG into this markup instead. Nothing to ship, nothing to run.
    if ([self.delegate rendererHasMathJax:self])
    {
        scriptsOption = MPAssetEmbedded;
        [scripts addObjectsFromArray:self.mathjaxScripts];
    }

    NSString *title = [self.dataSource rendererHTMLTitle:self];
    if (!title)
        title = @"";
    NSString *html = MPGetHTML(
        title, self.currentHtml, styles, stylesOption, scripts, scriptsOption);
    return html;
}

@end
