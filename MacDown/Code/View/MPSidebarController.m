//
//  MPSidebarController.m
//  MacDown
//

#import "MPSidebarController.h"


/// A heading, with the range of its line in the Markdown source.
@interface MPOutlineNode : NSObject
@property (copy, nonatomic) NSString *title;
@property (assign, nonatomic) NSInteger level;
@property (assign, nonatomic) NSRange range;
@property (strong, nonatomic) NSMutableArray<MPOutlineNode *> *children;
@end

@implementation MPOutlineNode
- (NSMutableArray *)children
{
    if (!_children)
        _children = [NSMutableArray array];
    return _children;
}
@end


/// A file or folder beside the document. Children are read on demand, so
/// opening a folder full of folders costs nothing until it is expanded.
@interface MPFileNode : NSObject
@property (strong, nonatomic) NSURL *url;
@property (copy, nonatomic) NSString *name;
@property (assign, nonatomic) BOOL directory;
@property (strong, nonatomic) NSArray<MPFileNode *> *loadedChildren;
@end

@implementation MPFileNode
@end


@implementation MPSidebarRemoteFile
@end


typedef NS_ENUM(NSUInteger, MPSidebarMode) {
    MPSidebarModeOutline = 0,
    MPSidebarModeFiles = 1,
    MPSidebarModeAttachments = 2,
};


@interface MPSidebarController () <NSOutlineViewDataSource,
                                  NSOutlineViewDelegate,
                                  NSSplitViewDelegate, NSMenuDelegate>

@property (strong, nonatomic) NSView *view;
@property (strong, nonatomic) NSOutlineView *outlineView;
@property (strong, nonatomic) NSSegmentedControl *modeControl;
@property (assign, nonatomic) MPSidebarMode mode;
@property (copy, nonatomic) NSArray<MPOutlineNode *> *headings;
/// Flattened, in document order, for finding the heading around the caret.
@property (copy, nonatomic) NSArray<MPOutlineNode *> *headingsInOrder;
@property (strong, nonatomic) MPFileNode *root;
/// L'elenco che viene da un servizio, quando il documento non sta su
/// disco. Nil quando la barra mostra una cartella vera.
@property (copy, nonatomic) NSArray<MPSidebarRemoteFile *> *remoteFiles;
@property (copy, nonatomic) NSString *remotePlaceName;
/// Gli allegati del documento, quelli che il testo si porta dietro.
@property (copy, nonatomic) NSArray<NSURL *> *attachments;
/// Set while the selection is being driven from the caret, so that echoing
/// it back to the editor is skipped.
@property (assign, nonatomic) BOOL selectingProgrammatically;
@end


@implementation MPSidebarController

#pragma mark - Interface

- (NSView *)view
{
    if (_view)
        return _view;

    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];

    NSSegmentedControl *mode = [NSSegmentedControl
        segmentedControlWithLabels:@[NSLocalizedString(@"Outline", @"sidebar outline tab"),
                                     NSLocalizedString(@"Files", @"sidebar files tab"),
                                     NSLocalizedString(@"Attached", @"sidebar attachments tab")]
                      trackingMode:NSSegmentSwitchTrackingSelectOne
                            target:self action:@selector(modeChanged:)];
    mode.selectedSegment = 0;
    mode.segmentDistribution = NSSegmentDistributionFillEqually;
    self.modeControl = mode;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.borderType = NSNoBorder;

    NSOutlineView *outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    outline.dataSource = self;
    outline.delegate = self;
    outline.headerView = nil;
    outline.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    outline.floatsGroupRows = NO;
    outline.indentationPerLevel = 13.0;
    outline.backgroundColor = [NSColor clearColor];
    // The sidebar look: translucent, with the selection drawn to match.
    outline.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    // A single click is enough. Waiting for a double click to jump to a
    // heading makes the outline feel like a file dialog rather than a map.
    outline.target = self;
    outline.action = @selector(rowClicked:);
    outline.menu = [[NSMenu alloc] initWithTitle:@""];
    outline.menu.delegate = self;

    NSTableColumn *column =
        [[NSTableColumn alloc] initWithIdentifier:@"MPSidebarColumn"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [outline addTableColumn:column];
    outline.outlineTableColumn = column;
    scroll.documentView = outline;
    self.outlineView = outline;

    NSVisualEffectView *backdrop =
        [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    backdrop.material = NSVisualEffectMaterialSidebar;
    backdrop.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    backdrop.state = NSVisualEffectStateFollowsWindowActiveState;

    for (NSView *view in @[backdrop, mode, scroll])
    {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [backdrop.topAnchor constraintEqualToAnchor:container.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [backdrop.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        // Clear of the toolbar, which the content now runs underneath.
        [mode.topAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.topAnchor
                                       constant:8.0],
        [mode.leadingAnchor constraintEqualToAnchor:container.leadingAnchor
                                           constant:10.0],
        [mode.trailingAnchor constraintEqualToAnchor:container.trailingAnchor
                                            constant:-10.0],

        [scroll.topAnchor constraintEqualToAnchor:mode.bottomAnchor
                                         constant:8.0],
        [scroll.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    _view = container;
    return _view;
}

- (void)modeChanged:(id)sender
{
    self.mode = (MPSidebarMode)self.modeControl.selectedSegment;
    if (self.mode == MPSidebarModeAttachments
            && [self.delegate respondsToSelector:
                    @selector(sidebarNeedsTheAttachments)])
        [self.delegate sidebarNeedsTheAttachments];
    [self.outlineView reloadData];
    if (self.mode == MPSidebarModeOutline)
        [self.outlineView expandItem:nil expandChildren:YES];
}

#pragma mark - Outline

/** Reads the headings out of the Markdown.
 *
 * Both spellings: the hash form, and the underlined setext form where the
 * level comes from the character used. Fenced code is skipped, since a
 * comment starting with a hash is not a heading.
 */
- (void)updateOutlineWithMarkdown:(NSString *)markdown
{
    NSMutableArray<MPOutlineNode *> *flat = [NSMutableArray array];
    NSArray<NSString *> *lines = [markdown componentsSeparatedByString:@"\n"];
    NSUInteger location = 0;
    BOOL inFence = NO;

    for (NSUInteger i = 0; i < lines.count; i++)
    {
        NSString *line = lines[i];
        NSUInteger lineLength = line.length;
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];

        if ([trimmed hasPrefix:@"```"] || [trimmed hasPrefix:@"~~~"])
            inFence = !inFence;

        if (!inFence)
        {
            MPOutlineNode *node = nil;

            if ([trimmed hasPrefix:@"#"])
            {
                NSUInteger hashes = 0;
                while (hashes < trimmed.length
                       && [trimmed characterAtIndex:hashes] == '#')
                    hashes++;
                NSString *rest = [[trimmed substringFromIndex:hashes]
                    stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceCharacterSet]];
                // "#hashtag" is not a heading; a space has to follow.
                if (hashes >= 1 && hashes <= 6 && rest.length
                        && [trimmed characterAtIndex:hashes] == ' ')
                {
                    node = [[MPOutlineNode alloc] init];
                    node.level = (NSInteger)hashes;
                    node.title = [rest stringByTrimmingCharactersInSet:
                        [NSCharacterSet characterSetWithCharactersInString:@"# "]];
                }
            }
            else if (trimmed.length && i + 1 < lines.count)
            {
                NSString *next = [lines[i + 1] stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]];
                BOOL equals = next.length >= 2
                    && [next stringByTrimmingCharactersInSet:
                        [NSCharacterSet characterSetWithCharactersInString:@"="]].length == 0;
                BOOL dashes = next.length >= 2
                    && [next stringByTrimmingCharactersInSet:
                        [NSCharacterSet characterSetWithCharactersInString:@"-"]].length == 0;
                if (equals || dashes)
                {
                    node = [[MPOutlineNode alloc] init];
                    node.level = equals ? 1 : 2;
                    node.title = trimmed;
                }
            }

            if (node)
            {
                node.range = NSMakeRange(location, lineLength);
                [flat addObject:node];
            }
        }

        location += lineLength + 1;   // + the newline
    }

    self.headingsInOrder = flat;
    self.headings = [self treeFromHeadings:flat];

    if (self.mode == MPSidebarModeOutline && _view)
    {
        [self.outlineView reloadData];
        [self.outlineView expandItem:nil expandChildren:YES];
    }
}

/// Nests each heading under the nearest preceding one of a lower level.
- (NSArray<MPOutlineNode *> *)treeFromHeadings:(NSArray<MPOutlineNode *> *)flat
{
    NSMutableArray<MPOutlineNode *> *roots = [NSMutableArray array];
    NSMutableArray<MPOutlineNode *> *stack = [NSMutableArray array];

    for (MPOutlineNode *node in flat)
    {
        while (stack.count && stack.lastObject.level >= node.level)
            [stack removeLastObject];

        if (stack.count)
            [stack.lastObject.children addObject:node];
        else
            [roots addObject:node];

        [stack addObject:node];
    }
    return roots;
}

- (void)selectHeadingContainingLocation:(NSUInteger)location
{
    if (self.mode != MPSidebarModeOutline || !_view)
        return;

    MPOutlineNode *found = nil;
    for (MPOutlineNode *node in self.headingsInOrder)
    {
        if (node.range.location > location)
            break;
        found = node;
    }
    if (!found)
        return;

    NSInteger row = [self.outlineView rowForItem:found];
    if (row < 0)
        return;

    self.selectingProgrammatically = YES;
    [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                  byExtendingSelection:NO];
    [self.outlineView scrollRowToVisible:row];
    self.selectingProgrammatically = NO;
}

#pragma mark - Files

- (void)setRootURL:(NSURL *)url
{
    if (url.isFileURL)
    {
        // Una cartella vera prende il posto dell'elenco del servizio.
        self.remoteFiles = nil;
        self.remotePlaceName = nil;
    }
    else if (self.remoteFiles)
    {
        return;                 // l'elenco del servizio resta quello
    }

    if (!url.isFileURL)
    {
        self.root = nil;
    }
    else
    {
        MPFileNode *node = [[MPFileNode alloc] init];
        node.url = url;
        node.name = url.lastPathComponent;
        node.directory = YES;
        self.root = node;
    }

    if (self.mode == MPSidebarModeFiles && _view)
        [self.outlineView reloadData];
}

- (void)showAttachments:(NSArray<NSURL *> *)attachments
{
    self.attachments = attachments ?: @[];
    if (self.mode == MPSidebarModeAttachments && _view)
        [self.outlineView reloadData];
}


- (void)showRemoteDocuments:(NSArray<MPSidebarRemoteFile *> *)documents
                       from:(NSString *)placeName
{
    self.remoteFiles = documents;
    self.remotePlaceName = documents ? placeName : nil;
    if (documents)
        self.root = nil;        // la cartella di prima non c'entra più
    if (self.mode == MPSidebarModeFiles && _view)
        [self.outlineView reloadData];
}


/// Sorted with folders first, then by name, and dotfiles left out.
- (NSArray<MPFileNode *> *)childrenOfFileNode:(MPFileNode *)node
{
    if (node.loadedChildren)
        return node.loadedChildren;
    if (!node.directory)
        return @[];

    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray<NSURL *> *contents =
        [manager contentsOfDirectoryAtURL:node.url
               includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                    error:NULL];

    NSMutableArray<MPFileNode *> *children = [NSMutableArray array];
    for (NSURL *url in contents)
    {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey
                        error:NULL];

        MPFileNode *child = [[MPFileNode alloc] init];
        child.url = url;
        child.name = url.lastPathComponent;
        child.directory = isDirectory.boolValue;
        [children addObject:child];
    }

    [children sortUsingComparator:^NSComparisonResult(MPFileNode *a,
                                                      MPFileNode *b) {
        if (a.directory != b.directory)
            return a.directory ? NSOrderedAscending : NSOrderedDescending;
        return [a.name localizedStandardCompare:b.name];
    }];

    node.loadedChildren = children;
    return children;
}

#pragma mark - NSMenuDelegate

/// Il menu si rifà quando si preme, sulla riga che si è premuta: fuori
/// dagli allegati non c'è niente da offrire, e un menu vuoto non si apre.
- (void)menuNeedsUpdate:(NSMenu *)menu
{
    [menu removeAllItems];
    NSInteger row = self.outlineView.clickedRow;
    if (row < 0)
        return;
    NSMenu *made = [self menuForAttachmentAt:row];
    for (NSMenuItem *item in made.itemArray.copy)
    {
        [made removeItem:item];
        [menu addItem:item];
    }
}


#pragma mark - NSSplitViewDelegate

/* The controller is the delegate of its own split view rather than the
 * document, which is already delegate of the editor/preview one and would
 * have to tell the two apart on every call. */

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return subview == self.view;
}

- (CGFloat)splitView:(NSSplitView *)splitView
    constrainMinCoordinate:(CGFloat)proposed ofSubviewAt:(NSInteger)index
{
    return (index == 0) ? 170.0 : proposed;
}

- (CGFloat)splitView:(NSSplitView *)splitView
    constrainMaxCoordinate:(CGFloat)proposed ofSubviewAt:(NSInteger)index
{
    return (index == 0) ? 420.0 : MIN(proposed, 420.0);
}

/// The panes absorb a window resize; the sidebar keeps the width it was
/// given, which is what one expects of a sidebar.
- (BOOL)splitView:(NSSplitView *)splitView
    shouldAdjustSizeOfSubview:(NSView *)subview
{
    return subview != self.view;
}

#pragma mark - NSOutlineViewDataSource

- (NSArray *)childrenOfItem:(id)item
{
    if (self.mode == MPSidebarModeOutline)
    {
        if (!item)
            return self.headings ?: @[];
        return [(MPOutlineNode *)item children];
    }

    if (self.mode == MPSidebarModeAttachments)
        return item ? @[] : (self.attachments ?: @[]);
    if (self.remoteFiles)
        return item ? @[] : self.remoteFiles;
    if (!item)
        return self.root ? [self childrenOfFileNode:self.root] : @[];
    return [self childrenOfFileNode:(MPFileNode *)item];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView
  numberOfChildrenOfItem:(id)item
{
    return (NSInteger)[self childrenOfItem:item].count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index
           ofItem:(id)item
{
    return [self childrenOfItem:item][(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if ([item isKindOfClass:[MPOutlineNode class]])
        return [(MPOutlineNode *)item children].count > 0;
    if ([item isKindOfClass:[MPSidebarRemoteFile class]]
            || [item isKindOfClass:[NSURL class]])
        return NO;              // là dentro non si scende: è un elenco
    return [(MPFileNode *)item directory];
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableCellView *cell =
        [outlineView makeViewWithIdentifier:@"MPSidebarCell" owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"MPSidebarCell";

        NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:icon];
        cell.imageView = icon;

        NSTextField *label = [NSTextField labelWithString:@""];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:label];
        cell.textField = label;

        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:16.0],
            [icon.heightAnchor constraintEqualToConstant:16.0],
            [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor
                                                constant:5.0],
            [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor
                                                 constant:-4.0],
            [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }

    if ([item isKindOfClass:[MPOutlineNode class]])
    {
        MPOutlineNode *node = item;
        cell.textField.stringValue = node.title ?: @"";
        cell.imageView.image = nil;
        // Depth is already shown by the indentation; the weight separates a
        // section title from the paragraphs of headings beneath it.
        cell.textField.font = (node.level <= 2)
            ? [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold]
            : [NSFont systemFontOfSize:12.0];
        cell.textField.textColor = [NSColor labelColor];
    }
    else if ([item isKindOfClass:[NSURL class]])
    {
        NSURL *file = item;
        cell.textField.stringValue = file.lastPathComponent ?: @"";
        cell.textField.font = [NSFont systemFontOfSize:12.0];
        cell.textField.textColor = [NSColor labelColor];
        cell.imageView.image =
            [[NSWorkspace sharedWorkspace] iconForFile:file.path];
        cell.toolTip = file.path;
    }
    else if ([item isKindOfClass:[MPSidebarRemoteFile class]])
    {
        MPSidebarRemoteFile *remote = item;
        cell.textField.stringValue = remote.name ?: @"";
        cell.textField.font = [NSFont systemFontOfSize:12.0];
        cell.textField.textColor = [NSColor labelColor];
        // Il documento col simbolo della nuvola: dice da dove viene senza
        // aggiungere una parola all'elenco.
        cell.imageView.image = [NSImage imageWithSystemSymbolName:@"doc.text"
                                       accessibilityDescription:nil];
        cell.imageView.contentTintColor = [NSColor secondaryLabelColor];
    }
    else
    {
        MPFileNode *node = item;
        cell.textField.stringValue = node.name ?: @"";
        cell.textField.font = [NSFont systemFontOfSize:12.0];
        cell.imageView.image =
            [[NSWorkspace sharedWorkspace] iconForFile:node.url.path];
        // Anything that is not a folder or a document reads as unavailable,
        // since opening it here would do nothing useful.
        BOOL openable = node.directory || [self isTextURL:node.url];
        cell.textField.textColor = openable
            ? [NSColor labelColor] : [NSColor tertiaryLabelColor];
    }
    return cell;
}

- (BOOL)isTextURL:(NSURL *)url
{
    static NSSet *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"md", @"markdown", @"mdown",
                                           @"mkd", @"mkdn", @"text", @"txt"]];
    });
    return [extensions containsObject:url.pathExtension.lowercaseString];
}

/// Il menu del tasto destro su un allegato: quello che si fa con un file.
- (NSMenu *)menuForAttachmentAt:(NSInteger)row
{
    id item = [self.outlineView itemAtRow:row];
    if (![item isKindOfClass:[NSURL class]])
        return nil;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *save = [menu addItemWithTitle:NSLocalizedString(
        @"Save a Copy…", @"Button: write the attachment somewhere else")
        action:@selector(saveClickedAttachment:) keyEquivalent:@""];
    save.target = self;
    save.representedObject = item;
    NSMenuItem *open = [menu addItemWithTitle:NSLocalizedString(@"Open",
        @"Button: open the attachment where it is")
        action:@selector(openClickedAttachment:) keyEquivalent:@""];
    open.target = self;
    open.representedObject = item;
    NSMenuItem *reveal = [menu addItemWithTitle:NSLocalizedString(
        @"Show in Finder", @"Menu item: reveal the attachment on disk")
        action:@selector(revealClickedAttachment:) keyEquivalent:@""];
    reveal.target = self;
    reveal.representedObject = item;
    return menu;
}


- (void)saveClickedAttachment:(NSMenuItem *)item
{
    if ([self.delegate respondsToSelector:
            @selector(sidebarDidAskToSaveAttachment:)])
        [self.delegate sidebarDidAskToSaveAttachment:item.representedObject];
}

- (void)openClickedAttachment:(NSMenuItem *)item
{
    [[NSWorkspace sharedWorkspace] openURL:item.representedObject];
}

- (void)revealClickedAttachment:(NSMenuItem *)item
{
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:
        @[item.representedObject]];
}


- (void)rowClicked:(id)sender
{
    if (self.selectingProgrammatically)
        return;

    NSInteger row = self.outlineView.clickedRow;
    if (row < 0)
        return;

    id item = [self.outlineView itemAtRow:row];
    if ([item isKindOfClass:[MPOutlineNode class]])
    {
        [self.delegate sidebarDidSelectHeadingRange:
            [(MPOutlineNode *)item range]];
        return;
    }

    if ([item isKindOfClass:[NSURL class]])
    {
        if ([self.delegate respondsToSelector:
                @selector(sidebarDidSelectAttachment:)])
            [self.delegate sidebarDidSelectAttachment:item];
        return;
    }

    if ([item isKindOfClass:[MPSidebarRemoteFile class]])
    {
        MPSidebarRemoteFile *remote = item;
        if ([self.delegate respondsToSelector:
                @selector(sidebarDidSelectRemoteDocument:named:)])
            [self.delegate sidebarDidSelectRemoteDocument:remote.identifier
                                                    named:remote.name];
        return;
    }

    MPFileNode *node = item;
    if (node.directory)
    {
        // Folders open in place rather than in the editor.
        if ([self.outlineView isItemExpanded:node])
            [self.outlineView collapseItem:node];
        else
            [self.outlineView expandItem:node];
        return;
    }
    if ([self isTextURL:node.url])
        [self.delegate sidebarDidSelectFileURL:node.url];
}

@end
