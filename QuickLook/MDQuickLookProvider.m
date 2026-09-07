//
//  MDQuickLookProvider.m
//  MacDown QuickLook
//

#import "MDQuickLookProvider.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "MDPreviewPage.h"
#import "MDQuickLookStrings.h"

#include "document.h"
#include "html.h"


/// How much of a document to draw. A preview is a glance: past this the rest
/// is left out and the page says so, rather than keeping Finder waiting.
static const NSUInteger kMDMarkdownAtMost = 2 * 1024 * 1024;

/// The size Finder is asked to open the preview at.
static const CGSize kMDPreviewSize = (CGSize){800.0, 1000.0};

/// The same reading of Markdown the app's own preview uses, minus the parts
/// that need something loaded from the network to show at all.
static const int kMDExtensions =
    HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE | HOEDOWN_EXT_FOOTNOTES |
    HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_HIGHLIGHT |
    HOEDOWN_EXT_QUOTE | HOEDOWN_EXT_SUPERSCRIPT |
    HOEDOWN_EXT_NO_INTRA_EMPHASIS | HOEDOWN_EXT_SPACE_HEADERS;

static const size_t kMDNestingAtMost = 16;


/// Markdown turned into HTML, the body only.
static NSString *MDBodyForMarkdown(NSString *markdown)
{
    NSData *utf8 = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    if (!utf8.length)
        return @"";

    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 0);
    hoedown_document *document = hoedown_document_new(
        renderer, kMDExtensions, kMDNestingAtMost);
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


@implementation MDQuickLookProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *, NSError *))handler
{
    NSURL *fileURL = request.fileURL;
    QLPreviewReply *reply = [[QLPreviewReply alloc]
        initWithDataOfContentType:UTTypeHTML
                      contentSize:kMDPreviewSize
                dataCreationBlock:^NSData *(QLPreviewReply *reply,
                                            NSError **error) {
        NSString *markdown = [self markdownAt:fileURL error:error];
        if (!markdown)
            return nil;

        NSString *body =
            MDBodyForMarkdown(MDMarkdownWithoutFrontMatter(markdown));
        MDPreviewPage *page =
            [MDPreviewPage pageForBody:body
                                 title:MDPreviewTitleForMarkdown(markdown,
                                                                 fileURL)
                            styleSheet:[self styleSheet]
                            documentAt:fileURL];
        reply.attachments = [self attachmentsFor:page.pictures];
        reply.stringEncoding = NSUTF8StringEncoding;
        return [page.html dataUsingEncoding:NSUTF8StringEncoding];
    }];
    handler(reply, nil);
}


/// The document as text, however it happens to be encoded, and cut short if
/// it is far too long to glance at.
- (NSString *)markdownAt:(NSURL *)fileURL error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:error];
    if (!data)
        return nil;

    BOOL whole = data.length <= kMDMarkdownAtMost;
    if (!whole)
        data = [data subdataWithRange:NSMakeRange(0, kMDMarkdownAtMost)];

    NSString *markdown = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];
    if (!markdown)
    {
        // Not UTF-8: read it the way TextEdit would rather than give up.
        markdown = [[NSString alloc] initWithData:data
            encoding:NSISOLatin1StringEncoding] ?: @"";
    }
    if (!whole)
    {
        // A cut in the middle of a line is better admitted than hidden.
        markdown = [markdown stringByAppendingString:
            MDQLLocalizedString(
                @"\n\n---\n\n*The document is too long: only the beginning "
                @"is shown here.*\n",
                @"Admitting that the preview is cut short")];
    }
    return markdown;
}


/// The style the app's own preview opens with, so a file looks the same in
/// Finder as it does once it is open.
- (NSString *)styleSheet
{
    NSURL *css = [[NSBundle bundleForClass:[self class]]
        URLForResource:@"GitHub2" withExtension:@"css"];
    if (!css)
        return nil;
    return [NSString stringWithContentsOfURL:css encoding:NSUTF8StringEncoding
                                       error:NULL];
}


/// Quick Look draws the page with no access to the disk, so every picture it
/// asks for by name has to be handed over with the reply.
- (NSDictionary<NSString *, QLPreviewReplyAttachment *> *)
    attachmentsFor:(NSDictionary<NSString *, NSURL *> *)pictures
{
    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    for (NSString *name in pictures)
    {
        NSURL *file = pictures[name];
        NSData *data = [NSData dataWithContentsOfURL:file];
        if (!data.length)
            continue;

        UTType *type = nil;
        [file getResourceValue:&type forKey:NSURLContentTypeKey error:NULL];
        if (!type)
            type = [UTType typeWithFilenameExtension:file.pathExtension];
        if (!type)
            continue;

        attachments[name] = [[QLPreviewReplyAttachment alloc]
            initWithData:data contentType:type];
    }
    return attachments;
}

@end
