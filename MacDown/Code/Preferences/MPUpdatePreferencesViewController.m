//
//  MPUpdatePreferencesViewController.m
//  MacDown
//

#import "MPUpdatePreferencesViewController.h"

#import "MPPreferences.h"
#import "MPUpdateController.h"


static const CGFloat kMPPanelWidth = 520.0;
static const CGFloat kMPPanelPadding = 20.0;


@interface MPUpdatePreferencesViewController ()
@property (strong, nonatomic) NSTextField *versionLabel;
@property (strong, nonatomic) NSButton *automatically;
@property (strong, nonatomic) NSTextField *lastCheckLabel;
@end


@implementation MPUpdatePreferencesViewController

- (id)init
{
    return [super initWithNibName:nil bundle:nil];
}


#pragma mark - The panel

- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPPanelWidth, 220.0)];

    self.versionLabel = [self labelWithString:@""];
    self.versionLabel.font =
        [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];

    self.automatically = [NSButton checkboxWithTitle:NSLocalizedString(
        @"Look for a new version once a day",
        @"Whether to look for updates automatically")
        target:self action:@selector(toggleAutomatically:)];

    NSTextField *what = [self labelWithString:NSLocalizedString(
        @"The check is one request to the releases feed on GitHub, and it "
        @"sends nothing about the open document or about the machine. "
        @"Downloading and installing stay two separate questions: the disk "
        @"image lands in Downloads, and the application is dragged into "
        @"Applications by hand, as always.",
        @"What checking for updates does and does not do")];
    what.textColor = [NSColor secondaryLabelColor];

    self.lastCheckLabel = [self labelWithString:@""];
    self.lastCheckLabel.textColor = [NSColor secondaryLabelColor];
    self.lastCheckLabel.font =
        [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

    NSButton *now = [NSButton buttonWithTitle:NSLocalizedString(
        @"Check Now", @"Check for updates now")
        target:[MPUpdateController sharedInstance]
        action:@selector(checkForUpdates:)];

    NSStackView *column = [NSStackView stackViewWithViews:
        @[self.versionLabel, self.automatically, what, self.lastCheckLabel,
          now]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 12.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [column setCustomSpacing:18.0 afterView:self.lastCheckLabel];

    [view addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:view.leadingAnchor
            constant:kMPPanelPadding],
        [column.trailingAnchor constraintEqualToAnchor:view.trailingAnchor
            constant:-kMPPanelPadding],
        [column.topAnchor constraintEqualToAnchor:view.topAnchor
            constant:kMPPanelPadding],
        [column.bottomAnchor constraintEqualToAnchor:view.bottomAnchor
            constant:-kMPPanelPadding],
        [view.widthAnchor constraintEqualToConstant:kMPPanelWidth],
    ]];
    what.preferredMaxLayoutWidth = kMPPanelWidth - 2.0 * kMPPanelPadding;

    self.view = view;
}

- (NSTextField *)labelWithString:(NSString *)text
{
    NSTextField *label = [NSTextField labelWithString:text];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.selectable = YES;
    return label;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self showWhatWeKnow];
}

- (void)showWhatWeKnow
{
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *version = info[@"CFBundleShortVersionString"] ?: @"?";
    NSString *build = info[@"CFBundleBuildVersion"] ?: info[@"CFBundleVersion"];
    self.versionLabel.stringValue = build.length
        ? [NSString stringWithFormat:NSLocalizedString(
              @"This is MacDown Next %@ (%@).",
              @"The running version and its build"), version, build]
        : [NSString stringWithFormat:NSLocalizedString(
              @"This is MacDown Next %@.",
              @"The running version"), version];

    self.automatically.state = self.preferences.updatesCheckAutomatically
        ? NSControlStateValueOn : NSControlStateValueOff;

    NSDate *last = self.preferences.updatesLastCheck;
    if (last)
    {
        NSDateFormatter *when = [[NSDateFormatter alloc] init];
        when.dateStyle = NSDateFormatterMediumStyle;
        when.timeStyle = NSDateFormatterShortStyle;
        self.lastCheckLabel.stringValue = [NSString stringWithFormat:
            NSLocalizedString(@"Last checked: %@",
                @"When the app last looked for an update"),
            [when stringFromDate:last]];
    }
    else
    {
        self.lastCheckLabel.stringValue = NSLocalizedString(
            @"It has not checked yet.",
            @"The app has never looked for an update");
    }
}

- (void)toggleAutomatically:(NSButton *)sender
{
    self.preferences.updatesCheckAutomatically =
        (sender.state == NSControlStateValueOn);
}


#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"UpdatePreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageWithSystemSymbolName:@"arrow.down.circle"
                     accessibilityDescription:nil]
        ?: [NSImage imageNamed:NSImageNameRefreshTemplate];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Updates", @"Preference pane title.");
}

@end
