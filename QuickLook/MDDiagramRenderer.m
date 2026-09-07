//
//  MDDiagramRenderer.m
//  MacDownQuickLook
//

#import "MDDiagramRenderer.h"

#import <WebKit/WebKit.h>
#import <os/log.h>


/// The extension has no window to put a message in, so what it can say
/// about itself it says to the log. `log show --predicate 'process ==
/// "MacDownQuickLook"'` is where the control suite reads it.
static os_log_t MDDiagramLog(void)
{
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("com.nicolorisitano82.macdown.quicklook",
                            "diagrams");
    });
    return log;
}


/// The fence, in both shapes hoedown emits for it.
static NSString * const kMDFencePattern =
    @"(?:<div[^>]*>)?<pre[^>]*><code class=\"language-mermaid\">"
    @"([\\s\\S]*?)</code></pre>(?:</div>)?";

/// What mermaid is asked to lay out at, since nothing here has a window to
/// take a width from. Wide enough that labels do not collide; the page then
/// fits the drawing to its own column.
static const CGSize kMDLayoutSize = (CGSize){1400.0, 1000.0};


@implementation MDDiagramFence

- (instancetype)initWithSource:(NSString *)source range:(NSRange)range
{
    self = [super init];
    if (self)
    {
        _source = [source copy];
        _range = range;
    }
    return self;
}

@end


#pragma mark - Reading the page

/// The escaping hoedown put in, taken back out.
///
/// The fence arrives as HTML, so `-->` inside a flowchart is `--&gt;` by the
/// time it gets here, and mermaid would refuse it.
static NSString *MDUnescaped(NSString *text)
{
    if (![text containsString:@"&"])
        return text;

    NSMutableString *out = [text mutableCopy];
    // The ampersand last of all: undoing it earlier would turn "&amp;lt;"
    // into a tag.
    NSDictionary<NSString *, NSString *> *entities = @{
        @"&lt;": @"<", @"&gt;": @">", @"&quot;": @"\"", @"&apos;": @"'",
        @"&nbsp;": @" ", @"&#39;": @"'", @"&#x27;": @"'", @"&#x2F;": @"/",
        @"&#47;": @"/",
    };
    for (NSString *entity in entities)
    {
        [out replaceOccurrencesOfString:entity withString:entities[entity]
                                options:0 range:NSMakeRange(0, out.length)];
    }
    [out replaceOccurrencesOfString:@"&amp;" withString:@"&"
                            options:0 range:NSMakeRange(0, out.length)];
    return out;
}


NSArray<MDDiagramFence *> *MDDiagramFencesInHTML(NSString *html)
{
    if (!html.length)
        return @[];

    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:kMDFencePattern options:0 error:NULL];
    NSMutableArray<MDDiagramFence *> *fences = [NSMutableArray array];
    for (NSTextCheckingResult *match in
         [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)])
    {
        NSString *source =
            MDUnescaped([html substringWithRange:[match rangeAtIndex:1]]);
        if (!source.length)
            continue;
        [fences addObject:[[MDDiagramFence alloc] initWithSource:source
                                                           range:match.range]];
    }
    return fences;
}


NSString *MDSVGWithoutScripts(NSString *svg)
{
    if (!svg.length)
        return @"";

    NSArray<NSString *> *patterns = @[
        @"<script[\\s\\S]*?</script\\s*>",
        @"<(?:iframe|object|embed)[\\s\\S]*?>",
        // An attribute that runs on an event, however it is quoted.
        @"\\son[a-zA-Z]+\\s*=\\s*(?:\"[^\"]*\"|'[^']*'|[^\\s>]+)",
        // A link that runs instead of going somewhere.
        @"(?:xlink:)?href\\s*=\\s*(?:\"\\s*javascript:[^\"]*\""
        @"|'\\s*javascript:[^']*')",
    ];
    NSMutableString *out = [svg mutableCopy];
    for (NSString *pattern in patterns)
    {
        NSRegularExpression *regex = [NSRegularExpression
            regularExpressionWithPattern:pattern
                                 options:NSRegularExpressionCaseInsensitive
                                   error:NULL];
        [regex replaceMatchesInString:out options:0
                               range:NSMakeRange(0, out.length)
                        withTemplate:@""];
    }
    return out;
}


NSString *MDHTMLByDrawingFences(NSString *html,
                                NSArray<MDDiagramFence *> *fences,
                                NSArray *drawings)
{
    if (!fences.count)
        return html;

    // Back to front, so each replacement leaves the earlier ranges valid.
    NSMutableString *out = [html mutableCopy];
    for (NSInteger i = (NSInteger)fences.count - 1; i >= 0; i--)
    {
        id drawing = (NSUInteger)i < drawings.count ? drawings[(NSUInteger)i]
                                                    : nil;
        if (![drawing isKindOfClass:[NSString class]]
                || ![(NSString *)drawing length])
            continue;

        NSString *svg = MDSVGWithoutScripts(drawing);
        if (!svg.length)
            continue;
        [out replaceCharactersInRange:fences[(NSUInteger)i].range
                           withString:[NSString stringWithFormat:
                               @"<div class=\"macdown-diagram\">%@</div>",
                               svg]];
    }
    return out;
}


#pragma mark - Drawing them

/// The page mermaid is loaded into: the library itself, and the one function
/// this extension calls.
static NSString *MDDrawingPage(NSString *mermaid)
{
    return [NSString stringWithFormat:
        @"<!doctype html><html><head><meta charset=\"utf-8\">"
        @"<style>body{margin:0;width:%.0fpx}</style></head><body>"
        @"<script>%@</script>\n"
        @"<script>\n"
        // startOnLoad would look for fences; there are none here, the
        // diagrams are handed over one at a time. htmlLabels are off so
        // that what comes back is SVG all the way down: a foreignObject
        // full of HTML would arrive in a page that allows no styles of its
        // own beyond the sheet.
        @"mermaid.initialize({startOnLoad:false, securityLevel:'strict',"
        @" theme:'forest', flowchart:{htmlLabels:false, useMaxWidth:true},"
        @" gantt:{useWidth:%.0f}});\n"
        @"var mdCount = 0;\n"
        @"window.MDDraw = function (code) {\n"
        @"  return mermaid.render('md-diagram-' + (mdCount++), code)\n"
        @"    .then(function (r) { return (r && r.svg) ? r.svg : String(r); });\n"
        @"};\n"
        @"window.MDReady = true;\n"
        @"</script></body></html>",
        kMDLayoutSize.width, mermaid, kMDLayoutSize.width];
}


@interface MDDiagramRenderer () <WKNavigationDelegate>
@property (nonatomic) WKWebView *webView;
@property (nonatomic) NSMutableArray *drawings;
@property (copy, nonatomic) NSArray<NSString *> *sources;
@property (nonatomic) NSUInteger next;
@property (nonatomic) NSDate *deadline;
@property (nonatomic) NSDate *started;
@property (copy, nonatomic) void (^completion)(NSArray *);
/// The renderer keeps itself alive: nobody else holds it while mermaid works.
@property (nonatomic) MDDiagramRenderer *self_;
@end


@implementation MDDiagramRenderer

+ (void)drawSources:(NSArray<NSString *> *)sources
      mermaidScript:(NSURL *)script
             within:(NSTimeInterval)budget
         completion:(void (^)(NSArray *))completion
{
    NSString *mermaid = script
        ? [NSString stringWithContentsOfURL:script encoding:NSUTF8StringEncoding
                                      error:NULL]
        : nil;
    if (!sources.count || !mermaid.length)
    {
        // Nothing to draw, or nothing to draw with: the fences stay as they
        // are, which is what the preview showed until now.
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[]);
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        MDDiagramRenderer *renderer = [[MDDiagramRenderer alloc] init];
        renderer.self_ = renderer;
        renderer.sources = sources;
        renderer.drawings = [NSMutableArray array];
        renderer.completion = completion;
        renderer.deadline = [NSDate dateWithTimeIntervalSinceNow:budget];
        renderer.started = [NSDate date];
        os_log(MDDiagramLog(), "drawing %lu diagrams, %.1f s to do it in",
               (unsigned long)sources.count, budget);

        WKWebViewConfiguration *configuration =
            [[WKWebViewConfiguration alloc] init];
        // A page built here, from a file inside this bundle. It asks for
        // nothing else, and inside the sandbox it would get nothing else.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
        renderer.webView = [[WKWebView alloc]
            initWithFrame:NSMakeRect(0.0, 0.0, kMDLayoutSize.width,
                                     kMDLayoutSize.height)
            configuration:configuration];
        renderer.webView.navigationDelegate = renderer;
        [renderer.webView loadHTMLString:MDDrawingPage(mermaid) baseURL:nil];

        // The whole batch, however far it gets. A preview that arrives late
        // has not arrived: Quick Look has already given up on it.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(budget * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [renderer finish];
        });
    });
}


- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation
{
    os_log(MDDiagramLog(), "page loaded after %.0f ms",
           -[self.started timeIntervalSinceNow] * 1000.0);
    [self drawNext];
}


- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    os_log_error(MDDiagramLog(), "page did not load: %{public}@",
                 error.localizedDescription);
    [self finish];
}


- (void)drawNext
{
    if (!self.completion)
        return;                     // already finished, or timed out
    if (self.next >= self.sources.count
            || [self.deadline timeIntervalSinceNow] <= 0.0)
    {
        [self finish];
        return;
    }

    NSString *source = self.sources[self.next++];
    [self.webView callAsyncJavaScript:@"return await MDDraw(code);"
                           arguments:@{@"code": source}
                             inFrame:nil
                      inContentWorld:WKContentWorld.pageWorld
                   completionHandler:^(id result, NSError *error) {
        // A diagram with a mistake in it is a mistake in one diagram: the
        // page keeps the fence for that one and the drawings for the rest.
        if (![result isKindOfClass:[NSString class]])
        {
            os_log_error(MDDiagramLog(), "diagram not drawn: %{public}@",
                         error.localizedDescription ?: @"no answer");
        }
        [self.drawings addObject:[result isKindOfClass:[NSString class]]
            ? result : (id)[NSNull null]];
        [self drawNext];
    }];
}


- (void)finish
{
    void (^completion)(NSArray *) = self.completion;
    if (!completion)
        return;
    self.completion = nil;

    self.webView.navigationDelegate = nil;
    [self.webView stopLoading];
    self.webView = nil;

    NSArray *drawings = [self.drawings copy];
    NSUInteger drawn = 0;
    for (id drawing in drawings)
    {
        if ([drawing isKindOfClass:[NSString class]])
            drawn++;
    }
    os_log(MDDiagramLog(), "drawn %lu of %lu in %.0f ms",
           (unsigned long)drawn, (unsigned long)self.sources.count,
           -[self.started timeIntervalSinceNow] * 1000.0);

    self.self_ = nil;
    completion(drawings);
}

@end
