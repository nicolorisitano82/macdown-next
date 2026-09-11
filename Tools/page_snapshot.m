//
//  Tools/page_snapshot.m — an HTML page drawn into a PNG, off screen.
//
//      page_snapshot <page.html> <out.png> [width] [height]
//      page_snapshot --preview <doc.md> <out.png> [width] [height]
//
//  With `--preview` it builds the page the way the extension does — body,
//  wiki links, diagrams and formulas drawn into SVG — and then draws that.
//
//  For the pictures on the site: the page the Finder preview is handed,
//  drawn by the same WebKit that draws it there, into a file. Nothing is
//  captured from anybody's screen — the page is loaded into a web view that
//  is never shown and asked for its own snapshot, which is why the result
//  is the product rather than a photograph of somebody's desktop.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "MDDiagramRenderer.h"
#import "MDPreviewPage.h"
#import "html.h"
#import "document.h"


static const int kMDExtensions =
    HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE | HOEDOWN_EXT_FOOTNOTES |
    HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_HIGHLIGHT |
    HOEDOWN_EXT_QUOTE | HOEDOWN_EXT_SUPERSCRIPT |
    HOEDOWN_EXT_NO_INTRA_EMPHASIS | HOEDOWN_EXT_SPACE_HEADERS |
    HOEDOWN_EXT_MATH;


/// The body, the way the extension makes it — including the table of
/// contents, which is a second pass.
static NSString *MDDemoBody(NSString *markdown)
{
    NSData *utf8 = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 0);
    hoedown_document *document =
        hoedown_document_new(renderer, kMDExtensions, 16);
    hoedown_buffer *out = hoedown_buffer_new(64);
    hoedown_document_render(document, out, utf8.bytes, utf8.length);
    NSString *body = [[NSString alloc] initWithBytes:out->data length:out->size
                                            encoding:NSUTF8StringEncoding];
    hoedown_buffer_free(out);
    hoedown_document_free(document);
    hoedown_html_renderer_free(renderer);
    body = body ?: @"";

    if (MDBodyAsksForContents(body))
    {
        hoedown_renderer *toc =
            hoedown_html_toc_renderer_new(MDContentsDepth());
        hoedown_document *second = hoedown_document_new(toc, kMDExtensions, 16);
        hoedown_buffer *list = hoedown_buffer_new(64);
        hoedown_document_render(second, list, utf8.bytes, utf8.length);
        NSString *contents = [[NSString alloc] initWithBytes:list->data
                                                      length:list->size
                                                    encoding:NSUTF8StringEncoding];
        hoedown_buffer_free(list);
        hoedown_document_free(second);
        hoedown_html_renderer_free(toc);
        body = MDBodyWithContents(body, contents);
    }
    return body;
}


/// Where the drawing libraries are, in the built extension.
static NSDictionary<NSString *, NSURL *> *MDDemoLibraries(NSString *appex)
{
    NSMutableDictionary *libraries = [NSMutableDictionary dictionary];
    NSDictionary *files = @{MDMermaidResource: @"mermaid.min",
                            MDGraphvizResource: @"viz",
                            MDMathResource: @"tex-svg"};
    for (NSString *name in files)
    {
        NSString *path = [NSString stringWithFormat:@"%@/Contents/Resources/%@.js",
                          appex, files[name]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            libraries[name] = [NSURL fileURLWithPath:path];
    }
    return libraries;
}


@interface MDSnapshot : NSObject <WKNavigationDelegate>
@property (nonatomic) WKWebView *web;
@property (nonatomic, copy) NSURL *out;
@property (nonatomic) BOOL done;
@end


@implementation MDSnapshot

- (void)webView:(WKWebView *)web didFinishNavigation:(WKNavigation *)nav
{
    // A moment for the fonts and the layout to settle: a snapshot taken in
    // the same turn as the load is a page half drawn.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WKSnapshotConfiguration *how = [[WKSnapshotConfiguration alloc] init];
        how.afterScreenUpdates = YES;
        [web takeSnapshotWithConfiguration:how
                         completionHandler:^(NSImage *image, NSError *error) {
            if (image)
            {
                CGImageRef cg = [image CGImageForProposedRect:NULL context:nil
                                                        hints:nil];
                NSBitmapImageRep *rep =
                    [[NSBitmapImageRep alloc] initWithCGImage:cg];
                NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                                properties:@{}];
                [png writeToURL:self.out atomically:YES];
                printf("scritto %s (%.0f × %.0f)\n", self.out.path.UTF8String,
                       image.size.width, image.size.height);
            }
            else
            {
                fprintf(stderr, "niente immagine: %s\n",
                        error.localizedDescription.UTF8String ?: "?");
            }
            self.done = YES;
        }];
    });
}

@end


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        BOOL building = (argc > 1 && strcmp(argv[1], "--preview") == 0);
        int first = building ? 2 : 1;
        if (argc < first + 2)
        {
            fprintf(stderr, "uso: page_snapshot [--preview] <in> <out.png> "
                            "[larghezza] [altezza]\n");
            return 2;
        }
        CGFloat width = (argc > first + 2) ? atof(argv[first + 2]) : 900.0;
        CGFloat height = (argc > first + 3) ? atof(argv[first + 3]) : 1200.0;

        [NSApplication sharedApplication];
        MDSnapshot *shot = [[MDSnapshot alloc] init];
        shot.out = [NSURL fileURLWithPath:@(argv[first + 1])];

        WKWebViewConfiguration *configuration =
            [[WKWebViewConfiguration alloc] init];
        shot.web = [[WKWebView alloc] initWithFrame:
            NSMakeRect(0.0, 0.0, width, height) configuration:configuration];
        shot.web.navigationDelegate = shot;

        NSURL *page = [NSURL fileURLWithPath:@(argv[first])];
        NSString *html = nil;

        if (!building)
        {
            html = [NSString stringWithContentsOfURL:page
                encoding:NSUTF8StringEncoding error:NULL];
        }
        else
        {
            // The whole of what the extension does, so that the picture is
            // the product and not an impression of it.
            NSString *markdown = [NSString stringWithContentsOfURL:page
                encoding:NSUTF8StringEncoding error:NULL];
            NSString *body = MDDemoBody(
                MDMarkdownWithoutFrontMatter(markdown ?: @""));
            body = MDBodyWithWikiLinks(body, page);

            NSString *appex = @(getenv("MD_APPEX") ?: "");
            NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(body);
            if (jobs.count && appex.length)
            {
                __block NSString *drawn = body;
                __block NSString *extra = nil;
                __block BOOL waiting = YES;
                [MDDiagramRenderer drawJobs:jobs
                                  resources:MDDemoLibraries(appex)
                                     within:8.0
                                 completion:^(NSArray *drawings,
                                              NSString *styles) {
                    drawn = MDHTMLByDrawingJobs(body, jobs, drawings);
                    extra = styles;
                    waiting = NO;
                }];
                NSDate *until = [NSDate dateWithTimeIntervalSinceNow:20.0];
                while (waiting && [until timeIntervalSinceNow] > 0.0)
                {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                        beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                }
                body = drawn;
                if (extra.length)
                    body = [NSString stringWithFormat:@"<style>%@</style>%@",
                            extra, body];
            }

            NSString *style = [NSString stringWithContentsOfFile:
                @"MacDown/Resources/Styles/GitHub2.css"
                encoding:NSUTF8StringEncoding error:NULL];
            MDPreviewPage *built = [MDPreviewPage pageForBody:body
                title:MDPreviewTitleForMarkdown(markdown, page)
                styleSheet:style documentAt:page];
            html = built.html;
        }

        if (!html)
        {
            fprintf(stderr, "non si legge: %s\n", argv[first]);
            return 3;
        }
        if (building)
        {
            [shot.web loadHTMLString:html
                             baseURL:page.URLByDeletingLastPathComponent];
        }
        else
        {
            // From the file itself, with read access to the folder around
            // it: a page loaded as a string cannot reach its own pictures.
            [shot.web loadFileURL:page
          allowingReadAccessToURL:page.URLByDeletingLastPathComponent];
        }


        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:30.0];
        while (!shot.done && [until timeIntervalSinceNow] > 0.0)
        {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        }
        return shot.done ? 0 : 4;
    }
}
