//
//  MPTextBundle.m
//  MacDown
//

#import "MPTextBundle.h"

#import "MPUtilities.h"
#import "MPZipArchive.h"


/// The names the format fixes, and the ones it leaves to us.
static NSString * const kMPTextBundleTextName = @"text.markdown";
static NSString * const kMPTextBundleAssets = @"assets";

/// What a picture is, when deciding whether a link points at one. Read from
/// the file system rather than from the name where possible; the name is the
/// fallback, and this is that list.
static NSSet<NSString *> *MPPictureExtensions(void)
{
    static NSSet *extensions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        extensions = [NSSet setWithArray:@[
            @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"tif", @"bmp",
            @"heic", @"webp", @"svg", @"pdf", @"avif",
        ]];
    });
    return extensions;
}


@interface MPTextBundleAsset ()
@property (copy, nonatomic) NSURL *fileURL;
@property (copy, nonatomic) NSString *name;
@end

@implementation MPTextBundleAsset
@end


#pragma mark - Reading the markdown

/// Every image destination in the markdown, and where it is written.
///
/// Both ways a picture is written: `![alt](destination)` and the definition
/// a reference points at, `[label]: destination`. What is inside code is
/// left alone — a fence explaining how to write an image is not one.
static NSArray<NSTextCheckingResult *> *MPImageDestinations(NSString *markdown)
{
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            // ![alt](destination "title")   destination may be in <>
            @"!\\[[^\\]]*\\]\\(\\s*(?:<([^>]*)>|([^\\s\\)]+))"
            @"(?:\\s+\"[^\"]*\")?\\s*\\)"
            // [label]: destination "title"
            @"|^[ \\t]{0,3}\\[[^\\]]+\\]:[ \\t]*(?:<([^>]*)>|(\\S+))"
                                                          options:
            NSRegularExpressionAnchorsMatchLines error:NULL];
    });
    NSArray<NSValue *> *code = MPMarkdownCodeRanges(markdown);
    NSMutableArray<NSTextCheckingResult *> *found = [NSMutableArray array];
    for (NSTextCheckingResult *match in
         [regex matchesInString:markdown options:0
                         range:NSMakeRange(0, markdown.length)])
    {
        BOOL insideCode = NO;
        for (NSValue *value in code)
        {
            if (NSIntersectionRange(value.rangeValue, match.range).length)
            {
                insideCode = YES;
                break;
            }
        }
        if (!insideCode)
            [found addObject:match];
    }
    return found;
}


/// The destination of that match, and its range, whichever way it was
/// written.
static NSRange MPDestinationRange(NSTextCheckingResult *match)
{
    for (NSUInteger group = 1; group <= 4; group++)
    {
        NSRange range = [match rangeAtIndex:group];
        if (range.location != NSNotFound)
            return range;
    }
    return NSMakeRange(NSNotFound, 0);
}


/// Whether that destination is an address rather than a file.
static BOOL MPIsRemote(NSString *destination)
{
    NSString *lower = destination.lowercaseString;
    return [lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]
        || [lower hasPrefix:@"data:"] || [lower hasPrefix:@"//"];
}


/// The file a destination means, or nil when it means nothing local.
static NSURL *MPFileForDestination(NSString *destination, NSURL *documentURL)
{
    if (!destination.length || MPIsRemote(destination))
        return nil;
    if ([destination hasPrefix:@"#"])
        return nil;             // an anchor in this document

    NSString *path = [destination stringByRemovingPercentEncoding]
        ?: destination;
    NSURL *file = [path hasPrefix:@"/"]
        ? [NSURL fileURLWithPath:path]
        : [NSURL URLWithString:
               [path stringByAddingPercentEncodingWithAllowedCharacters:
                   [NSCharacterSet URLPathAllowedCharacterSet]] ?: path
           relativeToURL:documentURL];
    file = file.URLByStandardizingPath.absoluteURL;
    if (!file.isFileURL)
        return nil;

    NSNumber *directory = nil;
    if (![file getResourceValue:&directory forKey:NSURLIsDirectoryKey
                          error:NULL] || directory.boolValue)
        return nil;               // not there, or not a file

    // A picture, and not the neighbouring document a link points at: a
    // textbundle holds one text, so the other documents stay where they are.
    return [MPPictureExtensions() containsObject:
            file.pathExtension.lowercaseString] ? file : nil;
}


NSArray<NSString *> *MPTextBundleRemoteImages(NSString *markdown)
{
    NSMutableArray<NSString *> *addresses = [NSMutableArray array];
    for (NSTextCheckingResult *match in MPImageDestinations(markdown))
    {
        NSRange range = MPDestinationRange(match);
        if (range.location == NSNotFound)
            continue;
        NSString *destination = [markdown substringWithRange:range];
        if (MPIsRemote(destination)
                && ![addresses containsObject:destination])
            [addresses addObject:destination];
    }
    return addresses;
}


NSString *MPTextBundleMarkdown(
    NSString *markdown, NSURL *documentURL,
    NSArray<MPTextBundleAsset *> * __autoreleasing *assets)
{
    NSMutableArray<MPTextBundleAsset *> *found = [NSMutableArray array];
    if (assets)
        *assets = found;
    if (!markdown.length)
        return markdown ?: @"";

    NSArray<NSTextCheckingResult *> *matches = MPImageDestinations(markdown);
    if (!matches.count)
        return markdown;

    // One asset per file, whatever it is called where it lives now, and one
    // name per asset: two folders can both hold a rete.png.
    NSMutableDictionary<NSString *, MPTextBundleAsset *> *byPath =
        [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *taken = [NSMutableSet set];
    NSMutableString *out = [markdown mutableCopy];

    // Back to front, so each replacement leaves the earlier ranges valid.
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator)
    {
        NSRange range = MPDestinationRange(match);
        if (range.location == NSNotFound)
            continue;
        NSString *destination = [markdown substringWithRange:range];
        NSURL *file = MPFileForDestination(destination, documentURL);
        if (!file)
            continue;

        MPTextBundleAsset *asset = byPath[file.path];
        if (!asset)
        {
            NSString *name = file.lastPathComponent;
            NSString *stem = name.stringByDeletingPathExtension;
            NSString *extension = name.pathExtension;
            NSUInteger attempt = 2;
            while ([taken containsObject:name.lowercaseString])
            {
                name = extension.length
                    ? [NSString stringWithFormat:@"%@-%lu.%@", stem,
                       (unsigned long)attempt++, extension]
                    : [NSString stringWithFormat:@"%@-%lu", stem,
                       (unsigned long)attempt++];
            }
            [taken addObject:name.lowercaseString];

            asset = [[MPTextBundleAsset alloc] init];
            asset.fileURL = file;
            asset.name = name;
            byPath[file.path] = asset;
            [found insertObject:asset atIndex:0];   // first written, first
        }

        // The link is written the way a link is written: percent-encoded
        // where it has to be, so a name with a space in it still resolves.
        NSString *encoded = [asset.name
            stringByAddingPercentEncodingWithAllowedCharacters:
                [NSCharacterSet URLPathAllowedCharacterSet]] ?: asset.name;
        [out replaceCharactersInRange:range withString:
            [NSString stringWithFormat:@"%@/%@", kMPTextBundleAssets,
             encoded]];
    }

    if (assets)
        *assets = found;
    return out;
}


#pragma mark - Writing it out

NSData *MPTextBundleInfo(NSString *creatorIdentifier, NSString *creatorURL)
{
    NSMutableDictionary *info = [@{
        @"version": @2,
        // The type of the *text*, which is what the specification asks for.
        @"type": @"net.daringfireball.markdown",
        // Not a hand-off from a share sheet: this is a file somebody asked
        // to keep.
        @"transient": @NO,
    } mutableCopy];
    if (creatorIdentifier.length)
        info[@"creatorIdentifier"] = creatorIdentifier;
    if (creatorURL.length)
        info[@"creatorURL"] = creatorURL;

    NSData *json = [NSJSONSerialization dataWithJSONObject:info
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
          error:NULL];
    // A file somebody may open in an editor ends with a newline.
    NSMutableData *out = [json mutableCopy];
    [out appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    return out;
}


NSData *MPTextPackData(NSString *bundleName, NSString *markdown,
                       NSData *info, NSArray<MPTextBundleAsset *> *assets)
{
    if (!bundleName.length)
        return nil;

    NSMutableArray<MPZipEntry *> *entries = [NSMutableArray array];
    [entries addObject:MPStoredEntry(
        [bundleName stringByAppendingPathComponent:@"info.json"], info)];
    [entries addObject:MPStoredEntry(
        [bundleName stringByAppendingPathComponent:kMPTextBundleTextName],
        [markdown dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data])];

    for (MPTextBundleAsset *asset in assets)
    {
        NSData *data = [NSData dataWithContentsOfURL:asset.fileURL];
        if (!data)
            continue;           // gone since it was written: nothing to add
        NSString *name = [[bundleName
            stringByAppendingPathComponent:kMPTextBundleAssets]
            stringByAppendingPathComponent:asset.name];
        [entries addObject:MPStoredEntry(name, data)];
    }
    return MPZipWrite(entries);
}


BOOL MPWriteTextBundle(NSURL *bundleURL, NSString *markdown, NSData *info,
                       NSArray<MPTextBundleAsset *> *assets, NSError **error)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    // Overwriting a bundle means replacing it: leaving the pictures of a
    // previous export inside would be a package that lies about itself.
    if ([manager fileExistsAtPath:bundleURL.path]
            && ![manager removeItemAtURL:bundleURL error:error])
        return NO;
    if (![manager createDirectoryAtURL:bundleURL
           withIntermediateDirectories:YES attributes:nil error:error])
        return NO;

    if (![info writeToURL:[bundleURL URLByAppendingPathComponent:@"info.json"]
                  options:NSDataWritingAtomic error:error])
        return NO;
    if (![markdown writeToURL:[bundleURL URLByAppendingPathComponent:
                                   kMPTextBundleTextName]
                   atomically:YES encoding:NSUTF8StringEncoding error:error])
        return NO;
    if (!assets.count)
        return YES;

    NSURL *folder = [bundleURL
        URLByAppendingPathComponent:kMPTextBundleAssets isDirectory:YES];
    if (![manager createDirectoryAtURL:folder
           withIntermediateDirectories:YES attributes:nil error:error])
        return NO;
    for (MPTextBundleAsset *asset in assets)
    {
        NSURL *destination = [folder
            URLByAppendingPathComponent:asset.name];
        NSError *copyError = nil;
        if (![manager copyItemAtURL:asset.fileURL toURL:destination
                              error:&copyError])
        {
            // A picture that has gone since the document mentioned it is not
            // a reason to lose the export; the link stays and points at
            // nothing, which is what the document already did.
            continue;
        }
    }
    return YES;
}
