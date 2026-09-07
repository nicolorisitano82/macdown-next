//
//  MDDiagramRenderer.m
//  MacDownQuickLook
//

#import "MDDiagramRenderer.h"

#import <WebKit/WebKit.h>
#import <os/log.h>


NSString * const MDMermaidResource = @"mermaid";
NSString * const MDGraphvizResource = @"graphviz";
NSString * const MDMathResource = @"math";

/// Graphviz picks a layout by engine, and each is spelled as a fence
/// language: ```dot for the hierarchical one, ```neato for spring layout.
static NSString * const kMDGraphvizEngines =
    @"dot|neato|fdp|circo|twopi|osage";

/// What mermaid and Graphviz are asked to lay out at, since nothing here has
/// a window to take a width from. Wide enough that labels do not collide;
/// the page then fits the drawing to its own column.
static const CGSize kMDLayoutSize = (CGSize){1400.0, 1000.0};


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


@interface MDDrawingJob ()
@property (copy, nonatomic) NSString *source;
@property (nonatomic) NSRange range;
@property (nonatomic) MDDrawingKind kind;
@property (copy, nonatomic) NSString *engine;
@end

@implementation MDDrawingJob
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


/// The parts of the page that are code, and where nothing is drawn.
///
/// hoedown protects a code *span* from becoming a formula, but the inside of
/// a fenced block is text it copies out as written: a block showing how to
/// write `\[x\]` would otherwise be typeset instead of shown.
static NSArray<NSValue *> *MDCodeRegions(NSString *html)
{
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"<pre[\\s\\S]*?</pre\\s*>"
                                     @"|<code[\\s\\S]*?</code\\s*>"
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];
    NSMutableArray<NSValue *> *regions = [NSMutableArray array];
    for (NSTextCheckingResult *match in
         [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)])
    {
        [regions addObject:[NSValue valueWithRange:match.range]];
    }
    return regions;
}

static BOOL MDIsInside(NSRange range, NSArray<NSValue *> *regions)
{
    for (NSValue *value in regions)
    {
        NSRange region = value.rangeValue;
        if (range.location >= region.location
                && NSMaxRange(range) <= NSMaxRange(region))
            return YES;
    }
    return NO;
}


NSArray<MDDrawingJob *> *MDDrawingJobsInHTML(NSString *html)
{
    if (!html.length)
        return @[];

    NSString *fences = [NSString stringWithFormat:
        @"(?:<div[^>]*>)?<pre[^>]*><code class=\"language-(mermaid|%@)\">"
        @"([\\s\\S]*?)</code></pre>(?:</div>)?", kMDGraphvizEngines];
    // The delimiters hoedown leaves behind for a formula, which are the ones
    // MathJax looks for. Display first: "\[" would otherwise never match.
    NSString *math = @"\\\\\\[([\\s\\S]*?)\\\\\\]|\\\\\\(([\\s\\S]*?)\\\\\\)";

    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:[NSString stringWithFormat:@"%@|%@",
                                      fences, math]
                             options:0 error:NULL];
    NSArray<NSValue *> *code = MDCodeRegions(html);
    NSMutableArray<MDDrawingJob *> *jobs = [NSMutableArray array];

    for (NSTextCheckingResult *match in
         [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)])
    {
        MDDrawingJob *job = [[MDDrawingJob alloc] init];
        job.range = match.range;

        NSRange fence = [match rangeAtIndex:2];
        NSRange display = [match rangeAtIndex:3];
        NSRange inline_ = [match rangeAtIndex:4];
        if (fence.location != NSNotFound)
        {
            NSString *language = [html substringWithRange:
                [match rangeAtIndex:1]];
            job.kind = [language isEqualToString:@"mermaid"]
                ? MDDrawingMermaid : MDDrawingGraphviz;
            job.engine = job.kind == MDDrawingGraphviz ? language : nil;
            job.source = MDUnescaped([html substringWithRange:fence]);
        }
        else if (display.location != NSNotFound)
        {
            // A formula inside a code block is a formula being shown, not
            // one being written.
            if (MDIsInside(match.range, code))
                continue;
            job.kind = MDDrawingMathDisplay;
            job.source = MDUnescaped([html substringWithRange:display]);
        }
        else if (inline_.location != NSNotFound)
        {
            if (MDIsInside(match.range, code))
                continue;
            job.kind = MDDrawingMathInline;
            job.source = MDUnescaped([html substringWithRange:inline_]);
        }
        else
        {
            continue;
        }

        if (![job.source stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]].length)
            continue;
        [jobs addObject:job];
    }
    return jobs;
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


NSString *MDHTMLByDrawingJobs(NSString *html,
                              NSArray<MDDrawingJob *> *jobs,
                              NSArray *drawings)
{
    if (!jobs.count)
        return html;

    // Back to front, so each replacement leaves the earlier ranges valid.
    NSMutableString *out = [html mutableCopy];
    for (NSInteger i = (NSInteger)jobs.count - 1; i >= 0; i--)
    {
        id drawing = (NSUInteger)i < drawings.count ? drawings[(NSUInteger)i]
                                                    : nil;
        if (![drawing isKindOfClass:[NSString class]]
                || ![(NSString *)drawing length])
            continue;

        NSString *svg = MDSVGWithoutScripts(drawing);
        if (!svg.length)
            continue;

        MDDrawingJob *job = jobs[(NSUInteger)i];
        // A diagram gets a block of its own to sit in; a formula carries its
        // own placement, in the container MathJax wraps it in.
        NSString *replacement =
            (job.kind == MDDrawingMermaid || job.kind == MDDrawingGraphviz)
            ? [NSString stringWithFormat:
                   @"<div class=\"macdown-diagram\">%@</div>", svg]
            : svg;
        [out replaceCharactersInRange:job.range withString:replacement];
    }
    return out;
}


#pragma mark - Drawing them

/// The page the libraries are loaded into, with only the ones that are
/// wanted: three and a half megabytes of JavaScript per preview is a price
/// worth paying once for a document with a flowchart in it, and not at all
/// for one without.
static NSString *MDDrawingPage(NSString *mermaid, NSString *viz,
                               NSString *mathjax)
{
    NSMutableString *page = [NSMutableString string];
    [page appendFormat:
        @"<!doctype html><html><head><meta charset=\"utf-8\">"
        @"<style>body{margin:0;width:%.0fpx}</style></head><body>",
        kMDLayoutSize.width];
    for (NSString *library in @[mermaid ?: @"", viz ?: @"", mathjax ?: @""])
    {
        if (library.length)
            [page appendFormat:@"<script>%@</script>\n", library];
    }

    [page appendString:@"<script>\n"];
    if (mermaid.length)
    {
        // startOnLoad would look for fences; there are none here, the
        // diagrams are handed over one at a time. htmlLabels are off so that
        // what comes back is SVG all the way down: a foreignObject full of
        // HTML would arrive in a page that allows no styles of its own
        // beyond the sheet.
        [page appendFormat:
            @"mermaid.initialize({startOnLoad:false, securityLevel:'strict',"
            @" theme:'forest', flowchart:{htmlLabels:false,"
            @" useMaxWidth:true}, gantt:{useWidth:%.0f}});\n",
            kMDLayoutSize.width];
    }
    [page appendString:
        @"var mdCount = 0;\n"
        @"window.MDDraw = function (kind, code, engine) {\n"
        @"  if (kind === 'mermaid') {\n"
        @"    return mermaid.render('md-' + (mdCount++), code)\n"
        @"      .then(function (r) { return (r && r.svg) ? r.svg"
        @" : String(r); });\n"
        @"  }\n"
        @"  if (kind === 'graphviz') {\n"
        // Viz reports a malformed graph by throwing, and a rejected promise
        // is what the extension is waiting for.
        @"    return new Promise(function (resolve) {\n"
        @"      resolve(Viz(code, {engine: engine, format: 'svg'}));\n"
        @"    });\n"
        @"  }\n"
        @"  var display = (kind === 'math-display');\n"
        @"  return MathJax.startup.promise.then(function () {\n"
        @"    return MathJax.tex2svgPromise(code, {display: display});\n"
        @"  }).then(function (node) { return node.outerHTML; });\n"
        @"};\n"
        // What the formulas need in order to sit on the line properly.
        // MathJax writes it once it has typeset something.
        @"window.MDStyles = function () {\n"
        @"  if (typeof MathJax === 'undefined' || !MathJax.svgStylesheet)\n"
        @"    return '';\n"
        @"  return MathJax.svgStylesheet().textContent || '';\n"
        @"};\n"
        @"</script></body></html>"];
    return page;
}


static NSString *MDKindName(MDDrawingKind kind)
{
    switch (kind)
    {
        case MDDrawingMermaid:      return @"mermaid";
        case MDDrawingGraphviz:     return @"graphviz";
        case MDDrawingMathDisplay:  return @"math-display";
        case MDDrawingMathInline:   return @"math-inline";
    }
}


@interface MDDiagramRenderer () <WKNavigationDelegate>
@property (nonatomic) WKWebView *webView;
@property (nonatomic) NSMutableArray *drawings;
@property (copy, nonatomic) NSArray<MDDrawingJob *> *jobs;
@property (nonatomic) NSUInteger next;
@property (nonatomic) BOOL wantsStyles;
/// What MathJax says its drawings need, once it has drawn one.
@property (copy, nonatomic) NSString *styleSheet;
@property (nonatomic) NSDate *deadline;
@property (nonatomic) NSDate *started;
@property (copy, nonatomic) void (^completion)(NSArray *, NSString *);
/// The renderer keeps itself alive: nobody else holds it while the libraries
/// work.
@property (nonatomic) MDDiagramRenderer *self_;
@end


@implementation MDDiagramRenderer

+ (void)drawJobs:(NSArray<MDDrawingJob *> *)jobs
       resources:(NSDictionary<NSString *, NSURL *> *)resources
          within:(NSTimeInterval)budget
      completion:(void (^)(NSArray *, NSString *))completion
{
    BOOL wantsMermaid = NO, wantsGraphviz = NO, wantsMath = NO;
    for (MDDrawingJob *job in jobs)
    {
        wantsMermaid |= (job.kind == MDDrawingMermaid);
        wantsGraphviz |= (job.kind == MDDrawingGraphviz);
        wantsMath |= (job.kind == MDDrawingMathDisplay
                      || job.kind == MDDrawingMathInline);
    }

    NSString *(^read)(NSString *) = ^NSString *(NSString *name) {
        NSURL *url = resources[name];
        if (!url)
            return nil;
        return [NSString stringWithContentsOfURL:url
                                        encoding:NSUTF8StringEncoding
                                           error:NULL];
    };
    NSString *mermaid = wantsMermaid ? read(MDMermaidResource) : nil;
    NSString *viz = wantsGraphviz ? read(MDGraphvizResource) : nil;
    NSString *mathjax = wantsMath ? read(MDMathResource) : nil;

    // A job whose library is missing is a job that cannot be done: its
    // source stays in the page, which is what the preview showed before.
    NSMutableArray<MDDrawingJob *> *doable = [NSMutableArray array];
    for (MDDrawingJob *job in jobs)
    {
        switch (job.kind)
        {
            case MDDrawingMermaid:
                if (mermaid.length) [doable addObject:job];
                break;
            case MDDrawingGraphviz:
                if (viz.length) [doable addObject:job];
                break;
            default:
                if (mathjax.length) [doable addObject:job];
                break;
        }
    }

    if (!doable.count)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil);
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        MDDiagramRenderer *renderer = [[MDDiagramRenderer alloc] init];
        renderer.self_ = renderer;
        renderer.jobs = doable;
        renderer.drawings = [NSMutableArray array];
        renderer.wantsStyles = mathjax.length > 0;
        renderer.completion = completion;
        renderer.deadline = [NSDate dateWithTimeIntervalSinceNow:budget];
        renderer.started = [NSDate date];
        os_log(MDDiagramLog(),
               "drawing %lu things (mermaid %d, graphviz %d, maths %d),"
               " %.1f s to do it in",
               (unsigned long)doable.count, wantsMermaid, wantsGraphviz,
               wantsMath, budget);

        WKWebViewConfiguration *configuration =
            [[WKWebViewConfiguration alloc] init];
        // A page built here, from files inside this bundle. It asks for
        // nothing else, and inside the sandbox it would get nothing else.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
        renderer.webView = [[WKWebView alloc]
            initWithFrame:NSMakeRect(0.0, 0.0, kMDLayoutSize.width,
                                     kMDLayoutSize.height)
            configuration:configuration];
        renderer.webView.navigationDelegate = renderer;
        [renderer.webView loadHTMLString:MDDrawingPage(mermaid, viz, mathjax)
                                baseURL:nil];

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
    if (self.next >= self.jobs.count
            || [self.deadline timeIntervalSinceNow] <= 0.0)
    {
        [self collectStyles];
        return;
    }

    MDDrawingJob *job = self.jobs[self.next++];
    [self.webView callAsyncJavaScript:@"return await MDDraw(kind, code, engine);"
                           arguments:@{@"kind": MDKindName(job.kind),
                                       @"code": job.source,
                                       @"engine": job.engine ?: @"dot"}
                             inFrame:nil
                      inContentWorld:WKContentWorld.pageWorld
                   completionHandler:^(id result, NSError *error) {
        // Something with a mistake in it is a mistake in one thing: the page
        // keeps that source and the drawings for everything else.
        if (![result isKindOfClass:[NSString class]])
        {
            os_log_error(MDDiagramLog(), "%{public}@ not drawn: %{public}@",
                         MDKindName(job.kind),
                         error.localizedDescription ?: @"no answer");
        }
        [self.drawings addObject:[result isKindOfClass:[NSString class]]
            ? result : (id)[NSNull null]];
        [self drawNext];
    }];
}


/// What the formulas need to sit on the line, asked for once at the end.
- (void)collectStyles
{
    if (!self.wantsStyles || !self.completion)
    {
        [self finish];
        return;
    }
    self.wantsStyles = NO;
    [self.webView evaluateJavaScript:@"MDStyles();"
                  completionHandler:^(id result, NSError *error) {
        if ([result isKindOfClass:[NSString class]])
            self.styleSheet = result;
        [self finish];
    }];
}


- (void)finish
{
    void (^completion)(NSArray *, NSString *) = self.completion;
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
           (unsigned long)drawn, (unsigned long)self.jobs.count,
           -[self.started timeIntervalSinceNow] * 1000.0);

    NSString *styles = self.styleSheet;
    self.self_ = nil;
    completion(drawings, styles);
}

@end
