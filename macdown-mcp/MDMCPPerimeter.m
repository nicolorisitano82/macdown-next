//
//  MDMCPPerimeter.m
//  macdownext-mcp
//

#import "MDMCPPerimeter.h"


/// The extensions this server will open. Markdown and plain text: a folder
/// of notes is not a place to read binaries out of.
static NSSet<NSString *> *MDTextExtensions(void)
{
    static NSSet *extensions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        extensions = [NSSet setWithArray:@[
            @"md", @"markdown", @"mdown", @"mkd", @"txt", @"text",
        ]];
    });
    return extensions;
}


/// Folders nobody meant to include when they said "this folder".
static NSSet<NSString *> *MDAlwaysExcluded(void)
{
    static NSSet *excluded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        excluded = [NSSet setWithArray:@[
            @".git", @".svn", @".hg", @"node_modules", @".build",
            @"DerivedData", @".Trash", @"Pods", @".venv", @"__pycache__",
        ]];
    });
    return excluded;
}


@implementation MDMCPPerimeter

- (instancetype)initWithRoot:(NSURL *)root
{
    self = [super init];
    if (self)
    {
        NSURL *url = [[root URLByResolvingSymlinksInPath]
            URLByStandardizingPath];
        _root = url.isFileURL ? url : nil;
        _excluded = @[];
        _writing = MDMCPReadOnly;
        _sizeLimit = 2 * 1024 * 1024;
    }
    return self;
}


+ (BOOL)isExcludedComponent:(NSString *)component
{
    if ([MDAlwaysExcluded() containsObject:component])
        return YES;
    // A name that begins with a dot is machinery, not a document.
    return component.length > 1 && [component hasPrefix:@"."];
}


/// Whether `path` is that folder or something under it.
static BOOL MDPathIsUnder(NSString *path, NSString *folder)
{
    if ([path isEqualToString:folder])
        return YES;
    NSString *prefix = [folder hasSuffix:@"/"] ? folder
        : [folder stringByAppendingString:@"/"];
    return [path hasPrefix:prefix];
}


- (MDMCPVerdict)verdictForPath:(NSString *)path
{
    NSURL *url = nil;
    MDMCPVerdict verdict = MDMCPAllowed;
    url = [self urlForPath:path verdict:&verdict];
    (void)url;
    return verdict;
}


- (NSURL *)urlForPath:(NSString *)path verdict:(MDMCPVerdict *)outVerdict
{
    MDMCPVerdict verdict = MDMCPAllowed;
    NSURL *answer = nil;

    do {
        if (!path.length || !self.root)
        {
            verdict = MDMCPOutsideTheRoots;
            break;
        }

        // Relative to the root, so a caller can say "verbali/x.md".
        NSURL *given = [path hasPrefix:@"/"]
            ? [NSURL fileURLWithPath:path]
            : [self.root URLByAppendingPathComponent:path];

        // Resolved before it is compared: a symbolic link pointing out of
        // the folder is a path that leaves, however it is spelled. A file
        // that is not there cannot be resolved, so the parent is.
        NSURL *resolved = [[given URLByResolvingSymlinksInPath]
            URLByStandardizingPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:resolved.path])
        {
            NSURL *parent = [[given.URLByDeletingLastPathComponent
                URLByResolvingSymlinksInPath] URLByStandardizingPath];
            resolved = [parent URLByAppendingPathComponent:
                given.lastPathComponent];
        }

        if (!MDPathIsUnder(resolved.path, self.root.path))
        {
            verdict = MDMCPOutsideTheRoots;
            break;
        }

        for (NSString *component in resolved.pathComponents)
        {
            if ([MDMCPPerimeter isExcludedComponent:component])
            {
                verdict = MDMCPExcluded;
                break;
            }
        }
        if (verdict != MDMCPAllowed)
            break;

        // A pattern is matched against the path as the caller would write
        // it and against every name in it, so "bozze*" excludes the folder
        // and everything under it.
        NSString *relative = resolved.path;
        NSString *prefix = [self.root.path stringByAppendingString:@"/"];
        if ([relative hasPrefix:prefix])
            relative = [relative substringFromIndex:prefix.length];

        for (NSString *pattern in self.excluded)
        {
            NSPredicate *glob = [NSPredicate predicateWithFormat:
                @"SELF LIKE %@", pattern];
            BOOL hit = [glob evaluateWithObject:relative];
            for (NSString *component in relative.pathComponents)
                hit = hit || [glob evaluateWithObject:component];
            if (hit)
            {
                verdict = MDMCPExcluded;
                break;
            }
        }
        if (verdict != MDMCPAllowed)
            break;

        NSNumber *directory = nil;
        [resolved getResourceValue:&directory forKey:NSURLIsDirectoryKey
                             error:NULL];
        if (![[NSFileManager defaultManager] fileExistsAtPath:resolved.path])
        {
            verdict = MDMCPNotThere;
            break;
        }
        if (directory.boolValue && [MDMCPPerimeter isTextBundle:resolved])
        {
            // One document, and the size that matters is the text's.
            NSURL *text = [MDMCPPerimeter textFileFor:resolved];
            if (!text)
            {
                verdict = MDMCPNotText;
                break;
            }
            NSNumber *size = nil;
            [text getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
            if (size.unsignedLongLongValue > self.sizeLimit)
            {
                verdict = MDMCPTooBig;
                break;
            }
            answer = resolved;
            break;
        }
        if (!directory.boolValue)
        {
            if (![MDTextExtensions() containsObject:
                    resolved.pathExtension.lowercaseString])
            {
                verdict = MDMCPNotText;
                break;
            }
            NSNumber *size = nil;
            [resolved getResourceValue:&size forKey:NSURLFileSizeKey
                                 error:NULL];
            if (size.unsignedLongLongValue > self.sizeLimit)
            {
                verdict = MDMCPTooBig;
                break;
            }
        }
        answer = resolved;
    } while (0);

    if (outVerdict)
        *outVerdict = verdict;
    return verdict == MDMCPAllowed ? answer : nil;
}


+ (NSString *)reasonFor:(MDMCPVerdict)verdict
{
    switch (verdict)
    {
        case MDMCPAllowed:
            return @"allowed";
        case MDMCPOutsideTheRoots:
            return @"that path is outside the folders this server was "
                   @"given";
        case MDMCPNotText:
            return @"this server reads Markdown and text files only";
        case MDMCPExcluded:
            return @"that path is inside a folder this server leaves alone";
        case MDMCPTooBig:
            return @"that file is larger than this server will hand over";
        case MDMCPNotThere:
            return @"there is nothing at that path";
    }
}


+ (BOOL)isTextBundle:(NSURL *)url
{
    if (![url.pathExtension.lowercaseString isEqualToString:@"textbundle"])
        return NO;
    NSNumber *directory = nil;
    return [url getResourceValue:&directory forKey:NSURLIsDirectoryKey
                           error:NULL] && directory.boolValue;
}


+ (NSURL *)textFileFor:(NSURL *)document
{
    if (![self isTextBundle:document])
        return document;
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *name in @[@"text.markdown", @"text.md", @"text.txt"])
    {
        NSURL *file = [document URLByAppendingPathComponent:name];
        if ([manager fileExistsAtPath:file.path])
            return file;
    }
    return nil;
}


- (NSArray<NSURL *> *)filesUnder:(NSURL *)folder
{
    NSMutableArray<NSURL *> *found = [NSMutableArray array];
    NSURL *start = folder ?: self.root;
    if (!start)
        return found;

    NSDirectoryEnumerator<NSURL *> *walker = [[NSFileManager defaultManager]
        enumeratorAtURL:start
        includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey]
                   options:NSDirectoryEnumerationSkipsHiddenFiles
              errorHandler:nil];
    for (NSURL *url in walker)
    {
        NSNumber *directory = nil;
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey
                        error:NULL];
        if (directory.boolValue)
        {
            if ([MDMCPPerimeter isExcludedComponent:url.lastPathComponent])
            {
                [walker skipDescendants];
                continue;
            }
            // A textbundle is one document: counted here and not walked
            // into, so its plumbing never shows up in a listing.
            if ([MDMCPPerimeter isTextBundle:url])
            {
                [walker skipDescendants];
                if ([self verdictForPath:url.path] == MDMCPAllowed)
                    [found addObject:url];
            }
            continue;
        }
        if ([self verdictForPath:url.path] == MDMCPAllowed)
            [found addObject:url];
    }
    [found sortUsingComparator:^NSComparisonResult (NSURL *a, NSURL *b) {
        return [a.path compare:b.path];
    }];
    return found;
}

@end
