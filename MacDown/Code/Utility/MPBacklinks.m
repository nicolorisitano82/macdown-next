//
//  MPBacklinks.m
//  MacDown
//

#import "MPBacklinks.h"
#import "MPMarkdownText.h"

/// Big enough for any document written by a person.
static const unsigned long long kMPBacklinkFileSizeLimit = 4 * 1024 * 1024;
/// A stop, so a folder that turns out to be a whole disk cannot hang this.
static const NSUInteger kMPBacklinkFileLimit = 20000;


@implementation MPBacklink

- (instancetype)initWithDocumentURL:(NSURL *)documentURL
                              title:(NSString *)title
                               line:(NSUInteger)line
                            context:(NSString *)context
                              range:(NSRange)range
{
    self = [super init];
    if (!self)
        return nil;
    _documentURL = [documentURL copy];
    _title = [title copy] ?: @"";
    _line = line;
    _context = [context copy] ?: @"";
    _range = range;
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@:%lu>", self.class,
            self.documentURL.lastPathComponent, (unsigned long)self.line];
}

@end


NSString *MPFirstHeadingOfText(NSString *text)
{
    static NSRegularExpression *heading = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        heading = [[NSRegularExpression alloc]
            initWithPattern:@"^[ \\t]*#{1,6}[ \\t]+(\\S.*?)[ \\t]*#*[ \\t]*$"
                    options:NSRegularExpressionAnchorsMatchLines error:NULL];
    });

    NSTextCheckingResult *first = [heading firstMatchInString:text ?: @""
        options:0 range:NSMakeRange(0, text.length)];
    if (!first)
        return nil;
    return [text substringWithRange:[first rangeAtIndex:1]];
}


#pragma mark - What is not a citation


NS_INLINE BOOL MPRangeIsInsideAny(NSRange range, NSArray<NSValue *> *ranges)
{
    for (NSValue *value in ranges)
    {
        if (NSIntersectionRange(value.rangeValue, range).length)
            return YES;
    }
    return NO;
}


#pragma mark - What a destination points at

/** One spelling for a path, whether or not the file is there.
 *
 * `stringByStandardizingPath` takes `/private` off a temporary folder only
 * when what is left names something that exists, so `…/verbale.md` came out
 * `/var/…` and `…/verbale` — the extensionless half of a WikiLink — came
 * out `/private/var/…`, and the two never matched. Resolving the folder,
 * which does exist, and leaving the name alone gives one spelling for both.
 */
NS_INLINE NSString *MPCanonicalPath(NSString *path)
{
    NSString *tidy = path.stringByStandardizingPath;
    NSString *folder = tidy.stringByDeletingLastPathComponent
        .stringByResolvingSymlinksInPath;
    if (!folder.length)
        return tidy;
    return [folder stringByAppendingPathComponent:tidy.lastPathComponent];
}

/// The path a link destination stands for, resolved and tidied, or nil.
static NSString *MPResolvedPath(NSString *destination, NSURL *folder)
{
    NSString *target = [destination stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!target.length || !folder)
        return nil;

    // `<a b.md>` is how a destination with spaces is written.
    if ([target hasPrefix:@"<"] && [target hasSuffix:@">"])
        target = [target substringWithRange:NSMakeRange(1, target.length - 2)];

    // A title after the destination: `(path "il verbale")`.
    NSRange quote = [target rangeOfString:@" \""];
    if (quote.location != NSNotFound)
        target = [target substringToIndex:quote.location];
    // An anchor or a query is not part of the file's name.
    for (NSString *cut in @[@"#", @"?"])
    {
        NSRange found = [target rangeOfString:cut];
        if (found.location != NSNotFound)
            target = [target substringToIndex:found.location];
    }
    target = [target stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if (!target.length)
        return nil;

    // Somewhere else entirely: a web address, a mail address, a scheme of
    // its own. `file:` is the exception, since it does name a file.
    NSRange scheme = [target rangeOfString:@":"];
    if (scheme.location != NSNotFound
            && [target rangeOfString:@"/"].location > scheme.location)
    {
        if (![target.lowercaseString hasPrefix:@"file:"])
            return nil;
        NSURL *url = [NSURL URLWithString:target];
        return url.isFileURL ? MPCanonicalPath(url.path) : nil;
    }

    // `%20` and a space are the same file.
    NSString *decoded = target.stringByRemovingPercentEncoding ?: target;

    NSURL *resolved = [target hasPrefix:@"/"]
        ? [NSURL fileURLWithPath:decoded]
        : [folder URLByAppendingPathComponent:decoded];
    return MPCanonicalPath(resolved.path);
}


NSArray<MPBacklink *> *MPBacklinksInText(NSString *text, NSURL *from,
                                        NSURL *target)
{
    if (!text.length || !from.isFileURL || !target.isFileURL)
        return @[];

    NSString *wanted = MPCanonicalPath(target.path);
    NSURL *folder = from.URLByDeletingLastPathComponent;
    // A document that cites itself is not a backlink.
    if ([MPCanonicalPath(from.path) isEqualToString:wanted])
        return @[];

    static NSRegularExpression *links = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        // `[[Target]]` or `[[Target|label]]`, and the destination of a
        // Markdown link or image.
        links = [[NSRegularExpression alloc] initWithPattern:
            @"\\[\\[([^\\[\\]|]+)(?:\\|[^\\[\\]]*)?\\]\\]"
            @"|\\]\\(([^()\\n]*(?:\\([^()\\n]*\\)[^()\\n]*)*)\\)"
                                                    options:0 error:NULL];
    });

    NSArray<NSValue *> *code = MPMarkdownCodeRanges(text);
    NSString *title = MPFirstHeadingOfText(text)
        ?: from.lastPathComponent.stringByDeletingPathExtension;

    NSMutableArray *found = [NSMutableArray array];
    for (NSTextCheckingResult *match in [links matchesInString:text options:0
            range:NSMakeRange(0, text.length)])
    {
        if (MPRangeIsInsideAny(match.range, code))
            continue;

        BOOL isWiki = [match rangeAtIndex:1].location != NSNotFound;
        NSRange inside = isWiki ? [match rangeAtIndex:1]
                                : [match rangeAtIndex:2];
        if (inside.location == NSNotFound)
            continue;

        NSString *destination = [text substringWithRange:inside];
        NSString *path = MPResolvedPath(destination, folder);
        if (!path)
            continue;

        BOOL hit = [path isEqualToString:wanted];
        if (!hit && isWiki)
        {
            // A WikiLink carries no extension, and MacDown tries these in
            // this order when it follows one.
            for (NSString *extension in @[@"md", @"markdown", @"txt"])
            {
                NSString *candidate =
                    [path stringByAppendingPathExtension:extension];
                if ([candidate isEqualToString:wanted])
                {
                    hit = YES;
                    break;
                }
            }
        }
        if (!hit)
            continue;

        NSUInteger lineStart = 0, lineEnd = 0, contentsEnd = 0;
        [text getLineStart:&lineStart end:&lineEnd contentsEnd:&contentsEnd
                  forRange:match.range];
        NSString *context = [[text substringWithRange:
            NSMakeRange(lineStart, contentsEnd - lineStart)]
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];

        [found addObject:[[MPBacklink alloc] initWithDocumentURL:from
            title:title
             line:MPLineNumberForLocation(text, match.range.location)
          context:context
            range:match.range]];
    }
    return [found copy];
}


#pragma mark - Looking through a folder

@implementation MPBacklinkFinder

+ (NSArray<NSString *> *)readableExtensions
{
    return @[@"md", @"markdown", @"mdown", @"mkd", @"txt", @"text"];
}

+ (void)findLinksTo:(NSURL *)target
           inFolder:(NSURL *)folder
         completion:(void (^)(NSArray<MPBacklink *> *, NSUInteger))done
{
    if (!target.isFileURL || !folder.isFileURL)
    {
        if (done)
            done(@[], 0);
        return;
    }

    dispatch_async(dispatch_get_global_queue(
        DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *found = [NSMutableArray array];
        NSUInteger read = 0;

        NSArray *keys = @[NSURLIsDirectoryKey, NSURLIsRegularFileKey,
                          NSURLFileSizeKey, NSURLIsHiddenKey,
                          NSURLIsPackageKey];
        NSDirectoryEnumerator *walk = [[NSFileManager defaultManager]
            enumeratorAtURL:folder includingPropertiesForKeys:keys
                    options:NSDirectoryEnumerationSkipsHiddenFiles
                          | NSDirectoryEnumerationSkipsPackageDescendants
               errorHandler:NULL];

        NSSet *extensions = [NSSet setWithArray:[self readableExtensions]];
        for (NSURL *url in walk)
        {
            if (read >= kMPBacklinkFileLimit)
                break;

            NSNumber *regular = nil;
            [url getResourceValue:&regular forKey:NSURLIsRegularFileKey
                            error:NULL];
            if (!regular.boolValue)
                continue;
            if (![extensions containsObject:url.pathExtension.lowercaseString])
                continue;

            NSNumber *size = nil;
            [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
            if (size.unsignedLongLongValue > kMPBacklinkFileSizeLimit)
                continue;

            NSString *text = [NSString stringWithContentsOfURL:url
                encoding:NSUTF8StringEncoding error:NULL];
            if (!text.length)
                continue;
            read++;

            [found addObjectsFromArray:
                MPBacklinksInText(text, url, target)];
        }

        // By document, then by line: the order somebody reads a list in.
        [found sortUsingComparator:^NSComparisonResult(MPBacklink *a,
                                                       MPBacklink *b) {
            NSComparisonResult byName = [a.documentURL.lastPathComponent
                localizedStandardCompare:b.documentURL.lastPathComponent];
            if (byName != NSOrderedSame)
                return byName;
            if (a.line != b.line)
                return a.line < b.line ? NSOrderedAscending
                                       : NSOrderedDescending;
            return NSOrderedSame;
        }];

        NSUInteger counted = read;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done)
                done([found copy], counted);
        });
    });
}

@end
