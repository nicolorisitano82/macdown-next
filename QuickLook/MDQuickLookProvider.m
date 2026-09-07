//
//  MDQuickLookProvider.m
//  MacDown QuickLook
//

#import "MDQuickLookProvider.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/log.h>

#import "MDDiagramRenderer.h"
#import "MDPreviewPage.h"
#import "MDQuickLookStrings.h"

#include "document.h"
#include "html.h"


/// How much of a document to draw. A preview is a glance: past this the rest
/// is left out and the page says so, rather than keeping Finder waiting.
static const NSUInteger kMDMarkdownAtMost = 2 * 1024 * 1024;

/// The size Finder is asked to open the preview at.
static const CGSize kMDPreviewSize = (CGSize){800.0, 1000.0};

/// How long the diagrams may take, all of them together. Quick Look is
/// waiting, and a preview that arrives late has not arrived; past this the
/// fences that are left stay as source, which is what they were before.
static const NSTimeInterval kMDDrawingBudget = 2.5;

/// How many diagrams a glance is worth drawing, and how long one may be.
/// A document with fifty diagrams in it is not a document being glanced at.
static const NSUInteger kMDDiagramsAtMost = 8;
static const NSUInteger kMDDiagramSourceAtMost = 16 * 1024;

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
    NSError *error = nil;
    NSString *markdown = [self markdownAt:fileURL error:&error];
    if (!markdown)
    {
        os_log_error(OS_LOG_DEFAULT, "MacDown preview: not read, %{public}@",
                     error.localizedDescription ?: @"no reason given");
        handler(nil, error);
        return;
    }

    // The Markdown is turned into HTML here rather than inside the reply's
    // block, because the diagrams in it have to be drawn before there is a
    // page to hand over, and drawing them takes a web view and a moment.
    NSString *body = MDBodyForMarkdown(MDMarkdownWithoutFrontMatter(markdown));
    NSArray<MDDiagramFence *> *fences = [self drawableFencesIn:body];
    if (!fences.count)
    {
        handler([self replyForBody:body markdown:markdown documentAt:fileURL],
                nil);
        return;
    }

    NSMutableArray<NSString *> *sources =
        [NSMutableArray arrayWithCapacity:fences.count];
    for (MDDiagramFence *fence in fences)
        [sources addObject:fence.source];

    NSURL *mermaid = [[NSBundle bundleForClass:[self class]]
        URLForResource:@"mermaid.min" withExtension:@"js"];
    [MDDiagramRenderer drawSources:sources
                     mermaidScript:mermaid
                            within:kMDDrawingBudget
                        completion:^(NSArray *drawings) {
        NSString *drawn = MDHTMLByDrawingFences(body, fences, drawings);
        handler([self replyForBody:drawn markdown:markdown documentAt:fileURL],
                nil);
    }];
}


/// The fences worth drawing: the first few, and none of them enormous.
- (NSArray<MDDiagramFence *> *)drawableFencesIn:(NSString *)body
{
    NSMutableArray<MDDiagramFence *> *wanted = [NSMutableArray array];
    for (MDDiagramFence *fence in MDDiagramFencesInHTML(body))
    {
        if (fence.source.length > kMDDiagramSourceAtMost)
            continue;               // left as source, and honestly so
        [wanted addObject:fence];
        if (wanted.count >= kMDDiagramsAtMost)
            break;
    }
    return wanted;
}


/// The reply for a page that is ready to be built.
- (QLPreviewReply *)replyForBody:(NSString *)body
                        markdown:(NSString *)markdown
                      documentAt:(NSURL *)fileURL
{
    return [[QLPreviewReply alloc]
        initWithDataOfContentType:UTTypeHTML
                      contentSize:kMDPreviewSize
                dataCreationBlock:^NSData *(QLPreviewReply *reply,
                                            NSError **error) {
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
