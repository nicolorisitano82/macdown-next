//
//  MDDrawioPlugIn.m
//  MacDown Next — draw.io plug-in
//

#import "MDDrawioPlugIn.h"
#import "MDDrawioFile.h"
#import "MDDrawioRenderer.h"
#import "MDDrawioResources.h"
#import "MDDrawioProgress.h"
#import "MDDrawioLog.h"
#import "MDDrawioStrings.h"

/// What was asked for last time, remembered in the application's defaults.
static NSString * const kMDScaleKey = @"MDDrawioScale";
static NSString * const kMDUseServiceKey = @"MDDrawioUsesExportServer";
static NSString * const kMDServiceKey = @"MDDrawioExportServer";


#pragma mark - Reaching the document

/// The first text view inside a view, which in this window is the editor.
static NSTextView *MDTextViewIn(NSView *view)
{
    if ([view isKindOfClass:[NSTextView class]])
        return (NSTextView *)view;
    for (NSView *child in view.subviews)
    {
        NSTextView *found = MDTextViewIn(child);
        if (found)
            return found;
    }
    return nil;
}

/** The editor of a document, found through the window rather than the class.
 *
 * A plug-in is loaded into the application and could call straight into
 * MPDocument, which would tie it to the version of MacDown Next it was
 * built against. A text view in a window is a text view in any version.
 */
static NSTextView *MDEditorOfDocument(NSDocument *document)
{
    for (NSWindowController *controller in document.windowControllers)
    {
        NSWindow *window = controller.window;
        if ([window.firstResponder isKindOfClass:[NSTextView class]])
            return (NSTextView *)window.firstResponder;
        NSTextView *found = MDTextViewIn(window.contentView);
        if (found)
            return found;
    }
    return nil;
}

@implementation MDDrawioNaming

/// A name that can be a file name: no separators, no surprises.
+ (NSString *)fileNameSlugOf:(NSString *)name
{
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet
        alphanumericCharacterSet];
    [allowed addCharactersInString:@"-_ àèéìòùáíóúäöüçñ"];
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < name.length; i++)
    {
        unichar c = [name characterAtIndex:i];
        [out appendString:[allowed characterIsMember:c]
            ? [NSString stringWithCharacters:&c length:1] : @"-"];
    }
    NSString *slug = [out stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    return slug.length ? slug : @"pagina";
}

+ (NSString *)linkTargetForFile:(NSURL *)file besideDocument:(NSURL *)document
{
    NSString *path = file.URLByStandardizingPath.path;
    NSString *folder = document.URLByDeletingLastPathComponent
        .URLByStandardizingPath.path;
    if (folder.length && [path hasPrefix:[folder stringByAppendingString:@"/"]])
        path = [path substringFromIndex:folder.length + 1];

    NSCharacterSet *safe = [NSCharacterSet
        characterSetWithCharactersInString:
            @"abcdefghijklmnopqrstuvwxyz"
            @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/"];
    return [path stringByAddingPercentEncodingWithAllowedCharacters:safe];
}

@end


#pragma mark - The sheet

/// Scale, and which of the two ways the drawing is done.
@interface MDDrawioOptions : NSView
@property (strong, nonatomic) NSPopUpButton *scaleButton;
@property (strong, nonatomic) NSButton *hereRadio;
@property (strong, nonatomic) NSButton *serviceRadio;
@property (strong, nonatomic) NSTextField *serviceField;
@end


@implementation MDDrawioOptions

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults
{
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, 420.0, 116.0)];
    if (!self)
        return nil;

    NSTextField *sizeLabel = [NSTextField labelWithString:
        MDLocalizedString(@"Size:", @"How big the picture is drawn")];
    sizeLabel.alignment = NSTextAlignmentRight;
    sizeLabel.frame = NSMakeRect(0.0, 94.0, 92.0, 18.0);
    [self addSubview:sizeLabel];

    _scaleButton = [[NSPopUpButton alloc]
        initWithFrame:NSMakeRect(96.0, 90.0, 150.0, 25.0) pullsDown:NO];
    [_scaleButton addItemsWithTitles:@[@"1×", @"2× (retina)", @"3×"]];
    double scale = [defaults doubleForKey:kMDScaleKey];
    [_scaleButton selectItemAtIndex:(scale >= 3.0 ? 2 : (scale <= 1.0 ? 0 : 1))];
    [self addSubview:_scaleButton];

    NSTextField *whereLabel = [NSTextField labelWithString:
        MDLocalizedString(@"Draw:", @"Where the drawing happens")];
    whereLabel.alignment = NSTextAlignmentRight;
    whereLabel.frame = NSMakeRect(0.0, 64.0, 92.0, 18.0);
    [self addSubview:whereLabel];

    _hereRadio = [NSButton radioButtonWithTitle:
        MDLocalizedString(@"On this Mac, with no connection",
                          @"Draw with the viewer inside the plug-in")
                                         target:self
                                         action:@selector(whereChanged:)];
    _hereRadio.frame = NSMakeRect(96.0, 62.0, 300.0, 20.0);
    [self addSubview:_hereRadio];

    _serviceRadio = [NSButton radioButtonWithTitle:
        MDLocalizedString(@"On an export server, at this address:",
                          @"Draw by sending the diagram somewhere")
                                            target:self
                                            action:@selector(whereChanged:)];
    _serviceRadio.frame = NSMakeRect(96.0, 40.0, 300.0, 20.0);
    [self addSubview:_serviceRadio];

    BOOL service = [defaults boolForKey:kMDUseServiceKey];
    _hereRadio.state = service ? NSControlStateValueOff
                               : NSControlStateValueOn;
    _serviceRadio.state = service ? NSControlStateValueOn
                                  : NSControlStateValueOff;

    _serviceField = [NSTextField textFieldWithString:
        [defaults stringForKey:kMDServiceKey] ?: @"http://localhost:8000/"];
    _serviceField.frame = NSMakeRect(114.0, 12.0, 282.0, 22.0);
    _serviceField.placeholderString = @"http://localhost:8000/";
    [self addSubview:_serviceField];

    [self whereChanged:nil];
    return self;
}

- (void)whereChanged:(id)sender
{
    self.serviceField.enabled = self.usesService;
}

- (BOOL)usesService
{
    return self.serviceRadio.state == NSControlStateValueOn;
}

- (CGFloat)scale
{
    switch (self.scaleButton.indexOfSelectedItem)
    {
        case 0: return 1.0;
        case 2: return 3.0;
        default: return 2.0;
    }
}

- (NSURL *)service
{
    NSString *text = [self.serviceField.stringValue
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length ? [NSURL URLWithString:text] : nil;
}

@end


#pragma mark - The plug-in

@interface MDDrawioPlugIn ()
@property (strong, nonatomic) MDDrawioRenderer *renderer;
@property (strong, nonatomic) MDDrawioProgress *progress;
/// Kept after the import so its window can outlive the alert that offers it.
@property (strong, nonatomic) MDDrawioLog *log;
@end


NSBundle *MDDrawioBundle(void)
{
    // The principal class is in the plug-in, so the bundle it came from is
    // the plug-in — wherever it was installed.
    return [NSBundle bundleForClass:[MDDrawioPlugIn class]];
}


@implementation MDDrawioPlugIn

- (NSString *)name
{
    return MDLocalizedString(@"Import a draw.io Diagram…",
                             @"Plug-in menu item");
}

- (BOOL)run:(id)sender
{
    NSDocument *document =
        [NSDocumentController sharedDocumentController].currentDocument;
    NSTextView *editor = document ? MDEditorOfDocument(document) : nil;
    if (!document || !editor)
    {
        [self say:MDLocalizedString(@"Open a document",
                                    @"There is no document to import into")
              text:MDLocalizedString(
            @"The diagram goes into a document, so there has to be one in "
            @"front of you.", @"Why a document is needed")];
        return NO;
    }
    // The picture goes beside the document, and a link to it is relative to
    // the document's folder. Without a folder there is neither.
    if (!document.fileURL)
    {
        [self say:MDLocalizedString(@"Save the document first",
                                    @"The document has no folder yet")
              text:MDLocalizedString(
            @"The pictures are written beside the document, and a document "
            @"that has not been saved has no folder to sit beside.",
            @"Why the document has to be saved first")];
        return NO;
    }

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"drawio", @"xml", @"png", @"svg"];
    panel.allowsMultipleSelection = NO;
    panel.message = MDLocalizedString(
        @"Choose the draw.io diagram to import", @"Open panel message");
    if ([panel runModal] != NSModalResponseOK || !panel.URL)
        return YES;   // asked and answered: nothing went wrong

    self.log = [[MDDrawioLog alloc] init];
    NSNumber *size = nil;
    [panel.URL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
    [self.log noteFormat:@"file: %@ (%@ bytes)", panel.URL.path, size];

    NSError *error = nil;
    MDDrawioFile *file = [MDDrawioFile fileWithURL:panel.URL error:&error];
    if (!file)
    {
        [self.log noteFormat:@"not read: %@ (%@ %ld)",
            error.localizedDescription, error.domain, (long)error.code];
        [self say:MDLocalizedString(@"The diagram could not be read",
                                    @"The file did not parse")
             text:error.localizedDescription];
        return NO;
    }

    [self.log noteFormat:@"pages: %lu", (unsigned long)file.pages.count];
    for (MDDrawioPage *page in file.pages)
    {
        [self.log noteFormat:@"  “%@”, %lu characters of model",
            page.name, (unsigned long)page.xml.length];
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    MDDrawioOptions *options =
        [[MDDrawioOptions alloc] initWithDefaults:defaults];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = file.pages.count == 1
        ? MDLocalizedString(@"Import the Diagram", @"One page to import")
        : [NSString stringWithFormat:MDLocalizedString(@"Import %lu Pages",
              @"Several pages to import"),
           (unsigned long)file.pages.count];
    alert.informativeText =
        MDLocalizedString(
        @"Every page becomes a PNG beside the document, and is linked where "
        @"the cursor is. On this Mac the diagram never leaves the machine "
        @"and no connection is needed: the viewer and the shape libraries "
        @"are inside the plug-in. On an export server the diagram is sent "
        @"to the address you name.", @"What importing does, and what goes "
        @"out of the Mac");
    [alert addButtonWithTitle:MDLocalizedString(@"Import",
        @"Go ahead with the import")];
    [alert addButtonWithTitle:MDLocalizedString(@"Cancel",
        @"Do not import")];
    alert.accessoryView = options;

    if ([alert runModal] != NSAlertFirstButtonReturn)
        return YES;

    [defaults setDouble:options.scale forKey:kMDScaleKey];
    [defaults setBool:options.usesService forKey:kMDUseServiceKey];
    if (options.usesService && options.service)
        [defaults setObject:options.service.absoluteString forKey:kMDServiceKey];

    if (options.usesService && !options.service)
    {
        [self say:MDLocalizedString(@"The address is missing",
                                    @"No export server was given")
              text:MDLocalizedString(
            @"Drawing on an export server needs its address.",
            @"Why the address is needed")];
        return NO;
    }

    NSURL *service = options.usesService ? options.service : nil;
    [self.log noteFormat:@"scale %g, %@", options.scale,
        service ? [@"export server " stringByAppendingString:
                    service.absoluteString] : @"drawn here"];

    self.renderer = [[MDDrawioRenderer alloc]
        initWithBundle:[NSBundle bundleForClass:[self class]]];

    [self renderPagesOf:file from:panel.URL into:document editor:editor
                  scale:options.scale service:service];
    return YES;
}

/** One page at a time, because the local renderer holds one web view.
 *
 * Written and linked as they arrive rather than all at the end: a diagram
 * of twenty pages that fails on the nineteenth should still have brought
 * in eighteen.
 */
- (void)renderPagesOf:(MDDrawioFile *)file
                 from:(NSURL *)source
                 into:(NSDocument *)document
               editor:(NSTextView *)editor
                scale:(CGFloat)scale
              service:(NSURL *)service
{
    NSMutableArray<MDDrawioPage *> *queue = [file.pages mutableCopy];
    NSMutableArray<NSString *> *problems = [NSMutableArray array];
    NSString *stem = source.lastPathComponent.stringByDeletingPathExtension;
    NSUInteger total = file.pages.count;
    NSWindow *window = document.windowControllers.firstObject.window;

    self.progress = [[MDDrawioProgress alloc] init];
    [self.progress showOnWindow:window
                          title:MDLocalizedString(@"Importing the diagram",
                                    @"Title of the progress panel")];

    __block NSUInteger index = 0;
    __block void (^next)(void) = nil;
    void (^step)(void) = ^{
        BOOL stopped = self.progress.isCancelled;
        if (stopped && queue.count)
        {
            [self.log noteFormat:@"cancelled: %lu pages not drawn",
                (unsigned long)queue.count];
        }

        if (!queue.count || stopped)
        {
            [self.progress finish];
            self.progress = nil;
            next = nil;

            if (problems.count)
            {
                [self.log noteFormat:@"finished with %lu problems",
                    (unsigned long)problems.count];
                [self say:MDLocalizedString(
                    @"Not every page arrived", @"Some pages failed")
                     text:[problems componentsJoinedByString:@"\n"]
                  offerLog:YES];
            }
            else
            {
                [self.log note:@"finished"];
            }
            return;
        }

        MDDrawioPage *page = queue.firstObject;
        [queue removeObjectAtIndex:0];
        index++;

        NSString *label = page.name.length ? page.name
            : (total > 1
               ? [NSString stringWithFormat:MDLocalizedString(@"page %lu",
                     @"A page with no name of its own"),
                  (unsigned long)index]
               : stem);

        [self.progress showPage:index of:total named:label];
        [self.log noteFormat:@"page %lu/%lu “%@”: drawing",
            (unsigned long)index, (unsigned long)total, label];

        MDDrawioRenderHandler done = ^(NSData *png, NSError *error) {
            // What the drawing needed and what it could not get: the one
            // thing that explains a shape coming out as a rectangle.
            NSArray *served = self.renderer.resources.servedPaths;
            NSArray *missing = self.renderer.resources.failedPaths;
            if (served.count)
                [self.log noteFormat:@"  served: %@",
                    [served componentsJoinedByString:@", "]];
            if (missing.count)
                [self.log noteFormat:@"  NOT served: %@",
                    [missing componentsJoinedByString:@", "]];

            if (!png)
            {
                [self.log noteFormat:@"  error: %@ (%@ %ld)",
                    error.localizedDescription, error.domain,
                    (long)error.code];
                [problems addObject:[NSString stringWithFormat:@"%@: %@",
                    label, error.localizedDescription
                        ?: MDLocalizedString(@"it did not draw",
                               @"A page failed and said nothing")]];
            }
            else
            {
                [self.log noteFormat:@"  %lu bytes of PNG",
                    (unsigned long)png.length];
                NSString *problem = [self write:png forLabel:label
                                           stem:stem document:document
                                         editor:editor
                                     manyPages:total > 1];
                if (problem)
                    [problems addObject:problem];
            }
            if (next)
                next();
        };

        if (service)
            [self.renderer renderPage:page scale:scale onService:service
                           completion:done];
        else
            [self.renderer renderPage:page scale:scale completion:done];
    };
    next = step;
    step();
}

/// Writes the picture beside the document and links it, once.
- (NSString *)write:(NSData *)png
           forLabel:(NSString *)label
               stem:(NSString *)stem
           document:(NSDocument *)document
             editor:(NSTextView *)editor
          manyPages:(BOOL)manyPages
{
    NSString *name = manyPages
        ? [NSString stringWithFormat:@"%@-%@.png", [MDDrawioNaming fileNameSlugOf:stem],
           [MDDrawioNaming fileNameSlugOf:label]]
        : [NSString stringWithFormat:@"%@.png",
           [MDDrawioNaming fileNameSlugOf:stem]];
    NSURL *folder = document.fileURL.URLByDeletingLastPathComponent;
    NSURL *file = [folder URLByAppendingPathComponent:name];

    NSError *error = nil;
    // Written over, deliberately: importing the same diagram again is how a
    // picture gets brought up to date, and the link must keep working.
    if (![png writeToURL:file options:NSDataWritingAtomic error:&error])
    {
        [self.log noteFormat:@"  not written to %@: %@ (%@ %ld)",
            file.path, error.localizedDescription, error.domain,
            (long)error.code];
        return [NSString stringWithFormat:@"%@: %@", label,
                error.localizedDescription];
    }
    [self.log noteFormat:@"  written %@", file.path];

    NSString *target = [MDDrawioNaming linkTargetForFile:file
                                      besideDocument:document.fileURL];
    NSString *markup = [NSString stringWithFormat:@"![%@](%@)\n",
                        label, target];

    // The document may already carry this link, from the last import of the
    // same diagram. The file has just been rewritten, so there is nothing
    // to add: adding it would show the same picture twice.
    if ([editor.string containsString:target])
    {
        [self.log noteFormat:@"  already linked as %@, not repeated", target];
        return nil;
    }

    NSRange at = editor.selectedRange;
    if (NSMaxRange(at) > editor.string.length)
        at = NSMakeRange(editor.string.length, 0);
    if ([editor shouldChangeTextInRange:at replacementString:markup])
    {
        [editor insertText:markup replacementRange:at];
        editor.selectedRange = NSMakeRange(at.location + markup.length, 0);
        [self.log noteFormat:@"  linked as %@", target];
    }
    else
    {
        [self.log note:@"  the editor did not accept the change"];
    }
    return nil;
}

- (void)say:(NSString *)title text:(NSString *)text
{
    [self say:title text:text offerLog:NO];
}

/** Says what went wrong, and offers what was actually attempted.
 *
 * "Non si è potuta disegnare" is true and useless: an import touches a file
 * it did not write, a renderer it does not control and a folder it may not
 * be able to write to, and which of those it was is in the log.
 */
- (void)say:(NSString *)title text:(NSString *)text offerLog:(BOOL)offerLog
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = text ?: @"";
    [alert addButtonWithTitle:@"OK"];
    if (offerLog && self.log)
        [alert addButtonWithTitle:MDLocalizedString(@"Show the Log…",
            @"Open the import log")];

    if ([alert runModal] == NSAlertSecondButtonReturn && offerLog)
        [self.log showOnWindow:nil];
}

@end
