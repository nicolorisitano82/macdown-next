//
//  MPCompareWindowController.m
//  MacDown
//

#import "MPCompareWindowController.h"

#import "MPDiff.h"


static const CGFloat kMPComparePadding = 16.0;
/// How many unchanged lines stay around a difference when the unchanged
/// ones are folded away: enough to know where you are.
static const NSUInteger kMPCompareContext = 3;
/// The gutter, in characters: five digits of line number and a space.
static const NSUInteger kMPCompareGutter = 6;


/// The comparisons on screen, so that a window nobody holds does not go
/// away while somebody is reading it.
static NSMutableSet<MPCompareWindowController *> *MPOpenComparisons(void)
{
    static NSMutableSet *open = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        open = [NSMutableSet set];
    });
    return open;
}


@interface MPCompareWindowController () <NSWindowDelegate>

@property (copy, nonatomic) NSString *leftText;
@property (copy, nonatomic) NSString *rightText;
@property (copy, nonatomic) NSString *leftName;
@property (copy, nonatomic) NSString *rightName;
@property (strong, nonatomic) NSURL *leftURL;
@property (strong, nonatomic) NSURL *rightURL;

@property (strong, nonatomic) NSTextField *summary;
@property (strong, nonatomic) NSTextField *leftTitle;
@property (strong, nonatomic) NSTextField *rightTitle;
@property (strong, nonatomic) NSTextView *leftView;
@property (strong, nonatomic) NSTextView *rightView;
@property (strong, nonatomic) NSScrollView *leftScroll;
@property (strong, nonatomic) NSScrollView *rightScroll;
@property (strong, nonatomic) NSButton *foldButton;

/// The rows as they are shown, and which of them are differences: the two
/// buttons walk this list, and both sides are on the same row number.
@property (copy, nonatomic) NSArray<MPDiffRow *> *shown;
@property (copy, nonatomic) NSArray<NSNumber *> *differences;
@property (nonatomic) NSInteger at;
/// One side is scrolling the other, and should not be scrolled back.
@property (nonatomic) BOOL following;

@end


@implementation MPCompareWindowController

+ (instancetype)compare:(NSString *)leftText
                  named:(NSString *)leftName
                    url:(NSURL *)leftURL
                   with:(NSString *)rightText
                  named:(NSString *)rightName
                    url:(NSURL *)rightURL
{
    MPCompareWindowController *controller =
        [[MPCompareWindowController alloc] init];
    controller.leftText = leftText ?: @"";
    controller.rightText = rightText ?: @"";
    controller.leftName = leftName ?: @"";
    controller.rightName = rightName ?: @"";
    controller.leftURL = leftURL;
    controller.rightURL = rightURL;
    [controller showTheComparison];
    [MPOpenComparisons() addObject:controller];
    [controller showWindow:nil];
    return controller;
}


- (instancetype)init
{
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0.0, 0.0, 980.0, 620.0)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                            | NSWindowStyleMaskMiniaturizable
                            | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered defer:NO];
    window.title = NSLocalizedString(@"Comparison",
                                     @"Title of the window comparing two "
                                     @"documents");
    window.minSize = NSMakeSize(640.0, 320.0);
    [window center];

    self = [super initWithWindow:window];
    if (!self)
        return nil;

    window.delegate = self;
    [self buildContent];
    return self;
}


- (void)windowWillClose:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [MPOpenComparisons() removeObject:self];
}


#pragma mark - The window

- (void)buildContent
{
    NSView *content = self.window.contentView;

    self.summary = [NSTextField labelWithString:@""];
    self.summary.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];

    NSButton *previous = [NSButton buttonWithTitle:NSLocalizedString(
        @"Previous", @"Go to the previous difference")
        target:self action:@selector(goToPrevious:)];
    NSButton *next = [NSButton buttonWithTitle:NSLocalizedString(
        @"Next", @"Go to the next difference")
        target:self action:@selector(goToNext:)];
    next.keyEquivalent = @"\r";

    self.foldButton = [NSButton checkboxWithTitle:NSLocalizedString(
        @"Differences only", @"Hide the lines that are the same")
        target:self action:@selector(toggleFolding:)];

    NSButton *swap = [NSButton buttonWithTitle:NSLocalizedString(
        @"Swap Sides", @"Put the right document on the left")
        target:self action:@selector(swapSides:)];
    NSButton *again = [NSButton buttonWithTitle:NSLocalizedString(
        @"Read the Files Again", @"Compare the files as they are now")
        target:self action:@selector(readAgain:)];

    NSStackView *buttons = [NSStackView stackViewWithViews:
        @[self.summary, previous, next, self.foldButton, swap, again]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 8.0;
    [buttons setCustomSpacing:16.0 afterView:self.summary];
    [buttons setHuggingPriority:NSLayoutPriorityDefaultLow
                 forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.leftTitle = [self titleLabel];
    self.rightTitle = [self titleLabel];

    self.leftScroll = [self textPane:&_leftView];
    self.rightScroll = [self textPane:&_rightView];

    NSStackView *leftColumn = [NSStackView stackViewWithViews:
        @[self.leftTitle, self.leftScroll]];
    leftColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    leftColumn.alignment = NSLayoutAttributeLeading;
    leftColumn.spacing = 6.0;
    NSStackView *rightColumn = [NSStackView stackViewWithViews:
        @[self.rightTitle, self.rightScroll]];
    rightColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    rightColumn.alignment = NSLayoutAttributeLeading;
    rightColumn.spacing = 6.0;

    NSStackView *sides = [NSStackView stackViewWithViews:
        @[leftColumn, rightColumn]];
    sides.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    sides.distribution = NSStackViewDistributionFillEqually;
    sides.spacing = 10.0;

    NSStackView *column = [NSStackView stackViewWithViews:@[buttons, sides]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 12.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:content.leadingAnchor
            constant:kMPComparePadding],
        [column.trailingAnchor constraintEqualToAnchor:content.trailingAnchor
            constant:-kMPComparePadding],
        [column.topAnchor constraintEqualToAnchor:content.topAnchor
            constant:kMPComparePadding],
        [column.bottomAnchor constraintEqualToAnchor:content.bottomAnchor
            constant:-kMPComparePadding],
        [sides.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [sides.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
        [buttons.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [buttons.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
        [self.leftScroll.widthAnchor
            constraintEqualToAnchor:leftColumn.widthAnchor],
        [self.rightScroll.widthAnchor
            constraintEqualToAnchor:rightColumn.widthAnchor],
    ]];
}


- (NSTextField *)titleLabel
{
    NSTextField *label = [NSTextField labelWithString:@""];
    label.font = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    label.selectable = YES;
    return label;
}


/// One side: a text view that does not wrap, because a comparison read
/// line by line has to keep the two sides on the same rows.
- (NSScrollView *)textPane:(NSTextView * __strong *)view
{
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextView *text = [[NSTextView alloc] initWithFrame:NSZeroRect];
    text.editable = NO;
    text.richText = YES;
    text.drawsBackground = YES;
    text.backgroundColor = [NSColor textBackgroundColor];
    text.textContainerInset = NSMakeSize(4.0, 6.0);
    text.horizontallyResizable = YES;
    text.verticallyResizable = YES;
    text.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    text.textContainer.widthTracksTextView = NO;
    text.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    scroll.documentView = text;
    *view = text;

    // The two sides scroll together: reading one column and having to drag
    // the other to keep up is worse than no comparison at all.
    scroll.contentView.postsBoundsChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(oneSideScrolled:)
            name:NSViewBoundsDidChangeNotification
          object:scroll.contentView];
    return scroll;
}


- (void)oneSideScrolled:(NSNotification *)note
{
    if (self.following)
        return;
    NSClipView *moved = note.object;
    NSClipView *other = (moved == self.leftScroll.contentView)
        ? self.rightScroll.contentView : self.leftScroll.contentView;
    if (!other || moved == other)
        return;

    self.following = YES;
    NSPoint where = moved.bounds.origin;
    NSPoint mine = other.bounds.origin;
    // Only the vertical is shared: the two sides have lines of different
    // lengths, and dragging one sideways should not drag the other.
    [other scrollToPoint:NSMakePoint(mine.x, where.y)];
    [(NSScrollView *)other.superview reflectScrolledClipView:other];
    self.following = NO;
}


#pragma mark - Showing it

- (void)showTheComparison
{
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(self.leftText,
                                                   self.rightText);
    NSUInteger added = 0, removed = 0, changed = 0;
    MPDiffCounts(rows, &added, &removed, &changed);

    BOOL folding = (self.foldButton.state == NSControlStateValueOn);
    self.shown = folding ? [self fold:rows] : rows;

    NSMutableArray<NSNumber *> *differences = [NSMutableArray array];
    [self.shown enumerateObjectsUsingBlock:^(MPDiffRow *row, NSUInteger i,
                                             BOOL *stop) {
        if (row.kind != MPDiffEqual)
            [differences addObject:@(i)];
    }];
    self.differences = differences;
    self.at = -1;

    self.leftTitle.stringValue = self.leftName;
    self.rightTitle.stringValue = self.rightName;

    if (!added && !removed && !changed)
    {
        self.summary.stringValue = NSLocalizedString(
            @"The two are the same.",
            @"Shown when two compared documents do not differ");
    }
    else
    {
        self.summary.stringValue = [NSString stringWithFormat:
            NSLocalizedString(@"%lu changed, %lu added, %lu taken away",
                              @"How many lines differ, in the comparison "
                              @"window"),
            (unsigned long)changed, (unsigned long)added,
            (unsigned long)removed];
    }

    [self.leftView.textStorage setAttributedString:[self sideOf:YES]];
    [self.rightView.textStorage setAttributedString:[self sideOf:NO]];
}


/// The unchanged lines away, except the few around each difference.
- (NSArray<MPDiffRow *> *)fold:(NSArray<MPDiffRow *> *)rows
{
    NSMutableIndexSet *keep = [NSMutableIndexSet indexSet];
    [rows enumerateObjectsUsingBlock:^(MPDiffRow *row, NSUInteger i,
                                       BOOL *stop) {
        if (row.kind == MPDiffEqual)
            return;
        NSUInteger from = (i > kMPCompareContext) ? i - kMPCompareContext : 0;
        NSUInteger to = MIN(i + kMPCompareContext, rows.count - 1);
        [keep addIndexesInRange:NSMakeRange(from, to - from + 1)];
    }];
    return [rows objectsAtIndexes:keep];
}


- (NSAttributedString *)sideOf:(BOOL)left
{
    NSFont *font = [NSFont monospacedSystemFontOfSize:12.0
                                               weight:NSFontWeightRegular];
    NSMutableAttributedString *whole =
        [[NSMutableAttributedString alloc] init];

    for (MPDiffRow *row in self.shown)
    {
        NSString *text = left ? row.left : row.right;
        NSUInteger number = left ? row.leftLine : row.rightLine;

        // A row with nothing on this side still takes a line, so that the
        // two columns stay level with each other all the way down.
        NSString *gutter = number
            ? [[NSString stringWithFormat:@"%lu", (unsigned long)number]
                stringByPaddingToLength:kMPCompareGutter - 1
                             withString:@" " startingAtIndex:0]
            : [@"" stringByPaddingToLength:kMPCompareGutter - 1
                                withString:@" " startingAtIndex:0];
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", gutter,
                          text ?: @""];

        NSMutableAttributedString *piece =
            [[NSMutableAttributedString alloc] initWithString:line];
        NSRange all = NSMakeRange(0, piece.length);
        [piece addAttribute:NSFontAttributeName value:font range:all];
        [piece addAttribute:NSForegroundColorAttributeName
                      value:[NSColor labelColor] range:all];
        [piece addAttribute:NSForegroundColorAttributeName
                      value:[NSColor tertiaryLabelColor]
                      range:NSMakeRange(0, kMPCompareGutter)];

        NSColor *background = [self colourFor:row.kind
                                     thisSide:left
                                      hasText:(text != nil)];
        if (background)
            [piece addAttribute:NSBackgroundColorAttributeName
                          value:background range:all];

        // Inside a changed row, the words that actually differ.
        if (row.kind == MPDiffChanged && text.length)
        {
            NSArray<NSValue *> *leftRanges = nil;
            NSArray<NSValue *> *rightRanges = nil;
            MPDiffWordRanges(row.left, row.right, &leftRanges, &rightRanges);
            NSColor *strong = [self wordColourFor:left];
            for (NSValue *value in (left ? leftRanges : rightRanges))
            {
                NSRange range = value.rangeValue;
                range.location += kMPCompareGutter;
                if (NSMaxRange(range) <= piece.length)
                    [piece addAttribute:NSBackgroundColorAttributeName
                                  value:strong range:range];
            }
        }

        [whole appendAttributedString:piece];
    }
    return whole;
}


/// The colours: green for what arrived, red for what went, yellow for what
/// changed, and a flat grey for the empty half of a row that only one side
/// has — an empty white line there reads as a line that says nothing, and
/// it says «there is nothing here».
- (NSColor *)colourFor:(MPDiffKind)kind thisSide:(BOOL)left
               hasText:(BOOL)hasText
{
    switch (kind)
    {
        case MPDiffEqual:
            return nil;
        case MPDiffChanged:
            return [[NSColor systemYellowColor] colorWithAlphaComponent:0.16];
        case MPDiffAdded:
            return hasText
                ? [[NSColor systemGreenColor] colorWithAlphaComponent:0.18]
                : [[NSColor systemGrayColor] colorWithAlphaComponent:0.10];
        case MPDiffRemoved:
            return hasText
                ? [[NSColor systemRedColor] colorWithAlphaComponent:0.16]
                : [[NSColor systemGrayColor] colorWithAlphaComponent:0.10];
    }
}


- (NSColor *)wordColourFor:(BOOL)left
{
    return left ? [[NSColor systemRedColor] colorWithAlphaComponent:0.30]
                : [[NSColor systemGreenColor] colorWithAlphaComponent:0.30];
}


#pragma mark - Walking the differences

- (void)goToNext:(id)sender
{
    if (!self.differences.count)
        return;
    self.at = (self.at + 1) % (NSInteger)self.differences.count;
    [self showDifference];
}

- (void)goToPrevious:(id)sender
{
    if (!self.differences.count)
        return;
    self.at = (self.at <= 0) ? (NSInteger)self.differences.count - 1
                             : self.at - 1;
    [self showDifference];
}

- (void)showDifference
{
    NSUInteger row = self.differences[(NSUInteger)self.at].unsignedIntegerValue;
    [self show:row in:self.leftView];
    [self show:row in:self.rightView];
}

/// The row is the same number on both sides, which is the whole point of
/// building the two texts row by row.
- (void)show:(NSUInteger)row in:(NSTextView *)view
{
    NSString *text = view.string;
    NSUInteger at = 0;
    NSUInteger start = 0;
    NSUInteger end = text.length;
    for (NSUInteger line = 0; line <= row && start < text.length; line++)
    {
        NSRange found = [text rangeOfString:@"\n"
                                    options:0
                                      range:NSMakeRange(at, text.length - at)];
        start = at;
        end = (found.location == NSNotFound) ? text.length : found.location;
        at = (found.location == NSNotFound) ? text.length
                                            : NSMaxRange(found);
    }
    NSRange range = NSMakeRange(start, end - start);
    [view setSelectedRange:range];
    [view scrollRangeToVisible:range];
}


#pragma mark - The buttons

- (void)toggleFolding:(id)sender
{
    [self showTheComparison];
}

- (void)swapSides:(id)sender
{
    NSString *text = self.leftText;
    NSString *name = self.leftName;
    NSURL *url = self.leftURL;
    self.leftText = self.rightText;
    self.leftName = self.rightName;
    self.leftURL = self.rightURL;
    self.rightText = text;
    self.rightName = name;
    self.rightURL = url;
    [self showTheComparison];
}

/// Both sides read off the disk again. A side with no file — an unsaved
/// document — keeps what it had, because there is nowhere to read it from.
- (void)readAgain:(id)sender
{
    if (self.leftURL)
    {
        NSString *text = [NSString stringWithContentsOfURL:self.leftURL
            encoding:NSUTF8StringEncoding error:NULL];
        if (text)
            self.leftText = text;
    }
    if (self.rightURL)
    {
        NSString *text = [NSString stringWithContentsOfURL:self.rightURL
            encoding:NSUTF8StringEncoding error:NULL];
        if (text)
            self.rightText = text;
    }
    [self showTheComparison];
}

@end
