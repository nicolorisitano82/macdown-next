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

/// What the window is called: the two names and how many differences.
+ (NSString *)titleForLeft:(NSString *)left right:(NSString *)right
               differences:(NSUInteger)differences;

@end
