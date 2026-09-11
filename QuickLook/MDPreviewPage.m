//
//  MDPreviewPage.m
//  MacDown QuickLook
//

#import "MDPreviewPage.h"
#import "MDQuickLookStrings.h"


/// The biggest picture worth attaching, and the most to attach in all.
/// A Finder preview is a glance, not a reading room, and everything sent
/// travels through the extension's reply.
static const unsigned long long kMDOnePictureAtMost = 8ULL * 1024 * 1024;
static const unsigned long long kMDAllPicturesAtMost = 24ULL * 1024 * 1024;

/// What the page needs beyond the document's own style sheet: the styles are
/// written for the app's preview, which is always light, and Quick Look would
/// otherwise put dark chrome behind them.
static NSString * const kMDPageStyle =
    @"html { color-scheme: light; }\n"
    @"body { background-color: white; }\n"
    @"img { max-width: 100%; height: auto; }\n"
    @"pre { overflow-x: auto; }\n"
    @"li.task { list-style: none; margin-left: -1.2em; }\n"
    @"li.task > input { margin-right: 0.4em; vertical-align: baseline; }\n"
    // A drawn diagram is SVG in the page rather than a picture in the
    // reply, so it needs telling that it may not be wider than the column.
    @".macdown-diagram { margin: 1em 0; text-align: center; }\n"
    @".macdown-diagram svg { max-width: 100%; height: auto; }\n";


NS_INLINE NSString *MDTrimmed(NSString *line)
{
    NSCharacterSet *blank = [NSCharacterSet whitespaceCharacterSet];
    return [line stringByTrimmingCharactersInSet:blank];
}

NS_INLINE BOOL MDAllOf(NSString *line, unichar wanted)
{
    if (line.length < 2)
        return NO;
    for (NSUInteger i = 0; i < line.length; i++)
    {
        if ([line characterAtIndex:i] != wanted)
            return NO;
    }
    return YES;
}

NS_INLINE NSString *MDEscaped(NSString *text)
{
    NSMutableString *escaped = [text mutableCopy];
    [escaped replaceOccurrencesOfString:@"&" withString:@"&amp;"
        options:0 range:NSMakeRange(0, escaped.length)];
    for (NSArray *pair in @[@[@"<", @"&lt;"], @[@">", @"&gt;"]])
    {
        [escaped replaceOccurrencesOfString:pair[0] withString:pair[1]
            options:0 range:NSMakeRange(0, escaped.length)];
    }
    return escaped;
}


/// Whether a line reads as a front matter entry: `title: qualcosa`.
NS_INLINE BOOL MDLooksLikeAnEntry(NSString *line)
{
    static NSRegularExpression *entry = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entry = [NSRegularExpression regularExpressionWithPattern:
            @"^[A-Za-z_][A-Za-z0-9_. -]*:(\\s|$)" options:0 error:NULL];
    });
    return [entry numberOfMatchesInString:line options:0
                                    range:NSMakeRange(0, line.length)] > 0;
}


/// Where the document itself begins: past the front matter, if any.
///
/// A document may just as well open with a horizontal rule, so a rule alone
/// is not enough: what follows it has to read as front matter.
static NSUInteger MDStartOfDocument(NSArray<NSString *> *lines)
{
    if (lines.count < 2 || ![MDTrimmed(lines[0]) isEqualToString:@"---"])
        return 0;
    if (!MDLooksLikeAnEntry(MDTrimmed(lines[1])))
        return 0;

    NSUInteger end = 1;
    while (end < lines.count && !MDAllOf(MDTrimmed(lines[end]), '-')
           && ![MDTrimmed(lines[end]) isEqualToString:@"..."])
        end++;
    // Never closed: it was not front matter after all, so keep it all.
    return end < lines.count ? end + 1 : 0;
}


NSString *MDMarkdownWithoutFrontMatter(NSString *markdown)
{
    if (!markdown.length)
        return markdown ?: @"";

    NSArray *lines = [markdown componentsSeparatedByString:@"\n"];
    NSUInteger start = MDStartOfDocument(lines);
    if (!start)
        return markdown;
    return [[lines subarrayWithRange:
        NSMakeRange(start, lines.count - start)] componentsJoinedByString:@"\n"];
}


NSString *MDPreviewTitleForMarkdown(NSString *markdown, NSURL *fileURL)
{
    NSString *name = fileURL.lastPathComponent.stringByDeletingPathExtension;
    if (!name)
        name = @"";
    if (!markdown.length)
        return name;

    NSArray *lines = [markdown componentsSeparatedByCharactersInSet:
        [NSCharacterSet newlineCharacterSet]];
    NSUInteger i = MDStartOfDocument(lines);

    for (; i < lines.count; i++)
    {
        NSString *line = MDTrimmed(lines[i]);
        if (!line.length)
            continue;
        // A rule says nothing; the title may well be just under it.
        if (MDAllOf(line, '-') || MDAllOf(line, '*') || MDAllOf(line, '_'))
            continue;

        if ([line hasPrefix:@"#"])
        {
            NSUInteger hashes = 0;
            while (hashes < line.length && [line characterAtIndex:hashes] == '#')
                hashes++;
            // `#tag` is a word, not a heading: a heading has a space after
            // its hashes, which is what the app's own renderer insists on.
            if (hashes <= 6 && hashes < line.length
                && [line characterAtIndex:hashes] == ' ')
            {
                NSCharacterSet *edge = [NSCharacterSet
                    characterSetWithCharactersInString:@"# \t"];
                NSString *heading =
                    [line stringByTrimmingCharactersInSet:edge];
                if (heading.length)
                    return heading;
            }
            break;
        }

        // The other way of writing a heading: underlined with = or -.
        if (i + 1 < lines.count)
        {
            NSString *next = MDTrimmed(lines[i + 1]);
            if (MDAllOf(next, '=') || MDAllOf(next, '-'))
                return line;
        }
        break;      // The document opens with prose: it has no title.
    }
    return name;
}


/// The file a picture's address stands for, if it is a file we may send and
/// small enough to be worth sending. Anything on the network is left alone.
static NSURL *MDPictureFile(NSString *src, NSURL *folder,
                            unsigned long long *budget)
{
    if (!src.length || !folder)
        return nil;

    NSURL *address = [NSURL URLWithString:src];
    if (address.scheme.length && ![address.scheme isEqualToString:@"file"])
        return nil;

    NSString *path = address.isFileURL ? address.path : nil;
    if (!path)
        path = [src stringByRemovingPercentEncoding] ?: src;
    if (!path.length)
        return nil;

    NSURL *file = path.isAbsolutePath ? [NSURL fileURLWithPath:path]
                                      : [folder URLByAppendingPathComponent:path];
    file = file.URLByStandardizingPath;

    NSNumber *size = nil;
    if (![file getResourceValue:&size forKey:NSURLFileSizeKey error:NULL])
        return nil;
    unsigned long long bytes = size.unsignedLongLongValue;
    if (!bytes || bytes > kMDOnePictureAtMost || bytes > *budget)
        return nil;

    // Being able to see the file is not the same as being allowed to read
    // it: in Finder the preview runs in a sandbox. A picture that cannot be
    // read is left addressed as the document wrote it, rather than pointed
    // at an attachment that will never arrive.
    NSFileHandle *open = [NSFileHandle fileHandleForReadingFromURL:file
                                                             error:NULL];
    if (!open)
        return nil;
    [open closeFile];

    *budget -= bytes;
    return file;
}


#pragma mark - WikiLinks

/// Whether a WikiLink target resolves to a file next to the document.
///
/// The name as written first, then the extensions a Markdown document is
/// likely to carry — the same order the application uses when it follows
/// one.
static BOOL MDWikiTargetExists(NSURL *directory, NSString *target)
{
    if (!directory.isFileURL || !target.length)
        return NO;

    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *base = [directory URLByAppendingPathComponent:target];
    if ([manager fileExistsAtPath:base.path])
        return YES;

    for (NSString *extension in @[@"md", @"markdown", @"txt"])
    {
        NSURL *candidate = [base URLByAppendingPathExtension:extension];
        if ([manager fileExistsAtPath:candidate.path])
            return YES;
    }
    return NO;
}


static NSRegularExpression *MDContentsParagraph(void)
{
    static NSRegularExpression *paragraph = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        paragraph = [[NSRegularExpression alloc] initWithPattern:
            @"<p[^>]*>\\s*\\[TOC\\]\\s*</p>"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return paragraph;
}


BOOL MDBodyAsksForContents(NSString *bodyHTML)
{
    if (!bodyHTML.length)
        return NO;
    return [MDContentsParagraph() firstMatchInString:bodyHTML options:0
        range:NSMakeRange(0, bodyHTML.length)] != nil;
}


int MDContentsDepth(void)
{
    return 6;
}


NSString *MDBodyWithContents(NSString *bodyHTML, NSString *contents)
{
    if (!bodyHTML.length)
        return bodyHTML ?: @"";
    // A template, so a `$1` inside a heading does not become something else
    // on the way in.
    NSString *safe = [NSRegularExpression
        escapedTemplateForString:contents ?: @""];
    return [MDContentsParagraph() stringByReplacingMatchesInString:bodyHTML
        options:0 range:NSMakeRange(0, bodyHTML.length) withTemplate:safe];
}


NSString *MDBodyWithWikiLinks(NSString *bodyHTML, NSURL *documentURL)
{
    if (![bodyHTML containsString:@"[["])
        return bodyHTML ?: @"";

    static NSRegularExpression *wiki = nil;
    static NSRegularExpression *code = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        wiki = [NSRegularExpression regularExpressionWithPattern:
            @"\\[\\[([^\\[\\]|]+)(?:\\|([^\\[\\]]+))?\\]\\]"
                                                        options:0 error:NULL];
        code = [NSRegularExpression regularExpressionWithPattern:
            @"<pre[\\s\\S]*?</pre>|<code[\\s\\S]*?</code>"
                    options:NSRegularExpressionCaseInsensitive error:NULL];
    });

    NSRange whole = NSMakeRange(0, bodyHTML.length);
    NSArray<NSTextCheckingResult *> *links =
        [wiki matchesInString:bodyHTML options:0 range:whole];
    if (!links.count)
        return bodyHTML;

    NSArray<NSTextCheckingResult *> *spans =
        [code matchesInString:bodyHTML options:0 range:whole];
    NSURL *directory = documentURL.URLByDeletingLastPathComponent;
    NSCharacterSet *spaces = [NSCharacterSet whitespaceCharacterSet];
    NSMutableString *out = [bodyHTML mutableCopy];

    // Back to front, so each replacement leaves the earlier ranges valid.
    for (NSInteger i = (NSInteger)links.count - 1; i >= 0; i--)
    {
        NSTextCheckingResult *link = links[(NSUInteger)i];

        BOOL insideCode = NO;
        for (NSTextCheckingResult *span in spans)
        {
            if (NSIntersectionRange(span.range, link.range).length)
            {
                insideCode = YES;
                break;
            }
        }
        if (insideCode)
            continue;

        NSString *target = [[bodyHTML substringWithRange:
            [link rangeAtIndex:1]] stringByTrimmingCharactersInSet:spaces];
        if (!target.length)
            continue;

        NSRange labelRange = [link rangeAtIndex:2];
        NSString *label = labelRange.location == NSNotFound ? target
            : [[bodyHTML substringWithRange:labelRange]
                stringByTrimmingCharactersInSet:spaces];

        // The href carries no extension, as the application's does not.
        // Nothing here follows it — a preview does not navigate — and a
        // link that reads the way the document wrote it is the point.
        NSString *href = [target stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLPathAllowedCharacterSet]] ?: target;

        NSString *replacement;
        if (MDWikiTargetExists(directory, target))
        {
            replacement = [NSString stringWithFormat:
                @"<a href=\"%@\" class=\"wikilink\">%@</a>",
                MDEscaped(href), label];
        }
        else
        {
            replacement = [NSString stringWithFormat:
                @"<a href=\"%@\" class=\"wikilink wikilink-missing\" "
                @"title=\"%@\">%@</a>", MDEscaped(href),
                MDEscaped(MDQLLocalizedString(@"This page does not exist yet",
                    @"tooltip on a WikiLink whose target is missing")),
                label];
        }
        [out replaceCharactersInRange:link.range withString:replacement];
    }
    return out;
}


@implementation MDPreviewPage

+ (instancetype)pageForBody:(NSString *)bodyHTML
                      title:(NSString *)title
                 styleSheet:(NSString *)styleSheet
                 documentAt:(NSURL *)fileURL
{
    MDPreviewPage *page = [[self alloc] init];
    NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
    NSString *body = [self bodyWithTaskBoxes:bodyHTML ?: @""];
    body = [self body:body withPicturesNamedIn:pictures
           besideDocument:fileURL];

    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<!DOCTYPE html>\n<html>\n<head>\n"];
    [html appendString:@"<meta charset=\"utf-8\">\n"];
    // Selecting a file in Finder is enough to draw this page, so the page is
    // not allowed to reach anywhere: no scripts, and pictures only from what
    // the reply itself carries. A document that tries to fetch something
    // from the network simply does not get it.
    [html appendString:@"<meta http-equiv=\"Content-Security-Policy\" "
        @"content=\"default-src 'none'; img-src cid:; "
        @"style-src 'unsafe-inline'\">\n"];
    [html appendFormat:@"<title>%@</title>\n", MDEscaped(title ?: @"")];
    [html appendString:@"<style>\n"];
    if (styleSheet.length)
        [html appendFormat:@"%@\n", styleSheet];
    [html appendString:kMDPageStyle];
    [html appendString:@"</style>\n</head>\n<body>\n"];
    [html appendString:body];
    [html appendString:@"\n</body>\n</html>\n"];

    page->_html = [html copy];
    page->_pictures = [pictures copy];
    return page;
}


/// `- [ ] fare la spesa` reaches here as a list item that opens with the
/// brackets, because the renderer leaves them as written. Finder should show
/// what the document means: a box, ticked or not.
+ (NSString *)bodyWithTaskBoxes:(NSString *)body
{
    static NSRegularExpression *tasks = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tasks = [NSRegularExpression regularExpressionWithPattern:
            @"<li[^>]*>(<p>)?\\[([ xX])\\]\\s" options:0 error:NULL];
    });

    NSMutableString *marked = [body mutableCopy];
    NSArray *matches = [tasks matchesInString:body options:0
                                        range:NSMakeRange(0, body.length)];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator)
    {
        NSRange paragraph = [match rangeAtIndex:1];
        NSString *state = [body substringWithRange:[match rangeAtIndex:2]];
        BOOL done = ![state isEqualToString:@" "];
        NSMutableString *item = [NSMutableString stringWithString:
            @"<li class=\"task\">"];
        if (paragraph.location != NSNotFound)
            [item appendString:@"<p>"];
        [item appendFormat:@"<input type=\"checkbox\" disabled%@> ",
            done ? @" checked" : @""];
        [marked replaceCharactersInRange:match.range withString:item];
    }
    return marked;
}


/// Pictures kept next to the document have to travel with the reply, so each
/// one is given a name the page can ask for.
+ (NSString *)body:(NSString *)body
    withPicturesNamedIn:(NSMutableDictionary<NSString *, NSURL *> *)pictures
         besideDocument:(NSURL *)fileURL
{
    NSURL *folder = fileURL.URLByDeletingLastPathComponent;
    if (!folder)
        return body;

    static NSRegularExpression *sources = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sources = [NSRegularExpression regularExpressionWithPattern:
            @"<img\\b[^>]*?\\bsrc\\s*=\\s*\"([^\"]*)\"" options:0 error:NULL];
    });

    NSArray *matches = [sources matchesInString:body options:0
                                          range:NSMakeRange(0, body.length)];
    unsigned long long budget = kMDAllPicturesAtMost;

    // Named in the order they are read, so the pictures at the top of the
    // document are the ones that get the room.
    NSMutableArray *found = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches)
    {
        NSRange src = [match rangeAtIndex:1];
        NSURL *file = MDPictureFile([body substringWithRange:src], folder,
                                    &budget);
        if (!file)
            continue;
        NSString *name = [NSString stringWithFormat:@"pict%lu",
            (unsigned long)pictures.count];
        pictures[name] = file;
        [found addObject:@[[NSValue valueWithRange:src], name]];
    }

    // Replaced from the end, so that no replacement moves the next range.
    NSMutableString *named = [body mutableCopy];
    for (NSArray *picture in found.reverseObjectEnumerator)
    {
        NSString *cid = [@"cid:" stringByAppendingString:picture[1]];
        [named replaceCharactersInRange:[picture[0] rangeValue]
                             withString:cid];
    }
    return named;
}

@end
/// Nothing but a name to ask NSBundle about.
@interface MDPreviewPageBundleMarker : NSObject
@end

@implementation MDPreviewPageBundleMarker
@end


NSBundle *MDQuickLookBundle(void)
{
    // A class from this file, so the answer is the bundle the code came in
    // whether that is the extension or the suite's harness.
    return [NSBundle bundleForClass:[MDPreviewPageBundleMarker class]];
}

