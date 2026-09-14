//
//  MPSyncPreferencesViewController.m
//  MacDown
//

#import "MPSyncPreferencesViewController.h"

#import "MPCloudService.h"


static const CGFloat kMPPanelWidth = 640.0;
static const CGFloat kMPPanelPadding = 20.0;
/// La colonna dei servizi, a sinistra, e quello che resta a destra.
static const CGFloat kMPServicesWidth = 150.0;
static const CGFloat kMPGutter = 16.0;
static const CGFloat kMPDetailWidth = kMPPanelWidth - kMPServicesWidth
                                    - kMPPanelPadding * 2.0 - kMPGutter;

/// Dove si crea un client OAuth. Sta scritto qui una volta sola perché è
/// l'unica cosa di questo pannello che non si può spiegare a parole.
static NSString *const kMPConsole = @"https://console.cloud.google.com/apis/credentials";


@interface MPSyncPreferencesViewController () <NSTableViewDataSource,
                                              NSTableViewDelegate>

@property (strong, nonatomic) NSTableView *list;
/// Cosa si è mosso all'ultima occhiata, detto a parole.
@property (copy, nonatomic) NSString *movement;
/// La scheda con dentro tutto quello che riguarda il collegamento.
@property (strong, nonatomic) NSBox *card;
@property (strong, nonatomic) NSImageView *dot;
@property (strong, nonatomic) NSTextField *stateLabel;
@property (strong, nonatomic) NSButton *mainButton;
@property (strong, nonatomic) NSPopUpButton *moreButton;
@property (strong, nonatomic) NSTextField *clientTitle;
@property (strong, nonatomic) NSTextField *clientField;
@property (strong, nonatomic) NSButton *helpButton;
@property (strong, nonatomic) NSStackView *clientRow;
@property (strong, nonatomic) NSStackView *buttons;
/// Quello che si legge solo se lo si chiede: il come e il perché, che
/// sono la parte lunga e che nessuno rilegge dopo la prima volta.
@property (strong, nonatomic) NSPopover *help;
/// Il segreto, dietro il triangolino: facoltativo per un client desktop.
@property (strong, nonatomic) NSButton *moreFields;
@property (strong, nonatomic) NSStackView *secretTitleRow;
@property (strong, nonatomic) NSStackView *secretRow;
@property (strong, nonatomic) NSSecureTextField *secretField;

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
    NSInteger index = self.list.selectedRow;
    if (index < 0 || (NSUInteger)index >= services.count)
        index = 0;
    return services[index];
}


/** Poche cose, e quelle che servono sempre.
 *
 * Il pannello di prima diceva tutto quello che c'è da sapere, tutto in
 * una volta: com'è fatto un client OAuth, perché il segreto è facoltativo,
 * cosa si sta chiedendo al servizio. Roba vera, che però si legge una
 * volta sola e poi resta lì a fare da muro fra chi apre le impostazioni e
 * il pulsante che gli serve. Adesso sta dietro il «?», e in vista restano
 * tre cose: dove sei, un campo, un pulsante.
 */
- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPPanelWidth, 280.0)];

    // I servizi stanno in colonna, uno sotto l'altro, come nella barra
    // laterale di una finestra qualunque: le schede in fila mettevano tre
    // nomi lunghi in una riga sola, e il terzo — che è un segnaposto — ci
    // stava peggio di tutti.
    self.list = [[NSTableView alloc] init];
    self.list.style = NSTableViewStyleSourceList;
    self.list.headerView = nil;
    self.list.rowHeight = 28.0;
    self.list.dataSource = self;
    self.list.delegate = self;
    NSTableColumn *only = [[NSTableColumn alloc]
        initWithIdentifier:@"servizio"];
    only.resizingMask = NSTableColumnAutoresizingMask;
    [self.list addTableColumn:only];

    NSScrollView *listScroll = [[NSScrollView alloc] init];
    listScroll.drawsBackground = NO;
    listScroll.hasVerticalScroller = YES;
    listScroll.documentView = self.list;
    listScroll.translatesAutoresizingMaskIntoConstraints = NO;

    // Il pallino dice lo stato prima delle parole: verde collegato,
    // arancione qualcosa da sistemare, grigio non ancora.
    self.dot = [[NSImageView alloc] init];
    self.dot.image = [NSImage imageWithSystemSymbolName:@"circle.fill"
                             accessibilityDescription:nil];
    self.dot.symbolConfiguration = [NSImageSymbolConfiguration
        configurationWithPointSize:9.0 weight:NSFontWeightRegular];
    [self.dot.widthAnchor constraintEqualToConstant:12.0].active = YES;

    // La larghezza della scheda meno i suoi margini, meno il pallino.
    self.stateLabel = [self paragraph:@"" width:kMPDetailWidth - 28.0 - 20.0];
    self.stateLabel.textColor = [NSColor labelColor];
    // Perché un indirizzo dentro un messaggio del servizio si possa
    // premere invece che ricopiare a mano.
    self.stateLabel.allowsEditingTextAttributes = YES;
    self.stateLabel.selectable = YES;

    self.mainButton = [NSButton buttonWithTitle:@"" target:self
                                         action:@selector(mainAction:)];
    self.mainButton.controlSize = NSControlSizeRegular;
    self.moreButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect
                                                 pullsDown:YES];
    [self.moreButton.widthAnchor constraintEqualToConstant:44.0].active = YES;

    NSStackView *state = [NSStackView stackViewWithViews:
        @[self.dot, self.stateLabel]];
    state.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    state.alignment = NSLayoutAttributeFirstBaseline;
    state.spacing = 8.0;

    self.helpButton = [NSButton buttonWithTitle:@"" target:self
                                         action:@selector(showHelp:)];
    self.helpButton.bezelStyle = NSBezelStyleHelpButton;
    self.helpButton.title = @"";

    self.buttons = [[NSStackView alloc] initWithFrame:NSZeroRect];
    self.buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.buttons.spacing = 8.0;
    [self.buttons addView:self.mainButton inGravity:NSStackViewGravityLeading];
    [self.buttons addView:self.moreButton inGravity:NSStackViewGravityLeading];
    [self.buttons addView:self.helpButton inGravity:NSStackViewGravityTrailing];

    [self.buttons.widthAnchor constraintEqualToConstant:
        kMPDetailWidth - 28.0].active = YES;
    NSStackView *inside = [NSStackView stackViewWithViews:
        @[state, self.buttons]];
    inside.orientation = NSUserInterfaceLayoutOrientationVertical;
    inside.alignment = NSLayoutAttributeLeading;
    inside.spacing = 12.0;
    inside.edgeInsets = NSEdgeInsetsMake(14.0, 14.0, 14.0, 14.0);

    self.card = [[NSBox alloc] initWithFrame:NSZeroRect];
    self.card.boxType = NSBoxCustom;
    self.card.borderWidth = 0.0;
    self.card.cornerRadius = 8.0;
    self.card.fillColor = [NSColor controlBackgroundColor];
    self.card.contentViewMargins = NSZeroSize;
    self.card.titlePosition = NSNoTitle;
    // Una NSBox non lega da sola quello che le si mette dentro: senza
    // questi quattro vincoli il contenuto si disegna dove capita — sopra
    // quello che viene prima, come si è visto.
    inside.translatesAutoresizingMaskIntoConstraints = NO;
    self.card.contentView = inside;
    [NSLayoutConstraint activateConstraints:@[
        [inside.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor],
        [inside.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor],
        [inside.topAnchor constraintEqualToAnchor:self.card.topAnchor],
        [inside.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor],
    ]];

    self.clientTitle = [self label:NSLocalizedString(
        @"Client ID", @"Field for the client identifier")];
    self.clientField = [NSTextField textFieldWithString:@""];
    self.clientField.delegate = self;
    [self.clientField.widthAnchor constraintEqualToConstant:320.0].active = YES;
    self.clientRow = [NSStackView stackViewWithViews:
        @[self.clientTitle, self.clientField]];
    self.clientRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.clientRow.spacing = 8.0;

    // Il triangolino di AppKit mostra solo sé stesso: la scritta gli va
    // messa accanto, e si preme anche quella — che è come si comporta
    // ovunque nel sistema.
    self.moreFields = [NSButton buttonWithTitle:@"" target:self
                                         action:@selector(toggleSecret:)];
    self.moreFields.bezelStyle = NSBezelStyleDisclosure;
    self.moreFields.buttonType = NSButtonTypePushOnPushOff;
    self.moreFields.title = @"";
    NSTextField *secretTitle = [self label:NSLocalizedString(
        @"Client secret (optional)",
        @"Disclosure that shows the client secret field")];
    secretTitle.textColor = [NSColor secondaryLabelColor];
    [secretTitle addGestureRecognizer:[[NSClickGestureRecognizer alloc]
        initWithTarget:self action:@selector(clickTheDisclosure:)]];
    self.secretTitleRow = [NSStackView stackViewWithViews:
        @[self.moreFields, secretTitle]];
    self.secretTitleRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.secretTitleRow.spacing = 4.0;

    self.secretField = [[NSSecureTextField alloc] init];
    self.secretField.placeholderString = NSLocalizedString(
        @"kept in the keychain",
        @"Placeholder of the client secret field");
    self.secretField.delegate = self;
    [self.secretField.widthAnchor constraintEqualToConstant:320.0].active = YES;
    self.secretRow = [NSStackView stackViewWithViews:@[self.secretField]];
    self.secretRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.secretRow.edgeInsets = NSEdgeInsetsMake(0.0, 18.0, 0.0, 0.0);
    self.secretRow.hidden = YES;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[self.card, self.clientRow, self.secretTitleRow, self.secretRow]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 14.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [column setCustomSpacing:18.0 afterView:self.card];
    [column setCustomSpacing:8.0 afterView:self.clientRow];
    [column setCustomSpacing:6.0 afterView:self.secretTitleRow];

    [view addSubview:listScroll];
    [view addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [listScroll.leadingAnchor constraintEqualToAnchor:view.leadingAnchor
                                                 constant:kMPPanelPadding],
        [listScroll.topAnchor constraintEqualToAnchor:view.topAnchor
                                             constant:kMPPanelPadding],
        [listScroll.bottomAnchor constraintEqualToAnchor:view.bottomAnchor
                                                constant:-kMPPanelPadding],
        [listScroll.widthAnchor constraintEqualToConstant:kMPServicesWidth],

        [column.leadingAnchor constraintEqualToAnchor:listScroll.trailingAnchor
                                             constant:kMPGutter],
        [column.widthAnchor constraintEqualToConstant:kMPDetailWidth],
        [column.topAnchor constraintEqualToAnchor:view.topAnchor
                                         constant:kMPPanelPadding],
        [column.bottomAnchor constraintLessThanOrEqualToAnchor:view.bottomAnchor
                                                     constant:-kMPPanelPadding],
        [self.card.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [self.card.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
    ]];
    self.view = view;
    // Alla fine, e non appena l'elenco esiste: scegliere una riga chiama
    // subito chi ascolta, e chi ascolta vuole trovare il pannello finito.
    [self.list selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
           byExtendingSelection:NO];
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
    if (!self.card)
        return;             // il pannello non è ancora costruito
    MPCloudService *service = [self chosen];

    self.clientField.placeholderString = service.clientPlaceholder;
    self.clientField.stringValue = service.clientIdentifier;
    self.secretField.stringValue = service.clientSecret;

    // Un segnaposto mostra il perché e niente su cui mettere le mani; e
    // un servizio che non chiede credenziali non mostra i campi che
    // servono a incollarle.
    BOOL ready = service.available;
    BOOL credentials = ready && service.needsAClient;
    for (NSView *row in @[self.clientRow, self.secretTitleRow,
                          self.secretRow])
        row.hidden = !credentials;
    self.secretRow.hidden = !credentials
        || self.moreFields.state != NSControlStateValueOn;
    self.buttons.hidden = !ready;

    if (ready)
        [self showState];
    else
    {
        [self dotColour:[NSColor tertiaryLabelColor]];
        [self say:service.explanation];
    }
}


/// Una riga sola, e dice solo quello che è successo davvero.
- (void)showState
{
    MPCloudService *service = [self chosen];

    if (!service.isConfigured)
    {
        [self dotColour:[NSColor tertiaryLabelColor]];
        [self offer:NSLocalizedString(@"Connect…",
            @"Button that starts the permission") enabled:NO];
        [self say:NSLocalizedString(@"Paste your client ID to begin.",
            @"State: the pane has no client identifier")];
        return;
    }

    // Il guaio, con le parole del servizio: «la Drive API non è attiva in
    // questo progetto» è una frase che si risolve in un clic, e nasconderla
    // lascerebbe un'applicazione collegata che non vede niente.
    if (service.isLinked && service.problem.length)
    {
        [self dotColour:[NSColor systemOrangeColor]];
        [self offer:NSLocalizedString(@"Try Again",
            @"Button that asks the service once more") enabled:YES];
        [self say:service.problem];
        return;
    }
    if (!service.isLinked)
    {
        [self dotColour:[NSColor tertiaryLabelColor]];
        [self offer:NSLocalizedString(@"Connect…",
            @"Button that starts the permission") enabled:YES];
        [self say:NSLocalizedString(@"Not connected yet.",
                                    @"State: no permission yet")];
        return;
    }

    [self dotColour:[NSColor systemGreenColor]];
    [self offer:service.picksDocuments
        ? NSLocalizedString(@"Add Documents…",
            @"Button that hands single documents over")
        : NSLocalizedString(@"Change Folder…",
            @"Button that picks another folder") enabled:YES];

    NSString *place = service.placeName.length ? service.placeName : nil;
    if (!place)
    {
        [self say:NSLocalizedString(@"Connected.",
                                    @"State: connected to a service")];
        return;
    }

    NSInteger visible = service.visibleInPlace;
    if (visible > 0)
    {
        NSString *line = [NSString stringWithFormat:
            NSLocalizedString(@"«%@» — %ld documents",
                @"State: connected, the chosen folder and what is visible"),
            place, (long)visible];
        if (self.movement.length)
            line = [line stringByAppendingFormat:@" · %@", self.movement];
        [self say:line];
    }
    else if (visible == 0)
    {
        // Zero vuol dire due cose diverse e non sappiamo quale: una
        // cartella vuota e una cartella i cui documenti non sono compresi
        // nel permesso rispondono uguale. Il pannello lo dice corto, e il
        // «?» tiene il resto.
        [self dotColour:[NSColor systemOrangeColor]];
        [self say:[NSString stringWithFormat:NSLocalizedString(
            @"«%@» — nothing visible in there yet.",
            @"State: the folder came across, and it looks empty"), place]];
    }
    else
    {
        [self say:[NSString stringWithFormat:
            NSLocalizedString(@"«%@»",
                @"State: connected, and what the connection covers"), place]];
    }
}


/// Il pulsante grande, e quello che c'è dietro i puntini.
- (void)offer:(NSString *)title enabled:(BOOL)enabled
{
    MPCloudService *service = [self chosen];
    self.mainButton.title = title;
    self.mainButton.enabled = enabled;

    [self.moreButton removeAllItems];
    // La prima voce di un menu a tendina è il suo titolo e non si sceglie:
    // qui sono i tre puntini.
    [self.moreButton addItemWithTitle:@"⋯"];
    NSMutableArray<NSString *> *rest = [NSMutableArray array];
    if (service.isConfigured && service.picksDocuments)
        [rest addObject:NSLocalizedString(@"Choose Folder…",
            @"Menu item: pick the folder to write into")];
    if (service.isLinked)
    {
        [rest addObject:NSLocalizedString(@"Refresh",
            @"Menu item: ask the service what it sees, again")];
        [rest addObject:NSLocalizedString(@"Disconnect",
            @"Menu item: forget the tokens of a service")];
    }
    for (NSString *entry in rest)
    {
        NSMenuItem *item = [self.moreButton.menu addItemWithTitle:entry
            action:@selector(moreAction:) keyEquivalent:@""];
        item.target = self;
    }
    self.moreButton.enabled = rest.count > 0;
}


- (void)dotColour:(NSColor *)colour
{
    self.dot.contentTintColor = colour;
}


#pragma mark - L'elenco dei servizi

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
    return (NSInteger)[MPCloudService services].count;
}

/// Un servizio che non c'è ancora si vede e non si sceglie: nasconderlo
/// vorrebbe dire far cercare alla gente una cosa che è in programma.
- (BOOL)tableView:(NSTableView *)table shouldSelectRow:(NSInteger)row
{
    NSArray<MPCloudService *> *services = [MPCloudService services];
    return row >= 0 && (NSUInteger)row < services.count
        && services[(NSUInteger)row].available;
}

- (NSView *)tableView:(NSTableView *)table
   viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    MPCloudService *service = [MPCloudService services][(NSUInteger)row];
    NSTableCellView *cell = [table makeViewWithIdentifier:@"servizio"
                                                    owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"servizio";
        NSImageView *icon = [[NSImageView alloc] init];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        NSTextField *label = [NSTextField labelWithString:@""];
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:icon];
        [cell addSubview:label];
        cell.imageView = icon;
        cell.textField = label;
        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:18.0],
            [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor
                                                constant:6.0],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:
                cell.trailingAnchor],
            [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }
    cell.textField.stringValue = service.name;
    cell.textField.textColor = service.available
        ? [NSColor labelColor] : [NSColor tertiaryLabelColor];
    cell.imageView.image = [NSImage imageWithSystemSymbolName:
        service.symbolName accessibilityDescription:service.name];
    cell.imageView.contentTintColor = service.available
        ? [NSColor controlAccentColor] : [NSColor tertiaryLabelColor];
    cell.toolTip = service.available ? nil : service.explanation;
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
    [self showService];
}


#pragma mark - Quello che fanno i comandi

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


/** Il pulsante grande fa la cosa che serve adesso.
 *
 * Non collegato: si collega, scegliendo la cartella — che è il primo
 * gesto, sempre. Collegato: si aggiungono documenti, che è l'unico gesto
 * che si ripete. Con un guaio in corso: si richiede.
 */
- (void)mainAction:(id)sender
{
    MPCloudService *service = [self chosen];
    if (service.isLinked && service.problem.length)
        [self check:nil];
    else if (service.isLinked && service.picksDocuments)
        [self link:MPCloudPickDocuments];
    else
        [self link:MPCloudPickFolder];
}


/// Quello che si usa di rado sta dietro i puntini, per titolo.
- (void)moreAction:(NSMenuItem *)item
{
    NSString *title = item.title;
    if ([title isEqualToString:NSLocalizedString(@"Choose Folder…",
            @"Menu item: pick the folder to write into")])
        [self link:MPCloudPickFolder];
    else if ([title isEqualToString:NSLocalizedString(@"Refresh",
            @"Menu item: ask the service what it sees, again")])
        [self check:nil];
    else if ([title isEqualToString:NSLocalizedString(@"Disconnect",
            @"Menu item: forget the tokens of a service")])
        [self unlink:nil];
}


- (void)toggleSecret:(id)sender
{
    self.secretRow.hidden = self.moreFields.state != NSControlStateValueOn;
}


/// Premere la scritta è premere il triangolino.
- (void)clickTheDisclosure:(id)sender
{
    self.moreFields.state = self.moreFields.state == NSControlStateValueOn
        ? NSControlStateValueOff : NSControlStateValueOn;
    [self toggleSecret:sender];
}


/** Il perché, dietro un «?».
 *
 * Sono le tre cose che prima stavano sempre in vista: cos'è questo
 * servizio, come ci si registra un client, e cosa gli si sta chiedendo.
 * Vanno lette una volta e poi mai più, quindi stanno dove si va a
 * cercarle invece che dove si inciampa.
 */
- (void)showHelp:(id)sender
{
    MPCloudService *service = [self chosen];

    CGFloat wide = 320.0;
    NSTextField *what = [self paragraph:service.explanation width:wide];
    NSTextField *how = [self paragraph:service.howToGetAClient width:wide];
    NSTextField *scope = [self paragraph:service.scopeExplanation width:wide];
    BOOL credentials = service.needsAClient;
    NSTextField *secret = [self paragraph:NSLocalizedString(
        @"The secret of a desktop client is not really a secret — PKCE "
        @"protects the permission instead. Paste it only if your client "
        @"refuses without it. It lives in the keychain, like the tokens.",
        @"Why the client secret is optional") width:wide];

    NSButton *console = [NSButton buttonWithTitle:service.consoleButtonTitle
        target:self action:@selector(openConsole:)];

    NSArray *pieces = credentials ? @[what, how, console, scope, secret]
                                  : @[what, scope];
    NSStackView *column = [NSStackView stackViewWithViews:pieces];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 10.0;
    column.edgeInsets = NSEdgeInsetsMake(16.0, 16.0, 16.0, 16.0);

    NSViewController *inside = [[NSViewController alloc] init];
    inside.view = column;

    self.help = [[NSPopover alloc] init];
    self.help.behavior = NSPopoverBehaviorTransient;
    self.help.contentViewController = inside;
    [self.help showRelativeToRect:self.helpButton.bounds
                           ofView:self.helpButton
                    preferredEdge:NSMaxXEdge];
}


- (void)linkFolder:(id)sender
{
    [self link:MPCloudPickFolder];
}


- (void)linkDocuments:(id)sender
{
    [self link:MPCloudPickDocuments];
}


- (void)link:(MPCloudPick)what
{
    self.mainButton.enabled = NO;
    self.moreButton.enabled = NO;
    [self say:NSLocalizedString(@"Waiting for the browser…",
        @"State while the consent screen is open")];

    [[self chosen] link:what completion:
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
    self.moreButton.enabled = NO;
    self.movement = nil;
    [self say:NSLocalizedString(@"Asking…",
        @"State while the service is being asked what it sees")];

    MPCloudService *service = [self chosen];
    [service checkWithCompletion:^(NSString *problem) {
        if (problem)
        {
            [self showState];
            return;
        }
        // Due domande, una dietro l'altra: cosa si vede, e cosa si è
        // mosso da quando si è guardato l'ultima volta.
        [service changesWithCompletion:^(MPCloudDelta *delta, NSString *bad) {
            self.movement = delta.summary;
            [self showState];
        }];
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


- (NSView *)clientFieldForTesting
{
    return self.clientField;
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
    return [self paragraph:string
                     width:kMPPanelWidth - kMPPanelPadding * 2.0];
}

/// Un paragrafo che va a capo dentro una larghezza data: dentro una
/// scheda non c'è tutta la finestra, e un testo che non lo sa esce fuori.
- (NSTextField *)paragraph:(NSString *)string width:(CGFloat)width
{
    NSTextField *label = [self label:string];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.textColor = [NSColor secondaryLabelColor];
    [label.widthAnchor constraintEqualToConstant:width].active = YES;
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
