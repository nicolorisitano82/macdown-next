//
//  MPBacklinksViewController.m
//  MacDown
//

#import "MPBacklinksViewController.h"
#import "MPBacklinks.h"

static const CGFloat kMPRowHeight = 42.0;
static const CGFloat kMPWidth = 420.0;
static const CGFloat kMPMaximumHeight = 460.0;


@interface MPBacklinksViewController ()
    <NSTableViewDataSource, NSTableViewDelegate>
@property (copy, nonatomic) NSArray<MPBacklink *> *backlinks;
@property (nonatomic) NSUInteger counted;
@property (copy, nonatomic) void (^chosen)(MPBacklink *link);
@property (strong, nonatomic) NSTableView *table;
@end


@implementation MPBacklinksViewController

- (instancetype)initWithBacklinks:(NSArray<MPBacklink *> *)backlinks
                          counted:(NSUInteger)documentsRead
                           chosen:(void (^)(MPBacklink *))chosen
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;
    _backlinks = [backlinks copy];
    _counted = documentsRead;
    _chosen = [chosen copy];
    return self;
}

- (void)loadView
{
    NSTableView *table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *column =
        [[NSTableColumn alloc] initWithIdentifier:@"link"];
    column.width = kMPWidth - 24.0;
    [table addTableColumn:column];
    table.headerView = nil;
    table.rowHeight = kMPRowHeight;
    table.dataSource = self;
    table.delegate = self;
    table.style = NSTableViewStyleInset;
    table.backgroundColor = [NSColor clearColor];
    table.target = self;
    // One click: going there is the only thing a row is for.
    table.action = @selector(rowClicked:);
    self.table = table;

    CGFloat listHeight = MIN(kMPMaximumHeight,
        MAX(kMPRowHeight, kMPRowHeight * self.backlinks.count + 16.0));
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPWidth, listHeight)];
    scroll.documentView = table;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.autohidesScrollers = YES;

    // How many documents were read to answer, because "nothing points here"
    // and "there was nothing to look at" are different answers.
    NSString *summary = self.backlinks.count
        ? [NSString stringWithFormat:NSLocalizedString(
              @"%lu links, in %lu documents read",
              @"Backlinks popover header"),
           (unsigned long)self.backlinks.count, (unsigned long)self.counted]
        : [NSString stringWithFormat:NSLocalizedString(
              @"No document points here, out of %lu read",
              @"Backlinks popover header when there are none"),
           (unsigned long)self.counted];

    NSTextField *header = [NSTextField wrappingLabelWithString:summary];
    header.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    header.textColor = [NSColor secondaryLabelColor];
    header.frame = NSMakeRect(12.0, 0.0, kMPWidth - 24.0, 0.0);
    [header sizeToFit];
    CGFloat headerHeight = NSHeight(header.frame) + 16.0;

    NSView *content = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPWidth, listHeight + headerHeight)];
    header.frame = NSMakeRect(12.0, listHeight + 8.0, kMPWidth - 24.0,
                              NSHeight(header.frame));
    [content addSubview:header];
    [content addSubview:scroll];
    self.view = content;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)self.backlinks.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    MPBacklink *link = self.backlinks[(NSUInteger)row];

    NSView *cell = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, column.width, kMPRowHeight)];

    NSString *where = [NSString stringWithFormat:NSLocalizedString(
        @"%@ · line %lu", @"Which document links here, and from which line"),
        link.title.length ? link.title
                          : link.documentURL.lastPathComponent,
        (unsigned long)link.line];
    NSTextField *name = [NSTextField labelWithString:where];
    name.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    name.frame = NSMakeRect(4.0, 21.0, column.width - 8.0, 18.0);
    name.toolTip = link.documentURL.path;
    [cell addSubview:name];

    // The line as written: it is what tells two citations apart.
    NSTextField *context = [NSTextField labelWithString:link.context];
    context.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    context.textColor = [NSColor secondaryLabelColor];
    context.lineBreakMode = NSLineBreakByTruncatingTail;
    context.frame = NSMakeRect(4.0, 3.0, column.width - 8.0, 16.0);
    [cell addSubview:context];

    return cell;
}

- (void)rowClicked:(id)sender
{
    NSInteger row = self.table.clickedRow;
    if (row < 0 || row >= (NSInteger)self.backlinks.count)
        return;
    if (self.chosen)
        self.chosen(self.backlinks[(NSUInteger)row]);
}

@end
