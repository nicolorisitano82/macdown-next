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
@property (strong, nonatomic) NSButton *checkButton;
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

    self.stateLabel = [self paragraph:@""];
    self.stateLabel.textColor = [NSColor labelColor];
    // Perché un indirizzo dentro un messaggio del servizio si possa
    // premere invece che ricopiare a mano.
    self.stateLabel.allowsEditingTextAttributes = YES;
    self.stateLabel.selectable = YES;
    self.linkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Connect…", @"Starts the permission flow")
        target:self action:@selector(link:)];
    self.unlinkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Disconnect", @"Forgets the tokens of a service")
        target:self action:@selector(unlink:)];
    self.checkButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Check", @"Asks the service what it can see, again")
        target:self action:@selector(check:)];
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
        @[self.linkButton, self.checkButton, self.unlinkButton]];
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
    // Fra una volta e l'altra può essere successo di tutto — un permesso
    // dato, uno lasciato a metà — quindi i pulsanti si rifanno da capo
    // invece di ricordarsi com'erano.
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
        [self say:NSLocalizedString(@"No client ID yet.",
            @"State: the pane has no client identifier")];
        self.unlinkButton.enabled = NO;
        return;
    }
    self.unlinkButton.enabled = service.isLinked;
    self.checkButton.enabled = service.isLinked;

    // Il guaio, con le parole del servizio: «la Drive API non è attiva in
    // questo progetto» è una frase che si risolve in un clic, e nasconderla
    // lascerebbe un'applicazione collegata che non vede niente.
    if (service.isLinked && service.problem.length)
    {
        [self say:service.problem];
        return;
    }
    if (!service.isLinked)
    {
        [self say:NSLocalizedString(@"Not connected.",
                                   @"State: no permission yet")];
        return;
    }
    NSString *place = service.placeName.length ? service.placeName : nil;
    if (!place)
    {
        [self say:NSLocalizedString(@"Connected.",
                                   @"State: connected to a service")];
        return;
    }

    // Quello che si vede là dentro è la domanda che decide tutto il resto,
    // e la risposta si è avuta collegandosi: vale la pena dirla, e dire
    // cosa fare quando è «niente».
    NSInteger visible = service.visibleInPlace;
    if (visible > 0)
    {
        [self say:[NSString stringWithFormat:
            NSLocalizedString(@"Connected, on «%@» — %ld documents in there.",
                @"State: connected, the chosen folder and what is visible"),
            place, (long)visible]];
    }
    else if (visible == 0)
    {
        // Zero vuol dire due cose diverse e non sappiamo quale: una
        // cartella vuota e una cartella i cui documenti non sono compresi
        // nel permesso rispondono uguale. Dirne una sola sarebbe
        // inventare, quindi si dicono tutte e due e si dice come saperlo.
        [self say:[NSString stringWithFormat:
            NSLocalizedString(
                @"Connected, on «%@», and nothing is visible inside it — "
                @"which means either that it is empty, or that documents "
                @"already in there are not covered by the permission. To "
                @"find out: put a file in it from Drive and press Check.",
                @"State: the folder came across, and it looks empty"),
            place]];
    }
    else
    {
        [self say:[NSString stringWithFormat:
            NSLocalizedString(@"Connected, on «%@».",
                @"State: connected, and what the connection covers"), place]];
    }
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
    [self say:NSLocalizedString(@"Waiting for the browser…",
        @"State while the consent screen is open")];

    [[self chosen] linkWithCompletion:
     ^(MPCloudLinkOutcome outcome, NSString *message) {
        if (outcome == MPCloudLinkDone)
        {
            // Collegati non vuol dire che si veda qualcosa: si chiede
            // subito, ed è anche la misura di B0.
            [self check:nil];
            return;
        }
        [self showState];
        if (outcome == MPCloudLinkCancelled)
            return;             // chiusa la finestra: non è successo niente

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


- (void)check:(id)sender
{
    self.checkButton.enabled = NO;
    [self say:NSLocalizedString(@"Asking…",
        @"State while the service is being asked what it sees")];
    [[self chosen] checkWithCompletion:^(NSString *problem) {
        [self showState];
    }];
}


- (void)unlink:(id)sender
{
    [[self chosen] unlink];
    [self showState];
}


/** Scrive la riga di stato, e rende premibile quello che è un indirizzo.
 *
 * I messaggi che contano non sono i nostri: sono quelli del servizio, e
 * quello di Google quando manca un'API è una frase lunga **con dentro il
 * link che la risolve**. Ricopiarlo a mano da un pannello è un lavoro che
 * non ha ragione di esistere, e una riga sola larga quanto la finestra non
 * si legge.
 */
- (void)say:(NSString *)text
{
    NSString *message = text ?: @"";

    // Una frase per riga, quando ce n'è più d'una: il messaggio di un
    // servizio è scritto per un registro, non per un pannello, e tutto di
    // fila non si legge. Le parole restano le sue — si tocca solo dove va
    // a capo.
    if (message.length > 120)
    {
        message = [message stringByReplacingOccurrencesOfString:@". "
                                                     withString:@".\n"];
    }

    NSMutableAttributedString *written =
        [[NSMutableAttributedString alloc] initWithString:message];
    [written addAttribute:NSFontAttributeName
                    value:[NSFont systemFontOfSize:
                              [NSFont systemFontSize]]
                    range:NSMakeRange(0, message.length)];
    [written addAttribute:NSForegroundColorAttributeName
                    value:[NSColor labelColor]
                    range:NSMakeRange(0, message.length)];

    NSDataDetector *addresses = [NSDataDetector
        dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
    for (NSTextCheckingResult *found in
            [addresses matchesInString:message options:0
                                 range:NSMakeRange(0, message.length)])
    {
        if (!found.URL)
            continue;
        [written addAttribute:NSLinkAttributeName value:found.URL
                        range:found.range];
        [written addAttribute:NSUnderlineStyleAttributeName
                        value:@(NSUnderlineStyleSingle) range:found.range];
    }

    NSMutableParagraphStyle *paragraph =
        [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.paragraphSpacing = 4.0;
    [written addAttribute:NSParagraphStyleAttributeName value:paragraph
                    range:NSMakeRange(0, message.length)];

    self.stateLabel.attributedStringValue = written;
}


- (NSAttributedString *)stateText
{
    return self.stateLabel.attributedStringValue;
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
