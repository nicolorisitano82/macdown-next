//
//  MDPreviewPage.h
//  MacDown QuickLook
//

#import <Foundation/Foundation.h>


/// The page Finder shows for a Markdown file, and the pictures it needs.
///
/// Quick Look hands its web view only what the extension gives it: anything
/// the page asks for by name has to be attached to the reply. So the page is
/// built with its pictures rewritten to `cid:` names, and `pictures` says
/// which file each name stands for.
@interface MDPreviewPage : NSObject

/// The complete HTML document, style sheet and all.
@property (readonly, copy, nonatomic) NSString *html;

/// The local pictures the page asks for, keyed by their `cid:` name.
@property (readonly, copy, nonatomic) NSDictionary<NSString *, NSURL *> *pictures;

/// @param bodyHTML   what the Markdown was turned into.
/// @param title      what to call the page.
/// @param styleSheet the CSS to put in the page; may be nil.
/// @param fileURL    the document itself, so its neighbours can be found.
+ (instancetype)pageForBody:(NSString *)bodyHTML
                      title:(NSString *)title
                 styleSheet:(NSString *)styleSheet
                 documentAt:(NSURL *)fileURL;
@end


/// The document's own title: its first heading, or else its file name.
///
/// Front matter is not the document talking, so it is stepped over.
extern NSString *MDPreviewTitleForMarkdown(NSString *markdown, NSURL *fileURL);

/** `[[Target]]` and `[[Target|label]]` turned into links.
 *
 * The same shape the application gives them, so a document reads the same
 * in Finder as it does open: a link, with a dashed underline when the page
 * it points at is not there yet. The target is resolved against the
 * document's own folder, trying the name as written and then the extensions
 * a Markdown document is likely to carry.
 *
 * Runs on the HTML rather than the Markdown so that code can be skipped:
 * `[[this]]` inside a fence is code, not a link.
 */
extern NSString *MDBodyWithWikiLinks(NSString *bodyHTML, NSURL *documentURL);

/// Whether the document asked for a table of contents: `[TOC]` on a line of
/// its own, which arrives in the HTML as the paragraph it looked like.
extern BOOL MDBodyAsksForContents(NSString *bodyHTML);

/// How deep a table of contents goes: h1 to h6, as in the application.
extern int MDContentsDepth(void);

/** The `[TOC]` paragraph replaced by the contents themselves.
 *
 * hoedown does not do this by itself — the contents are a second pass over
 * the same text with another renderer — so the preview used to show the
 * four letters where the application shows a list of the headings.
 */
extern NSString *MDBodyWithContents(NSString *bodyHTML, NSString *contents);

/// The document without its front matter.
///
/// A glance at a document should show what it says, and `title:` and
/// `source:` between two rules are notes about it, not part of it. The app's
/// own preview can lay them out as a table; here they are simply left out.
extern NSString *MDMarkdownWithoutFrontMatter(NSString *markdown);
