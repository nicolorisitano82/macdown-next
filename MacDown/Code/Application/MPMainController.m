//
//  MPMainController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPMainController.h"
#import "MPPlugInsWindowController.h"
#import "MPPlugInController.h"
#import "MPPlugIn.h"
#import "MPActionLog.h"
#import <MASPreferences/MASPreferencesWindowController.h>
#import "MPGlobals.h"
#import "MPUtilities.h"
#import "NSDocumentController+Document.h"
#import "NSUserDefaults+Suite.h"
#import "MPPreferences.h"
#import "MPGeneralPreferencesViewController.h"
#import "MPMarkdownPreferencesViewController.h"
#import "MPEditorPreferencesViewController.h"
#import "MPAgentsPreferencesViewController.h"
#import "MPQuickLookPreferencesViewController.h"
#import "MPUpdateController.h"
#import "MPUpdatePreferencesViewController.h"
#import "MPHtmlPreferencesViewController.h"
#import "MPTerminalPreferencesViewController.h"
#import "MPDocument.h"
#import "MPDocumentTemplate.h"
#import "MPModelsWindowController.h"


static NSString * const kMPTreatLastSeenStampKey = @"treatLastSeenStamp";


NS_INLINE void MPOpenBundledFile(NSString *resource, NSString *extension)
{
    NSURL *source = [[NSBundle mainBundle] URLForResource:resource
                                            withExtension:extension];
    NSString *filename = source.absoluteString.lastPathComponent;
    NSURL *target = [NSURL fileURLWithPathComponents:@[NSTemporaryDirectory(),
                                                       filename]];
    BOOL ok = NO;
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtURL:target error:NULL];
    ok = [manager copyItemAtURL:source toURL:target error:NULL];

    if (!ok)
        return;
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    [c openDocumentWithContentsOfURL:target display:YES completionHandler:
     ^(NSDocument *document, BOOL wasOpen, NSError *error) {
         if (!document || wasOpen || error)
             return;
         NSRect frame = [NSScreen mainScreen].visibleFrame;
         for (NSWindowController *wc in document.windowControllers)
             [wc.window setFrame:frame display:YES];
     }];
}

NS_INLINE void treat()
{
    NSDictionary *info = MPGetDataMap(@"treats");
    NSString *name = info[@"name"];
    if (![NSUserName().lowercaseString hasPrefix:name]
            && ![NSFullUserName().lowercaseString hasPrefix:name])
        return;

    NSDictionary *data = info[@"data"];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSCalendarUnit unit =
        NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear;
    NSDateComponents *comps = [calendar components:unit fromDate:[NSDate date]];

    NSString *key =
        [NSString stringWithFormat:@"%02ld%02ld", comps.month, comps.day];
    if (!data[key])     // No matching treat.
        return;

    NSString *stamp = [NSString stringWithFormat:@"%ld%02ld%02ld",
                       comps.year, comps.month, comps.day];

    // User has seen this treat today.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults objectForKey:kMPTreatLastSeenStampKey] isEqual:stamp])
        return;

    [defaults setObject:stamp forKey:kMPTreatLastSeenStampKey];
    NSArray *components = @[NSTemporaryDirectory(), key];
    NSURL *url = [NSURL fileURLWithPathComponents:components];
    [data[key] writeToURL:url atomically:NO];

    // Make sure this is opened last and immediately visible.
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [c openDocumentWithContentsOfURL:url display:YES
                       completionHandler:MPDocumentOpenCompletionEmpty];
    }];
}


@interface MPMainController () <NSMenuDelegate>
@property (readonly) NSWindowController *preferencesWindowController;
@end


@implementation MPMainController

@synthesize preferencesWindowController = _preferencesWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // Using private API [WebCache setDisabled:YES] to disable WebView's cache
    id webCacheClass = (id)NSClassFromString(@"WebCache");
    if (webCacheClass) {
// Ignoring "undeclared selector" warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        BOOL setDisabledValue = YES;
        NSMethodSignature *signature = [webCacheClass methodSignatureForSelector:@selector(setDisabled:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = @selector(setDisabled:);
        invocation.target = [webCacheClass class];
        [invocation setArgument:&setDisabledValue atIndex:2];
        [invocation invoke];
#pragma clang diagnostic pop
    }
    [[NSAppleEventManager sharedAppleEventManager]
        setEventHandler:self
            andSelector:@selector(openUrlSchemeAppleEvent:withReplyEvent:)
          forEventClass:kInternetEventClass andEventID:kAEGetURL];

    [self takeChargeOfTheTemplateMenu];
    [self takeChargeOfTheExportMenu];
    [self addTheUpdateMenuItem];
    [[MPUpdateController sharedInstance] checkQuietlyIfDue];
}

/** Puts "Controlla aggiornamenti…" under the application menu.
 *
 * Added here rather than drawn in the nib because the nib is the one
 * MacDown has always had, translated into two dozen languages; a menu item
 * this fork adds is better added where it can be read than merged into a
 * file nobody diffs.
 */
- (void)addTheUpdateMenuItem
{
    NSMenu *application = [NSApp mainMenu].itemArray.firstObject.submenu;
    if (!application)
        return;
    for (NSMenuItem *item in application.itemArray)
    {
        if (item.action == @selector(checkForUpdates:))
            return;     // Already there: this is not the first launch.
    }

    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:
        NSLocalizedString(@"Check for Updates…",
            @"Application menu item that looks for a newer release")
        action:@selector(checkForUpdates:) keyEquivalent:@""];
    item.target = [MPUpdateController sharedInstance];
    // Under "About MacDown Next", where every application keeps it.
    [application insertItem:item atIndex:1];
    [application insertItem:[NSMenuItem separatorItem] atIndex:2];
}

/** Makes this the keeper of the template submenu.
 *
 * What is in it is which files are installed, and that is known when the
 * menu opens and not when the nib was drawn — a reader who drops a
 * template into their folder should find it there without relaunching.
 *
 * Here rather than in the document because there is one menu bar for every
 * window; the items aim at the first responder, so it is still the document
 * in front that inserts.
 */
/// The tag the nib puts on Format › Insert Template.
const NSInteger kMPTemplateMenuTag = 9001;
/// And the one on File › Export, which plug-ins add formats to.
const NSInteger kMPExportMenuTag = 9002;
/// What the items this adds are marked with, so that they can be taken away
/// again without touching the formats the application itself writes.
static const NSInteger kMPPlugInExportItemTag = 9003;

- (void)takeChargeOfTheTemplateMenu
{
    NSMenu *submenu = [self templateSubmenu];
    submenu.delegate = self;
}

/** Makes this the keeper of the export submenu as well.
 *
 * Which formats are there depends on which plug-ins are installed and
 * switched on, and that is known when the menu opens rather than when the
 * nib was drawn — switching an exporter off in the plug-ins window should
 * take its format out of the menu without a relaunch.
 */
- (void)takeChargeOfTheExportMenu
{
    NSMenu *submenu = [self submenuWithTag:kMPExportMenuTag];
    submenu.delegate = self;
}

- (NSMenu *)submenuWithTag:(NSInteger)tag
{
    for (NSMenuItem *top in [NSApp mainMenu].itemArray)
    {
        for (NSMenuItem *item in top.submenu.itemArray)
        {
            if (item.tag == tag && item.hasSubmenu)
                return item.submenu;
        }
    }
    return nil;
}

/// The formats plug-ins add, under the ones the application writes itself.
- (void)rebuildExportMenu:(NSMenu *)menu
{
    for (NSMenuItem *item in [menu.itemArray reverseObjectEnumerator])
    {
        if (item.tag == kMPPlugInExportItemTag)
            [menu removeItem:item];
    }

    NSArray<MPPlugIn *> *exporters = [MPPlugInController enabledExporters];
    if (!exporters.count)
        return;

    NSMenuItem *separator = [NSMenuItem separatorItem];
    separator.tag = kMPPlugInExportItemTag;
    [menu addItem:separator];

    for (MPPlugIn *exporter in exporters)
    {
        NSString *title = [NSString stringWithFormat:@"%@…",
                           exporter.exportFormatName];
        NSMenuItem *item = [menu addItemWithTitle:title
                                           action:@selector(exportWithPlugIn:)
                                    keyEquivalent:@""];
        // No target: it goes to whichever document is in front, like every
        // other export.
        item.representedObject = exporter;
        item.tag = kMPPlugInExportItemTag;
    }
}

/** Finds the template submenu by its tag.
 *
 * The first version of this walk also required `item.action == NULL`,
 * reasoning that an item which only opens a submenu does nothing itself.
 * It does: AppKit gives it `submenuAction:`. So nothing matched, the
 * delegate was never set, and the menu shipped exactly as the nib drew it
 * — empty. The identifier it also looked for was innocent, and is in the
 * compiled nib; I checked, after blaming it in a comment.
 *
 * A tag rather than a title, because a title is localised out from under
 * a lookup like this one.
 */
- (NSMenu *)templateSubmenu
{
    for (NSMenuItem *top in [NSApp mainMenu].itemArray)
    {
        for (NSMenuItem *item in top.submenu.itemArray)
        {
            if (item.tag == kMPTemplateMenuTag && item.submenu)
                return item.submenu;
        }
    }
    return nil;
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu == [self submenuWithTag:kMPExportMenuTag])
    {
        [self rebuildExportMenu:menu];
        return;
    }

    if (menu != [self templateSubmenu])
        return;

    [menu removeAllItems];
    NSArray<MPDocumentTemplate *> *templates =
        [MPDocumentTemplate installedTemplates];

    for (MPDocumentTemplate *template in templates)
    {
        NSMenuItem *item = [[NSMenuItem alloc]
            initWithTitle:template.name
                   action:@selector(insertDocumentTemplate:)
            keyEquivalent:@""];
        item.representedObject = template;
        // Nil target, so it walks the responder chain to the document that
        // is in front, and greys out when there is none.
        item.target = nil;
        [menu addItem:item];
    }

    if (!templates.count)
    {
        NSMenuItem *empty = [[NSMenuItem alloc]
            initWithTitle:NSLocalizedString(@"No Templates Installed",
                                            @"Template menu")
                   action:NULL keyEquivalent:@""];
        empty.enabled = NO;
        [menu addItem:empty];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *reveal = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Reveal Templates Folder",
                                        @"Template menu")
               action:@selector(revealTemplatesFolder:) keyEquivalent:@""];
    reveal.target = self;
    [menu addItem:reveal];
}

- (IBAction)showModelsPanel:(id)sender
{
    [[MPModelsWindowController sharedController] showPanel];
}

/// Opens the folder, which is how a reader adds one of their own.
- (IBAction)revealTemplatesFolder:(id)sender
{
    NSURL *folder = [MPDocumentTemplate customDirectory];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[folder]];
}

// Open a file from a browser with url of the form :
// "x-macdown://open?url=file:///path/to/a/file&line=123&column=45"
- (void)openUrlSchemeAppleEvent:(NSAppleEventDescriptor *)event
                 withReplyEvent:(NSAppleEventDescriptor *)reply
{
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (!urlString) {
        return;
    }
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    if (!url) {
        return;
    }
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url
                                                resolvingAgainstBaseURL:NO];
    if (!urlComponents) {
        return;
    }
    NSString *host = urlComponents.host;
    if (!host || ![host isEqualToString:@"open"]) {
        return;
    }
    NSArray *queryItems = urlComponents.queryItems;
    if (!queryItems) {
        return;
    }
    NSString *fileParam = [self valueForKey:@"url" fromQueryItems:queryItems];
    if (!fileParam) {
        return;
    }
    // FIXME: Could not figure out how to place the insertion point at a given
    // line and column.
    /* Unused */ NSString *lineParam = [self valueForKey:@"line"
                                          fromQueryItems:queryItems];
    /* Unused */ NSString *columnParam = [self valueForKey:@"column"
                                            fromQueryItems:queryItems];
    NSLog(@"%@:%@:%@", fileParam, lineParam, columnParam);

    NSURL *target = [NSURL URLWithString:fileParam];
    if (!target) {
        return;
    }
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    [c openDocumentWithContentsOfURL:target display:YES completionHandler:
     ^(NSDocument *document, BOOL wasOpen, NSError *error) {
         if (!document || wasOpen || error)
             return;
         NSRect frame = [NSScreen mainScreen].visibleFrame;
         for (NSWindowController *wc in document.windowControllers)
             [wc.window setFrame:frame display:YES];
     }];

}

- (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (NSWindowController *)preferencesWindowController
{
    if (!_preferencesWindowController)
    {
        NSArray *vcs = @[
            [[MPGeneralPreferencesViewController alloc] init],
            [[MPMarkdownPreferencesViewController alloc] init],
            [[MPEditorPreferencesViewController alloc] init],
            [[MPHtmlPreferencesViewController alloc] init],
            [[MPTerminalPreferencesViewController alloc] init],
            [[MPQuickLookPreferencesViewController alloc] init],
            [[MPAgentsPreferencesViewController alloc] init],
            [[MPUpdatePreferencesViewController alloc] init],
        ];
        NSString *title = NSLocalizedString(@"Preferences",
                                            @"Preferences window title.");

        typedef MASPreferencesWindowController WC;
        _preferencesWindowController =
            [[WC alloc] initWithViewControllers:vcs title:title];
    }
    return _preferencesWindowController;
}

- (IBAction)showPreferencesWindow:(id)sender
{
    [self.preferencesWindowController showWindow:nil];
}

- (IBAction)showHelp:(id)sender
{
    MPOpenBundledFile(@"help", @"md");
}

/** Starts and stops writing down what is asked of the editor.
 *
 * For the case that keeps happening: something does not work and neither of
 * us can see what the other sees. A recording of the screen would be a
 * recording of everything else on it too; this is a transcript of the
 * commands and their answers, in a file on this Mac.
 */
- (IBAction)toggleActionRecording:(id)sender
{
    MPPreferences *preferences = [MPPreferences sharedInstance];
    BOOL on = !preferences.diagnosticsRecording;
    preferences.diagnosticsRecording = on;
    [MPActionLog sharedLog].recording = on;

    // Said out loud the first time: a recording nobody knows is running is
    // not a thing to leave lying about.
    if (!on)
        return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Recording what you do",
                                          @"Action recording started");
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(
        @"Commands and answers are written to %@. Nothing leaves the Mac. "
        @"What lands in there: the paths of the documents and the titles of "
        @"the sections you work on.",
        @"Explains what the recording holds"),
        [MPActionLog sharedLog].fileURL.path];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Confirm")];
    [alert runModal];
}

- (IBAction)showActionRecording:(id)sender
{
    NSURL *url = [MPActionLog sharedLog].fileURL;
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Nothing has been recorded",
                                              @"No recording yet");
        alert.informativeText = NSLocalizedString(
            @"Turn on “Record What I Do”, do the thing that goes wrong again, "
            @"and the diary will be here.", @"How to get a recording");
        [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Confirm")];
        [alert runModal];
        return;
    }
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
}

- (IBAction)clearActionRecording:(id)sender
{
    [[MPActionLog sharedLog] clear];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if (item.action == @selector(toggleActionRecording:))
    {
        item.state = [MPPreferences sharedInstance].diagnosticsRecording
            ? NSControlStateValueOn : NSControlStateValueOff;
    }
    return YES;
}

- (IBAction)showContributing:(id)sender
{
    MPOpenBundledFile(@"contribute", @"md");
}


#pragma mark - Override

- (instancetype)init
{
    self = [super init];
    if (!self)
        return self;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(showFirstLaunchTips)
                   name:MPDidDetectFreshInstallationNotification
                 object:self.preferences];
    [self copyFiles];
    return self;
}


#pragma mark - NSApplicationDelegate

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    if (self.preferences.filesToOpen.count || self.preferences.pipedContentFileToOpen)
        return NO;
    return !self.preferences.supressesUntitledDocumentOnLaunch;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self openPendingPipedContent];
    [self openPendingFiles];
    treat();
}




#pragma mark - Private

- (void)copyFiles
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *root = MPDataDirectory(nil);
    if (![manager fileExistsAtPath:root])
    {
        [manager createDirectoryAtPath:root
           withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    NSBundle *bundle = [NSBundle mainBundle];
    for (NSString *key in @[kMPStylesDirectoryName, kMPThemesDirectoryName])
    {
        NSURL *dirSource = [bundle URLForResource:key withExtension:@""];
        NSURL *dirTarget = [NSURL fileURLWithPath:MPDataDirectory(key)];

        // If the directory doesn't exist, just copy the whole thing.
        if (![manager fileExistsAtPath:dirTarget.path])
        {
            [manager copyItemAtURL:dirSource toURL:dirTarget error:NULL];
            continue;
        }

        // Check for existence of each file and copy if it's not there.
        NSArray *contents = [manager contentsOfDirectoryAtURL:dirSource
                                   includingPropertiesForKeys:nil options:0
                                                        error:NULL];
        for (NSURL *fileSource in contents)
        {
            NSString *name = fileSource.lastPathComponent;
            NSURL *fileTarget = [dirTarget URLByAppendingPathComponent:name];
            if (![manager fileExistsAtPath:fileTarget.path])
                [manager copyItemAtURL:fileSource toURL:fileTarget error:NULL];
        }
    }
}

- (void)openPendingFiles
{
    NSDocumentController *c = [NSDocumentController sharedDocumentController];

    for (NSString *path in self.preferences.filesToOpen)
    {
        NSURL *url = [NSURL fileURLWithPath:path];
        if ([url checkResourceIsReachableAndReturnError:NULL])
        {
            [c openDocumentWithContentsOfURL:url display:YES
                           completionHandler:MPDocumentOpenCompletionEmpty];
        }
        else
        {
            [c createNewEmptyDocumentForURL:url display:YES error:NULL];
        }
    }

    self.preferences.filesToOpen = nil;
    [self.preferences synchronize];
}

- (void)openPendingPipedContent {
    NSDocumentController *c = [NSDocumentController sharedDocumentController];

    if (self.preferences.pipedContentFileToOpen) {
        NSURL *pipedContentFileToOpenURL = [NSURL fileURLWithPath:self.preferences.pipedContentFileToOpen];
        NSError *readPipedContentError;
        NSString *pipedContentString = [NSString stringWithContentsOfURL:pipedContentFileToOpenURL encoding:NSUTF8StringEncoding error:&readPipedContentError];

        NSError *openDocumentError;
        MPDocument *document = (MPDocument *)[c openUntitledDocumentAndDisplay:YES error:&openDocumentError];

        if (document && openDocumentError == nil && readPipedContentError == nil) {
            document.markdown = pipedContentString;
        }

        self.preferences.pipedContentFileToOpen = nil;
        [self.preferences synchronize];
    }
}


#pragma mark - Notification handler

- (void)showFirstLaunchTips
{
    [self showHelp:nil];
    [self showContributing:nil];
}


@end
