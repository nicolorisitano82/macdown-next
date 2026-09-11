//
//  MPDiagramSheetController.h
//  MacDown
//

#import <Cocoa/Cocoa.h>

@protocol MPTextGenerator;


/** Describe a diagram in words; the model on this Mac writes the Mermaid.
 *
 * A box for the description — in any language, and the labels come back in
 * that language — a choice of what kind of diagram to draw, and the source
 * the model produced, which can be read and corrected before it goes into
 * the document. Nothing is written into the document until the reader says
 * so: a model that answers badly should cost a second, not an undo.
 */
@interface MPDiagramSheetController : NSWindowController

/// `insert` is called with the Mermaid source when the reader accepts it.
- (instancetype)initWithGenerator:(id<MPTextGenerator>)generator
                           insert:(void (^)(NSString *code))insert;

/// Shown on the document's window, and kept alive until it is dismissed.
- (void)beginOn:(NSWindow *)window;

@end
