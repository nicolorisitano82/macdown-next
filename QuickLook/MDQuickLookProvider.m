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

/// How many drawings a glance is worth, and how long one may be. A document
/// with two hundred formulas in it is not a document being glanced at.
static const NSUInteger kMDDrawingsAtMost = 40;
static const NSUInteger kMDDrawingSourceAtMost = 16 * 1024;

/// The same reading of Markdown the app's own preview uses, minus the parts
/// that need something loaded from the network to show at all.
static const int kMDExtensions =
    HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE | HOEDOWN_EXT_FOOTNOTES |
    HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_HIGHLIGHT |
    HOEDOWN_EXT_QUOTE | HOEDOWN_EXT_SUPERSCRIPT |
    HOEDOWN_EXT_NO_INTRA_EMPHASIS | HOEDOWN_EXT_SPACE_HEADERS;

static const size_t kMDNestingAtMost = 16;


/// Which maths the reader has asked for, as hoedown flags.
///
/// `$$…$$` costs nothing when a document has no formulas in it, so maths is
/// on unless the application says otherwise. A *single* dollar is another
/// matter: it turns "costa $5 e la scatola $7" into algebra — measured — so
/// it follows the application's own switch, which is off until turned on.
/// A pure function, because the two answers come from preferences and the
/// rule they feed should be readable on its own.
int MDMathExtensionsFor(NSNumber *maths, NSNumber *inlineDollar)
{
    if (maths && !maths.boolValue)
        return 0;
    int flags = HOEDOWN_EXT_MATH;
    if (inlineDollar.boolValue)
        flags |= HOEDOWN_EXT_MATH_EXPLICIT;
    return flags;
}


/// Markdown turned into HTML, the body only.
static NSString *MDBodyForMarkdown(NSString *markdown, int extensions)
{
    NSData *utf8 = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    if (!utf8.length)
        return @"";

    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 0);
    hoedown_document *document = hoedown_document_new(
        renderer, kMDExtensions | extensions, kMDNestingAtMost);
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
    NSString *body = MDBodyForMarkdown(MDMarkdownWithoutFrontMatter(markdown),
                                       [self mathExtensions]);
    if ([self wikiLinksWanted])
        body = MDBodyWithWikiLinks(body, fileURL);
    NSArray<MDDrawingJob *> *jobs = [self drawableJobsIn:body];
    if (!jobs.count)
    {
        handler([self replyForBody:body markdown:markdown documentAt:fileURL
                        styleSheet:nil], nil);
        return;
    }

    [MDDiagramRenderer drawJobs:jobs
                      resources:[self drawingLibraries]
                         within:kMDDrawingBudget
                     completion:^(NSArray *drawings, NSString *styles) {
        NSString *drawn = MDHTMLByDrawingJobs(body, jobs, drawings);
        handler([self replyForBody:drawn markdown:markdown documentAt:fileURL
                        styleSheet:styles], nil);
    }];
}


/// The drawings worth making: the first few, and none of them enormous.
- (NSArray<MDDrawingJob *> *)drawableJobsIn:(NSString *)body
{
    NSMutableArray<MDDrawingJob *> *wanted = [NSMutableArray array];
    for (MDDrawingJob *job in MDDrawingJobsInHTML(body))
    {
        if (job.source.length > kMDDrawingSourceAtMost)
            continue;               // left as source, and honestly so
        [wanted addObject:job];
        if (wanted.count >= kMDDrawingsAtMost)
            break;
    }
    return wanted;
}


/// The maths the application it belongs to has been told to show.
///
/// The extension's own identifier is the application's with `.quicklook`
/// added, so the domain to read is the identifier without that suffix. The
/// entitlement names both — release and debug — and allows nothing but
/// reading them.
- (int)mathExtensions
{
    NSNumber *maths = [self preference:@"htmlMathJax"];
    NSNumber *dollars = [self preference:@"htmlMathJaxInlineDollar"];
    int flags = MDMathExtensionsFor(maths, dollars);
    os_log(OS_LOG_DEFAULT, "maths: %{public}@ says %@ / %@, so flags %d",
           [self applicationDomain], maths ?: @"(nothing)",
           dollars ?: @"(nothing)", flags);
    return flags;
}


/// Whether WikiLinks are links here, as they are in the application.
///
/// On unless the application says otherwise, which is the application's own
/// default: `[[Verbale]]` is written to be a link, and showing the brackets
/// in Finder while the editor shows a link would be two answers to one
/// question.
- (BOOL)wikiLinksWanted
{
    NSNumber *wanted = [self preference:@"htmlWikiLinks"];
    return wanted ? wanted.boolValue : YES;
}


/// The preferences domain of the application this extension belongs to.
///
/// The extension's own identifier is the application's with `.quicklook`
/// added, so the domain to read is the identifier without that suffix. The
/// entitlement names both — release and debug — and allows nothing but
/// reading them.
- (NSString *)applicationDomain
{
    NSString *identifier =
        [NSBundle bundleForClass:[self class]].bundleIdentifier ?: @"";
    return [identifier hasSuffix:@".quicklook"]
        ? [identifier substringToIndex:identifier.length
                                       - @".quicklook".length]
        : identifier;
}


- (NSNumber *)preference:(NSString *)key
{
    id value = (__bridge_transfer id)CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key,
        (__bridge CFStringRef)[self applicationDomain]);
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}


/// mermaid, Graphviz and MathJax, as this bundle carries them.
- (NSDictionary<NSString *, NSURL *> *)drawingLibraries
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSMutableDictionary<NSString *, NSURL *> *libraries =
        [NSMutableDictionary dictionary];
    NSDictionary<NSString *, NSString *> *files = @{
        MDMermaidResource: @"mermaid.min",
        MDGraphvizResource: @"viz",
        MDMathResource: @"tex-svg",
    };
    for (NSString *name in files)
    {
        NSURL *url = [bundle URLForResource:files[name] withExtension:@"js"];
        if (url)
            libraries[name] = url;
    }
    return libraries;
}


/// The reply for a page that is ready to be built.
- (QLPreviewReply *)replyForBody:(NSString *)body
                        markdown:(NSString *)markdown
                      documentAt:(NSURL *)fileURL
                      styleSheet:(NSString *)extra
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
                            styleSheet:[self styleSheetWith:extra]
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
- (NSString *)styleSheetWith:(NSString *)extra
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSMutableString *sheet = [NSMutableString string];
    // The preview style the application opens with, then the rules for the
    // things it draws itself. Read from the bundle rather than copied into
    // the code, so there is one copy of each to keep right.
    for (NSString *name in @[@"GitHub2", @"wikilink"])
    {
        NSURL *css = [bundle URLForResource:name withExtension:@"css"];
        NSString *text = css
            ? [NSString stringWithContentsOfURL:css
                                       encoding:NSUTF8StringEncoding
                                          error:NULL]
            : nil;
        if (text.length)
            [sheet appendFormat:@"%@\n", text];
    }
    if (!extra.length)
        return sheet;
    // MathJax's own rules, which say how a formula sits on the line. They
    // come from the web view that typeset it, so the page needs no script to
    // get them right.
    return [NSString stringWithFormat:@"%@%@", sheet, extra];
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
