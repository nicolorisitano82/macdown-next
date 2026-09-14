//
//  MPAttachments.m
//  MacDown
//

#import "MPAttachments.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>


/// Quello che dentro un textbundle si chiama così da sempre.
static NSString *const kMPBundleAssets = @"assets";


BOOL MPIsAPicture(NSString *name)
{
    static NSSet *kinds = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kinds = [NSSet setWithArray:@[@"png", @"jpg", @"jpeg", @"gif",
                                      @"svg", @"webp", @"heic", @"heif",
                                      @"tif", @"tiff", @"bmp", @"avif",
                                      @"ico"]];
    });
    return [kinds containsObject:name.pathExtension.lowercaseString];
}


BOOL MPIsANeighbouringDocument(NSString *name)
{
    static NSSet *kinds = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kinds = [NSSet setWithArray:@[@"md", @"markdown", @"mdown", @"mkd",
                                      @"mkdn", @"text", @"txt",
                                      @"textbundle", @"textpack"]];
    });
    return [kinds containsObject:name.pathExtension.lowercaseString];
}


NSString *MPAttachmentsFolderNameFor(NSURL *documentURL)
{
    if (!documentURL.isFileURL)
        return nil;
    if ([documentURL.pathExtension.lowercaseString
            isEqualToString:@"textbundle"])
        return kMPBundleAssets;
    return [documentURL.lastPathComponent.stringByDeletingPathExtension
        stringByAppendingPathExtension:@"assets"];
}


NSURL *MPAttachmentsFolderFor(NSURL *documentURL)
{
    NSString *name = MPAttachmentsFolderNameFor(documentURL);
    if (!name)
        return nil;
    // Dentro un textbundle il documento *è* la cartella; fuori, gli
    // allegati stanno accanto al file.
    NSURL *beside = [documentURL.pathExtension.lowercaseString
                        isEqualToString:@"textbundle"]
        ? documentURL
        : documentURL.URLByDeletingLastPathComponent;
    return [beside URLByAppendingPathComponent:name isDirectory:YES];
}


NSString *MPAttachFileToDocument(NSURL *source, NSURL *documentURL,
                                 NSString **problem)
{
    NSURL *folder = MPAttachmentsFolderFor(documentURL);
    if (!source.isFileURL || !folder)
    {
        if (problem)
            *problem = NSLocalizedString(
                @"Save the document first: its attachments live beside it.",
                @"Attaching to a document that is not on disk yet");
        return nil;
    }

    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *making = nil;
    if (![manager createDirectoryAtURL:folder withIntermediateDirectories:YES
                            attributes:nil error:&making]
            && ![manager fileExistsAtPath:folder.path])
    {
        if (problem)
            *problem = making.localizedDescription;
        return nil;
    }

    // Un nome già preso non si sovrascrive: si numera. Due cartelle
    // possono benissimo avere ciascuna il suo «verbale.pdf».
    NSString *name = source.lastPathComponent;
    NSString *stem = name.stringByDeletingPathExtension;
    NSString *extension = name.pathExtension;
    NSURL *destination = [folder URLByAppendingPathComponent:name];
    for (NSUInteger attempt = 2;
         [manager fileExistsAtPath:destination.path] && attempt < 1000;
         attempt++)
    {
        name = extension.length
            ? [NSString stringWithFormat:@"%@-%lu.%@", stem,
               (unsigned long)attempt, extension]
            : [NSString stringWithFormat:@"%@-%lu", stem,
               (unsigned long)attempt];
        destination = [folder URLByAppendingPathComponent:name];
    }

    NSError *copying = nil;
    if (![manager copyItemAtURL:source toURL:destination error:&copying])
    {
        if (problem)
            *problem = copying.localizedDescription;
        return nil;
    }
    return name;
}


NSString *MPAttachmentMarkdown(NSString *name, NSString *folder)
{
    NSString *where = folder.length
        ? [NSString stringWithFormat:@"%@/%@", folder, name] : name;
    NSString *encoded = [where
        stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLPathAllowedCharacterSet]] ?: where;
    NSString *label = name.stringByDeletingPathExtension;
    // Un'immagine si vede, un file si apre: sono due scritture diverse
    // perché sono due cose diverse.
    return MPIsAPicture(name)
        ? [NSString stringWithFormat:@"![%@](%@)", label, encoded]
        : [NSString stringWithFormat:@"[%@](%@)", name, encoded];
}


NSString *MPDataURIForFile(NSURL *file, NSString **problem)
{
    NSError *reading = nil;
    NSData *data = [NSData dataWithContentsOfURL:file
                                         options:NSDataReadingMappedIfSafe
                                           error:&reading];
    if (!data)
    {
        if (problem)
            *problem = reading.localizedDescription;
        return nil;
    }
    UTType *type = [UTType typeWithFilenameExtension:
        file.pathExtension ?: @""];
    NSString *mime = type.preferredMIMEType ?: @"application/octet-stream";
    return [NSString stringWithFormat:@"data:%@;base64,%@", mime,
            [data base64EncodedStringWithOptions:0]];
}


#pragma mark - Quali file fanno parte del documento

/// Ogni destinazione di link nel Markdown, immagini comprese: `[x](qui)`,
/// `![x](qui)` e la definizione a cui una referenza rimanda.
static NSArray<NSTextCheckingResult *> *MPLinkDestinations(NSString *markdown)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"!?\\[[^\\]]*\\]\\(\\s*(?:<([^>]*)>"
            @"|((?:[^\\s()]|\\([^\\s()]*\\))+))"
            @"(?:\\s+\"[^\"]*\")?\\s*\\)"
            @"|^[ \\t]{0,3}\\[[^\\]]+\\]:[ \\t]*(?:<([^>]*)>|(\\S+))"
            options:NSRegularExpressionAnchorsMatchLines error:NULL];
    });
    return [regex matchesInString:markdown options:0
                            range:NSMakeRange(0, markdown.length)];
}


NSArray<NSURL *> *MPAttachmentsIn(NSString *markdown, NSURL *documentURL)
{
    NSMutableArray<NSURL *> *found = [NSMutableArray array];
    if (!markdown.length)
        return found;

    NSURL *base = [documentURL.pathExtension.lowercaseString
                      isEqualToString:@"textbundle"]
        ? [documentURL URLByAppendingPathComponent:@"text.markdown"]
        : documentURL;

    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSTextCheckingResult *match in MPLinkDestinations(markdown))
    {
        NSRange range = NSMakeRange(NSNotFound, 0);
        for (NSUInteger group = 1; group <= 4; group++)
        {
            NSRange one = [match rangeAtIndex:group];
            if (one.location != NSNotFound)
            {
                range = one;
                break;
            }
        }
        if (range.location == NSNotFound)
            continue;

        NSString *destination = [markdown substringWithRange:range];
        NSString *low = destination.lowercaseString;
        if (!destination.length || [low hasPrefix:@"#"]
                || [low hasPrefix:@"http://"] || [low hasPrefix:@"https://"]
                || [low hasPrefix:@"data:"] || [low hasPrefix:@"mailto:"]
                || [low hasPrefix:@"//"])
            continue;
        // Un'immagine ha già la sua strada, e un documento accanto è un
        // vicino: nessuno dei due è un allegato.
        if (MPIsAPicture(destination) || MPIsANeighbouringDocument(destination))
            continue;

        NSString *path = [destination stringByRemovingPercentEncoding]
            ?: destination;
        NSURL *file = [path hasPrefix:@"/"]
            ? [NSURL fileURLWithPath:path]
            : [NSURL URLWithString:
                [path stringByAddingPercentEncodingWithAllowedCharacters:
                    [NSCharacterSet URLPathAllowedCharacterSet]] ?: path
               relativeToURL:base];
        file = file.URLByStandardizingPath.absoluteURL;
        if (!file.isFileURL)
            continue;
        NSNumber *directory = nil;
        if (![file getResourceValue:&directory forKey:NSURLIsDirectoryKey
                              error:NULL] || directory.boolValue)
            continue;           // non c'è, o è una cartella
        if ([seen containsObject:file.path])
            continue;
        [seen addObject:file.path];
        [found addObject:file];
    }
    return found;
}


NSString *MPHTMLWithAttachmentsInlined(NSString *html, NSURL *base)
{
    if (!html.length)
        return html ?: @"";

    static NSRegularExpression *links = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        links = [NSRegularExpression regularExpressionWithPattern:
            @"<a\\b[^>]*?\\bhref\\s*=\\s*[\"']([^\"']+)[\"']"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });

    NSMutableString *made = [html mutableCopy];
    NSArray<NSTextCheckingResult *> *found = [links matchesInString:html
        options:0 range:NSMakeRange(0, html.length)];
    // All'indietro, così gli indici di prima restano validi.
    for (NSTextCheckingResult *one in found.reverseObjectEnumerator)
    {
        NSRange where = [one rangeAtIndex:1];
        NSString *source = [html substringWithRange:where];
        NSString *low = source.lowercaseString;
        if ([low hasPrefix:@"#"] || [low hasPrefix:@"data:"]
                || [low hasPrefix:@"http:"] || [low hasPrefix:@"https:"]
                || [low hasPrefix:@"mailto:"])
            continue;
        if (MPIsANeighbouringDocument(source))
            continue;

        NSURL *url = [low hasPrefix:@"file:"]
            ? [NSURL URLWithString:source]
            : [NSURL URLWithString:
                [source stringByRemovingPercentEncoding] ?: source
                relativeToURL:base];
        if (!url.isFileURL)
            continue;
        NSString *uri = MPDataURIForFile(url, NULL);
        if (!uri)
            continue;           // un file che non c'è resta scritto com'era
        [made replaceCharactersInRange:where withString:uri];
    }
    return made;
}
