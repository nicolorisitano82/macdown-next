//
//  MPInstructionsViewController.m
//  MacDown
//

#import "MPInstructionsViewController.h"

#import "MPInstructionFiles.h"


static const CGFloat kMPPanelWidth = 560.0;
static const CGFloat kMPRowHeight = 26.0;


/// One line of the panel: what to show, what it stands for, how far in.
@interface MPInstructionRow : NSObject
@property (copy, nonatomic) NSString *text;
@property (copy, nonatomic) NSString *detail;
@property (copy, nonatomic) NSURL *fileURL;
@property (nonatomic) NSUInteger indent;
@property (nonatomic) BOOL header;
@property (nonatomic) BOOL missing;
@property (nonatomic) BOOL trouble;
@end

@implementation MPInstructionRow
@end


@interface MPInstructionsViewController ()
    <NSTableViewDataSource, NSTableViewDelegate>
@property (strong, nonatomic) NSArray<MPInstructionRow *> *rows;
@property (copy, nonatomic) void (^chosen)(NSURL *fileURL);
@property (strong, nonatomic) NSTableView *table;
@end


@implementation MPInstructionsViewController

- (instancetype)initWithHierarchy:(NSArray<MPInstructionFile *> *)hierarchy
                             tree:(MPInstructionNode *)tree
                           issues:(NSArray<MPInstructionIssue *> *)issues
                           chosen:(void (^)(NSURL *))chosen
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;

    _chosen = [chosen copy];
    NSMutableArray<MPInstructionRow *> *rows = [NSMutableArray array];

    [rows addObject:[self headerRow:NSLocalizedString(
        @"Read in this order", @"Instruction panel section")]];
    for (MPInstructionFile *file in hierarchy)
    {
        MPInstructionRow *row = [[MPInstructionRow alloc] init];
        row.text = file.fileURL.lastPathComponent;
        row.fileURL = file.fileURL;
        row.missing = !file.exists;
        row.detail = file.exists
            ? [NSString stringWithFormat:NSLocalizedString(
                @"%@ · %lu lines", @"An instruction file and how long it is"),
               file.scopeName, (unsigned long)file.lines]
            : [NSString stringWithFormat:NSLocalizedString(
                @"%@ · not there", @"An instruction file that is not there"),
               file.scopeName];
        [rows addObject:row];
    }

    if (tree.imports.count)
    {
        [rows addObject:[self headerRow:NSLocalizedString(
            @"And what they pull in",
            @"Instruction panel section")]];
        [self appendImportsOf:tree to:rows];
    }

    if (issues.count)
    {
        [rows addObject:[self headerRow:NSLocalizedString(
            @"Worth a look", @"Instruction panel section")]];
        for (MPInstructionIssue *issue in issues)
        {
            MPInstructionRow *row = [[MPInstructionRow alloc] init];
            row.text = issue.message;
            row.detail = issue.fileURL.lastPathComponent;
            row.fileURL = issue.fileURL;
            row.trouble = YES;
            [rows addObject:row];
        }
    }
    _rows = rows;

    return self;
}

- (MPInstructionRow *)headerRow:(NSString *)title
{
    MPInstructionRow *row = [[MPInstructionRow alloc] init];
    row.text = title;
    row.header = YES;
    return row;
}

- (void)appendImportsOf:(MPInstructionNode *)node
                     to:(NSMutableArray<MPInstructionRow *> *)rows
{
    for (MPInstructionNode *child in node.imports)
    {
        MPInstructionRow *row = [[MPInstructionRow alloc] init];
        row.text = [@"@" stringByAppendingString:child.writtenAs ?: @""];
        row.fileURL = child.fileURL;
        row.indent = child.depth;
        row.missing = !child.exists;
        if (!child.exists)
            row.detail = NSLocalizedString(@"not there", @"Missing import");
        else if (child.circular)
            row.detail = NSLocalizedString(@"a circle", @"Circular import");
        else if (child.tooDeep)
            row.detail = NSLocalizedString(@"past the fourth hop",
                                           @"Import past the depth limit");
        else
            row.detail = child.fileURL.lastPathComponent;
        [rows addObject:row];
        [self appendImportsOf:child to:rows];
    }
}


#pragma mark - The panel

- (void)loadView
{
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(
        0.0, 0.0, kMPPanelWidth,
        MIN(420.0, MAX(90.0, kMPRowHeight * (CGFloat)self.rows.count + 16.0)))];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;

    NSTableView *table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *column = [[NSTableColumn alloc]
        initWithIdentifier:@"instruction"];
    column.width = kMPPanelWidth - 24.0;
    [table addTableColumn:column];
    table.headerView = nil;
    table.rowHeight = kMPRowHeight;
    table.style = NSTableViewStyleInset;
    table.dataSource = self;
    table.delegate = self;
    table.target = self;
    table.action = @selector(rowClicked:);
    table.backgroundColor = [NSColor clearColor];

    scroll.documentView = table;
    self.table = table;
    self.view = scroll;
}


#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)self.rows.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)column row:(NSInteger)index
{
    MPInstructionRow *row = self.rows[(NSUInteger)index];
    NSView *cell = [[NSView alloc] initWithFrame:NSMakeRect(
        0.0, 0.0, column.width, kMPRowHeight)];

    CGFloat left = 4.0 + 14.0 * (CGFloat)row.indent;
    NSTextField *what = [NSTextField labelWithString:row.text ?: @""];
    what.frame = NSMakeRect(left, 4.0, column.width - left - 150.0, 18.0);
    what.lineBreakMode = NSLineBreakByTruncatingTail;
    if (row.header)
    {
        what.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]
                                      weight:NSFontWeightSemibold];
        what.textColor = [NSColor secondaryLabelColor];
    }
    else if (row.trouble)
        what.textColor = [NSColor systemOrangeColor];
    else if (row.missing)
        what.textColor = [NSColor tertiaryLabelColor];
    [cell addSubview:what];

    if (row.detail.length)
    {
        NSTextField *detail = [NSTextField labelWithString:row.detail];
        detail.alignment = NSTextAlignmentRight;
        detail.textColor = [NSColor secondaryLabelColor];
        detail.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        detail.frame = NSMakeRect(column.width - 146.0, 5.0, 144.0, 16.0);
        detail.lineBreakMode = NSLineBreakByTruncatingHead;
        [cell addSubview:detail];
    }
    return cell;
}

- (void)rowClicked:(id)sender
{
    NSInteger index = self.table.clickedRow;
    if (index < 0 || index >= (NSInteger)self.rows.count)
        return;
    MPInstructionRow *row = self.rows[(NSUInteger)index];
    if (row.header || !row.fileURL)
        return;
    if (self.chosen)
        self.chosen(row.fileURL);
}

@end
