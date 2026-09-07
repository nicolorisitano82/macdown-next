//
//  MPHtmlPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPHtmlPreferencesViewController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"


NS_INLINE NSString *MPPrismDefaultThemeName(void)
{
    return NSLocalizedString(@"(Default)", @"Prism theme title");
}


@interface MPHtmlPreferencesViewController ()
/// The column of sections, kept because its fitting size is the pane's.
@property (weak, nonatomic) NSStackView *sections;
@property (weak) NSPopUpButton *stylesheetSelect;
@property (weak) NSSegmentedControl *stylesheetFunctions;
@property (weak) NSPopUpButton *highlightingThemeSelect;
/// The controls that only make sense while syntax highlighting is on.
@property (copy) NSArray<NSControl *> *highlightingDependents;
@property (weak) NSButton *inlineDollarCheckbox;
@property (assign, nonatomic) CGFloat rowLabelWidth;
@end


@implementation MPHtmlPreferencesViewController

#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"HtmlPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesRendering"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Rendering", @"Preference pane title.");
}


#pragma mark - Building the pane

/** Builds the pane rather than unarchiving it.
 *
 * It was a nib, and had drifted out of step with what the application does:
 * the diagram switches were still disabled unless syntax highlighting was on,
 * long after the two were separated in the renderer, and a label promised
 * that maths needed an internet connection when MathJax now ships inside the
 * application. Neither is the sort of thing that survives being nudged; the
 * layout also had a checkbox sitting on top of the row above it.
 *
 * In code the groups can say what belongs together, and a switch added later
 * costs a line rather than a fight with fifty-five constraints.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    for (NSView *old in [self.view.subviews copy])
        [old removeFromSuperview];

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 18.0;
    stack.edgeInsets = NSEdgeInsetsMake(20.0, 20.0, 20.0, 20.0);
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    /* Seven sections, and it scrolls.
     *
     * The pane used to be exactly as tall as its content, and the window
     * takes its height from the pane — so every switch added made the
     * window taller, until it was taller than the screen it had to open on
     * and the bottom of it could not be reached at all.
     *
     * Scrolling and a height that can be dragged, rather than dropping
     * anything or hiding it behind a disclosure: the sections are all
     * things somebody looks for.
     */
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.autohidesScrollers = YES;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = stack;
    [self.view addSubview:scroll];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:
            self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:
            scroll.contentView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:
            scroll.contentView.leadingAnchor],
        // The width comes from the clip view, so the rows lay out to the
        // pane and the scrolling stays vertical only.
        [stack.widthAnchor constraintEqualToAnchor:
            scroll.contentView.widthAnchor],
        // And deliberately NOT the bottom. Pinned there, the document view
        // is as tall as the clip view and the clip view as tall as the
        // document — so the content drove the pane's height and the scroll
        // view scrolled nothing. Measured: 991 points, with a cap of 560
        // right above it doing nothing at all. Left free, the stack's own
        // height is the document's, which is what a scroll view is for.
    ]];
    self.sections = stack;

    [self addStyleSectionTo:stack];
    [self addCodeSectionTo:stack];
    [self addDiagramSectionTo:stack];
    [self addMathSectionTo:stack];
    [self addMarkdownSectionTo:stack];
    [self addWritingSectionTo:stack];
    [self addPreviewSectionTo:stack];

    [self updateHighlightingDependents];

    /* The size the window opens at.
     *
     * Taken from what the sections want, and then capped: the whole point
     * of the scroll view is that the pane need not be as tall as its
     * content. The cap is a height that fits a laptop screen with room for
     * the menu bar and the dock, which is the machine this has to open on.
     *
     * The fitting size is asked of the stack and not of the view, because a
     * view whose only child is a scroll view has no opinion about its own
     * height at all.
     */
    static const CGFloat kMPPaneMaximumHeight = 560.0;

    [self.view layoutSubtreeIfNeeded];
    NSSize needed = self.sections.fittingSize;
    if (needed.width > 0.0 && needed.height > 0.0)
    {
        self.view.frame = NSMakeRect(0.0, 0.0, needed.width,
            MIN(needed.height, kMPPaneMaximumHeight));
    }
}

/** Lets the window be dragged taller, which MASPreferences asks about.
 *
 * It reads these to decide the window's maximum size and whether to show a
 * resize indicator at all. Height only: the rows are a column of switches,
 * and stretching that sideways gives a reader nothing but longer lines to
 * follow with their eye.
 */
- (BOOL)hasResizableHeight
{
    return YES;
}

- (BOOL)hasResizableWidth
{
    return NO;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self loadStylesheets];
    [self loadHighlightingThemes];
    [self updateHighlightingDependents];
}


#pragma mark - Pieces

- (NSTextField *)headingWithTitle:(NSString *)title
{
    NSTextField *label = [NSTextField labelWithString:title];
    label.font = [NSFont systemFontOfSize:
        [NSFont smallSystemFontSize] weight:NSFontWeightSemibold];
    label.textColor = [NSColor secondaryLabelColor];
    return label;
}

/// Explanatory small print under a switch.
static const CGFloat kMPNoteWidth = 400.0;

- (NSTextField *)noteWithText:(NSString *)text
{
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    label.textColor = [NSColor secondaryLabelColor];
    label.selectable = NO;

    // A wrapping label with nothing to push against hugs its own text and
    // breaks after every second word. The width has to be stated.
    label.preferredMaxLayoutWidth = kMPNoteWidth;
    [label.widthAnchor constraintEqualToConstant:kMPNoteWidth].active = YES;
    return label;
}

/// A checkbox wired straight to a preference, which is all any of these do.
- (NSButton *)checkboxWithTitle:(NSString *)title key:(NSString *)key
{
    NSButton *box = [NSButton checkboxWithTitle:title target:self
                                         action:@selector(preferenceToggled:)];
    [box bind:NSValueBinding toObject:self
       withKeyPath:[@"preferences." stringByAppendingString:key]
           options:nil];
    return box;
}

/// The width of the label column, measured rather than guessed.
///
/// Tying each label's width to the first one's looked tidier and hung the
/// layout engine. Measuring the strings is duller and terminates.
- (CGFloat)rowLabelWidth
{
    if (_rowLabelWidth > 0.0)
        return _rowLabelWidth;

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:
            [NSFont systemFontSize]],
    };
    CGFloat widest = 96.0;
    for (NSString *title in @[
        NSLocalizedString(@"Stylesheet:", @"CSS picker"),
        NSLocalizedString(@"Theme:", @"Prism theme"),
        NSLocalizedString(@"Label:", @"Code accessory"),
        NSLocalizedString(@"Default path:", @"Where previews resolve from"),
    ])
    {
        widest = MAX(widest, [title sizeWithAttributes:attributes].width);
    }
    _rowLabelWidth = ceil(widest) + 4.0;
    return _rowLabelWidth;
}

/// A row of a label and a control, so the labels line up down the pane.
- (NSStackView *)rowWithLabel:(NSString *)title control:(NSView *)control
{
    NSTextField *label = [NSTextField labelWithString:title];
    label.alignment = NSTextAlignmentRight;
    [label setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [label.widthAnchor constraintEqualToConstant:self.rowLabelWidth].active =
        YES;

    NSStackView *row = [NSStackView stackViewWithViews:@[label, control]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8.0;
    return row;
}

/// Indents the controls that belong to the switch above them.
- (NSStackView *)indented:(NSArray<NSView *> *)views
{
    NSStackView *inner = [NSStackView stackViewWithViews:views];
    inner.orientation = NSUserInterfaceLayoutOrientationVertical;
    inner.alignment = NSLayoutAttributeLeading;
    inner.spacing = 8.0;
    inner.edgeInsets = NSEdgeInsetsMake(0.0, 20.0, 0.0, 0.0);
    return inner;
}

- (void)addSection:(NSString *)title views:(NSArray<NSView *> *)views
                to:(NSStackView *)stack
{
    NSMutableArray *all = [NSMutableArray array];
    if (title.length)
        [all addObject:[self headingWithTitle:title]];
    [all addObjectsFromArray:views];

    NSStackView *section = [NSStackView stackViewWithViews:all];
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 8.0;
    [stack addArrangedSubview:section];
}


#pragma mark - Sections

- (void)addStyleSectionTo:(NSStackView *)stack
{
    NSPopUpButton *styles = [[NSPopUpButton alloc] initWithFrame:NSZeroRect
                                                       pullsDown:NO];
    styles.target = self;
    styles.action = @selector(changeStylesheet:);
    [styles.widthAnchor constraintGreaterThanOrEqualToConstant:220.0].active =
        YES;
    self.stylesheetSelect = styles;

    NSSegmentedControl *functions = [NSSegmentedControl
        segmentedControlWithLabels:@[
            NSLocalizedString(@"Reveal", @"Show the styles folder in Finder"),
            NSLocalizedString(@"Reload", @"Re-read the styles folder"),
        ]
                      trackingMode:NSSegmentSwitchTrackingMomentary
                            target:self
                            action:@selector(invokeStylesheetFunction:)];
    self.stylesheetFunctions = functions;

    NSStackView *row = [NSStackView stackViewWithViews:@[styles, functions]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 8.0;

    [self addSection:NSLocalizedString(@"Style", @"Preferences section")
               views:@[[self rowWithLabel:
                            NSLocalizedString(@"Stylesheet:", @"CSS picker")
                                  control:row]]
                  to:stack];
}

- (void)addCodeSectionTo:(NSStackView *)stack
{
    NSButton *highlight = [self
        checkboxWithTitle:NSLocalizedString(@"Highlight syntax in code blocks",
                                            @"Preference")
                      key:@"htmlSyntaxHighlighting"];

    NSPopUpButton *theme = [[NSPopUpButton alloc] initWithFrame:NSZeroRect
                                                      pullsDown:NO];
    theme.target = self;
    theme.action = @selector(changeHighlightingTheme:);
    [theme.widthAnchor constraintGreaterThanOrEqualToConstant:200.0].active =
        YES;
    self.highlightingThemeSelect = theme;

    NSPopUpButton *accessory = [[NSPopUpButton alloc] initWithFrame:NSZeroRect
                                                          pullsDown:NO];
    [accessory addItemsWithTitles:@[
        NSLocalizedString(@"None", @"No code block accessory"),
        NSLocalizedString(@"Language name", @"Code block accessory"),
        NSLocalizedString(@"Custom", @"Code block accessory"),
    ]];
    [accessory bind:NSSelectedIndexBinding toObject:self
        withKeyPath:@"preferences.htmlCodeBlockAccessory" options:nil];
    [accessory.widthAnchor constraintGreaterThanOrEqualToConstant:200.0]
        .active = YES;

    NSButton *numbers = [self
        checkboxWithTitle:NSLocalizedString(@"Show line numbers", @"Preference")
                      key:@"htmlLineNumbers"];

    self.highlightingDependents = @[theme, accessory, numbers];

    [self addSection:NSLocalizedString(@"Code", @"Preferences section")
               views:@[
        highlight,
        [self indented:@[
            [self rowWithLabel:NSLocalizedString(@"Theme:", @"Prism theme")
                       control:theme],
            [self rowWithLabel:NSLocalizedString(@"Label:", @"Code accessory")
                       control:accessory],
            numbers,
        ]],
    ] to:stack];
}

- (void)addDiagramSectionTo:(NSStackView *)stack
{
    // No longer beneath syntax highlighting, in the pane or in the renderer:
    // a diagram is not a highlighted code block, and tying the two meant a
    // mermaid fence quietly stayed a code block for anyone who preferred
    // their code unhighlighted.
    [self addSection:NSLocalizedString(@"Diagrams", @"Preferences section")
               views:@[
        [self checkboxWithTitle:NSLocalizedString(@"Mermaid", @"Preference")
                            key:@"htmlMermaid"],
        [self checkboxWithTitle:NSLocalizedString(@"Graphviz", @"Preference")
                            key:@"htmlGraphviz"],
        [self noteWithText:NSLocalizedString(
            @"Loaded only for documents that contain a diagram.",
            @"Explains that diagram support costs nothing otherwise")],
    ] to:stack];
}

- (void)addMathSectionTo:(NSStackView *)stack
{
    NSButton *math = [self
        checkboxWithTitle:NSLocalizedString(@"TeX-like math syntax",
                                            @"Preference")
                      key:@"htmlMathJax"];

    NSButton *dollar = [self
        checkboxWithTitle:NSLocalizedString(
            @"Use dollar sign ($) as inline delimiter", @"Preference")
                      key:@"htmlMathJaxInlineDollar"];
    self.inlineDollarCheckbox = dollar;

    [self addSection:NSLocalizedString(@"Math", @"Preferences section")
               views:@[
        math,
        [self indented:@[dollar]],
        // The pane used to say this needed an internet connection. MathJax
        // is bundled now, and nothing is fetched.
        [self noteWithText:NSLocalizedString(
            @"MathJax is included in the application; no connection is "
            @"required.", @"Explains that maths works offline")],
    ] to:stack];
}

- (void)addMarkdownSectionTo:(NSStackView *)stack
{
    [self addSection:NSLocalizedString(@"Markdown", @"Preferences section")
               views:@[
        [self checkboxWithTitle:NSLocalizedString(@"Task list syntax",
                                                  @"Preference")
                            key:@"htmlTaskList"],
        [self checkboxWithTitle:NSLocalizedString(@"Detect Jekyll front-matter",
                                                  @"Preference")
                            key:@"htmlDetectFrontMatter"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Detect table of contents token", @"Preference")
                            key:@"htmlRendersTOC"],
        [self checkboxWithTitle:NSLocalizedString(@"Render newline literally",
                                                  @"Preference")
                            key:@"htmlHardWrap"],
    ] to:stack];
}

- (void)addWritingSectionTo:(NSStackView *)stack
{
    [self addSection:NSLocalizedString(@"Writing", @"Preferences section")
               views:@[
        [self checkboxWithTitle:NSLocalizedString(
            @"Link [[wiki style]] references to neighbouring documents",
            @"Preference") key:@"htmlWikiLinks"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Highlight prose issues in new documents", @"Preference")
                            key:@"editorProseHighlights"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Scale headings with the editor font", @"Preference")
                            key:@"editorSemanticStyling"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Hide the Markdown markers until the caret reaches them",
            @"Preference") key:@"editorHideMarkers"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Indent lists and quotations in the editor", @"Preference")
                            key:@"editorBlockLayout"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Dim everything but the paragraph you are writing",
            @"Preference") key:@"editorFocusMode"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Keep the line you are writing at the same height",
            @"Preference") key:@"editorTypewriter"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Paste formatted text as Markdown", @"Preference")
                            key:@"editorPasteAsMarkdown"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Fetch images from the network when exporting", @"Preference")
                            key:@"exportFetchesRemoteImages"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Ask a web page what it is when the pointer rests on its link",
            @"Preference") key:@"previewFetchesLinkPages"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Selecting text in the preview selects it in the editor",
            @"Preference") key:@"previewSelectionSelectsSource"],
        [self checkboxWithTitle:NSLocalizedString(
            @"Offer the writing commands, using a local model",
            @"Preference") key:@"editorWritingHelp"],
        [self noteWithText:NSLocalizedString(
            @"Editor themes state heading sizes in points, chosen for the "
            @"default body size. This keeps their proportions at any size. "
            @"At the default it changes nothing.",
            @"Explains what heading scaling does")],
        [self noteWithText:NSLocalizedString(
            @"Hiding the markers and indenting, together, also draw three "
            @"dashes as a line across the page.",
            @"Explains that horizontal rules need both settings")],
        [self noteWithText:NSLocalizedString(
            @"Pasted headings, lists and links keep their shape. "
            @"⌘⇧V pastes the text exactly as it was copied.",
            @"Explains what pasting as Markdown does")],
    ] to:stack];
}

- (void)addPreviewSectionTo:(NSStackView *)stack
{
    NSPathControl *path = [[NSPathControl alloc] initWithFrame:NSZeroRect];
    path.pathStyle = NSPathStylePopUp;
    [path bind:NSValueBinding toObject:self
   withKeyPath:@"preferences.htmlDefaultDirectoryUrl" options:nil];
    [path.widthAnchor constraintGreaterThanOrEqualToConstant:220.0].active =
        YES;

    [self addSection:NSLocalizedString(@"Preview", @"Preferences section")
               views:@[
        [self checkboxWithTitle:NSLocalizedString(
            @"Scale preview based on editor font size", @"Preference")
                            key:@"previewZoomRelativeToBaseFontSize"],
        [self rowWithLabel:NSLocalizedString(@"Default path:",
                                              @"Where previews resolve from")
                   control:path],
    ] to:stack];
}


#pragma mark - Actions

- (IBAction)preferenceToggled:(NSButton *)sender
{
    [self updateHighlightingDependents];
}

/// Greys out what genuinely depends on syntax highlighting, and nothing else.
- (void)updateHighlightingDependents
{
    BOOL on = self.preferences.htmlSyntaxHighlighting;
    for (NSControl *control in self.highlightingDependents)
        control.enabled = on;
    self.inlineDollarCheckbox.enabled = self.preferences.htmlMathJax;
}

- (IBAction)changeStylesheet:(NSPopUpButton *)sender
{
    NSString *title = sender.selectedItem.title;

    // Special case: the first (empty) item. No stylesheets will be used.
    if (!title.length)
        self.preferences.htmlStyleName = nil;
    else
        self.preferences.htmlStyleName = title;
}

- (IBAction)changeHighlightingTheme:(NSPopUpButton *)sender
{
    NSString *title = sender.selectedItem.title;
    if ([title isEqualToString:MPPrismDefaultThemeName()])
        self.preferences.htmlHighlightingThemeName = @"";
    else
        self.preferences.htmlHighlightingThemeName = title;
}

- (IBAction)invokeStylesheetFunction:(NSSegmentedControl *)sender
{
    switch (sender.selectedSegment)
    {
        case 0:     // Reveal
        {
            NSString *dirPath = MPDataDirectory(kMPStylesDirectoryName);
            NSURL *url = [NSURL fileURLWithPath:dirPath];
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace activateFileViewerSelectingURLs:@[url]];
            break;
        }
        case 1:     // Reload
        {
            [self loadStylesheets];
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            [center postNotificationName:MPDidRequestPreviewRenderNotification
                                  object:self];
            break;
        }
        default:
            break;
    }
}


#pragma mark - Private

- (void)loadStylesheets
{
    self.stylesheetSelect.enabled = NO;
    [self.stylesheetSelect removeAllItems];

    NSArray *itemTitles = MPListEntriesForDirectory(
        kMPStylesDirectoryName,
        MPFileNameHasExtensionProcessor(kMPStyleFileExtension)
    );

    [self.stylesheetSelect addItemWithTitle:@""];
    [self.stylesheetSelect addItemsWithTitles:itemTitles];

    NSString *title = self.preferences.htmlStyleName;
    if (title.length)
        [self.stylesheetSelect selectItemWithTitle:title];

    self.stylesheetSelect.enabled = YES;
}

- (void)loadHighlightingThemes
{
    [self.highlightingThemeSelect removeAllItems];

    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *urls = [bundle URLsForResourcesWithExtension:@"css"
                                             subdirectory:@"Prism/themes"];
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSURL *url in urls)
    {
        NSString *name = url.lastPathComponent;
        if (name.length <= 10)
            continue;
        name = [name substringWithRange:NSMakeRange(6, name.length - 10)];
        [titles addObject:[name capitalizedString]];
    }

    [self.highlightingThemeSelect addItemWithTitle:MPPrismDefaultThemeName()];
    [self.highlightingThemeSelect addItemsWithTitles:titles];

    NSString *currentName = self.preferences.htmlHighlightingThemeName;
    if (currentName.length)
        [self.highlightingThemeSelect selectItemWithTitle:currentName];
}

@end
