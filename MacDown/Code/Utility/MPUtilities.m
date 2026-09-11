//
//  MPUtilities.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPUtilities.h"
#import "MPGlobals.h"
#import "NSString+Lookup.h"
#import <JavaScriptCore/JavaScriptCore.h>

NSString * const kMPStylesDirectoryName = @"Styles";
NSString * const kMPStyleFileExtension = @"css";
NSString * const kMPThemesDirectoryName = @"Themes";
NSString * const kMPThemeFileExtension = @"style";
NSString * const kMPPlugInsDirectoryName = @"PlugIns";
NSString * const kMPPlugInFileExtension = @"plugin";

static NSString *MPDataRootDirectory()
{
    static NSString *path = nil;
    if (!path)
    {
        NSArray *paths =
            NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                NSUserDomainMask, YES);
        NSCAssert(paths.count > 0,
                  @"Cannot find directory for NSApplicationSupportDirectory.");
        // Not CFBundleName: see kMPDataDirectoryName.
        path = [NSString pathWithComponents:@[paths[0],
                                              kMPDataDirectoryName]];
    }
    return path;
}

NSString *MPDataDirectory(NSString *relativePath)
{
    if (!relativePath)
        return MPDataRootDirectory();
    return [NSString pathWithComponents:@[MPDataRootDirectory(), relativePath]];
}

NSString *MPPathToDataFile(NSString *name, NSString *dirPath)
{
    return [NSString pathWithComponents:@[MPDataDirectory(dirPath),
                                          name]];
}

NSUInteger MPReadingMinutesForWords(NSUInteger words)
{
    static const NSUInteger perMinute = 200;
    if (!words)
        return 0;
    return MAX((NSUInteger)1, (words + perMinute / 2) / perMinute);
}

NSUInteger MPLineNumberForLocation(NSString *text, NSUInteger location)
{
    if (!text.length)
        return 1;
    location = MIN(location, text.length);

    // One more line for each line ending passed, and not for the last line
    // of a text that does not end with one: its end is on it, not after it.
    NSUInteger line = 1;
    NSUInteger at = 0;
    while (at < location)
    {
        NSUInteger start = 0, end = 0, contentsEnd = 0;
        [text getLineStart:&start end:&end contentsEnd:&contentsEnd
                  forRange:NSMakeRange(at, 0)];
        if (end <= at || end > location || contentsEnd == end)
            break;
        line++;
        at = end;
    }
    return line;
}

NSArray<NSURL *> *MPPlugInBundleURLs(void)
{
    return MPPlugInBundleURLsInFolders(@[
        [NSURL fileURLWithPath:MPDataDirectory(kMPPlugInsDirectoryName)],
        // The application's own, which is where the ones it ships with are.
        // The test bundle lives here too in a test build, and is not a
        // plug-in: the extension settles that.
        [NSBundle mainBundle].builtInPlugInsURL,
    ]);
}

NSArray<NSURL *> *MPPlugInBundleURLsInFolders(NSArray<NSURL *> *folders)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableArray *found = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NSURL *> *> *byName =
        [NSMutableDictionary dictionary];

    for (NSURL *folder in folders)
    {
        if (!folder)
            continue;
        NSArray *entries = [manager contentsOfDirectoryAtURL:folder
            includingPropertiesForKeys:nil options:0 error:NULL];
        for (NSURL *entry in [entries sortedArrayUsingComparator:
                ^NSComparisonResult(NSURL *a, NSURL *b) {
            return [a.lastPathComponent compare:b.lastPathComponent];
        }])
        {
            if (![entry.pathExtension isEqualToString:kMPPlugInFileExtension])
                continue;
            NSString *name = entry.lastPathComponent;
            if (!byName[name])
                byName[name] = [NSMutableArray array];
            [byName[name] addObject:entry];
        }
    }

    /* Two copies of the same plug-in, and the newer one wins.
     *
     * "Installed wins" was the first rule, so that a build could be tried
     * without touching the application. It pins an old copy in silence
     * instead: install one, rebuild the application with a fixed version
     * inside it, and the fixed one never runs. The date says which is
     * which, and it is right for both cases — a copy dropped in to be
     * tried is newer than the application it is being tried against.
     */
    for (NSString *name in [byName.allKeys sortedArrayUsingSelector:
            @selector(compare:)])
    {
        NSArray *copies = byName[name];
        NSURL *newest = copies.firstObject;
        NSDate *when = nil;
        [newest getResourceValue:&when
                          forKey:NSURLContentModificationDateKey error:NULL];

        for (NSURL *other in copies)
        {
            NSDate *date = nil;
            [other getResourceValue:&date
                             forKey:NSURLContentModificationDateKey
                              error:NULL];
            if (when && date && [date compare:when] == NSOrderedDescending)
            {
                newest = other;
                when = date;
            }
        }
        [found addObject:newest];
    }
    return [found copy];
}

NSArray *MPListEntriesForDirectory(
    NSString *dirName, NSString *(^processor)(NSString *absolutePath))
{
    NSString *dirPath = MPDataDirectory(dirName);

    NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *fileNames = [manager contentsOfDirectoryAtPath:dirPath
                                                      error:&error];
    if (error || !fileNames.count)
        return @[];

    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (NSString *fileName in fileNames)
    {
        NSString *item = [NSString pathWithComponents:@[dirPath, fileName]];
        if (processor)
            item = processor(item);
        if (item)
            [items addObject:item];
    }
    return [items copy];
}

NSString *(^MPFileNameHasExtensionProcessor(NSString *ext))(NSString *path)
{
    id block = ^(NSString *absPath) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *name = absPath.lastPathComponent;
        NSString *processed = nil;
        if ([name hasExtension:ext] && [manager fileExistsAtPath:absPath])
            processed = name.stringByDeletingPathExtension;
        return processed;
    };
    return block;
}

/// UTF-8 bytes for one UTF-16 unit, or for the pair it opens.
NS_INLINE NSUInteger MPUTF8LengthOfUnit(unichar unit, unichar next,
                                        BOOL *consumedPair)
{
    if (consumedPair)
        *consumedPair = NO;
    if (unit < 0x80)
        return 1;
    if (unit < 0x800)
        return 2;
    // A surrogate pair is one character in four bytes; on its own a stray
    // surrogate is not, and three bytes is what an encoder writes for the
    // replacement it becomes.
    if (unit >= 0xD800 && unit <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF)
    {
        if (consumedPair)
            *consumedPair = YES;
        return 4;
    }
    return 3;
}

NSUInteger MPUTF8ByteOffsetForCharacterIndex(NSString *string,
                                             NSUInteger index)
{
    NSUInteger length = string.length;
    if (index > length)
        index = length;
    if (!index)
        return 0;

    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)string, &buffer,
                             CFRangeMake(0, (CFIndex)index));

    NSUInteger bytes = 0;
    for (NSUInteger i = 0; i < index; i++)
    {
        unichar unit = CFStringGetCharacterFromInlineBuffer(&buffer,
                                                            (CFIndex)i);
        unichar next = (i + 1 < index)
            ? CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)(i + 1))
            : 0;
        BOOL pair = NO;
        bytes += MPUTF8LengthOfUnit(unit, next, &pair);
        if (pair)
            i++;
    }
    return bytes;
}

NSUInteger MPCharacterIndexForUTF8ByteOffset(NSString *string,
                                             NSUInteger offset)
{
    NSUInteger length = string.length;
    if (!offset || !length)
        return 0;

    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)string, &buffer,
                             CFRangeMake(0, (CFIndex)length));

    NSUInteger bytes = 0;
    for (NSUInteger i = 0; i < length; i++)
    {
        if (bytes >= offset)
            return i;
        unichar unit = CFStringGetCharacterFromInlineBuffer(&buffer,
                                                            (CFIndex)i);
        unichar next = (i + 1 < length)
            ? CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)(i + 1))
            : 0;
        BOOL pair = NO;
        bytes += MPUTF8LengthOfUnit(unit, next, &pair);
        if (pair)
            i++;
    }
    return length;
}

/** Markdown link target for a file being pointed at from this document.
 *
 * Relative to the document's own folder when the file sits inside it, so
 * that moving the pair together keeps the link alive; absolute otherwise.
 * Percent-encoded either way, because an unescaped space ends the link
 * target and the rest of the path leaks into the page as text.
 */
NSString *MPMarkdownLinkTargetForFileURL(NSURL *fileURL,
                                         NSURL *documentURL)
{
    NSString *path = fileURL.path;
    NSString *directory = documentURL.URLByDeletingLastPathComponent.path;

    if (directory.length)
    {
        NSString *prefix = [directory hasSuffix:@"/"]
            ? directory : [directory stringByAppendingString:@"/"];
        if ([path hasPrefix:prefix])
            path = [path substringFromIndex:prefix.length];
        else
            path = nil;
    }
    else
    {
        path = nil;
    }

    if (!path)
        return fileURL.absoluteString;

    NSCharacterSet *allowed = [NSCharacterSet URLPathAllowedCharacterSet];
    return [path stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

NSURL *MPNewMarkdownFileURLForName(NSString *name, NSURL *documentURL)
{
    NSURL *directory = documentURL.URLByDeletingLastPathComponent;
    if (!directory || !documentURL)
        return nil;

    // Everything a folder will not take, and the whitespace that a
    // selection drags along with it.
    NSMutableCharacterSet *forbidden = [NSMutableCharacterSet
        characterSetWithCharactersInString:@"/\\:*?\"<>|"];
    [forbidden formUnionWithCharacterSet:
        [NSCharacterSet controlCharacterSet]];
    [forbidden formUnionWithCharacterSet:
        [NSCharacterSet newlineCharacterSet]];

    NSString *clean = [[name componentsSeparatedByCharactersInSet:forbidden]
        componentsJoinedByString:@" "];
    // Runs of spaces collapse: a selection spanning a line break would
    // otherwise leave a gap in the middle of the name.
    while ([clean rangeOfString:@"  "].location != NSNotFound)
        clean = [clean stringByReplacingOccurrencesOfString:@"  "
                                                 withString:@" "];
    clean = [clean stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    // A leading dot hides the file, which is never what a link meant.
    while ([clean hasPrefix:@"."])
        clean = [[clean substringFromIndex:1] stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
    if (!clean.length)
        return nil;

    // Long enough for anybody, short enough for every file system.
    if (clean.length > 120)
        clean = [clean substringToIndex:120];

    NSString *extension = clean.pathExtension.lowercaseString;
    if (![extension isEqualToString:@"md"]
            && ![extension isEqualToString:@"markdown"])
        clean = [clean stringByAppendingPathExtension:@"md"];

    return [directory URLByAppendingPathComponent:clean];
}

/// The named entities worth carrying a table for: the ones that turn up in
/// the titles and descriptions of ordinary pages. Everything else arrives
/// numbered, which is handled below without a table.
static NSDictionary<NSString *, NSString *> *MPNamedHTMLEntities(void)
{
    static NSDictionary *named = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        named = @{
            @"nbsp": @"\u00a0", @"ndash": @"–", @"mdash": @"—",
            @"hellip": @"…", @"laquo": @"«", @"raquo": @"»",
            @"lsquo": @"‘", @"rsquo": @"’", @"ldquo": @"“", @"rdquo": @"”",
            @"sbquo": @"‚", @"bdquo": @"„", @"middot": @"·", @"bull": @"•",
            @"deg": @"°", @"times": @"×", @"divide": @"÷", @"plusmn": @"±",
            @"euro": @"€", @"pound": @"£", @"yen": @"¥", @"cent": @"¢",
            @"copy": @"©", @"reg": @"®", @"trade": @"™", @"sect": @"§",
            @"para": @"¶", @"dagger": @"†", @"permil": @"‰",
            @"agrave": @"à", @"aacute": @"á", @"acirc": @"â", @"auml": @"ä",
            @"aring": @"å", @"atilde": @"ã", @"aelig": @"æ",
            @"egrave": @"è", @"eacute": @"é", @"ecirc": @"ê", @"euml": @"ë",
            @"igrave": @"ì", @"iacute": @"í", @"icirc": @"î", @"iuml": @"ï",
            @"ograve": @"ò", @"oacute": @"ó", @"ocirc": @"ô", @"ouml": @"ö",
            @"otilde": @"õ", @"oslash": @"ø",
            @"ugrave": @"ù", @"uacute": @"ú", @"ucirc": @"û", @"uuml": @"ü",
            @"ccedil": @"ç", @"ntilde": @"ñ", @"szlig": @"ß", @"yuml": @"ÿ",
            @"Agrave": @"À", @"Eacute": @"É", @"Egrave": @"È",
            @"Igrave": @"Ì", @"Ograve": @"Ò", @"Ugrave": @"Ù",
            @"Ccedil": @"Ç", @"Ntilde": @"Ñ", @"Auml": @"Ä", @"Ouml": @"Ö",
            @"Uuml": @"Ü",
        };
    });
    return named;
}


NSString *MPStringByUnescapingHTMLEntities(NSString *value)
{
    if (!value.length || [value rangeOfString:@"&"].location == NSNotFound)
        return value;

    NSMutableString *out = [value mutableCopy];

    // Numbered first, and by hand rather than by table: a page may use any
    // character there is, and `&#233;` and `&#xE9;` are the same é.
    static NSRegularExpression *numbered = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        numbered = [NSRegularExpression regularExpressionWithPattern:
            @"&#(x?)([0-9a-fA-F]+);" options:0 error:NULL];
    });
    NSArray *matches = [numbered matchesInString:out options:0
                                           range:NSMakeRange(0, out.length)];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator)
    {
        BOOL hex = [out substringWithRange:[match rangeAtIndex:1]].length > 0;
        NSString *digits = [out substringWithRange:[match rangeAtIndex:2]];
        unsigned long long code = hex
            ? strtoull(digits.UTF8String, NULL, 16)
            : strtoull(digits.UTF8String, NULL, 10);
        if (!code || code > 0x10FFFF)
            continue;

        NSString *character = nil;
        if (code > 0xFFFF)
        {
            code -= 0x10000;
            unichar pair[2] = {
                (unichar)(0xD800 + (code >> 10)),
                (unichar)(0xDC00 + (code & 0x3FF)),
            };
            character = [NSString stringWithCharacters:pair length:2];
        }
        else
        {
            unichar one = (unichar)code;
            character = [NSString stringWithCharacters:&one length:1];
        }
        [out replaceCharactersInRange:match.range withString:character];
    }

    NSDictionary *named = MPNamedHTMLEntities();
    for (NSString *name in named)
    {
        [out replaceOccurrencesOfString:
            [NSString stringWithFormat:@"&%@;", name]
                             withString:named[name] options:0
                                  range:NSMakeRange(0, out.length)];
    }

    // The ampersand last: doing it first would turn `&amp;lt;` into `<`.
    NSArray<NSArray<NSString *> *> *pairs = @[
        @[@"&lt;", @"<"], @[@"&gt;", @">"], @[@"&quot;", @"\""],
        @[@"&apos;", @"'"], @[@"&amp;", @"&"],
    ];
    for (NSArray<NSString *> *pair in pairs)
    {
        [out replaceOccurrencesOfString:pair[0] withString:pair[1]
                                options:NSCaseInsensitiveSearch
                                  range:NSMakeRange(0, out.length)];
    }
    return out;
}

BOOL MPCharacterIsWhitespace(unichar character)
{
    static NSCharacterSet *whitespaces = nil;
    if (!whitespaces)
        whitespaces = [NSCharacterSet whitespaceCharacterSet];
    return [whitespaces characterIsMember:character];
}

BOOL MPCharacterIsNewline(unichar character)
{
    static NSCharacterSet *newlines = nil;
    if (!newlines)
        newlines = [NSCharacterSet newlineCharacterSet];
    return [newlines characterIsMember:character];
}

BOOL MPStringIsNewline(NSString *str)
{
    if (str.length != 1)
        return NO;
    return MPCharacterIsNewline([str characterAtIndex:0]);
}

NSString *MPStylePathForName(NSString *name)
{
    if (!name)
        return nil;
    if (![name hasExtension:kMPStyleFileExtension])
        name = [name stringByAppendingPathExtension:kMPStyleFileExtension];
    NSString *path = MPPathToDataFile(name, kMPStylesDirectoryName);
    return path;
}

NSString *MPThemePathForName(NSString *name)
{
    if (![name hasExtension:kMPThemeFileExtension])
        name = [name stringByAppendingPathExtension:kMPThemeFileExtension];
    NSString *path = MPPathToDataFile(name, kMPThemesDirectoryName);
    return path;
}

NSURL *MPHighlightingThemeURLForName(NSString *name)
{
    name = [NSString stringWithFormat:@"prism-%@", [name lowercaseString]];
    if ([name hasExtension:@"css"])
        name = name.stringByDeletingPathExtension;

    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:name withExtension:@"css"
                           subdirectory:@"Prism/themes"];

    // Safty net: file not found, use default.
    if (!url)
    {
        url = [bundle URLForResource:@"prism" withExtension:@"css"
                        subdirectory:@"Prism/themes"];
    }
    return url;
}

NSString *MPReadFileOfPath(NSString *path)
{
    NSError *error = nil;
    NSString *s = [NSString stringWithContentsOfFile:path
                                            encoding:NSUTF8StringEncoding
                                               error:&error];
    if (error)
        return @"";
    return s;
}

NSDictionary *MPGetDataMap(NSString *name)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *filePath = [bundle pathForResource:name ofType:@"map"
                                     inDirectory:@"Data"];
    return [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
}

id MPGetObjectFromJavaScript(NSString *code, NSString *variableName)
{
    if (!code.length)
        return nil;

    id object = nil;
    JSGlobalContextRef cxt = NULL;
    JSStringRef js = NULL;
    JSStringRef varn = NULL;
    JSStringRef jsonr = NULL;

    do {
        JSValueRef exc = NULL;

        cxt = JSGlobalContextCreate(NULL);
        js = JSStringCreateWithCFString((__bridge CFStringRef)code);
        JSEvaluateScript(cxt, js, NULL, NULL, 0, &exc);
        if (exc)
            break;

        varn = JSStringCreateWithUTF8CString([variableName UTF8String]);
        JSObjectRef global = JSContextGetGlobalObject(cxt);
        JSValueRef val = JSObjectGetProperty(cxt, global, varn, &exc);

        // JavaScript Object -> JSON -> Foundation Object.
        // Not the best way to do this, but enough for our purpose.
        jsonr = JSValueCreateJSONString(cxt, val, 0, &exc);
        if (exc)
            break;
        size_t sz = JSStringGetLength(jsonr) + 1;   // NULL terminated.
        char *buffer = (char *)malloc(sz * sizeof(char));
        JSStringGetUTF8CString(jsonr, buffer, sz);
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:sz - 1
                                      freeWhenDone:YES];
        object = [NSJSONSerialization JSONObjectWithData:data options:0
                                                   error:NULL];
    } while (0);

    if (jsonr)
        JSStringRelease(jsonr);
    if (varn)
        JSStringRelease(varn);
    if (cxt)
        JSGlobalContextRelease(cxt);
    if (js)
        JSStringRelease(js);
    return object;
}


BOOL MPFileIsMissing(NSURL *fileURL)
{
    // A document that was never saved is not missing anything: it has no
    // file to lose.
    if (!fileURL.isFileURL)
        return NO;
    return ![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path];
}


MPExternalChange MPExternalChangeFor(NSString *onDisk, NSString *inEditor,
                                     BOOL edited, BOOL missing)
{
    if (missing)
        return MPExternalChangeGone;
    // Unreadable is not the same as changed: a file being written to right
    // now reads as nothing, and a moment later reads as itself.
    if (!onDisk)
        return MPExternalChangeNothing;
    if ([onDisk isEqualToString:inEditor ?: @""])
        return MPExternalChangeNothing;
    return edited ? MPExternalChangeAsk : MPExternalChangeReload;
}


NSArray<NSValue *> *MPMarkdownCodeRanges(NSString *text)
{
    NSMutableArray *ranges = [NSMutableArray array];

    // Fenced blocks first, line by line, because a fence is a whole line
    // and an inline span inside one is part of the block.
    NSUInteger at = 0;
    NSUInteger openedAt = NSNotFound;
    unichar fence = 0;
    NSUInteger fenceLength = 0;

    while (at < text.length)
    {
        NSUInteger start = 0, end = 0, contentsEnd = 0;
        [text getLineStart:&start end:&end contentsEnd:&contentsEnd
                  forRange:NSMakeRange(at, 0)];
        NSString *line = [text substringWithRange:
            NSMakeRange(start, contentsEnd - start)];
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];

        NSUInteger run = 0;
        unichar character = 0;
        if (trimmed.length >= 3)
        {
            character = [trimmed characterAtIndex:0];
            if (character == '`' || character == '~')
            {
                while (run < trimmed.length
                       && [trimmed characterAtIndex:run] == character)
                    run++;
                if (run < 3)
                    run = 0;
            }
        }

        if (run && openedAt == NSNotFound)
        {
            openedAt = start;
            fence = character;
            fenceLength = run;
        }
        else if (run && character == fence && run >= fenceLength)
        {
            [ranges addObject:[NSValue valueWithRange:
                NSMakeRange(openedAt, contentsEnd - openedAt)]];
            openedAt = NSNotFound;
        }

        if (end <= at)
            break;
        at = end;
    }
    // A fence that never closes takes the rest of the document with it,
    // which is what the parser does too.
    if (openedAt != NSNotFound)
    {
        [ranges addObject:[NSValue valueWithRange:
            NSMakeRange(openedAt, text.length - openedAt)]];
    }

    static NSRegularExpression *inlineCode = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        inlineCode = [[NSRegularExpression alloc]
            initWithPattern:@"`+[^`\\n]*`+" options:0 error:NULL];
    });
    for (NSTextCheckingResult *span in [inlineCode matchesInString:text
            options:0 range:NSMakeRange(0, text.length)])
    {
        [ranges addObject:[NSValue valueWithRange:span.range]];
    }

    return ranges;
}
