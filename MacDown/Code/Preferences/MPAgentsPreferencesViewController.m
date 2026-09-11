//
//  MPAgentsPreferencesViewController.m
//  MacDown
//

#import "MPAgentsPreferencesViewController.h"

#import "MPPreferences.h"


static const CGFloat kMPPanelWidth = 560.0;
static const CGFloat kMPPanelPadding = 20.0;

/// Enough of the diary to see what an assistant has been doing, and not so
/// much that the panel becomes a log reader.
static const NSUInteger kMPDiaryLines = 200;


@interface MPAgentsPreferencesViewController ()

@property (strong, nonatomic) NSButton *allowedSwitch;
@property (strong, nonatomic) NSTextField *folderLabel;
@property (strong, nonatomic) NSPopUpButton *levelButton;
@property (strong, nonatomic) NSTextField *commandLabel;
@property (strong, nonatomic) NSTextView *diaryView;
@property (strong, nonatomic) NSTextField *diaryEmptyLabel;

@end


@implementation MPAgentsPreferencesViewController

- (id)init
{
    // Built here rather than in a nib: every line of it is either a
    // preference or something read off the disk when the panel opens.
    return [super initWithNibName:nil bundle:nil];
}


#pragma mark - The panel

- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, kMPPanelWidth, 520.0)];

    NSTextField *what = [self paragraph:NSLocalizedString(
        @"An assistant that speaks MCP — Claude Code, Claude Desktop, "
        @"anything else — can be given one folder of Markdown to read. It "
        @"is not this application that answers: the client starts a small "
        @"server that ships inside it, macdownext-mcp, talks to it over a "
        @"pipe and stops it when it is done. Nothing is running until a "
        @"client starts it, and nothing leaves your Mac.",
        @"What the agents preference pane is about")];

    self.allowedSwitch = [NSButton checkboxWithTitle:NSLocalizedString(
        @"Let assistants use the folder server",
        @"Switch that allows or refuses the MCP server")
        target:self action:@selector(toggleAllowed:)];

    NSTextField *offNote = [self paragraph:NSLocalizedString(
        @"Off, the server refuses to start and says so, whatever a client "
        @"has in its configuration.",
        @"What happens when the agents switch is off")];
    offNote.font = [NSFont systemFontOfSize:11.0];

    // The folder and the level are not settings the server reads: they are
    // what the line below is built from, so that the line can be pasted
    // instead of assembled by hand.
    NSTextField *folderTitle = [self label:NSLocalizedString(
        @"Folder to offer:", @"Label for the folder given to an assistant")];
    self.folderLabel = [self detail:@""];
    NSButton *choose = [NSButton buttonWithTitle:NSLocalizedString(
        @"Choose…", @"Pick the folder to offer an assistant")
        target:self action:@selector(chooseFolder:)];

    NSTextField *levelTitle = [self label:NSLocalizedString(
        @"It may:", @"Label for the writing level of the MCP server")];
    self.levelButton = [[NSPopUpButton alloc] init];
    [self.levelButton addItemWithTitle:NSLocalizedString(
        @"only read", @"MCP writing level: read only")];
    [self.levelButton addItemWithTitle:NSLocalizedString(
        @"read, and add to the end of a document",
        @"MCP writing level: append")];
    [self.levelButton addItemWithTitle:NSLocalizedString(
        @"read, add, make new documents and replace text",
        @"MCP writing level: write")];
    self.levelButton.target = self;
    self.levelButton.action = @selector(chooseLevel:);

    NSTextField *lineTitle = [self label:NSLocalizedString(
        @"The line to paste in the client:",
        @"Label for the command line that declares the server")];
    self.commandLabel = [self detail:@""];
    self.commandLabel.drawsBackground = YES;
    self.commandLabel.backgroundColor = [NSColor textBackgroundColor];
    NSButton *copy = [NSButton buttonWithTitle:NSLocalizedString(
        @"Copy", @"Copy the command line that declares the server")
        target:self action:@selector(copyCommand:)];

    NSTextField *diaryTitle = [self label:NSLocalizedString(
        @"What has been asked of it:",
        @"Label for the list of calls read from the log")];
    NSScrollView *scroll = [self diaryScrollView];
    self.diaryEmptyLabel = [self detail:NSLocalizedString(
        @"Nothing yet.", @"Shown when the agents log is empty")];

    NSButton *reveal = [NSButton buttonWithTitle:NSLocalizedString(
        @"Show the Log in Finder", @"Reveal the MCP log file")
        target:self action:@selector(showLog:)];
    NSButton *clear = [NSButton buttonWithTitle:NSLocalizedString(
        @"Clear the Log", @"Empty the MCP log file")
        target:self action:@selector(clearLog:)];

    NSStackView *folderRow = [NSStackView stackViewWithViews:
        @[folderTitle, self.folderLabel, choose]];
    folderRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    folderRow.spacing = 8.0;

    NSStackView *levelRow = [NSStackView stackViewWithViews:
        @[levelTitle, self.levelButton]];
    levelRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    levelRow.spacing = 8.0;

    NSStackView *commandRow = [NSStackView stackViewWithViews:
        @[self.commandLabel, copy]];
    commandRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    commandRow.spacing = 8.0;

    NSStackView *logRow = [NSStackView stackViewWithViews:@[reveal, clear]];
    logRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    logRow.spacing = 10.0;

    NSStackView *column = [NSStackView stackViewWithViews:
        @[what, self.allowedSwitch, offNote, folderRow, levelRow, lineTitle,
          commandRow, diaryTitle, scroll, self.diaryEmptyLabel, logRow]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 12.0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [column setCustomSpacing:4.0 afterView:self.allowedSwitch];
    [column setCustomSpacing:18.0 afterView:offNote];
    [column setCustomSpacing:6.0 afterView:lineTitle];
    [column setCustomSpacing:6.0 afterView:diaryTitle];
    [column setCustomSpacing:6.0 afterView:scroll];

    [view addSubview:column];
    CGFloat text = kMPPanelWidth - 2.0 * kMPPanelPadding;
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:view.leadingAnchor
            constant:kMPPanelPadding],
        [column.trailingAnchor constraintEqualToAnchor:view.trailingAnchor
            constant:-kMPPanelPadding],
        [column.topAnchor constraintEqualToAnchor:view.topAnchor
            constant:kMPPanelPadding],
        [column.bottomAnchor constraintEqualToAnchor:view.bottomAnchor
            constant:-kMPPanelPadding],
        [view.widthAnchor constraintEqualToConstant:kMPPanelWidth],
        [scroll.widthAnchor constraintEqualToConstant:text],
        [scroll.heightAnchor constraintEqualToConstant:150.0],
    ]];
    what.preferredMaxLayoutWidth = text;
    offNote.preferredMaxLayoutWidth = text;

    self.view = view;
}

- (NSScrollView *)diaryScrollView
{
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextView *text = [[NSTextView alloc] init];
    text.editable = NO;
    text.richText = NO;
    text.font = [NSFont monospacedSystemFontOfSize:10.0
                                            weight:NSFontWeightRegular];
    text.textContainerInset = NSMakeSize(4.0, 4.0);
    // A log line is long and the point of it is the end — the file and the
    // outcome — so it scrolls sideways instead of folding.
    text.horizontallyResizable = YES;
    text.textContainer.widthTracksTextView = NO;
    text.textContainer.containerSize =
        NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    scroll.hasHorizontalScroller = YES;
    scroll.documentView = text;
    self.diaryView = text;
    return scroll;
}

- (NSTextField *)label:(NSString *)string
{
    NSTextField *label = [NSTextField labelWithString:string];
    label.selectable = YES;
    return label;
}

- (NSTextField *)paragraph:(NSString *)string
{
    NSTextField *label = [self label:string];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.textColor = [NSColor secondaryLabelColor];
    return label;
}

- (NSTextField *)detail:(NSString *)string
{
    NSTextField *label = [self label:string];
    label.font = [NSFont monospacedSystemFontOfSize:11.0
                                             weight:NSFontWeightRegular];
    label.textColor = [NSColor secondaryLabelColor];
    return label;
}


#pragma mark - Showing what is set

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self showWhatWeKnow];
    [self showTheDiary];
}

- (void)showWhatWeKnow
{
    MPPreferences *preferences = self.preferences;
    self.allowedSwitch.state = preferences.agentsAllowed
        ? NSControlStateValueOn : NSControlStateValueOff;

    NSString *folder = preferences.agentsFolderPath;
    self.folderLabel.stringValue = folder.length
        ? [folder stringByAbbreviatingWithTildeInPath]
        : NSLocalizedString(@"none chosen",
                            @"Shown when no folder is offered to assistants");
    [self.levelButton selectItemAtIndex:
        MIN(MAX(preferences.agentsWritingLevel, 0), 2)];
    self.commandLabel.stringValue = [self command];
}

/// The line somebody pastes into a client's configuration, with the binary
/// where it actually is: inside this copy of the application, whichever
/// copy that turns out to be.
- (NSString *)command
{
    NSString *server = [[NSBundle mainBundle] pathForAuxiliaryExecutable:
        @"macdownext-mcp"]
        ?: [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:
            @"Contents/SharedSupport/bin/macdownext-mcp"];

    NSString *folder = self.preferences.agentsFolderPath;
    if (!folder.length)
        folder = NSLocalizedString(@"/path/to/your/notes",
                                   @"Stand-in for a folder nobody has "
                                   @"chosen yet, in the pasted line");

    NSArray<NSString *> *levels = @[@"", @" --append", @" --write"];
    NSInteger level = MIN(MAX(self.preferences.agentsWritingLevel, 0), 2);

    // A folder somebody named with a quote in it would otherwise produce a
    // line that means something else once a shell has read it.
    return [NSString stringWithFormat:
        @"claude mcp add notes -- \"%@\" --root \"%@\"%@",
        [self quoted:server], [self quoted:folder], levels[level]];
}

/// What a double quote and a backslash have to look like inside a quoted
/// argument.
- (NSString *)quoted:(NSString *)path
{
    NSString *escaped = [path stringByReplacingOccurrencesOfString:@"\\"
                                                        withString:@"\\\\"];
    return [escaped stringByReplacingOccurrencesOfString:@"\""
                                             withString:@"\\\""];
}

- (void)showTheDiary
{
    NSString *whole = [NSString stringWithContentsOfURL:[self logURL]
        encoding:NSUTF8StringEncoding error:NULL];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [whole enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        [lines addObject:line];
    }];
    if (lines.count > kMPDiaryLines)
    {
        [lines removeObjectsInRange:
            NSMakeRange(0, lines.count - kMPDiaryLines)];
    }

    // The last line is the interesting one, so the view starts at the end.
    self.diaryView.string = [lines componentsJoinedByString:@"\n"];
    [self.diaryView scrollRangeToVisible:
        NSMakeRange(self.diaryView.string.length, 0)];
    self.diaryEmptyLabel.hidden = lines.count > 0;
}

/// Where the server writes: the same path it builds for itself, which this
/// panel only reads.
- (NSURL *)logURL
{
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(
        NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *folder = [libraries.firstObject
        stringByAppendingPathComponent:@"Logs/MacDown Next"];
    return [NSURL fileURLWithPath:
        [folder stringByAppendingPathComponent:@"mcp.log"]];
}


#pragma mark - Doing

- (void)toggleAllowed:(id)sender
{
    self.preferences.agentsAllowed =
        (self.allowedSwitch.state == NSControlStateValueOn);
}

- (void)chooseFolder:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.allowsMultipleSelection = NO;
    panel.prompt = NSLocalizedString(@"Offer",
                                     @"Confirm the folder to offer an "
                                     @"assistant");
    [panel beginSheetModalForWindow:self.view.window
                  completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL)
            return;
        self.preferences.agentsFolderPath = panel.URL.path;
        [self showWhatWeKnow];
    }];
}

- (void)chooseLevel:(id)sender
{
    self.preferences.agentsWritingLevel = self.levelButton.indexOfSelectedItem;
    [self showWhatWeKnow];
}

- (void)copyCommand:(id)sender
{
    NSPasteboard *board = [NSPasteboard generalPasteboard];
    [board clearContents];
    [board setString:[self command] forType:NSPasteboardTypeString];
}

- (void)showLog:(id)sender
{
    NSURL *url = [self logURL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path])
    {
        [[NSWorkspace sharedWorkspace]
            activateFileViewerSelectingURLs:@[url]];
        return;
    }
    [[NSWorkspace sharedWorkspace] openURL:url.URLByDeletingLastPathComponent];
}

- (void)clearLog:(id)sender
{
    [[NSFileManager defaultManager] removeItemAtURL:[self logURL] error:NULL];
    [self showTheDiary];
}


#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"AgentsPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageWithSystemSymbolName:@"sparkles"
                     accessibilityDescription:nil]
        ?: [NSImage imageNamed:NSImageNameNetwork];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Agents", @"Preference pane title.");
}

@end
