//
//  MPUpdate.m
//  MacDown
//

#import "MPUpdate.h"


static NSString * const kMPReleasesFeed =
    @"https://api.github.com/repos/nicolorisitano82/macdown-next/releases/"
    @"latest";
static NSString * const kMPErrorDomain = @"MPUpdate";
static const NSTimeInterval kMPCheckEvery = 24 * 60 * 60;


@interface MPRelease ()
@property (copy, nonatomic) NSString *version;
@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *notes;
@property (copy, nonatomic) NSURL *pageURL;
@property (copy, nonatomic) NSURL *diskImageURL;
@property (nonatomic) long long size;
@end

@implementation MPRelease
@end


#pragma mark - Versions

/// A version taken apart: its numbers, and how far past them a build is.
///
/// `0.22.0d7` is seven commits into what will become 0.22.0, so it counts
/// as 0.22.0 with a mark against it — behind the release of the same name,
/// ahead of everything before.
static NSArray<NSNumber *> *MPVersionParts(NSString *version, NSInteger *dev)
{
    if (dev)
        *dev = -1;      // Not a development build at all.
    if (!version.length)
        return @[];

    NSString *text = version;
    if ([text hasPrefix:@"v"] || [text hasPrefix:@"V"])
        text = [text substringFromIndex:1];

    NSRange marker = [text rangeOfString:@"d" options:NSBackwardsSearch];
    if (marker.location != NSNotFound && marker.location > 0)
    {
        NSString *count = [text substringFromIndex:NSMaxRange(marker)];
        NSScanner *scanner = [NSScanner scannerWithString:count];
        NSInteger commits = 0;
        if (count.length && [scanner scanInteger:&commits]
            && scanner.isAtEnd && commits >= 0)
        {
            if (dev)
                *dev = commits;
            text = [text substringToIndex:marker.location];
        }
    }

    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *piece in [text componentsSeparatedByString:@"."])
    {
        NSScanner *scanner = [NSScanner scannerWithString:piece];
        NSInteger number = 0;
        [scanner scanInteger:&number];
        [parts addObject:@(number)];
    }
    return parts;
}


NSComparisonResult MPCompareVersions(NSString *one, NSString *other)
{
    NSInteger oneDev = -1;
    NSInteger otherDev = -1;
    NSArray *a = MPVersionParts(one, &oneDev);
    NSArray *b = MPVersionParts(other, &otherDev);

    NSUInteger count = MAX(a.count, b.count);
    for (NSUInteger i = 0; i < count; i++)
    {
        // A version with fewer parts is read as if the rest were zeroes,
        // so 0.22 and 0.22.0 are the same version.
        NSInteger left = i < a.count ? [a[i] integerValue] : 0;
        NSInteger right = i < b.count ? [b[i] integerValue] : 0;
        if (left != right)
            return left < right ? NSOrderedAscending : NSOrderedDescending;
    }

    // Same numbers: a build on the way to a release is behind the release.
    if (oneDev == otherDev)
        return NSOrderedSame;
    if (oneDev < 0)
        return NSOrderedDescending;
    if (otherDev < 0)
        return NSOrderedAscending;
    return oneDev < otherDev ? NSOrderedAscending : NSOrderedDescending;
}


BOOL MPUpdateIsNewer(MPRelease *release, NSString *running)
{
    if (!release.version.length || !release.diskImageURL)
        return NO;
    if (!running.length)
        return YES;     // Nothing to compare against: better to say.
    return MPCompareVersions(release.version, running) == NSOrderedDescending;
}


BOOL MPUpdateIsDue(NSDate *lastCheck, NSDate *now)
{
    if (!lastCheck)
        return YES;
    NSTimeInterval since = [(now ?: [NSDate date]) timeIntervalSinceDate:
                            lastCheck];
    // A clock that has gone backwards — or a date from the future — should
    // not stop the application from ever looking again.
    return since < 0.0 || since >= kMPCheckEvery;
}


#pragma mark - Reading the answer

BOOL MPIsTrustedDownload(NSURL *url)
{
    if (![url.scheme.lowercaseString isEqualToString:@"https"])
        return NO;
    NSString *host = url.host.lowercaseString;
    for (NSString *trusted in @[@"github.com", @"objects.githubusercontent.com",
                                @"release-assets.githubusercontent.com"])
    {
        if ([host isEqualToString:trusted]
            || [host hasSuffix:[@"." stringByAppendingString:trusted]])
            return YES;
    }
    return NO;
}


MPRelease *MPReleaseFromFeed(NSData *json)
{
    if (!json.length)
        return nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:json options:0
                                                  error:NULL];
    if (![parsed isKindOfClass:[NSDictionary class]])
        return nil;

    NSDictionary *feed = parsed;
    // A draft is not out yet, whatever it says about itself.
    if ([feed[@"draft"] boolValue])
        return nil;

    NSString *tag = feed[@"tag_name"];
    if (![tag isKindOfClass:[NSString class]] || !tag.length)
        return nil;

    MPRelease *release = [[MPRelease alloc] init];
    release.version = [tag hasPrefix:@"v"] ? [tag substringFromIndex:1] : tag;
    release.title = [feed[@"name"] isKindOfClass:[NSString class]]
        ? feed[@"name"] : release.version;
    release.notes = [feed[@"body"] isKindOfClass:[NSString class]]
        ? feed[@"body"] : @"";
    if ([feed[@"html_url"] isKindOfClass:[NSString class]])
        release.pageURL = [NSURL URLWithString:feed[@"html_url"]];

    for (id item in feed[@"assets"])
    {
        if (![item isKindOfClass:[NSDictionary class]])
            continue;
        NSString *name = item[@"name"];
        NSString *address = item[@"browser_download_url"];
        if (![name isKindOfClass:[NSString class]]
            || ![address isKindOfClass:[NSString class]]
            || ![name.pathExtension.lowercaseString isEqualToString:@"dmg"])
            continue;

        NSURL *url = [NSURL URLWithString:address];
        if (!MPIsTrustedDownload(url))
            continue;
        release.diskImageURL = url;
        release.size = [item[@"size"] longLongValue];
        break;
    }
    // A release with nothing to download is a release nobody can install.
    return release.diskImageURL ? release : nil;
}


#pragma mark - Where it goes

NSURL *MPDownloadsFolder(void)
{
    NSArray *folders = [[NSFileManager defaultManager]
        URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask];
    return folders.firstObject
        ?: [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
}


NSURL *MPFreeFileInFolder(NSURL *folder, NSString *name)
{
    if (!folder || !name.length)
        return nil;

    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *file = [folder URLByAppendingPathComponent:name];
    if (![manager fileExistsAtPath:file.path])
        return file;

    // The same name the browser would settle on, rather than overwriting a
    // file somebody may have kept on purpose.
    NSString *stem = name.stringByDeletingPathExtension;
    NSString *extension = name.pathExtension;
    for (NSUInteger i = 2; i < 1000; i++)
    {
        NSString *tried = [NSString stringWithFormat:@"%@ %lu", stem,
                           (unsigned long)i];
        if (extension.length)
            tried = [tried stringByAppendingPathExtension:extension];
        file = [folder URLByAppendingPathComponent:tried];
        if (![manager fileExistsAtPath:file.path])
            return file;
    }
    return nil;
}


double MPProgressFraction(long long received, long long total)
{
    if (total <= 0 || received < 0)
        return -1.0;    // The server did not say how big it is.
    if (received >= total)
        return 1.0;
    return (double)received / (double)total;
}


#pragma mark - Asking the repository

@implementation MPUpdateCheck

+ (void)latestReleaseWithCompletion:(void (^)(MPRelease *, NSError *))completion
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:kMPReleasesFeed]
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
        timeoutInterval:20.0];
    [request setValue:@"application/vnd.github+json"
        forHTTPHeaderField:@"Accept"];
    // GitHub asks callers to name themselves, and a name is all it gets:
    // no account, no token, nothing about the machine.
    NSString *version = [NSBundle mainBundle]
        .infoDictionary[@"CFBundleShortVersionString"] ?: @"0";
    [request setValue:[@"MacDownNext/" stringByAppendingString:version]
        forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response,
                              NSError *error) {
        MPRelease *release = nil;
        NSError *trouble = error;
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (!trouble && status != 200)
        {
            trouble = [NSError errorWithDomain:kMPErrorDomain code:status
                userInfo:@{NSLocalizedDescriptionKey: [NSString
                    stringWithFormat:NSLocalizedString(
                        @"The releases feed answered %ld.",
                        @"HTTP status from the releases feed"),
                    (long)status]}];
        }
        if (!trouble)
        {
            release = MPReleaseFromFeed(data);
            if (!release)
            {
                trouble = [NSError errorWithDomain:kMPErrorDomain code:-1
                    userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(
                        @"The latest release carries no disk image.",
                        @"The latest release has no .dmg asset")}];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(release, trouble);
        });
    }];
    [task resume];
}

@end


#pragma mark - Fetching it

@interface MPUpdateDownload () <NSURLSessionDownloadDelegate>
/// What is being fetched. Not called `release`: ARC forbids it.
@property (strong, nonatomic) MPRelease *wanted;
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSURLSessionDownloadTask *task;
@property (copy, nonatomic) void (^progress)(double, long long, long long);
@property (copy, nonatomic) void (^completion)(NSURL *, NSError *);
@property (copy, nonatomic) NSURL *fileURL;
@property (nonatomic, getter=isRunning) BOOL running;
@end


@implementation MPUpdateDownload

- (instancetype)initWithRelease:(MPRelease *)release
{
    self = [super init];
    if (self)
        _wanted = release;
    return self;
}

- (void)startWithProgress:(void (^)(double, long long, long long))progress
               completion:(void (^)(NSURL *, NSError *))completion
{
    self.progress = progress;
    self.completion = completion;

    if (!MPIsTrustedDownload(self.wanted.diskImageURL))
    {
        [self finishWith:nil error:[NSError errorWithDomain:kMPErrorDomain
            code:-2 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(
                @"The update's address is not GitHub's.",
                @"Refusing to download an update from elsewhere")}]];
        return;
    }

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:configuration
        delegate:self delegateQueue:nil];
    self.task = [self.session downloadTaskWithURL:self.wanted.diskImageURL];
    self.running = YES;
    [self.task resume];
}

- (void)cancel
{
    if (!self.running)
        return;
    [self.task cancel];
}

- (void)finishWith:(NSURL *)file error:(NSError *)error
{
    void (^completion)(NSURL *, NSError *) = self.completion;
    self.completion = nil;
    self.progress = nil;
    self.running = NO;
    [self.session finishTasksAndInvalidate];
    self.session = nil;
    if (!completion)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(file, error);
    });
}


#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)task
      didWriteData:(int64_t)written
 totalBytesWritten:(int64_t)received
totalBytesExpectedToWrite:(int64_t)total
{
    void (^progress)(double, long long, long long) = self.progress;
    if (!progress)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        progress(MPProgressFraction(received, total), received, total);
    });
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(NSURL *)location
{
    // The file is handed over in a temporary place that stops existing the
    // moment this method returns, so it is moved here and not later.
    NSInteger status = [(NSHTTPURLResponse *)task.response statusCode];
    if (status != 200)
    {
        [self finishWith:nil error:[NSError errorWithDomain:kMPErrorDomain
            code:status userInfo:@{NSLocalizedDescriptionKey: [NSString
                stringWithFormat:NSLocalizedString(
                    @"The download answered %ld.",
                    @"HTTP status while downloading the update"),
                (long)status]}]];
        return;
    }

    NSString *name = self.wanted.diskImageURL.lastPathComponent;
    NSURL *destination = MPFreeFileInFolder(MPDownloadsFolder(), name);
    NSError *error = nil;
    if (!destination
        || ![[NSFileManager defaultManager] moveItemAtURL:location
                                                   toURL:destination
                                                   error:&error])
    {
        [self finishWith:nil error:error];
        return;
    }
    self.fileURL = destination;
    [self finishWith:destination error:nil];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    if (!error || !self.completion)
        return;     // A download that arrived is finished above.
    if (error.code == NSURLErrorCancelled)
    {
        error = [NSError errorWithDomain:kMPErrorDomain code:NSUserCancelledError
            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(
                @"The download was stopped.",
                @"The download was stopped by the user")}];
    }
    [self finishWith:nil error:error];
}

@end
