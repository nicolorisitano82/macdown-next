//
//  selection_probe.m
//  MacDown
//
//  The whole path between the two panes, outside XCTest.
//
//  The unit tests drive the page script with hand-written HTML and the
//  mapping with hand-written source. This takes a real Markdown file,
//  renders it with the real renderer, loads the real script into a real web
//  view, makes a real selection in it — and then asks the real mapping what
//  the editor would have selected. What is left out is only the glue in
//  MPDocument; everything the two panes say to each other is here.
//
//  Build:  clang -fobjc-arc -framework Cocoa -framework WebKit \
//              -IMacDown/Code/Utility -IDependency/hoedown/src \
//              -o selection_probe Tools/selection_probe.m \
//              MacDown/Code/Utility/MPPreviewSelection.m \
//              Dependency/hoedown/src/*.c
//
//  Use:    selection_probe <file.md> pick <text> [occurrence]
//          selection_probe <file.md> show <text> <source offset>
//
//  "pick" selects those words in the page and says what the editor would
//  select; "show" is the other direction — the editor has a selection and
//  the page is asked to mark it.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "MPPreviewSelection.h"

#include "document.h"
#include "html.h"


/// The same reading of Markdown the preview asks for. Smartypants is a
/// pass over the finished HTML rather than a renderer flag, and what it
/// changes is covered by the unit tests; what this is for is the path
/// between the two panes.
static const int kMPExtensions =
    HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE | HOEDOWN_EXT_FOOTNOTES |
    HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_QUOTE |
    HOEDOWN_EXT_NO_INTRA_EMPHASIS | HOEDOWN_EXT_SPACE_HEADERS;


static NSString *MPBody(NSString *markdown)
{
    NSData *utf8 = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 0);
    hoedown_document *document = hoedown_document_new(renderer,
                                                      kMPExtensions, 16);
    hoedown_buffer *out = hoedown_buffer_new(64);
    hoedown_document_render(document, out, utf8.bytes, utf8.length);
    NSString *body = [[NSString alloc] initWithBytes:out->data
                                              length:out->size
                                            encoding:NSUTF8StringEncoding];
    hoedown_buffer_free(out);
    hoedown_document_free(document);
    hoedown_html_renderer_free(renderer);
    return body ?: @"";
}


/// Selects the nth time those words appear in the page, and lets go of the
/// mouse: the same two events a reader makes.
static NSString *MPSelectionScript(NSString *text, NSUInteger occurrence)
{
    NSData *quoted = [NSJSONSerialization dataWithJSONObject:text
        options:NSJSONWritingFragmentsAllowed error:NULL];
    NSString *literal = [[NSString alloc] initWithData:quoted
                                              encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:
        @"(function(){"
        @"var wanted=%@,which=%lu;"
        @"var walker=document.createTreeWalker(document.body,"
        @"NodeFilter.SHOW_TEXT);"
        @"var nodes=[],starts=[],whole='',n;"
        @"while((n=walker.nextNode())){"
        @"nodes.push(n);starts.push(whole.length);whole+=n.data;}"
        @"var at=-1;"
        @"for(var k=0;k<which;k++)at=whole.indexOf(wanted,at+1);"
        @"if(at<0)return 'quelle parole non sono nella pagina';"
        @"function where(i){"
        @"for(var j=nodes.length-1;j>=0;j--)"
        @"if(starts[j]<=i)return [nodes[j],i-starts[j]];"
        @"return [nodes[0],0];}"
        @"var a=where(at),b=where(at+wanted.length-1);"
        @"var range=document.createRange();"
        @"range.setStart(a[0],a[1]);range.setEnd(b[0],b[1]+1);"
        @"var sel=document.getSelection();"
        @"sel.removeAllRanges();sel.addRange(range);"
        @"a[0].parentElement.dispatchEvent("
        @"new MouseEvent('mouseup',{bubbles:true}));"
        @"return 'ok';})()", literal, (unsigned long)occurrence];
}


@interface MPProbe : NSObject <WKScriptMessageHandler>
@property (copy) NSString *markdown;
@property (copy) void (^onReport)(NSDictionary *body);
@end

@implementation MPProbe

- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSDictionary *body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]
            || ![body[@"done"] boolValue])
        return;
    if (self.onReport)
        self.onReport(body);
}

@end


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 4)
        {
            fprintf(stderr, "uso: %s <file.md> pick|show <testo> [numero]\n",
                    argv[0]);
            return 2;
        }
        [NSApplication sharedApplication];

        NSString *path = @(argv[1]);
        NSString *what = @(argv[2]);
        NSString *text = @(argv[3]);
        NSUInteger number = argc > 4 ? (NSUInteger)atoi(argv[4]) : 1;

        NSString *markdown = [NSString stringWithContentsOfFile:path
            encoding:NSUTF8StringEncoding error:NULL];
        if (!markdown)
        {
            fprintf(stderr, "non letto: %s\n", argv[1]);
            return 3;
        }

        if ([what isEqualToString:@"show"] && argc <= 4)
        {
            // Where those words are in the source, since that is what the
            // editor would be telling the page.
            NSRange where = [markdown rangeOfString:text];
            number = where.location == NSNotFound ? 0 : where.location;
        }

        MPProbe *probe = [[MPProbe alloc] init];
        probe.markdown = markdown;

        WKWebViewConfiguration *configuration =
            [[WKWebViewConfiguration alloc] init];
        [configuration.userContentController
            addScriptMessageHandler:probe name:@"macdownSelection"];
        [configuration.userContentController addUserScript:
            [[WKUserScript alloc] initWithSource:MPSelectionWatchScript()
                injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
             forMainFrameOnly:YES]];
        WKWebView *webView = [[WKWebView alloc]
            initWithFrame:NSMakeRect(0.0, 0.0, 800.0, 600.0)
            configuration:configuration];

        __block BOOL finished = NO;
        __block int status = 1;
        probe.onReport = ^(NSDictionary *body) {
            if (finished)
                return;
            finished = YES;

            NSInteger begin = [body[@"begin"] integerValue];
            NSInteger end = [body[@"end"] integerValue];
            NSInteger offset = [body[@"offset"] integerValue];
            NSString *picked = body[@"text"];
            NSUInteger length = markdown.length;
            NSRange block = NSMakeRange(begin < 0 ? 0 : (NSUInteger)begin,
                0);
            block.length = (end < 0 || (NSUInteger)end > length)
                ? length - block.location
                : (NSUInteger)end - block.location;

            NSRange found = MPSourceRangeForPreviewText(markdown, picked,
                block, offset < 0 ? NSNotFound : (NSUInteger)offset);
            printf("pagina: «%s»\n", picked.UTF8String);
            printf("blocco: %ld…%ld, dentro il blocco: %ld\n",
                   (long)begin, (long)end, (long)offset);
            if (found.location == NSNotFound)
            {
                printf("sorgente: non piazzata\n");
                status = 1;
            }
            else
            {
                printf("sorgente: «%s» a %lu\n",
                       [markdown substringWithRange:found].UTF8String,
                       (unsigned long)found.location);
                status = 0;
            }
        };

        NSString *page = [NSString stringWithFormat:
            @"<html><head><meta charset=\"utf-8\"></head><body>%@</body>"
            @"</html>", MPBody(markdown)];
        [webView loadHTMLString:page baseURL:nil];

        // The page has to be there before it can be asked anything, and it
        // says so by defining what the script defines.
        __block BOOL asked = NO;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:15.0];
        while (!finished && [deadline timeIntervalSinceNow] > 0.0)
        {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            if (asked)
                continue;
            [webView evaluateJavaScript:@"typeof window.MacDownMarkHere"
                      completionHandler:^(id result, NSError *error) {
                if (asked || ![result isEqual:@"function"])
                    return;
                asked = YES;
                if ([what isEqualToString:@"show"])
                {
                    // The other direction: the editor has a selection and
                    // the page is asked to mark it.
                    NSString *shown = MPPreviewTextForSource(text);
                    NSData *quoted = [NSJSONSerialization
                        dataWithJSONObject:shown
                                   options:NSJSONWritingFragmentsAllowed
                                     error:NULL];
                    NSString *literal = [[NSString alloc]
                        initWithData:quoted encoding:NSUTF8StringEncoding];
                    NSString *js = [NSString stringWithFormat:
                        @"(function(){"
                        @"if(!MacDownShowPicked(%@,%lu))return 'non trovata';"
                        @"var h=CSS.highlights.get('macdown-picked');"
                        @"return h.values().next().value.toString();})()",
                        literal, (unsigned long)number];
                    [webView evaluateJavaScript:js
                              completionHandler:^(id r, NSError *e) {
                        printf("editor: «%s»\n", shown.UTF8String);
                        printf("pagina: «%s»\n",
                               [r isKindOfClass:[NSString class]]
                               ? [r UTF8String] : "(niente)");
                        status = [r isKindOfClass:[NSString class]]
                            && ![r isEqualToString:@"non trovata"] ? 0 : 1;
                        finished = YES;
                    }];
                    return;
                }
                [webView evaluateJavaScript:MPSelectionScript(text, number)
                          completionHandler:^(id r, NSError *e) {
                    if ([r isKindOfClass:[NSString class]]
                            && ![r isEqualToString:@"ok"])
                    {
                        printf("%s\n", [r UTF8String]);
                        finished = YES;
                    }
                }];
            }];
        }
        if (!finished)
        {
            printf("nessuna risposta dalla pagina\n");
            return 4;
        }
        return status;
    }
}
