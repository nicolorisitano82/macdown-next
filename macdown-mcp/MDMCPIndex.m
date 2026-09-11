//
//  MDMCPIndex.m
//  macdownext-mcp
//

#import "MDMCPIndex.h"


@interface MDMCPHit ()
@property (copy, nonatomic) NSURL *document;
@property (nonatomic) NSUInteger line;
@property (copy, nonatomic) NSString *text;
@end

@implementation MDMCPHit
@end


/// What is kept about one document: enough to know whether it has changed,
/// and the lines themselves.
@interface MDMCPEntry : NSObject
@property (copy, nonatomic) NSDate *modified;
@property (nonatomic) unsigned long long size;
@property (copy, nonatomic) NSArray<NSString *> *lines;
@end

@implementation MDMCPEntry
@end


@interface MDMCPIndex ()
@property (nonatomic) MDMCPPerimeter *perimeter;
@property (nonatomic) NSMutableDictionary<NSString *, MDMCPEntry *> *entries;
@property (copy, nonatomic) NSArray<NSURL *> *order;
@property (nonatomic) NSUInteger lastReadCount;
@end


@implementation MDMCPIndex

- (instancetype)initWithPerimeter:(MDMCPPerimeter *)perimeter
{
    self = [super init];
    if (self)
    {
        _perimeter = perimeter;
        _entries = [NSMutableDictionary dictionary];
        _order = @[];
    }
    return self;
}


- (NSUInteger)documentCount
{
    return self.entries.count;
}


- (void)refresh
{
    NSArray<NSURL *> *documents = [self.perimeter filesUnder:nil];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSUInteger read = 0;

    for (NSURL *document in documents)
    {
        [seen addObject:document.path];
        NSURL *text = [MDMCPPerimeter textFileFor:document];
        NSDate *modified = nil;
        NSNumber *size = nil;
        [text getResourceValue:&modified
                        forKey:NSURLContentModificationDateKey error:NULL];
        [text getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];

        MDMCPEntry *entry = self.entries[document.path];
        // Same second and same size: the file system says nothing has
        // happened, and reading it again would be work for its own sake.
        if (entry && [entry.modified isEqualToDate:modified]
                && entry.size == size.unsignedLongLongValue)
            continue;

        NSString *whole = [NSString stringWithContentsOfURL:text
            encoding:NSUTF8StringEncoding error:NULL];
        if (!whole)
        {
            [self.entries removeObjectForKey:document.path];
            continue;
        }
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        [whole enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            [lines addObject:line];
        }];

        entry = [[MDMCPEntry alloc] init];
        entry.modified = modified;
        entry.size = size.unsignedLongLongValue;
        entry.lines = lines;
        self.entries[document.path] = entry;
        read++;
    }

    // Documents that have gone are forgotten rather than answered about.
    for (NSString *known in self.entries.allKeys)
    {
        if (![seen containsObject:known])
            [self.entries removeObjectForKey:known];
    }
    self.order = documents;
    self.lastReadCount = read;
}


- (NSArray<MDMCPHit *> *)search:(NSString *)query limit:(NSUInteger)limit
                            cut:(BOOL *)cut
{
    [self refresh];

    NSMutableArray<MDMCPHit *> *hits = [NSMutableArray array];
    BOOL full = NO;
    for (NSURL *document in self.order)
    {
        MDMCPEntry *entry = self.entries[document.path];
        NSUInteger number = 0;
        for (NSString *line in entry.lines)
        {
            number++;
            if ([line rangeOfString:query
                            options:NSCaseInsensitiveSearch].location
                    == NSNotFound)
                continue;

            MDMCPHit *hit = [[MDMCPHit alloc] init];
            hit.document = document;
            hit.line = number;
            hit.text = [line stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            [hits addObject:hit];
            if (hits.count >= limit)
            {
                full = YES;
                break;
            }
        }
        if (full)
            break;
    }
    if (cut)
        *cut = full;
    return hits;
}


- (NSString *)textOf:(NSURL *)document
{
    [self refresh];
    MDMCPEntry *entry = self.entries[document.path];
    if (!entry)
        return nil;
    return [entry.lines componentsJoinedByString:@"\n"];
}

@end
