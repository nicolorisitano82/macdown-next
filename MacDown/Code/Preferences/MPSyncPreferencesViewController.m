//
//  MPSyncPreferencesViewController.m
//  MacDown
//

#import "MPSyncPreferencesViewController.h"

#import "MPCloudService.h"


static const CGFloat kMPPanelWidth = 560.0;
static const CGFloat kMPPanelPadding = 20.0;

/// Dove si crea un client OAuth. Sta scritto qui una volta sola perché è
/// l'unica cosa di questo pannello che non si può spiegare a parole.
static NSString *const kMPConsole = @"https://console.cloud.google.com/apis/credentials";


@interface MPSyncPreferencesViewController ()

@property (strong, nonatomic) NSSegmentedControl *picker;
@property (strong, nonatomic) NSTextField *soon;
@property (strong, nonatomic) NSTextField *explanation;
@property (strong, nonatomic) NSTextField *howTitle;
@property (strong, nonatomic) NSTextField *how;
@property (strong, nonatomic) NSButton *console;
@property (strong, nonatomic) NSTextField *clientTitle;
@property (strong, nonatomic) NSTextField *clientField;
@property (strong, nonatomic) NSTextField *secretTitle;
@property (strong, nonatomic) NSSecureTextField *secretField;
@property (strong, nonatomic) NSTextField *secretNote;
@property (strong, nonatomic) NSTextField *stateLabel;
@property (strong, nonatomic) NSButton *linkButton;
@property (strong, nonatomic) NSButton *unlinkButton;
@property (strong, nonatomic) NSTextField *scopeNote;
@property (strong, nonatomic) NSStackView *clientRow;
@property (strong, nonatomic) NSStackView *secretRow;
@property (strong, nonatomic) NSStackView *buttons;

@end


@implementation MPSyncPreferencesViewController

- (id)init
{
    return [super initWithNibName:nil bundle:nil];
}


#pragma mark - Il pannello

/// Il servizio che si sta guardando.
- (MPCloudService *)chosen
{
    NSArray *services = [MPCloudService services];
    NSInteger index = self.picker.selectedSegment;
    if (index < 0 || (NSUInteger)index >= services.count)
        index = 0;
    return services[index];
}


- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPPanelWidth, 460.0)];

    NSArray<MPCloudService *> *services = [MPCloudService services];
    self.picker = [NSSegmentedControl segmentedControlWithLabels:
        [services valueForKey:@"name"]
        trackingMode:NSSegmentSwitchTrackingSelectOne
        target:self action:@selector(pickService:)];
    // Un servizio che non c'è ancora si vede e non si preme: nasconderlo
    // vorrebbe dire far cercare alla gente una cosa che è in programma.
    for (NSUInteger i = 0; i < services.count; i++)
        [self.picker setEnabled:services[i].available forSegment:(NSInteger)i];
    self.picker.selectedSegment = 0;

    self.soon = [self paragraph:@""];
    self.soon.font = [NSFont systemFontOfSize:11.0];
    self.explanation = [self paragraph:@""];
    self.howTitle = [self label:NSLocalizedString(
        @"How to get one", @"Title above the steps to register an app")];
    self.how = [self paragraph:@""];
    self.console = [NSButton buttonWithTitle:@""
        target:self action:@selector(openConsole:)];

    self.clientTitle = [self label:NSLocalizedString(
        @"Client ID:", @"Field for the client identifier")];
    self.clientField = [NSTextField textFieldWithString:@""];
    self.clientField.delegate = self;
    [self.clientField.widthAnchor constraintEqualToConstant:330.0].active = YES;

    self.secretTitle = [self label:NSLocalizedString(
        @"Client secret:", @"Field for the client secret")];
    self.secretField = [[NSSecureTextField alloc] init];
    self.secretField.placeholderString = NSLocalizedString(
        @"optional", @"Placeholder: the client secret is not required");
    self.secretField.delegate = self;
    [self.secretField.widthAnchor constraintEqualToConstant:330.0].active = YES;

    self.secretNote = [self paragraph:NSLocalizedString(
        @"A desktop client's secret is not really a secret — it would live "
        @"inside the application anyway — so the permission is protected by "
        @"PKCE instead. Paste it only if your client refuses without it. It "
        @"is kept in the keychain, like the tokens; neither ever reaches a "
        @"preferences file or the log.",
        @"Why the client secret is optional")];

    self.stateLabel = [self label:@""];
    self.linkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Connect…", @"Starts the permission flow")
        target:self action:@selector(link:)];
    self.unlinkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Disconnect", @"Forgets the tokens of a service")
        target:self action:@selector(unlink:)];
    self.scopeNote = [self paragraph:@""];

    self.clientRow = [NSStackView stackViewWithViews:
        @[self.clientTitle, self.clientField]];
    self.clientRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.clientRow.spacing = 8.0;

    self.secretRow = [NSStackView stackViewWithViews:
        @[self.secretTitle, self.secretField]];
    self.secretRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.secretRow.spacing = 8.0;

    self.buttons = [NSStackView stackViewWithViews:
        @[self.linkButton, self.unlinkButton]];
    self.buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.buttons.spacing = 10.0;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[self.picker, self.soon, self.explanation, self.howTitle, self.how, self.console,
          self.clientRow, self.secretRow, self.secretNote, self.stateLabel,
          self.buttons, self.scopeNote]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 12.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [column setCustomSpacing:6.0 afterView:self.picker];
    [column setCustomSpacing:18.0 afterView:self.soon];
    [column setCustomSpacing:4.0 afterView:self.howTitle];
    [column setCustomSpacing:18.0 afterView:self.console];
    [column setCustomSpacing:4.0 afterView:self.secretRow];
    [column setCustomSpacing:18.0 afterView:self.secretNote];
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
    [self showService];
}


- (void)viewWillAppear
{
    [super viewWillAppear];
    [self showService];
}


/// Tutto quello che cambia quando si cambia servizio, in un posto solo.
- (void)showService
{
    MPCloudService *service = [self chosen];

    // Quello che c'è ma non si può ancora premere lo dice qui, una riga:
    // una scheda grigia senza spiegazione è una domanda lasciata aperta.
    NSMutableArray<NSString *> *waiting = [NSMutableArray array];
    for (MPCloudService *other in [MPCloudService services])
    {
        if (!other.available)
            [waiting addObject:[NSString stringWithFormat:@"%@ — %@",
                                other.name, other.explanation]];
    }
    self.soon.stringValue = [waiting componentsJoinedByString:@"\n"];
    self.soon.hidden = !waiting.count;

    self.explanation.stringValue = service.explanation;
    self.how.stringValue = service.howToGetAClient;
    self.scopeNote.stringValue = service.scopeExplanation;
    self.clientField.placeholderString = service.clientPlaceholder;
    self.clientField.stringValue = service.clientIdentifier;
    self.secretField.stringValue = service.clientSecret;
    self.console.title = service.consoleButtonTitle;

    // Un segnaposto mostra il perché e niente su cui mettere le mani.
    BOOL ready = service.available;
    for (NSView *row in @[self.howTitle, self.how, self.console, self.clientRow,
                          self.secretRow, self.secretNote, self.stateLabel,
                          self.buttons, self.scopeNote])
        row.hidden = !ready;

    if (ready)
        [self showState];
}


/// Una riga sola, e dice solo quello che è successo davvero.
- (void)showState
{
    MPCloudService *service = [self chosen];
    self.linkButton.enabled = service.isConfigured;

    if (!service.isConfigured)
    {
        self.stateLabel.stringValue = NSLocalizedString(
            @"No client ID yet.",
            @"State: the pane has no client identifier");
        self.unlinkButton.enabled = NO;
        return;
    }
    self.unlinkButton.enabled = service.isLinked;
    if (!service.isLinked)
    {
        self.stateLabel.stringValue = NSLocalizedString(
            @"Not connected.", @"State: no permission yet");
        return;
    }
    NSString *place = service.placeName.length ? service.placeName : nil;
    self.stateLabel.stringValue = place
        ? [NSString stringWithFormat:NSLocalizedString(
              @"Connected, on «%@».",
              @"State: connected, and what the connection covers"), place]
        : NSLocalizedString(@"Connected.", @"State: connected to a service");
}


#pragma mark - Quello che fanno i comandi

- (void)pickService:(id)sender
{
    [self showService];
}


- (void)controlTextDidChange:(NSNotification *)notification
{
    MPCloudService *service = [self chosen];
    if (notification.object == self.clientField)
        service.clientIdentifier = self.clientField.stringValue;
    else if (notification.object == self.secretField)
        service.clientSecret = self.secretField.stringValue;
    [self showState];
}


- (void)openConsole:(id)sender
{
    NSURL *url = [self chosen].consoleURL;
    if (url)
        [[NSWorkspace sharedWorkspace] openURL:url];
}


- (void)link:(id)sender
{
    self.linkButton.enabled = NO;
    self.stateLabel.stringValue = NSLocalizedString(
        @"Waiting for the browser…",
        @"State while the consent screen is open");

    [[self chosen] linkWithCompletion:
     ^(MPCloudLinkOutcome outcome, NSString *message) {
        [self showState];
        if (outcome == MPCloudLinkDone || outcome == MPCloudLinkCancelled)
            return;             // riuscito, o chiuso: non è successo niente

        // Le parole del servizio, non le nostre: «client sbagliato» e
        // «permesso negato» si distinguono solo così.
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(
            @"The permission was not given",
            @"Title of the alert when linking a service fails");
        alert.informativeText = message ?: @"";
        [alert runModal];
    }];
}


- (void)unlink:(id)sender
{
    [[self chosen] unlink];
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
