//
//  MPAttributedSpans.h
//  MacDown
//
//  `[testo]{...}` — a piece of text with attributes on it.
//
//  Markdown itself has no colour, and that is not an oversight: it says
//  what a thing *is*, not how it looks. The two languages that grew out of
//  it and do say it — Djot and Pandoc — agree on the same spelling: the
//  words in square brackets, the attributes in braces right after.
//
//      Rosso: [acceso]{style="color:#c00"}.
//      Una parola [in classe]{.avviso} e una [con un nome]{#qui}.
//
//  This turns that into `<span>` before the Markdown is parsed, because
//  hoedown has never heard of it and there is no reason it should: what
//  comes out the other side is ordinary inline HTML, which every renderer
//  in this application already carries.
//
//  Anything that does not parse is left exactly as it was written. A
//  reader who sees the braces on the page is being told, correctly, that
//  what is in them was not understood.
//

#import <Foundation/Foundation.h>


/// One bracketed span as it stands in a document.
@interface MPAttributedSpan : NSObject
/// The whole of it, brackets and braces included.
@property (assign, nonatomic) NSRange range;
/// The words between the brackets, which are what the reader is looking at.
@property (assign, nonatomic) NSRange content;
/// What the braces asked for, once what a document may not say is out.
@property (copy, nonatomic) NSDictionary<NSString *, NSString *> *attributes;
@end


/** Every bracketed span in `text`, in the order they are written.
 *
 * The same reading the rewriting does, handed out instead of used: the
 * editor needs to know where these are — to hide the braces, and to show
 * the words in the colour they ask for — and two readings of the same
 * syntax would be two answers to the same question.
 */
NSArray<MPAttributedSpan *> *MPAttributedSpansIn(NSString *text);

/** Whether `text` runs across a paragraph break — a blank line.
 *
 * A span is inline, in Djot as in Pandoc: what crosses a blank line is not
 * one, and neither the reading nor the writing pretends otherwise.
 */
BOOL MPTextHasABlankLine(NSString *text);


/** `text` with every bracketed span turned into inline HTML.
 *
 * Code — fenced, indented, or between backticks — is left alone, as is a
 * bracket that carries a link, an image, or a footnote after it.
 *
 * Only attributes that describe are kept: `class`, `id`, `style`, `title`,
 * `lang`, `dir` and `data-…`. Anything else — an event handler above all —
 * is not what a document is for, and a span left with none of them is not
 * rewritten at all.
 */
NSString *MPMarkdownWithAttributedSpans(NSString *text);

/** The attributes of one brace block, or nil when it is not one.
 *
 * Separate because it is the part with the rules in it, and the part a
 * test can ask about a hundred strings without a document in sight.
 * Classes come back joined by spaces under `class`.
 */
NSDictionary<NSString *, NSString *> *MPAttributesFromBraces(NSString *inside);

/** `text` as a span with one style declaration set.
 *
 * What the editor's colour panel writes. Text that is already a span keeps
 * its classes, its identifier and its other declarations, and only the one
 * named is replaced — somebody who sets a colour and then a highlight
 * should end up with one span saying both, not two nested.
 *
 * A nil or empty `value` takes the declaration out again; a span left
 * saying nothing at all is unwrapped, so «remove the colour» gives back the
 * words rather than an empty pair of braces.
 */
NSString *MPSpanWithStyle(NSString *text, NSString *property,
                          NSString *value);

/// The same, for the commonest case: the colour of the words themselves.
NSString *MPSpanColouring(NSString *text, NSString *colour);

/// The value of one declaration in a style, trimmed, or nil.
NSString *MPStyleDeclaration(NSString *style, NSString *property);
