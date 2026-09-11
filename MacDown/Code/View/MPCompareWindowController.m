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


/** The two sides, as text views that do not answer ⌘G themselves.
 *
 * Find Next in the menu bar sends `performFindPanelAction:` down the
 * responder chain, and an NSTextView answers it — with the two panes as
 * first responder that means «find the next match in this column», which is
 * not what ⌘G means in a window whose whole subject is differences. Passed
 * on, it reaches the window controller, which walks them.
 */
@interface MPCompareTextView : NSTextView
@end

@implementation MPCompareTextView

- (void)performFindPanelAction:(id)sender
{
    [[self nextResponder] tryToPerform:@selector(performFindPanelAction:)
                                  with:sender];
}

@end


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
@property (strong, nonatomic) NSSegmentedControl *grainControl;
@property (strong, nonatomic) NSButton *spaceButton;
@property (strong, nonatomic) NSButton *caseButton;

/// The rows as they are shown, and which of them are differences: the two
/// buttons walk this list, and both sides are on the same row number.
@property (copy, nonatomic) NSArray<MPDiffRow *> *shown;
/// Where each row is in each side's text, so that scrolling one side can
/// put the *same row* at the top of the other — which is the only way the
/// two stay together once a row can be a whole paragraph and wrap.
@property (copy, nonatomic) NSArray<NSValue *> *leftRowRanges;
@property (copy, nonatomic) NSArray<NSValue *> *rightRowRanges;
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


/// What the window is called: the two names and how many differences, so
/// that the Window menu is readable with three comparisons open.
+ (NSString *)titleForLeft:(NSString *)left right:(NSString *)right
               differences:(NSUInteger)differences
{
    NSString *names = [NSString stringWithFormat:@"%@ ↔ %@",
                       left.length ? left : @"?",
                       right.length ? right : @"?"];
    if (!differences)
    {
        return [NSString stringWithFormat:@"%@ — %@", names,
            NSLocalizedString(@"no differences",
                              @"Comparison window title, when the two are "
                              @"the same")];
    }
    if (differences == 1)
    {
        return [NSString stringWithFormat:@"%@ — %@", names,
            NSLocalizedString(@"one difference",
                              @"Comparison window title")];
    }
    return [NSString stringWithFormat:NSLocalizedString(
        @"%@ — %lu differences", @"Comparison window title"),
        names, (unsigned long)differences];
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
    next.keyEquivalent = @"g";
    next.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    previous.keyEquivalent = @"G";
    previous.keyEquivalentModifierMask = NSEventModifierFlagCommand
        | NSEventModifierFlagShift;

    self.foldButton = [NSButton checkboxWithTitle:NSLocalizedString(
        @"Differences only", @"Hide the lines that are the same")
        target:self action:@selector(toggleFolding:)];

    // What counts as one thing to compare. Lines to start with, because
    // that is what a comparison has always meant; paragraphs because a
    // document that has been re-wrapped otherwise reads as changed from top
    // to bottom.
    self.grainControl = [NSSegmentedControl
        segmentedControlWithLabels:@[NSLocalizedString(@"by line",
                                        @"Comparison grain"),
                                     NSLocalizedString(@"by paragraph",
                                        @"Comparison grain")]
                      trackingMode:NSSegmentSwitchTrackingSelectOne
                            target:self action:@selector(changeGrain:)];
    [self.grainControl setSelectedSegment:0];

    self.spaceButton = [NSButton checkboxWithTitle:NSLocalizedString(
        @"ignore spaces", @"Comparison option")
        target:self action:@selector(changeGrain:)];
    self.caseButton = [NSButton checkboxWithTitle:NSLocalizedString(
        @"ignore case", @"Comparison option")
        target:self action:@selector(changeGrain:)];

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

    NSTextField *compareTitle = [NSTextField labelWithString:
        NSLocalizedString(@"Compare:", @"Label of the comparison options")];
    compareTitle.textColor = [NSColor secondaryLabelColor];
    NSStackView *options = [NSStackView stackViewWithViews:
        @[compareTitle, self.grainControl, self.spaceButton, self.caseButton]];
    options.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    options.spacing = 10.0;
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

    NSStackView *column = [NSStackView stackViewWithViews:
        @[buttons, options, sides]];
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
        [options.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
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
    BOOL fromTheLeft = (moved == self.leftScroll.contentView);
    NSTextView *mover = fromTheLeft ? self.leftView : self.rightView;
    NSScrollView *otherScroll = fromTheLeft ? self.rightScroll
                                            : self.leftScroll;
    NSTextView *other = fromTheLeft ? self.rightView : self.leftView;
    if (!other || !self.shown.count)
        return;

    // Which row is at the top of the side that moved, and the same row put
    // at the top of the other. By row and not by pixel: a row can be a whole
    // paragraph, which wraps to a different height on each side.
    NSUInteger row = [self rowAtTopOf:mover
                               ranges:fromTheLeft ? self.leftRowRanges
                                                  : self.rightRowRanges
                               scroll:fromTheLeft ? self.leftScroll
                                                  : self.rightScroll];
    NSArray<NSValue *> *ranges = fromTheLeft ? self.rightRowRanges
                                             : self.leftRowRanges;
    if (row >= ranges.count)
        return;

    NSRect rect = [self rectOfRange:ranges[row].rangeValue in:other];
    self.following = YES;
    NSPoint where = otherScroll.contentView.bounds.origin;
    [otherScroll.contentView scrollToPoint:
        NSMakePoint(where.x, MAX(0.0, NSMinY(rect) - 4.0))];
    [otherScroll reflectScrolledClipView:otherScroll.contentView];
    self.following = NO;
}


/// The first row whose text reaches the top of what is visible.
- (NSUInteger)rowAtTopOf:(NSTextView *)view
                  ranges:(NSArray<NSValue *> *)ranges
                  scroll:(NSScrollView *)scroll
{
    CGFloat top = NSMinY(scroll.contentView.bounds);
    NSUInteger low = 0;
    NSUInteger high = ranges.count;
    while (low + 1 < high)
    {
        NSUInteger middle = (low + high) / 2;
        NSRect rect = [self rectOfRange:ranges[middle].rangeValue in:view];
        if (NSMinY(rect) <= top)
            low = middle;
        else
            high = middle;
    }
    return low;
}


- (NSRect)rectOfRange:(NSRange)range in:(NSTextView *)view
{
    NSLayoutManager *layout = view.layoutManager;
    NSRange glyphs = [layout glyphRangeForCharacterRange:range
                                   actualCharacterRange:NULL];
    NSRect rect = [layout boundingRectForGlyphRange:glyphs
                                    inTextContainer:view.textContainer];
    rect.origin.y += view.textContainerInset.height;
    return rect;
}


#pragma mark - Showing it

/// What the three controls say, as the comparison understands it.
- (MPDiffOptions)options
{
    MPDiffOptions options = MPDiffOptionsStrict;
    options.grain = (self.grainControl.selectedSegment == 1)
        ? MPDiffByParagraphs : MPDiffByLines;
    options.ignoringSpace = (self.spaceButton.state == NSControlStateValueOn);
    options.ignoringCase = (self.caseButton.state == NSControlStateValueOn);
    return options;
}


- (void)changeGrain:(id)sender
{
    [self showTheComparison];
}


- (void)showTheComparison
{
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetweenWithOptions(
        self.leftText, self.rightText, [self options]);
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

    // In the title too: the Window menu lists titles, and «Comparison»
    // three times over says nothing about which is which.
    self.window.title = [MPCompareWindowController titleForLeft:self.leftName
        right:self.rightName differences:added + removed + changed];

    NSMutableArray<NSValue *> *leftRanges = [NSMutableArray array];
    NSMutableArray<NSValue *> *rightRanges = [NSMutableArray array];
    [self.leftView.textStorage setAttributedString:
        [self sideOf:YES ranges:leftRanges]];
    [self.rightView.textStorage setAttributedString:
        [self sideOf:NO ranges:rightRanges]];
    self.leftRowRanges = leftRanges;
    self.rightRowRanges = rightRanges;

    // A paragraph is too long to read sideways; a line is not, and keeping
    // it on one line is what lets two columns be read across.
    BOOL wrapping = ([self options].grain == MPDiffByParagraphs);
    [self setWrapping:wrapping in:self.leftView scroll:self.leftScroll];
    [self setWrapping:wrapping in:self.rightView scroll:self.rightScroll];
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


/// Wrapped, a row is as tall as it needs to be and the two sides no longer
/// line up by pixel — which is why the scrolling follows rows and not
/// points.
- (void)setWrapping:(BOOL)wrapping in:(NSTextView *)view
             scroll:(NSScrollView *)scroll
{
    scroll.hasHorizontalScroller = !wrapping;
    view.horizontallyResizable = !wrapping;
    view.textContainer.widthTracksTextView = wrapping;
    if (wrapping)
    {
        NSSize size = NSMakeSize(scroll.contentSize.width, CGFLOAT_MAX);
        view.textContainer.containerSize = size;
        [view setFrameSize:NSMakeSize(scroll.contentSize.width,
                                      view.frame.size.height)];
    }
    else
    {
        view.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX,
                                                      CGFLOAT_MAX);
    }
}


- (NSAttributedString *)sideOf:(BOOL)left
                        ranges:(NSMutableArray<NSValue *> *)ranges
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
        // The mark before the number: red and green are not something
        // everybody separates, and a sign in the margin is.
        NSString *mark = @" ";
        if (row.kind == MPDiffChanged)
            mark = @"~";
        else if (row.kind == MPDiffAdded)
            mark = text ? @"+" : @" ";
        else if (row.kind == MPDiffRemoved)
            mark = text ? @"\u2212" : @" ";
        NSString *line = [NSString stringWithFormat:@"%@%@ %@\n", mark,
                          gutter, text ?: @""];

        [ranges addObject:[NSValue valueWithRange:
            NSMakeRange(whole.length, line.length)]];

        NSMutableAttributedString *piece =
            [[NSMutableAttributedString alloc] initWithString:line];
        NSRange all = NSMakeRange(0, piece.length);
        [piece addAttribute:NSFontAttributeName value:font range:all];
        [piece addAttribute:NSForegroundColorAttributeName
                      value:[NSColor labelColor] range:all];
        [piece addAttribute:NSForegroundColorAttributeName
                      value:[NSColor tertiaryLabelColor]
                      range:NSMakeRange(0, kMPCompareGutter + 1)];

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
                range.location += kMPCompareGutter + 2;
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

/// ⌘G and ⇧⌘G, which is what those keys mean everywhere else: the next one
/// of what this window is about.
- (void)performFindPanelAction:(id)sender
{
    NSInteger tag = [sender respondsToSelector:@selector(tag)]
        ? [sender tag] : NSFindPanelActionNext;
    if (tag == NSFindPanelActionPrevious)
        [self goToPrevious:sender];
    else
        [self goToNext:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if (item.action == @selector(performFindPanelAction:))
    {
        return item.tag == NSFindPanelActionNext
            || item.tag == NSFindPanelActionPrevious;
    }
    return YES;
}

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
    [self show:row in:self.leftView ranges:self.leftRowRanges
        scroll:self.leftScroll];
    [self show:row in:self.rightView ranges:self.rightRowRanges
        scroll:self.rightScroll];
}


/// The row is the same number on both sides, which is the whole point of
/// building the two texts row by row.
- (void)show:(NSUInteger)row in:(NSTextView *)view
      ranges:(NSArray<NSValue *> *)ranges scroll:(NSScrollView *)scroll
{
    if (row >= ranges.count)
        return;
    NSRange range = ranges[row].rangeValue;
    if (range.length > 0)
        range.length -= 1;              // without the line ending
    if (NSMaxRange(range) > view.string.length)
        return;

    self.following = YES;
    [view setSelectedRange:range];
    NSRect rect = [self rectOfRange:range in:view];
    NSRect visible = scroll.contentView.bounds;
    // Kept a third of the way down rather than scrolled to the very top:
    // a difference with nothing above it has lost its context.
    CGFloat wanted = MAX(0.0, NSMinY(rect) - visible.size.height / 3.0);
    [scroll.contentView scrollToPoint:NSMakePoint(visible.origin.x, wanted)];
    [scroll reflectScrolledClipView:scroll.contentView];
    self.following = NO;
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
