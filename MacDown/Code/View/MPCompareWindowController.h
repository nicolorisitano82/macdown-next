//
//  MPCompareWindowController.h
//  MacDown
//

#import <Cocoa/Cocoa.h>


/** Two documents beside each other, with what changed marked.
 *
 * The left side is usually what you have in the editor — including what you
 * have not saved yet, because that is the version you are asking about —
 * and the right side is the file you picked. Lines that were changed are
 * shown once with both versions on the same row, and inside such a row the
 * words that actually differ are marked, so that a comma does not look like
 * a rewritten paragraph.
 */
@interface MPCompareWindowController : NSWindowController

/** Opens a comparison, and keeps it alive until its window closes.
 *
 * `leftURL` and `rightURL` may be nil — an unsaved document has no file —
 * and are used to read the sides again when the button is pressed, and to
 * open a side in the editor.
 */
+ (instancetype)compare:(NSString *)leftText
                  named:(NSString *)leftName
                    url:(NSURL *)leftURL
                   with:(NSString *)rightText
                  named:(NSString *)rightName
                    url:(NSURL *)rightURL;

/** What the left side can do when it is a living document.
 *
 * Set by whoever opened the comparison, and left nil when the left side is
 * only a file: the panel then offers neither taking a version nor going to
 * a line, rather than offering something that would quietly do nothing.
 *
 * `replaceInEditor` is given the range in the text the panel was handed,
 * the text it believes is there, and what to put in its place; it answers
 * NO when the document has moved on, and the panel says so rather than
 * writing into the wrong place.
 */
@property (copy, nonatomic) BOOL (^replaceInEditor)(NSRange range,
                                                    NSString *expected,
                                                    NSString *replacement);
@property (copy, nonatomic) BOOL (^revealInEditor)(NSRange range);

/** A row of buttons at the bottom, for a comparison that is a question.
 *
 * A conflict is not read for its own sake: it is read to decide which
 * version stays, and that decision has to be one button away from the two
 * texts — not hidden in a menu on a single row. Whoever opens the panel for
 * such a reason hands it the choices, in the order they should be offered
 * from left to right; the last one is what ⏎ means, because that is where
 * macOS puts the button ⏎ presses. `note` says, in a line, what the two
 * sides are.
 *
 * Without this call there is no bar at all, and an ordinary comparison
 * looks exactly as it did. Pressing one closes the window and then calls
 * `picked` with the index of the title that was pressed.
 */
- (void)offerChoices:(NSArray<NSString *> *)titles
                note:(NSString *)note
             handler:(void (^)(NSUInteger picked))picked;

/// What the window is called: the two names and how many differences.
+ (NSString *)titleForLeft:(NSString *)left right:(NSString *)right
               differences:(NSUInteger)differences;

@end
