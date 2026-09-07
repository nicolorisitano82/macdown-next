//
//  MDDrawioRenderer.m
//  MacDown Next — draw.io plug-in
//

#import "MDDrawioRenderer.h"
#import "MDDrawioStrings.h"
#import "MDDrawioResources.h"
#import <WebKit/WebKit.h>

/// Long enough for a page of a few hundred cells; short enough to give up.
static const NSTimeInterval kMDRenderTimeout = 20.0;
/// How often the page is asked whether the drawing has appeared.
static const NSTimeInterval kMDPollInterval = 0.1;


@interface MDDrawioRenderer () <WKNavigationDelegate>
@property (strong, nonatomic) NSBundle *bundle;
@property (strong, nonatomic) WKWebView *webView;
@property (copy, nonatomic) MDDrawioRenderHandler handler;
@property (nonatomic) CGFloat scale;
@property (strong, nonatomic) NSDate *deadline;
/// The viewer, read once: it is two and a half megabytes of JavaScript.
@property (copy, nonatomic) NSString *viewer;
/// Serves the page and the shape libraries; lives as long as the web view.
@property (strong, nonatomic, readwrite) MDDrawioResources *resources;
@end


@implementation MDDrawioRenderer

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (!self)
        return nil;
    _bundle = bundle;
    return self;
}

- (NSString *)viewer
{
    if (_viewer)
        return _viewer;
    NSURL *url = [self.bundle URLForResource:@"viewer.min" withExtension:@"js"];
    _viewer = url ? [NSString stringWithContentsOfURL:url
                                             encoding:NSUTF8StringEncoding
                                                error:NULL] : nil;
    return _viewer;
}

/** The page that draws one diagram, with the viewer written into it.
 *
 * Inline rather than linked: two and a half megabytes in a string for a
 * moment beats a copy of them in a folder per picture.
 *
 * The eight addresses below are the viewer's own, every one of them on
 * diagrams.net by default, and every one of them pointed back into the
 * plug-in here. Two of the eight were done at first, which is the same as
 * none: a diagram drawn with the AWS library would have gone out for its
 * stencils while this said it was working offline.
 */
+ (NSString *)pageForXML:(NSString *)xml
                    base:(NSString *)base
                  viewer:(NSString *)viewer
{
    NSDictionary *settings = @{
        @"xml": xml,
        @"editable": @NO,
        @"toolbar": [NSNull null],
        @"resize": @YES,
        @"border": @8,
        @"zoom": @1,
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:settings
                                                   options:0 error:NULL];
    NSString *config = [[NSString alloc] initWithData:json
                                            encoding:NSUTF8StringEncoding];

    /* The attribute is set from JavaScript rather than written into the
     * HTML, and this is not fussiness.
     *
     * Written into an attribute, the text is read by the HTML parser first,
     * and draw.io writes `&quot;` inside its styles as a matter of course.
     * The parser turns each of those into a quotation mark, inside a JSON
     * string where a quotation mark ends the string: the JSON then fails to
     * parse, GraphViewer catches that and does nothing, and the page sits
     * there with no drawing and no complaint. Which is what a real diagram
     * did, for twenty seconds, while two guesses about why went wrong.
     *
     * As a JavaScript string literal there is no HTML parsing in the way at
     * all. `<` is written as an escape so that a label containing a closing
     * script tag cannot end the script.
     */
    NSData *quoted = [NSJSONSerialization dataWithJSONObject:config
        options:NSJSONWritingFragmentsAllowed error:NULL];
    NSString *literal = [[NSString alloc] initWithData:quoted
                                             encoding:NSUTF8StringEncoding];
    literal = [literal stringByReplacingOccurrencesOfString:@"<"
                                                 withString:@"\\u003C"];

    // What is in the bundle, and what is not. The libraries the viewer
    // loads are; MathJax is not — it is dozens of files loaded on demand,
    // and maths in a diagram is rare enough not to carry them for.
    NSDictionary *paths = @{
        @"STYLE_PATH": @"/styles",
        @"SHAPES_PATH": @"/shapes",
        @"STENCIL_PATH": @"/stencils",
        @"GRAPH_IMAGE_PATH": @"/img",
        @"mxImageBasePath": @"/mxgraph/images",
        @"mxBasePath": @"/mxgraph/",
    };
    NSMutableString *addresses = [NSMutableString stringWithString:
        @"window.PROXY_URL='';window.DRAW_MATH_URL='';"];
    for (NSString *name in paths)
    {
        [addresses appendFormat:@"window.%@='%@%@';",
            name, base, paths[name]];
    }
    [addresses appendString:@"window.mxLoadStylesheets=false;"];

    // Anything the viewer throws is kept where it can be asked for: a
    // drawing that never appears says nothing by itself, and the reason is
    // usually one line in a console nobody is watching.
    NSString *watch =
        @"window.__errors=[];"
        @"window.onerror=function(m,u,l){window.__errors.push(m+' ('+l+')');};"
        @"window.addEventListener('unhandledrejection',function(e){"
        @"window.__errors.push('promise: '+e.reason);});";

    return [NSString stringWithFormat:
        @"<!doctype html><html><head><meta charset=\"utf-8\">"
        @"<style>html,body{margin:0;padding:0;background:#fff}</style>"
        @"<script>%@%@</script></head><body>"
        @"<div class=\"mxgraph\" id=\"mdgraph\"></div>"
        @"<script>document.getElementById('mdgraph')"
        @".setAttribute('data-mxgraph', %@);</script>"
        @"<script>%@</script></body></html>",
        watch, addresses, literal, viewer];
}

- (void)renderPage:(MDDrawioPage *)page
             scale:(CGFloat)scale
        completion:(MDDrawioRenderHandler)handler
{
    if (!self.viewer.length)
    {
        handler(nil, [NSError errorWithDomain:MDDrawioErrorDomain
            code:MDDrawioErrorRenderFailed userInfo:@{
            NSLocalizedDescriptionKey: MDLocalizedString(
                @"The draw.io viewer is not in the plug-in: viewer.min.js is "
                @"missing.", @"Drawio plug-in")}]);
        return;
    }

    self.handler = handler;
    self.scale = scale;
    self.deadline = [NSDate dateWithTimeIntervalSinceNow:kMDRenderTimeout];

    // The page is served rather than handed over as a string, so that it
    // and the libraries share an origin: the viewer fetches some of them
    // by XHR, and a refusal there says nothing.
    self.resources = [[MDDrawioResources alloc]
        initWithBundle:self.bundle
                  page:[[self class] pageForXML:page.xml
                                           base:[MDDrawioResources base]
                                         viewer:self.viewer]];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.suppressesIncrementalRendering = YES;
    [config setURLSchemeHandler:self.resources
                   forURLScheme:[MDDrawioResources scheme]];

    self.webView = [[WKWebView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 1600.0, 1200.0)
        configuration:config];
    self.webView.navigationDelegate = self;

    [self.webView loadRequest:
        [NSURLRequest requestWithURL:[MDDrawioResources pageURL]]];
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation
{
    [self waitForDrawing];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self finishWithData:nil error:error];
}

/** Asks the page how big the drawing is, until there is one.
 *
 * The viewer builds the SVG after the document has loaded, so the end of
 * the navigation is not the end of the work. Its size is what is waited
 * for, since it is also what the picture has to be.
 */
- (void)waitForDrawing
{
    // Any SVG on the page, not only one under a div that still carries the
    // class: the viewer builds its own containers and what matters is that
    // something was drawn. The rest is for when nothing was.
    NSString *ask =
        @"JSON.stringify((function(){"
        @"var s=document.querySelector('svg');"
        @"var b=s?s.getBoundingClientRect():null;"
        @"return {w:b?Math.round(b.width):0,h:b?Math.round(b.height):0,"
        @" svgs:document.querySelectorAll('svg').length,"
        @" divs:document.querySelectorAll('.mxgraph').length,"
        @" body:document.body?document.body.scrollHeight:0,"
        @" errors:(window.__errors||[]).slice(0,4)};})())";

    [self.webView evaluateJavaScript:ask completionHandler:
        ^(id result, NSError *error) {
        NSData *json = [[result isKindOfClass:[NSString class]] ? result : @""
            dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *state = json.length
            ? [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL]
            : nil;

        CGFloat width = [state[@"w"] doubleValue];
        CGFloat height = [state[@"h"] doubleValue];
        if (width > 0.0 && height > 0.0)
        {
            [self snapshotWidth:width height:height];
            return;
        }
        if ([self.deadline timeIntervalSinceNow] <= 0.0)
        {
            [self finishWithData:nil error:
                [self gaveUpWithState:state pageError:error]];
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(kMDPollInterval * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ [self waitForDrawing]; });
    }];
}

/// What the page had to say for itself when the time ran out.
- (NSError *)gaveUpWithState:(NSDictionary *)state
                   pageError:(NSError *)pageError
{
    NSMutableString *said = [NSMutableString stringWithFormat:
        MDLocalizedString(@"The viewer drew nothing within %.0f seconds.",
                          @"Drawio plug-in"),
        kMDRenderTimeout];

    NSArray *errors = state[@"errors"];
    if ([errors isKindOfClass:[NSArray class]] && errors.count)
    {
        [said appendFormat:MDLocalizedString(@" The page said: %@",
                                             @"Drawio plug-in"),
            [errors componentsJoinedByString:@" / "]];
    }
    else if (pageError)
    {
        [said appendFormat:@" (%@)", pageError.localizedDescription];
    }
    else
    {
        // No complaint at all is itself the finding: the viewer was there
        // and drew nothing, which points at what it could not load.
        [said appendFormat:MDLocalizedString(
            @" No error from the page: %@ SVG, %@ containers, height %@.",
            @"Drawio plug-in"),
            state[@"svgs"] ?: @0, state[@"divs"] ?: @0, state[@"body"] ?: @0];
    }

    NSArray *missing = self.resources.failedPaths;
    if (missing.count)
    {
        [said appendFormat:MDLocalizedString(
            @" Not served: %@.", @"Drawio plug-in"),
            [missing componentsJoinedByString:@", "]];
    }

    return [NSError errorWithDomain:MDDrawioErrorDomain
        code:MDDrawioErrorRenderFailed userInfo:@{
        NSLocalizedDescriptionKey: said}];
}

- (void)snapshotWidth:(CGFloat)width height:(CGFloat)height
{
    // The view is made exactly as big as the drawing, so the picture has no
    // white margin round it beyond the border the viewer was given.
    self.webView.frame = NSMakeRect(0.0, 0.0, width, height);

    WKSnapshotConfiguration *config = [[WKSnapshotConfiguration alloc] init];
    config.snapshotWidth = @(width * self.scale);

    // One turn of the run loop after the resize, so what is captured is the
    // laid-out page rather than the one before it.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView takeSnapshotWithConfiguration:config
                                 completionHandler:^(NSImage *image,
                                                     NSError *error) {
            if (!image)
            {
                [self finishWithData:nil error:error ?:
                    [NSError errorWithDomain:MDDrawioErrorDomain
                        code:MDDrawioErrorRenderFailed userInfo:nil]];
                return;
            }
            CGImageRef cg = [image CGImageForProposedRect:NULL context:nil
                                                    hints:nil];
            NSBitmapImageRep *rep =
                [[NSBitmapImageRep alloc] initWithCGImage:cg];
            NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                            properties:@{}];
            [self finishWithData:png error:nil];
        }];
    });
}

- (void)finishWithData:(NSData *)png error:(NSError *)error
{
    MDDrawioRenderHandler handler = self.handler;
    self.handler = nil;
    self.webView.navigationDelegate = nil;
    self.webView = nil;
    if (handler)
        handler(png, error);
}


#pragma mark - An export server of your own

- (void)renderPage:(MDDrawioPage *)page
             scale:(CGFloat)scale
         onService:(NSURL *)service
        completion:(MDDrawioRenderHandler)handler
{
    NSCharacterSet *safe = [NSCharacterSet
        characterSetWithCharactersInString:@"-._~"];
    NSString *xml = [page.xml
        stringByAddingPercentEncodingWithAllowedCharacters:safe];
    NSString *body = [NSString stringWithFormat:
        @"format=png&scale=%g&xml=%@", scale, xml];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:service];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    request.timeoutInterval = 60.0;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request completionHandler:
        ^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                handler(nil, error);
                return;
            }
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            BOOL isPNG = data.length > 8
                && ((const unsigned char *)data.bytes)[1] == 'P';
            if (status != 200 || !isPNG)
            {
                // What the server said, rather than a code on its own: an
                // export server that refuses says why in the body.
                NSString *said = [[NSString alloc] initWithData:
                    [data subdataWithRange:NSMakeRange(0,
                        MIN((NSUInteger)200, data.length))]
                    encoding:NSUTF8StringEncoding];
                handler(nil, [NSError errorWithDomain:MDDrawioErrorDomain
                    code:MDDrawioErrorServiceRefused userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        MDLocalizedString(@"The server answered %ld%@",
                                          @"Drawio plug-in"),
                        (long)status, said.length
                            ? [@": " stringByAppendingString:said] : @"."]}]);
                return;
            }
            handler(data, nil);
        });
    }];
    [task resume];
}

@end
