//
//  quicklook_page.m
//  MacDown
//
//  Prints the page the Quick Look extension would hand Finder for a
//  document, so that a check can read it without going through Quick Look.
//  The extension itself runs out of process, in a sandbox, on the system's
//  own schedule; this builds the very same page from the very same code.
//
//  Used by Tools/verify_features.sh. Build:
//
//      clang -fobjc-arc -framework Foundation \
//            -IQuickLook -IDependency/hoedown/src \
//            -o quicklook_page Tools/quicklook_page.m \
//            QuickLook/MDPreviewPage.m Dependency/hoedown/src/*.c
//
//  Usage: quicklook_page <document.md> [style.css] [--pictures]
//

#import <Foundation/Foundation.h>

#import "MDPreviewPage.h"

#include "document.h"
#include "html.h"


/// The same reading of Markdown MDQuickLookProvider asks for.
static const int kMDExtensions =
    HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE | HOEDOWN_EXT_FOOTNOTES |
    HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_HIGHLIGHT |
    HOEDOWN_EXT_QUOTE | HOEDOWN_EXT_SUPERSCRIPT |
    HOEDOWN_EXT_NO_INTRA_EMPHASIS | HOEDOWN_EXT_SPACE_HEADERS |
    // Maths the unambiguous way. The extension also honours the
    // application's switch for a single dollar; there is no application
    // here, so this is the default half of that answer.
    HOEDOWN_EXT_MATH;


static NSString *MDBody(NSString *markdown)
{
    NSData *utf8 = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 0);
    hoedown_document *document =
        hoedown_document_new(renderer, kMDExtensions, 16);
    hoedown_buffer *out = hoedown_buffer_new(64);
    hoedown_document_render(document, out, utf8.bytes, utf8.length);
    NSString *body = [[NSString alloc] initWithBytes:out->data
                                             length:out->size
                                           encoding:NSUTF8StringEncoding];
    hoedown_buffer_free(out);
    hoedown_document_free(document);
    hoedown_html_renderer_free(renderer);
    body = body ?: @"";

    // The table of contents, the same way the extension does it: a second
    // pass with another renderer, and only when the document asked.
    if (MDBodyAsksForContents(body))
    {
        hoedown_renderer *toc =
            hoedown_html_toc_renderer_new(MDContentsDepth());
        hoedown_document *second =
            hoedown_document_new(toc, kMDExtensions, 16);
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


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 2)
        {
            fputs("usage: quicklook_page <document.md> [style.css] "
                  "[--pictures]\n", stderr);
            return 2;
        }

        BOOL listPictures = NO;
        NSString *stylePath = nil;
        for (int i = 2; i < argc; i++)
        {
            if (strcmp(argv[i], "--pictures") == 0)
                listPictures = YES;
            else
                stylePath = @(argv[i]);
        }

        NSURL *file = [NSURL fileURLWithPath:@(argv[1])];
        NSString *markdown = [NSString stringWithContentsOfURL:file
            encoding:NSUTF8StringEncoding error:NULL];
        if (!markdown)
        {
            fprintf(stderr, "non si legge: %s\n", argv[1]);
            return 1;
        }

        NSString *style = nil;
        if (stylePath)
        {
            style = [NSString stringWithContentsOfFile:stylePath
                encoding:NSUTF8StringEncoding error:NULL];
            if (!style)
            {
                fprintf(stderr, "stile non letto: %s\n",
                        stylePath.UTF8String);
                return 1;
            }
        }

        NSString *body = MDBody(MDMarkdownWithoutFrontMatter(markdown));
        // What the extension does before it draws anything: the diagrams
        // need a web view and cannot come this way, the WikiLinks can.
        body = MDBodyWithWikiLinks(body, file);
        MDPreviewPage *page = [MDPreviewPage pageForBody:body
            title:MDPreviewTitleForMarkdown(markdown, file)
            styleSheet:style documentAt:file];

        if (listPictures)
        {
            // One line per attachment: the name the page asks for, and the
            // file that would travel under it.
            NSArray *names = [page.pictures.allKeys sortedArrayUsingSelector:
                @selector(compare:)];
            for (NSString *name in names)
            {
                printf("%s\t%s\n", name.UTF8String,
                       page.pictures[name].path.UTF8String);
            }
        }
        else
        {
            fputs(page.html.UTF8String, stdout);
        }
    }
    return 0;
}
