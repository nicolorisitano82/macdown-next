//
//  MPQuickLookPreferencesViewController.m
//  MacDown
//

#import "MPQuickLookPreferencesViewController.h"

#import "MPQuickLookExtension.h"


static const CGFloat kMPPanelWidth = 520.0;
static const CGFloat kMPPanelPadding = 20.0;


/// The dot beside the sentence, in the colour the sentence deserves.
NS_INLINE NSColor *MPStateColour(MPQuickLookExtensionState state)
{
    switch (state)
    {
        case MPQuickLookExtensionStateInstalled:
            return [NSColor systemGreenColor];
        case MPQuickLookExtensionStateOutdated:
        case MPQuickLookExtensionStateElsewhere:
        case MPQuickLookExtensionStateDisabled:
            return [NSColor systemOrangeColor];
        case MPQuickLookExtensionStateNotInstalled:
        case MPQuickLookExtensionStateMissing:
            return [NSColor systemRedColor];
    }
}


@interface MPQuickLookPreferencesViewController ()

@property (strong, nonatomic) MPQuickLookExtension *extension;

@property (strong, nonatomic) NSTextField *indicator;
@property (strong, nonatomic) NSTextField *summaryLabel;
@property (strong, nonatomic) NSTextField *registeredLabel;
@property (strong, nonatomic) NSTextField *bundledLabel;
@property (strong, nonatomic) NSTextField *troubleLabel;
@property (strong, nonatomic) NSButton *installButton;
@property (strong, nonatomic) NSButton *removeButton;
@property (strong, nonatomic) NSProgressIndicator *spinner;

@end


@implementation MPQuickLookPreferencesViewController

- (id)init
{
    // Built here rather than in a nib: the panel is a sentence, two lines of
    // detail and two buttons, and all of it changes with the answer the
    // system gives.
    return [super initWithNibName:nil bundle:nil];
}


#pragma mark - The panel

- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPPanelWidth, 260.0)];

    self.indicator = [self labelWithString:@"●"];
    self.indicator.font = [NSFont systemFontOfSize:13.0];
    self.summaryLabel = [self labelWithString:@""];
    self.summaryLabel.font =
        [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];

    NSStackView *headline = [NSStackView stackViewWithViews:
        @[self.indicator, self.summaryLabel]];
    headline.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    headline.spacing = 6.0;
    headline.alignment = NSLayoutAttributeFirstBaseline;

    NSTextField *what = [self labelWithString:NSLocalizedString(
        @"Press the space bar on a Markdown file and Finder shows the "
        @"document as it reads — headings, tables, code and to-do boxes — "
        @"instead of the source. The preview is part of this application: "
        @"installing it means telling macOS that it is here.",
        @"Explanation of the Quick Look extension")];
    what.textColor = [NSColor secondaryLabelColor];

    self.registeredLabel = [self detailLabel];
    self.bundledLabel = [self detailLabel];

    self.installButton = [NSButton buttonWithTitle:@""
        target:self action:@selector(install:)];
    self.installButton.keyEquivalent = @"\r";
    self.removeButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Remove", @"Remove the Quick Look extension")
        target:self action:@selector(remove:)];

    self.spinner = [[NSProgressIndicator alloc] init];
    self.spinner.style = NSProgressIndicatorStyleSpinning;
    self.spinner.controlSize = NSControlSizeSmall;
    self.spinner.displayedWhenStopped = NO;

    NSButton *settings = [NSButton buttonWithTitle:NSLocalizedString(
        @"Show in System Settings…",
        @"Open the Extensions pane of System Settings")
        target:self action:@selector(showInSystemSettings:)];
    settings.bezelStyle = NSBezelStyleInline;
    settings.bordered = NO;
    settings.contentTintColor = [NSColor linkColor];

    NSStackView *buttons = [NSStackView stackViewWithViews:
        @[self.installButton, self.removeButton, self.spinner]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 10.0;

    self.troubleLabel = [self labelWithString:@""];
    self.troubleLabel.textColor = [NSColor systemRedColor];
    self.troubleLabel.hidden = YES;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[headline, what, self.registeredLabel, self.bundledLabel, buttons,
          self.troubleLabel, settings]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 12.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [column setCustomSpacing:6.0 afterView:self.registeredLabel];
    [column setCustomSpacing:18.0 afterView:self.bundledLabel];

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

    // The paragraph has to know how wide it may be before it can say how
    // tall it is, and the panel's width is the answer.
    CGFloat text = kMPPanelWidth - 2.0 * kMPPanelPadding;
    what.preferredMaxLayoutWidth = text;
    self.troubleLabel.preferredMaxLayoutWidth = text;
    self.registeredLabel.preferredMaxLayoutWidth = text;
    self.bundledLabel.preferredMaxLayoutWidth = text;

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

/// A path or a version: read rarely, copied when it matters.
- (NSTextField *)detailLabel
{
    NSTextField *label = [self labelWithString:@""];
    label.font = [NSFont monospacedSystemFontOfSize:11.0
                                             weight:NSFontWeightRegular];
    label.textColor = [NSColor secondaryLabelColor];
    return label;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self refresh];
}


#pragma mark - Asking, and saying

- (void)refresh
{
    [self setBusy:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        MPQuickLookExtension *extension = [MPQuickLookExtension current];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.extension = extension;
            [self setBusy:NO];
            [self showWhatWeKnow];
        });
    });
}

- (void)showWhatWeKnow
{
    MPQuickLookExtension *extension = self.extension;
    self.indicator.textColor = MPStateColour(extension.state);
    self.summaryLabel.stringValue = extension.summary;

    if (extension.registeredURL)
    {
        self.registeredLabel.stringValue = [NSString stringWithFormat:
            NSLocalizedString(@"Registered: %@ (%@)",
                @"Where macOS has the Quick Look extension, and its version"),
            extension.registeredURL.path,
            extension.registeredVersion ?: @"?"];
    }
    else
    {
        self.registeredLabel.stringValue = NSLocalizedString(
            @"Registered: nowhere.",
            @"macOS has no Quick Look extension registered for Markdown");
    }
    self.bundledLabel.stringValue = [NSString stringWithFormat:
        NSLocalizedString(@"In this application: %@",
            @"The version of the Quick Look extension inside the app"),
        extension.bundledVersion ?: NSLocalizedString(@"none",
            @"No Quick Look extension inside the app")];

    switch (extension.state)
    {
        case MPQuickLookExtensionStateOutdated:
        case MPQuickLookExtensionStateElsewhere:
            self.installButton.title = NSLocalizedString(@"Register Again",
                @"Re-register the Quick Look extension from this app");
            break;
        default:
            self.installButton.title = NSLocalizedString(@"Install",
                @"Register the Quick Look extension");
            break;
    }
    self.installButton.enabled = extension.canInstall;
    self.removeButton.enabled = extension.canRemove;
}

- (void)setBusy:(BOOL)busy
{
    if (busy)
        [self.spinner startAnimation:nil];
    else
        [self.spinner stopAnimation:nil];
    self.installButton.enabled = !busy && self.extension.canInstall;
    self.removeButton.enabled = !busy && self.extension.canRemove;
}

- (void)showTrouble:(NSError *)error
{
    self.troubleLabel.stringValue = error.localizedDescription ?: @"";
    self.troubleLabel.hidden = (error == nil);
}


#pragma mark - Doing

- (void)install:(id)sender
{
    [self doWork:^BOOL(MPQuickLookExtension *extension, NSError **error) {
        return [extension install:error];
    }];
}

- (void)remove:(id)sender
{
    [self doWork:^BOOL(MPQuickLookExtension *extension, NSError **error) {
        return [extension remove:error];
    }];
}

/// Both buttons wait on Launch Services, which takes seconds, so the panel
/// says it is working and asks the system again afterwards rather than
/// assuming the answer.
- (void)doWork:(BOOL (^)(MPQuickLookExtension *, NSError **))work
{
    MPQuickLookExtension *extension = self.extension;
    if (!extension)
        return;

    [self showTrouble:nil];
    [self setBusy:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL done = work(extension, &error);
        MPQuickLookExtension *now = [MPQuickLookExtension current];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.extension = now;
            [self setBusy:NO];
            [self showWhatWeKnow];
            if (!done)
                [self showTrouble:error];
        });
    });
}

- (void)showInSystemSettings:(id)sender
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    // The pane has been renamed more than once; the older address is kept as
    // a fallback rather than guessing which macOS this is.
    for (NSString *address in @[
        @"x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
        @"x-apple.systempreferences:com.apple.ExtensionsPreferences"])
    {
        if ([workspace openURL:[NSURL URLWithString:address]])
            return;
    }
}


#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"QuickLookPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:NSImageNameQuickLookTemplate];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Quick Look", @"Preference pane title.");
}

@end
