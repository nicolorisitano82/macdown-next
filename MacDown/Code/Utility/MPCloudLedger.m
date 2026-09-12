//
//  MPCloudLedger.m
//  MacDown
//

#import "MPCloudLedger.h"


@implementation MPCloudDelta

- (BOOL)isQuiet
{
    return self.added == 0 && self.changed == 0 && self.removed == 0;
}

- (NSString *)summary
{
    if (self.isQuiet)
        return NSLocalizedString(@"nothing has moved",
                                 @"Summary when a look found no changes");

    NSMutableArray<NSString *> *pieces = [NSMutableArray array];
    if (self.added)
        [pieces addObject:[NSString stringWithFormat:
            NSLocalizedString(@"%lu new", @"How many documents are new"),
            (unsigned long)self.added]];
    if (self.changed)
        [pieces addObject:[NSString stringWithFormat:
            NSLocalizedString(@"%lu changed",
                              @"How many documents have changed"),
            (unsigned long)self.changed]];
    if (self.removed)
        [pieces addObject:[NSString stringWithFormat:
            NSLocalizedString(@"%lu gone",
                              @"How many documents are no longer there"),
            (unsigned long)self.removed]];
    return [pieces componentsJoinedByString:
        NSLocalizedString(@", ", @"Between the pieces of a change summary")];
}

@end


@interface MPCloudLedger ()
@property (copy, nonatomic) NSString *service;
@property (strong, nonatomic) NSURL *file;
@property (strong, nonatomic) NSMutableDictionary *documents;
@end


@implementation MPCloudLedger

+ (NSURL *)defaultFolder
{
    NSURL *support = [[[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask] firstObject];
    return [[support URLByAppendingPathComponent:@"MacDown"]
        URLByAppendingPathComponent:@"sync"];
}


+ (instancetype)ledgerFor:(NSString *)service
{
    static NSMutableDictionary *ledgers = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ledgers = [NSMutableDictionary dictionary]; });
    @synchronized (ledgers)
    {
        MPCloudLedger *ledger = ledgers[service ?: @""];
        if (!ledger)
        {
            ledger = [[MPCloudLedger alloc] initWithService:service
                                                   inFolder:[self defaultFolder]];
            ledgers[service ?: @""] = ledger;
        }
        return ledger;
    }
}


- (instancetype)initWithService:(NSString *)service inFolder:(NSURL *)folder
{
    self = [super init];
    if (!self)
        return nil;

    _service = [service copy] ?: @"";
    _documents = [NSMutableDictionary dictionary];
    [[NSFileManager defaultManager] createDirectoryAtURL:folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
    _file = [folder URLByAppendingPathComponent:
        [NSString stringWithFormat:@"%@.plist", _service]];

    NSDictionary *written = [NSDictionary dictionaryWithContentsOfURL:_file];
    _startToken = [written[@"startToken"] copy];
    NSDictionary *documents = written[@"documents"];
    if ([documents isKindOfClass:[NSDictionary class]])
        _documents = [documents mutableCopy];
    return self;
}


- (NSUInteger)count
{
    return self.documents.count;
}


- (NSDictionary *)documentWithIdentifier:(NSString *)identifier
{
    return identifier.length ? self.documents[identifier] : nil;
}


- (MPCloudDelta *)applyChanges:(NSArray<NSDictionary *> *)changes
{
    MPCloudDelta *delta = [[MPCloudDelta alloc] init];
    for (NSDictionary *change in changes)
    {
        if (![change isKindOfClass:[NSDictionary class]])
            continue;
        NSString *identifier = change[@"fileId"];
        if (!identifier.length)
            continue;

        NSDictionary *file = change[@"file"];
        BOOL gone = [change[@"removed"] boolValue]
                 || [file[@"trashed"] boolValue];
        if (gone)
        {
            // Sparito di là. Qui non si cancella niente: il registro
            // dimentica, il file che c'è sul disco resta dov'è.
            if (self.documents[identifier])
            {
                [self.documents removeObjectForKey:identifier];
                delta.removed++;
            }
            continue;
        }
        if (![file isKindOfClass:[NSDictionary class]])
            continue;

        NSDictionary *known = self.documents[identifier];
        NSMutableDictionary *now = [known mutableCopy]
            ?: [NSMutableDictionary dictionary];
        now[@"name"] = file[@"name"] ?: known[@"name"] ?: @"";
        now[@"revision"] = file[@"headRevisionId"]
            ?: known[@"revision"] ?: @"";
        self.documents[identifier] = now;

        if (!known)
            delta.added++;
        else if (![known[@"revision"] isEqualToString:now[@"revision"]])
            delta.changed++;
        // Stessa versione: il servizio racconta anche i cambi di nome e i
        // propri rimescolamenti, e quelli non sono un documento cambiato.
    }
    return delta;
}


- (BOOL)save
{
    NSDictionary *written = @{
        @"startToken": self.startToken ?: @"",
        @"documents": self.documents ?: @{},
    };
    return [written writeToURL:self.file error:NULL];
}


- (void)forget
{
    [self.documents removeAllObjects];
    self.startToken = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.file error:NULL];
}

@end
