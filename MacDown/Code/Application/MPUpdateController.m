//
//  MPUpdateController.m
//  MacDown
//

#import "MPUpdateController.h"

#import "MPPreferences.h"
#import "MPUpdate.h"


/// How much of the release notes fits in a question without becoming one.
static const NSUInteger kMPNotesShown = 400;


@interface MPUpdateController ()
@property (strong, nonatomic) MPUpdateDownload *download;
@property (strong, nonatomic) NSWindow *progressWindow;
@property (strong, nonatomic) NSProgressIndicator *bar;
@property (strong, nonatomic) NSTextField *progressLabel;
@property (nonatomic, getter=isBusy) BOOL busy;
@end


@implementation MPUpdateController

+ (instancetype)sharedInstance
{
    static MPUpdateController *controller = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        controller = [[MPUpdateController alloc] init];
    });
    return controller;
}

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (NSString *)runningVersion
{
    return [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
}


#pragma mark - Looking

- (IBAction)checkForUpdates:(id)sender
{
    [self checkAndSaySo:YES];
}

- (void)checkQuietlyIfDue
{
    if (!self.preferences.updatesCheckAutomatically)
        return;
    if (!MPUpdateIsDue(self.preferences.updatesLastCheck, [NSDate date]))
        return;
    [self checkAndSaySo:NO];
}

/// @param loud whether "there is nothing new" and errors are worth a panel.
- (void)checkAndSaySo:(BOOL)loud
{
    if (self.busy)
        return;
    self.busy = YES;

    [MPUpdateCheck latestReleaseWithCompletion:^(MPRelease *release,
                                                 NSError *error) {
        self.busy = NO;
        // Written down whatever the answer was: a repository that is down
        // should not turn into a check on every launch.
        self.preferences.updatesLastCheck = [NSDate date];

        if (error)
        {
            if (loud)
                [self sayTrouble:error];
            return;
        }
        if (!MPUpdateIsNewer(release, self.runningVersion))
        {
            if (loud)
                [self sayUpToDate];
            return;
        }
        [self offer:release];
    }];
}


#pragma mark - Asking

- (void)offer:(MPRelease *)release
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(
        @"MacDown Next %@ is available.",
        @"A newer release exists"), release.version];

    NSMutableString *what = [NSMutableString string];
    if (release.notes.length)
    {
        NSString *notes = release.notes;
        if (notes.length > kMPNotesShown)
        {
            notes = [[notes substringToIndex:kMPNotesShown]
                stringByAppendingString:@"…"];
        }
        [what appendString:notes];
        [what appendString:@"\n\n"];
    }
    [what appendFormat:NSLocalizedString(
        @"You have %@. The download is %@ and lands in Downloads.",
        @"How big the update is and where it goes"),
        self.runningVersion ?: @"?",
        [NSByteCountFormatter stringFromByteCount:release.size
                                       countStyle:NSByteCountFormatterCountStyleFile]];
    alert.informativeText = what;

    [alert addButtonWithTitle:NSLocalizedString(@"Download",
        @"Download the update")];
    [alert addButtonWithTitle:NSLocalizedString(@"Not Now",
        @"Do not download the update")];
    if (release.pageURL)
    {
        [alert addButtonWithTitle:NSLocalizedString(@"Release Notes",
            @"Open the release page")];
    }

    NSModalResponse answer = [alert runModal];
    if (answer == NSAlertFirstButtonReturn)
    {
        [self fetch:release];
    }
    else if (answer == NSAlertThirdButtonReturn && release.pageURL)
    {
        // Reading what changed is part of deciding, so the question comes
        // back once the page is open.
        [[NSWorkspace sharedWorkspace] openURL:release.pageURL];
        [self offer:release];
    }
}


#pragma mark - Fetching

- (void)fetch:(MPRelease *)release
{
    if (self.busy)
        return;
    self.busy = YES;

    self.download = [[MPUpdateDownload alloc] initWithRelease:release];
    [self showProgressFor:release];

    [self.download startWithProgress:^(double fraction, long long received,
                                       long long total) {
        [self showFraction:fraction received:received total:total];
    } completion:^(NSURL *file, NSError *error) {
        self.busy = NO;
        self.download = nil;
        [self hideProgress];

        if (error)
        {
            // Stopping it was a decision, not a fault: no panel for that.
            if (error.code != NSUserCancelledError)
                [self sayTrouble:error];
            return;
        }
        [self offerToOpen:file version:release.version];
    }];
}

- (void)showProgressFor:(MPRelease *)release
{
    NSTextField *title = [NSTextField labelWithString:[NSString
        stringWithFormat:NSLocalizedString(@"Downloading MacDown Next %@",
            @"Title of the update download panel"), release.version]];
    title.font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];

    self.bar = [[NSProgressIndicator alloc] init];
    self.bar.style = NSProgressIndicatorStyleBar;
    self.bar.indeterminate = YES;
    self.bar.minValue = 0.0;
    self.bar.maxValue = 1.0;
    [self.bar startAnimation:nil];
    [self.bar.widthAnchor constraintEqualToConstant:360.0].active = YES;

    self.progressLabel = [NSTextField labelWithString:NSLocalizedString(
        @"Waiting for an answer…", @"The download has not started yet")];
    self.progressLabel.textColor = [NSColor secondaryLabelColor];
    self.progressLabel.font =
        [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

    NSButton *stop = [NSButton buttonWithTitle:NSLocalizedString(@"Stop",
        @"Stop the download") target:self action:@selector(stopDownload:)];
    stop.keyEquivalent = @"\033";       // Escape stops it too.

    NSStackView *buttons = [NSStackView stackViewWithViews:@[stop]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.alignment = NSLayoutAttributeTrailing;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[title, self.bar, self.progressLabel, buttons]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 10.0;
    column.edgeInsets = NSEdgeInsetsMake(20.0, 20.0, 20.0, 20.0);
    [buttons.widthAnchor constraintEqualToAnchor:column.widthAnchor
        constant:-40.0].active = YES;

    NSPanel *panel = [[NSPanel alloc] initWithContentRect:
        NSMakeRect(0.0, 0.0, 400.0, 140.0)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
          backing:NSBackingStoreBuffered defer:NO];
    panel.title = NSLocalizedString(@"Update", @"Update panel title");
    panel.contentView = column;
    panel.hidesOnDeactivate = NO;
    [panel center];

    self.progressWindow = panel;
    [panel makeKeyAndOrderFront:nil];
}

- (void)showFraction:(double)fraction received:(long long)received
               total:(long long)total
{
    if (fraction < 0.0)
    {
        self.bar.indeterminate = YES;
        [self.bar startAnimation:nil];
    }
    else
    {
        self.bar.indeterminate = NO;
        self.bar.doubleValue = fraction;
    }

    NSByteCountFormatter *sizes = [[NSByteCountFormatter alloc] init];
    sizes.countStyle = NSByteCountFormatterCountStyleFile;
    self.progressLabel.stringValue = total > 0
        ? [NSString stringWithFormat:NSLocalizedString(@"%@ of %@",
              @"Downloaded so far, and the whole size"),
           [sizes stringFromByteCount:received],
           [sizes stringFromByteCount:total]]
        : [sizes stringFromByteCount:received];
}

- (void)hideProgress
{
    [self.progressWindow close];
    self.progressWindow = nil;
    self.bar = nil;
    self.progressLabel = nil;
}

- (void)stopDownload:(id)sender
{
    [self.download cancel];
}


#pragma mark - Standing aside

- (void)offerToOpen:(NSURL *)file version:(NSString *)version
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(
        @"MacDown Next %@ is in Downloads.",
        @"The update has been downloaded"), version];
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(
        @"To install it, MacDown Next quits and “%@” opens: then you drag the "
        @"application onto the Applications folder, as usual. You will be "
        @"asked about the documents that are not saved.",
        @"What happens when the update is opened"), file.lastPathComponent];

    [alert addButtonWithTitle:NSLocalizedString(@"Quit and Open",
        @"Quit and open the downloaded disk image")];
    [alert addButtonWithTitle:NSLocalizedString(@"Later",
        @"Leave the downloaded disk image alone for now")];
    [alert addButtonWithTitle:NSLocalizedString(@"Show in Finder",
        @"Reveal the downloaded disk image")];

    NSModalResponse answer = [alert runModal];
    if (answer == NSAlertThirdButtonReturn)
    {
        [[NSWorkspace sharedWorkspace]
            activateFileViewerSelectingURLs:@[file]];
        return;
    }
    if (answer != NSAlertFirstButtonReturn)
        return;

    // The disk image is opened first: asking the application to quit and
    // then to open something is asking a process that is going away to do
    // one more thing.
    [[NSWorkspace sharedWorkspace] openURL:file];
    [[NSApplication sharedApplication] terminate:nil];
}


#pragma mark - Saying

- (void)sayUpToDate
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"This is already the latest "
                                          @"version.",
        @"There is no newer release");
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(
        @"This is %@.", @"Which version is running"),
        self.runningVersion ?: @"?"];
    [alert runModal];
}

- (void)sayTrouble:(NSError *)error
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = NSLocalizedString(
        @"The updates could not be checked.",
        @"The update check failed");
    alert.informativeText = error.localizedDescription ?: @"";
    [alert runModal];
}

@end
