//
//  MPUtilities.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kMPStylesDirectoryName;
extern NSString * const kMPStyleFileExtension;
extern NSString * const kMPThemesDirectoryName;
extern NSString * const kMPThemeFileExtension;
extern NSString * const kMPPlugInsDirectoryName;
extern NSString * const kMPPlugInFileExtension;

NSString *MPDataDirectory(NSString *relativePath);
NSString *MPPathToDataFile(NSString *name, NSString *dirPath);

/** Every plug-in bundle the application should load, in the order it will.
 *
 * Two places. The folder in Application Support, where a plug-in someone
 * installed lives; and the application's own PlugIns folder, where the ones
 * that ship with it are. The second is why a plug-in that comes with
 * MacDown Next needs no installing at all — hunting through a build folder
 * for a bundle that looks like a folder was a poor welcome.
 *
 * Installed ones come first, so a newer copy of a plug-in that also ships
 * inside wins by being loaded first.
 */
NSArray<NSURL *> *MPPlugInBundleURLs(void);

/// The same, over folders given rather than the two the application uses.
NSArray<NSURL *> *MPPlugInBundleURLsInFolders(NSArray<NSURL *> *folders);

/** Which line `location` falls on in `text`, counting from one.
 *
 * For showing where something is rather than for finding it again: a
 * number a person can compare with what the editor shows them.
 */
NSUInteger MPLineNumberForLocation(NSString *text, NSUInteger location);

/** How long a text of `words` words takes to read, in minutes.
 *
 * Two hundred words a minute, which is a number and not a measurement: it
 * is the figure prose is usually reckoned at, and what it is for is telling
 * a page from a chapter. Never zero — a document that is there takes some
 * reading.
 */
NSUInteger MPReadingMinutesForWords(NSUInteger words);

NSArray *MPListEntriesForDirectory(
    NSString *dirName, NSString *(^processor)(NSString *absolutePath)
);

// Block factory for MPListEntriesForDirectory
NSString *(^MPFileNameHasExtensionProcessor(NSString *ext))(NSString *path);

/** Where `index` falls once the string is written out as UTF-8.
 *
 * The renderer records, for each block it produces, the byte offset it came
 * from — the file is UTF-8, so those are byte offsets. A text view counts in
 * UTF-16 units instead, and the two agree only while the text stays ASCII.
 * In Italian they part company at the first accent and never meet again: a
 * few dozen characters in, everything the preview is told is off by one
 * block, and further down by two.
 */
NSUInteger MPUTF8ByteOffsetForCharacterIndex(NSString *string,
                                             NSUInteger index);

/** The other way: a byte offset in the UTF-8 form back to a character index.
 *
 * Both are defined on character boundaries. An index between the halves of
 * a surrogate pair is not one — a text view never puts the caret there —
 * and neither function promises anything about it.
 */
NSUInteger MPCharacterIndexForUTF8ByteOffset(NSString *string,
                                             NSUInteger offset);

/** An HTML attribute value with its five escapes put back.
 *
 * Markup is HTML, so a picture called `a&b.png` arrives written
 * `a&amp;b.png` and is then looked for under a name it does not have; a web
 * address arrives with its query separators escaped and is fetched as a
 * different address from the one the writer meant.
 */
NSString *MPStringByUnescapingHTMLEntities(NSString *value);

/** Markdown link target for a file being pointed at from this document.
 *
 * Relative to the document's own folder when the file sits inside it, so
 * that moving the pair together keeps the link alive; absolute otherwise.
 * Percent-encoded either way, because an unescaped space ends the link
 * target and the rest of the path leaks into the page as text.
 */
NSString *MPMarkdownLinkTargetForFileURL(NSURL *fileURL,
                                         NSURL *documentURL);

/** The file a name asks for, beside `documentURL`. Nil if it cannot.
 *
 * The name comes from whatever was selected in the editor, which is prose
 * and not a file name: it may hold a slash, a colon, a newline, or three
 * hundred characters. What comes back is something a folder will accept,
 * with `.md` on the end, in the document's own directory.
 *
 * Nil when the document has never been saved — there is no "beside" then —
 * or when nothing usable is left of the name.
 */
NSURL *MPNewMarkdownFileURLForName(NSString *name, NSURL *documentURL);

BOOL MPCharacterIsWhitespace(unichar character);
BOOL MPCharacterIsNewline(unichar character);
BOOL MPStringIsNewline(NSString *str);

NSString *MPStylePathForName(NSString *name);
NSString *MPThemePathForName(NSString *name);
NSURL *MPHighlightingThemeURLForName(NSString *name);
NSString *MPReadFileOfPath(NSString *path);

NSDictionary *MPGetDataMap(NSString *name);

id MPGetObjectFromJavaScript(NSString *code, NSString *variableName);


static void (^MPDocumentOpenCompletionEmpty)(
        NSDocument *doc, BOOL wasOpen, NSError *error) = ^(
        NSDocument *doc, BOOL wasOpen, NSError *error) {

};

/** The ranges of fenced blocks and inline spans in Markdown: code, not prose.
 *
 * Whoever reads a document for something — citations, findings, imports —
 * has to leave code alone, and every one of them was writing this again.
 */
NSArray<NSValue *> *MPMarkdownCodeRanges(NSString *text);

/** Whether a document's file has gone from where the document thinks it is.
 *
 * A file moved with the Finder is followed; one moved by `git`, by a script
 * or by another program while the application was not running is not, and
 * the document then points at a path that holds nothing. Every write fails
 * from there on, with a system alert about saving that says nothing about
 * why.
 */
BOOL MPFileIsMissing(NSURL *fileURL);


/// What to do about a file that has changed while the document was open.
typedef NS_ENUM(NSUInteger, MPExternalChange) {
    /// The file says what the document says: our own save, or a touch.
    MPExternalChangeNothing,
    /// The file has changed and there is nothing of the reader's to lose.
    MPExternalChangeReload,
    /// It has changed and so has the document: only the reader can choose.
    MPExternalChangeAsk,
    /// There is no file there any more.
    MPExternalChangeGone,
};

/** Which of those four a change is.
 *
 * A document is open while `git` checks out a branch, a script rewrites a
 * table, another window of another application saves over it. Reloading
 * silently is right when the reader has nothing in hand and wrong when they
 * have; the rule is small enough to be read in one go, and it is here
 * rather than in the document so that it can be.
 */
MPExternalChange MPExternalChangeFor(NSString *onDisk, NSString *inEditor,
                                     BOOL edited, BOOL missing);
