//
//  DocumentImport.m
//  A MacDown Next plug-in: a .docx or an .odt read into the document.
//
//  Somebody sends a Word file, and the choice is to retype it or to keep a
//  format you cannot read without the program that made it. This is the
//  third way: the text, the headings, the lists, the tables, the links and
//  the pictures come across as Markdown, at the insertion point, in one
//  step of undo.
//
//  Both formats are a zip of XML, so nothing here needs a library: the
//  archive is opened with the system's own unzip, the XML with NSXMLDocument
//  — which is in Foundation — and the conversion is in MDOfficeImport, away
//  from windows and files so that it can be tested on its own.
//
//  What it does not do is said out loud at the end: footnotes, comments,
//  tracked changes and anything drawn inside the document stay behind, and
//  the panel lists them rather than leaving you to find out.
//

#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "MDOfficeImport.h"


/// The plug-in's own strings: NSLocalizedString would ask the application,
/// which does not carry them.
#define DILocalized(key) \
    [[NSBundle bundleForClass:[DocumentImport class]] \
        localizedStringForKey:(key) value:@"" table:nil]


@interface DocumentImport : NSObject
@end


/** The instance the File menu points at.
 *
 * `NSMenuItem.target` is a **weak** reference. Whether the object that adds
 * the item outlives the adding is the plug-in manager's business, not ours,
 * and when it did not the item was simply grey — enabled is what AppKit
 * shows for a target that has gone. Holding one instance here costs nothing
 * and makes the item answer for as long as the application runs.
 */
static DocumentImport *sImporter = nil;


@implementation DocumentImport

/// The name the plug-in manager shows. No ellipsis: it is not a command
/// any more — the commands are in File ▸ Import — and a row in a list that
/// promises a dialog it does not open is a small lie.
- (NSString *)name
{
    return DILocalized(@"Import Word and OpenDocument Files");
}


#pragma mark - Where the item goes

/** An **Import** submenu under File, beside **Export**.
 *
 * The plug-in manager puts every plug-in under Plug-ins, which is right for
 * something that acts on the text in front of you and wrong for something
 * that opens a document: importing belongs next to exporting, and that is
 * in File.
 *
 * Nothing here knows MacDown's classes. A menu is an object like any other,
 * and the File menu is found by what it *does* — it is the one holding an
 * item that answers `saveDocument:` — rather than by its title, which is in
 * whatever language the reader has chosen.
 */
/// Already in File: the application leaves it out of the plug-ins menu, and
/// keeps it in the plug-in manager, where it can be switched off.
- (BOOL)placesItsOwnMenuItem
{
    return YES;
}


- (void)plugInDidInitialize
{
    sImporter = self;
    // On the main queue and after the launch: the main menu is not
    // necessarily assembled while the plug-ins are being loaded.
    dispatch_async(dispatch_get_main_queue(), ^{
        [sImporter addImportMenu];
    });
}


- (NSMenu *)fileMenu
{
    for (NSMenuItem *item in [NSApp mainMenu].itemArray)
    {
        NSMenu *submenu = item.submenu;
        if (!submenu)
            continue;
        if ([submenu indexOfItemWithTarget:nil
                                 andAction:@selector(saveDocument:)] >= 0)
            return submenu;
    }
    return nil;
}


/// Just after Export, which is the item whose submenu exports HTML. Failing
/// that, after Save As; failing that, at the end.
- (NSInteger)placeInFileMenu:(NSMenu *)file
{
    NSInteger at = 0;
    for (NSMenuItem *item in file.itemArray)
    {
        if (item.submenu
                && [item.submenu indexOfItemWithTarget:nil
                        andAction:@selector(exportHtml:)] >= 0)
            return at + 1;
        at++;
    }
    NSInteger save = [file indexOfItemWithTarget:nil
                                       andAction:@selector(saveDocumentAs:)];
    if (save >= 0)
        return save + 1;
    return file.numberOfItems;
}


- (void)addImportMenu
{
    NSMenu *file = [self fileMenu];
    if (!file)
        return;                 // no File menu: nothing to add it to
    if ([file indexOfItemWithTarget:self
                          andAction:@selector(importWord:)] >= 0)
        return;                 // already there, in case of a second call

    NSMenu *submenu = [[NSMenu alloc] initWithTitle:DILocalized(@"Import")];
    NSMenuItem *word = [submenu addItemWithTitle:
        DILocalized(@"Word Document (.docx)…")
        action:@selector(importWord:) keyEquivalent:@""];
    word.target = sImporter ?: self;
    NSMenuItem *open = [submenu addItemWithTitle:
        DILocalized(@"OpenDocument Text (.odt)…")
        action:@selector(importOpenDocument:) keyEquivalent:@""];
    open.target = sImporter ?: self;

    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:DILocalized(@"Import")
        action:NULL keyEquivalent:@""];
    item.submenu = submenu;
    [file insertItem:item atIndex:[self placeInFileMenu:file]];
}


/* No -validateMenuItem: here, on purpose.
 *
 * The obvious rule — offer it only when the editor is the first responder —
 * looked right and left the item greyed out in cases where importing is
 * exactly what somebody wants: a window that has just opened, or one whose
 * focus is in the preview. The item is therefore always offered, and the
 * one case it cannot serve — no document at all — says so in words when it
 * is chosen, which is a sentence rather than a mystery.
 */

- (void)importWord:(id)sender
{
    [self importKinds:@[@"docx"]];
}


- (void)importOpenDocument:(id)sender
{
    [self importKinds:@[@"odt"]];
}


#pragma mark - The archive

/// Everything in the archive, in a folder of its own. Whole rather than
/// piece by piece: these files are small, and unzip called five times costs
/// more than unzip called once.
- (NSString *)unpack:(NSURL *)file error:(NSString **)error
{
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"macdown-import-%@",
         [NSUUID UUID].UUIDString]];

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/unzip"];
    task.arguments = @[@"-q", @"-o", file.path, @"-d", folder];
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];

    NSError *failure = nil;
    if (![task launchAndReturnError:&failure])
    {
        if (error)
            *error = failure.localizedDescription;
        return nil;
    }
    [task waitUntilExit];

    // unzip answers 1 for "finished, with warnings", which a document
    // written by another program often produces and which is not a failure.
    if (task.terminationStatus > 1)
    {
        if (error)
            *error = DILocalized(@"That file could not be opened as an "
                                 @"archive. A .docx and an .odt are zip "
                                 @"files; this one is not.");
        return nil;
    }
    return folder;
}


- (NSString *)textOf:(NSString *)folder entry:(NSString *)entry
{
    return [NSString stringWithContentsOfFile:
        [folder stringByAppendingPathComponent:entry]
        encoding:NSUTF8StringEncoding error:NULL];
}


#pragma mark - Running

/// Plug-ins ▸ this plug-in: the same thing, with both formats offered.
- (BOOL)run:(id)sender
{
    return [self importKinds:@[@"docx", @"odt"]];
}


- (BOOL)importKinds:(NSArray<NSString *> *)extensions
{
    NSResponder *responder = [NSApp keyWindow].firstResponder;
    if (![responder isKindOfClass:[NSTextView class]])
    {
        [self say:DILocalized(@"Open a document first")
           detail:DILocalized(@"The text is put in where the cursor is, so "
                              @"there has to be a document with a cursor in "
                              @"it. A new one (⌘N) will do.")];
        return NO;
    }
    NSTextView *editor = (NSTextView *)responder;
    NSURL *documentURL = [NSApp keyWindow].representedURL;

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    NSMutableArray<UTType *> *kinds = [NSMutableArray array];
    for (NSString *extension in extensions)
    {
        UTType *kind = [UTType typeWithFilenameExtension:extension];
        if (kind)
            [kinds addObject:kind];
    }
    panel.allowedContentTypes = kinds;
    panel.message = DILocalized(@"Choose the document to bring in");
    if ([panel runModal] != NSModalResponseOK || !panel.URL)
        return NO;

    NSURL *file = panel.URL;
    NSString *problem = nil;
    NSString *folder = [self unpack:file error:&problem];
    if (!folder)
    {
        [self say:DILocalized(@"That document could not be read")
           detail:problem ?: file.path];
        return NO;
    }

    // Where the pictures would go: beside the document, in a folder named
    // after it. A document that has never been saved has no beside, and the
    // reader is asked rather than surprised.
    NSString *pictureFolder = [NSString stringWithFormat:
        DILocalized(@"%@-pictures"),
        file.lastPathComponent.stringByDeletingPathExtension];
    NSURL *pictureDestination = documentURL
        ? [documentURL.URLByDeletingLastPathComponent
            URLByAppendingPathComponent:pictureFolder] : nil;

    BOOL word = [file.pathExtension.lowercaseString isEqualToString:@"docx"];
    MDImportResult *result = word
        ? MDMarkdownFromWordXML([self textOf:folder entry:@"word/document.xml"],
                                [self textOf:folder
                                       entry:@"word/_rels/document.xml.rels"],
                                [self textOf:folder entry:@"word/numbering.xml"],
                                pictureFolder)
        : MDMarkdownFromOpenDocumentXML([self textOf:folder entry:@"content.xml"],
                                        pictureFolder);

    if (!result.markdown.length)
    {
        [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
        NSString *why = [self inWords:result.lost].firstObject;
        [self say:DILocalized(@"There was nothing to bring in")
           detail:why ?: DILocalized(@"The document holds no text this "
                                     @"plug-in knows how to read.")];
        return NO;
    }

    NSMutableArray<NSString *> *lost = [self inWords:result.lost];
    NSString *markdown = result.markdown;

    if (result.pictures.count)
    {
        if (!pictureDestination)
        {
            [lost addObject:DILocalized(@"the pictures: this document has "
                                        @"never been saved, so there is "
                                        @"nowhere beside it to put them")];
            markdown = [self withoutPictures:markdown];
        }
        else
        {
            NSUInteger written = [self writePictures:result.pictures
                                                from:folder
                                                  to:pictureDestination];
            if (written < result.pictures.count)
            {
                [lost addObject:DILocalized(@"some of the pictures, which "
                                            @"could not be written")];
            }
        }
    }

    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];

    // Through the responder chain, so the insertion respects the selection
    // and one ⌘Z takes the whole import back out.
    [editor insertText:markdown replacementRange:editor.selectedRange];

    if (lost.count)
    {
        [self say:DILocalized(@"Brought in, with something left behind")
           detail:[lost componentsJoinedByString:@"\n"]];
    }
    return YES;
}


/** What the converter left behind, in the reader's language.
 *
 * MDOfficeImport has no bundle and no business having one — it is XML in
 * and Markdown out — so it says what went wrong in fixed English, and the
 * translation happens here, where there is a bundle to ask. A sentence
 * that has no translation comes back as it went in, which is English and
 * still true.
 */
- (NSMutableArray<NSString *> *)inWords:(NSArray<NSString *> *)lost
{
    NSMutableArray<NSString *> *said = [NSMutableArray array];
    for (NSString *one in lost)
        [said addObject:DILocalized(one)];
    return said;
}


/// The links to pictures taken out, when there is nowhere to put them: a
/// link to a file that will never exist is worse than a line saying so.
- (NSString *)withoutPictures:(NSString *)markdown
{
    NSRegularExpression *image = [[NSRegularExpression alloc]
        initWithPattern:@"!\\[[^\\]]*\\]\\([^)]*\\)" options:0 error:NULL];
    return [image stringByReplacingMatchesInString:markdown options:0
        range:NSMakeRange(0, markdown.length)
        withTemplate:DILocalized(@"<!-- picture not brought in -->")];
}


- (NSUInteger)writePictures:(NSArray<MDImportPicture *> *)pictures
                       from:(NSString *)folder
                         to:(NSURL *)destination
{
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:destination withIntermediateDirectories:YES
                       attributes:nil error:NULL];

    NSUInteger written = 0;
    for (MDImportPicture *picture in pictures)
    {
        NSString *from = [folder stringByAppendingPathComponent:picture.entry];
        NSURL *to = [destination URLByAppendingPathComponent:picture.name];
        if (![manager fileExistsAtPath:from])
            continue;
        // Written once: the same picture used twice in a document is one
        // file and two links.
        if ([manager fileExistsAtPath:to.path])
        {
            written++;
            continue;
        }
        if ([manager copyItemAtPath:from toPath:to.path error:NULL])
            written++;
    }
    return written;
}


- (void)say:(NSString *)what detail:(NSString *)detail
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = what;
    alert.informativeText = detail ?: @"";
    [alert runModal];
}

@end
