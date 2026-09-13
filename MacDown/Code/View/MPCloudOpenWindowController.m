//
//  MPCloudOpenWindowController.m
//  MacDown
//

#import "MPCloudOpenWindowController.h"

#import "MPCloudService.h"


@interface MPCloudOpenWindowController ()
@property (strong, nonatomic) MPCloudService *service;
@property (strong, nonatomic) NSArray<MPCloudDocument *> *documents;
@property (strong, nonatomic) NSTableView *table;
@property (strong, nonatomic) NSTextField *note;
@property (strong, nonatomic) NSButton *openButton;
@property (copy, nonatomic) void (^chosen)(MPCloudDocument *);
@end


@implementation MPCloudOpenWindowController

+ (void)chooseFrom:(MPCloudService *)service
            chosen:(void (^)(MPCloudDocument *))chosen
{
    static MPCloudOpenWindowController *open = nil;
    open = [[MPCloudOpenWindowController alloc] initWithService:service
                                                         chosen:chosen];
    [open showWindow:nil];
    [open.window makeKeyAndOrderFront:nil];
    [open reload];
}


- (instancetype)initWithService:(MPCloudService *)service
                         chosen:(void (^)(MPCloudDocument *))chosen
{
    NSWindow *window = [[NSWindow alloc] initWithContentRect:
        NSMakeRect(0.0, 0.0, 420.0, 320.0)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
          backing:NSBackingStoreBuffered defer:NO];
    window.title = [NSString stringWithFormat:NSLocalizedString(
        @"Open from %@", @"Title of the window that lists remote documents"),
        service.name];
    [window center];

    self = [super initWithWindow:window];
    if (!self)
        return nil;
    _service = service;
    _chosen = [chosen copy];
    _documents = @[];
    [self build];
    return self;
}


- (void)build
{
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    self.table = [[NSTableView alloc] init];
    self.table.headerView = nil;
    self.table.rowHeight = 22.0;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.target = self;
    self.table.doubleAction = @selector(open:);
    NSTableColumn *column = [[NSTableColumn alloc]
        initWithIdentifier:@"nome"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.table addTableColumn:column];
    scroll.documentView = self.table;

    self.note = [NSTextField labelWithString:NSLocalizedString(
        @"Asking…", @"While the list of remote documents is being fetched")];
    self.note.textColor = [NSColor secondaryLabelColor];
    self.note.translatesAutoresizingMaskIntoConstraints = NO;

    self.openButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Open the document", @"Opens the chosen remote document")
        target:self action:@selector(open:)];
    self.openButton.keyEquivalent = @"\r";
    self.openButton.enabled = NO;
    NSButton *cancel = [NSButton buttonWithTitle:NSLocalizedString(
        @"Cancel", @"Closes the list of remote documents")
        target:self action:@selector(cancel:)];
    cancel.keyEquivalent = @"\033";

    NSStackView *buttons = [NSStackView stackViewWithViews:
        @[cancel, self.openButton]];
    buttons.spacing = 10.0;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *content = self.window.contentView;
    [content addSubview:scroll];
    [content addSubview:self.note];
    [content addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:content.topAnchor
                                         constant:16.0],
        [scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor
                                             constant:16.0],
        [scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor
                                              constant:-16.0],
        [self.note.topAnchor constraintEqualToAnchor:scroll.bottomAnchor
                                            constant:10.0],
        [self.note.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [buttons.topAnchor constraintEqualToAnchor:self.note.bottomAnchor
                                          constant:10.0],
        [buttons.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:content.bottomAnchor
                                             constant:-16.0],
    ]];
}


- (void)reload
{
    [self.service documentsWithCompletion:
     ^(NSArray<MPCloudDocument *> *found, NSString *problem) {
        self.documents = found ?: @[];
        [self.table reloadData];
        if (problem)
            self.note.stringValue = problem;
        else if (!self.documents.count)
            self.note.stringValue = NSLocalizedString(
                @"Nothing here yet. What this application writes into the "
                @"folder shows up here; documents that were already there "
                @"have to be handed over in the picker.",
                @"When the connected service shows no documents");
        else
            self.note.stringValue = [NSString stringWithFormat:
                NSLocalizedString(@"%lu documents.",
                    @"How many remote documents there are"),
                (unsigned long)self.documents.count];
    }];
}


#pragma mark - L'elenco

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
    return (NSInteger)self.documents.count;
}

- (NSView *)tableView:(NSTableView *)table
   viewForTableColumn:(NSTableColumn *)column
                  row:(NSInteger)row
{
    NSTextField *cell = [table makeViewWithIdentifier:@"nome" owner:self];
    if (!cell)
    {
        cell = [NSTextField labelWithString:@""];
        cell.identifier = @"nome";
    }
    cell.stringValue = self.documents[(NSUInteger)row].name ?: @"";
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    self.openButton.enabled = self.table.selectedRow >= 0;
}


#pragma mark - I pulsanti

- (void)open:(id)sender
{
    NSInteger row = self.table.selectedRow;
    if (row < 0 || (NSUInteger)row >= self.documents.count)
        return;
    MPCloudDocument *document = self.documents[(NSUInteger)row];
    void (^chosen)(MPCloudDocument *) = self.chosen;
    self.chosen = nil;
    [self close];
    if (chosen)
        chosen(document);
}

- (void)cancel:(id)sender
{
    void (^chosen)(MPCloudDocument *) = self.chosen;
    self.chosen = nil;
    [self close];
    if (chosen)
        chosen(nil);
}

@end
