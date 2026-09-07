//
//  MPPreviewSelection.h
//  MacDown
//
//  Finding, in the source, the text somebody selected in the preview.
//
//  The preview shows what the Markdown means; the editor holds what it
//  says. Selecting "test" in the preview and pressing delete has to remove
//  the "test" the writer wrote, which means going from rendered text back
//  to a range in the source — and the rendered text is not the source: the
//  line breaks are gone, the asterisks of an emphasis are gone, and a word
//  may appear a dozen times in the document.
//
//  What makes it tractable is that each block carries the offset it was
//  rendered from, so the search happens inside one block rather than in the
//  whole document.
//

#import <Cocoa/Cocoa.h>


/** Where `selected` sits in `source`, looked for inside `block` first.
 *
 * Three attempts, in this order, because each is right about a different
 * kind of selection:
 *
 *  1. the text as selected, with any run of whitespace matching any other —
 *     the browser gives a newline where the source has one and a space
 *     where the source wrapped a line;
 *  2. the same, anywhere in the source, for a block whose offset has moved
 *     since the page was drawn;
 *  3. from the first word of the selection to the last, inside the block,
 *     which is what is left when the selection crossed an emphasis: the
 *     asterisks are in the source and not in what the browser handed over.
 *
 * `{NSNotFound, 0}` when none of the three is convincing. A selection that
 * cannot be placed is better left alone than placed nearly right: the next
 * keystroke would delete the wrong words.
 */
extern NSRange MPSourceRangeForPreviewText(NSString *source,
                                           NSString *selected,
                                           NSRange block);


/** The script the preview runs to report where the reader is.
 *
 * It marks the block the caret is in, tells the document which block a
 * click landed in — and, when a selection gesture ends, what text was
 * selected. The two moments are deliberately different: reporting the text
 * while the pointer is still down would take the focus away from somebody
 * in the middle of dragging a selection.
 *
 * A function rather than a constant so that a test can inject the same
 * script the application injects.
 */
extern NSString *MPSelectionWatchScript(void);
