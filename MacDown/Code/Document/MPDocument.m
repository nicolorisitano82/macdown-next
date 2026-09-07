//
//  MPDocument.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPDocument.h"
#import <WebKit/WebKit.h>
#import <JJPluralForm/JJPluralForm.h>
#import <hoedown/html.h>
#import "hoedown_html_patch.h"
#import "HGMarkdownHighlighter.h"
#import "MPUtilities.h"
#import "MPAutosaving.h"
#import "NSColor+HTML.h"
#import "NSDocumentController+Document.h"
#import "NSPasteboard+Types.h"
#import "NSString+Lookup.h"
#import "NSTextView+Autocomplete.h"
#import "MPPreferences.h"
#import "MPDocumentSplitView.h"
#import "MPEditorView.h"
#import "MPRenderer.h"
#import "MPPreferencesViewController.h"
#import "MPEditorPreferencesViewController.h"
#import "MPExportPanelAccessoryViewController.h"
#import "MPMathJaxListener.h"
#import "MPToolbarController.h"
#import "MPPreviewSchemeHandler.h"
#import "MPProseChecker.h"
#import "MPSemanticStyler.h"
#import "MPMarkerHider.h"
#import "MPBlockStyler.h"
#import "MPTableSource.h"
#import "MPMathEditorController.h"
#import "MPSidebarController.h"
#import "MPEpubExport.h"
#import "MPDocxPostProcessing.h"
#import "MPRemoteImageFetch.h"
#import "MPModelStore.h"
#import "MPWritingAssistant.h"
#import "MPDocumentTemplate.h"
#import "MPCodeLanguages.h"
#import "MPProseIssuesViewController.h"
#import "MPBacklinksViewController.h"
#import "MPBacklinks.h"
#import "MPLinkPreview.h"
#import "MPLinkPreviewViewController.h"
#import "MPWebClipper.h"
#import "MPPreviewSelection.h"
#import "MPRichExport.h"
#import "MPTextBundle.h"
#import "MPSendTo.h"
#import "MPInstructionFiles.h"
#import "MPInstructionsViewController.h"
#import "MPPlugIn.h"
#import "MPActionLog.h"
#import "MPTaskList.h"
#import <JavaScriptCore/JavaScriptCore.h>

static NSString * const kMPDefaultAutosaveName = @"Untitled";


NS_INLINE NSString *MPEditorPreferenceKeyWithValueKey(NSString *key)
{
    if (!key.length)
        return @"editor";
    NSString *first = [[key substringToIndex:1] uppercaseString];
    NSString *rest = [key substringFromIndex:1];
    return [NSString stringWithFormat:@"editor%@%@", first, rest];
}

NS_INLINE NSDictionary *MPEditorKeysToObserve()
{
    static NSDictionary *keys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        // Every check except the four that rewrite what was typed. The mask
        // and the switches below are two views of one state, and a
        // dictionary hands them over in whatever order it likes: asking for
        // every type turns the switches back on, so `---` became an em
        // dash — which is not a horizontal rule, not the underline of a
        // setext heading, and not a table's separator row.
        NSTextCheckingTypes rewriting =
            NSTextCheckingTypeDash | NSTextCheckingTypeQuote
            | NSTextCheckingTypeReplacement | NSTextCheckingTypeCorrection;

        keys = @{@"automaticDashSubstitutionEnabled": @NO,
                 @"automaticDataDetectionEnabled": @NO,
                 @"automaticQuoteSubstitutionEnabled": @NO,
                 @"automaticSpellingCorrectionEnabled": @NO,
                 @"automaticTextReplacementEnabled": @NO,
                 @"continuousSpellCheckingEnabled": @NO,
                 @"enabledTextCheckingTypes":
                     @(NSTextCheckingAllTypes & ~rewriting),
                 @"grammarCheckingEnabled": @NO};
    });
    return keys;
}

NS_INLINE NSSet *MPEditorPreferencesToObserve()
{
    static NSSet *keys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        keys = [NSSet setWithObjects:
            @"editorBaseFontInfo", @"extensionFootnotes",
            @"editorHorizontalInset", @"editorVerticalInset",
            @"editorWidthLimited", @"editorMaximumWidth", @"editorLineSpacing",
            @"editorOnRight", @"editorStyleName", @"editorShowWordCount",
            @"editorScrollsPastEnd", @"editorProseHighlights",
            @"editorSemanticStyling", @"editorHideMarkers",
            @"editorBlockLayout", @"editorPasteAsMarkdown", nil
        ];
    });
    return keys;
}

NS_INLINE NSString *MPRectStringForAutosaveName(NSString *name)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [NSString stringWithFormat:@"NSWindow Frame %@", name];
    NSString *rectString = [defaults objectForKey:key];
    return rectString;
}


@implementation NSURL (Convert)

- (NSString *)absoluteBaseURLString
{
    // Remove fragment (#anchor) and query string.
    NSString *base = self.absoluteString;
    base = [base componentsSeparatedByString:@"?"].firstObject;
    base = [base componentsSeparatedByString:@"#"].firstObject;
    return base;
}

@end


@implementation MPPreferences (Hoedown)
- (int)extensionFlags
{
    int flags = 0;
    if (self.extensionAutolink)
        flags |= HOEDOWN_EXT_AUTOLINK;
    if (self.extensionFencedCode)
        flags |= HOEDOWN_EXT_FENCED_CODE;
    if (self.extensionFootnotes)
        flags |= HOEDOWN_EXT_FOOTNOTES;
    if (self.extensionHighlight)
        flags |= HOEDOWN_EXT_HIGHLIGHT;
    if (!self.extensionIntraEmphasis)
        flags |= HOEDOWN_EXT_NO_INTRA_EMPHASIS;
    if (self.extensionQuote)
        flags |= HOEDOWN_EXT_QUOTE;
    if (self.extensionStrikethough)
        flags |= HOEDOWN_EXT_STRIKETHROUGH;
    if (self.extensionSuperscript)
        flags |= HOEDOWN_EXT_SUPERSCRIPT;
    if (self.extensionTables)
        flags |= HOEDOWN_EXT_TABLES;
    if (self.extensionUnderline)
        flags |= HOEDOWN_EXT_UNDERLINE;
    if (self.htmlMathJax)
        flags |= HOEDOWN_EXT_MATH;
    if (self.htmlMathJaxInlineDollar)
        flags |= HOEDOWN_EXT_MATH_EXPLICIT;

    // Not a preference. CommonMark and GitHub both require the space after
    // the hashes, and without it `#hashtag` at the start of a line is a
    // level-one heading — which is never what anybody meant by writing a
    // hashtag. The parser has always been able to do this; nothing turned
    // it on.
    flags |= HOEDOWN_EXT_SPACE_HEADERS;
    return flags;
}

- (int)rendererFlags
{
    int flags = 0;
    if (self.htmlTaskList)
        flags |= HOEDOWN_HTML_USE_TASK_LIST;
    if (self.htmlLineNumbers)
        flags |= HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS;
    if (self.htmlHardWrap)
        flags |= HOEDOWN_HTML_HARD_WRAP;
    if (self.htmlCodeBlockAccessory == MPCodeBlockAccessoryCustom)
        flags |= HOEDOWN_HTML_BLOCKCODE_INFORMATION;
    return flags;
}
@end


@interface MPDocument ()
    <NSSplitViewDelegate, NSTextViewDelegate, NSWindowDelegate,
     MPSidebarControllerDelegate,
     WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
     MPAutosaving, MPRendererDataSource, MPRendererDelegate>

/// The list of flagged words, while it is open.
@property (strong, nonatomic) NSPopover *prosePopover;

/** Whether this document is being read rather than written.
 *
 * Per document and not remembered: a verbale that has been signed is read
 * today and may be corrected tomorrow, and a lock that outlives the
 * session is a lock somebody has to remember about.
 */
@property (assign, nonatomic) BOOL readOnly;
@property (strong, nonatomic)
    NSTitlebarAccessoryViewController *readOnlyBadge;
/// The list of documents that cite this one, while it is open.
@property (strong, nonatomic) NSPopover *backlinkPopover;
@property (strong, nonatomic) NSPopover *instructionsPopover;
/// The card for the link the pointer is resting on, while it is up.
@property (strong, nonatomic) NSPopover *linkPopover;
/// Moves every time a card is asked for or put away, so a page
/// answering late cannot open a card nobody is waiting for.
@property (nonatomic) NSUInteger hoverToken;
/// How many the last tally found, so the menu item knows whether to offer.
@property (assign, nonatomic) NSUInteger proseIssueCount;

typedef NS_ENUM(NSUInteger, MPWordCountType) {
    MPWordCountTypeWord,
    MPWordCountTypeCharacter,
    MPWordCountTypeCharacterNoSpaces,
    /// How long it takes to read, which is the figure that means something
    /// to whoever has to read it.
    MPWordCountTypeReadingTime,
};

@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet MPDocumentSplitView *splitView;
@property (weak) IBOutlet NSView *editorContainer;
@property (unsafe_unretained) IBOutlet MPEditorView *editor;
@property (weak) IBOutlet NSLayoutConstraint *editorPaddingBottom;
@property (weak) IBOutlet NSView *previewContainer;

/** The preview.
 *
 * Built in code rather than in the nib: WKWebView needs a configuration
 * assembled before it exists — the user scripts below have to be in place
 * before the first page loads, and a view unarchived from a nib has already
 * missed that.
 */
@property (strong, nonatomic) WKWebView *preview;

/// Last scroll position the page reported, in CSS pixels.
@property (assign, nonatomic) CGFloat previewScrollTop;
@property (assign, nonatomic) CGFloat previewContentHeight;
@property (assign, nonatomic) CGFloat previewViewportHeight;
/// Body background as the page computes it, for the split view divider.
@property (strong, nonatomic) NSColor *previewBackgroundColor;
/// The drawn diagrams, posted by the page after each render.
@property (copy, nonatomic) NSArray<NSString *> *harvestedDiagrams;
/// The typeset formulas, likewise: {svg, display}.
@property (copy, nonatomic) NSArray<NSDictionary *> *harvestedFormulas;
@property (strong, nonatomic) NSURL *previewScratchDirectory;
@property (strong, nonatomic) MPPreviewSchemeHandler *previewSchemeHandler;
@property (weak) IBOutlet NSPopUpButton *wordCountWidget;
@property (strong) IBOutlet MPToolbarController *toolbarController;
@property (copy, nonatomic) NSString *autosaveName;
@property (copy, nonatomic) NSString *currentHeadHTML;
@property (strong, nonatomic) MPSidebarController *sidebar;
@property (strong, nonatomic) NSSplitView *outerSplitView;
@property (strong) HGMarkdownHighlighter *highlighter;
@property (strong) MPSemanticStyler *semanticStyler;
@property (strong) MPMarkerHider *markerHider;
@property (strong) MPBlockStyler *blockStyler;
@property (strong) MPRenderer *renderer;
@property CGFloat previousSplitRatio;
@property BOOL manualRender;
@property BOOL copying;
@property BOOL printing;
@property BOOL shouldHandleBoundsChange;
/** When each side was last moved by the reader.
 *
 * One notion instead of two flags. Two panes that scroll each other will
 * chase one another down the document unless something decides which of
 * them is being driven, and a flag set around the moment of scrolling does
 * not do it: the bounds change arrives after the flag has been put back.
 *
 * Whichever side the reader touched last owns the scrolling until a moment
 * after they stop, and the other side only follows.
 */
@property (assign) NSTimeInterval previewDrivenAt;
@property (assign) NSTimeInterval editorDrivenAt;
/** When the last character was typed.
 *
 * Typing is the third thing that scrolls the editor, and neither side of
 * the handover above accounts for it: the reader is not scrolling at all,
 * the text view is, a line at a time, to keep the caret in sight. Sending
 * the preview after it means both panes shuffling on every keystroke — and
 * on every re-render in between, since the page is rebuilt as you write
 * and comes back a different height.
 */
@property (assign) NSTimeInterval lastTypedAt;
/// Made on the first writing command, and only then.
@property (strong) MPWritingAssistant *writingAssistant;
/// Says what the writing help is doing, while it is doing it.
@property (strong) NSView *writingStatus;
@property (strong) NSTextField *writingStatusLabel;
@property (strong) NSProgressIndicator *writingSpinner;
/// Where the editor stood when the current burst of typing began.
@property (assign) CGFloat editorTopWhenTypingBegan;
/// Whether a keystroke is recent enough that the panes should sit still.
@property (nonatomic, readonly) BOOL isTyping;
@property BOOL isPreviewReady;
@property (strong) NSURL *currentBaseUrl;
@property CGFloat lastPreviewScrollTop;
@property (nonatomic, readonly) BOOL needsHtml;
@property (nonatomic) NSUInteger totalWords;
@property (nonatomic) NSUInteger totalCharacters;
@property (nonatomic) NSUInteger totalCharactersNoSpaces;
@property (strong) NSMenuItem *wordsMenuItem;
@property (strong) NSMenuItem *charMenuItem;
@property (strong) NSMenuItem *charNoSpacesMenuItem;
@property (strong) NSMenuItem *readingTimeMenuItem;
@property (nonatomic) BOOL needsToUnregister;
@property (nonatomic) BOOL alreadyRenderingInWeb;
@property (nonatomic) BOOL renderToWebPending;
@property (strong) NSArray<NSNumber *> *webViewHeaderLocations;
@property (strong) NSArray<NSNumber *> *editorHeaderLocations;
@property (nonatomic) BOOL inLiveScroll;

// Store file content in initializer until nib is loaded.
@property (copy) NSString *loadedString;

- (void)adjustPreviewContentInsets;
- (void)markPreviewAtSelection;
- (void)setPreviewScrollTopTo:(CGFloat)top;
- (void)refreshPreviewBackgroundColor;
- (void)harvestDiagramsFromPreview;
- (void)scaleWebview;
- (void)syncScrollers;
-(void) updateHeaderLocations;

@end

static void (^MPGetPreviewLoadingCompletionHandler(MPDocument *doc))()
{
    __weak MPDocument *weakObj = doc;
    return ^{
        [weakObj scaleWebview];

        // A refresh rebuilds the page, so the mark showing where the reader
        // is goes with it. Put it back rather than leaving the bar missing
        // until the selection next happens to move.
        [weakObj markPreviewAtSelection];
        [weakObj adjustPreviewContentInsets];
        [weakObj refreshPreviewBackgroundColor];
        [weakObj harvestDiagramsFromPreview];
        // While the reader is typing a refresh keeps the preview where it
        // was, exactly as it does with the syncing switched off. The page
        // is rebuilt on every pause in the writing, and a pane that jumps
        // each time is worse than one that waits.
        if (weakObj.preferences.editorSyncScrolling && !weakObj.isTyping)
        {
            [weakObj updateHeaderLocations];
            [weakObj syncScrollers];
        }
        else
        {
            [weakObj setPreviewScrollTopTo:weakObj.lastPreviewScrollTop];
        }
    };
}


/** The two numbers the table sheet asks for, and the controls that take them.
 *
 * A stepper beside each field, because a table is three or four of something
 * and nobody wants to type that; the field is there for the fifth time, when
 * it is twelve.
 */
@interface MPTableSizeAccessory : NSView
@property (strong, nonatomic) NSTextField *rowsField;
@property (strong, nonatomic) NSTextField *columnsField;
@property (readonly, nonatomic) NSUInteger rows;
@property (readonly, nonatomic) NSUInteger columns;
@end

@implementation MPTableSizeAccessory

- (instancetype)initWithRows:(NSUInteger)rows columns:(NSUInteger)columns
{
    self = [super initWithFrame:NSMakeRect(0, 0, 264, 58)];
    if (!self)
        return nil;

    NSArray *labels = @[NSLocalizedString(@"Rows:", @"Table size sheet"),
                        NSLocalizedString(@"Columns:", @"Table size sheet")];
    NSArray *values = @[@(rows), @(columns)];
    NSMutableArray *fields = [NSMutableArray array];

    for (NSUInteger i = 0; i < 2; i++)
    {
        CGFloat y = i ? 2.0 : 30.0;

        NSTextField *label = [NSTextField labelWithString:labels[i]];
        label.alignment = NSTextAlignmentRight;
        label.frame = NSMakeRect(0, y + 2, 78, 18);
        [self addSubview:label];

        NSTextField *field = [NSTextField textFieldWithString:
            [values[i] stringValue]];
        field.frame = NSMakeRect(86, y, 56, 22);
        field.alignment = NSTextAlignmentRight;
        [self addSubview:field];
        [fields addObject:field];

        NSStepper *stepper = [[NSStepper alloc] initWithFrame:
            NSMakeRect(146, y, 17, 22)];
        stepper.minValue = 1;
        stepper.maxValue = 50;
        stepper.increment = 1;
        stepper.valueWraps = NO;
        stepper.integerValue = [values[i] integerValue];
        stepper.target = self;
        stepper.action = @selector(stepped:);
        stepper.tag = (NSInteger)i;
        [self addSubview:stepper];
    }

    _rowsField = fields[0];
    _columnsField = fields[1];
    return self;
}

- (void)stepped:(NSStepper *)stepper
{
    NSTextField *field = stepper.tag == 0 ? self.rowsField : self.columnsField;
    field.integerValue = stepper.integerValue;
}

/// Clamped rather than refused: a sheet that scolds you for typing 0 is worse
/// than one that reads it as 1.
- (NSUInteger)numberFrom:(NSTextField *)field
{
    NSInteger value = field.integerValue;
    return (NSUInteger)MIN(MAX(value, (NSInteger)1), (NSInteger)50);
}

- (NSUInteger)rows { return [self numberFrom:self.rowsField]; }
- (NSUInteger)columns { return [self numberFrom:self.columnsField]; }

@end


/** What the link sheet asks for: where the link goes, and what it says.
 *
 * Two kinds of destination, because they are found in two different ways. A
 * web address is typed or pasted; a file is looked for, and asking someone
 * to type a path to a file they can see in the Finder is asking them to do
 * the computer's work.
 *
 * This collects and validates nothing else: turning a chosen file into a
 * link target is the document's business, since only the document knows
 * where it is saved and therefore what the path should be relative to.
 */
@interface MPLinkAccessory : NSView
@property (strong, nonatomic) NSTextField *targetField;
@property (strong, nonatomic) NSTextField *textField;
@property (strong, nonatomic) NSButton *webRadio;
@property (strong, nonatomic) NSButton *fileRadio;
@property (strong, nonatomic) NSButton *emptyFileRadio;
/// Whether the sheet was asked for a file that does not exist yet.
@property (readonly, nonatomic) BOOL makesNewFile;
@property (strong, nonatomic) NSButton *chooseButton;
/// The file picked through the panel, and what was shown in the field for it.
@property (strong, nonatomic) NSURL *chosenURL;
@property (copy, nonatomic) NSString *shownForChosenURL;
@end


@implementation MPLinkAccessory

- (instancetype)initWithText:(NSString *)text
                     address:(NSString *)address
                      toFile:(BOOL)toFile
{
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, 380.0, 134.0)];
    if (!self)
        return nil;

    NSTextField *kind = [NSTextField labelWithString:
        NSLocalizedString(@"Link to:", @"Link sheet")];
    kind.alignment = NSTextAlignmentRight;
    kind.frame = NSMakeRect(0.0, 113.0, 78.0, 18.0);
    [self addSubview:kind];

    _webRadio = [NSButton radioButtonWithTitle:
        NSLocalizedString(@"A web address", @"Link sheet")
                                        target:self
                                        action:@selector(kindChanged:)];
    _webRadio.frame = NSMakeRect(84.0, 111.0, 240.0, 20.0);
    [self addSubview:_webRadio];

    _fileRadio = [NSButton radioButtonWithTitle:
        NSLocalizedString(@"A file on this Mac", @"Link sheet")
                                         target:self
                                         action:@selector(kindChanged:)];
    _fileRadio.frame = NSMakeRect(84.0, 89.0, 240.0, 20.0);
    [self addSubview:_fileRadio];

    // The third destination is one that does not exist yet, which is why
    // it needs no address: the text below names it.
    _emptyFileRadio = [NSButton radioButtonWithTitle:
        NSLocalizedString(@"A new, empty Markdown file beside this one",
                          @"Link sheet")
                                            target:self
                                            action:@selector(kindChanged:)];
    _emptyFileRadio.frame = NSMakeRect(84.0, 67.0, 300.0, 20.0);
    [self addSubview:_emptyFileRadio];

    _webRadio.state = toFile ? NSControlStateValueOff : NSControlStateValueOn;
    _fileRadio.state = toFile ? NSControlStateValueOn : NSControlStateValueOff;
    _emptyFileRadio.state = NSControlStateValueOff;

    NSTextField *where = [NSTextField labelWithString:
        NSLocalizedString(@"Address:", @"Link sheet")];
    where.alignment = NSTextAlignmentRight;
    where.frame = NSMakeRect(0.0, 43.0, 78.0, 18.0);
    [self addSubview:where];

    _targetField = [NSTextField textFieldWithString:address ?: @""];
    _targetField.frame = NSMakeRect(86.0, 40.0, 200.0, 22.0);
    [self addSubview:_targetField];

    _chooseButton = [NSButton buttonWithTitle:
        NSLocalizedString(@"Choose…", @"Link sheet") target:self
                                       action:@selector(choose:)];
    _chooseButton.frame = NSMakeRect(292.0, 38.0, 88.0, 24.0);
    [self addSubview:_chooseButton];

    NSTextField *says = [NSTextField labelWithString:
        NSLocalizedString(@"Text:", @"Link sheet")];
    says.alignment = NSTextAlignmentRight;
    says.frame = NSMakeRect(0.0, 11.0, 78.0, 18.0);
    [self addSubview:says];

    _textField = [NSTextField textFieldWithString:text ?: @""];
    _textField.frame = NSMakeRect(86.0, 8.0, 294.0, 22.0);
    [self addSubview:_textField];

    return self;
}

- (void)kindChanged:(NSButton *)sender
{
    // Choosing a file is the point of the file option, so offer it at once.
    if (sender == self.fileRadio && !self.chosenURL)
        [self choose:sender];

    // A file that does not exist yet has no address to give, and the text
    // is what will name it.
    BOOL blank = (self.emptyFileRadio.state == NSControlStateValueOn);
    self.targetField.enabled = !blank;
    self.chooseButton.enabled = !blank;
}

- (BOOL)makesNewFile
{
    return self.emptyFileRadio.state == NSControlStateValueOn;
}

/** Runs the open panel modally, on top of the sheet.
 *
 * Modal rather than a sheet of its own: a sheet cannot present a sheet, and
 * the alert this sits in already owns the window's.
 */
- (void)choose:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.message = NSLocalizedString(@"Choose the file to link to",
                                      @"Link sheet");

    if ([panel runModal] != NSModalResponseOK || !panel.URL)
        return;

    self.chosenURL = panel.URL;
    // The path as a person reads it. What actually goes in the document is
    // worked out from the URL, since it has to be escaped and may have to
    // be relative — but showing that here would be showing them `%20`.
    self.shownForChosenURL = panel.URL.path;
    self.targetField.stringValue = self.shownForChosenURL;
    self.webRadio.state = NSControlStateValueOff;
    self.fileRadio.state = NSControlStateValueOn;

    if (!self.textField.stringValue.length)
    {
        self.textField.stringValue =
            panel.URL.lastPathComponent.stringByDeletingPathExtension;
    }
}

- (BOOL)usesFile
{
    return self.fileRadio.state == NSControlStateValueOn;
}

/// The file to link to, or nil if the field no longer describes it.
- (NSURL *)fileToLink
{
    if (!self.usesFile || !self.chosenURL)
        return nil;
    // Edited by hand since it was chosen: then what is written wins, and
    // the document takes the field at its word.
    if (![self.targetField.stringValue isEqualToString:self.shownForChosenURL])
        return nil;
    return self.chosenURL;
}

- (NSString *)typedTarget
{
    return [self.targetField.stringValue stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)linkText
{
    return [self.textField.stringValue stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end


/** Asks whether code goes in the line or in a block, and in what language.
 *
 * Backticks around a word and a fenced block are the same idea at two
 * scales, and one button used to do only the smaller one. The larger needs
 * a language to be worth anything — a fence without one is a grey box —
 * and a language is not something to type from memory when there are more
 * than a hundred of them and only the ones in this build will work.
 */
@interface MPCodeAccessory : NSView
@property (strong, nonatomic) NSButton *inlineRadio;
@property (strong, nonatomic) NSButton *blockRadio;
@property (strong, nonatomic) NSPopUpButton *languageButton;
/// Whether a fenced block was asked for, rather than backticks in the line.
@property (readonly, nonatomic) BOOL usesBlock;
/// The chosen language as it is written after the fence; empty for none.
@property (readonly, nonatomic) NSString *language;
@end


@implementation MPCodeAccessory

- (instancetype)initWithBlock:(BOOL)block language:(NSString *)language
{
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, 380.0, 74.0)];
    if (!self)
        return nil;

    NSTextField *kind = [NSTextField labelWithString:
        NSLocalizedString(@"Code:", @"Code sheet")];
    kind.alignment = NSTextAlignmentRight;
    kind.frame = NSMakeRect(0.0, 53.0, 78.0, 18.0);
    [self addSubview:kind];

    _inlineRadio = [NSButton radioButtonWithTitle:
        NSLocalizedString(@"Inside the line", @"Code sheet")
                                           target:self
                                           action:@selector(kindChanged:)];
    _inlineRadio.frame = NSMakeRect(84.0, 51.0, 280.0, 20.0);
    [self addSubview:_inlineRadio];

    _blockRadio = [NSButton radioButtonWithTitle:
        NSLocalizedString(@"A block, highlighted as:", @"Code sheet")
                                          target:self
                                          action:@selector(kindChanged:)];
    _blockRadio.frame = NSMakeRect(84.0, 29.0, 280.0, 20.0);
    [self addSubview:_blockRadio];

    _inlineRadio.state = block ? NSControlStateValueOff
                               : NSControlStateValueOn;
    _blockRadio.state = block ? NSControlStateValueOn
                              : NSControlStateValueOff;

    _languageButton = [[NSPopUpButton alloc]
        initWithFrame:NSMakeRect(102.0, 2.0, 262.0, 25.0) pullsDown:NO];
    [self fillLanguageButtonSelecting:language];
    [self addSubview:_languageButton];

    [self kindChanged:nil];
    return self;
}

/** The languages this build can highlight, the common ones above a line.
 *
 * "None" first, because a fence with no language is still the right answer
 * for a shell transcript or a piece of output, and it is what the plain
 * button used to give.
 */
- (void)fillLanguageButtonSelecting:(NSString *)language
{
    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *none = [[NSMenuItem alloc] init];
    none.title = NSLocalizedString(@"No language", @"Code sheet");
    none.representedObject = @"";
    [menu addItem:none];
    [menu addItem:[NSMenuItem separatorItem]];

    BOOL separated = NO;
    for (MPCodeLanguage *found in MPAvailableCodeLanguages())
    {
        if (!found.isCommon && !separated)
        {
            [menu addItem:[NSMenuItem separatorItem]];
            separated = YES;
        }
        NSMenuItem *item = [[NSMenuItem alloc] init];
        item.title = found.title;
        item.representedObject = found.identifier;
        [menu addItem:item];
    }
    self.languageButton.menu = menu;

    for (NSMenuItem *item in menu.itemArray)
    {
        if (![item.representedObject isEqualToString:language ?: @""])
            continue;
        [self.languageButton selectItem:item];
        break;
    }
}

- (void)kindChanged:(id)sender
{
    // A language only means something to a block: there is no way to mark
    // one on backticks inside a sentence.
    self.languageButton.enabled = self.usesBlock;
}

- (BOOL)usesBlock
{
    return self.blockRadio.state == NSControlStateValueOn;
}

- (NSString *)language
{
    NSString *identifier = self.languageButton.selectedItem.representedObject;
    return [identifier isKindOfClass:[NSString class]] ? identifier : @"";
}

@end


@implementation MPDocument

#pragma mark - Talking to the page

/** Scrolls the preview to a position in CSS pixels.
 *
 * The counterpart of reading it, which arrives on its own through the
 * scroll reporter rather than being asked for: there is no scroll view here
 * to set a bounds origin on.
 */
- (void)setPreviewScrollTopTo:(CGFloat)top
{
    if (!self.preview)
        return;
    NSString *js = [NSString stringWithFormat:
        @"window.scrollTo(0, %.2f);", top];

    [self.preview evaluateJavaScript:js completionHandler:nil];
    self.previewScrollTop = top;
}

/** Puts the editor where the preview is, from the block at the top of it.
 *
 * The other direction interpolates between headings, because that is all it
 * has. This one has the offset each block was rendered from, so it can put
 * the editor on the same words rather than at the same fraction of a
 * different height — and the fraction of the way down that block is carried
 * across too, so a long paragraph scrolls smoothly rather than in jumps.
 */
- (void)scrollEditorToPreviewBlock:(NSDictionary *)block
{
    if (![block isKindOfClass:[NSDictionary class]])
        return;

    NSScrollView *scrollView = self.editor.enclosingScrollView;
    NSLayoutManager *manager = self.editor.layoutManager;
    NSTextContainer *container = self.editor.textContainer;
    if (!scrollView || !manager || !container)
        return;

    NSString *text = self.editor.string ?: @"";
    NSInteger srcByte = [block[@"src"] integerValue];
    NSInteger nextByte = [block[@"next"] integerValue];
    if (srcByte < 0)
        return;

    NSUInteger begin = MPCharacterIndexForUTF8ByteOffset(text,
                                                         (NSUInteger)srcByte);
    NSUInteger end = nextByte < 0 ? text.length
        : MPCharacterIndexForUTF8ByteOffset(text, (NSUInteger)nextByte);
    if (begin > text.length)
        return;

    CGFloat top = [self editorTopForCharacterIndex:begin];
    if (end > begin && end <= text.length)
    {
        CGFloat next = [self editorTopForCharacterIndex:end];
        double within = [block[@"within"] doubleValue];
        top += (next - top) * MAX(0.0, MIN(1.0, within));
    }

    NSClipView *clip = scrollView.contentView;
    CGFloat lowest = MAX(0.0, NSHeight(scrollView.documentView.bounds)
                              - NSHeight(clip.bounds));
    top = MAX(0.0, MIN(top, lowest));
    if (fabs(top - NSMinY(clip.bounds)) < 1.0)
        return;

    // No flag around this: the bounds change it causes arrives later, and
    // -editorBoundsDidChange: turns it away by seeing that the preview is
    // the side being driven.
    [clip scrollToPoint:NSMakePoint(NSMinX(clip.bounds), top)];
    [scrollView reflectScrolledClipView:clip];
}

/** Puts the preview where the editor is, by the offset at the top of it.
 *
 * The mirror of the other direction, and on the same data. What it replaces
 * interpolated between the nearest headings above and below, which is as
 * close as the editor alone can get — and on a document of long tables the
 * two panes ended a whole section apart, because a table that is four lines
 * of source and twelve lines of editor is one compact block in the preview.
 *
 * Returns NO when the page has no blocks to go by, so the caller can fall
 * back to the old way.
 */
- (BOOL)scrollPreviewToEditorTop
{
    NSClipView *clip = self.editor.enclosingScrollView.contentView;
    NSLayoutManager *manager = self.editor.layoutManager;
    NSTextContainer *container = self.editor.textContainer;
    NSString *text = self.editor.string ?: @"";
    if (!clip || !manager || !container || !text.length || !self.isPreviewReady)
        return NO;

    CGFloat y = NSMinY(clip.bounds) - self.editor.textContainerInset.height;
    NSUInteger glyph = [manager glyphIndexForPoint:NSMakePoint(0, MAX(0.0, y))
                                   inTextContainer:container];
    NSUInteger character = [manager characterIndexForGlyphAtIndex:glyph];
    if (character > text.length)
        return NO;

    NSUInteger byte = MPUTF8ByteOffsetForCharacterIndex(text, character);
    NSString *js = [NSString stringWithFormat:
        @"if (window.MacDownScrollToSource) MacDownScrollToSource(%lu);",
        (unsigned long)byte];
    [self.preview evaluateJavaScript:js completionHandler:nil];
    return YES;
}

/// Where in the editor's document a character sits, top of its line.
- (CGFloat)editorTopForCharacterIndex:(NSUInteger)index
{
    NSLayoutManager *manager = self.editor.layoutManager;
    NSTextContainer *container = self.editor.textContainer;
    NSUInteger length = self.editor.string.length;
    if (!length)
        return 0.0;

    NSRange glyphs = [manager glyphRangeForCharacterRange:
        NSMakeRange(MIN(index, length ? length - 1 : 0), 1)
                                     actualCharacterRange:NULL];
    NSRect rect = [manager boundingRectForGlyphRange:glyphs
                                     inTextContainer:container];
    return rect.origin.y + self.editor.textContainerInset.height;
}

/** Loads rendered markup into the preview.
 *
 * Not -loadHTMLString:baseURL:, which would be the obvious call: a page
 * loaded that way has an opaque origin, and WebKit2 then refuses every
 * local subresource it asks for. The stylesheet lives in Application
 * Support, the scripts in the bundle and the images beside the document,
 * so that leaves nothing but unstyled text.
 *
 * Writing the markup to a file and loading it as a file grants read access
 * explicitly. A <base> keeps relative paths in the document — an image next
 * to it — resolving against the document rather than against the temporary
 * file.
 */
- (void)loadPreviewHTML:(NSString *)html baseURL:(NSURL *)baseUrl
{
    NSURL *directory = self.previewScratchDirectory;
    if (!directory)
    {
        // Nowhere to write: better an unstyled preview than none.
        [self.preview loadHTMLString:html baseURL:baseUrl];
        return;
    }

    // A <base> so that a relative path in the document — an image beside it
    // — resolves against the document rather than against the file this is
    // written to.
    NSString *directoryPath = baseUrl.isFileURL
        ? baseUrl.path.stringByDeletingLastPathComponent : nil;
    if (directoryPath.length)
    {
        NSURL *base = MPPreviewURLForPath(directoryPath);
        // The trailing slash goes on here, after the URL is built, because
        // standardising a path takes it off — and without it the browser
        // reads the last component as a file rather than a folder, so an
        // image beside the document is looked for one directory above it.
        NSString *href = base.absoluteString;
        if (![href hasSuffix:@"/"])
            href = [href stringByAppendingString:@"/"];
        NSString *tag = [NSString stringWithFormat:@"<base href=\"%@\">",
                         href];
        NSRange head = [html rangeOfString:@"<head>"];
        if (head.location != NSNotFound)
        {
            html = [html stringByReplacingCharactersInRange:head
                withString:[@"<head>" stringByAppendingString:tag]];
        }
    }

    NSURL *file = [directory URLByAppendingPathComponent:@"preview.html"];
    if (![html writeToURL:file atomically:YES
                 encoding:NSUTF8StringEncoding error:NULL])
    {
        [self.preview loadHTMLString:html baseURL:baseUrl];
        return;
    }

    NSURL *served = MPPreviewURLForPath(file.path);
    [self.preview loadRequest:[NSURLRequest requestWithURL:served]];
}

/** A per-document directory for the file the preview is loaded from. */
- (NSURL *)previewScratchDirectory
{
    if (_previewScratchDirectory)
        return _previewScratchDirectory;

    NSString *name = [NSString stringWithFormat:@"MacDownPreview-%@",
                      [[NSUUID UUID] UUIDString]];
    NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
                  URLByAppendingPathComponent:name isDirectory:YES];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error])
        return nil;

    _previewScratchDirectory = url;
    return url;
}

/** Asks the page for the diagrams it has drawn.
 *
 * Kept here so that exporting stays synchronous: a save panel hands back a
 * URL and the file is written on the spot, with no opportunity to wait for
 * another process to answer.
 */
- (void)harvestDiagramsFromPreview
{
    static NSString * const script =
        @"(function(){var out=[];"
        // Containers rather than drawings. A diagram whose source does not
        // parse leaves a container with no svg in it, and skipping those
        // shifts every later diagram onto the wrong fence — or, since the
        // counts then disagree, throws away every diagram in the document.
        // An empty string holds the place instead.
        @"var nodes=document.querySelectorAll('.macdown-diagram');"
        @"for(var i=0;i<nodes.length;i++){"
        @"var g=nodes[i].querySelector('svg');"
        @"if(!g){out.push('');continue;}"
        @"var c=g.cloneNode(true);"
        @"c.removeAttribute('width');c.removeAttribute('height');"
        @"c.style.width='';c.style.height='';c.style.maxWidth='100%';"
        @"out.push(c.outerHTML);}"
        // MathJax draws with currentColor, which is inherited. Detached from
        // the page for rasterising there is nothing to inherit from, and the
        // formula would come out invisible.
        @"var maths=[];"
        @"var m=document.querySelectorAll('mjx-container');"
        @"for(var j=0;j<m.length;j++){"
        @"var svg=m[j].querySelector('svg');"
        @"if(!svg)continue;"
        @"var k=svg.cloneNode(true);"
        @"k.setAttribute('color','#000000');"
        @"k.style.color='#000000';"
        // MathJax sizes its output in ex, which rasterises to a formula a
        // few pixels wide. The page knows what it actually drew.
        @"var r=svg.getBoundingClientRect();"
        @"if(r.width>0&&r.height>0){"
        @"k.setAttribute('width',Math.ceil(r.width));"
        @"k.setAttribute('height',Math.ceil(r.height));"
        @"k.style.width='';k.style.height='';}"
        @"maths.push({svg:k.outerHTML,"
        @"display:m[j].getAttribute('display')==='true'});}"
        @"try{window.webkit.messageHandlers.macdownDiagrams"
        @".postMessage({diagrams:out,formulas:maths});}catch(e){}"
        @"return out.length;})";

    // Installed as a function rather than run once, because it has to run
    // again later: MathJax typesets after the page has finished loading, so
    // a single pass here finds the diagrams and no formulas at all.
    NSString *install = [NSString stringWithFormat:
        @"window.MacDownHarvest = %@; MacDownHarvest();"
        @"if (window.MathJax && MathJax.startup && MathJax.startup.promise)"
        @" MathJax.startup.promise.then(function(){MacDownHarvest();});",
        script];
    [self.preview evaluateJavaScript:install completionHandler:nil];
}

/** Reads the body background out of the page, for the divider.
 *
 * Asked for once per load and kept, because the answer only changes when the
 * stylesheet does and the question now costs a round trip to another
 * process.
 */
- (void)refreshPreviewBackgroundColor
{
    if (!self.preview)
        return;
    NSString *js = @"getComputedStyle(document.body).backgroundColor";
    __weak MPDocument *weakSelf = self;
    [self.preview evaluateJavaScript:js completionHandler:
        ^(id result, NSError *error) {
        NSString *value = [result isKindOfClass:[NSString class]]
            ? result : nil;
        weakSelf.previewBackgroundColor = value.length
            ? [NSColor colorWithHTMLName:value] : nil;
        [weakSelf redrawDivider];
    }];
}

#pragma mark - Accessor

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (NSString *)markdown
{
    return self.editor.string;
}

- (void)setMarkdown:(NSString *)markdown
{
    self.editor.string = markdown;
}

- (NSString *)html
{
    return self.renderer.currentHtml;
}

- (BOOL)toolbarVisible
{
    return self.windowForSheet.toolbar.visible;
}

- (BOOL)previewVisible
{
    return (self.preview.frame.size.width != 0.0);
}

- (BOOL)editorVisible
{
    return (self.editorContainer.frame.size.width != 0.0);
}

- (BOOL)needsHtml
{
    if (self.preferences.markdownManualRender)
        return NO;
    return (self.previewVisible || self.preferences.editorShowWordCount);
}

- (void)setTotalWords:(NSUInteger)value
{
    _totalWords = value;
    NSString *key = NSLocalizedString(@"WORDS_PLURAL_STRING", @"");
    NSInteger rule = kJJPluralFormRule.integerValue;
    self.wordsMenuItem.title =
        [JJPluralForm pluralStringForNumber:value withPluralForms:key
                            usingPluralRule:rule localizeNumeral:NO];

    // Made of the same number, so it is right whenever that one is.
    NSUInteger minutes = MPReadingMinutesForWords(value);
    self.readingTimeMenuItem.title = minutes
        ? [NSString stringWithFormat:NSLocalizedString(
              @"%lu min read", @"Reading time in the counter"),
           (unsigned long)minutes]
        : NSLocalizedString(@"nothing to read",
                            @"Reading time of an empty document");
}

- (void)setTotalCharacters:(NSUInteger)value
{
    _totalCharacters = value;
    NSString *key = NSLocalizedString(@"CHARACTERS_PLURAL_STRING", @"");
    NSInteger rule = kJJPluralFormRule.integerValue;
    self.charMenuItem.title =
        [JJPluralForm pluralStringForNumber:value withPluralForms:key
                            usingPluralRule:rule localizeNumeral:NO];
}

- (void)setTotalCharactersNoSpaces:(NSUInteger)value
{
    _totalCharactersNoSpaces = value;
    NSString *key = NSLocalizedString(@"CHARACTERS_NO_SPACES_PLURAL_STRING",
                                      @"");
    NSInteger rule = kJJPluralFormRule.integerValue;
    self.charNoSpacesMenuItem.title =
        [JJPluralForm pluralStringForNumber:value withPluralForms:key
                            usingPluralRule:rule localizeNumeral:NO];
}

- (void)setAutosaveName:(NSString *)autosaveName
{
    _autosaveName = autosaveName;
    self.splitView.autosaveName = autosaveName;
}


#pragma mark - Override

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.isPreviewReady = NO;
    self.shouldHandleBoundsChange = YES;
    self.previousSplitRatio = -1.0;
    
    return self;
}

- (NSString *)windowNibName
{
    return @"MPDocument";
}

/** Names the page uses to talk back to us. */
static NSString * const kMPScrollMessage = @"macdownScroll";

/// How long the side the reader touched keeps the scrolling to itself.
static const NSTimeInterval kMPScrollHandover = 0.4;

/** How long after a keystroke the two panes stay where they are.
 *
 * Long enough to cover the gap between words, so a sentence is one quiet
 * stretch rather than a resync between every word.
 */
static const NSTimeInterval kMPTypingQuiet = 1.0;
static NSString * const kMPMathJaxMessage = @"macdownMathJax";
static NSString * const kMPDiagramsMessage = @"macdownDiagrams";
static NSString * const kMPSelectionMessage = @"macdownSelection";

/** Reports scrolling and the page's dimensions back to the document.
 *
 * WKWebView exposes no scroll view on macOS — the one on iOS has no
 * counterpart here — so the numbers the editor needs to stay in step have to
 * come from the page itself. Coalesced onto an animation frame: a scroll
 * fires far more often than there is any point answering, and every one of
 * these crosses out of the web process.
 */
static NSString * const kMPScrollReporterSource =
    @"(function(){"
    @"var pending=false;"
    // The block the top of the window is showing, and the one after it, so
    // that the editor can be put at the same place in the source rather than
    // at the same fraction of a different height.
    @"window.MacDownTopBlock=function(){"
    @"var all=document.querySelectorAll('[data-src]');"
    @"var y=window.scrollY,best=null,next=null;"
    @"for(var i=0;i<all.length;i++){"
    @"var r=all[i].getBoundingClientRect();"
    @"if(r.top+y<=y+1){best=all[i];next=all[i+1]||null;}else break;}"
    // At the very top nothing is above the fold; the first block is the
    // answer, and the editor goes to the top with it.
    @"if(!best){best=all[0];next=all[1]||null;}"
    @"if(!best)return null;"
    @"var b=best.getBoundingClientRect();"
    @"var top=b.top+y,h=Math.max(b.height,1);"
    @"return {src:parseInt(best.getAttribute('data-src'),10),"
    @"next:next?parseInt(next.getAttribute('data-src'),10):-1,"
    @"within:Math.max(0,Math.min(1,(y-top)/h))};};"
    // The other direction, on the same data: put the window on the block a
    // source offset came from, interpolating inside it the same way.
    @"window.MacDownScrollToSource=function(src){"
    @"var all=document.querySelectorAll('[data-src]');"
    @"var best=null,next=null;"
    @"for(var i=0;i<all.length;i++){"
    @"var v=parseInt(all[i].getAttribute('data-src'),10);"
    @"if(v<=src){best=all[i];next=all[i+1]||null;}else break;}"
    @"if(!best){window.scrollTo(0,0);return;}"
    @"var b=best.getBoundingClientRect();"
    @"var top=b.top+window.scrollY,h=Math.max(b.height,1);"
    @"var bs=parseInt(best.getAttribute('data-src'),10);"
    @"var ns=next?parseInt(next.getAttribute('data-src'),10):bs+1;"
    @"var f=ns>bs?Math.max(0,Math.min(1,(src-bs)/(ns-bs))):0;"
    @"window.scrollTo(0,top+f*h);};"
    @"function report(){"
    @"pending=false;"
    @"try{window.webkit.messageHandlers.macdownScroll.postMessage({"
    @"top:window.scrollY,"
    @"height:document.documentElement.scrollHeight,"
    @"viewport:window.innerHeight,"
    @"block:MacDownTopBlock()});}catch(e){}}"
    @"function schedule(){if(!pending){pending=true;"
    @"requestAnimationFrame(report);}}"
    @"window.addEventListener('scroll',schedule,{passive:true});"
    @"window.addEventListener('resize',schedule,{passive:true});"
    @"window.MacDownReportScroll=report;"
    @"schedule();"
    @"})();";

/* The script that keeps the two panes pointing at the same block, and
 * reports what was selected, lives in MPPreviewSelection: a page script
 * nobody can call from a test is a page script nobody has tried.
 */


- (WKWebView *)buildPreviewWebView
{
    WKWebViewConfiguration *configuration =
        [[WKWebViewConfiguration alloc] init];

    WKUserContentController *content = configuration.userContentController;
    [content addScriptMessageHandler:self name:kMPScrollMessage];
    [content addScriptMessageHandler:self name:kMPMathJaxMessage];
    [content addScriptMessageHandler:self name:kMPDiagramsMessage];
    [content addScriptMessageHandler:self name:kMPSelectionMessage];
    [content addScriptMessageHandler:self name:MPHoverMessageName];

    // At the end of the document, so the page it decorates exists, and in
    // every frame the preview will ever load rather than being re-injected
    // by hand after each render.
    WKUserScript *reporter = [[WKUserScript alloc]
        initWithSource:kMPScrollReporterSource
         injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
      forMainFrameOnly:YES];
    [content addUserScript:reporter];

    WKUserScript *selection = [[WKUserScript alloc]
        initWithSource:MPSelectionWatchScript()
         injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
      forMainFrameOnly:YES];
    [content addUserScript:selection];

    WKUserScript *hover = [[WKUserScript alloc]
        initWithSource:MPHoverWatchScript(MPHoverDelay)
         injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
      forMainFrameOnly:YES];
    [content addUserScript:hover];

    // Everything the preview loads comes through here. See
    // MPPreviewSchemeHandler for why it cannot simply be file://.
    self.previewSchemeHandler = [[MPPreviewSchemeHandler alloc] init];
    [configuration setURLSchemeHandler:self.previewSchemeHandler
                          forURLScheme:MPPreviewURLScheme];
    if (@available(macOS 10.15, *))
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;

    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSZeroRect
                                            configuration:configuration];
    webView.navigationDelegate = self;
    webView.UIDelegate = self;

    // The page paints its own background, dark or light. Left opaque, the
    // web view flashes white behind every load.
    if (@available(macOS 12.0, *))
        webView.underPageBackgroundColor = [NSColor clearColor];
    webView.allowsMagnification = NO;

    return webView;
}

/** Puts the preview inside the container the nib provides. */
- (void)installPreviewWebView
{
    NSView *container = self.previewContainer;
    if (!container)
        return;

    WKWebView *webView = [self buildPreviewWebView];
    webView.frame = container.bounds;
    webView.autoresizingMask =
        NSViewWidthSizable | NSViewHeightSizable;
    [container addSubview:webView];
    self.preview = webView;
}


- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
    [super windowControllerDidLoadNib:controller];

    [self installPreviewWebView];

    // Unified toolbar, but the content deliberately does NOT run underneath
    // it: no NSWindowStyleMaskFullSizeContentView here.
    //
    // This window shows two backdrops at once whose brightness is unrelated,
    // because the editor theme is picked independently of the system
    // appearance and is routinely dark while the preview is light. With the
    // content extending under the toolbar, items drawn without a background
    // of their own took a single glyph colour from the appearance and
    // disappeared over whichever half happened to match it. Keeping the
    // toolbar in its own titlebar area gives every item a predictable ground.
    NSWindow *window = controller.window;
    window.toolbarStyle = NSWindowToolbarStyleUnified;

    /* One window, one tab per open file.
     *
     * The system's own tabs rather than a bar of our own: they are the ones
     * with the keyboard shortcuts people already know, the overview on
     * ⇧⌘\, the drag between windows, and the behaviour Finder and Safari
     * have. A bar of our own would be a month of building the same thing
     * slightly differently.
     *
     * Preferred, not Automatic. Automatic follows the system setting for
     * whether documents open in tabs, which is "in full screen only" by
     * default — and this is a feature somebody asked for, not one to be
     * discovered by chance. One line to defer to the system again.
     *
     * All documents share the identifier, so any two of them can be tabs
     * of each other; the identifier is the only thing keeping unrelated
     * windows out of the group.
     */
    window.tabbingMode = NSWindowTabbingModePreferred;
    window.tabbingIdentifier = @"com.nicolorisitano82.macdown.document";

    [self installSidebarInWindow:window];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // All files use their absolute path to keep their window states.
    NSString *autosaveName = kMPDefaultAutosaveName;
    if (self.fileURL)
        autosaveName = self.fileURL.absoluteString;
    controller.window.frameAutosaveName = autosaveName;
    self.autosaveName = autosaveName;

    // Perform initial resizing manually because for some reason untitled
    // documents do not pick up the autosaved frame automatically in 10.10.
    NSString *rectString = MPRectStringForAutosaveName(autosaveName);
    if (!rectString)
        rectString = MPRectStringForAutosaveName(kMPDefaultAutosaveName);
    if (rectString)
        [controller.window setFrameFromString:rectString];

    self.highlighter =
        [[HGMarkdownHighlighter alloc] initWithTextView:self.editor
                                           waitInterval:0.0];

    // Rides on the highlighter's parse rather than running a second one:
    // the element list it caches is exactly the semantic model needed here.
    self.semanticStyler =
        [[MPSemanticStyler alloc] initWithTextView:self.editor];
    self.markerHider = [[MPMarkerHider alloc] initWithTextView:self.editor];
    self.editor.markerHider = self.markerHider;
    self.blockStyler = [[MPBlockStyler alloc] initWithTextView:self.editor];
    self.semanticStyler.themeStyles = self.highlighter.styles;
    __weak MPDocument *weakSelf = self;
    self.highlighter.elementsDidChange = ^(pmh_element **elements) {
        [weakSelf.semanticStyler applyToElements:elements];
        [weakSelf.markerHider updateWithElements:elements];
        [weakSelf.blockStyler applyToElements:elements];
    };
    self.renderer = [[MPRenderer alloc] init];
    self.renderer.dataSource = self;
    self.renderer.delegate = self;

    for (NSString *key in MPEditorPreferencesToObserve())
    {
        [defaults addObserver:self forKeyPath:key
                      options:NSKeyValueObservingOptionNew context:NULL];
    }
    for (NSString *key in MPEditorKeysToObserve())
    {
        [self.editor addObserver:self forKeyPath:key
                         options:NSKeyValueObservingOptionNew context:NULL];
    }

    self.editor.postsFrameChangedNotifications = YES;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(editorTextDidChange:)
                   name:NSTextDidChangeNotification object:self.editor];
    [center addObserver:self selector:@selector(userDefaultsDidChange:)
                   name:NSUserDefaultsDidChangeNotification
                 object:[NSUserDefaults standardUserDefaults]];
    [center addObserver:self selector:@selector(editorBoundsDidChange:)
                   name:NSViewBoundsDidChangeNotification
                 object:self.editor.enclosingScrollView.contentView];
    [center addObserver:self selector:@selector(editorFrameDidChange:)
                   name:NSViewFrameDidChangeNotification object:self.editor];
    [center addObserver:self selector:@selector(didRequestEditorReload:)
                   name:MPDidRequestEditorSetupNotification object:nil];
    [center addObserver:self selector:@selector(didRequestPreviewReload:)
                   name:MPDidRequestPreviewRenderNotification object:nil];
    [center addObserver:self selector:@selector(willStartLiveScroll:)
                   name:NSScrollViewWillStartLiveScrollNotification
                 object:self.editor.enclosingScrollView];
    [center addObserver:self selector:@selector(didEndLiveScroll:)
                   name:NSScrollViewDidEndLiveScrollNotification
                 object:self.editor.enclosingScrollView];

    self.needsToUnregister = YES;

    self.wordsMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL
                                             keyEquivalent:@""];
    self.charMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL
                                            keyEquivalent:@""];
    self.charNoSpacesMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                           action:NULL
                                                    keyEquivalent:@""];
    self.readingTimeMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                          action:NULL
                                                   keyEquivalent:@""];

    NSPopUpButton *wordCountWidget = self.wordCountWidget;
    [wordCountWidget removeAllItems];
    [wordCountWidget.menu addItem:self.wordsMenuItem];
    [wordCountWidget.menu addItem:self.charMenuItem];
    [wordCountWidget.menu addItem:self.charNoSpacesMenuItem];
    [wordCountWidget.menu addItem:self.readingTimeMenuItem];
    [wordCountWidget selectItemAtIndex:self.preferences.editorWordCountType];
    wordCountWidget.alphaValue = 0.9;
    wordCountWidget.hidden = !self.preferences.editorShowWordCount;
    wordCountWidget.enabled = NO;

    // These needs to be queued until after the window is shown, so that editor
    // can have the correct dimention for size-limiting and stuff. See
    // https://github.com/uranusjr/macdown/issues/236
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self setupEditor:nil];
        [self redrawDivider];
        [self reloadFromLoadedString];
    }];
}

- (void)reloadFromLoadedString
{
    if (self.loadedString && self.editor && self.renderer && self.highlighter)
    {
        self.editor.string = self.loadedString;
        self.loadedString = nil;
        [self.renderer parseAndRenderNow];
        [self.highlighter parseAndHighlightNow];

        // Setting the string is not an edit, so nothing else asks for these.
        // Without them a document that has just been opened reports having
        // nothing to flag, however much prose is in it, until the first
        // keystroke.
        [self.editor updateProseHighlights];
        [self updateProseSummary];
    }
}

- (void)close
{
    if (self.needsToUnregister) 
    {
        // Close can be called multiple times, but this can only be done once.
        // http://www.cocoabuilder.com/archive/cocoa/240166-nsdocument-close-method-calls-itself.html
        self.needsToUnregister = NO;

        // Need to cleanup these so that callbacks won't crash the app.
        [self.highlighter deactivate];
        self.highlighter.targetTextView = nil;
        self.highlighter = nil;
        self.renderer = nil;
        if (_previewScratchDirectory)
        {
            [[NSFileManager defaultManager]
                removeItemAtURL:_previewScratchDirectory error:NULL];
            _previewScratchDirectory = nil;
        }
        self.preview.navigationDelegate = nil;
        self.preview.UIDelegate = nil;
        [self.preview.configuration.userContentController
            removeAllScriptMessageHandlers];

        [[NSNotificationCenter defaultCenter] removeObserver:self];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        for (NSString *key in MPEditorPreferencesToObserve())
            [defaults removeObserver:self forKeyPath:key];
        for (NSString *key in MPEditorKeysToObserve())
            [self.editor removeObserver:self forKeyPath:key];
    }

    [super close];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

+ (NSArray *)writableTypes
{
    return @[@"net.daringfireball.markdown"];
}

- (BOOL)isDocumentEdited
{
    // Prevent save dialog on an unnamed, empty document. The file will still
    // show as modified (because it is), but no save dialog will be presented
    // when the user closes it.
    if (!self.presentedItemURL && !self.editor.string.length)
        return NO;
    return [super isDocumentEdited];
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName
             error:(NSError *__autoreleasing *)outError
{
    if (self.preferences.editorEnsuresNewlineAtEndOfFile)
    {
        NSCharacterSet *newline = [NSCharacterSet newlineCharacterSet];
        NSString *text = self.editor.string;
        NSUInteger end = text.length;
        if (end && ![newline characterIsMember:[text characterAtIndex:end - 1]])
        {
            NSRange selection = self.editor.selectedRange;
            [self.editor insertText:@"\n" replacementRange:NSMakeRange(end, 0)];
            self.editor.selectedRange = selection;
        }
    }
    return [super writeToURL:url ofType:typeName error:outError];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    return [self.editor.string dataUsingEncoding:NSUTF8StringEncoding];
}

/** What to call this document.
 *
 * A document opened out of a textbundle is a file called `text.markdown`
 * inside a folder called something the reader chose. Showing the folder's
 * name is the only honest answer: it is the thing they opened, the thing
 * they will look for again, and the thing every other application shows.
 */
- (NSString *)displayName
{
    NSURL *folder = self.fileURL.URLByDeletingLastPathComponent;
    if (MPIsTextBundle(folder))
        return folder.lastPathComponent.stringByDeletingPathExtension;
    return [super displayName];
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName
               error:(NSError **)outError
{
    NSString *content = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    if (!content)
        return NO;

    self.loadedString = content;
    [self reloadFromLoadedString];
    return YES;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    savePanel.extensionHidden = NO;
    if (self.fileURL && self.fileURL.isFileURL)
    {
        NSString *path = self.fileURL.path;

        // Use path of parent directory if this is a file. Otherwise this is it.
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path
                                                           isDirectory:&isDir];
        if (!exists || !isDir)
            path = [path stringByDeletingLastPathComponent];

        savePanel.directoryURL = [NSURL fileURLWithPath:path];
    }
    else
    {
        // Suggest a file name for new documents.
        NSString *fileName = self.presumedFileName;
        if (fileName && ![fileName hasExtension:@"md"])
        {
            fileName = [fileName stringByAppendingPathExtension:@"md"];
            savePanel.nameFieldStringValue = fileName;
        }
    }
    
    // Get supported extensions from plist
    static NSMutableArray *supportedExtensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportedExtensions = [NSMutableArray array];
        NSDictionary *infoDict = [NSBundle mainBundle].infoDictionary;
        for (NSDictionary *docType in infoDict[@"CFBundleDocumentTypes"])
        {
            NSArray *exts = docType[@"CFBundleTypeExtensions"];
            if (exts.count)
            {
                [supportedExtensions addObjectsFromArray:exts];
            }
        }
    });
    
    savePanel.allowedFileTypes = supportedExtensions;
    savePanel.allowsOtherFileTypes = YES; // Allow all extensions.
    
    return [super prepareSavePanel:savePanel];
}

- (NSPrintInfo *)printInfo
{
    NSPrintInfo *info = [super printInfo];
    if (!info)
        info = [[NSPrintInfo sharedPrintInfo] copy];
    info.horizontalPagination = NSAutoPagination;
    info.verticalPagination = NSAutoPagination;
    info.verticallyCentered = NO;
    info.topMargin = 50.0;
    info.leftMargin = 0.0;
    info.rightMargin = 0.0;
    info.bottomMargin = 50.0;
    return info;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings
                                           error:(NSError *__autoreleasing *)e
{
    NSPrintInfo *info = [self.printInfo copy];
    [info.dictionary addEntriesFromDictionary:printSettings];

    // WKWebView prints itself; the frame view this used to reach for has no
    // counterpart, and does not need one.
    return [self.preview printOperationWithPrintInfo:info];
}

- (void)printDocumentWithSettings:(NSDictionary *)printSettings
                   showPrintPanel:(BOOL)showPrintPanel delegate:(id)delegate
                 didPrintSelector:(SEL)selector contextInfo:(void *)contextInfo
{
    self.printing = YES;
    NSInvocation *invocation = nil;
    if (delegate && selector)
    {
        NSMethodSignature *signature =
            [NSMethodSignature methodSignatureForSelector:selector];
        invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = delegate;
        if (contextInfo)
            [invocation setArgument:&contextInfo atIndex:2];
    }
    [super printDocumentWithSettings:printSettings
                      showPrintPanel:showPrintPanel delegate:self
                    didPrintSelector:@selector(document:didPrint:context:)
                         contextInfo:(void *)invocation];
}

/// The writing commands, for validation: all of them want the same things.
NS_INLINE BOOL MPIsWritingCommandAction(SEL action)
{
    return action == @selector(improveWriting:)
        || action == @selector(correctWriting:)
        || action == @selector(makeWritingFormal:)
        || action == @selector(makeWritingPlain:)
        || action == @selector(makeWritingShorter:)
        || action == @selector(makeWritingLonger:);
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    BOOL result = [super validateUserInterfaceItem:item];
    SEL action = item.action;

    if (MPIsWritingCommandAction(action))
    {
        // Switched off, and they are not offered at all.
        if (!self.preferences.editorWritingHelp)
            return NO;
        // Something to work on, a model to work with, and not already busy.
        NSRange range =
            [MPWritingAssistant rangeForCommandInTextView:self.editor];
        return range.location != NSNotFound && range.length > 0
            && [MPModelStore sharedStore].selectedModel != nil
            && !self.writingAssistant.isWorking;
    }
    if (action == @selector(linkToNewMarkdownFile:))
        return self.fileURL != nil && self.editor.selectedRange.length > 0;

    // The count comes from the tally, which is worked out when the text
    // changes: running the checker to decide whether a menu item is
    // enabled would run it every time a menu opens.
    if (action == @selector(showProseIssues:))
    {
        return self.editor.proseHighlightsEnabled
            && self.proseIssueCount > 0;
    }

    // Nowhere to look until the document has a folder to be in.
    if (action == @selector(showBacklinks:))
        return self.fileURL != nil;

    // Nothing to offer unless the caret is in a list with something to
    // move: a command that does nothing when pressed teaches you to stop
    // pressing it.
    if (action == @selector(moveDoneTasksToEnd:))
    {
        if (self.readOnly)
            return NO;
        NSRange where = NSMakeRange(NSNotFound, 0);
        return MPTasksMovedToEnd(self.editor.string ?: @"",
            self.editor.selectedRange.location, &where) != nil;
    }

    if (action == @selector(toggleFocusMode:)
            || action == @selector(toggleTypewriterScrolling:))
    {
        if ([(id)item isKindOfClass:[NSMenuItem class]])
        {
            BOOL on = (action == @selector(toggleFocusMode:))
                ? self.preferences.editorFocusMode
                : self.preferences.editorTypewriter;
            ((NSMenuItem *)item).state = on ? NSControlStateValueOn
                                            : NSControlStateValueOff;
        }
        return YES;
    }

    if (action == @selector(toggleReadOnly:))
    {
        // The protocol says nothing about being an object one can ask.
        if ([(id)item isKindOfClass:[NSMenuItem class]])
        {
            ((NSMenuItem *)item).state = self.readOnly
                ? NSControlStateValueOn : NSControlStateValueOff;
        }
        return YES;
    }
    // What edits is refused while the document is being read. The text view
    // refuses what is typed; this refuses what is commanded.
    if (self.readOnly && MPActionEditsTheDocument(action))
        return NO;

    if (action == @selector(stopWritingHelp:))
    {
        return self.preferences.editorWritingHelp
            && self.writingAssistant.isWorking;
    }

    if (action == @selector(toggleToolbar:))
    {
        NSMenuItem *it = ((NSMenuItem *)item);
        it.title = self.toolbarVisible ?
            NSLocalizedString(@"Hide Toolbar",
                              @"Toggle reveal toolbar") :
            NSLocalizedString(@"Show Toolbar",
                              @"Toggle reveal toolbar");
    }
    else if (action == @selector(togglePreviewPane:))
    {
        NSMenuItem *it = ((NSMenuItem *)item);
        it.hidden = (!self.previewVisible && self.previousSplitRatio < 0.0);
        it.title = self.previewVisible ?
            NSLocalizedString(@"Hide Preview Pane",
                              @"Toggle preview pane menu item") :
            NSLocalizedString(@"Restore Preview Pane",
                              @"Toggle preview pane menu item");

    }
    else if (action == @selector(toggleEditorPane:))
    {
        NSMenuItem *it = (NSMenuItem*)item;
        it.title = self.editorVisible ?
        NSLocalizedString(@"Hide Editor Pane",
                          @"Toggle editor pane menu item") :
        NSLocalizedString(@"Restore Editor Pane",
                          @"Toggle editor pane menu item");
    }
    else if (action == @selector(toggleSidebar:))
    {
        NSMenuItem *it = (NSMenuItem *)item;
        it.title = self.sidebarVisible ?
            NSLocalizedString(@"Hide Sidebar", @"Toggle sidebar menu item") :
            NSLocalizedString(@"Show Sidebar", @"Toggle sidebar menu item");
    }
    else if (action == @selector(toggleProseHighlights:))
    {
        // A tick rather than a second wording: the command reads the same
        // either way, and what is missing is whether it is on.
        NSMenuItem *it = (NSMenuItem *)item;
        it.state = self.editor.proseHighlightsEnabled
            ? NSControlStateValueOn : NSControlStateValueOff;
    }
    return result;
}


#pragma mark - NSSplitViewDelegate

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    [self redrawDivider];
    self.editor.editable = self.editorVisible;
}


#pragma mark - NSTextViewDelegate

/** Tells the preview where the reader is.
 *
 * Only the offset goes across: which block that lands in is worked out in
 * the page, where the blocks and their offsets already are, rather than
 * duplicated on this side.
 */
- (void)textViewDidChangeSelection:(NSNotification *)notification
{
    [self.markerHider selectionDidChange];
    [self.editor updateWritingAids];
    if (notification.object != self.editor)
        return;
    [self markPreviewAtSelection];
}

- (void)markPreviewAtSelection
{
    // In bytes, because that is what the blocks in the page are labelled
    // with. The caret's own index counts UTF-16 units, and the two are the
    // same number only while the document stays ASCII.
    NSUInteger offset = MPUTF8ByteOffsetForCharacterIndex(
        self.editor.string ?: @"", self.editor.selectedRange.location);
    NSString *js = [NSString stringWithFormat:
        @"if (window.MacDownMarkHere) MacDownMarkHere(%lu);",
        (unsigned long)offset];
    [self.preview evaluateJavaScript:js completionHandler:nil];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertTab:))
        return ![self textViewShouldInsertTab:textView];
    else if (commandSelector == @selector(insertBacktab:))
        return ![self textViewShouldInsertBacktab:textView];
    else if (commandSelector == @selector(insertNewline:))
        return ![self textViewShouldInsertNewline:textView];
    else if (commandSelector == @selector(deleteBackward:))
        return ![self textViewShouldDeleteBackward:textView];
    else if (commandSelector == @selector(moveToLeftEndOfLine:))
        return ![self textViewShouldMoveToLeftEndOfLine:textView];
    return NO;
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range
                                              replacementString:(NSString *)str
{
    // Ignore if this originates from an IM marked text commit event.
    if (NSIntersectionRange(textView.markedRange, range).length)
        return YES;

    if (self.preferences.editorCompleteMatchingCharacters)
    {
        BOOL strikethrough = self.preferences.extensionStrikethough;
        if ([textView completeMatchingCharactersForTextInRange:range
                                                    withString:str
                                          strikethroughEnabled:strikethrough])
            return NO;
    }
    
	// For every change, set the typing attributes
	if (range.location > 0) {
		NSRange prevRange = range;
		prevRange.location -= 1;
		prevRange.length = 1;

		NSDictionary *attr = [[textView attributedString] fontAttributesInRange:prevRange];
		[textView setTypingAttributes:attr];
	}

    return YES;
}

#pragma mark - Fake NSTextViewDelegate

- (BOOL)textViewShouldInsertTab:(NSTextView *)textView
{
    if (textView.selectedRange.length != 0)
    {
        [self indent:nil];
        return NO;
    }
    else if (self.preferences.editorConvertTabs)
    {
        [textView insertSpacesForTab];
        return NO;
    }
    return YES;
}

- (BOOL)textViewShouldInsertBacktab:(NSTextView *)textView
{
    [self unindent:nil];
    return NO;
}

- (BOOL)textViewShouldInsertNewline:(NSTextView *)textView
{
    if ([textView insertMappedContent])
        return NO;

    BOOL inserts = self.preferences.editorInsertPrefixInBlock;
    if (inserts && [textView completeNextListItem:
            self.preferences.editorAutoIncrementNumberedLists])
        return NO;
    if (inserts && [textView completeNextBlockquoteLine])
        return NO;
    if ([textView completeNextIndentedLine])
        return NO;
    return YES;
}

- (BOOL)textViewShouldDeleteBackward:(NSTextView *)textView
{
    NSRange selectedRange = textView.selectedRange;
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        NSUInteger location = selectedRange.location;
        if ([textView deleteMatchingCharactersAround:location])
            return NO;
    }
    if (self.preferences.editorConvertTabs && !selectedRange.length)
    {
        NSUInteger location = selectedRange.location;
        if ([textView unindentForSpacesBefore:location])
            return NO;
    }
    return YES;
}

- (BOOL)textViewShouldMoveToLeftEndOfLine:(NSTextView *)textView
{
    if (!self.preferences.editorSmartHome)
        return YES;
    NSUInteger cur = textView.selectedRange.location;
    NSUInteger location =
        [textView.string locationOfFirstNonWhitespaceCharacterInLineBefore:cur];
    if (location == cur || cur == 0)
        return YES;
    else if (cur >= textView.string.length)
        cur = textView.string.length - 1;

    // We don't want to jump rows when the line is wrapped. (#103)
    // If the line is wrapped, the target will be higher than the current glyph.
    NSLayoutManager *manager = textView.layoutManager;
    NSTextContainer *container = textView.textContainer;
    NSRect targetRect =
        [manager boundingRectForGlyphRange:NSMakeRange(location, 1)
                           inTextContainer:container];
    NSRect currentRect =
        [manager boundingRectForGlyphRange:NSMakeRange(cur, 1)
                           inTextContainer:container];
    if (targetRect.origin.y != currentRect.origin.y)
        return YES;

    textView.selectedRange = NSMakeRange(location, 0);
    return NO;
}


#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    didCommitNavigation:(WKNavigation *)navigation
{
    // The flush-window dance that used to live here is gone: the methods it
    // called have been no-ops since the window server stopped working that
    // way, and WKWebView draws in another process regardless.
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation
{
    // Always, MathJax or not. This used to be left to a callback from
    // MathJax's own startup when maths was enabled, which meant the scroll
    // position stayed unsynced if that callback never arrived. MathJax still
    // calls in when it has finished, as a second pass once the equations have
    // changed the layout.
    id callback = MPGetPreviewLoadingCompletionHandler(self);
    [[NSOperationQueue mainQueue] addOperationWithBlock:callback];

    self.isPreviewReady = YES;

    if (self.preferences.editorShowWordCount)
        [self updateWordCount];

    self.alreadyRenderingInWeb = NO;

    if (self.renderToWebPending)
        [self.renderer parseAndRenderNow];

    self.renderToWebPending = NO;
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self webView:webView didFinishNavigation:navigation];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error
{
    [self webView:webView didFinishNavigation:navigation];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:
        (void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;

    if (navigationAction.navigationType == WKNavigationTypeLinkActivated)
    {
        // The same page: a fragment jump, which the page can do itself.
        if ([self.currentBaseUrl isEqual:url])
        {
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        // Somewhere else: ours to open, not the preview's to navigate to.
        if (![self isCurrentBaseUrl:url])
        {
            decisionHandler(WKNavigationActionPolicyCancel);
            [self openOrCreateFileForUrl:url];
            return;
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}


#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:MPHoverMessageName])
    {
        NSDictionary *body = message.body;
        if (![body isKindOfClass:[NSDictionary class]])
            return;
        if ([body[@"away"] boolValue])
        {
            [self hideLinkPreview];
            return;
        }
        [self showLinkPreviewFor:body];
        return;
    }

    if ([message.name isEqualToString:kMPScrollMessage])
    {
        NSDictionary *body = message.body;
        if (![body isKindOfClass:[NSDictionary class]])
            return;

        self.previewScrollTop = [body[@"top"] doubleValue];
        self.lastPreviewScrollTop = self.previewScrollTop;
        self.previewContentHeight = [body[@"height"] doubleValue];
        self.previewViewportHeight = [body[@"viewport"] doubleValue];

        // A report caused by our own scrolling would send the editor after
        // the preview that the editor had just moved, and the two would
        // chase each other down the document.
        if (!self.preferences.editorSyncScrolling)
            return;
        // A report that arrived because the page was rebuilt under a
        // reader who is writing, not because they scrolled it.
        if (self.isTyping)
            return;
        // The editor is the one being driven: this report is the preview
        // arriving where the editor sent it.
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - self.editorDrivenAt < kMPScrollHandover)
            return;
        self.previewDrivenAt = now;
        [self scrollEditorToPreviewBlock:body[@"block"]];
        return;
    }

    if ([message.name isEqualToString:kMPDiagramsMessage])
    {
        NSDictionary *body = message.body;
        if ([body isKindOfClass:[NSDictionary class]])
        {
            self.harvestedDiagrams = body[@"diagrams"];
            self.harvestedFormulas = body[@"formulas"];
        }
        return;
    }

    if ([message.name isEqualToString:kMPSelectionMessage])
    {
        NSDictionary *body = message.body;
        if (![body isKindOfClass:[NSDictionary class]])
            return;

        NSInteger beginByte = [body[@"begin"] integerValue];
        NSInteger endByte = [body[@"end"] integerValue];
        if (beginByte < 0)
            return;

        // Back from bytes to the units the text view counts in, the same
        // conversion -markPreviewAtSelection makes in the other direction.
        NSString *text = self.editor.string ?: @"";
        NSUInteger length = self.editor.textStorage.length;
        NSUInteger begin = MPCharacterIndexForUTF8ByteOffset(
            text, (NSUInteger)beginByte);
        // The last block reports no end, since nothing follows it.
        NSUInteger end = endByte < 0 ? length
            : MPCharacterIndexForUTF8ByteOffset(text, (NSUInteger)endByte);
        if (begin > length || end > length || end <= begin)
            return;

        self.editor.activeSourceRange = NSMakeRange(begin, end - begin);

        // Text selected in the preview, once the gesture is over: the same
        // words are selected in the editor, so pressing delete removes
        // what the reader was looking at and typing replaces it.
        NSString *selected = body[@"text"];
        if ([body[@"done"] boolValue]
                && [selected isKindOfClass:[NSString class]]
                && selected.length
                && self.preferences.previewSelectionSelectsSource)
        {
            NSInteger reported = body[@"offset"]
                ? [body[@"offset"] integerValue] : -1;
            [self selectInEditor:selected
                       fromBlock:NSMakeRange(begin, end - begin)
                        rendered:reported < 0 ? NSNotFound
                                              : (NSUInteger)reported
                           focus:[body[@"focus"] boolValue]
                          delete:[body[@"action"]
                                     isEqualToString:@"delete"]];
            return;
        }

        // A click in a cell puts the caret in that cell. The block the
        // click landed in is the table row, so its offset and the cell's
        // position in the row are between them enough to find it.
        NSInteger column = [body[@"cell"] integerValue];
        if (column >= 0)
            [self moveCaretToColumn:(NSUInteger)column inTableRowAt:begin];
        return;
    }

    if ([message.name isEqualToString:kMPMathJaxMessage])
    {
        // MathJax has finished typesetting, and the layout has moved under
        // whatever was measured before it ran.
        MPGetPreviewLoadingCompletionHandler(self)();
        return;
    }
}


/** Selects, in the editor, the text somebody selected in the preview.
 *
 * The block it came from is the search window; MPPreviewSelection decides
 * what the rendered text corresponds to in the source, and says so or says
 * nothing. Nothing is what happens when it cannot tell: a selection placed
 * nearly right would have the next keystroke delete the wrong words.
 *
 * The focus follows the selection. That is the point of the whole thing —
 * the reader picked the words out of the preview in order to change them —
 * and it is why this waits for the end of the gesture.
 */
- (void)selectInEditor:(NSString *)selected fromBlock:(NSRange)block
              rendered:(NSUInteger)renderedOffset
                 focus:(BOOL)takeFocus
                delete:(BOOL)removeIt
{
    NSString *text = self.editor.string ?: @"";
    NSRange range = MPSourceRangeForPreviewText(text, selected, block,
                                                renderedOffset);
    if (range.location == NSNotFound
            || NSMaxRange(range) > self.editor.textStorage.length)
    {
        MPNote(@"  selection not placed: %lu characters",
               (unsigned long)selected.length);
        return;
    }

    self.editor.selectedRange = range;
    [self.editor scrollRangeToVisible:range];
    // The focus moves only when the gesture is over and the reader is
    // plainly finished with the page: a mouse released in it, or delete
    // pressed on what they had chosen. A selection still being extended
    // with the keyboard is followed, not taken over.
    if (takeFocus)
        [self.editor.window makeFirstResponder:self.editor];
    if (removeIt && [self.editor shouldChangeTextInRange:range
                                       replacementString:@""])
    {
        [self.editor.textStorage replaceCharactersInRange:range
                                               withString:@""];
        [self.editor didChangeText];
    }
    MPNote(@"selected from the preview: %lu characters at %lu%@%@",
           (unsigned long)range.length, (unsigned long)range.location,
           takeFocus ? @", with the focus" : @"",
           removeIt ? @", deleted" : @"");
}


/** Puts the caret in one cell of the table row that starts at `rowStart`.
 *
 * Where that cell is in the source is the table model's business; this
 * only takes the answer to the editor.
 */
- (void)moveCaretToColumn:(NSUInteger)column inTableRowAt:(NSUInteger)rowStart
{
    NSString *text = self.editor.string ?: @"";
    NSUInteger caret = [MPTableSource caretForColumn:column
                                             inRowAt:rowStart
                                              inText:text];
    if (caret == NSNotFound || caret > self.editor.textStorage.length)
        return;

    self.editor.selectedRange = NSMakeRange(caret, 0);
    [self.editor scrollRangeToVisible:NSMakeRange(caret, 0)];
    [self.editor.window makeFirstResponder:self.editor];
}


#pragma mark - MPRendererDataSource

- (BOOL)rendererLoading {
	return self.preview.loading;
}
    
- (NSString *)rendererMarkdown:(MPRenderer *)renderer
{
    return self.editor.string;
}

- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer
{
    NSString *n = self.fileURL.lastPathComponent.stringByDeletingPathExtension;
    return n ? n : @"";
}


#pragma mark - MPRendererDelegate

- (int)rendererExtensions:(MPRenderer *)renderer
{
    return self.preferences.extensionFlags;
}

- (BOOL)rendererHasSmartyPants:(MPRenderer *)renderer
{
    return self.preferences.extensionSmartyPants;
}

- (BOOL)rendererRendersTOC:(MPRenderer *)renderer
{
    return self.preferences.htmlRendersTOC;
}

- (NSString *)rendererStyleName:(MPRenderer *)renderer
{
    return self.preferences.htmlStyleName;
}

- (BOOL)rendererDetectsFrontMatter:(MPRenderer *)renderer
{
    return self.preferences.htmlDetectFrontMatter;
}

- (BOOL)rendererHasSyntaxHighlighting:(MPRenderer *)renderer
{
    return self.preferences.htmlSyntaxHighlighting;
}

- (BOOL)rendererHasMermaid:(MPRenderer *)renderer
{
    return self.preferences.htmlMermaid;
}

- (BOOL)rendererHasGraphviz:(MPRenderer *)renderer
{
    return self.preferences.htmlGraphviz;
}

- (MPCodeBlockAccessoryType)rendererCodeBlockAccesory:(MPRenderer *)renderer
{
    return self.preferences.htmlCodeBlockAccessory;
}

- (BOOL)rendererHasMathJax:(MPRenderer *)renderer
{
    return self.preferences.htmlMathJax;
}

- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer
{
    return self.preferences.htmlHighlightingThemeName;
}

/// The contents of <head>, or nil if the document is not shaped as expected.
NS_INLINE NSString *MPHeadOfHTML(NSString *html)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [[NSRegularExpression alloc] initWithPattern:
            @"<head[^>]*>([\\s\\S]*)</head>"
                    options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    NSTextCheckingResult *match =
        [regex firstMatchInString:html options:0
                            range:NSMakeRange(0, html.length)];
    if (!match)
        return nil;
    return [html substringWithRange:[match rangeAtIndex:1]];
}

/// The contents of <body>, or nil if the document is not shaped as expected.
NS_INLINE NSString *MPBodyOfHTML(NSString *html)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [[NSRegularExpression alloc] initWithPattern:
            @"<body[^>]*>([\\s\\S]*)</body>"
                    options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    NSTextCheckingResult *match =
        [regex firstMatchInString:html options:0
                            range:NSMakeRange(0, html.length)];
    if (!match)
        return nil;
    return [html substringWithRange:[match rangeAtIndex:1]];
}


/** Whether a WikiLink target resolves to a file next to the document.
 *
 * Tries the name as written first, then the extensions a Markdown document is
 * likely to carry, which is the same order MacDown itself uses when it
 * follows a link.
 */
NS_INLINE BOOL MPWikiTargetExists(NSURL *directory, NSString *target)
{
    if (!directory.isFileURL || !target.length)
        return NO;

    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *base = [directory URLByAppendingPathComponent:target];
    if ([manager fileExistsAtPath:base.path])
        return YES;

    for (NSString *extension in @[@"md", @"markdown", @"txt"])
    {
        NSURL *candidate = [base URLByAppendingPathExtension:extension];
        if ([manager fileExistsAtPath:candidate.path])
            return YES;
    }
    return NO;
}

/** Turns [[Target]] and [[Target|label]] into links.
 *
 * The href deliberately carries no extension: MacDown's own link handling
 * already tries .md and offers to create what is missing, so a WikiLink to a
 * page that does not exist yet behaves the way it does in a wiki.
 *
 * Runs on the rendered HTML rather than the Markdown so that fenced code and
 * inline code can be skipped — [[this]] inside a code block is code, not a
 * link, and a pass over the Markdown could not tell the difference.
 */
- (NSString *)htmlByResolvingWikiLinksIn:(NSString *)html
{
    static NSRegularExpression *wikiRegex = nil;
    static NSRegularExpression *codeRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wikiRegex = [[NSRegularExpression alloc] initWithPattern:
            @"\\[\\[([^\\[\\]|]+)(?:\\|([^\\[\\]]+))?\\]\\]"
                                                        options:0 error:NULL];
        codeRegex = [[NSRegularExpression alloc] initWithPattern:
            @"<pre[\\s\\S]*?</pre>|<code[\\s\\S]*?</code>"
                    options:NSRegularExpressionCaseInsensitive error:NULL];
    });

    NSRange whole = NSMakeRange(0, html.length);
    NSArray<NSTextCheckingResult *> *links =
        [wikiRegex matchesInString:html options:0 range:whole];
    if (!links.count)
        return html;

    NSArray<NSTextCheckingResult *> *codeSpans =
        [codeRegex matchesInString:html options:0 range:whole];

    // An unsaved document has nowhere to resolve against, so every target
    // reads as missing until the file has been saved somewhere.
    NSURL *directory = self.fileURL.URLByDeletingLastPathComponent;

    NSMutableString *result = [html mutableCopy];

    // Back to front, so each replacement leaves the earlier ranges valid.
    for (NSInteger i = (NSInteger)links.count - 1; i >= 0; i--)
    {
        NSTextCheckingResult *link = links[(NSUInteger)i];

        BOOL insideCode = NO;
        for (NSTextCheckingResult *span in codeSpans)
        {
            if (NSIntersectionRange(span.range, link.range).length)
            {
                insideCode = YES;
                break;
            }
        }
        if (insideCode)
            continue;

        NSCharacterSet *spaces = [NSCharacterSet whitespaceCharacterSet];
        NSString *target = [[html substringWithRange:[link rangeAtIndex:1]]
            stringByTrimmingCharactersInSet:spaces];
        if (!target.length)
            continue;

        NSRange labelRange = [link rangeAtIndex:2];
        NSString *label = target;
        if (labelRange.location != NSNotFound)
        {
            label = [[html substringWithRange:labelRange]
                stringByTrimmingCharactersInSet:spaces];
        }

        NSString *href = [target stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLPathAllowedCharacterSet]] ?: target;

        NSString *replacement;
        if (MPWikiTargetExists(directory, target))
        {
            replacement = [NSString stringWithFormat:
                @"<a href=\"%@\" class=\"wikilink\">%@</a>", href, label];
        }
        else
        {
            NSString *tip = NSLocalizedString(
                @"This page does not exist yet",
                @"tooltip on a WikiLink whose target is missing");
            replacement = [NSString stringWithFormat:
                @"<a href=\"%@\" class=\"wikilink wikilink-missing\" "
                @"title=\"%@\">%@</a>", href, tip, label];
        }

        [result replaceCharactersInRange:link.range withString:replacement];
    }
    return result;
}


/** Rewrites the file:// links in rendered markup to the preview's scheme.
 *
 * The page has an ordinary origin of its own, and from there a file:// URL
 * is refused. This used to happen only on the way to a full page load,
 * which meant an image written as a file:// URL appeared when the document
 * was opened and vanished at the next keystroke, when the body is replaced
 * in place instead of the page being loaded again.
 */
- (NSString *)htmlByServingLocalFilesIn:(NSString *)html
{
    // Only where a link is declared. Replacing every `file://` in the markup
    // rewrites the ones in the prose as well, and a document explaining what
    // a file:// URL is would find its own words edited.
    static NSRegularExpression *regex = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"(\\b(?:src|href|poster|data-src)\\s*=\\s*[\"'])file://"
                                                          options:
            NSRegularExpressionCaseInsensitive error:NULL];
    });
    if (!regex)
        return html;

    NSString *template = [NSString stringWithFormat:@"$1%@://",
                          MPPreviewURLScheme];
    return [regex stringByReplacingMatchesInString:html options:0
                                             range:NSMakeRange(0, html.length)
                                      withTemplate:template];
}

- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html
{
    if (self.alreadyRenderingInWeb)
    {
        self.renderToWebPending = YES;
        return;
    }
    
    if (self.printing)
        return;
    
    self.alreadyRenderingInWeb = YES;

    if (self.preferences.htmlWikiLinks)
        html = [self htmlByResolvingWikiLinksIn:html];

    // Delayed copying for -copyHtml, after the document has finished with
    // the renderer's output rather than before: what is copied should be
    // what the preview was given, and a WikiLink that is a link on screen
    // and in every export should not arrive on the pasteboard as brackets.
    if (self.copying)
    {
        self.copying = NO;
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard writeObjects:@[html]];
    }

    NSURL *baseUrl = self.fileURL;
    if (!baseUrl)   // Unsaved doument; just use the default URL.
        baseUrl = self.preferences.htmlDefaultDirectoryUrl;

    self.manualRender = self.preferences.markdownManualRender;

    // Typing reloads the whole page unless the head is unchanged.
    //
    // A full load tears the document down and builds it again, and that is
    // what makes the preview blink on every keystroke: the window flush
    // guards around it are no-ops on current AppKit. Replacing the body
    // instead leaves the head — the stylesheets, and the scripts that have
    // already run — exactly where it is, so there is nothing to flash and
    // the reader keeps their scroll position.
    //
    // The head is compared rather than assumed: it changes when a preference
    // adds or removes a stylesheet, and those renders still need a real load.
    // Before the split, so that both roads out of here — a full load and a
    // body replaced in place — carry the same links.
    html = [self htmlByServingLocalFilesIn:html];

    NSString *head = MPHeadOfHTML(html);
    NSString *body = MPBodyOfHTML(html);

    if (self.isPreviewReady && body && head
            && [self.currentBaseUrl isEqualTo:baseUrl]
            && [head isEqualToString:self.currentHeadHTML]
            && [self replacePreviewBodyWith:body])
    {
        return;
    }

    [self loadPreviewHTML:html baseURL:baseUrl];
    self.currentBaseUrl = baseUrl;
    self.currentHeadHTML = head;
}


/** Swaps the preview's body, leaving the rest of the document alone.
 *
 * Returns NO if the document is not in a state to be updated this way, in
 * which case the caller falls back to a full load.
 */
- (BOOL)replacePreviewBodyWith:(NSString *)body
{
    if (!self.isPreviewReady || !self.preview)
        return NO;

    // The markup travels as a JSON string rather than being pasted into the
    // script: a document contains quotes, newlines and backslashes, and
    // escaping them by hand is a bug waiting for the first apostrophe.
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:@[body]
                                                      options:0 error:NULL];
    NSString *literal = [[NSString alloc] initWithData:encoded
                                              encoding:NSUTF8StringEncoding];
    if (!literal)
        return NO;

    // Assigning innerHTML does not re-run the page's scripts, so everything
    // that decorates the document has to be invited back for this revision.
    // window keeps its properties across the swap, so they are all still
    // there. Mermaid goes first: it replaces whole code blocks, and there is
    // no point highlighting the ones that are about to disappear.
    NSString *js = [NSString stringWithFormat:
        @"(function(){"
        @"if (!document.body) return false;"
        @"document.body.innerHTML = %@[0];"
        @"if (window.MacDownRenderMermaid) MacDownRenderMermaid();"
        @"if (window.MacDownRenderGraphviz) MacDownRenderGraphviz();"
        @"if (window.Prism && Prism.highlightAll) Prism.highlightAll();"
        @"if (window.MathJax && MathJax.typesetPromise)"
        @" MathJax.typesetPromise();"
        @"if (window.MacDownReportScroll) MacDownReportScroll();"
        @"return true;})()", literal];
    [self.preview evaluateJavaScript:js completionHandler:nil];

    // No load means no load-finished delegate call, so the bookkeeping it
    // does has to happen here: the same completion handler for scaling,
    // insets and scroll syncing, and the flags that let the next render run.
    id callback = MPGetPreviewLoadingCompletionHandler(self);
    [[NSOperationQueue mainQueue] addOperationWithBlock:callback];

    if (self.preferences.editorShowWordCount)
        [self updateWordCount];

    self.alreadyRenderingInWeb = NO;
    if (self.renderToWebPending)
        [self.renderer parseAndRenderNow];
    self.renderToWebPending = NO;

    return YES;
}


#pragma mark - Notification handler

- (BOOL)isTyping
{
    return [NSDate timeIntervalSinceReferenceDate] - self.lastTypedAt
        < kMPTypingQuiet;
}

/** Brings the panes back together once the writing stops.
 *
 * Without this they would simply drift: the editor follows the caret down
 * the page all through a paragraph while the preview holds still, and
 * nothing would put them back until the reader scrolled something
 * themselves. Each keystroke arranges one of these and the earlier ones
 * stand down, so a burst of typing costs a single alignment at its end.
 *
 * And only if the editor actually moved while they wrote. Typing into the
 * middle of a page that stayed put leaves the preview already right, and
 * someone who pauses to think between sentences should not be paid for it
 * in a pane that jumps at every pause.
 */
- (void)resyncScrollingAfterTyping
{
    NSTimeInterval typed = self.lastTypedAt;
    __weak MPDocument *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kMPTypingQuiet * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        MPDocument *document = weakSelf;
        if (!document || document.lastTypedAt != typed)
            return;     // A later keystroke owns the resync now.
        if (!document.preferences.editorSyncScrolling)
            return;

        NSClipView *clip = document.editor.enclosingScrollView.contentView;
        if (clip && fabs(NSMinY(clip.bounds)
                         - document.editorTopWhenTypingBegan) < 1.0)
            return;

        @synchronized(document) {
            document.shouldHandleBoundsChange = NO;
            [document scrollPreviewToEditorTop];
            document.shouldHandleBoundsChange = YES;
        }
    });
}

- (void)editorTextDidChange:(NSNotification *)notification
{
    if (!self.isTyping)
    {
        NSClipView *clip = self.editor.enclosingScrollView.contentView;
        self.editorTopWhenTypingBegan = clip ? NSMinY(clip.bounds) : 0.0;
    }
    self.lastTypedAt = [NSDate timeIntervalSinceReferenceDate];
    if (self.preferences.editorSyncScrolling)
        [self resyncScrollingAfterTyping];

    if (self.editor.proseHighlightsEnabled)
        [self updateProseSummary];

    [self.sidebar updateOutlineWithMarkdown:self.editor.string ?: @""];
    [self.editor updateWritingAids];

    if (self.needsHtml)
        [self.renderer parseAndRenderLater];
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
    MPRenderer *renderer = self.renderer;

    // Force update if we're switching from manual to auto, or renderer settings
    // changed.
    int rendererFlags = self.preferences.rendererFlags;
    if ((!self.preferences.markdownManualRender && self.manualRender)
            || renderer.rendererFlags != rendererFlags)
    {
        renderer.rendererFlags = rendererFlags;
        [renderer parseAndRenderLater];
    }
    else
    {
        [renderer parseIfPreferencesChanged];
        [renderer renderIfPreferencesChanged];
    }
}

- (void)editorFrameDidChange:(NSNotification *)notification
{
    if (self.preferences.editorWidthLimited)
        [self adjustEditorInsets];
}

- (void)willStartLiveScroll:(NSNotification *)notification
{
    [self updateHeaderLocations];
    _inLiveScroll = YES;
}

-(void)didEndLiveScroll:(NSNotification *)notification
{
    _inLiveScroll = NO;
}

- (void)editorBoundsDidChange:(NSNotification *)notification
{
    if (!self.shouldHandleBoundsChange)
        return;

    if (self.preferences.editorSyncScrolling)
    {
        // Nobody is scrolling: the text view is moving itself to keep the
        // caret in view. The resync comes once the typing stops.
        if (self.isTyping)
            return;

        // The preview is the one being driven: this bounds change is the
        // editor arriving where the preview sent it.
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - self.previewDrivenAt < kMPScrollHandover)
            return;
        self.editorDrivenAt = now;

        @synchronized(self) {
            self.shouldHandleBoundsChange = NO;
            if (![self scrollPreviewToEditorTop])
            {
                // No blocks to go by — a page that has not finished loading.
                if (!_inLiveScroll)
                    [self updateHeaderLocations];
                [self syncScrollers];
            }
            self.shouldHandleBoundsChange = YES;
        }
    }
}

- (void)didRequestEditorReload:(NSNotification *)notification
{
    NSString *key =
        notification.userInfo[MPDidRequestEditorSetupNotificationKeyName];
    [self setupEditor:key];
}

- (void)didRequestPreviewReload:(NSNotification *)notification
{
    [self render:nil];
}



#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (object == self.editor)
    {
        if (!self.highlighter.isActive)
            return;
        id value = change[NSKeyValueChangeNewKey];
        NSString *preferenceKey = MPEditorPreferenceKeyWithValueKey(keyPath);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:value forKey:preferenceKey];
    }
    else if (object == [NSUserDefaults standardUserDefaults])
    {
        if (self.highlighter.isActive)
            [self setupEditor:keyPath];
        [self redrawDivider];
    }
}


#pragma mark - IBAction

- (IBAction)copyHtml:(id)sender
{
    // Dis-select things in WebView so that it's more obvious we're NOT
    // respecting the selection range.
    [self.preview evaluateJavaScript:
        @"if (window.getSelection) getSelection().removeAllRanges();"
                   completionHandler:nil];

    // Always through the rendering callback, even when the HTML is already
    // up to date. What the renderer holds is its own output; what the
    // preview was given has been through the document as well, and that is
    // what someone copying the HTML is looking at.
    self.copying = YES;
    [self.renderer parseAndRenderNow];
}

/** A PNG <img> tag for SVG markup, for consumers that cannot read SVG.
 *
 * Rasterised above 1:1 and then declared at its point size, so the picture
 * carries enough detail to survive being printed rather than looking soft.
 */
NS_INLINE NSString *MPImageTagForSVG(NSString *svg, CGFloat scale)
{
    NSData *svgData = [svg dataUsingEncoding:NSUTF8StringEncoding];
    NSImage *image = svgData ? [[NSImage alloc] initWithData:svgData] : nil;
    NSSize points = image ? image.size : NSZeroSize;
    if (points.width <= 0.0 || points.height <= 0.0)
        return nil;

    NSInteger wide = (NSInteger)ceil(points.width * scale);
    NSInteger high = (NSInteger)ceil(points.height * scale);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:wide pixelsHigh:high
                   bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
                        isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                     bytesPerRow:0 bitsPerPixel:0];
    rep.size = points;

    NSGraphicsContext *context =
        [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    if (!context)
        return nil;

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = context;
    [image drawInRect:NSMakeRect(0.0, 0.0, points.width, points.height)];
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                    properties:@{}];
    if (!png.length)
        return nil;

    return [NSString stringWithFormat:
            @"<p><img alt=\"diagram\" width=\"%ld\" src=\"data:image/png;"
            @"base64,%@\"></p>",
            (long)lround(points.width),
            [png base64EncodedStringWithOptions:0]];
}


/** The diagrams as the preview drew them, in document order.
 *
 * Both kinds: mermaid and Graphviz share one container class, and both are
 * wanted in an export for the same reason.
 */
- (NSArray<NSString *> *)renderedDiagrams
{
    // Collected after each render and kept, rather than asked for here.
    // Exporting is synchronous — a save panel returns a URL and the file is
    // written — and there is no way to ask the page a question and have the
    // answer in the same breath.
    return self.harvestedDiagrams ?: @[];
}

/** Puts the drawn diagrams into exported markup, in place of their sources.
 *
 * The alternative would be shipping the mermaid library with every export and
 * re-rendering on open, which is 1.1 MB per file and needs JavaScript enabled
 * wherever it lands.
 *
 * Diagrams are matched to fences by position, so a mismatch in the counts
 * means something did not draw. Rather than risk pairing a diagram with the
 * wrong fence, that leaves every fence alone as a code block.
 */
/** Puts the typeset formulas into exported markup, in place of their TeX.
 *
 * An EPUB carries no scripts, and neither does a Word file, so TeX left in
 * the text stays TeX: the reader sees \(E = mc^2\) where the formula should
 * be. MathJax has already drawn it in the preview, so what is exported is
 * that drawing.
 *
 * Most formulas arrive already normalised to \( \) and \[ \], but not all:
 * a display block the Markdown parser had to fight over keeps its $$. Both
 * forms are matched, and $$ has to precede $ or the longer one is read as
 * two empty ones.
 */
- (NSString *)htmlByInliningFormulasIn:(NSString *)html asImages:(BOOL)asImages
{
    NSArray<NSDictionary *> *formulas = self.harvestedFormulas;
    if (!formulas.count)
        return html;

    // Non-greedy, and the two forms in one alternation so that the matches
    // come back in document order — the order MathJax typeset them in.
    NSMutableArray<NSString *> *forms = [NSMutableArray arrayWithArray:@[
        @"\\\\\\[[\\s\\S]*?\\\\\\]",
        @"\\\\\\([\\s\\S]*?\\\\\\)",
        @"\\$\\$[\\s\\S]*?\\$\\$",
    ]];
    if (self.preferences.htmlMathJaxInlineDollar)
        [forms addObject:@"\\$[^\\$\\n]+?\\$"];
    NSString *pattern = [forms componentsJoinedByString:@"|"];
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:pattern options:0
                                                    error:NULL];
    NSArray<NSTextCheckingResult *> *found =
        [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)];

    // An export embeds its scripts, and MathJax's own source is full of the
    // sequences this is looking for — twenty of them in a document with two
    // formulas in it. Only what lies outside a script is TeX.
    static NSRegularExpression *scriptRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Code as well as scripts. A document that writes about the
        // delimiters puts them in backticks, and a match running from one
        // to the next swallows the prose between — which MathJax never
        // typeset, because it skips code too.
        scriptRegex = [NSRegularExpression regularExpressionWithPattern:
            @"<script[\\s\\S]*?</script>|<code[\\s\\S]*?</code>"
            @"|<pre[\\s\\S]*?</pre>"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    NSArray<NSTextCheckingResult *> *scripts =
        [scriptRegex matchesInString:html options:0
                               range:NSMakeRange(0, html.length)];

    NSMutableArray<NSTextCheckingResult *> *matches = [NSMutableArray array];
    for (NSTextCheckingResult *candidate in found)
    {
        BOOL inScript = NO;
        for (NSTextCheckingResult *script in scripts)
        {
            if (NSLocationInRange(candidate.range.location, script.range))
            {
                inScript = YES;
                break;
            }
        }
        if (!inScript)
            [matches addObject:candidate];
    }

    if (matches.count != formulas.count)
        return html;

    NSMutableString *result = [html mutableCopy];
    for (NSInteger i = (NSInteger)matches.count - 1; i >= 0; i--)
    {
        NSDictionary *formula = formulas[(NSUInteger)i];
        NSString *svg = formula[@"svg"];
        if (![svg isKindOfClass:[NSString class]])
            continue;

        // EPUB carries SVG natively, and it is the better answer: the
        // formula stays sharp at any zoom, and NSImage cannot rasterise
        // what MathJax emits anyway — its <defs> and <use> come back a
        // solid black rectangle. Word has no SVG, so there it is a picture
        // and the black rectangle is a known limit.
        NSString *tag = asImages ? MPImageTagForSVG(svg, 3.0) : svg;
        if (!tag)
            continue;

        // A display formula sits on its own line; an inline one has to sit
        // on the text's baseline, or it rides above it.
        if ([formula[@"display"] boolValue])
        {
            tag = [NSString stringWithFormat:
                @"<span style=\"display:block;text-align:center\">%@</span>",
                tag];
        }
        else
        {
            // Only the picture needs help sitting on the baseline. The SVG
            // arrives with MathJax's own vertical-align on it, which is the
            // exact offset for that formula — and a second style attribute
            // would not be valid XML anyway.
            if (asImages)
            {
                tag = [tag stringByReplacingOccurrencesOfString:@"<img "
                    withString:@"<img style=\"vertical-align:middle\" "];
            }
        }

        [result replaceCharactersInRange:matches[(NSUInteger)i].range
                              withString:tag];
    }
    return result;
}

- (NSString *)htmlByInliningDiagramsIn:(NSString *)html asImages:(BOOL)asImages
{
    NSArray<NSString *> *diagrams = self.renderedDiagrams;
    if (!diagrams.count)
        return html;

    // Matches what hoedown_patch_render_blockcode emits for a fence, for
    // every language that becomes a drawing: mermaid, and the six Graphviz
    // layout engines. Both lists are in document order, so the nth fence is
    // the nth diagram.
    static NSString * const pattern =
        // The div carries a data-src attribute since the renderer learned to
        // report source positions, so it can no longer be matched literally.
        @"<div[^>]*><pre[^>]*><code class=\"language-"
        @"(?:mermaid|dot|neato|fdp|circo|twopi|osage)\">[\\s\\S]*?"
        @"</code></pre></div>";
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:pattern options:0
                                                    error:NULL];
    NSArray<NSTextCheckingResult *> *matches =
        [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)];
    if (matches.count != diagrams.count)
        return html;

    // Back to front, so each replacement leaves the earlier ranges valid.
    NSMutableString *result = [html mutableCopy];
    for (NSInteger i = (NSInteger)matches.count - 1; i >= 0; i--)
    {
        NSString *svg = diagrams[(NSUInteger)i];
        // The placeholder for a diagram that would not draw. Its fence is
        // left as it stands, which is the honest thing to export: the source
        // of a diagram nobody could render.
        if (![svg isKindOfClass:[NSString class]] || !svg.length)
            continue;

        NSString *replacement = asImages
            ? MPImageTagForSVG(svg, 2.0)
            : [NSString stringWithFormat:@"<p>%@</p>", svg];
        if (!replacement)
            continue;
        [result replaceCharactersInRange:matches[(NSUInteger)i].range
                              withString:replacement];
    }
    return result;
}


- (IBAction)exportHtml:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"html"];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;

    MPExportPanelAccessoryViewController *controller =
        [[MPExportPanelAccessoryViewController alloc] init];
    controller.stylesIncluded = (BOOL)self.preferences.htmlStyleName;
    controller.highlightingIncluded = self.preferences.htmlSyntaxHighlighting;
    panel.accessoryView = controller.view;

    NSWindow *w = self.windowForSheet;
    [panel beginSheetModalForWindow:w completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        BOOL styles = controller.stylesIncluded;
        BOOL highlighting = controller.highlightingIncluded;
        NSString *html = [self.renderer HTMLForExportWithStyles:styles
                                                   highlighting:highlighting];
        if (self.preferences.htmlWikiLinks)
        html = [self htmlByResolvingWikiLinksIn:html];
        html = [self htmlByInliningDiagramsIn:html asImages:NO];
        [html writeToURL:panel.URL atomically:NO encoding:NSUTF8StringEncoding
                   error:NULL];
    }];
}

- (IBAction)exportEpub:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"epub"];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;

    NSWindow *window = self.windowForSheet;
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger res) {
        if (res != NSFileHandlingPanelOKButton)
            return;
        [self writeEpubToURL:panel.URL];
    }];
}

- (void)writeEpubToURL:(NSURL *)url
{
    // Styles are not linked in: an EPUB carries its own, and a reader is
    // entitled to override them. Diagrams are rasterised for the same reason
    // the Word export does it — nothing here runs scripts.
    NSString *html = [self.renderer HTMLForExportWithStyles:NO
                                               highlighting:NO];
    if (self.preferences.htmlWikiLinks)
        html = [self htmlByResolvingWikiLinksIn:html];
    html = [self htmlByInliningDiagramsIn:html asImages:YES];
    html = [self htmlByInliningFormulasIn:html asImages:NO];

    __weak MPDocument *weakSelf = self;
    [self html:html withRemoteImagesFetched:^(NSString *ready,
                                              NSArray<NSString *> *unreachable) {
        [weakSelf writeEpubMarkup:ready toURL:url unreachable:unreachable];
    }];
}

- (void)writeEpubMarkup:(NSString *)html
                  toURL:(NSURL *)url
            unreachable:(NSArray<NSString *> *)unreachable
{
    NSURL *cssURL = [[NSBundle mainBundle] URLForResource:@"epub-export"
                                            withExtension:@"css"
                                             subdirectory:@"Extensions"];
    NSString *css = cssURL
        ? [NSString stringWithContentsOfURL:cssURL encoding:NSUTF8StringEncoding
                                      error:NULL]
        : @"";

    MPEpubMetadata *metadata = [[MPEpubMetadata alloc] init];
    metadata.title = self.presumedFileName.stringByDeletingPathExtension;
    metadata.author = NSFullUserName();

    NSData *epub = MPEpubDataFromHTML(html, css, self.fileURL, metadata);
    if (!epub)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(
            @"The EPUB could not be built.",
            @"EPUB export failure title");
        alert.informativeText = NSLocalizedString(
            @"The rendered document could not be turned into the XHTML an "
            @"EPUB requires.",
            @"EPUB export failure detail");
        [alert beginSheetModalForWindow:self.windowForSheet
                      completionHandler:nil];
        return;
    }

    NSError *error = nil;
    if (![epub writeToURL:url options:NSDataWritingAtomic error:&error])
    {
        [self presentError:error];
        return;
    }

    if (unreachable.count)
    {
        NSMutableArray<NSString *> *problems = [NSMutableArray array];
        for (NSString *address in unreachable)
        {
            [problems addObject:MPExportImageProblem(address,
                NSLocalizedString(@"could not be fetched",
                                  @"Export image problem"))];
        }
        [self reportImageProblems:problems];
    }
}

/** Says which pictures did not make it into a package, and what went wrong.
 *
 * One line each, naming the file. A count on its own — "5 of the images in
 * this document are missing" — is a dead end: it says something is wrong
 * and nothing about what, and the reader who can see the pictures in their
 * document and in the preview has no way to tell which five or why. The
 * address and the reason are the whole value of the message.
 */
- (void)reportImageProblems:(NSArray<NSString *> *)problems
{
    if (!problems.count)
        return;

    // Enough to show a pattern, not enough to fill the screen.
    static const NSUInteger listed = 8;
    NSArray<NSString *> *shown = problems.count > listed
        ? [problems subarrayWithRange:NSMakeRange(0, listed)] : problems;
    NSMutableString *body =
        [[shown componentsJoinedByString:@"\n"] mutableCopy];
    if (problems.count > shown.count)
    {
        [body appendFormat:NSLocalizedString(@"\n…and %lu more.",
                                             @"Export partial images"),
            (unsigned long)(problems.count - shown.count)];
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(
        @"%lu images are missing from the exported file",
        @"Export partial images"), (unsigned long)problems.count];
    alert.informativeText = body;
    [alert runModal];
}

- (IBAction)exportDocx:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"docx"];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;

    NSWindow *window = self.windowForSheet;
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger res) {
        if (res != NSFileHandlingPanelOKButton)
            return;
        [self writeDocxToURL:panel.URL];
    }];
}

/** One line of the report: what was pointed at, and what went wrong.
 *
 * The address is shortened from the middle. A data: URI is thousands of
 * characters of base64 and would push everything else out of the dialog,
 * while its first few characters say all anyone needs — which kind of
 * picture it was meant to be.
 */
NS_INLINE NSString *MPExportImageProblem(NSString *source, NSString *reason)
{
    NSString *shown = source;
    if (shown.length > 70)
    {
        shown = [NSString stringWithFormat:@"%@…%@",
                 [shown substringToIndex:40],
                 [shown substringFromIndex:shown.length - 20]];
    }
    return [NSString stringWithFormat:@"%@ — %@", shown, reason];
}

/** PNG bytes and page size for one image reachable from exported markup.
 *
 * Everything is re-encoded to PNG so the archive only has to declare one
 * image content type, and rendered at the source's own pixel size so nothing
 * is upscaled or thrown away.
 *
 * Never wider than the text column. A picture is declared at its natural
 * size, and a screenshot two thousand points across would be declared two
 * thousand points across — Word does not shrink it to fit, it runs it off
 * the page. The pixels are kept and only the declared size comes down, so
 * clamping makes the picture sharper rather than coarser.
 */
NS_INLINE MPDocxImage *MPDocxImageFromData(NSData *data, NSString *placeholder)
{
    NSImage *image = data.length ? [[NSImage alloc] initWithData:data] : nil;
    NSSize points = image ? image.size : NSZeroSize;
    if (points.width <= 0.0 || points.height <= 0.0)
        return nil;

    if (points.width > MPDocxContentWidthPoints)
    {
        points = NSMakeSize(MPDocxContentWidthPoints,
                            points.height * MPDocxContentWidthPoints
                                / points.width);
    }

    NSInteger wide = 0;
    NSInteger high = 0;
    for (NSImageRep *rep in image.representations)
    {
        wide = MAX(wide, rep.pixelsWide);
        high = MAX(high, rep.pixelsHigh);
    }
    // Vector sources report no pixels; twice the point size prints cleanly.
    if (wide <= 0 || high <= 0)
    {
        wide = (NSInteger)ceil(points.width * 2.0);
        high = (NSInteger)ceil(points.height * 2.0);
    }

    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:wide pixelsHigh:high
                   bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
                        isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                     bytesPerRow:0 bitsPerPixel:0];
    bitmap.size = points;

    NSGraphicsContext *context =
        [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    if (!context)
        return nil;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = context;
    [image drawInRect:NSMakeRect(0.0, 0.0, points.width, points.height)];
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG
                                       properties:@{}];
    if (!png.length)
        return nil;

    MPDocxImage *result = [[MPDocxImage alloc] init];
    result.placeholder = placeholder;
    result.pngData = png;
    result.pointSize = points;
    return result;
}

/** Loads what an <img src> points at, for the Word export.
 *
 * Only data: URIs and local files. A remote image is left alone rather than
 * quietly turning an export into a network fetch.
 *
 * A local source is treated as a *path*, not parsed as a URL. `#` and `?`
 * are ordinary characters in a file name, and reading them as a fragment
 * or a query throws away everything after them — which is a picture
 * silently missing from the exported document rather than an error anyone
 * could act on. The percent-decoded name is tried as well, since a path
 * that came from a URL carries `%20` where the file on disk has a space.
 */
- (NSData *)imageDataForExportSource:(NSString *)source
                              reason:(NSString **)reason
{
    if (reason)
        *reason = nil;

    if ([source hasPrefix:@"data:"])
    {
        NSRange marker = [source rangeOfString:@";base64,"];
        if (marker.location == NSNotFound)
        {
            if (reason)
                *reason = NSLocalizedString(@"not base64 data",
                                            @"Export image problem");
            return nil;
        }
        NSString *encoded = [source substringFromIndex:NSMaxRange(marker)];
        NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded
            options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (!data.length && reason)
        {
            *reason = NSLocalizedString(@"the data could not be decoded",
                                        @"Export image problem");
        }
        return data;
    }

    NSString *plain = MPStringByUnescapingHTMLEntities(source);
    if ([plain hasPrefix:@"file://"])
        plain = [plain substringFromIndex:7];
    else if ([plain rangeOfString:@"://"].location != NSNotFound)
    {
        if (reason)
        {
            *reason = NSLocalizedString(@"could not be fetched",
                                        @"Export image problem");
        }
        return nil;
    }
    if (!plain.length)
    {
        if (reason)
            *reason = NSLocalizedString(@"no address", @"Export image problem");
        return nil;
    }

    if (!self.fileURL && ![plain hasPrefix:@"/"] && ![plain hasPrefix:@"~"])
    {
        if (reason)
        {
            *reason = NSLocalizedString(
                @"the document has never been saved, so a relative path has "
                @"nothing to be relative to", @"Export image problem");
        }
        return nil;
    }

    NSFileManager *files = [NSFileManager defaultManager];
    NSURL *base = self.fileURL.URLByDeletingLastPathComponent;

    for (NSString *path in @[plain, plain.stringByRemovingPercentEncoding ?: plain])
    {
        NSURL *url = nil;
        if ([path hasPrefix:@"/"])
            url = [NSURL fileURLWithPath:path];
        else if ([path hasPrefix:@"~"])
            url = [NSURL fileURLWithPath:path.stringByExpandingTildeInPath];
        else if (base)
            url = [NSURL fileURLWithPath:path relativeToURL:base];
        if (!url)
            continue;

        NSString *resolved = url.URLByStandardizingPath.path;
        if (!resolved || ![files fileExistsAtPath:resolved])
            continue;

        NSData *data = [NSData dataWithContentsOfFile:resolved];
        if (data.length)
            return data;
        if (reason)
        {
            *reason = [NSString stringWithFormat:NSLocalizedString(
                @"found at %@ but could not be read",
                @"Export image problem"), resolved];
        }
        return nil;
    }

    if (reason)
    {
        NSString *where = base.path ?: NSLocalizedString(@"the document's folder",
                                                         @"Export image problem");
        *reason = [NSString stringWithFormat:NSLocalizedString(
            @"not found, looked under %@", @"Export image problem"), where];
    }
    return nil;
}

/** Swaps every <img> for a plain-text marker, collecting the pictures.
 *
 * The markers survive AppKit's Word writer as ordinary runs, which is what
 * gives MPDocxPostProcessing somewhere to put the pictures back.
 */
- (NSString *)html:(NSString *)html
    withImagesReplacedByPlaceholders:(NSMutableArray<MPDocxImage *> *)images
                            problems:(NSMutableArray<NSString *> *)problems
{
    NSRegularExpression *imgRegex = [NSRegularExpression
        regularExpressionWithPattern:@"<img[^>]*>"
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];
    // Either quote. Only double ones come out of the renderer, but the
    // diagrams and the formulas are spliced in as markup of their own.
    NSRegularExpression *srcRegex = [NSRegularExpression
        regularExpressionWithPattern:
            @"src\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')"
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];

    NSArray<NSTextCheckingResult *> *matches =
        [imgRegex matchesInString:html options:0
                            range:NSMakeRange(0, html.length)];

    NSMutableString *result = [html mutableCopy];

    // Back to front, so each replacement leaves the earlier ranges valid.
    for (NSInteger i = (NSInteger)matches.count - 1; i >= 0; i--)
    {
        NSRange tagRange = matches[(NSUInteger)i].range;
        NSString *tag = [html substringWithRange:tagRange];

        NSTextCheckingResult *src =
            [srcRegex firstMatchInString:tag options:0
                                   range:NSMakeRange(0, tag.length)];
        NSString *source = nil;
        if (src)
        {
            NSRange quoted = [src rangeAtIndex:1];
            if (quoted.location == NSNotFound)
                quoted = [src rangeAtIndex:2];
            if (quoted.location != NSNotFound)
                source = [tag substringWithRange:quoted];
        }

        if (!source.length)
        {
            [problems addObject:MPExportImageProblem(
                tag, NSLocalizedString(@"the tag carries no src",
                                       @"Export image problem"))];
            continue;
        }

        // Closed at both ends, so the marker for image 1 is not also found
        // inside the marker for image 10.
        NSString *placeholder = [NSString stringWithFormat:
            @"MPIMGPLACEHOLDER%ldEND", (long)i];

        NSString *reason = nil;
        NSData *data = [self imageDataForExportSource:source reason:&reason];
        MPDocxImage *image = MPDocxImageFromData(data, placeholder);
        if (!image)
        {
            if (!reason)
            {
                reason = NSLocalizedString(
                    @"read, but not usable as a picture",
                    @"Export image problem");
            }
            [problems addObject:MPExportImageProblem(source, reason)];
            continue;
        }

        image.source = source;
        [images addObject:image];
        [result replaceCharactersInRange:tagRange
                             withString:image.placeholder];
    }
    return result;
}

/** The markup handed to the Word converter, on its own stylesheet.
 *
 * Not the preview style: that one is written for a screen, and the reader
 * that builds the Word document honours only a narrow subset of it. The
 * bundled word-export.css says the same things in the terms that reader
 * understands. Syntax highlighting is left out too, since it only ever
 * colours anything once Prism has run, and nothing runs in a .docx.
 */
- (NSString *)htmlForWordExport
{
    NSString *html = [self.renderer HTMLForExportWithStyles:NO
                                               highlighting:NO];
    if (self.preferences.htmlWikiLinks)
        html = [self htmlByResolvingWikiLinksIn:html];

    NSURL *url = [[NSBundle mainBundle] URLForResource:@"word-export"
                                        withExtension:@"css"
                                         subdirectory:@"Extensions"];
    NSString *css = url
        ? [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding
                                      error:NULL]
        : nil;
    if (!css.length)
        return html;

    NSString *tag = [NSString stringWithFormat:@"<style>\n%@\n</style>", css];
    NSRange head = [html rangeOfString:@"</head>"];
    if (head.location == NSNotFound)
        return html;

    return [html stringByReplacingCharactersInRange:head
                                         withString:
            [tag stringByAppendingString:@"</head>"]];
}

/** Collects the runs in a table cell, keeping the inline formatting.
 *
 * Walks the element rather than stripping tags, so a bold word or a snippet
 * of code inside a cell still reads as one in the Word file.
 */
static void MPCollectCellRuns(NSXMLNode *node,
                              NSMutableArray<MPDocxTextRun *> *runs,
                              BOOL bold, BOOL italic, BOOL monospaced)
{
    for (NSXMLNode *child in node.children)
    {
        if (child.kind == NSXMLTextKind)
        {
            NSString *text = child.stringValue;
            if (!text.length)
                continue;
            MPDocxTextRun *run = [[MPDocxTextRun alloc] init];
            run.text = text;
            run.bold = bold;
            run.italic = italic;
            run.monospaced = monospaced;
            [runs addObject:run];
            continue;
        }

        if (child.kind != NSXMLElementKind)
            continue;

        NSString *name = child.name.lowercaseString;
        if ([name isEqualToString:@"br"])
        {
            MPDocxTextRun *run = [[MPDocxTextRun alloc] init];
            run.text = @" ";
            [runs addObject:run];
            continue;
        }

        BOOL nowBold = bold
            || [name isEqualToString:@"strong"] || [name isEqualToString:@"b"];
        BOOL nowItalic = italic
            || [name isEqualToString:@"em"] || [name isEqualToString:@"i"];
        BOOL nowMono = monospaced
            || [name isEqualToString:@"code"] || [name isEqualToString:@"tt"];
        MPCollectCellRuns(child, runs, nowBold, nowItalic, nowMono);
    }
}

/** Reads one hoedown-emitted <table> into the model the builder wants.
 *
 * Parsed as XML, which hoedown's output is: it closes every cell and escapes
 * its text. Returns nil on anything it cannot parse, so the table is left to
 * AppKit rather than half-converted.
 */
NS_INLINE MPDocxTable *MPDocxTableFromHTML(NSString *html,
                                           NSString *placeholder)
{
    // Void elements hoedown writes unclosed, which XML will not accept.
    NSMutableString *xml = [html mutableCopy];
    [xml replaceOccurrencesOfString:@"<br>" withString:@"<br/>"
                            options:NSCaseInsensitiveSearch
                              range:NSMakeRange(0, xml.length)];

    NSError *error = nil;
    NSXMLDocument *parsed = [[NSXMLDocument alloc] initWithXMLString:xml
                                                            options:0
                                                              error:&error];
    NSXMLElement *root = parsed.rootElement;
    if (!root)
        return nil;

    NSArray<NSXMLNode *> *rowNodes = [root nodesForXPath:@".//tr" error:NULL];
    if (!rowNodes.count)
        return nil;

    NSMutableArray *rows = [NSMutableArray array];
    for (NSXMLNode *rowNode in rowNodes)
    {
        NSArray<NSXMLNode *> *cellNodes =
            [rowNode nodesForXPath:@"./th|./td" error:NULL];
        if (!cellNodes.count)
            continue;

        NSMutableArray<MPDocxTableCell *> *cells = [NSMutableArray array];
        for (NSXMLNode *cellNode in cellNodes)
        {
            MPDocxTableCell *cell = [[MPDocxTableCell alloc] init];
            cell.header = [cellNode.name.lowercaseString isEqualToString:@"th"];

            NSMutableArray<MPDocxTextRun *> *runs = [NSMutableArray array];
            MPCollectCellRuns(cellNode, runs, cell.header, NO, NO);
            cell.runs = runs;

            // hoedown puts the column alignment in a style attribute.
            NSXMLNode *style = [(NSXMLElement *)cellNode attributeForName:@"style"];
            NSString *value = style.stringValue;
            if ([value containsString:@"center"])
                cell.alignment = @"center";
            else if ([value containsString:@"right"])
                cell.alignment = @"right";

            [cells addObject:cell];
        }
        [rows addObject:cells];
    }

    if (!rows.count)
        return nil;

    MPDocxTable *table = [[MPDocxTable alloc] init];
    table.placeholder = placeholder;
    table.rows = rows;
    return table;
}

/** Swaps every <table> for a text marker, collecting its structure.
 *
 * The structure has to be read here: by the time AppKit has written the
 * .docx, a table is a run of tab-separated paragraphs and there is nothing
 * left to rebuild from.
 */
- (NSString *)html:(NSString *)html
    withTablesReplacedByPlaceholders:(NSMutableArray<MPDocxTable *> *)tables
{
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"<table[^>]*>[\\s\\S]*?</table>"
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];
    NSArray<NSTextCheckingResult *> *matches =
        [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)];

    NSMutableString *result = [html mutableCopy];

    // Back to front, so each replacement leaves the earlier ranges valid.
    for (NSInteger i = (NSInteger)matches.count - 1; i >= 0; i--)
    {
        NSRange range = matches[(NSUInteger)i].range;
        NSString *placeholder =
            [NSString stringWithFormat:@"MPTBLPLACEHOLDER%ld", (long)i];
        MPDocxTable *table = MPDocxTableFromHTML(
            [html substringWithRange:range], placeholder);
        if (!table)
            continue;

        [tables addObject:table];
        [result replaceCharactersInRange:range withString:placeholder];
    }
    return result;
}


/// The prefix of the marks that tell the Word export where a heading was.
static NSString * const kMPDocxHeadingToken = @"MPHDGPLACEHOLDER";

/** Marks each heading with its level, for the Word export to find later.
 *
 * By the time AppKit has turned the page into a .docx a heading is just a
 * paragraph in a larger, bolder face, indistinguishable from a line of text
 * someone emphasised. Marking them here, while the markup still says which
 * is which, is what lets the export give them Word's heading styles.
 *
 * The mark goes immediately before the heading's text and is taken out
 * again on the other side, so it never reaches the page.
 */
- (NSString *)htmlByMarkingHeadingsIn:(NSString *)html
{
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"<h([1-6])(\\s[^>]*)?>"
                             options:NSRegularExpressionCaseInsensitive
                               error:NULL];
    NSArray<NSTextCheckingResult *> *matches =
        [regex matchesInString:html options:0
                         range:NSMakeRange(0, html.length)];

    NSMutableString *result = [html mutableCopy];

    // Back to front, so each insertion leaves the earlier ranges valid.
    for (NSInteger i = (NSInteger)matches.count - 1; i >= 0; i--)
    {
        NSTextCheckingResult *match = matches[(NSUInteger)i];
        NSString *level = [html substringWithRange:[match rangeAtIndex:1]];
        [result insertString:[kMPDocxHeadingToken stringByAppendingString:level]
                     atIndex:NSMaxRange(match.range)];
    }
    return result;
}

/// The window an export's sheet belongs on, if the document has one.
- (NSWindow *)exportSheetParent
{
    NSArray *controllers = self.windowControllers;
    return controllers.count ? [controllers[0] window] : nil;
}

/** Fetches the remote pictures, then carries on with `next`.
 *
 * Both package formats go through here. With the preference off, or with
 * nothing remote in the markup, `next` runs immediately and the export is
 * the synchronous thing it always was.
 */
- (void)html:(NSString *)html
    withRemoteImagesFetched:(void (^)(NSString *html,
                                      NSArray<NSString *> *unreachable))next
{
    if (!self.preferences.exportFetchesRemoteImages)
    {
        next(html, @[]);
        return;
    }
    MPFetchRemoteImagesInHTML(html, [self exportSheetParent], next);
}

- (void)writeDocxToURL:(NSURL *)url
{
    NSString *html = [self htmlForWordExport];

    // Rasterised rather than left as SVG, because AppKit's HTML reader has no
    // SVG support at all and would drop the diagrams without a word. They
    // then travel the same road as any other image below.
    html = [self htmlByInliningDiagramsIn:html asImages:YES];
    html = [self htmlByInliningFormulasIn:html asImages:YES];

    __weak MPDocument *weakSelf = self;
    [self html:html withRemoteImagesFetched:^(NSString *ready,
                                              NSArray<NSString *> *unreachable) {
        [weakSelf writeDocxMarkup:ready toURL:url unreachable:unreachable];
    }];
}

- (void)writeDocxMarkup:(NSString *)html
                  toURL:(NSURL *)url
            unreachable:(NSArray<NSString *> *)unreachable
{
    NSMutableArray<MPDocxImage *> *images = [NSMutableArray array];
    NSMutableArray<NSString *> *problems = [NSMutableArray array];
    html = [self html:html withImagesReplacedByPlaceholders:images
             problems:problems];

    NSMutableArray<MPDocxTable *> *tables = [NSMutableArray array];
    html = [self html:html withTablesReplacedByPlaceholders:tables];

    // After the tables, so that a heading inside one — which is a cell, not
    // a section — never picks up a mark that its cell would then show.
    html = [self htmlByMarkingHeadingsIn:html];

    NSData *htmlData = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *readOptions = @{
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
        NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding),
    };

    NSError *error = nil;
    NSAttributedString *rich =
        [[NSAttributedString alloc] initWithData:htmlData options:readOptions
                              documentAttributes:NULL error:&error];
    if (!rich)
    {
        [self presentError:error];
        return;
    }

    NSDictionary *writeOptions = @{
        NSDocumentTypeDocumentAttribute: NSOfficeOpenXMLTextDocumentType,
    };
    NSData *docx = [rich dataFromRange:NSMakeRange(0, rich.length)
                   documentAttributes:writeOptions error:&error];
    if (!docx)
    {
        [self presentError:error];
        return;
    }

    // Shading and list indents, which the writer does not carry over either.
    // The family and colour have to match word-export.css, since the font is
    // what identifies a code paragraph once the markup is gone.
    NSData *repaired = MPDocxDataByRepairingLayout(docx, @"Menlo", @"F4F4F4");
    if (repaired)
        docx = repaired;

    // Tables, which the writer flattens into tab-separated paragraphs. The
    // fonts and size match word-export.css so a table sits with the prose.
    NSData *tabled = MPDocxDataByBuildingTables(docx, tables,
                                                @"Helvetica Neue", @"Menlo",
                                                10.0);
    if (tabled)
        docx = tabled;

    // Then the pictures, which AppKit's writer would otherwise have left out
    // of the file entirely. After the tables on purpose: a picture inside a
    // cell has its marker in the table this step has just written, and
    // planting them earlier meant looking for a marker that was not in the
    // document yet — one picture in a table and every picture in the
    // document went missing, with nothing said.
    NSMutableArray<NSString *> *unplaced = [NSMutableArray array];
    NSData *embedded = MPDocxDataByEmbeddingImages(docx, images, unplaced);
    if (embedded)
        docx = embedded;
    for (NSString *source in unplaced)
    {
        [problems addObject:MPExportImageProblem(source, NSLocalizedString(
            @"read, but there was nowhere in the document to put it",
            @"Export image problem"))];
    }

    // The heading styles, without which Word's navigation pane stays empty
    // and a table of contents field finds nothing to build from.
    NSData *headed = MPDocxDataByStylingHeadings(docx, kMPDocxHeadingToken);
    if (headed)
        docx = headed;

    // Menlo ships with macOS and nowhere else, so on its own it leaves code
    // blocks proportional in Word on Windows. The font table gives Word a
    // fixed-pitch alternative to reach for.
    NSData *withFonts = MPDocxDataByDeclaringFonts(docx, @"Menlo", @"Consolas",
                                                   @"Helvetica Neue",
                                                   @"Arial");
    if (withFonts)
        docx = withFonts;

    if (![docx writeToURL:url options:NSDataWritingAtomic error:&error])
    {
        [self presentError:error];
        return;
    }

    if (problems.count)
        [self reportImageProblems:problems];
}

/** OpenDocument and RTF, which share everything but their last step.
 *
 * Both of AppKit's writers keep the tables and the character styling — which
 * its Word writer does not — so those go through untouched; both drop every
 * picture, which is what MPRichExport puts back.
 */
- (IBAction)exportOdt:(id)sender
{
    [self exportRichTextOfKind:MPRichExportOpenDocument];
}

- (IBAction)exportRtf:(id)sender
{
    [self exportRichTextOfKind:MPRichExportRTF];
}

- (IBAction)exportTextBundle:(id)sender
{
    [self exportTextBundleZipped:NO];
}


- (IBAction)exportTextPack:(id)sender
{
    [self exportTextBundleZipped:YES];
}


/** The document and its pictures, in somebody else's container on purpose.
 *
 * A `.textbundle` is a folder Finder shows as one item; a `.textpack` is
 * that folder zipped, which is what travels through mail. Bear, Ulysses, iA
 * Writer and Marked read both.
 *
 * Unlike every other export here this one does not go through the rendered
 * HTML: what a textbundle holds is the Markdown as written, with the links
 * to its pictures pointed at `assets/`. Taken apart by hand it still works,
 * which is the whole reason to use the format.
 */
- (void)exportTextBundleZipped:(BOOL)zipped
{
    NSString *extension = zipped ? @"textpack" : @"textbundle";
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[extension];
    if (self.presumedFileName)
    {
        panel.nameFieldStringValue = [self.presumedFileName
            .stringByDeletingPathExtension
            stringByAppendingPathExtension:extension];
    }

    [panel beginSheetModalForWindow:self.windowForSheet
                  completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        [self writeTextBundleTo:panel.URL zipped:zipped];
    }];
}


- (void)writeTextBundleTo:(NSURL *)url zipped:(BOOL)zipped
{
    NSString *markdown = self.markdown ?: @"";
    NSArray<MPTextBundleAsset *> *assets = nil;
    // The pictures are resolved against the document's own folder, so a
    // document that has never been saved has none to bring: its links are
    // relative to nothing.
    NSString *text = MPTextBundleMarkdown(markdown, self.fileURL, &assets);
    NSData *info = MPTextBundleInfo(
        [NSBundle mainBundle].bundleIdentifier,
        @"https://nicolorisitano82.github.io/macdown-next/");

    NSError *error = nil;
    BOOL written = NO;
    if (zipped)
    {
        // The folder's name inside the archive, extension and all: a
        // textpack that unzips to a bare assets/ is not a textbundle.
        NSString *inside = [url.lastPathComponent.stringByDeletingPathExtension
            stringByAppendingPathExtension:@"textbundle"];
        NSData *pack = MPTextPackData(inside, text, info, assets);
        written = pack
            && [pack writeToURL:url options:NSDataWritingAtomic error:&error];
    }
    else
    {
        written = MPWriteTextBundle(url, text, info, assets, &error);
    }

    MPNote(@"%@: %lu pictures, %@", zipped ? @"textpack" : @"textbundle",
           (unsigned long)assets.count,
           written ? url.lastPathComponent : @"not written");

    if (!written)
    {
        [self say:NSLocalizedString(@"The package could not be written",
                                    @"Textbundle or Textpack export failed")
             text:error.localizedDescription];
        return;
    }

    // What could not be brought along, said once and by name: a reader can
    // do something about an address, and nothing about a number.
    NSArray<NSString *> *remote = MPTextBundleRemoteImages(markdown);
    if (remote.count)
    {
        [self say:NSLocalizedString(
            @"The pictures on the web stayed as addresses",
            @"Some images could not be put in the package")
             text:[NSString stringWithFormat:NSLocalizedString(
            @"A package carries the pictures kept beside the document. "
            @"These are addresses, and they are still addresses inside "
            @"it:\n\n%@",
            @"Which images stayed as links, and why"),
            [remote componentsJoinedByString:@"\n"]]];
    }
}


- (void)exportRichTextOfKind:(MPRichExportKind)kind
{
    NSString *extension = (kind == MPRichExportOpenDocument) ? @"odt" : @"rtf";
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[extension];
    if (self.presumedFileName)
    {
        panel.nameFieldStringValue = [self.presumedFileName
            .stringByDeletingPathExtension
            stringByAppendingPathExtension:extension];
    }

    [panel beginSheetModalForWindow:self.windowForSheet
                  completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        [self writeRichText:kind toURL:panel.URL];
    }];
}

- (void)writeRichText:(MPRichExportKind)kind toURL:(NSURL *)url
{
    NSString *html = [self htmlForWordExport];
    // Rasterised for the same reason as in the Word export: AppKit's HTML
    // reader has no SVG at all, and would drop the diagrams without a word.
    html = [self htmlByInliningDiagramsIn:html asImages:YES];
    html = [self htmlByInliningFormulasIn:html asImages:YES];

    __weak MPDocument *weakSelf = self;
    [self html:html withRemoteImagesFetched:^(NSString *ready,
                                              NSArray<NSString *> *unreachable) {
        [weakSelf writeRichTextMarkup:ready kind:kind toURL:url
                          unreachable:unreachable];
    }];
}

- (void)writeRichTextMarkup:(NSString *)html
                       kind:(MPRichExportKind)kind
                      toURL:(NSURL *)url
                unreachable:(NSArray<NSString *> *)unreachable
{
    NSMutableArray<MPDocxImage *> *images = [NSMutableArray array];
    NSMutableArray<NSString *> *problems = [NSMutableArray array];
    // The tables are left where they are: unlike the Word writer, these two
    // carry them over by themselves.
    html = [self html:html withImagesReplacedByPlaceholders:images
             problems:problems];

    NSError *error = nil;
    NSAttributedString *rich = [[NSAttributedString alloc]
        initWithData:[html dataUsingEncoding:NSUTF8StringEncoding]
             options:@{
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
        NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding),
    } documentAttributes:NULL error:&error];
    if (!rich)
    {
        [self presentError:error];
        return;
    }

    NSString *type = (kind == MPRichExportOpenDocument)
        ? NSOpenDocumentTextDocumentType : NSRTFTextDocumentType;
    NSData *data = [rich dataFromRange:NSMakeRange(0, rich.length)
                    documentAttributes:@{NSDocumentTypeDocumentAttribute: type}
                                 error:&error];
    if (!data)
    {
        [self presentError:error];
        return;
    }

    NSMutableArray<NSString *> *unplaced = [NSMutableArray array];
    NSData *withPictures = (kind == MPRichExportOpenDocument)
        ? MPOdtDataByEmbeddingImages(data, images, unplaced)
        : MPRtfDataByEmbeddingImages(data, images, unplaced);
    if (withPictures)
        data = withPictures;

    for (NSString *source in unplaced)
    {
        [problems addObject:MPExportImageProblem(source, NSLocalizedString(
            @"read, but there was nowhere in the document to put it",
            @"Export image problem"))];
    }
    for (NSString *source in unreachable)
    {
        [problems addObject:MPExportImageProblem(source, NSLocalizedString(
            @"could not be fetched", @"Export image problem"))];
    }

    if (![data writeToURL:url options:NSDataWritingAtomic error:&error])
    {
        [self presentError:error];
        return;
    }
    if (problems.count)
        [self reportImageProblems:problems];
}


/** A format a plug-in adds, run the way the built-in ones are.
 *
 * The plug-in is handed the document already rendered and made
 * self-contained — diagrams and formulas drawn, remote pictures fetched if
 * the preferences allow it — so that every exporter starts from the same
 * thing, and none of them has to know how any of that is done.
 */
- (IBAction)exportWithPlugIn:(id)sender
{
    MPPlugIn *exporter = [sender representedObject];
    if (![exporter isKindOfClass:[MPPlugIn class]] || !exporter.isExporter)
        return;

    NSString *extension = exporter.exportFileExtension;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = extension.length ? @[extension] : nil;
    panel.message = exporter.exportFormatDescription;
    if (self.presumedFileName && extension.length)
    {
        panel.nameFieldStringValue = [self.presumedFileName
            .stringByDeletingPathExtension
            stringByAppendingPathExtension:extension];
    }

    [panel beginSheetModalForWindow:self.windowForSheet
                  completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        [self exportWith:exporter toURL:panel.URL];
    }];
}

- (void)exportWith:(MPPlugIn *)exporter toURL:(NSURL *)url
{
    NSString *html = [self htmlForWordExport];
    html = [self htmlByInliningDiagramsIn:html asImages:YES];
    html = [self htmlByInliningFormulasIn:html asImages:YES];

    __weak MPDocument *weakSelf = self;
    [self html:html withRemoteImagesFetched:^(NSString *ready,
                                              NSArray<NSString *> *unreachable) {
        MPDocument *strong = weakSelf;
        if (!strong)
            return;

        MPNote(@"exporting with %@ to %@", exporter.name, url.lastPathComponent);
        NSError *error = nil;
        NSData *data = [exporter exportDataFromHTML:ready
                                           markdown:strong.markdown
                                            fileURL:strong.fileURL
                                              error:&error];
        if (!data)
        {
            // A plug-in that fails without saying why still owes the reader
            // a sentence, and this is the only one available.
            if (!error)
            {
                error = [NSError errorWithDomain:@"MPExporterPlugIn" code:1
                    userInfo:@{NSLocalizedDescriptionKey: [NSString
                        stringWithFormat:NSLocalizedString(
                            @"%@ did not say why the export failed.",
                            @"An exporter plug-in failed"),
                        exporter.name]}];
            }
            [strong presentError:error];
            return;
        }

        if (![data writeToURL:url options:NSDataWritingAtomic error:&error])
        {
            [strong presentError:error];
            return;
        }

        if (unreachable.count)
        {
            NSMutableArray *problems = [NSMutableArray array];
            for (NSString *source in unreachable)
            {
                [problems addObject:MPExportImageProblem(source,
                    NSLocalizedString(@"could not be fetched",
                                      @"Export image problem"))];
            }
            [strong reportImageProblems:problems];
        }
    }];
}


/** Hands the document, or the selection, to Claude or to ChatGPT.
 *
 * The text goes on the clipboard and the chat opens with the prompt field
 * filled in where that is possible — filled in, not sent: what to ask is the
 * reader's to write, and a menu item that started a conversation by itself
 * would be a menu item nobody trusts.
 *
 * Nothing is sent by the application: the link opens somebody else's
 * program, and what happens next happens there.
 */
/** What an agent would read, for this document.
 *
 * CLAUDE.md and AGENTS.md are files like any other until you ask which ones
 * apply and in what order, what they pull in with `@`, and which of those
 * paths lead nowhere. Then they are a small system, and a small system
 * deserves to be shown rather than reconstructed by opening files one by
 * one.
 */
- (IBAction)showInstructionFiles:(id)sender
{
    if (self.instructionsPopover.isShown)
    {
        [self.instructionsPopover close];
        self.instructionsPopover = nil;
        return;
    }
    if (!self.fileURL)
        return;

    NSURL *home = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
    NSURL *managed = [NSURL fileURLWithPath:
        @"/Library/Application Support/ClaudeCode" isDirectory:YES];
    NSArray<MPInstructionFile *> *hierarchy =
        MPInstructionHierarchyForDocument(self.fileURL, home, managed);

    // The tree is grown from the nearest project file, which is the one a
    // reader is looking at when they ask.
    NSURL *nearest = nil;
    for (MPInstructionFile *file in hierarchy)
    {
        if (file.exists && file.scope != MPInstructionScopeAgents)
            nearest = file.fileURL;
    }
    if (MPIsInstructionFile(self.fileURL))
        nearest = self.fileURL;

    MPInstructionNode *tree = nearest
        ? MPResolveInstructionImports(nearest) : nil;
    NSArray<MPInstructionIssue *> *issues =
        MPInstructionIssues(tree, hierarchy);
    MPNote(@"instructions: %lu files, %lu warnings",
           (unsigned long)hierarchy.count, (unsigned long)issues.count);

    MPInstructionsViewController *list = [[MPInstructionsViewController alloc]
        initWithHierarchy:hierarchy tree:tree issues:issues
                   chosen:^(NSURL *fileURL) {
        NSDocumentController *controller =
            [NSDocumentController sharedDocumentController];
        if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path])
        {
            // Not there yet: this is where it would go, so make it and open
            // it rather than saying no.
            [@"" writeToURL:fileURL atomically:YES
                   encoding:NSUTF8StringEncoding error:NULL];
        }
        [controller openDocumentWithContentsOfURL:fileURL display:YES
                                completionHandler:^(NSDocument *opened,
                                                    BOOL was,
                                                    NSError *error) {}];
    }];

    NSPopover *popover = [[NSPopover alloc] init];
    popover.contentViewController = list;
    popover.behavior = NSPopoverBehaviorTransient;
    popover.contentSize = list.view.frame.size;
    self.instructionsPopover = popover;

    NSView *anchor = self.editor;
    NSRect top = anchor.visibleRect;
    top.size.height = 1.0;
    [popover showRelativeToRect:top ofView:anchor
                  preferredEdge:NSRectEdgeMaxY];
}


- (IBAction)sendToClaude:(id)sender
{
    [self sendTo:MPSendToClaude];
}

- (IBAction)sendToChatGPT:(id)sender
{
    [self sendTo:MPSendToChatGPT];
}

- (void)sendTo:(MPSendToTarget)target
{
    NSRange selected = self.editor.selectedRange;
    NSString *text = selected.length
        ? [self.editor.string substringWithRange:selected]
        : self.editor.string;
    if (![text stringByTrimmingCharactersInSet:
          [NSCharacterSet whitespaceAndNewlineCharacterSet]].length)
        return;

    // On the clipboard whatever happens: a link that carries the document is
    // a convenience, and pasting is what works when it cannot.
    NSPasteboard *board = [NSPasteboard generalPasteboard];
    [board clearContents];
    [board setString:text forType:NSPasteboardTypeString];

    BOOL installed = MPSendToDesktopAppIsInstalled(target);
    NSURL *url = MPSendToURL(target, text, installed);
    MPNote(@"sending %lu characters to %@ (%@, text in the link: %@)",
           (unsigned long)text.length,
           target == MPSendToClaude ? @"Claude" : @"ChatGPT",
           installed ? @"application" : @"web",
           MPSendToLinkCarriesText(target, text, installed) ? @"yes" : @"no");
    if (url)
        [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction)exportPdf:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"pdf"];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;
    
    NSWindow *w = nil;
    NSArray *windowControllers = self.windowControllers;
    if (windowControllers.count > 0)
        w = [windowControllers[0] window];

    [panel beginSheetModalForWindow:w completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;

        NSDictionary *settings = @{
            NSPrintJobDisposition: NSPrintSaveJob,
            NSPrintJobSavingURL: panel.URL,
        };
        [self printDocumentWithSettings:settings showPrintPanel:NO delegate:nil
                       didPrintSelector:NULL contextInfo:NULL];
    }];
}

- (IBAction)convertToH1:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:1];
}

- (IBAction)convertToH2:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:2];
}

- (IBAction)convertToH3:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:3];
}

- (IBAction)convertToH4:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:4];
}

- (IBAction)convertToH5:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:5];
}

- (IBAction)convertToH6:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:6];
}

- (IBAction)convertToParagraph:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:0];
}

- (IBAction)toggleStrong:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"**" suffix:@"**"];
}

- (IBAction)toggleEmphasis:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"*" suffix:@"*"];
}

- (IBAction)toggleInlineCode:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"`" suffix:@"`"];
}

/** Code, at whichever size is wanted, from one button.
 *
 * A selection that is already marked is taken off without asking, so the
 * button undoes itself the way the others do.
 */
- (IBAction)insertCode:(id)sender
{
    NSRange selection = self.editor.selectedRange;
    if (selection.length
            && [self.editor substringInRange:selection
                        isSurroundedByPrefix:@"`" suffix:@"`"])
    {
        [self.editor toggleForMarkupPrefix:@"`" suffix:@"`"];
        return;
    }
    if ([self selectedLinesAreFencedCodeBlock])
    {
        [self insertCodeFenceForLanguage:nil];
        return;
    }

    // Text with a line break in it cannot be code inside a line, so that
    // half of the question answers itself; the language does not.
    NSString *chosen = selection.length
        ? [self.editor.string substringWithRange:selection] : @"";
    BOOL block = [chosen rangeOfString:@"\n"].location != NSNotFound;
    [self runCodeSheetPreferringBlock:block onlyBlock:block];
}

/// The same, when the block is already the answer.
- (IBAction)insertCodeBlock:(id)sender
{
    if ([self selectedLinesAreFencedCodeBlock])
    {
        [self insertCodeFenceForLanguage:nil];
        return;
    }
    [self runCodeSheetPreferringBlock:YES onlyBlock:YES];
}

- (BOOL)selectedLinesAreFencedCodeBlock
{
    NSString *text = self.editor.string;
    NSRange lines = [text lineRangeForRange:self.editor.selectedRange];
    return MPBodyOfFencedCodeBlock([text substringWithRange:lines]) != nil;
}

- (void)runCodeSheetPreferringBlock:(BOOL)block onlyBlock:(BOOL)onlyBlock
{
    // What was asked for last time. Someone writing code samples is
    // usually writing several, in one language.
    static BOOL lastWasBlock = NO;
    static NSString *lastLanguage = nil;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Insert code", @"Code sheet");
    alert.informativeText = NSLocalizedString(
        @"A block is highlighted by the language you name here. Only the "
        @"languages this copy of MacDown Next can highlight are listed.",
        @"Code sheet");
    [alert addButtonWithTitle:NSLocalizedString(@"Insert", @"Code sheet")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Code sheet")];

    MPCodeAccessory *accessory =
        [[MPCodeAccessory alloc] initWithBlock:(block || lastWasBlock)
                                      language:lastLanguage];
    // Nothing to choose when only one of the two is possible; the choice
    // is still shown, so it is clear which one is being made.
    if (onlyBlock)
    {
        accessory.inlineRadio.enabled = NO;
        accessory.blockRadio.enabled = NO;
    }
    alert.accessoryView = accessory;

    void (^insert)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn)
            return;
        lastWasBlock = accessory.usesBlock;
        if (!accessory.usesBlock)
        {
            [self.editor toggleForMarkupPrefix:@"`" suffix:@"`"];
            return;
        }
        lastLanguage = accessory.language;
        [self insertCodeFenceForLanguage:accessory.language];
    };

    NSWindow *window = self.windowForSheet;
    if (window)
    {
        [alert beginSheetModalForWindow:window completionHandler:insert];
        [window makeFirstResponder:accessory.languageButton];
    }
    else
    {
        insert([alert runModal]);
    }
}

/** Puts the fence on the selected lines, or takes it off.
 *
 * Where the fence goes and where the caret lands afterwards is worked out
 * apart from here, in MPCodeLanguages, so it can be checked.
 */
- (void)insertCodeFenceForLanguage:(NSString *)language
{
    NSTextView *editor = self.editor;
    MPCodeFenceEdit *edit = MPCodeFenceEditForText(
        editor.string, editor.selectedRange, language);

    [editor insertText:edit.replacement
      replacementRange:edit.replacedRange];
    editor.selectedRange = edit.selectedRange;
}

- (IBAction)toggleStrikethrough:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"~~" suffix:@"~~"];
}

- (IBAction)toggleUnderline:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"_" suffix:@"_"];
}

- (IBAction)toggleHighlight:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"==" suffix:@"=="];
}

- (IBAction)toggleComment:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"<!--" suffix:@"-->"];
}

/** Asks where the link goes, then writes it.
 *
 * It used to put `[]()` in and leave the caret between the parentheses,
 * which is fine if the address is already on the clipboard and a guessing
 * game if it is not — and no help at all for a file, where the answer is a
 * path nobody wants to type from memory.
 *
 * A selection that is already a link is taken off instead, so the button
 * still undoes itself.
 */
- (IBAction)toggleLink:(id)sender
{
    NSRange selection = self.editor.selectedRange;
    if (selection.length
            && [self.editor substringInRange:selection
                        isSurroundedByPrefix:@"[" suffix:@"]()"])
    {
        [self.editor toggleForMarkupPrefix:@"[" suffix:@"]()"];
        return;
    }

    // Which kind was wanted last time. Someone linking to files is usually
    // linking to several.
    static BOOL lastWasFile = NO;

    NSString *text = selection.length
        ? [self.editor.string substringWithRange:selection] : @"";

    // An address already on the clipboard is almost certainly the one, and
    // this is the one place the old behaviour was genuinely useful.
    NSString *pasted = nil;
    if (!lastWasFile)
    {
        NSPasteboard *board = [NSPasteboard generalPasteboard];
        pasted = [board URLForType:NSPasteboardTypeString].absoluteString;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Insert a link", @"Link sheet");
    alert.informativeText = NSLocalizedString(
        @"A file inside this document's folder is linked by a relative path, "
        @"so the two keep working when you move them together.",
        @"Link sheet");
    [alert addButtonWithTitle:NSLocalizedString(@"Insert", @"Link sheet")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Link sheet")];

    MPLinkAccessory *accessory =
        [[MPLinkAccessory alloc] initWithText:text address:pasted
                                       toFile:lastWasFile];
    alert.accessoryView = accessory;

    NSWindow *window = self.windowForSheet;
    void (^insert)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn)
            return;
        lastWasFile = accessory.usesFile;
        [self insertLinkFromAccessory:accessory replacing:selection];
    };

    if (window)
    {
        [alert beginSheetModalForWindow:window completionHandler:insert];
        // The address is what the sheet is for; the text is usually already
        // there, taken from the selection.
        [window makeFirstResponder:accessory.targetField];
    }
    else
    {
        insert([alert runModal]);
    }
}

- (void)insertLinkFromAccessory:(MPLinkAccessory *)accessory
                      replacing:(NSRange)selection
{
    if (accessory.makesNewFile)
    {
        [self linkToNewMarkdownFileNamed:accessory.linkText
                          replacingRange:selection];
        return;
    }

    NSURL *file = accessory.fileToLink;
    NSString *target = file
        ? MPMarkdownLinkTargetForFileURL(file, self.fileURL)
        : accessory.typedTarget;
    if (!target.length)
        return;

    // Nothing said, so the link says where it goes: a file by its name, an
    // address by itself. Better than a pair of empty brackets.
    NSString *text = accessory.linkText;
    if (!text.length)
    {
        text = file ? file.lastPathComponent.stringByDeletingPathExtension
                    : accessory.typedTarget;
    }

    NSString *markup = [NSString stringWithFormat:@"[%@](%@)", text, target];
    if (NSMaxRange(selection) > self.editor.string.length)
        selection = self.editor.selectedRange;

    [self.editor insertText:markup replacementRange:selection];
    self.editor.selectedRange =
        NSMakeRange(selection.location + markup.length, 0);
}


/** MIME type for a data: URI built from an image file.
 *
 * Derived from the extension rather than from UTType, which would pull the
 * UniformTypeIdentifiers framework onto the target for one lookup.
 */
NS_INLINE NSString *MPMIMETypeForImageURL(NSURL *url)
{
    static NSDictionary *types = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = @{
            @"png": @"image/png",
            @"jpg": @"image/jpeg",
            @"jpeg": @"image/jpeg",
            @"gif": @"image/gif",
            @"svg": @"image/svg+xml",
            @"webp": @"image/webp",
            @"heic": @"image/heic",
            @"heif": @"image/heif",
            @"avif": @"image/avif",
            @"tif": @"image/tiff",
            @"tiff": @"image/tiff",
            @"bmp": @"image/bmp",
            @"ico": @"image/x-icon",
        };
    });
    NSString *type = types[url.pathExtension.lowercaseString];
    return type ? type : @"application/octet-stream";
}


- (NSString *)dataURIForImageURL:(NSURL *)imageURL
{
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:imageURL
                                        options:NSDataReadingMappedIfSafe
                                          error:&error];
    if (!data)
    {
        [self presentError:error];
        return nil;
    }
    return [NSString stringWithFormat:@"data:%@;base64,%@",
            MPMIMETypeForImageURL(imageURL),
            [data base64EncodedStringWithOptions:0]];
}

- (void)insertImageMarkupForURL:(NSURL *)imageURL embedded:(BOOL)embedded
{
    NSString *target = embedded
        ? [self dataURIForImageURL:imageURL]
        : MPMarkdownLinkTargetForFileURL(imageURL, self.fileURL);
    if (!target)
        return;

    NSRange selected = self.editor.selectedRange;

    // A selection is taken as the caption; otherwise the file name stands in,
    // which is at least a real alt text rather than an empty bracket.
    NSString *alt = selected.length
        ? [self.editor.string substringWithRange:selected]
        : imageURL.lastPathComponent.stringByDeletingPathExtension;

    NSString *markup =
        [NSString stringWithFormat:@"![%@](%@)", alt, target];

    [self.editor insertText:markup replacementRange:selected];
    self.editor.selectedRange =
        NSMakeRange(selected.location + markup.length, 0);
}

/** Base64 turns a binary file into document text, so a large image lands in
 * the editor as megabytes of one unbreakable line. Worth a question first.
 */
- (BOOL)confirmEmbeddingImageURL:(NSURL *)imageURL
{
    static const unsigned long long kWarnAboveBytes = 1024 * 1024;

    NSNumber *size = nil;
    [imageURL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
    if (!size || size.unsignedLongLongValue <= kWarnAboveBytes)
        return YES;

    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    NSString *readable =
        [formatter stringFromByteCount:(long long)size.unsignedLongLongValue];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(
        @"Embed this image in the document?",
        @"Large inline image confirmation");
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(
        @"%@ of image data will be written into the text as Base64, which is "
        @"roughly a third larger again. Linking the file instead keeps the "
        @"document small.",
        @"Large inline image confirmation"), readable];
    [alert addButtonWithTitle:NSLocalizedString(
        @"Embed", @"Large inline image confirmation")];
    [alert addButtonWithTitle:NSLocalizedString(
        @"Cancel", @"Large inline image confirmation")];

    return [alert runModal] == NSAlertFirstButtonReturn;
}



/** Puts an empty table in, the size you asked for.
 *
 * The header row and its separator come on top of the number of rows asked
 * for: those two are what make it a table rather than lines with bars in
 * them, and counting them would be asking the reader to know that.
 */
#pragma mark - Writing help

/** A spinner and a line of words, beside the word count.
 *
 * Because the wait had nothing to show for it. The model takes a moment to
 * open, and on a machine that has never compiled the Metal shaders the
 * first command takes three and a half seconds — for all of which the
 * application looked as though it had ignored the request. A wait that is
 * accounted for is a wait; an unaccounted one is a fault.
 *
 * Built here rather than in the nib: it is two views, and a nib would be
 * one more file to keep in step with twenty-six localisations.
 */
- (void)buildWritingStatusIfNeeded
{
    if (self.writingStatus)
        return;

    NSPopUpButton *counter = self.wordCountWidget;
    NSView *strip = counter.superview;
    if (!strip)
        return;

    NSProgressIndicator *spinner =
        [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    spinner.style = NSProgressIndicatorStyleSpinning;
    spinner.controlSize = NSControlSizeSmall;
    spinner.indeterminate = YES;
    spinner.displayedWhenStopped = NO;
    spinner.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *label = [NSTextField labelWithString:@""];
    label.font = [NSFont systemFontOfSize:11.0];
    label.textColor = [NSColor secondaryLabelColor];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 6.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row addView:spinner inGravity:NSStackViewGravityLeading];
    [row addView:label inGravity:NSStackViewGravityLeading];
    row.hidden = YES;

    [strip addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:counter.trailingAnchor
                                          constant:12.0],
        [row.centerYAnchor constraintEqualToAnchor:counter.centerYAnchor],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:
            strip.trailingAnchor constant:-12.0],
    ]];

    self.writingStatus = row;
    self.writingStatusLabel = label;
    self.writingSpinner = spinner;
}

- (void)showWritingStatus:(NSString *)text
{
    [self buildWritingStatusIfNeeded];
    self.writingStatusLabel.stringValue = text ?: @"";
    self.writingStatus.hidden = NO;
    [self.writingSpinner startAnimation:nil];
}

- (void)hideWritingStatus
{
    [self.writingSpinner stopAnimation:nil];
    self.writingStatus.hidden = YES;
    self.writingStatusLabel.stringValue = @"";
}

/// "Making it shorter…", from the command's own menu title.
- (NSString *)workingTitleForCommand:(MPWritingCommand)command
{
    return [NSString stringWithFormat:NSLocalizedString(@"%@…",
        @"Writing help in progress"),
        [MPWritingAssistant titleForCommand:command]];
}

/** Runs a writing command, loading the model first if it is not loaded.
 *
 * The loading is somebody else's business — one model serves every window
 * — and it happens off the main thread, so the first command after a cold
 * start answers a moment later than the rest. Nothing is shown for that
 * moment on purpose: a progress sheet for half a second is worse than a
 * half-second wait.
 */
- (void)runWritingCommand:(MPWritingCommand)command
{
    // Two waits, and they are told apart on screen: opening the model is
    // one thing and answering is another, and a reader who sees only a
    // spinner cannot tell a slow model from a stuck one.
    MPModelStore *store = [MPModelStore sharedStore];
    [self showWritingStatus:store.isGeneratorLoaded
        ? [self workingTitleForCommand:command]
        : NSLocalizedString(@"Opening the model…", @"Writing help")];

    __weak MPDocument *weakSelf = self;
    [store generatorWithCompletion:
        ^(id<MPTextGenerator> generator, NSError *error) {
        MPDocument *document = weakSelf;
        if (!document)
            return;
        if (!generator)
        {
            [document hideWritingStatus];
            [document presentWritingError:error];
            return;
        }
        [document showWritingStatus:
            [document workingTitleForCommand:command]];

        if (document.writingAssistant.generator != generator)
        {
            document.writingAssistant =
                [[MPWritingAssistant alloc] initWithGenerator:generator];
        }
        BOOL started = [document.writingAssistant runCommand:command
                                   onTextView:document.editor
                                   completion:^(NSError *failure) {
            [document hideWritingStatus];
            // Cancelling is the reader's own doing and needs no telling.
            if (failure && failure.code != MPTextGeneratorErrorCancelled)
                [document presentWritingError:failure];
        }];
        // Refused — nothing to work on, or one already running — and the
        // spinner would otherwise turn for a command that never began.
        if (!started)
            [document hideWritingStatus];
    }];
}

- (void)presentWritingError:(NSError *)error
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"The writing command could not run",
                                          @"Writing help failure");
    alert.informativeText = error.localizedDescription
        ?: NSLocalizedString(@"No reason was given.",
                             @"Writing help failure");
    [alert beginSheetModalForWindow:self.windowForSheet completionHandler:nil];
}

- (IBAction)improveWriting:(id)sender
{
    [self runWritingCommand:MPWritingCommandImprove];
}

- (IBAction)correctWriting:(id)sender
{
    [self runWritingCommand:MPWritingCommandCorrect];
}

- (IBAction)makeWritingFormal:(id)sender
{
    [self runWritingCommand:MPWritingCommandFormal];
}

- (IBAction)makeWritingPlain:(id)sender
{
    [self runWritingCommand:MPWritingCommandPlain];
}

- (IBAction)makeWritingShorter:(id)sender
{
    [self runWritingCommand:MPWritingCommandShorter];
}

- (IBAction)makeWritingLonger:(id)sender
{
    [self runWritingCommand:MPWritingCommandLonger];
}

- (IBAction)stopWritingHelp:(id)sender
{
    [self.writingAssistant cancel];
}

/** Puts a template in, on lines of its own.
 *
 * Where the caret is, not over the document: someone with a page of notes
 * who asks for a report skeleton wants it added, not their notes replaced.
 */
/** Makes an empty document beside this one, links to it, and opens it.
 *
 * The thing a note leads to before it exists. The selection is the name and
 * the link text, so writing "see the test plan", selecting three words of it
 * and pressing the key leaves a link in place and a file open at the other
 * end of it — which is how a set of notes actually grows.
 *
 * Empty, and not a template: what goes in it is the reader's business, and
 * a file that arrives with headings already in it is a file they have to
 * clear out first.
 *
 * A file that is already there is linked and opened, never overwritten. The
 * whole point is to reach the other document, and destroying it on the way
 * is not a lesser version of that.
 */
- (void)linkToNewMarkdownFileNamed:(NSString *)name
                    replacingRange:(NSRange)range
{
    if (!self.fileURL)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(
            @"Save this document first", @"New linked file");
        alert.informativeText = NSLocalizedString(
            @"A new file is made in the same folder as this one, and this "
            @"one has no folder yet.", @"New linked file");
        [alert beginSheetModalForWindow:self.windowForSheet
                      completionHandler:nil];
        return;
    }

    NSURL *url = MPNewMarkdownFileURLForName(name, self.fileURL);
    if (!url)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(
            @"That leaves nothing to name the file after",
            @"New linked file");
        alert.informativeText = NSLocalizedString(
            @"Select the words the link should say, and they will name the "
            @"file too.", @"New linked file");
        [alert beginSheetModalForWindow:self.windowForSheet
                      completionHandler:nil];
        return;
    }

    NSFileManager *files = [NSFileManager defaultManager];
    if (![files fileExistsAtPath:url.path])
    {
        NSError *error = nil;
        if (![@"" writeToURL:url atomically:YES encoding:NSUTF8StringEncoding
                        error:&error])
        {
            [self presentError:error];
            return;
        }
    }

    NSString *text = [name stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length)
        text = url.lastPathComponent.stringByDeletingPathExtension;

    NSString *markup = [NSString stringWithFormat:@"[%@](%@)", text,
        MPMarkdownLinkTargetForFileURL(url, self.fileURL)];

    if (NSMaxRange(range) > self.editor.string.length)
        range = self.editor.selectedRange;
    [self.editor insertText:markup replacementRange:range];
    self.editor.selectedRange =
        NSMakeRange(range.location + markup.length, 0);

    // And there it is, in its own tab.
    [self openOrCreateFileForUrl:url];
}

- (IBAction)linkToNewMarkdownFile:(id)sender
{
    NSRange selection = self.editor.selectedRange;
    NSString *name = selection.length
        ? [self.editor.string substringWithRange:selection] : @"";
    [self linkToNewMarkdownFileNamed:name replacingRange:selection];
}

/** The plus at the end of the tab bar.
 *
 * AppKit shows it only if something in the responder chain answers this,
 * and in a document-based application nothing does by default — so the bar
 * appears with no way to add to it, which reads as a missing button rather
 * than as a decision.
 *
 * A new untitled document, which joins the group because every document
 * window shares the tabbing identifier. ⌘T reaches the same code.
 */
- (IBAction)newWindowForTab:(id)sender
{
    NSError *error = nil;
    NSDocumentController *controller =
        [NSDocumentController sharedDocumentController];
    if (![controller openUntitledDocumentAndDisplay:YES error:&error] && error)
        [self presentError:error];
}

- (IBAction)insertDocumentTemplate:(id)sender
{
    MPDocumentTemplate *template = nil;
    if ([sender respondsToSelector:@selector(representedObject)])
        template = [sender representedObject];

    NSString *markdown = template.markdown;
    if (!markdown.length)
        return;

    NSRange selection = self.editor.selectedRange;
    NSString *text = self.editor.string;
    NSMutableString *insertion = [NSMutableString string];

    // A blank line before it unless it is already at the start of one, and
    // one after, so it is a block and not a continuation of a sentence.
    NSRange line = [text lineRangeForRange:NSMakeRange(selection.location, 0)];
    if (selection.location != line.location)
        [insertion appendString:@"\n\n"];
    [insertion appendString:markdown];
    if (![markdown hasSuffix:@"\n"])
        [insertion appendString:@"\n"];

    [self.editor insertText:insertion replacementRange:selection];
    // At the top of what was inserted: the first field is what gets filled
    // in, and it is easier to walk down from there than to find the way back.
    self.editor.selectedRange =
        NSMakeRange(selection.location + (selection.location != line.location
                                          ? 2 : 0), 0);
    [self.editor scrollRangeToVisible:self.editor.selectedRange];
}

- (IBAction)insertTable:(id)sender
{
    static NSUInteger lastRows = 3;
    static NSUInteger lastColumns = 3;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Insert a table",
                                          @"Table size sheet title");
    alert.informativeText = NSLocalizedString(
        @"A header row is added above the rows you ask for.",
        @"Table size sheet explanation");
    [alert addButtonWithTitle:NSLocalizedString(@"Insert",
                                                @"Table size sheet button")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel",
                                                @"Table size sheet button")];

    MPTableSizeAccessory *accessory =
        [[MPTableSizeAccessory alloc] initWithRows:lastRows
                                           columns:lastColumns];
    alert.accessoryView = accessory;

    NSWindow *window = self.windowForSheet;
    void (^insert)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn)
            return;
        lastRows = accessory.rows;
        lastColumns = accessory.columns;
        [self insertTableWithRows:lastRows columns:lastColumns];
    };

    if (window)
    {
        [alert beginSheetModalForWindow:window completionHandler:insert];
        // The number is what the sheet is for, so it is what is ready to type.
        [window makeFirstResponder:accessory.rowsField];
    }
    else
    {
        insert([alert runModal]);
    }
}

- (void)insertTableWithRows:(NSUInteger)rows columns:(NSUInteger)columns
{
    NSString *table = [MPTableSource emptyTableWithRows:rows columns:columns];
    if (!table.length)
        return;

    // On lines of its own: a table that starts halfway through a paragraph is
    // not a table, and the blank line after it keeps the next one out.
    NSRange selection = self.editor.selectedRange;
    NSString *text = self.editor.string;
    NSMutableString *insertion = [NSMutableString string];

    NSRange line = [text lineRangeForRange:NSMakeRange(selection.location, 0)];
    BOOL atLineStart = selection.location == line.location;
    if (!atLineStart)
        [insertion appendString:@"\n"];
    if (selection.location > 0)
    {
        // A blank line above, unless there already is one.
        NSUInteger before = atLineStart ? selection.location
                                        : NSMaxRange(line);
        NSString *above = [text substringToIndex:MIN(before, text.length)];
        if (![above hasSuffix:@"\n\n"])
            [insertion appendString:@"\n"];
    }

    NSUInteger caret = insertion.length + 2;    // Inside the first cell.
    [insertion appendString:table];
    [insertion appendString:@"\n"];

    if (![self.editor shouldChangeTextInRange:selection
                            replacementString:insertion])
        return;
    [self.editor.textStorage replaceCharactersInRange:selection
                                           withString:insertion];
    [self.editor didChangeText];
    self.editor.selectedRange =
        NSMakeRange(MIN(selection.location + caret, self.editor.string.length),
                    0);
}

- (IBAction)toggleImage:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.message = NSLocalizedString(
        @"Choose an image to link in the document",
        @"Image chooser prompt");

    // Deprecated in favour of -allowedContentTypes, which needs UTType from
    // UniformTypeIdentifiers and so a new framework on the target. Left as is
    // rather than growing the project file for a filter.
    panel.allowedFileTypes = [NSImage imageTypes];

    NSButton *embedToggle = [NSButton checkboxWithTitle:NSLocalizedString(
        @"Embed the image in the document (Base64)",
        @"Image chooser option") target:nil action:NULL];
    embedToggle.toolTip = NSLocalizedString(
        @"Writes the image data inline instead of linking the file, so the "
        @"document no longer depends on it. Note that some sites, GitHub "
        @"among them, strip inline image data.",
        @"Image chooser option help");
    embedToggle.frame = NSMakeRect(18.0, 10.0, 384.0, 20.0);

    NSView *accessory =
        [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 420.0, 40.0)];
    [accessory addSubview:embedToggle];
    panel.accessoryView = accessory;
    panel.accessoryViewDisclosed = YES;

    NSWindow *window = self.windowForSheet;
    void (^handler)(NSModalResponse) = ^(NSModalResponse result) {
        if (result != NSModalResponseOK)
            return;
        NSURL *url = panel.URLs.firstObject;
        if (!url)
            return;

        BOOL embedded = (embedToggle.state == NSControlStateValueOn);
        if (embedded && ![self confirmEmbeddingImageURL:url])
            return;

        [self insertImageMarkupForURL:url embedded:embedded];
    };

    if (window)
        [panel beginSheetModalForWindow:window completionHandler:handler];
    else
        handler([panel runModal]);
}

- (IBAction)toggleOrderedList:(id)sender
{
    [self.editor toggleBlockWithPattern:@"^[0-9]+ \\S" prefix:@"1. "];
}

- (IBAction)toggleUnorderedList:(id)sender
{
    NSString *marker = self.preferences.editorUnorderedListMarker;
    [self.editor toggleBlockWithPattern:@"^[\\*\\+-] \\S" prefix:marker];
}

- (IBAction)toggleBlockquote:(id)sender
{
    [self.editor toggleBlockWithPattern:@"^> \\S" prefix:@"> "];
}

- (IBAction)indent:(id)sender
{
    NSString *padding = @"\t";
    if (self.preferences.editorConvertTabs)
        padding = @"    ";
    [self.editor indentSelectedLinesWithPadding:padding];
}

- (IBAction)unindent:(id)sender
{
    [self.editor unindentSelectedLines];
}

- (IBAction)insertNewParagraph:(id)sender
{
    NSRange range = self.editor.selectedRange;
    NSUInteger location = range.location;
    NSUInteger length = range.length;
    NSString *content = self.editor.string;
    NSInteger newlineBefore = [content locationOfFirstNewlineBefore:location];
    NSUInteger newlineAfter =
        [content locationOfFirstNewlineAfter:location + length - 1];

    // If we are on an empty line, treat as normal return key; otherwise insert
    // two newlines.
    if (location == newlineBefore + 1 && location == newlineAfter)
        [self.editor insertNewline:self];
    else
        [self.editor insertText:@"\n\n"];
}

- (IBAction)setEditorOneQuarter:(id)sender
{
    [self setSplitViewDividerLocation:0.25];
}

- (IBAction)setEditorThreeQuarters:(id)sender
{
    [self setSplitViewDividerLocation:0.75];
}

- (IBAction)setEqualSplit:(id)sender
{
    [self setSplitViewDividerLocation:0.5];
}

/** Turns the prose underlines on and off.
 *
 * Per window rather than a stored preference: it is a thing you switch on to
 * go over a draft, not a way you leave the editor set up.
 */
/** Wraps the editor/preview split in a second one, with the sidebar first.
 *
 * Done here rather than in the nib because the nib pins the existing split
 * view to the window, and moving it means taking those constraints with it.
 */
- (void)installSidebarInWindow:(NSWindow *)window
{
    NSView *content = window.contentView;
    NSView *panes = self.splitView;
    if (!content || !panes || self.outerSplitView)
        return;

    self.sidebar = [[MPSidebarController alloc] init];
    self.sidebar.delegate = self;

    NSMutableArray<NSLayoutConstraint *> *stale = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in content.constraints)
    {
        if (constraint.firstItem == panes || constraint.secondItem == panes)
            [stale addObject:constraint];
    }
    [content removeConstraints:stale];
    [panes removeFromSuperview];

    NSSplitView *outer = [[NSSplitView alloc] initWithFrame:content.bounds];
    outer.vertical = YES;
    outer.dividerStyle = NSSplitViewDividerStyleThin;
    // The sidebar is delegate of its own split view: it owns the width
    // rules, and this document is already delegate of the inner one.
    outer.delegate = (id<NSSplitViewDelegate>)self.sidebar;
    // No autosave name. NSSplitView restores a saved position after the
    // subviews are in place, which lands on top of the position set below
    // and leaves the sidebar as an unusable sliver.
    outer.translatesAutoresizingMaskIntoConstraints = NO;

    [outer addSubview:self.sidebar.view];
    [outer addSubview:panes];
    [content addSubview:outer];

    [NSLayoutConstraint activateConstraints:@[
        [outer.topAnchor constraintEqualToAnchor:content.topAnchor],
        [outer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [outer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [outer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    ]];

    // The panes take the space; the sidebar keeps the width it was given.
    [outer setHoldingPriority:NSLayoutPriorityDefaultHigh
           forSubviewAtIndex:0];
    self.outerSplitView = outer;

    // Closed to begin with: a sidebar nobody asked for is in the way.
    [outer setPosition:0.0 ofDividerAtIndex:0];

    [self.sidebar setRootURL:self.fileURL.URLByDeletingLastPathComponent];
    [self.sidebar updateOutlineWithMarkdown:self.editor.string ?: @""];
}

/// Whether the sidebar is open, as the menu and the toggle both need to know.
- (BOOL)sidebarVisible
{
    NSSplitView *outer = self.outerSplitView;
    NSView *sidebar = outer.subviews.firstObject;
    return outer && sidebar && ![outer isSubviewCollapsed:sidebar]
        && sidebar.frame.size.width > 1.0;
}

- (IBAction)toggleSidebar:(id)sender
{
    NSSplitView *outer = self.outerSplitView;
    if (!outer)
        return;

    BOOL visible = self.sidebarVisible;
    [outer setPosition:(visible ? 0.0 : 240.0) ofDividerAtIndex:0];
    [outer adjustSubviews];

    if (!visible)
    {
        [self.sidebar setRootURL:self.fileURL.URLByDeletingLastPathComponent];
        [self.sidebar updateOutlineWithMarkdown:self.editor.string ?: @""];
    }
}

#pragma mark - MPSidebarControllerDelegate

- (void)sidebarDidSelectHeadingRange:(NSRange)range
{
    if (NSMaxRange(range) > self.editor.string.length)
        return;

    // Selecting the heading line, rather than only scrolling to it, makes it
    // obvious where you have landed.
    [self.editor setSelectedRange:range];
    [self.editor scrollRangeToVisible:range];
    [self.windowForSheet makeFirstResponder:self.editor];
}

- (void)sidebarDidSelectFileURL:(NSURL *)url
{
    [[NSDocumentController sharedDocumentController]
        openDocumentWithContentsOfURL:url display:YES
                    completionHandler:^(NSDocument *document,
                                        BOOL alreadyOpen, NSError *error) {
        (void)document; (void)alreadyOpen; (void)error;
    }];
}


/** Opens the maths sheet and inserts what comes back.
 *
 * The delimiters are chosen here rather than in the sheet, because which
 * ones a document wants is a preference: inline maths is written with
 * dollars only when the user has asked for that, and with \( \) otherwise.
 */
- (IBAction)showMathEditor:(id)sender
{
    NSWindow *window = self.windowForSheet;
    if (!window)
        return;

    // A selection is treated as a formula to edit rather than replaced
    // blindly, so the sheet can be used to fix an expression as well as
    // write one.
    NSRange selected = self.editor.selectedRange;
    NSString *initial = selected.length
        ? [self.editor.string substringWithRange:selected] : nil;

    __weak MPDocument *weakSelf = self;
    [MPMathEditorController presentForWindow:window initialTeX:initial
                                  completion:^(NSString *tex, BOOL display) {
        MPDocument *self = weakSelf;
        if (!self || !tex.length)
            return;

        NSString *markup;
        if (display)
        {
            markup = [NSString stringWithFormat:@"$$%@$$", tex];
        }
        else if (self.preferences.htmlMathJaxInlineDollar)
        {
            markup = [NSString stringWithFormat:@"$%@$", tex];
        }
        else
        {
            markup = [NSString stringWithFormat:@"\\(%@\\)", tex];
        }

        // Through the text view, so it lands in the undo stack like any
        // other edit.
        [self.editor insertText:markup
               replacementRange:self.editor.selectedRange];
    }];
}

- (IBAction)toggleProseHighlights:(id)sender
{
    BOOL on = !self.editor.proseHighlightsEnabled;
    self.editor.proseHighlightsEnabled = on;

    // Remembered, so the choice outlives the window it was made in. It used
    // to live only on the editor, which meant switching it on and reopening
    // the document switched it off again.
    self.preferences.editorProseHighlights = on;
    [self updateProseSummary];
}

/** Puts the tally in the window subtitle, which is otherwise unused, so the
 * count needs no widget of its own.
 *
 * It was a button in the title bar for a day. A tally reading "attenuazioni:
 * 3 · perifrasi allungate: 2 · spie del passivo: 5" is a sentence, and a
 * sentence on a button takes the width of the toolbar away from the
 * toolbar. Under the title it costs nothing, and the list it used to open
 * is on the menu instead — ⌃⌥⌘P, beside the switch that draws the
 * underlines.
 */
- (void)updateProseSummary
{
    NSWindow *window = self.windowForSheet;
    if (!window)
        return;

    if (!self.editor.proseHighlightsEnabled)
    {
        window.subtitle = @"";
        return;
    }

    MPProseChecker *checker = [MPProseChecker sharedChecker];
    NSArray<MPProseIssue *> *issues =
        [checker issuesInString:self.editor.string ?: @""];
    NSString *summary = [checker summaryForIssues:issues];
    self.proseIssueCount = issues.count;
    window.subtitle = summary ?: NSLocalizedString(
        @"nothing flagged", @"prose checker found no issues");
}

/** The list of what is flagged, and going to one of them.
 *
 * Read again on opening rather than kept: between the tally being written
 * and the button being pressed the document may have been typed in, and a
 * list of ranges that have moved sends the caret to the wrong words.
 */
- (IBAction)showProseIssues:(id)sender
{
    if (self.prosePopover.isShown)
    {
        [self.prosePopover close];
        return;
    }

    MPProseChecker *checker = [MPProseChecker sharedChecker];
    NSString *text = self.editor.string ?: @"";
    NSArray<MPProseIssue *> *issues = [checker issuesInString:text];
    if (!issues.count)
        return;

    __weak MPDocument *document = self;
    MPProseIssuesViewController *list =
        [[MPProseIssuesViewController alloc] initWithIssues:issues
            inText:text summary:[checker summaryForIssues:issues]
            chosen:^(MPProseIssue *issue) {
        [document goToProseIssue:issue];
    } fixed:^(MPProseIssue *issue) {
        [document applyProseFix:issue];
    }];

    NSPopover *popover = [[NSPopover alloc] init];
    popover.contentViewController = list;
    popover.behavior = NSPopoverBehaviorTransient;
    popover.contentSize = list.view.frame.size;
    self.prosePopover = popover;

    // Hung under the top of the text rather than off a button, since there
    // is no button any more: the list is about the words in view.
    NSView *anchor = self.editor;
    NSRect top = anchor.visibleRect;
    top.size.height = 1.0;
    [popover showRelativeToRect:top ofView:anchor
                 preferredEdge:NSRectEdgeMaxY];
}

/** The one correction the prose panel offers: the space after the hashes.
 *
 * Done through the text view rather than the storage, so it is one undo
 * away and the highlighter hears about it. The text is checked before it is
 * replaced: the panel is a list taken a moment ago, and the document may
 * have moved under it.
 */
- (void)applyProseFix:(MPProseIssue *)issue
{
    if (!issue.replacement.length || !issue.text.length)
        return;

    NSRange range = issue.range;
    NSString *text = self.editor.string;
    if (NSMaxRange(range) > text.length
        || ![[text substringWithRange:range] isEqualToString:issue.text])
    {
        MPNote(@"fix skipped: the text moved");
        return;
    }

    if (![self.editor shouldChangeTextInRange:range
                            replacementString:issue.replacement])
        return;
    [self.editor.textStorage replaceCharactersInRange:range
                                           withString:issue.replacement];
    [self.editor didChangeText];
    MPNote(@"fixed “%@” to “%@” at %lu", issue.text, issue.replacement,
           (unsigned long)range.location);

    // The list behind the panel is now one line out of date, and the tally
    // under the title is redrawn from the document anyway.
    [self.prosePopover close];
    self.prosePopover = nil;
}


#pragma mark - Peeking at a link

/** The card for a link the pointer has been resting on.
 *
 * Nothing is fetched: for a document in the same folder the answer is in
 * the file, and for an address the answer is the address, taken apart so a
 * long one can be read. A card that made a request would tell somebody's
 * server that you hovered.
 */
- (void)showLinkPreviewFor:(NSDictionary *)body
{
    MPLinkPreview *preview = [MPLinkPreview
        previewForHref:body[@"href"] inDocument:self.fileURL];
    if (!preview)
        return;

    [self hideLinkPreview];

    /* A web link, when the reader has asked for pages to be looked up.
     *
     * The address alone says where a link goes and nothing about what is
     * there, which is what somebody hovering a link in an article wants to
     * know. So the page is asked — once, and only with the preference on —
     * and the card is shown when the answer arrives. Four seconds at the
     * outside, and the pointer moving on cancels it: `hideLinkPreview`
     * moves the token this checks.
     */
    if (preview.kind == MPLinkPreviewKindAddress
        && self.preferences.previewFetchesLinkPages)
    {
        self.hoverToken++;
        NSUInteger token = self.hoverToken;
        __weak MPDocument *weakSelf = self;
        MPFetchPageSummary(preview.fileURL ?: [NSURL URLWithString:
                               body[@"href"]],
                           ^(NSString *title, NSString *summary) {
            MPDocument *strong = weakSelf;
            if (!strong || strong.hoverToken != token)
                return;     // the pointer has moved on
            if (title.length)
                [preview setValue:title forKey:@"title"];
            if (summary.length)
                [preview setValue:summary forKey:@"body"];
            [strong showCard:preview at:body];
        });
        return;
    }

    [self showCard:preview at:body];
}

- (void)showCard:(MPLinkPreview *)preview at:(NSDictionary *)body
{
    // With the lookup off, the card can only take the address apart, and a
    // reader who expected to see what is on the other side deserves to know
    // where the switch is rather than to wonder what the card is for.
    if (preview.kind == MPLinkPreviewKindAddress
        && !self.preferences.previewFetchesLinkPages)
    {
        [preview setValue:NSLocalizedString(
            @"To learn what it is about: Settings ▸ Rendering ▸ “Ask a web "
            @"page what it is”",
            @"Hint on the card for a web link when the lookup is off")
                   forKey:@"footnote"];
    }


    MPLinkPreviewViewController *card = [[MPLinkPreviewViewController alloc]
        initWithPreview:preview];
    NSPopover *popover = [[NSPopover alloc] init];
    popover.contentViewController = card;
    // Not transient: it is dismissed by the pointer leaving the link, which
    // the page reports, and a click in the page should follow the link
    // rather than merely closing a card.
    popover.behavior = NSPopoverBehaviorApplicationDefined;
    popover.animates = NO;
    popover.contentSize = card.view.fittingSize;
    self.linkPopover = popover;

    // Where the link is, in the view's own coordinates. WKWebView is
    // flipped, so the rectangle the page reports needs the zoom allowed for
    // and nothing else; see MPLinkRectInView.
    NSRect where = MPLinkRectInView(body, self.preview.pageZoom,
                                    self.preview.isFlipped,
                                    NSHeight(self.preview.bounds));

    if (!NSIntersectsRect(where, self.preview.bounds))
        return;   // scrolled away between the report and now
    [popover showRelativeToRect:where ofView:self.preview
                  preferredEdge:NSRectEdgeMaxY];
}

- (void)hideLinkPreview
{
    self.hoverToken++;
    [self.linkPopover close];
    self.linkPopover = nil;
}


#pragma mark - Clipping a page

/// One alert, since three places here have something to say and go wrong.
- (void)say:(NSString *)title text:(NSString *)text
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title ?: @"";
    alert.informativeText = text ?: @"";
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Confirm")];

    NSWindow *window = self.windowForSheet;
    if (window)
        [alert beginSheetModalForWindow:window completionHandler:nil];
    else
        [alert runModal];
}


/** Saves a web page as a Markdown file beside this document.
 *
 * For collecting evidence: a page that backs a statement in a report is
 * worth keeping next to the report, and keeping it as Markdown means it is
 * still readable when the page is gone. The conversion is the one used for
 * pasting, so what arrives is what copying the page would have given.
 */
- (IBAction)clipWebPage:(id)sender
{
    // An address on the clipboard is almost certainly the one.
    NSString *pasted = [[NSPasteboard generalPasteboard]
        URLForType:NSPasteboardTypeString].absoluteString;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Save a Web Page as Markdown",
                                          @"Web clipping");
    // What happens next depends on whether this document has a folder to put
    // a file in, so the question says which of the two it will be.
    alert.informativeText = self.fileURL
        ? NSLocalizedString(
            @"The file lands beside the document, with the address and the "
            @"date at the top, and a link to it goes where the cursor is. "
            @"Whatever the conversion does not recognize leaves its text "
            @"behind and nothing else.", @"Web clipping")
        : NSLocalizedString(
            @"This document has not been saved yet, so the clipping opens as "
            @"a new document, to save wherever you like. The address and the "
            @"date are at the top.", @"Web clipping");
    [alert addButtonWithTitle:NSLocalizedString(@"Save", @"Web clipping")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];

    NSTextField *field = [NSTextField textFieldWithString:pasted ?: @""];
    field.placeholderString = @"https://";
    field.frame = NSMakeRect(0.0, 0.0, 380.0, 22.0);
    alert.accessoryView = field;

    NSWindow *window = self.windowForSheet;
    void (^go)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn)
            return;
        NSString *typed = [field.stringValue stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSURL *url = typed.length ? [NSURL URLWithString:typed] : nil;
        if (!url.scheme.length || !url.host.length)
        {
            [self say:NSLocalizedString(@"That address is not valid",
                                        @"Web clipping")
                 text:typed];
            return;
        }
        [self clipFromURL:url];
    };

    if (window)
    {
        [alert beginSheetModalForWindow:window completionHandler:go];
        [window makeFirstResponder:field];
    }
    else
    {
        go([alert runModal]);
    }
}

- (void)clipFromURL:(NSURL *)url
{
    MPNote(@"clipping %@", url.absoluteString);
    __weak MPDocument *document = self;
    [MPWebClipper clipURL:url completion:^(NSString *markdown,
                                           NSString *title, NSError *error) {
        MPDocument *strong = document;
        if (!strong)
            return;
        if (!markdown)
        {
            MPNote(@"  not clipped: %@", error.localizedDescription);
            [strong say:NSLocalizedString(@"The page could not be saved",
                                          @"Web clipping")
                   text:error.localizedDescription];
            return;
        }

        // No folder to put a file in: the clipping becomes a document of
        // its own, and where it goes is asked when its window closes.
        if (!strong.fileURL)
        {
            [strong openClippingAsANewDocument:markdown];
            return;
        }

        NSURL *folder = strong.fileURL.URLByDeletingLastPathComponent;
        NSURL *file = [folder URLByAppendingPathComponent:
            MPFileNameForClipping(title, url)];
        // Never over something that is already there: a clipping is a new
        // document, and two pages can share a title.
        NSUInteger attempt = 2;
        while ([[NSFileManager defaultManager] fileExistsAtPath:file.path])
        {
            NSString *stem = MPFileNameForClipping(title, url)
                .stringByDeletingPathExtension;
            file = [folder URLByAppendingPathComponent:[NSString
                stringWithFormat:@"%@-%lu.md", stem,
                (unsigned long)attempt++]];
        }

        NSError *writing = nil;
        if (![markdown writeToURL:file atomically:YES
                         encoding:NSUTF8StringEncoding error:&writing])
        {
            MPNote(@"  not written: %@", writing.localizedDescription);
            [strong say:NSLocalizedString(@"The page could not be written",
                                          @"Web clipping")
                   text:writing.localizedDescription];
            return;
        }
        MPNote(@"  written %@ (%lu characters)", file.path,
               (unsigned long)markdown.length);

        // Linked where the caret is: a clipping taken while writing a report
        // is evidence for what is being written there, and a file in the
        // folder that nothing points at is a file nobody finds again.
        NSString *target = MPMarkdownLinkTargetForFileURL(file,
                                                          strong.fileURL);
        if (target.length)
        {
            NSRange selected = strong.editor.selectedRange;
            NSString *markup = [NSString stringWithFormat:@"[%@](%@)",
                title ?: file.lastPathComponent.stringByDeletingPathExtension,
                target];
            [strong.editor insertText:markup replacementRange:selected];
            strong.editor.selectedRange =
                NSMakeRange(selected.location + markup.length, 0);
        }

        // And opened in a tab, since the point of taking it is reading it.
        [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:file display:YES
                        completionHandler:^(NSDocument *opened, BOOL was,
                                            NSError *failure) {
            if (failure)
                [strong presentError:failure];
        }];
    }];
}


#pragma mark - Writing aids

/** The two writing modes, from the menu as well as the preferences.
 *
 * One switch, not two: a mode that is on in the menu and off in the
 * preferences is a mode nobody can find again.
 */
- (IBAction)toggleFocusMode:(id)sender
{
    BOOL on = !self.preferences.editorFocusMode;
    self.preferences.editorFocusMode = on;
    self.editor.focusModeEnabled = on;
    MPNote(@"focus mode: %@", on ? @"on" : @"off");
}

- (IBAction)toggleTypewriterScrolling:(id)sender
{
    BOOL on = !self.preferences.editorTypewriter;
    self.preferences.editorTypewriter = on;
    self.editor.typewriterEnabled = on;
    MPNote(@"typewriter scrolling: %@", on ? @"on" : @"off");
}


#pragma mark - Task lists

/** Moves the finished items of the list at the caret to the end of it.
 *
 * A command rather than something that happens by itself, unlike Bear's:
 * reordering somebody's lines while they are typing them is invasive, and
 * a list is often in the order it is in on purpose.
 */
- (IBAction)moveDoneTasksToEnd:(id)sender
{
    NSRange replaced = NSMakeRange(NSNotFound, 0);
    NSString *sorted = MPTasksMovedToEnd(self.editor.string ?: @"",
        self.editor.selectedRange.location, &replaced);
    if (!sorted || replaced.location == NSNotFound)
    {
        MPNote(@"done tasks to the bottom: nothing to move");
        return;
    }

    if (![self.editor shouldChangeTextInRange:replaced
                            replacementString:sorted])
        return;
    [self.editor insertText:sorted replacementRange:replaced];
    // The whole list stays selected: what moved is worth seeing, and one
    // undo takes it back.
    self.editor.selectedRange = NSMakeRange(replaced.location,
                                            sorted.length);
    MPNote(@"done tasks to the bottom: %lu characters rewritten",
           (unsigned long)sorted.length);
}


#pragma mark - Reading rather than writing

/** Stops the document being changed, and says so.
 *
 * An evidence file that is closed, or a report that has been signed, is not
 * meant to be edited — and the only defence until now was remembering that.
 * Nothing is written to the file and nothing is remembered: it is a state
 * of this window, for as long as it is open.
 */
- (IBAction)toggleReadOnly:(id)sender
{
    self.readOnly = !self.readOnly;
    self.editor.editable = !self.readOnly;
    // A caret blinking in a document that refuses to change is a lie.
    self.editor.selectable = YES;
    [self updateReadOnlyBadge];
    MPNote(@"read only: %@", self.readOnly ? @"on" : @"off");
}

/// The badge in the title bar, made once and hidden when it is not wanted.
- (void)updateReadOnlyBadge
{
    NSWindow *window = self.windowForSheet;
    if (!window)
        return;

    if (!self.readOnlyBadge)
    {
        NSTextField *label = [NSTextField labelWithString:
            NSLocalizedString(@"Read only", @"Read-only badge")];
        label.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        label.textColor = [NSColor secondaryLabelColor];
        label.frame = NSMakeRect(6.0, 4.0, 88.0, 16.0);

        NSImageView *lock = [NSImageView imageViewWithImage:
            [NSImage imageWithSystemSymbolName:@"lock.fill"
                      accessibilityDescription:nil]
                ?: [NSImage imageNamed:NSImageNameLockLockedTemplate]];
        lock.contentTintColor = [NSColor secondaryLabelColor];
        lock.frame = NSMakeRect(96.0, 4.0, 14.0, 16.0);

        NSView *holder = [[NSView alloc] initWithFrame:
            NSMakeRect(0.0, 0.0, 118.0, 24.0)];
        [holder addSubview:label];
        [holder addSubview:lock];

        NSTitlebarAccessoryViewController *badge =
            [[NSTitlebarAccessoryViewController alloc] init];
        badge.view = holder;
        badge.layoutAttribute = NSLayoutAttributeRight;
        self.readOnlyBadge = badge;
        [window addTitlebarAccessoryViewController:badge];
    }
    self.readOnlyBadge.hidden = !self.readOnly;
}

/** Whether a command would change the document.
 *
 * The text view refuses what is typed into it, but not what is done to it:
 * `insertText:replacementRange:` is the programmatic path and does not ask
 * whether the view is editable. So the commands that edit are named here
 * and refused while the document is being read. Named rather than guessed:
 * a list that has to be added to when a command is added is a list that
 * says out loud what edits.
 */
static BOOL MPActionEditsTheDocument(SEL action)
{
    static NSSet *editing = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        editing = [NSSet setWithArray:@[
            @"toggleStrong:", @"toggleEmphasis:", @"toggleUnderline:",
            @"toggleHighlight:", @"toggleStrikethrough:", @"toggleComment:",
            @"toggleInlineCode:", @"insertCode:", @"insertCodeBlock:",
            @"toggleLink:", @"toggleImage:", @"insertTable:",
            @"toggleBlockquote:", @"toggleUnorderedList:",
            @"toggleOrderedList:", @"indent:", @"unindent:",
            @"convertToH1:", @"convertToH2:", @"convertToH3:",
            @"convertToH4:", @"convertToH5:", @"convertToH6:",
            @"convertToParagraph:", @"insertNewParagraph:",
            @"showMathEditor:", @"insertTemplate:",
            @"linkToNewMarkdownFile:",
            @"improveWriting:", @"correctWriting:", @"makeWritingFormal:",
            @"makeWritingPlain:", @"makeWritingShorter:",
            @"makeWritingLonger:", @"moveDoneTasksToEnd:",
        ]];
    });
    return [editing containsObject:NSStringFromSelector(action)];
}


/** A clipping taken while the notes it belongs to are still untitled.
 *
 * A page worth keeping is worth keeping even before the document beside it
 * has a name. It opens as a new document with the clipping in it, marked as
 * changed so that closing the window asks where to put it — the text was
 * put there from here rather than typed, and an unsaved clipping that goes
 * away without asking is a clipping thrown away.
 */
- (BOOL)openClippingAsANewDocument:(NSString *)markdown
{
    NSDocumentController *controller =
        [NSDocumentController sharedDocumentController];
    NSError *making = nil;
    MPDocument *fresh = [controller openUntitledDocumentAndDisplay:YES
                                                             error:&making];
    if (!fresh)
    {
        MPNote(@"  not opened: %@", making.localizedDescription);
        [self say:NSLocalizedString(@"The clipping could not be opened",
                                    @"Web clipping")
             text:making.localizedDescription];
        return NO;
    }

    fresh.markdown = markdown;
    [fresh updateChangeCount:NSChangeDone];
    MPNote(@"  opened as a new document (%lu characters)",
           (unsigned long)markdown.length);
    return YES;
}


/** Which documents in this folder cite this one.
 *
 * A link says where it goes and nothing says what points here, so this was
 * a `grep`. The folder is read again on each asking rather than watched:
 * the answer is wanted a few times a day, and a watcher on a tree of
 * documents is a thing to get wrong.
 */
- (IBAction)showBacklinks:(id)sender
{
    if (self.backlinkPopover.isShown)
    {
        [self.backlinkPopover close];
        return;
    }
    if (!self.fileURL)
        return;

    NSURL *folder = self.fileURL.URLByDeletingLastPathComponent;
    MPNote(@"looking for what links %@ in %@", self.fileURL.lastPathComponent,
           folder.path);
    __weak MPDocument *document = self;
    [MPBacklinkFinder findLinksTo:self.fileURL inFolder:folder
                       completion:^(NSArray<MPBacklink *> *found,
                                    NSUInteger read) {
        MPNote(@"  %lu links in %lu documents read",
               (unsigned long)found.count, (unsigned long)read);
        [document showBacklinkList:found counted:read];
    }];
}

- (void)showBacklinkList:(NSArray<MPBacklink *> *)found
                 counted:(NSUInteger)read
{
    __weak MPDocument *document = self;
    MPBacklinksViewController *list = [[MPBacklinksViewController alloc]
        initWithBacklinks:found counted:read chosen:^(MPBacklink *link) {
        [document goToBacklink:link];
    }];

    NSPopover *popover = [[NSPopover alloc] init];
    popover.contentViewController = list;
    popover.behavior = NSPopoverBehaviorTransient;
    popover.contentSize = list.view.frame.size;
    self.backlinkPopover = popover;

    NSView *anchor = self.editor;
    NSRect top = anchor.visibleRect;
    top.size.height = 1.0;
    [popover showRelativeToRect:top ofView:anchor
                 preferredEdge:NSRectEdgeMaxY];
}

/// Opens the document that cites this one, at the line that does the citing.
- (void)goToBacklink:(MPBacklink *)link
{
    [self.backlinkPopover close];

    NSDocumentController *controller =
        [NSDocumentController sharedDocumentController];
    [controller openDocumentWithContentsOfURL:link.documentURL display:YES
        completionHandler:^(NSDocument *opened, BOOL wasOpen, NSError *error) {
        if (error)
        {
            [self presentError:error];
            return;
        }
        if ([opened isKindOfClass:[MPDocument class]])
            [(MPDocument *)opened goToRange:link.range];
    }];
}

/** Shows a place in this document and selects it.
 *
 * Called on a document that has just been opened as well as on this one, so
 * it waits for the text to be there: a document displays before its
 * contents have been put in the editor, and a range set against an empty
 * editor is a caret at the start.
 */
- (void)goToRange:(NSRange)range
{
    if (NSMaxRange(range) > self.editor.string.length)
    {
        // The text is not in yet. One turn of the run loop is what the
        // opening takes; more than a second means it was never coming.
        static const NSInteger kMPTries = 40;
        __block NSInteger left = kMPTries;
        __weak MPDocument *document = self;
        void (^__block again)(void) = nil;
        void (^attempt)(void) = ^{
            MPDocument *strong = document;
            if (!strong || left-- <= 0)
            {
                again = nil;
                return;
            }
            if (NSMaxRange(range) <= strong.editor.string.length)
            {
                again = nil;
                [strong goToRange:range];
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                (int64_t)(0.025 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{ if (again) again(); });
        };
        again = attempt;
        attempt();
        return;
    }

    self.editor.selectedRange = range;
    [self.editor scrollRangeToVisible:range];
    [self.windowForSheet makeFirstResponder:self.editor];
}

- (void)goToProseIssue:(MPProseIssue *)issue
{
    NSRange range = issue.range;
    if (NSMaxRange(range) > self.editor.string.length)
        return;

    // Selected rather than a caret next to it: the point is to see which
    // words were meant.
    self.editor.selectedRange = range;
    [self.editor scrollRangeToVisible:range];
    [self.windowForSheet makeFirstResponder:self.editor];
    [self.prosePopover close];
}

- (IBAction)toggleToolbar:(id)sender
{
    [self.windowForSheet toggleToolbarShown:sender];
    [self adjustPreviewContentInsets];
}

- (IBAction)togglePreviewPane:(id)sender
{
    [self toggleSplitterCollapsingEditorPane:NO];
}

- (IBAction)toggleEditorPane:(id)sender
{
    [self toggleSplitterCollapsingEditorPane:YES];
}

- (IBAction)render:(id)sender
{
    [self.renderer parseAndRenderLater];
}


#pragma mark - Private

- (void)toggleSplitterCollapsingEditorPane:(BOOL)forEditorPane
{
    BOOL isVisible = forEditorPane ? self.editorVisible : self.previewVisible;
    BOOL editorOnRight = self.preferences.editorOnRight;

    float targetRatio = ((forEditorPane == editorOnRight) ? 1.0 : 0.0);

    if (isVisible)
    {
        CGFloat oldRatio = self.splitView.dividerLocation;
        if (oldRatio != 0.0 && oldRatio != 1.0)
        {
            // We don't want to save these values, since they are meaningless.
            // The user should be able to switch between 100% editor and 100%
            // preview without losing the old ratio.
            self.previousSplitRatio = oldRatio;
        }
        [self setSplitViewDividerLocation:targetRatio];
    }
    else
    {
        // We have an inconsistency here, let's just go back to 0.5,
        // otherwise nothing will happen
        if (self.previousSplitRatio < 0.0)
            self.previousSplitRatio = 0.5;

        [self setSplitViewDividerLocation:self.previousSplitRatio];
    }
}

- (void)setupEditor:(NSString *)changedKey
{
    [self.highlighter deactivate];

    if (!changedKey || [changedKey isEqualToString:@"extensionFootnotes"])
    {
        int extensions = pmh_EXT_NOTES;
        if (self.preferences.extensionFootnotes)
            extensions = pmh_EXT_NONE;
        self.highlighter.extensions = extensions;
    }

    if (!changedKey || [changedKey isEqualToString:@"editorHorizontalInset"]
            || [changedKey isEqualToString:@"editorVerticalInset"]
            || [changedKey isEqualToString:@"editorWidthLimited"]
            || [changedKey isEqualToString:@"editorMaximumWidth"])
    {
        [self adjustEditorInsets];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorBaseFontInfo"]
            || [changedKey isEqualToString:@"editorStyleName"]
            || [changedKey isEqualToString:@"editorLineSpacing"])
    {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineSpacing = self.preferences.editorLineSpacing;
        self.editor.defaultParagraphStyle = [style copy];
        NSFont *font = [self.preferences.editorBaseFont copy];
        if (font)
            self.editor.font = font;
        self.editor.textColor = nil;
        self.editor.backgroundColor = [NSColor clearColor];
        self.highlighter.styles = nil;
        [self.highlighter readClearTextStylesFromTextView];

        NSString *themeName = [self.preferences.editorStyleName copy];
        if (themeName.length)
        {
            NSString *path = MPThemePathForName(themeName);
            NSString *themeString = MPReadFileOfPath(path);
            [self.highlighter applyStylesFromStylesheet:themeString
                                       withErrorHandler:
                ^(NSArray *errorMessages) {
                    self.preferences.editorStyleName = nil;
                }];
        }

        // Configure the view's own backing layer instead of swapping in a
        // bare CALayer: a replacement layer is not managed by AppKit, so it
        // loses its contentsScale and renders at 1x on Retina displays.
        NSView *container = self.editorContainer;
        container.wantsLayer = YES;
        CGColorRef backgroundCGColor = self.editor.backgroundColor.CGColor;
        if (backgroundCGColor)
            container.layer.backgroundColor = backgroundCGColor;
    }
    
    if ([changedKey isEqualToString:@"editorBaseFontInfo"])
    {
        [self scaleWebview];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorShowWordCount"])
    {
        if (self.preferences.editorShowWordCount)
        {
            self.wordCountWidget.hidden = NO;
            self.editorPaddingBottom.constant = 35.0;
            [self updateWordCount];
        }
        else
        {
            self.wordCountWidget.hidden = YES;
            self.editorPaddingBottom.constant = 0.0;
        }
    }

    if (!changedKey || [changedKey isEqualToString:@"editorPasteAsMarkdown"])
        self.editor.pastesAsMarkdown = self.preferences.editorPasteAsMarkdown;

    if (!changedKey || [changedKey isEqualToString:@"editorHideMarkers"]
            || [changedKey isEqualToString:@"editorBlockLayout"]
            || [changedKey isEqualToString:@"editorBaseFontInfo"])
    {
        // A drawn horizontal rule needs both halves: the dashes hidden and a
        // line put in their place. With only one of the two switched on you
        // would get either a rule beside its own dashes or a blank line where
        // a rule used to be, so neither half acts alone.
        BOOL rules = self.preferences.editorHideMarkers
            && self.preferences.editorBlockLayout;

        self.markerHider.hidesRules = rules;
        self.markerHider.enabled = self.preferences.editorHideMarkers;
        self.editor.focusModeEnabled = self.preferences.editorFocusMode;
        self.editor.typewriterEnabled = self.preferences.editorTypewriter;

        self.blockStyler.baseFont = self.preferences.editorBaseFont;
        self.blockStyler.enabled = self.preferences.editorBlockLayout;
        [self.highlighter parseAndHighlightNow];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorSemanticStyling"]
            || [changedKey isEqualToString:@"editorBaseFontInfo"]
            || [changedKey isEqualToString:@"editorStyleName"])
    {
        self.semanticStyler.baseFont = self.preferences.editorBaseFont;
        self.semanticStyler.themeStyles = self.highlighter.styles;
        self.semanticStyler.enabled = self.preferences.editorSemanticStyling;
        // The styling is rebuilt from the next parse; ask for one rather
        // than waiting for the reader to type something.
        [self.highlighter parseAndHighlightNow];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorProseHighlights"])
    {
        self.editor.proseHighlightsEnabled =
            self.preferences.editorProseHighlights;
        [self updateProseSummary];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorScrollsPastEnd"])
    {
        self.editor.scrollsPastEnd = self.preferences.editorScrollsPastEnd;
        NSRect contentRect = self.editor.contentRect;
        NSSize minSize = self.editor.enclosingScrollView.contentSize;
        if (contentRect.size.height < minSize.height)
            contentRect.size.height = minSize.height;
        if (contentRect.size.width < minSize.width)
            contentRect.size.width = minSize.width;
        self.editor.frame = contentRect;
    }

    if (!changedKey)
    {
        NSClipView *contentView = self.editor.enclosingScrollView.contentView;
        contentView.postsBoundsChangedNotifications = YES;

        NSDictionary *keysAndDefaults = MPEditorKeysToObserve();
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in keysAndDefaults)
        {
            NSString *preferenceKey = MPEditorPreferenceKeyWithValueKey(key);
            id value = [defaults objectForKey:preferenceKey];
            value = value ? value : keysAndDefaults[key];
            [self.editor setValue:value forKey:key];
        }
    }

    if (!changedKey || [changedKey isEqualToString:@"editorOnRight"])
    {
        BOOL editorOnRight = self.preferences.editorOnRight;
        NSArray *subviews = self.splitView.subviews;
        if ((!editorOnRight && subviews[0] == self.preview)
            || (editorOnRight && subviews[1] == self.preview))
        {
            [self.splitView swapViews];
            if (!self.previewVisible && self.previousSplitRatio >= 0.0)
                self.previousSplitRatio = 1.0 - self.previousSplitRatio;

            // Need to queue this or the views won't be initialised correctly.
            // Don't really know why, but this works.
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.splitView.needsLayout = YES;
            }];
        }
    }

    [self.highlighter activate];
    self.editor.automaticLinkDetectionEnabled = NO;
}

- (void)adjustEditorInsets
{
    CGFloat x = self.preferences.editorHorizontalInset;
    CGFloat y = self.preferences.editorVerticalInset;
    if (self.preferences.editorWidthLimited)
    {
        CGFloat editorWidth = self.editor.frame.size.width;
        CGFloat maxWidth = self.preferences.editorMaximumWidth;
        if (editorWidth > 2 * x + maxWidth)
            x = (editorWidth - maxWidth) * 0.45;
        // We tend to expect things in an editor to shift to left a bit.
        // Hence the 0.45 instead of 0.5 (which whould feel a bit too much).
    }
    self.editor.textContainerInset = NSMakeSize(x, y);
}

- (void)adjustPreviewContentInsets
{
    // Pads the page by however much the titlebar and toolbar overlap the
    // content view, which is zero as the window is currently configured, so
    // this is a no-op that costs one JS call per load and starts working
    // again on its own if the full-size content view is ever restored.
    //
    // It pads the document element rather than setting contentInsets on
    // WebKit's scroll view: that leaves the exposed strip painted white, no
    // matter what the scroll view's own background is set to. The body
    // background propagates to the canvas, so the page's own colour fills
    // the padded area.
    NSWindow *window = self.windowForSheet;
    NSView *contentView = window.contentView;
    if (!contentView)
        return;

    CGFloat overlap = NSHeight(contentView.bounds)
                      - NSHeight(window.contentLayoutRect);
    NSString *js = [NSString stringWithFormat:
        @"document.documentElement.style.paddingTop = '%.0fpx';", overlap];
    [self.preview evaluateJavaScript:js completionHandler:nil];
}


#pragma mark - NSWindowDelegate

- (void)windowDidResize:(NSNotification *)notification
{
    // Entering or leaving full screen changes the overlap, not just the size.
    [self adjustPreviewContentInsets];
}


- (void)redrawDivider
{
    if (!self.editorVisible)
    {
        // If the editor is not visible, detect preview's background color via
        // DOM query and use it instead. This is more expensive; we should try
        // to avoid it.
        // TODO: Is it possible to cache this until the user switches the style?
        // Will need to take account of the user MODIFIES the style without
        // switching. Complicated. This will do for now.
        self.splitView.dividerColor = self.previewBackgroundColor;
    }
    else if (!self.previewVisible)
    {
        // If the editor is visible, match its background color.
        self.splitView.dividerColor = self.editor.backgroundColor;
    }
    else
    {
        // If both sides are visible, draw a default "transparent" divider.
        // This works around the possibile problem of divider's color being too
        // similar to both the editor and preview and being obscured.
        self.splitView.dividerColor = nil;
    }
}

- (void)scaleWebview
{
    if (!self.preferences.previewZoomRelativeToBaseFontSize)
        return;

    CGFloat fontSize = self.preferences.editorBaseFontSize;
    if (fontSize <= 0.0)
        return;

    static const CGFloat defaultSize = 14.0;
    CGFloat scale = fontSize / defaultSize;
    
#if 0
    // Sadly, this doesn’t work correctly.
    // It looks fine, but selections are offset relative to the mouse cursor.
    NSScrollView *previewScrollView =

    NSClipView *previewContentView = previewScrollView.contentView;
    [previewContentView scaleUnitSquareToSize:NSMakeSize(scale, scale)];
    [previewContentView setNeedsDisplay:YES];
#else
    // Warning: this is private webkit API and NOT App Store-safe!
    // pageZoom is the public counterpart of -setPageSizeMultiplier:, the
    // private call this used to make.
    self.preview.pageZoom = scale;
#endif
}

/** Where each heading sits in the preview, in document coordinates.
 *
 * The page is asked for these rather than measured from here, and answers
 * when it answers: the editor half of the calculation below runs straight
 * away, and the preview half lands on a later turn of the run loop. Nothing
 * downstream needs them in the same breath — they are read by -syncScrollers
 * on the next scroll.
 */
-(void) updateHeaderLocations
{
    // Offsets are added in the page, where the scroll position is known
    // without asking, so the answer arrives already in document coordinates.
    static NSString * const script =
        @"(function(){var top=window.scrollY;"
        @"var nodes=document.querySelectorAll("
        @"'h1, h2, h3, h4, h5, h6, img:only-child');"
        @"var out=[];"
        @"for(var i=0;i<nodes.length;i++){"
        @"out.push(nodes[i].getBoundingClientRect().top+top);}"
        @"return out;})()";

    __weak MPDocument *weakSelf = self;
    [self.preview evaluateJavaScript:script completionHandler:
        ^(id result, NSError *error) {
        if ([result isKindOfClass:[NSArray class]])
            weakSelf.webViewHeaderLocations = result;
    }];


    // Next, cache the locations of all of the reference nodes in the editor
    // view. This half is measured here and needs nothing from the page.
    NSMutableArray<NSNumber *> *locations = [NSMutableArray array];
    NSInteger characterCount = 0;
    NSLayoutManager *layoutManager = [self.editor layoutManager];
    NSArray<NSString *> *documentLines = [self.editor.string componentsSeparatedByString:@"\n"];
    [locations removeAllObjects];

    // These are the patterns for markdown headers and images respectively. we're only going to
    // handle images that are not inline with other text/images
    NSRegularExpression *dashRegex = [NSRegularExpression regularExpressionWithPattern:@"^([-]+)$" options:0 error:nil];
    NSRegularExpression *headerRegex = [NSRegularExpression regularExpressionWithPattern:@"^(#+)\\s" options:0 error:nil];
    NSRegularExpression *imgRegex = [NSRegularExpression regularExpressionWithPattern:@"^!\\[[^\\]]*\\]\\([^)]*\\)$" options:0 error:nil];
    BOOL previousLineHadContent = NO;
    
    CGFloat editorContentHeight = ceilf(NSHeight(self.editor.enclosingScrollView.documentView.bounds));
    CGFloat editorVisibleHeight = ceilf(NSHeight(self.editor.enclosingScrollView.contentView.bounds));

    // We start by splitting our document into lines, and then searching
    // line by line for headers or images.
    for (NSInteger lineNumber = 0; lineNumber < [documentLines count]; lineNumber++)
    {
        NSString *line = documentLines[lineNumber];
        
        if ((previousLineHadContent && [dashRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])]) ||
            [imgRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])] ||
            [headerRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])])
        {
            // Calculate where this header/image appears vertically in the editor
            NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:NSMakeRange(characterCount, [line length]) actualCharacterRange:nil];
            NSRect topRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[self.editor textContainer]];
            CGFloat headerY = NSMidY(topRect);

            if(headerY <= editorContentHeight - editorVisibleHeight){
                [locations addObject:@(headerY)];
            }
        }
        
        previousLineHadContent = [line length] && ![dashRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])];
        
        characterCount += [line length] + 1;
    }

    _editorHeaderLocations = [locations copy];
}

- (void)syncScrollers
{
    CGFloat editorContentHeight = ceilf(NSHeight(self.editor.enclosingScrollView.documentView.bounds));
    CGFloat editorVisibleHeight = ceilf(NSHeight(self.editor.enclosingScrollView.contentView.bounds));
    // Last reported by the page. Asking for them here would mean waiting on
    // another process while the editor is mid-scroll.
    CGFloat previewContentHeight = ceilf(self.previewContentHeight);
    CGFloat previewVisibleHeight = ceilf(self.previewViewportHeight);
    NSInteger relativeHeaderIndex = -1; // -1 is start of document, before any other header
    CGFloat currY = NSMinY(self.editor.enclosingScrollView.contentView.bounds);
    CGFloat minY = 0;
    CGFloat maxY = 0;
    
    // align the documents at the middle of the screen, except at top/bottom of document
    CGFloat topTaper = MAX(0, MIN(1.0, currY / editorVisibleHeight));
    CGFloat bottomTaper = 1.0 - MAX(0, MIN(1.0, (currY - editorContentHeight + 2 * editorVisibleHeight) / editorVisibleHeight));
    CGFloat adjustmentForScroll = topTaper * bottomTaper * editorVisibleHeight / 2;

    // We start by splitting our document into lines, and then searching
    // line by line for headers or images.
    for (NSNumber *headerYNum in _editorHeaderLocations) {
        CGFloat headerY = [headerYNum floatValue];
        headerY -= adjustmentForScroll;
        
        if (headerY < currY)
        {
            // The header is before our current scroll position. the closest
            // of these will be our first reference node
            relativeHeaderIndex += 1;
            minY = headerY;
        } else if (maxY == 0 && headerY < editorContentHeight - editorVisibleHeight)
        {
            // Skip any headers that are within the last screen of the editor.
            // we'll interpolate to the end of the document in that case.
            maxY = headerY;
        }
    }
    
    // Usually, we'll be scrolling between two reference nodes, but toward the end
    // of the document we'll ignore nodes and reference the end of the document instead
    BOOL interpolateToEndOfDocument = NO;
    
    if (maxY == 0)
    {
        // We only have a reference node before our current position,
        // but not after, so we'll use the end of the document.
        maxY = editorContentHeight - editorVisibleHeight + adjustmentForScroll;
        interpolateToEndOfDocument = YES;
    }

    // We are currently at currY offset, between minY and maxY, which represent
    // headers indexed by relativeHeaderIndex and relativeHeaderIndex+1.
    currY = MAX(0, currY - minY);
    maxY -= minY;
    minY -= minY;
    CGFloat percentScrolledBetweenHeaders = MAX(0, MIN(1.0, currY / maxY));
    
    // Now that we know where the editor position is relative to two reference nodes,
    // we need to find the positions of those nodes in the HTML preview
    CGFloat topHeaderY = 0;
    CGFloat bottomHeaderY = previewContentHeight - previewVisibleHeight;
    
    // Find the Y positions in the preview window that we're scrolling between
    if ([_webViewHeaderLocations count] > relativeHeaderIndex)
    {
        topHeaderY = floorf([_webViewHeaderLocations[relativeHeaderIndex] doubleValue]) - adjustmentForScroll;
    }
    
    if (!interpolateToEndOfDocument && [_webViewHeaderLocations count] > relativeHeaderIndex + 1)
    {
        bottomHeaderY = ceilf([_webViewHeaderLocations[relativeHeaderIndex + 1] doubleValue]) - adjustmentForScroll;
    }
    
    // Now we scroll percentScrolledBetweenHeaders percent between those two positions in the webview
    CGFloat previewY = topHeaderY + (bottomHeaderY - topHeaderY) * percentScrolledBetweenHeaders;
    [self setPreviewScrollTopTo:previewY];
}

- (void)setSplitViewDividerLocation:(CGFloat)ratio
{
    BOOL wasVisible = self.previewVisible;
    [self.splitView setDividerLocation:ratio];
    if (!wasVisible && self.previewVisible
            && !self.preferences.markdownManualRender)
        [self.renderer parseAndRenderNow];
    [self setupEditor:NSStringFromSelector(@selector(editorHorizontalInset))];
}

- (NSString *)presumedFileName
{
    if (self.fileURL)
        return self.fileURL.lastPathComponent.stringByDeletingPathExtension;

    NSString *title = nil;
    NSString *string = self.editor.string;
    if (self.preferences.htmlDetectFrontMatter)
        title = [[[string frontMatter:NULL] objectForKey:@"title"] description];
    if (title)
        return title;

    title = string.titleString;
    if (!title)
        return NSLocalizedString(@"Untitled", @"default filename if no title can be determined");

    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"[/|:]"
                                                          options:0 error:NULL];
    });

    NSRange range = NSMakeRange(0, title.length);
    title = [regex stringByReplacingMatchesInString:title options:0 range:range
                                       withTemplate:@"-"];
    return title;
}

/** Counts the words in the rendered document.
 *
 * The walk used to be done from here, over the live DOM, through the
 * DOMNode+Text category. There is no live DOM to walk any more, so the same
 * rules run inside the page: skip what is not prose, count a code block as
 * nothing and an inline code span as a single word.
 */
static NSString * const kMPWordCountScript =
    @"(function(){"
    @"var SKIP={SCRIPT:1,STYLE:1,HEAD:1,NOSCRIPT:1};"
    @"var words=0,chars=0,bare=0;"
    @"function words_in(t){var m=t.match(/\\S+/g);return m?m.length:0;}"
    @"function walk(node){"
    @"if(node.nodeType===3||node.nodeType===4){"
    @"var t=node.nodeValue||'';"
    @"words+=words_in(t);"
    @"chars+=t.replace(/[\\r\\n]/g,'').length;"
    @"bare+=t.replace(/\\s/g,'').length;"
    @"return;}"
    @"if(node.nodeType!==1&&node.nodeType!==9&&node.nodeType!==11)return;"
    @"var tag=node.tagName?node.tagName.toUpperCase():'';"
    @"if(SKIP[tag])return;"
    @"if(tag==='CODE'||tag==='TT'){"
    // A code block is not prose; an inline span is one word if it has any
    // content at all. Characters are still counted either way.
    @"var parent=node.parentElement;"
    @"var block=parent&&parent.tagName==='PRE';"
    @"var before=words;"
    @"for(var c=node.firstChild;c;c=c.nextSibling)walk(c);"
    @"words=block?before:before+((words>before)?1:0);"
    @"return;}"
    @"for(var k=node.firstChild;k;k=k.nextSibling)walk(k);}"
    @"walk(document.body||document);"
    @"return {words:words,characters:chars,bare:bare};})()";

- (void)updateWordCount
{
    if (!self.preview)
        return;

    __weak MPDocument *weakSelf = self;
    [self.preview evaluateJavaScript:kMPWordCountScript completionHandler:
        ^(id result, NSError *error) {
        if (![result isKindOfClass:[NSDictionary class]])
            return;

        MPDocument *me = weakSelf;
        me.totalWords = [result[@"words"] unsignedIntegerValue];
        me.totalCharacters = [result[@"characters"] unsignedIntegerValue];
        me.totalCharactersNoSpaces = [result[@"bare"] unsignedIntegerValue];

        if (me.isPreviewReady)
            me.wordCountWidget.enabled = YES;
    }];
}

- (BOOL)isCurrentBaseUrl:(NSURL *)another
{
    NSString *mine = self.currentBaseUrl.absoluteBaseURLString;
    NSString *theirs = another.absoluteBaseURLString;
    return mine == theirs || [mine isEqualToString:theirs];
}


#define OPEN_FAIL_ALERT_INFORMATIVE NSLocalizedString( \
@"Please check the path of your link is correct. Turn on \
“Automatically create link targets” If you want MacDown to \
create nonexistent link targets for you.", \
@"preview navigation error information")

#define AUTO_CREATE_FAIL_ALERT_INFORMATIVE NSLocalizedString( \
@"MacDown can’t create a file for the clicked link because \
the current file is not saved anywhere yet. Save the \
current file somewhere to enable this feature.", \
@"preview navigation error information")


/// Whether this is a file this application would open as a document.
NS_INLINE BOOL MPIsMarkdownFileURL(NSURL *url)
{
    static NSSet *extensions = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        extensions = [NSSet setWithArray:@[@"md", @"markdown", @"mdown",
                                           @"mkd", @"mkdn", @"text", @"txt"]];
    });
    return [extensions containsObject:url.pathExtension.lowercaseString];
}

- (void)openOrCreateFileForUrl:(NSURL *)url
{
    // Out of the preview's scheme and back into a file. The page is served
    // over a scheme of its own so it has an ordinary origin, and a relative
    // link in the document resolves against it — so a link to the file next
    // door arrives here as `macdown-preview:///Users/…/nota.md`, and asking
    // the system to open that gets "no application has been set to open the
    // URL", which is true and useless.
    url = MPFileURLFromPreviewURL(url);

    // Simply open the file if it is not local, or exists already.
    BOOL file = url.isFileURL;
    BOOL reachable = !file || [url checkResourceIsReachableAndReturnError:NULL];
    
    // If the file is local but doesn't exist, check if a file with
    // the .md extension exists.
    if (file && !reachable && [url.pathExtension isEqualToString:@""])
    {
        NSURL *markdownURL = [url URLByAppendingPathExtension:@"md"];
        if ([markdownURL checkResourceIsReachableAndReturnError:NULL])
        {
            reachable = YES;
            url = markdownURL;
        }
    }
    
    if (reachable)
    {
        /* Already open? Then the link goes to the tab it is open in.
         *
         * Before anything else, because the alternative is asking the
         * document controller to open it and trusting that it notices. It
         * does notice — but this way the intent is in the code rather than
         * in a framework's good manners, and -showWindows on a tabbed
         * document is exactly "select that tab".
         */
        if (file)
        {
            NSDocument *already = [[NSDocumentController
                sharedDocumentController] documentForURL:url];
            if (already)
            {
                [already showWindows];
                return;
            }
        }

        // A document this application can open, opened here. Handing a
        // neighbouring note to the workspace opens it in whatever holds the
        // extension — which may be another copy of MacDown, or another
        // editor entirely, and either way is a second window in a second
        // application for a link followed inside this one. Anything else
        // does belong to the system.
        if (file && MPIsMarkdownFileURL(url))
        {
            NSDocumentController *controller =
                [NSDocumentController sharedDocumentController];
            [controller openDocumentWithContentsOfURL:url display:YES
                                    completionHandler:
                ^(NSDocument *document, BOOL wasOpen, NSError *error) {
                // Whatever stopped it, the system's own handler is a better
                // answer than a dead click.
                if (!document)
                    [[NSWorkspace sharedWorkspace] openURL:url];
            }];
            return;
        }
        [[NSWorkspace sharedWorkspace] openURL:url];
        return;
    }

    // Show an error if the user doesn't want us to create it automatically.
    if (!self.preferences.createFileForLinkTarget)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"File not found at path:\n%@",
            @"preview navigation error message");
        alert.messageText = [NSString stringWithFormat:template, url.path];
        alert.informativeText = OPEN_FAIL_ALERT_INFORMATIVE;
        [alert runModal];
        return;
    }

    // We can only create a file if the current file is saved. (Why?)
    if (!self.fileURL)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"Can’t create file:\n%@", @"preview navigation error message");
        alert.messageText = [NSString stringWithFormat:template,
                             url.lastPathComponent];
        alert.informativeText = AUTO_CREATE_FAIL_ALERT_INFORMATIVE;
        [alert runModal];
    }

    // Try to created the file.
    NSDocumentController *controller =
        [NSDocumentController sharedDocumentController];

    NSError *error = nil;
    id doc = [controller createNewEmptyDocumentForURL:url
                                              display:YES error:&error];
    if (!doc)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"Can’t create file:\n%@",
            @"preview navigation error message");
        alert.messageText =
            [NSString stringWithFormat:template, url.lastPathComponent];
        template = NSLocalizedString(
            @"An error occurred while creating the file:\n%@",
            @"preview navigation error information");
        alert.informativeText =
            [NSString stringWithFormat:template, error.localizedDescription];
        [alert runModal];
    }
}


- (void)document:(NSDocument *)doc didPrint:(BOOL)ok context:(void *)context
{
    if ([doc respondsToSelector:@selector(setPrinting:)])
        ((MPDocument *)doc).printing = NO;
    if (context)
    {
        NSInvocation *invocation = (__bridge NSInvocation *)context;
        if ([invocation isKindOfClass:[NSInvocation class]])
        {
            [invocation setArgument:&doc atIndex:0];
            [invocation setArgument:&ok atIndex:1];
            [invocation invoke];
        }
    }
}

@end
