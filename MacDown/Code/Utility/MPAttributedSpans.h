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

/// The span that writes `text` in `colour`, which is what the editor's
/// colour well inserts. Already-attributed text gets the colour added.
NSString *MPSpanColouring(NSString *text, NSString *colour);
