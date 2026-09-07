//
//  MPQuickLookExtension.m
//  MacDown
//

#import "MPQuickLookExtension.h"


static NSString * const kMPPlugInKit = @"/usr/bin/pluginkit";
static NSString * const kMPLaunchServices =
    @"/System/Library/Frameworks/CoreServices.framework/Frameworks/"
    @"LaunchServices.framework/Support/lsregister";
static NSString * const kMPExtensionName = @"MacDownQuickLook.appex";
static NSString * const kMPErrorDomain = @"MPQuickLookExtension";

/// Launch Services answers the next question before it has finished with
/// this one, and a registration read back immediately is the old one.
static const useconds_t kMPSettleTime = 3 * 1000 * 1000;


#pragma mark - Reading what the system says

/// Whether a line opens a record: a mark at the left margin, then the
/// identifier and its version — "+    com.esempio.anteprima(1.2)".
NS_INLINE BOOL MPOpensARecord(NSString *line)
{
    if (line.length < 2 || [line hasPrefix:@"\t"])
        return NO;
    NSString *head = [line stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    return head.length && [head hasSuffix:@")"]
        && [head rangeOfString:@"("].location != NSNotFound;
}


NSDictionary *MPQuickLookRecordInListing(NSString *listing,
                                         NSString *identifier)
{
    if (!listing.length || !identifier.length)
        return nil;

    NSMutableDictionary *record = nil;
    for (NSString *line in [listing componentsSeparatedByString:@"\n"])
    {
        if (MPOpensARecord(line))
        {
            if (record)
                break;      // The next record: ours is finished.

            // The mark is the first character; the identifier and version
            // follow it after some spaces.
            NSString *mark = [line substringToIndex:1];
            NSString *body = [[line substringFromIndex:1]
                stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]];
            NSRange bracket =
                [body rangeOfString:@"(" options:NSBackwardsSearch];
            if (bracket.location == NSNotFound
                || ![[body substringToIndex:bracket.location]
                     isEqualToString:identifier])
                continue;

            NSRange versionRange = NSMakeRange(NSMaxRange(bracket),
                body.length - NSMaxRange(bracket) - 1);
            record = [NSMutableDictionary dictionary];
            // Only a mark of "-" means switched off by hand; no mark at all
            // means the reader has never been asked, which is on.
            record[@"enabled"] = @(![mark isEqualToString:@"-"]);
            if (versionRange.length)
                record[@"version"] = [body substringWithRange:versionRange];
            continue;
        }

        // "	            Path = /Applications/…", but only inside our own.
        NSRange equals = [line rangeOfString:@" = "];
        if (!record || equals.location == NSNotFound)
            continue;
        NSString *field = [[line substringToIndex:equals.location]
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
        NSString *value = [line substringFromIndex:NSMaxRange(equals)];
        if ([field isEqualToString:@"Path"])
            record[@"path"] = value;
        else if ([field isEqualToString:@"Parent Bundle"])
            record[@"parent"] = value;
    }
    return record;
}


/// Two paths that name the same place, whatever they look like.
NS_INLINE BOOL MPSamePlace(NSURL *one, NSURL *other)
{
    if (!one || !other)
        return NO;
    NSString *a = one.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;
    NSString *b = other.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;
    return [a isEqualToString:b];
}


MPQuickLookExtensionState MPQuickLookStateForRecord(
    NSDictionary *record, NSURL *bundledURL, NSString *bundledVersion)
{
    if (!bundledURL)
        return MPQuickLookExtensionStateMissing;
    if (!record)
        return MPQuickLookExtensionStateNotInstalled;

    NSString *path = record[@"path"];
    NSURL *registered = path.length ? [NSURL fileURLWithPath:path] : nil;
    if (registered && !MPSamePlace(registered, bundledURL))
        return MPQuickLookExtensionStateElsewhere;

    // Registered from here, so the only question left is which build. An
    // application updated in place leaves the old version registered, and
    // that is the case this panel exists for.
    NSString *version = record[@"version"];
    if (bundledVersion.length && version.length
        && ![version isEqualToString:bundledVersion])
        return MPQuickLookExtensionStateOutdated;

    if (![record[@"enabled"] boolValue])
        return MPQuickLookExtensionStateDisabled;

    return MPQuickLookExtensionStateInstalled;
}


#pragma mark - Running the tools that know

/// Runs a tool and waits. Returns nil when the tool could not be run at all.
static NSString *MPRun(NSString *tool, NSArray<NSString *> *arguments,
                       int *status)
{
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:tool])
        return nil;

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:tool];
    task.arguments = arguments;
    NSPipe *out = [NSPipe pipe];
    task.standardOutput = out;
    task.standardError = [NSPipe pipe];

    NSError *error = nil;
    if (![task launchAndReturnError:&error])
        return nil;

    NSData *data = [out.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    if (status)
        *status = task.terminationStatus;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
        ?: @"";
}


@interface MPQuickLookExtension ()
@property (nonatomic) MPQuickLookExtensionState state;
@property (copy, nonatomic) NSString *identifier;
@property (copy, nonatomic) NSURL *bundledURL;
@property (copy, nonatomic) NSString *bundledVersion;
@property (copy, nonatomic) NSURL *registeredURL;
@property (copy, nonatomic) NSString *registeredVersion;
@end


@implementation MPQuickLookExtension

+ (instancetype)current
{
    MPQuickLookExtension *extension = [[self alloc] init];

    NSURL *inside = [[NSBundle mainBundle].builtInPlugInsURL
        URLByAppendingPathComponent:kMPExtensionName];
    NSBundle *bundle = [NSBundle bundleWithURL:inside];
    if (bundle)
    {
        extension.bundledURL = inside;
        extension.identifier = bundle.bundleIdentifier;
        extension.bundledVersion = bundle.infoDictionary
            [@"CFBundleShortVersionString"];
    }
    if (!extension.identifier.length)
    {
        // No extension in this build: say so rather than guess a name.
        extension.state = MPQuickLookExtensionStateMissing;
        return extension;
    }

    NSString *listing = MPRun(kMPPlugInKit,
        @[@"-m", @"-i", extension.identifier, @"-vvv"], NULL);
    NSDictionary *record =
        MPQuickLookRecordInListing(listing, extension.identifier);

    NSString *path = record[@"path"];
    if (path.length)
        extension.registeredURL = [NSURL fileURLWithPath:path];
    extension.registeredVersion = record[@"version"];
    extension.state = MPQuickLookStateForRecord(record, extension.bundledURL,
                                                extension.bundledVersion);
    return extension;
}


- (BOOL)install:(NSError **)error
{
    if (!self.bundledURL)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:kMPErrorDomain code:1 userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(
                    @"This copy of MacDown Next does not carry the Finder "
                    @"preview.",
                    @"Quick Look extension missing from the app bundle"),
            }];
        }
        return NO;
    }

    NSURL *app = [NSBundle mainBundle].bundleURL;
    // Asking again does not replace a record that is already there, and an
    // extension whose record is stale stays invisible however many times
    // the registration is repeated. So it is taken away first.
    int status = 0;
    NSString *out = MPRun(kMPLaunchServices, @[@"-u", app.path], &status);
    if (!out)
        return [self failWith:error
                       reason:NSLocalizedString(
            @"Launch Services could not be reached to register the extension.",
            @"lsregister not found")];
    usleep(kMPSettleTime / 3);
    MPRun(kMPLaunchServices, @[@"-f", @"-R", @"-trusted", app.path], &status);
    usleep(kMPSettleTime);

    // Whatever the reader may have switched off before.
    MPRun(kMPPlugInKit, @[@"-e", @"use", @"-i", self.identifier], NULL);
    usleep(kMPSettleTime / 3);

    MPQuickLookExtension *now = [MPQuickLookExtension current];
    if (now.state == MPQuickLookExtensionStateInstalled)
        return YES;

    return [self failWith:error reason:NSLocalizedString(
        @"macOS did not accept the extension. Moving MacDown Next into the "
        @"Applications folder and trying again is usually enough.",
        @"Quick Look extension registration refused")];
}


- (BOOL)remove:(NSError **)error
{
    if (!self.identifier.length)
        return YES;    // Nothing to take away.

    // Switched off first, so that a registration the system keeps a copy of
    // somewhere else does not come back on.
    MPRun(kMPPlugInKit, @[@"-e", @"ignore", @"-i", self.identifier], NULL);
    if (self.registeredURL)
        MPRun(kMPPlugInKit, @[@"-r", self.registeredURL.path], NULL);
    else if (self.bundledURL)
        MPRun(kMPPlugInKit, @[@"-r", self.bundledURL.path], NULL);
    usleep(kMPSettleTime);

    MPQuickLookExtension *now = [MPQuickLookExtension current];
    if (now.state == MPQuickLookExtensionStateNotInstalled
        || now.state == MPQuickLookExtensionStateDisabled)
        return YES;

    return [self failWith:error reason:NSLocalizedString(
        @"macOS still offers the extension. It can also be turned off in "
        @"System Settings, under General ▸ Login Items & Extensions.",
        @"Quick Look extension removal refused")];
}


- (BOOL)failWith:(NSError **)error reason:(NSString *)reason
{
    if (error)
    {
        *error = [NSError errorWithDomain:kMPErrorDomain code:2 userInfo:@{
            NSLocalizedDescriptionKey: reason,
        }];
    }
    return NO;
}


#pragma mark - What the panel says

- (NSString *)summary
{
    switch (self.state)
    {
        case MPQuickLookExtensionStateInstalled:
            return NSLocalizedString(
                @"Finder shows Markdown documents as they read.",
                @"Quick Look extension is installed");
        case MPQuickLookExtensionStateOutdated:
            return [NSString stringWithFormat:NSLocalizedString(
                @"An older version is registered (%@, against %@ here).",
                @"Quick Look extension is registered from an older build"),
                self.registeredVersion ?: @"?", self.bundledVersion ?: @"?"];
        case MPQuickLookExtensionStateElsewhere:
            return NSLocalizedString(
                @"The preview comes from another copy of MacDown Next.",
                @"Quick Look extension registered from another app bundle");
        case MPQuickLookExtensionStateDisabled:
            return NSLocalizedString(
                @"The preview is installed but turned off.",
                @"Quick Look extension is registered but disabled");
        case MPQuickLookExtensionStateNotInstalled:
            return NSLocalizedString(
                @"Finder shows the source of Markdown documents.",
                @"Quick Look extension is not installed");
        case MPQuickLookExtensionStateMissing:
            return NSLocalizedString(
                @"This copy of the application does not carry the Finder "
                @"preview.",
                @"Quick Look extension missing from the app bundle");
    }
}

- (BOOL)canInstall
{
    switch (self.state)
    {
        case MPQuickLookExtensionStateInstalled:
        case MPQuickLookExtensionStateMissing:
            return NO;
        default:
            return YES;
    }
}

- (BOOL)canRemove
{
    switch (self.state)
    {
        case MPQuickLookExtensionStateInstalled:
        case MPQuickLookExtensionStateOutdated:
        case MPQuickLookExtensionStateElsewhere:
            return YES;
        default:
            return NO;
    }
}

@end
