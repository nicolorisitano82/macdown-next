//
//  MPProseIssuesViewController.m
//  MacDown
//

#import "MPProseIssuesViewController.h"
#import "MPProseChecker.h"
#import "MPUtilities.h"

static const CGFloat kMPRowHeight = 26.0;
static const CGFloat kMPPopoverWidth = 340.0;
static const CGFloat kMPPopoverMaximumHeight = 420.0;


@interface MPProseIssuesViewController ()
    <NSTableViewDataSource, NSTableViewDelegate>
@property (copy, nonatomic) NSArray<MPProseIssue *> *issues;
@property (copy, nonatomic) NSArray<NSNumber *> *lines;
@property (copy, nonatomic) void (^chosen)(MPProseIssue *issue);
@property (copy, nonatomic) NSString *summary;
@property (strong, nonatomic) NSTableView *table;
@property (copy, nonatomic) void (^fixed)(MPProseIssue *issue);
@end


@implementation MPProseIssuesViewController

- (instancetype)initWithIssues:(NSArray<MPProseIssue *> *)issues
                        inText:(NSString *)text
                       summary:(NSString *)summary
                        chosen:(void (^)(MPProseIssue *))chosen
                         fixed:(void (^)(MPProseIssue *))fixed
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;

    _issues = [issues copy];
    _chosen = [chosen copy];
    _fixed = [fixed copy];
    _summary = [summary copy];

    // Worked out once, here: asking for a line number per row while the
    // table scrolls would walk the document for every row it drew.
    NSMutableArray *lines = [NSMutableArray array];
    for (MPProseIssue *issue in issues)
    {
        [lines addObject:@(MPLineNumberForLocation(text,
                                                   issue.range.location))];
    }
    _lines = lines;

    return self;
}

- (void)loadView
{
    NSTableView *table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *column =
        [[NSTableColumn alloc] initWithIdentifier:@"issue"];
    column.width = kMPPopoverWidth - 24.0;
    [table addTableColumn:column];
    table.headerView = nil;
    table.rowHeight = kMPRowHeight;
    table.dataSource = self;
    table.delegate = self;
    table.style = NSTableViewStyleInset;
    table.backgroundColor = [NSColor clearColor];
    table.target = self;
    // One click, not two: this is a list of places to go, and going there
    // is the only thing one can do with a row.
    table.action = @selector(rowClicked:);
    self.table = table;

    CGFloat listHeight = MIN(kMPPopoverMaximumHeight,
        MAX(kMPRowHeight * 2.0, kMPRowHeight * self.issues.count + 16.0));

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(
        0.0, 0.0, kMPPopoverWidth, listHeight)];
    scroll.documentView = table;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.autohidesScrollers = YES;

    if (!self.summary.length)
    {
        self.view = scroll;
        return;
    }

    // The tally in full at the top, because the button that opens this cuts
    // it off when there is more of it than there is room for.
    NSTextField *header = [NSTextField wrappingLabelWithString:self.summary];
    header.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    header.textColor = [NSColor secondaryLabelColor];
    header.frame = NSMakeRect(12.0, 0.0, kMPPopoverWidth - 24.0, 0.0);
    [header sizeToFit];
    CGFloat headerHeight = NSHeight(header.frame) + 16.0;

    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(
        0.0, 0.0, kMPPopoverWidth, listHeight + headerHeight)];
    header.frame = NSMakeRect(12.0, listHeight + 8.0,
                              kMPPopoverWidth - 24.0,
                              NSHeight(header.frame));
    scroll.frame = NSMakeRect(0.0, 0.0, kMPPopoverWidth, listHeight);
    [content addSubview:header];
    [content addSubview:scroll];

    self.view = content;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)self.issues.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    MPProseIssue *issue = self.issues[(NSUInteger)row];

    NSView *cell = [[NSView alloc] initWithFrame:NSMakeRect(
        0.0, 0.0, column.width, kMPRowHeight)];

    // The colour is the one the underline uses, so a row and a squiggle in
    // the text can be matched by eye.
    NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(2.0, 9.0, 8.0, 8.0)];
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 4.0;
    dot.layer.backgroundColor =
        (issue.color ?: [NSColor secondaryLabelColor]).CGColor;
    [cell addSubview:dot];

    NSTextField *what = [NSTextField labelWithString:issue.text ?: @""];
    what.frame = NSMakeRect(18.0, 4.0, column.width - 100.0, 18.0);
    what.lineBreakMode = NSLineBreakByTruncatingTail;
    [cell addSubview:what];

    CGFloat right = column.width - 2.0;
    if (issue.replacement.length && self.fixed)
    {
        // Only where there is one obvious answer; see the header.
        NSButton *fix = [NSButton buttonWithTitle:NSLocalizedString(@"Fix",
            @"Apply the correction to a prose issue")
            target:self action:@selector(fixClicked:)];
        fix.controlSize = NSControlSizeSmall;
        fix.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        fix.bezelStyle = NSBezelStyleRounded;
        fix.tag = row;
        [fix sizeToFit];
        NSRect frame = fix.frame;
        frame.origin = NSMakePoint(right - NSWidth(frame), 2.0);
        fix.frame = frame;
        [cell addSubview:fix];
        right -= NSWidth(frame) + 6.0;
    }

    NSString *where = [NSString stringWithFormat:@"riga %@ · %@",
        self.lines[(NSUInteger)row], issue.categoryName ?: @""];
    NSTextField *place = [NSTextField labelWithString:where];
    place.alignment = NSTextAlignmentRight;
    place.textColor = [NSColor secondaryLabelColor];
    place.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    place.frame = NSMakeRect(right - 166.0, 5.0, 166.0, 16.0);
    place.lineBreakMode = NSLineBreakByTruncatingHead;
    [cell addSubview:place];

    return cell;
}

/// The button on a row: the correction, applied where it was found.
- (void)fixClicked:(NSButton *)sender
{
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.issues.count)
        return;
    if (self.fixed)
        self.fixed(self.issues[(NSUInteger)row]);
}

- (void)rowClicked:(id)sender
{
    NSInteger row = self.table.clickedRow;
    if (row < 0 || row >= (NSInteger)self.issues.count)
        return;
    if (self.chosen)
        self.chosen(self.issues[(NSUInteger)row]);
}

@end
