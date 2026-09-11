//
//  MPDiagramSheetController.m
//  MacDown
//

#import "MPDiagramSheetController.h"

#import <WebKit/WebKit.h>

#import "MPDiagramPrompt.h"
#import "MPTextGenerator.h"


static const CGFloat kMPSheetWidth = 760.0;
static const CGFloat kMPSheetPadding = 20.0;


@interface MPDiagramSheetController () <NSTextViewDelegate,
                                        WKNavigationDelegate>

@property (strong, nonatomic) id<MPTextGenerator> generator;
@property (copy, nonatomic) void (^insert)(NSString *code);

@property (strong, nonatomic) NSTextView *descriptionView;
@property (strong, nonatomic) NSPopUpButton *kindButton;
@property (strong, nonatomic) NSTextView *codeView;
@property (strong, nonatomic) WKWebView *preview;
/// The page with mermaid in it has finished loading and can draw.
@property (nonatomic) BOOL previewReady;
/// What is waiting to be drawn while the page loads, or between keystrokes.
@property (copy, nonatomic) NSString *pending;
@property (strong, nonatomic) NSTextField *status;
@property (strong, nonatomic) NSProgressIndicator *spinner;
@property (strong, nonatomic) NSButton *generateButton;
@property (strong, nonatomic) NSButton *insertButton;

/// What the model has said so far, before it is cleaned up.
@property (copy, nonatomic) NSString *raw;
@property (nonatomic, getter=isWorking) BOOL working;
/// Held while the sheet is up, because nothing else holds it.
@property (strong, nonatomic) MPDiagramSheetController *itself;

@end


@implementation MPDiagramSheetController

- (instancetype)initWithGenerator:(id<MPTextGenerator>)generator
                           insert:(void (^)(NSString *))insert
{
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0.0, 0.0, kMPSheetWidth, 520.0)
                  styleMask:NSWindowStyleMaskTitled
                    backing:NSBackingStoreBuffered defer:NO];

    self = [super initWithWindow:window];
    if (!self)
        return nil;

    _generator = generator;
    _insert = [insert copy];
    [self buildContent];
    return self;
}


- (void)beginOn:(NSWindow *)window
{
    self.itself = self;
    [window beginSheet:self.window completionHandler:^(NSModalResponse r) {
        self.itself = nil;
    }];
    [self.window makeFirstResponder:self.descriptionView];
}


#pragma mark - The sheet

- (void)buildContent
{
    NSTextField *ask = [self label:NSLocalizedString(
        @"Describe the diagram, in whatever language you write in. The "
        @"labels come back in that language.",
        @"Prompt of the diagram sheet")];
    ask.textColor = [NSColor secondaryLabelColor];

    NSScrollView *describe = [self textBox:&_descriptionView
                                monospaced:NO height:96.0];
    self.descriptionView.editable = YES;
    self.descriptionView.delegate = self;

    NSTextField *drawTitle = [self label:NSLocalizedString(
        @"Draw:", @"Label of the diagram kind popup")];
    self.kindButton = [[NSPopUpButton alloc] init];
    for (NSUInteger i = 0; i < MPDiagramKindCount; i++)
        [self.kindButton addItemWithTitle:
            MPDiagramKindTitle(MPDiagramKindsInOrder[i])];

    NSStackView *kindRow = [NSStackView stackViewWithViews:
        @[drawTitle, self.kindButton]];
    kindRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    kindRow.spacing = 8.0;

    NSTextField *codeTitle = [self label:NSLocalizedString(
        @"What the model wrote — you can correct it here:",
        @"Label above the generated Mermaid source")];
    codeTitle.textColor = [NSColor secondaryLabelColor];
    NSScrollView *code = [self textBox:&_codeView monospaced:YES height:190.0];
    self.codeView.editable = YES;
    self.codeView.delegate = self;

    // The diagram as Mermaid draws it, beside its source: a diagram that
    // will not draw should be seen here and not found in the document.
    self.preview = [self buildPreview];
    NSStackView *middle = [NSStackView stackViewWithViews:@[code, self.preview]];
    middle.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    middle.distribution = NSStackViewDistributionFillEqually;
    middle.spacing = 10.0;

    self.status = [self label:@""];
    self.status.textColor = [NSColor secondaryLabelColor];
    self.spinner = [[NSProgressIndicator alloc] init];
    self.spinner.style = NSProgressIndicatorStyleSpinning;
    self.spinner.controlSize = NSControlSizeSmall;
    self.spinner.displayedWhenStopped = NO;

    NSButton *cancel = [NSButton buttonWithTitle:NSLocalizedString(
        @"Cancel", @"Diagram sheet") target:self action:@selector(dismiss:)];
    cancel.keyEquivalent = @"\033";
    self.generateButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Draw It", @"Diagram sheet: ask the model")
        target:self action:@selector(generate:)];
    self.generateButton.keyEquivalent = @"\r";
    self.insertButton = [NSButton buttonWithTitle:NSLocalizedString(
        @"Put It in the Document", @"Diagram sheet: accept the diagram")
        target:self action:@selector(accept:)];
    self.insertButton.enabled = NO;

    NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *buttons = [NSStackView stackViewWithViews:
        @[self.spinner, self.status, spacer, cancel, self.generateButton,
          self.insertButton]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 8.0;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[ask, describe, kindRow, codeTitle, middle, buttons]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 10.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *content = self.window.contentView;
    [content addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:content.leadingAnchor
            constant:kMPSheetPadding],
        [column.trailingAnchor constraintEqualToAnchor:content.trailingAnchor
            constant:-kMPSheetPadding],
        [column.topAnchor constraintEqualToAnchor:content.topAnchor
            constant:kMPSheetPadding],
        [column.bottomAnchor constraintEqualToAnchor:content.bottomAnchor
            constant:-kMPSheetPadding],
        [describe.widthAnchor constraintEqualToAnchor:column.widthAnchor],
        [middle.widthAnchor constraintEqualToAnchor:column.widthAnchor],
        [buttons.widthAnchor constraintEqualToAnchor:column.widthAnchor],
    ]];
    ask.preferredMaxLayoutWidth = kMPSheetWidth - 2.0 * kMPSheetPadding;
}


- (NSTextField *)label:(NSString *)string
{
    NSTextField *label = [NSTextField labelWithString:string];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    return label;
}


- (NSScrollView *)textBox:(NSTextView * __strong *)view
               monospaced:(BOOL)monospaced
                   height:(CGFloat)height
{
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll.heightAnchor constraintEqualToConstant:height].active = YES;

    NSTextView *text = [[NSTextView alloc] initWithFrame:NSZeroRect];
    text.font = monospaced
        ? [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightRegular]
        : [NSFont systemFontOfSize:[NSFont systemFontSize]];
    text.richText = NO;
    text.automaticQuoteSubstitutionEnabled = NO;
    text.automaticDashSubstitutionEnabled = NO;
    text.textContainerInset = NSMakeSize(4.0, 6.0);
    text.autoresizingMask = NSViewWidthSizable;
    text.minSize = NSMakeSize(0.0, height);
    text.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    text.verticallyResizable = YES;
    text.horizontallyResizable = NO;
    text.textContainer.widthTracksTextView = YES;
    scroll.documentView = text;
    *view = text;
    return scroll;
}


#pragma mark - Drawing what it wrote

- (WKWebView *)buildPreview
{
    WKWebViewConfiguration *configuration =
        [[WKWebViewConfiguration alloc] init];
    WKWebView *web = [[WKWebView alloc] initWithFrame:NSZeroRect
                                        configuration:configuration];
    web.navigationDelegate = self;
    web.translatesAutoresizingMaskIntoConstraints = NO;
    [web.heightAnchor constraintEqualToConstant:190.0].active = YES;
    if (@available(macOS 12.0, *))
        web.underPageBackgroundColor = [NSColor textBackgroundColor];
    [web loadHTMLString:[self drawingPage] baseURL:nil];
    return web;
}


/// Mermaid from the application's own bundle, and one function that draws
/// one diagram and answers what happened. The same library the preview pane
/// uses, so what is drawn here is what will be drawn there.
- (NSString *)drawingPage
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"mermaid.min"
                                                     ofType:@"js"
                                                inDirectory:@"Extensions"];
    NSString *library = path
        ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding
                                       error:NULL]
        : nil;
    if (!library.length)
        return @"<!doctype html><html><body></body></html>";

    return [NSString stringWithFormat:
        @"<!doctype html><html><head><meta charset=\"utf-8\">"
        @"<style>html,body{margin:0;padding:8px;font:13px -apple-system;"
        @"color-scheme:light dark}"
        @"#md{display:flex;align-items:center;justify-content:center}"
        @"svg{max-width:100%%;height:auto}</style></head>"
        @"<body><div id=\"md\"></div><script>%@</script><script>\n"
        @"mermaid.initialize({startOnLoad:false, securityLevel:'strict',"
        @" theme:'forest', flowchart:{htmlLabels:false, useMaxWidth:true}});\n"
        @"var mpCount = 0;\n"
        @"window.MPDraw = function (code) {\n"
        @"  var box = document.getElementById('md');\n"
        @"  return mermaid.render('mp-' + (mpCount++), code).then("
        @"function (r) {\n"
        @"    box.innerHTML = (r && r.svg) ? r.svg : String(r);\n"
        @"    return 'ok';\n"
        @"  }).catch(function (e) {\n"
        @"    box.innerHTML = '';\n"
        @"    return 'no: ' + ((e && e.message) ? e.message : String(e));\n"
        @"  });\n"
        @"};\n</script></body></html>", library];
}


- (void)webView:(WKWebView *)web didFinishNavigation:(WKNavigation *)nav
{
    self.previewReady = YES;
    if (self.pending)
        [self draw:self.pending];
}


/// Draws, and says what Mermaid said. A diagram that does not draw cannot
/// be put in the document: what would arrive there is an error message in a
/// box, which is worse than nothing.
- (void)draw:(NSString *)code
{
    self.pending = code;
    if (!self.previewReady)
        return;

    NSString *wanted = code ?: @"";
    __weak MPDiagramSheetController *weakSelf = self;
    [self.preview callAsyncJavaScript:@"return await window.MPDraw(code);"
        arguments:@{@"code": wanted} inFrame:nil
        inContentWorld:[WKContentWorld pageWorld]
        completionHandler:^(id answer, NSError *error) {
        MPDiagramSheetController *sheet = weakSelf;
        if (!sheet || ![sheet.pending isEqualToString:wanted])
            return;             // Something newer is already on its way.

        NSString *said = [answer isKindOfClass:[NSString class]] ? answer : nil;
        if ([said isEqualToString:@"ok"])
        {
            sheet.insertButton.enabled = YES;
            NSString *trouble = MPDiagramWarningForCode(wanted);
            sheet.status.textColor = trouble ? [NSColor systemOrangeColor]
                                             : [NSColor secondaryLabelColor];
            sheet.status.stringValue = trouble ?: @"";
            return;
        }
        sheet.insertButton.enabled = NO;
        sheet.status.textColor = [NSColor systemOrangeColor];
        sheet.status.stringValue = said
            ? [said stringByReplacingOccurrencesOfString:@"no: " withString:@""]
            : (error.localizedDescription ?: @"");
    }];
}


#pragma mark - Asking the model

- (void)generate:(id)sender
{
    if (self.working)
    {
        [self.generator cancel];
        return;
    }

    NSString *description = [self.descriptionView.string
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!description.length)
    {
        [self.window makeFirstResponder:self.descriptionView];
        return;
    }

    MPDiagramKind kind =
        MPDiagramKindsInOrder[MAX(self.kindButton.indexOfSelectedItem, 0)];
    self.raw = @"";
    self.codeView.string = @"";
    [self setWorking:YES
              saying:NSLocalizedString(@"The model is drawing…",
                                       @"Diagram sheet, while it works")];

    __weak MPDiagramSheetController *weakSelf = self;
    [self.generator generateWithInstruction:MPDiagramInstructionForKind(kind)
        onText:description
       onChunk:^(NSString *piece) {
        MPDiagramSheetController *sheet = weakSelf;
        // Shown as it arrives, raw: a diagram taking shape line by line is
        // an application working, and the same wait behind a spinner is one
        // that has stopped.
        sheet.raw = [(sheet.raw ?: @"") stringByAppendingString:piece ?: @""];
        sheet.codeView.string = sheet.raw;
        [sheet.codeView scrollRangeToVisible:
            NSMakeRange(sheet.codeView.string.length, 0)];
    } completion:^(NSError *error) {
        [weakSelf finishedWith:error];
    }];
}


- (void)finishedWith:(NSError *)error
{
    NSString *code = MPDiagramCodeFromAnswer(self.raw);
    if (code)
    {
        self.codeView.string = code;
        self.window.defaultButtonCell = self.insertButton.cell;
        [self setWorking:NO saying:@""];
        // Whether it can go in the document is Mermaid's answer, not ours.
        self.insertButton.enabled = NO;
        [self draw:code];
        return;
    }
    self.status.textColor = [NSColor secondaryLabelColor];

    // What it said is left on screen: a model that answered with an apology
    // has told the reader something, and hiding it would leave them with an
    // empty box and no idea why.
    self.insertButton.enabled = NO;
    if (error && error.code == MPTextGeneratorErrorCancelled)
    {
        [self setWorking:NO saying:NSLocalizedString(@"Stopped.",
                                                     @"Diagram sheet")];
        return;
    }
    [self setWorking:NO saying:error
        ? error.localizedDescription
        : NSLocalizedString(@"That was not a diagram. Try again, or say it "
                            @"differently.",
                            @"Diagram sheet, when the answer is not Mermaid")];
}


- (void)setWorking:(BOOL)working saying:(NSString *)saying
{
    self.working = working;
    self.status.stringValue = saying ?: @"";
    if (working)
        [self.spinner startAnimation:nil];
    else
        [self.spinner stopAnimation:nil];
    self.generateButton.title = working
        ? NSLocalizedString(@"Stop", @"Diagram sheet: stop the model")
        : NSLocalizedString(@"Draw It", @"Diagram sheet: ask the model");
}


#pragma mark - Leaving

- (void)accept:(id)sender
{
    NSString *code = [self.codeView.string stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!code.length)
        return;
    if (self.insert)
        self.insert(code);
    [self dismiss:sender];
}


- (void)dismiss:(id)sender
{
    [self.generator cancel];
    [self.window.sheetParent endSheet:self.window];
}


#pragma mark - NSTextViewDelegate

/// Corrected by hand, and drawn again a moment later: soon enough to be an
/// answer, late enough not to redraw on every keystroke.
- (void)textDidChange:(NSNotification *)note
{
    if (note.object != self.codeView)
        return;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
        selector:@selector(drawWhatIsTyped) object:nil];
    [self performSelector:@selector(drawWhatIsTyped) withObject:nil
               afterDelay:0.6];
}

- (void)drawWhatIsTyped
{
    NSString *code = [self.codeView.string stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!code.length)
    {
        self.insertButton.enabled = NO;
        return;
    }
    [self draw:code];
}

/// ⌘↩ in the description asks for the diagram, which is where a hand is.
- (BOOL)textView:(NSTextView *)view doCommandBySelector:(SEL)command
{
    if (view == self.descriptionView && command == @selector(insertNewline:)
            && (NSApp.currentEvent.modifierFlags & NSEventModifierFlagCommand))
    {
        [self generate:nil];
        return YES;
    }
    return NO;
}

@end
