//
//  MPActionLog.m
//  MacDown
//

#import "MPActionLog.h"
#import "MPGlobals.h"

/// Big enough for a session, small enough to read and to send.
static const unsigned long long kMPActionLogLimit = 2 * 1024 * 1024;


@interface MPActionLog ()
@property (strong, nonatomic) NSFileHandle *handle;
@property (strong, nonatomic) NSDateFormatter *clock;
@property (nonatomic) NSUInteger counter;
/// Every write happens here, so lines cannot arrive shuffled.
@property (strong, nonatomic) dispatch_queue_t queue;
@end


@implementation MPActionLog

+ (instancetype)sharedLog
{
    static MPActionLog *shared = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    // Read from the preferences rather than waiting for the menu item: a
    // recording that only starts when somebody clicks cannot record what
    // happens at launch, which is where a document reads its headings.
    _recording = [[NSUserDefaults standardUserDefaults]
        boolForKey:@"diagnosticsRecording"];
    _queue = dispatch_queue_create("com.macdown.actionlog",
                                   DISPATCH_QUEUE_SERIAL);
    _clock = [[NSDateFormatter alloc] init];
    _clock.dateFormat = @"HH:mm:ss.SSS";
    _clock.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return self;
}

- (NSURL *)fileURL
{
    // Beside the system's own logs, which is where somebody looking for a
    // log looks, and where Console shows it.
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(
        NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *folder = [libraries.firstObject
        stringByAppendingPathComponent:
            [@"Logs" stringByAppendingPathComponent:kMPApplicationName]];
    return [NSURL fileURLWithPath:
        [folder stringByAppendingPathComponent:@"actions.log"]];
}

- (void)setRecording:(BOOL)recording
{
    if (_recording == recording)
        return;

    if (!recording)
    {
        // Written while it is still on: a note taken after the flag has
        // gone down is a note that goes nowhere, which is how this line
        // was missing the first time.
        [self note:@"— recording stopped —"];
        _recording = NO;
        // Both go through the one queue, so the closing happens after the
        // line above has been written and not instead of it.
        dispatch_sync(self.queue, ^{
            [self.handle closeFile];
            self.handle = nil;
        });
        return;
    }

    _recording = YES;
    [self note:@"— recording started (%@ %@) —",
        kMPApplicationName,
        [NSBundle mainBundle].infoDictionary[
            @"CFBundleShortVersionString"] ?: @"?"];
}

/// The file, opened at the end, made if it is not there.
- (NSFileHandle *)openHandle
{
    if (self.handle)
        return self.handle;

    NSURL *url = self.fileURL;
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:url.URLByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:NULL];
    if (![manager fileExistsAtPath:url.path])
        [manager createFileAtPath:url.path contents:nil attributes:nil];

    self.handle = [NSFileHandle fileHandleForWritingAtPath:url.path];
    [self.handle seekToEndOfFile];

    // A log that grows for a week is a log nobody reads. Started again
    // rather than rotated: what is wanted is the last attempt.
    if ([self.handle offsetInFile] > kMPActionLogLimit)
    {
        [self.handle truncateFileAtOffset:0];
        [self.handle seekToEndOfFile];
    }
    return self.handle;
}

- (void)note:(NSString *)format, ...
{
    if (!self.recording || !format.length)
        return;

    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format
                                            arguments:arguments];
    va_end(arguments);

    NSString *stamp = [self.clock stringFromDate:[NSDate date]];
    dispatch_async(self.queue, ^{
        self.counter++;
        NSString *written = [NSString stringWithFormat:@"%@  %4lu  %@\n",
            stamp, (unsigned long)self.counter, line];
        [[self openHandle] writeData:
            [written dataUsingEncoding:NSUTF8StringEncoding]];
    });
}

- (NSString *)text
{
    __block NSString *text = nil;
    dispatch_sync(self.queue, ^{
        text = [NSString stringWithContentsOfURL:self.fileURL
                                        encoding:NSUTF8StringEncoding
                                           error:NULL] ?: @"";
    });
    return text;
}

- (void)clear
{
    dispatch_sync(self.queue, ^{
        [self.handle closeFile];
        self.handle = nil;
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL
                                                  error:NULL];
        self.counter = 0;
    });
}

@end
