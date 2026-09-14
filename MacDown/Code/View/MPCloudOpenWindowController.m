//
//  MPCloudOpenWindowController.m
//  MacDown
//

#import "MPCloudOpenWindowController.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "MPCloudService.h"


static NSString *const kMPCloudName = @"nome";
static NSString *const kMPCloudWhen = @"quando";
static NSString *const kMPCloudSize = @"quanto";


#pragma mark - La barra laterale

/** I servizi collegati, nello stile della barra laterale del Finder.
 *
 * Uno solo si mostra lo stesso. Una finestra che dice soltanto «apri» non
 * dice da dove, e con due servizi collegati la stessa finestra dovrebbe
 * cambiare forma: meglio che la forma sia già quella giusta.
 */
@interface MPCloudSidebar : NSViewController <NSTableViewDataSource,
                                              NSTableViewDelegate>
@property (copy, nonatomic) NSArray<MPCloudService *> *services;
@property (copy, nonatomic) void (^picked)(MPCloudService *service);
@property (strong, nonatomic) NSTableView *table;
@end


@implementation MPCloudSidebar

- (void)loadView
{
    self.table = [[NSTableView alloc] init];
    self.table.style = NSTableViewStyleSourceList;
    self.table.headerView = nil;
    self.table.rowHeight = 24.0;
    self.table.floatsGroupRows = NO;
    self.table.dataSource = self;
    self.table.delegate = self;
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:
        kMPCloudName];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.table addTableColumn:column];

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.documentView = self.table;
    self.view = scroll;
}


- (void)show:(MPCloudService *)service
{
    NSUInteger where = [self.services indexOfObject:service];
    if (where == NSNotFound)
        where = 0;
    [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:where + 1]
            byExtendingSelection:NO];
}


// Una riga di intestazione e poi i servizi: nella barra laterale del
// Finder le voci stanno sotto un titolo, e senza titolo la colonna sembra
// una lista qualunque appoggiata al bordo.
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
    return (NSInteger)self.services.count + 1;
}

- (BOOL)tableView:(NSTableView *)table isGroupRow:(NSInteger)row
{
    return row == 0;
}

- (BOOL)tableView:(NSTableView *)table shouldSelectRow:(NSInteger)row
{
    return row > 0;
}

- (NSView *)tableView:(NSTableView *)table
   viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    NSTableCellView *cell = [table makeViewWithIdentifier:
        row == 0 ? @"gruppo" : @"servizio" owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = row == 0 ? @"gruppo" : @"servizio";
        NSTextField *label = [NSTextField labelWithString:@""];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:label];
        cell.textField = label;
        if (row == 0)
        {
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:
                    cell.leadingAnchor],
                [label.centerYAnchor constraintEqualToAnchor:
                    cell.centerYAnchor],
            ]];
        }
        else
        {
            NSImageView *icon = [[NSImageView alloc] init];
            icon.translatesAutoresizingMaskIntoConstraints = NO;
            icon.contentTintColor = [NSColor controlAccentColor];
            [cell addSubview:icon];
            cell.imageView = icon;
            [NSLayoutConstraint activateConstraints:@[
                [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
                [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [icon.widthAnchor constraintEqualToConstant:18.0],
                [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor
                                                    constant:6.0],
                [label.trailingAnchor constraintLessThanOrEqualToAnchor:
                    cell.trailingAnchor],
                [label.centerYAnchor constraintEqualToAnchor:
                    cell.centerYAnchor],
            ]];
        }
    }

    if (row == 0)
    {
        cell.textField.stringValue = NSLocalizedString(@"Services",
            @"Header of the sidebar listing the connected services");
        return cell;
    }

    // Il servizio col suo nome: la cartella sta nel titolo della finestra,
    // e ripeterla qui direbbe due volte la stessa cosa.
    MPCloudService *service = self.services[(NSUInteger)row - 1];
    cell.textField.stringValue = service.name;
    cell.imageView.image = [NSImage imageWithSystemSymbolName:
        service.symbolName accessibilityDescription:service.name];
    cell.toolTip = service.placeName;
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
    NSInteger row = self.table.selectedRow;
    if (row <= 0 || (NSUInteger)row > self.services.count)
        return;
    if (self.picked)
        self.picked(self.services[(NSUInteger)row - 1]);
}

@end


#pragma mark - L'elenco

/// I documenti, con le colonne che si aspetta chi ha già aperto un file su
/// questo sistema: nome, quando è stato scritto, quanto pesa.
@interface MPCloudList : NSViewController <NSTableViewDataSource,
                                           NSTableViewDelegate>
@property (copy, nonatomic) NSArray<MPCloudDocument *> *documents;
@property (copy, nonatomic) NSString *filter;
@property (copy, nonatomic) void (^open)(MPCloudDocument *document);
@property (copy, nonatomic) void (^cancel)(void);
@property (strong, nonatomic) NSTableView *table;
@property (strong, nonatomic) NSTextField *count;
@property (strong, nonatomic) NSTextField *empty;
@property (strong, nonatomic) NSButton *openButton;
/// Quelli che si vedono adesso: filtrati e ordinati.
@property (copy, nonatomic) NSArray<MPCloudDocument *> *shown;
@end


@implementation MPCloudList

- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 420)];

    self.table = [[NSTableView alloc] init];
    self.table.style = NSTableViewStyleInset;
    self.table.rowHeight = 24.0;
    self.table.usesAlternatingRowBackgroundColors = YES;
    self.table.allowsMultipleSelection = NO;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.target = self;
    self.table.doubleAction = @selector(openPicked:);

    NSTableColumn *name = [[NSTableColumn alloc] initWithIdentifier:
        kMPCloudName];
    name.title = NSLocalizedString(@"Name", @"Column of the document list");
    name.width = 280.0;
    name.sortDescriptorPrototype = [NSSortDescriptor
        sortDescriptorWithKey:@"name" ascending:YES
                     selector:@selector(localizedStandardCompare:)];
    NSTableColumn *when = [[NSTableColumn alloc] initWithIdentifier:
        kMPCloudWhen];
    when.title = NSLocalizedString(@"Date Modified",
                                   @"Column of the document list");
    when.width = 160.0;
    when.sortDescriptorPrototype = [NSSortDescriptor
        sortDescriptorWithKey:@"modified" ascending:NO];
    NSTableColumn *size = [[NSTableColumn alloc] initWithIdentifier:
        kMPCloudSize];
    size.title = NSLocalizedString(@"Size", @"Column of the document list");
    size.width = 80.0;
    size.sortDescriptorPrototype = [NSSortDescriptor
        sortDescriptorWithKey:@"size" ascending:NO];
    for (NSTableColumn *column in @[name, when, size])
        [self.table addTableColumn:column];
    self.table.sortDescriptors = @[name.sortDescriptorPrototype];

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.documentView = self.table;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    // Quello che si legge quando non c'è niente da leggere sta in mezzo
    // alla finestra, dove si guarda, e non in una riga sotto ai pulsanti.
    self.empty = [NSTextField labelWithString:@""];
    self.empty.textColor = [NSColor secondaryLabelColor];
    self.empty.alignment = NSTextAlignmentCenter;
    self.empty.lineBreakMode = NSLineBreakByWordWrapping;
    self.empty.maximumNumberOfLines = 0;
    self.empty.preferredMaxLayoutWidth = 320.0;
    self.empty.translatesAutoresizingMaskIntoConstraints = NO;
    self.empty.hidden = YES;
    // Una frase lunga non deve decidere quanto è larga la finestra: senza
    // questo, la riga «qui non c'è ancora niente» la apriva quanto sé
    // stessa, tutta su un rigo solo.
    [self.empty setContentCompressionResistancePriority:
        NSLayoutPriorityDefaultLow
        forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.empty setContentHuggingPriority:NSLayoutPriorityDefaultLow
        forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.count = [NSTextField labelWithString:@""];
    self.count.textColor = [NSColor secondaryLabelColor];
    self.count.font = [NSFont systemFontOfSize:11.0];

    self.openButton = [NSButton buttonWithTitle:NSLocalizedString(@"Open",
        @"Opens the chosen remote document") target:self
        action:@selector(openPicked:)];
    self.openButton.keyEquivalent = @"\r";
    self.openButton.enabled = NO;
    NSButton *cancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel",
        @"Closes the list of remote documents") target:self
        action:@selector(cancelPicked:)];
    cancel.keyEquivalent = @"\033";

    NSStackView *bar = [[NSStackView alloc] initWithFrame:NSZeroRect];
    bar.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    bar.alignment = NSLayoutAttributeCenterY;
    bar.spacing = 10.0;
    bar.edgeInsets = NSEdgeInsetsMake(10.0, 16.0, 12.0, 16.0);
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addView:self.count inGravity:NSStackViewGravityLeading];
    [bar addView:cancel inGravity:NSStackViewGravityTrailing];
    [bar addView:self.openButton inGravity:NSStackViewGravityTrailing];

    NSBox *line = [[NSBox alloc] initWithFrame:NSZeroRect];
    line.boxType = NSBoxSeparator;
    line.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSView *piece in @[scroll, self.empty, line, bar])
        [view addSubview:piece];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:view.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:line.topAnchor],
        [self.empty.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],
        [self.empty.centerYAnchor constraintEqualToAnchor:scroll.centerYAnchor],
        [self.empty.widthAnchor constraintEqualToConstant:320.0],
        [line.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [line.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [line.bottomAnchor constraintEqualToAnchor:bar.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
    ]];
    self.view = view;
}


/// Cosa c'è da vedere, detto in una riga: il filtro, l'ordine, il conto.
- (void)show:(NSArray<MPCloudDocument *> *)documents note:(NSString *)note
{
    self.documents = documents ?: @[];
    [self refresh:note];
}


- (void)refresh:(NSString *)note
{
    NSArray<MPCloudDocument *> *kept = self.documents;
    if (self.filter.length)
    {
        NSString *wanted = self.filter;
        kept = [kept filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL (MPCloudDocument *document,
                                                   NSDictionary *bindings) {
            return [document.name rangeOfString:wanted
                options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]];
    }
    self.shown = [kept sortedArrayUsingDescriptors:self.table.sortDescriptors];
    [self.table reloadData];
    self.openButton.enabled = self.table.selectedRow >= 0;

    self.empty.stringValue = note ?: @"";
    self.empty.hidden = self.shown.count > 0 || !note.length;
    if (!self.documents.count)
        self.count.stringValue = @"";
    else if (self.shown.count == self.documents.count)
        self.count.stringValue = [NSString stringWithFormat:
            NSLocalizedString(@"%lu documents", @"How many are in the list"),
            (unsigned long)self.shown.count];
    else
        self.count.stringValue = [NSString stringWithFormat:
            NSLocalizedString(@"%lu of %lu documents",
                @"How many are in the list once a search narrowed it"),
            (unsigned long)self.shown.count,
            (unsigned long)self.documents.count];
}


- (void)setFilter:(NSString *)filter
{
    _filter = [filter copy];
    [self refresh:self.empty.stringValue];
}


#pragma mark - Le righe

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
    return (NSInteger)self.shown.count;
}

- (NSView *)tableView:(NSTableView *)table
   viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    MPCloudDocument *document = self.shown[(NSUInteger)row];
    NSString *kind = column.identifier;
    NSTableCellView *cell = [table makeViewWithIdentifier:kind owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = kind;
        NSTextField *label = [NSTextField labelWithString:@""];
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:label];
        cell.textField = label;
        if ([kind isEqualToString:kMPCloudName])
        {
            NSImageView *icon = [[NSImageView alloc] init];
            icon.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:icon];
            cell.imageView = icon;
            [NSLayoutConstraint activateConstraints:@[
                [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor
                                                   constant:2.0],
                [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [icon.widthAnchor constraintEqualToConstant:16.0],
                [icon.heightAnchor constraintEqualToConstant:16.0],
                [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor
                                                    constant:6.0],
            ]];
        }
        else
        {
            label.textColor = [NSColor secondaryLabelColor];
            label.alignment = [kind isEqualToString:kMPCloudSize]
                ? NSTextAlignmentRight : NSTextAlignmentLeft;
            [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor
                                                constant:2.0].active = YES;
        }
        [NSLayoutConstraint activateConstraints:@[
            [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor
                                                 constant:-2.0],
            [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }

    if ([kind isEqualToString:kMPCloudName])
    {
        cell.textField.stringValue = document.name ?: @"";
        cell.imageView.image = [self iconFor:document.name];
    }
    else if ([kind isEqualToString:kMPCloudWhen])
    {
        cell.textField.stringValue = [self whenOf:document.modified];
    }
    else
    {
        cell.textField.stringValue = document.size > 0
            ? [NSByteCountFormatter stringFromByteCount:document.size
                   countStyle:NSByteCountFormatterCountStyleFile]
            : @"--";
    }
    return cell;
}

- (void)tableView:(NSTableView *)table
    sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)was
{
    [self refresh:self.empty.stringValue];
}

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
    self.openButton.enabled = self.table.selectedRow >= 0;
}


/// L'icona che il sistema dà a un file con quel nome: un .md e un .txt si
/// distinguono così, come in una cartella qualunque.
- (NSImage *)iconFor:(NSString *)name
{
    UTType *type = [UTType typeWithFilenameExtension:
        name.pathExtension ?: @""] ?: UTTypePlainText;
    return [[NSWorkspace sharedWorkspace] iconForContentType:type];
}

- (NSString *)whenOf:(NSDate *)when
{
    if (!when)
        return @"--";
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        formatter.doesRelativeDateFormatting = YES;
    });
    return [formatter stringFromDate:when];
}


#pragma mark - I pulsanti

- (void)openPicked:(id)sender
{
    NSInteger row = self.table.selectedRow;
    if (row < 0 || (NSUInteger)row >= self.shown.count)
        return;
    if (self.open)
        self.open(self.shown[(NSUInteger)row]);
}

- (void)cancelPicked:(id)sender
{
    if (self.cancel)
        self.cancel();
}

@end


#pragma mark - La finestra

@interface MPCloudOpenWindowController () <NSToolbarDelegate, NSSearchFieldDelegate>
@property (strong, nonatomic) MPCloudService *service;
@property (strong, nonatomic) MPCloudSidebar *sidebar;
@property (strong, nonatomic) MPCloudList *list;
@property (strong, nonatomic) NSSplitViewController *split;
@property (copy, nonatomic) void (^chosen)(MPCloudService *, MPCloudDocument *);
@end


@implementation MPCloudOpenWindowController

+ (void)chooseFrom:(MPCloudService *)service
            chosen:(void (^)(MPCloudService *, MPCloudDocument *))chosen
{
    static MPCloudOpenWindowController *open = nil;
    open = [[MPCloudOpenWindowController alloc] initWithService:service
                                                         chosen:chosen];
    [open showWindow:nil];
    [open.window makeKeyAndOrderFront:nil];
    [open reload];
}


- (instancetype)initWithService:(MPCloudService *)service
                         chosen:(void (^)(MPCloudService *,
                                          MPCloudDocument *))chosen
{
    NSWindow *window = [[NSWindow alloc] initWithContentRect:
        NSMakeRect(0.0, 0.0, 760.0, 460.0)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
                | NSWindowStyleMaskFullSizeContentView
          backing:NSBackingStoreBuffered defer:NO];
    window.minSize = NSMakeSize(560.0, 320.0);
    [window center];

    self = [super initWithWindow:window];
    if (!self)
        return nil;
    _service = service;
    _chosen = [chosen copy];
    [self build];
    return self;
}


- (void)build
{
    __weak MPCloudOpenWindowController *weakSelf = self;

    self.sidebar = [[MPCloudSidebar alloc] init];
    self.sidebar.services = [self linked];
    self.sidebar.picked = ^(MPCloudService *picked) {
        [weakSelf changeTo:picked];
    };

    self.list = [[MPCloudList alloc] init];
    self.list.open = ^(MPCloudDocument *document) {
        [weakSelf finishWith:document];
    };
    self.list.cancel = ^{
        [weakSelf finishWith:nil];
    };

    NSSplitViewItem *side = [NSSplitViewItem
        sidebarWithViewController:self.sidebar];
    side.minimumThickness = 150.0;
    side.maximumThickness = 240.0;
    side.canCollapse = YES;
    NSSplitViewItem *main = [NSSplitViewItem
        contentListWithViewController:self.list];
    main.minimumThickness = 360.0;

    self.split = [[NSSplitViewController alloc] init];
    [self.split addSplitViewItem:side];
    [self.split addSplitViewItem:main];
    self.window.contentViewController = self.split;

    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"servizio"];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    self.window.toolbar = toolbar;
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;

    [self.sidebar show:self.service];
    [self nameTheWindow];
}


/// I servizi in cui c'è davvero qualcosa da aprire.
- (NSArray<MPCloudService *> *)linked
{
    NSMutableArray *linked = [NSMutableArray array];
    for (MPCloudService *service in [MPCloudService services])
    {
        if (service.isLinked)
            [linked addObject:service];
    }
    if (self.service && ![linked containsObject:self.service])
        [linked insertObject:self.service atIndex:0];
    return linked;
}


- (void)nameTheWindow
{
    // Il titolo è il posto, il sottotitolo è il servizio: come una
    // cartella, che si chiama col suo nome e non «disco».
    self.window.title = self.service.placeName.length ? self.service.placeName
                                                      : self.service.name;
    self.window.subtitle = self.service.name;
}


- (void)changeTo:(MPCloudService *)service
{
    if (service == self.service)
        return;
    self.service = service;
    [self nameTheWindow];
    [self reload];
}


- (void)reload
{
    [self.list show:@[] note:NSLocalizedString(@"Asking…",
        @"While the list of remote documents is being fetched")];
    MPCloudService *asked = self.service;
    [asked documentsWithCompletion:
     ^(NSArray<MPCloudDocument *> *found, NSString *problem) {
        if (asked != self.service)
            return;             // nel frattempo si è cambiato servizio
        NSString *note = problem;
        if (!problem && !found.count)
            note = asked.picksDocuments
                ? NSLocalizedString(
                    @"Nothing here yet.\nWhat this application writes into "
                    @"the folder shows up here; documents that were already "
                    @"there are handed over in Settings ▸ Sync.",
                    @"When the connected service shows no documents")
                : NSLocalizedString(
                    @"Nothing here yet.\nPut a document in the folder, or "
                    @"write one and save it there.",
                    @"When the connected folder is empty");
        [self.list show:found note:note];
    }];
}


- (void)finishWith:(MPCloudDocument *)document
{
    void (^chosen)(MPCloudService *, MPCloudDocument *) = self.chosen;
    MPCloudService *from = self.service;
    self.chosen = nil;
    [self close];
    if (chosen)
        chosen(from, document);
}


#pragma mark - La barra degli strumenti

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:
    (NSToolbar *)toolbar
{
    return @[NSToolbarToggleSidebarItemIdentifier,
             NSToolbarSidebarTrackingSeparatorItemIdentifier,
             NSToolbarFlexibleSpaceItemIdentifier,
             @"cerca"];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:
    (NSToolbar *)toolbar
{
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSToolbarItemIdentifier)identifier
 willBeInsertedIntoToolbar:(BOOL)inserted
{
    if (![identifier isEqualToString:@"cerca"])
        return nil;
    NSSearchToolbarItem *item = [[NSSearchToolbarItem alloc]
        initWithItemIdentifier:identifier];
    item.searchField.delegate = self;
    item.searchField.placeholderString = NSLocalizedString(@"Search",
        @"Placeholder of the field that narrows the list of documents");
    item.resignsFirstResponderWithCancel = YES;
    return item;
}

- (void)controlTextDidChange:(NSNotification *)note
{
    NSSearchField *field = note.object;
    if ([field isKindOfClass:[NSSearchField class]])
        self.list.filter = field.stringValue;
}

@end
