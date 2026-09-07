//
//  MPInstructionFiles.m
//  MacDown
//

#import "MPInstructionFiles.h"

#import "MPUtilities.h"


/// Where the loader stops following imports: four hops, per its own
/// documentation. Past that a file is written but never read, which is worth
/// saying out loud.
static const NSUInteger kMPImportHops = 4;

/// The length past which the documentation says adherence falls off.
static const NSUInteger kMPComfortableLines = 200;

/// And the length past which the file is skipped altogether.
static const unsigned long long kMPFileIgnoredAbove = 4ULL * 1024 * 1024;


@interface MPInstructionFile ()
@property (copy, nonatomic) NSURL *fileURL;
@property (nonatomic) MPInstructionScope scope;
@property (nonatomic) BOOL exists;
@property (nonatomic) NSUInteger lines;
@property (nonatomic) unsigned long long size;
@end

@implementation MPInstructionFile

- (NSString *)scopeName
{
    switch (self.scope)
    {
        case MPInstructionScopeManaged:
            return NSLocalizedString(@"machine", @"Instruction file scope");
        case MPInstructionScopeUser:
            return NSLocalizedString(@"yours", @"Instruction file scope");
        case MPInstructionScopeProject:
            return NSLocalizedString(@"project", @"Instruction file scope");
        case MPInstructionScopeLocal:
            return NSLocalizedString(@"local", @"Instruction file scope");
        case MPInstructionScopeAgents:
            return NSLocalizedString(@"other agents",
                                     @"Instruction file scope");
    }
}

@end


@interface MPInstructionImport ()
@property (copy, nonatomic) NSString *path;
@property (nonatomic) NSRange range;
@property (nonatomic) NSUInteger line;
@end

@implementation MPInstructionImport
@end


@interface MPInstructionNode ()
@property (copy, nonatomic) NSURL *fileURL;
@property (copy, nonatomic) NSString *writtenAs;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) BOOL exists;
@property (nonatomic) BOOL circular;
@property (nonatomic) BOOL tooDeep;
@property (copy, nonatomic) NSArray<MPInstructionNode *> *imports;
@end

@implementation MPInstructionNode
@end


@interface MPInstructionIssue ()
@property (copy, nonatomic) NSString *message;
@property (copy, nonatomic) NSURL *fileURL;
@property (nonatomic) NSUInteger line;
@end

@implementation MPInstructionIssue
@end


#pragma mark - Which files are these

BOOL MPIsInstructionFile(NSURL *fileURL)
{
    NSString *name = fileURL.lastPathComponent;
    return [name isEqualToString:@"CLAUDE.md"]
        || [name isEqualToString:@"CLAUDE.local.md"]
        || [name isEqualToString:@"AGENTS.md"];
}


/// One entry of the list, measured if it is there.
static MPInstructionFile *MPInstructionFileAt(NSURL *url,
                                              MPInstructionScope scope)
{
    MPInstructionFile *file = [[MPInstructionFile alloc] init];
    file.fileURL = url;
    file.scope = scope;

    NSNumber *size = nil;
    file.exists = [url getResourceValue:&size forKey:NSURLFileSizeKey
                                  error:NULL] && size != nil;
    if (!file.exists)
        return file;

    file.size = size.unsignedLongLongValue;
    NSString *text = [NSString stringWithContentsOfURL:url
        encoding:NSUTF8StringEncoding error:NULL];
    if (text)
    {
        NSUInteger lines = 0;
        NSUInteger at = 0;
        while (at < text.length)
        {
            at = NSMaxRange([text lineRangeForRange:NSMakeRange(at, 0)]);
            lines++;
        }
        file.lines = lines;
    }
    return file;
}


NSArray<MPInstructionFile *> *MPInstructionHierarchyForDocument(
    NSURL *documentURL, NSURL *home, NSURL *managedRoot)
{
    NSMutableArray<MPInstructionFile *> *files = [NSMutableArray array];
    if (!documentURL)
        return files;

    if (managedRoot)
    {
        [files addObject:MPInstructionFileAt(
            [managedRoot URLByAppendingPathComponent:@"CLAUDE.md"],
            MPInstructionScopeManaged)];
    }
    if (home)
    {
        [files addObject:MPInstructionFileAt(
            [[home URLByAppendingPathComponent:@".claude"]
                URLByAppendingPathComponent:@"CLAUDE.md"],
            MPInstructionScopeUser)];
    }

    // From the top of the tree down to the document's own folder, which is
    // the order the loader reads them in: the nearest file is read last, and
    // so has the last word.
    NSMutableArray<NSURL *> *folders = [NSMutableArray array];
    NSURL *folder = documentURL.URLByDeletingLastPathComponent
        .URLByStandardizingPath;
    while (folder && folder.path.length > 1)
    {
        [folders insertObject:folder atIndex:0];
        NSURL *up = folder.URLByDeletingLastPathComponent
            .URLByStandardizingPath;
        if ([up.path isEqualToString:folder.path])
            break;
        folder = up;
    }

    for (NSURL *each in folders)
    {
        NSURL *shared = [each URLByAppendingPathComponent:@"CLAUDE.md"];
        NSURL *inside = [[each URLByAppendingPathComponent:@".claude"]
            URLByAppendingPathComponent:@"CLAUDE.md"];
        NSURL *local = [each URLByAppendingPathComponent:@"CLAUDE.local.md"];
        NSURL *agents = [each URLByAppendingPathComponent:@"AGENTS.md"];

        for (NSURL *url in @[shared, inside])
        {
            MPInstructionFile *file =
                MPInstructionFileAt(url, MPInstructionScopeProject);
            // Only the folders that have one, except for the document's own,
            // where an absent file is worth showing: that is where you would
            // put it.
            if (file.exists || [each.path isEqualToString:
                    documentURL.URLByDeletingLastPathComponent
                        .URLByStandardizingPath.path])
                [files addObject:file];
        }
        MPInstructionFile *localFile =
            MPInstructionFileAt(local, MPInstructionScopeLocal);
        if (localFile.exists)
            [files addObject:localFile];

        MPInstructionFile *agentsFile =
            MPInstructionFileAt(agents, MPInstructionScopeAgents);
        if (agentsFile.exists)
            [files addObject:agentsFile];
    }
    return files;
}


#pragma mark - The imports

NSArray<MPInstructionImport *> *MPInstructionImportsInText(NSString *text)
{
    NSMutableArray<MPInstructionImport *> *found = [NSMutableArray array];
    if (!text.length)
        return found;

    static NSRegularExpression *imports = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // An `@` that opens a path, not one in the middle of a word and not
        // an e-mail address: what follows has to look like a path.
        imports = [NSRegularExpression regularExpressionWithPattern:
            @"(?<![\\w@/.-])@([~./]?[\\w./~-]*[\\w/~-])" options:0 error:NULL];
    });

    NSArray<NSValue *> *code = MPMarkdownCodeRanges(text);
    NSArray *matches = [imports matchesInString:text options:0
                                          range:NSMakeRange(0, text.length)];
    for (NSTextCheckingResult *match in matches)
    {
        BOOL inCode = NO;
        for (NSValue *value in code)
        {
            if (NSIntersectionRange(value.rangeValue, match.range).length)
            {
                inCode = YES;
                break;
            }
        }
        if (inCode)
            continue;

        MPInstructionImport *one = [[MPInstructionImport alloc] init];
        one.range = match.range;
        one.path = [text substringWithRange:[match rangeAtIndex:1]];
        one.line = MPLineNumberForLocation(text, match.range.location);
        [found addObject:one];
    }
    return found;
}


/// The file an import points at, resolved the way the loader resolves it:
/// against the file that wrote it, with `~` meaning the home folder.
static NSURL *MPImportedFileURL(NSString *path, NSURL *from)
{
    if (!path.length)
        return nil;
    if ([path hasPrefix:@"~"])
    {
        NSString *expanded = path.stringByExpandingTildeInPath;
        return [NSURL fileURLWithPath:expanded].URLByStandardizingPath;
    }
    if ([path hasPrefix:@"/"])
        return [NSURL fileURLWithPath:path].URLByStandardizingPath;
    return [[from.URLByDeletingLastPathComponent
        URLByAppendingPathComponent:path] URLByStandardizingPath];
}


static MPInstructionNode *MPResolveNode(NSURL *fileURL, NSString *writtenAs,
                                        NSUInteger depth,
                                        NSMutableSet<NSString *> *seen)
{
    MPInstructionNode *node = [[MPInstructionNode alloc] init];
    node.fileURL = fileURL;
    node.writtenAs = writtenAs;
    node.depth = depth;
    node.exists = [[NSFileManager defaultManager]
        fileExistsAtPath:fileURL.path];
    node.imports = @[];

    if (!node.exists)
        return node;
    if ([seen containsObject:fileURL.path])
    {
        node.circular = YES;
        return node;
    }
    if (depth >= kMPImportHops)
    {
        node.tooDeep = YES;
        return node;
    }

    [seen addObject:fileURL.path];
    NSString *text = [NSString stringWithContentsOfURL:fileURL
        encoding:NSUTF8StringEncoding error:NULL];
    NSMutableArray<MPInstructionNode *> *children = [NSMutableArray array];
    for (MPInstructionImport *one in MPInstructionImportsInText(text))
    {
        NSURL *imported = MPImportedFileURL(one.path, fileURL);
        if (!imported)
            continue;
        [children addObject:MPResolveNode(imported, one.path, depth + 1,
                                          seen)];
    }
    [seen removeObject:fileURL.path];
    node.imports = children;
    return node;
}


MPInstructionNode *MPResolveInstructionImports(NSURL *fileURL)
{
    if (!fileURL)
        return nil;
    return MPResolveNode(fileURL.URLByStandardizingPath, nil, 0,
                         [NSMutableSet set]);
}


#pragma mark - What is wrong with it

static MPInstructionIssue *MPIssue(NSString *message, NSURL *url,
                                   NSUInteger line)
{
    MPInstructionIssue *issue = [[MPInstructionIssue alloc] init];
    issue.message = message;
    issue.fileURL = url;
    issue.line = line;
    return issue;
}


static void MPCollectIssues(MPInstructionNode *node,
                            NSMutableArray<MPInstructionIssue *> *issues)
{
    for (MPInstructionNode *child in node.imports)
    {
        if (!child.exists)
        {
            [issues addObject:MPIssue([NSString stringWithFormat:
                NSLocalizedString(@"@%@ leads to no file",
                                  @"Instruction file issue"),
                child.writtenAs], node.fileURL, 0)];
        }
        else if (child.circular)
        {
            [issues addObject:MPIssue([NSString stringWithFormat:
                NSLocalizedString(@"@%@ closes a circle: it is not followed",
                                  @"Instruction file issue"),
                child.writtenAs], node.fileURL, 0)];
        }
        else if (child.tooDeep)
        {
            [issues addObject:MPIssue([NSString stringWithFormat:
                NSLocalizedString(
                    @"@%@ sits past the fourth hop: it is not read",
                    @"Instruction file issue"),
                child.writtenAs], node.fileURL, 0)];
        }
        MPCollectIssues(child, issues);
    }
}


NSArray<MPInstructionIssue *> *MPInstructionIssues(
    MPInstructionNode *tree, NSArray<MPInstructionFile *> *hierarchy)
{
    NSMutableArray<MPInstructionIssue *> *issues = [NSMutableArray array];
    if (tree)
        MPCollectIssues(tree, issues);

    // The files themselves: too long to be read well, or too long to be read
    // at all.
    for (MPInstructionFile *file in hierarchy)
    {
        if (!file.exists)
            continue;
        if (file.size > kMPFileIgnoredAbove)
        {
            [issues addObject:MPIssue(NSLocalizedString(
                @"more than 4 MiB: the loader skips it altogether",
                @"Instruction file issue"), file.fileURL, 0)];
        }
        else if (file.lines > kMPComfortableLines)
        {
            [issues addObject:MPIssue([NSString stringWithFormat:
                NSLocalizedString(
                    @"%lu lines: above the two hundred recommended",
                    @"Instruction file issue"),
                (unsigned long)file.lines], file.fileURL, 0)];
        }
    }

    // An AGENTS.md that nothing imports is an AGENTS.md Claude Code does not
    // read: it reads CLAUDE.md, and the way to share one is to import it.
    NSMutableSet<NSString *> *imported = [NSMutableSet set];
    NSMutableArray<MPInstructionNode *> *stack = [NSMutableArray array];
    if (tree)
        [stack addObject:tree];
    while (stack.count)
    {
        MPInstructionNode *node = stack.lastObject;
        [stack removeLastObject];
        for (MPInstructionNode *child in node.imports)
        {
            [imported addObject:child.fileURL.path];
            [stack addObject:child];
        }
    }
    for (MPInstructionFile *file in hierarchy)
    {
        if (file.scope != MPInstructionScopeAgents || !file.exists)
            continue;
        if ([imported containsObject:file.fileURL.path])
            continue;
        [issues addObject:MPIssue(NSLocalizedString(
            @"Claude Code does not read AGENTS.md: import it from the "
            @"CLAUDE.md beside it, with @AGENTS.md",
            @"Instruction file issue"), file.fileURL, 0)];
    }
    return issues;
}
