//
//  MPMarkerHider.h
//  MacDown
//

#import <Cocoa/Cocoa.h>
#import "pmh_definitions.h"

/** Hides the Markdown markers, and shows them back when the caret arrives.
 *
 * `**bold**` reads as bold with no asterisks around it, until you put the
 * caret in it — then the asterisks come back, because you cannot edit what
 * you cannot see. That reveal is the whole design: a marker is hidden only
 * while nobody is working on it.
 *
 * The characters are still there. Nothing is deleted, nothing is inserted,
 * and the document on disk is the same string it always was: the glyphs are
 * suppressed at layout time, through the layout manager's glyph generation
 * hook. That is also why this needs TextKit 1, which the editor is already
 * using — TextKit 2 has no equivalent.
 *
 * Emphasis, strong, inline code, and inline links — a link shows its text
 * and hides its destination until the caret arrives. Reference links are
 * left alone: their pointer is the only way to see which definition they
 * meant.
 */
@interface MPMarkerHider : NSObject <NSLayoutManagerDelegate>

- (instancetype)initWithTextView:(NSTextView *)textView;

/// When off, every marker is visible and this costs nothing.
@property (assign, nonatomic) BOOL enabled;

/** Whether to replace a horizontal rule's dashes with a drawn line.
 *
 * Unlike the rest, hiding these leaves nothing behind — the whole construct
 * is delimiter — so the hiding and the drawing are one decision. The dashes
 * go, and the ranges they occupied are handed to the view, which draws a
 * line down the middle of each.
 */
@property (assign, nonatomic) BOOL hidesRules;

/** Recomputes which characters are markers, from a fresh parse.
 *
 * The list belongs to the highlighter and is read, not kept.
 */
- (void)updateWithElements:(pmh_element **)elements;

/// Reveals the markers around the caret and hides the rest. Cheap.
- (void)selectionDidChange;

/** Whether a construct is being drawn as its meaning rather than as it is
 * written — markers hidden, in other words.
 *
 * Asked by whoever styles the text inside one. Most styling is the same
 * either way: a word stays the colour it asks for while you edit the
 * braces around it. A *size* is not — it moves everything on the line —
 * and showing the markup at one size and the words at another is a line
 * nobody can read. So the size waits until the markup is out of the way.
 */
- (BOOL)isDrawnAsMeaning:(NSRange)construct;

/** The construct whose delimiter covers `index`, if one does.
 *
 * Lets the editor treat a marker as one thing when it is deleted: pressing
 * backspace over the last asterisk of `**bold**` should leave `bold`, not
 * `**bold*`. Returns the whole construct and the length of one delimiter,
 * which is all that is needed to rebuild it without them.
 */
/** Whether the character at `index` is a marker that is not being drawn.
 *
 * What the caret and the delete keys go by. A marker you can see is a
 * character like any other: it is a place the caret stops and backspace
 * over it means what it says. One that is not drawn should behave as
 * though it were not between the caret and the text.
 */
- (BOOL)isHiddenMarkerAtIndex:(NSUInteger)index;

/** The construct whose delimiter covers `index`, and the part to keep.
 *
 * Lets the editor treat a construct as one thing when it is deleted:
 * backspace over the last asterisk of `**bold**` leaves `bold` rather than
 * `**bold*`, and over a link's tail leaves the link's text.
 */
- (BOOL)construct:(NSRange *)outRange
          content:(NSRange *)outContent
    coveringMarkerAtIndex:(NSUInteger)index;

@end
