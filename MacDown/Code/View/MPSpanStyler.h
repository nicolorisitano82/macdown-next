//
//  MPSpanStyler.h
//  MacDown
//
//  The colour a document asks for, in the editor.
//
//  `**forte**` is bold in the editor because the theme says what strong
//  looks like; `[acceso]{style="color:#c00"}` is red because the *document*
//  says so, and there is nothing for a theme to have an opinion about. It
//  is the same kind of statement, so it gets the same treatment: what you
//  see is what it means, and the braces are hidden by the marker hider
//  exactly as a link's destination is.
//
//  What it understands is what can be shown: `color` and `background-color`
//  — as a hex, as `rgb(…)`, or as one of the colour words CSS names — and
//  `font-size`, in points, pixels, `em`, `rem` or a percentage. Everything
//  else the preview still renders — a gradient, a colour space this does
//  not know — and the editor leaves alone, which is what it does with
//  every other piece of CSS.
//

#import <Cocoa/Cocoa.h>


@class MPMarkerHider;


@interface MPSpanStyler : NSObject

- (instancetype)initWithTextView:(NSTextView *)textView;

/** Who knows whether a span is drawn as its meaning or as it is written.
 *
 * A colour is applied either way; a size only while the braces are out of
 * the way, because a line showing `[titoletto]{style="font-size:2em"}` with
 * the middle word twice the size of the brackets is a line nobody can
 * read, and it rewraps under the caret as you edit it.
 */
@property (weak, nonatomic) MPMarkerHider *markerHider;

/** Colours every span the document declares.
 *
 * Written into the text storage, over what the highlighter has just put
 * there, and re-applied on the next parse the way the other stylers are.
 * It never reaches the file: the document is saved as its string.
 */
- (void)apply;

/** The caret moved: a span it has just left or entered changes size.
 *
 * Cheap on purpose — it looks only at the spans that ask for a size, and
 * only at those whose state actually flipped. Arrow keys happen more often
 * than anything else in an editor.
 */
- (void)selectionDidChange;

@end


/// The colour a CSS value names, or nil when it is one this does not read.
NSColor *MPColourFromCSS(NSString *value);

/** A CSS size in points, against a body of `base` points, or zero.
 *
 * `em`, `rem` and a percentage are relative and need the body size; `pt`
 * is already points; `px` is treated as a point, which is what a document
 * written for a screen means by it.
 */
CGFloat MPSizeFromCSS(NSString *value, CGFloat base);
