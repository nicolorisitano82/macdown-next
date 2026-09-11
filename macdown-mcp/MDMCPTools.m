//
//  MDMCPTools.m
//  macdownext-mcp
//

#import "MDMCPTools.h"

#import "MPBacklinks.h"
#import "NSString+Lookup.h"


/// How many answers a search gives back unless asked for fewer.
static const NSUInteger kMDSearchLimit = 50;

/// How many lines a read hands over when it is not told. Past this the
/// answer says it was cut, as the Finder preview does.
static const NSUInteger kMDReadLines = 500;


/** Enough of a map to answer «what does this document declare».
 *
 * The front matter comes back as an ordered dictionary — the application
 * wants the fields in the order they were written — and that is not an
 * NSDictionary. For an answer the order does not matter and the two are the
 * same thing, so they are asked the two questions they both answer.
 */
@protocol MDMCPMap <NSObject>
- (NSArray *)allKeys;
- (id)objectForKey:(id)key;
@end

static id<MDMCPMap> MDMCPMapOrNil(id value)
{
    if ([value respondsToSelector:@selector(allKeys)]
            && [value respondsToSelector:@selector(objectForKey:)])
        return (id<MDMCPMap>)value;
    return nil;
}


/// What YAML gives back is not always what JSON takes: a date, a set, a key
/// that is not a string. Anything unexpected is handed over as the text it
/// prints as, because an answer the client cannot parse is worse than an
/// approximate one.
static id MDMCPJSONSafe(id value)
{
    if ([value isKindOfClass:[NSString class]]
            || [value isKindOfClass:[NSNumber class]]
            || [value isKindOfClass:[NSNull class]])
        return value;
    if ([value isKindOfClass:[NSArray class]])
    {
        NSMutableArray *safe = [NSMutableArray array];
        for (id one in value)
            [safe addObject:MDMCPJSONSafe(one)];
        return safe;
    }
    id<MDMCPMap> map = MDMCPMapOrNil(value);
    if (map)
    {
        NSMutableDictionary *safe = [NSMutableDictionary dictionary];
        for (id key in [map allKeys])
        {
            NSString *name = [key isKindOfClass:[NSString class]]
                ? key : [key description];
            safe[name] = MDMCPJSONSafe([map objectForKey:key]);
        }
        return safe;
    }
    return [value description];
}


/// Whether a front matter field answers to `wanted`.
///
/// A field that holds a list answers when any of its items does — `tags:
/// [iso, qualità]` is found by `iso` — and the comparison ignores case,
/// because a person writing a note and a person asking for it later are the
/// same person on two different days.
static BOOL MDMCPFieldAnswers(id field, NSString *wanted)
{
    if (!wanted.length)
        return YES;
    if ([field isKindOfClass:[NSArray class]])
    {
        for (id one in field)
        {
            if (MDMCPFieldAnswers(one, wanted))
                return YES;
        }
        return NO;
    }
    NSString *text = [field isKindOfClass:[NSString class]]
        ? field : [field description];
    return [text caseInsensitiveCompare:wanted] == NSOrderedSame;
}


NSArray<NSDictionary *> *MDMCPOutlineOfMarkdown(NSString *text)
{
    NSMutableArray<NSDictionary *> *headings = [NSMutableArray array];
    __block BOOL inFence = NO;
    __block NSUInteger number = 0;

    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        number++;
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        if ([trimmed hasPrefix:@"```"] || [trimmed hasPrefix:@"~~~"])
        {
            inFence = !inFence;
            return;
        }
        if (inFence || ![trimmed hasPrefix:@"#"])
            return;

        NSUInteger level = 0;
        while (level < trimmed.length && [trimmed characterAtIndex:level] == '#')
            level++;
        // The space is what tells a heading from a hashtag, here as
        // everywhere else in this application.
        if (level > 6 || level >= trimmed.length
                || [trimmed characterAtIndex:level] != ' ')
            return;

        NSString *title = [[trimmed substringFromIndex:level + 1]
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
        if (!title.length)
            return;
        [headings addObject:@{@"level": @(level), @"title": title,
                              @"line": @(number)}];
    }];
    return headings;
}


@interface MDMCPTools ()
@property (nonatomic) MDMCPPerimeter *perimeter;
@property (nonatomic) MDMCPIndex *index;
@end


@implementation MDMCPTools

- (instancetype)initWithPerimeter:(MDMCPPerimeter *)perimeter
{
    self = [super init];
    if (self)
    {
        _perimeter = perimeter;
        _index = [[MDMCPIndex alloc] initWithPerimeter:perimeter];
    }
    return self;
}


- (NSArray<NSDictionary *> *)declarations
{
    NSDictionary *path = @{@"type": @"string",
        @"description": @"Path of the file, relative to the folder this "
                        @"server was given, or absolute inside it."};
    return @[
        @{@"name": @"search",
          @"description": @"Find a word or a phrase in the folder. Answers "
                          @"the file, the line number and the line itself. "
                          @"Reads Markdown and text files only, and never "
                          @"leaves the folder it was given.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"query": @{@"type": @"string",
                            @"description": @"What to look for."},
                @"limit": @{@"type": @"integer",
                            @"description": @"At most this many answers."}},
             @"required": @[@"query"]}},
        @{@"name": @"read",
          @"description": @"Read a document. Long files come back cut, and "
                          @"the answer says so.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"path": path,
                @"from": @{@"type": @"integer",
                           @"description": @"First line, counting from 1."},
                @"lines": @{@"type": @"integer",
                            @"description": @"How many lines to read."}},
             @"required": @[@"path"]}},
        @{@"name": @"list",
          @"description": @"What documents are in the folder, with their "
                          @"size and when they changed.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"folder": @{@"type": @"string",
                             @"description": @"A folder inside the one the "
                                             @"server was given."}}}},
        @{@"name": @"outline",
          @"description": @"The headings of a document, with their level "
                          @"and their line, which is the shape of it.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"path": path}, @"required": @[@"path"]}},
        @{@"name": @"backlinks",
          @"description": @"Which documents cite this one, with the line and "
                          @"the sentence around it. Counts [[wiki links]] "
                          @"and Markdown links whose destination resolves to "
                          @"the same file; what is inside code is not a "
                          @"citation.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"path": path}, @"required": @[@"path"]}},
        @{@"name": @"frontmatter",
          @"description": @"The YAML front matter of a document, as a map. "
                          @"Says so plainly when the document has none.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"path": path}, @"required": @[@"path"]}},
        @{@"name": @"find_by_field",
          @"description": @"The documents whose front matter declares a "
                          @"field — and, if a value is given, declares it "
                          @"with that value. A field holding a list answers "
                          @"when any of its items does.",
          @"inputSchema": @{@"type": @"object", @"properties": @{
                @"field": @{@"type": @"string",
                            @"description": @"The name of the field."},
                @"value": @{@"type": @"string",
                            @"description": @"What it should say. Left out, "
                                            @"every document that declares "
                                            @"the field answers."}},
             @"required": @[@"field"]}},
    ];
}


- (NSDictionary *)run:(NSString *)tool
            arguments:(NSDictionary *)arguments
                error:(NSString **)error
{
    if ([tool isEqualToString:@"search"])
        return [self searchFor:arguments[@"query"]
                         limit:[arguments[@"limit"] unsignedIntegerValue]
                         error:error];
    if ([tool isEqualToString:@"read"])
        return [self read:arguments[@"path"]
                     from:[arguments[@"from"] unsignedIntegerValue]
                    lines:[arguments[@"lines"] unsignedIntegerValue]
                    error:error];
    if ([tool isEqualToString:@"list"])
        return [self list:arguments[@"folder"] error:error];
    if ([tool isEqualToString:@"outline"])
        return [self outline:arguments[@"path"] error:error];
    if ([tool isEqualToString:@"backlinks"])
        return [self backlinksTo:arguments[@"path"] error:error];
    if ([tool isEqualToString:@"frontmatter"])
        return [self frontMatterOf:arguments[@"path"] error:error];
    if ([tool isEqualToString:@"find_by_field"])
        return [self documentsDeclaring:arguments[@"field"]
                                     as:arguments[@"value"]
                                  error:error];

    if (error)
        *error = [NSString stringWithFormat:@"there is no tool called %@",
                  tool];
    return nil;
}


#pragma mark - Reading the folder

- (NSDictionary *)searchFor:(NSString *)query
                      limit:(NSUInteger)limit
                      error:(NSString **)error
{
    if (![query isKindOfClass:[NSString class]] || !query.length)
    {
        if (error)
            *error = @"search needs something to look for";
        return nil;
    }
    if (!limit || limit > 500)
        limit = kMDSearchLimit;

    BOOL cut = NO;
    NSMutableArray<NSDictionary *> *hits = [NSMutableArray array];
    for (MDMCPHit *hit in [self.index search:query limit:limit cut:&cut])
    {
        [hits addObject:@{@"path": [self relative:hit.document],
                          @"line": @(hit.line),
                          @"text": hit.text}];
    }
    return @{@"query": query, @"found": @(hits.count), @"cut": @(cut),
             @"searched": @(self.index.documentCount),
             @"read": @(self.index.lastReadCount),
             @"hits": hits};
}


- (NSDictionary *)read:(NSString *)path
                  from:(NSUInteger)from
                 lines:(NSUInteger)wanted
                 error:(NSString **)error
{
    MDMCPVerdict verdict = MDMCPAllowed;
    NSURL *url = [self.perimeter urlForPath:path verdict:&verdict];
    if (!url)
    {
        if (error)
            *error = [MDMCPPerimeter reasonFor:verdict];
        return nil;
    }

    NSString *text = [NSString stringWithContentsOfURL:
        [MDMCPPerimeter textFileFor:url]
        encoding:NSUTF8StringEncoding error:NULL];
    if (!text)
    {
        if (error)
            *error = @"that file is not text this server can read";
        return nil;
    }

    NSMutableArray<NSString *> *all = [NSMutableArray array];
    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        [all addObject:line];
    }];

    NSUInteger first = from > 0 ? from - 1 : 0;
    if (first > all.count)
        first = all.count;
    NSUInteger count = wanted ?: kMDReadLines;
    if (first + count > all.count)
        count = all.count - first;

    NSArray<NSString *> *piece = [all subarrayWithRange:
        NSMakeRange(first, count)];
    BOOL cut = (first + count) < all.count || first > 0;
    return @{@"path": [self relative:url],
             @"from": @(first + 1),
             @"lines": @(count),
             @"of": @(all.count),
             @"cut": @(cut),
             @"text": [piece componentsJoinedByString:@"\n"]};
}


- (NSDictionary *)list:(NSString *)folder error:(NSString **)error
{
    NSURL *url = nil;
    if (folder.length)
    {
        MDMCPVerdict verdict = MDMCPAllowed;
        url = [self.perimeter urlForPath:folder verdict:&verdict];
        if (!url)
        {
            if (error)
                *error = [MDMCPPerimeter reasonFor:verdict];
            return nil;
        }
    }

    NSMutableArray<NSDictionary *> *files = [NSMutableArray array];
    for (NSURL *file in [self.perimeter filesUnder:url])
    {
        NSNumber *size = nil;
        NSDate *changed = nil;
        [file getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
        [file getResourceValue:&changed forKey:NSURLContentModificationDateKey
                         error:NULL];
        [files addObject:@{@"path": [self relative:file],
                           @"bytes": size ?: @0,
                           @"modified": changed
                               ? [self stamp:changed] : @""}];
    }
    return @{@"count": @(files.count), @"files": files};
}


- (NSDictionary *)outline:(NSString *)path error:(NSString **)error
{
    MDMCPVerdict verdict = MDMCPAllowed;
    NSURL *url = [self.perimeter urlForPath:path verdict:&verdict];
    if (!url)
    {
        if (error)
            *error = [MDMCPPerimeter reasonFor:verdict];
        return nil;
    }
    NSString *text = [NSString stringWithContentsOfURL:
        [MDMCPPerimeter textFileFor:url]
        encoding:NSUTF8StringEncoding error:NULL];
    if (!text)
    {
        if (error)
            *error = @"that file is not text this server can read";
        return nil;
    }
    NSArray<NSDictionary *> *headings = MDMCPOutlineOfMarkdown(text);
    return @{@"path": [self relative:url], @"count": @(headings.count),
             @"headings": headings};
}


#pragma mark - Reading it as a set of notes

- (NSDictionary *)backlinksTo:(NSString *)path error:(NSString **)error
{
    MDMCPVerdict verdict = MDMCPAllowed;
    NSURL *url = [self.perimeter urlForPath:path verdict:&verdict];
    if (!url)
    {
        if (error)
            *error = [MDMCPPerimeter reasonFor:verdict];
        return nil;
    }

    NSMutableArray<NSDictionary *> *citations = [NSMutableArray array];
    [self.index eachDocument:^(NSURL *document, NSString *text) {
        // A document does not cite itself: MPBacklinksInText says so, and
        // says it once for the application and for this server both.
        for (MPBacklink *link in MPBacklinksInText(text, document, url))
        {
            [citations addObject:@{@"path": [self relative:document],
                                   @"title": link.title ?: @"",
                                   @"line": @(link.line),
                                   @"text": link.context ?: @""}];
        }
    }];

    return @{@"path": [self relative:url],
             @"found": @(citations.count),
             @"searched": @(self.index.documentCount),
             @"read": @(self.index.lastReadCount),
             @"citations": citations};
}


- (NSDictionary *)frontMatterOf:(NSString *)path error:(NSString **)error
{
    MDMCPVerdict verdict = MDMCPAllowed;
    NSURL *url = [self.perimeter urlForPath:path verdict:&verdict];
    if (!url)
    {
        if (error)
            *error = [MDMCPPerimeter reasonFor:verdict];
        return nil;
    }
    NSString *text = [NSString stringWithContentsOfURL:
        [MDMCPPerimeter textFileFor:url]
        encoding:NSUTF8StringEncoding error:NULL];
    if (!text)
    {
        if (error)
            *error = @"that file is not text this server can read";
        return nil;
    }

    // Front matter that is not a map — a bare list between the dashes — is
    // no answer to «what does this document declare», so it counts as none.
    id<MDMCPMap> fields = MDMCPMapOrNil([text frontMatter:NULL]);
    if (!fields)
        return @{@"path": [self relative:url], @"has": @NO, @"fields": @{}};

    return @{@"path": [self relative:url], @"has": @YES,
             @"fields": MDMCPJSONSafe(fields)};
}


- (NSDictionary *)documentsDeclaring:(NSString *)field
                                  as:(NSString *)value
                               error:(NSString **)error
{
    if (![field isKindOfClass:[NSString class]] || !field.length)
    {
        if (error)
            *error = @"find_by_field needs the name of a field";
        return nil;
    }
    NSString *wanted = [value isKindOfClass:[NSString class]] ? value : nil;

    NSMutableArray<NSDictionary *> *documents = [NSMutableArray array];
    [self.index eachDocument:^(NSURL *document, NSString *text) {
        id<MDMCPMap> fields = MDMCPMapOrNil([text frontMatter:NULL]);
        if (!fields)
            return;
        id declared = [fields objectForKey:field];
        if (!declared || !MDMCPFieldAnswers(declared, wanted))
            return;
        [documents addObject:@{@"path": [self relative:document],
                               @"value": MDMCPJSONSafe(declared)}];
    }];

    return @{@"field": field, @"value": wanted ?: @"",
             @"found": @(documents.count),
             @"searched": @(self.index.documentCount),
             @"read": @(self.index.lastReadCount),
             @"documents": documents};
}


#pragma mark - Saying where something is

/// A path as the caller should see it, which the perimeter decides: it is
/// the one that knows what the root was standardized to.
- (NSString *)relative:(NSURL *)url
{
    return [self.perimeter relativePathFor:url];
}


- (NSString *)stamp:(NSDate *)date
{
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
    });
    return [formatter stringFromDate:date];
}

@end
