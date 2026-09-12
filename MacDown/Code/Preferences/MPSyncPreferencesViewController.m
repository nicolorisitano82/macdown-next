//
//  MPSyncPreferencesViewController.m
//  MacDown
//

#import "MPSyncPreferencesViewController.h"

#import "MPGoogleDrive.h"


static const CGFloat kMPPanelWidth = 560.0;
static const CGFloat kMPPanelPadding = 20.0;

/// Dove si crea un client OAuth. Sta scritto qui una volta sola perché è
/// l'unica cosa di questo pannello che non si può spiegare a parole.
static NSString *const kMPConsole = @"https://console.cloud.google.com/apis/credentials";


@interface MPSyncPreferencesViewController ()

@property (strong, nonatomic) NSTextField *clientField;
@property (strong, nonatomic) NSSecureTextField *secretField;
@property (strong, nonatomic) NSTextField *stateLabel;
@property (strong, nonatomic) NSButton *linkButton;
@property (strong, nonatomic) NSButton *unlinkButton;

@end


@implementation MPSyncPreferencesViewController

- (id)init
{
    return [super initWithNibName:nil bundle:nil];
}


#pragma mark - Il pannello

- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPPanelWidth, 420.0)];

    NSTextField *what = [self paragraph:NSLocalizedString(
        @"This application does not carry a Google client of its own, and "
        @"that is on purpose: one client for everybody would mean one "
        @"verification, one quota and a consent screen with somebody else's "
        @"name on it. You make your own — it takes five minutes and costs "
        @"nothing — and from then on the permission is between you and "
        @"Google.",
        @"What the sync preference pane is about")];

    NSTextField *howTitle = [self label:NSLocalizedString(
        @"How to get one", @"Title above the steps to create an OAuth client")];
    NSTextField *how = [self paragraph:NSLocalizedString(
        @"In the Google Cloud console: make a project, enable the Google "
        @"Drive API, then Credentials ▸ Create credentials ▸ OAuth client "
        @"ID, of type Desktop app. Copy the ID it gives you. There is no "
        @"redirect address to register: a desktop client is allowed to come "
        @"back to this Mac on any port.",
        @"The steps to create a Google OAuth client")];
    NSButton *console = [NSButton buttonWithTitle:NSLocalizedString(
        @"Open the console…", @"Opens the Google Cloud credentials page")
        target:self action:@selector(openConsole:)];

    NSTextField *clientTitle = [self label:NSLocalizedString(
        @"Client ID:", @"Field for the Google OAuth client identifier")];
    self.clientField = [NSTextField textFieldWithString:@""];
    self.clientField.placeholderString = @"…apps.googleusercontent.com";
    self.clientField.delegate = self;
    [self.clientField.widthAnchor constraintEqualToConstant:330.0].active = YES;

    NSTextField *secretTitle = [self label:NSLocalizedString(
        @"Client secret:", @"Field for the Google OAuth client secret")];
    self.secretField = [[NSSecureTextField alloc] init];
    self.secretField.placeholderString = NSLocalizedString(
        @"optional", @"Placeholder: the client secret is not required");
    self.secretField.delegate = self;
    [self.secretField.widthAnchor constraintEqualToConstant:330.0].active = YES;

    // Perché è facoltativo, detto dove serve saperlo.
    NSTextField *secretNote = [self paragraph:NSLocalizedString(
        @"A desktop client's secret is not really a secret — it would live "
        @"inside the application anyway — so the permission is protected by "
        @"PKCE instead, and Google itself calls the secret optional here. "
        @"Paste it only if your client refuses without it. It is kept in "
        @"the keychain, like the tokens; neither ever reaches a preferences "
        @"file or the log.",
        @"Why the client secret is optional")];

    self.stateLabel = [self label:@""];
    self.linkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Connect…", @"Starts the Google Drive permission flow")
        target:self action:@selector(link:)];
    self.unlinkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Disconnect", @"Forgets the Google Drive tokens")
        target:self action:@selector(unlink:)];

    NSTextField *scopeNote = [self paragraph:NSLocalizedString(
        @"What is asked for is the narrowest thing Drive has: the files "
        @"this application creates, and whatever you hand it in the picker "
        @"— nothing that resembles «see everything in my Drive». Nothing is "
        @"read or written until you connect, and Disconnect forgets the "
        @"tokens for good.",
        @"What the drive.file scope means")];

    NSStackView *clientRow = [NSStackView stackViewWithViews:
        @[clientTitle, self.clientField]];
    clientRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    clientRow.spacing = 8.0;

    NSStackView *secretRow = [NSStackView stackViewWithViews:
        @[secretTitle, self.secretField]];
    secretRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    secretRow.spacing = 8.0;

    NSStackView *buttons = [NSStackView stackViewWithViews:
        @[self.linkButton, self.unlinkButton]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 10.0;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[what, howTitle, how, console, clientRow, secretRow, secretNote,
          self.stateLabel, buttons, scopeNote]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 12.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [column setCustomSpacing:4.0 afterView:howTitle];
    [column setCustomSpacing:18.0 afterView:console];
    [column setCustomSpacing:4.0 afterView:secretRow];
    [column setCustomSpacing:18.0 afterView:secretNote];
    [column setCustomSpacing:6.0 afterView:self.stateLabel];

    [view addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:view.leadingAnchor
                                             constant:kMPPanelPadding],
        [column.trailingAnchor constraintEqualToAnchor:view.trailingAnchor
                                              constant:-kMPPanelPadding],
        [column.topAnchor constraintEqualToAnchor:view.topAnchor
                                         constant:kMPPanelPadding],
        [column.bottomAnchor constraintLessThanOrEqualToAnchor:view.bottomAnchor
                                                     constant:-kMPPanelPadding],
    ]];
    self.view = view;
}


- (void)viewWillAppear
{
    [super viewWillAppear];
    MPGoogleDrive *drive = [MPGoogleDrive sharedDrive];
    self.clientField.stringValue = drive.clientIdentifier;
    self.secretField.stringValue = drive.clientSecret;
    [self showState];
}


/// Una riga sola, e dice solo quello che è successo davvero.
- (void)showState
{
    MPGoogleDrive *drive = [MPGoogleDrive sharedDrive];
    self.linkButton.enabled = drive.isConfigured;

    if (!drive.isConfigured)
    {
        self.stateLabel.stringValue = NSLocalizedString(
            @"No client ID yet.",
            @"State: the pane has no Google client identifier");
        self.unlinkButton.enabled = NO;
        return;
    }
    self.unlinkButton.enabled = drive.isLinked;
    if (!drive.isLinked)
    {
        self.stateLabel.stringValue = NSLocalizedString(
            @"Not connected.", @"State: no Google Drive permission yet");
        return;
    }
    NSString *folder = drive.folderName.length ? drive.folderName : nil;
    self.stateLabel.stringValue = folder
        ? [NSString stringWithFormat:NSLocalizedString(
              @"Connected, on the folder «%@».",
              @"State: connected to Google Drive, with the chosen folder"),
           folder]
        : NSLocalizedString(@"Connected.",
                            @"State: connected to Google Drive");
}


#pragma mark - Quello che fanno i pulsanti

- (void)controlTextDidChange:(NSNotification *)notification
{
    MPGoogleDrive *drive = [MPGoogleDrive sharedDrive];
    if (notification.object == self.clientField)
        drive.clientIdentifier = self.clientField.stringValue;
    else if (notification.object == self.secretField)
        drive.clientSecret = self.secretField.stringValue;
    [self showState];
}


- (void)openConsole:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kMPConsole]];
}


- (void)link:(id)sender
{
    self.linkButton.enabled = NO;
    self.stateLabel.stringValue = NSLocalizedString(
        @"Waiting for the browser…",
        @"State while the Google consent screen is open");

    [[MPGoogleDrive sharedDrive] linkWithCompletion:
     ^(MPGoogleLinkOutcome outcome, NSString *message) {
        if (outcome == MPGoogleLinkDone)
        {
            [self showState];
            return;
        }
        [self showState];
        if (outcome == MPGoogleLinkCancelled)
            return;             // chiusa la finestra: non è successo niente

        // Le parole di Google, non le nostre: «client sbagliato» e
        // «permesso negato» si distinguono solo così.
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(
            @"Google did not give the permission",
            @"Title of the alert when linking Google Drive fails");
        alert.informativeText = message ?: @"";
        [alert runModal];
    }];
}


- (void)unlink:(id)sender
{
    [[MPGoogleDrive sharedDrive] unlink];
    [self showState];
}


#pragma mark - Pezzi

- (NSTextField *)label:(NSString *)string
{
    NSTextField *label = [NSTextField labelWithString:string];
    label.selectable = YES;
    return label;
}

- (NSTextField *)paragraph:(NSString *)string
{
    NSTextField *label = [self label:string];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.textColor = [NSColor secondaryLabelColor];
    [label.widthAnchor constraintEqualToConstant:
        kMPPanelWidth - kMPPanelPadding * 2.0].active = YES;
    return label;
}


#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"SyncPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageWithSystemSymbolName:@"arrow.triangle.2.circlepath"
                     accessibilityDescription:nil]
        ?: [NSImage imageNamed:NSImageNameNetwork];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Sync", @"Preference pane title.");
}

@end
