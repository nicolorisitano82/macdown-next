//
//  MPMarkdownText.h
//  MacDown
//
//  The questions about a text that have no opinions in them: which line a
//  place is on, which parts are code rather than prose, and whether a
//  character is a space or the end of a line.
//
//  They live apart from MPUtilities because they need nothing — no
//  preferences, no bundle, no window — and because whoever reads a
//  document for something (citations, findings, imports, a server handing
//  a folder to an assistant) needs exactly these two and nothing else.
//

#import <Foundation/Foundation.h>


/** Which line `location` falls on in `text`, counting from one.
 *
 * For showing where something is rather than for finding it again: a
 * number a person can compare with what the editor shows them.
 */
NSUInteger MPLineNumberForLocation(NSString *text, NSUInteger location);

/** The ranges of fenced blocks and inline spans in Markdown: code, not prose.
 *
 * Whoever reads a document for something — citations, findings, imports —
 * has to leave code alone, and every one of them was writing this again.
 */
NSArray<NSValue *> *MPMarkdownCodeRanges(NSString *text);

/// A space, a line ending, a string that is nothing but a line ending.
BOOL MPCharacterIsWhitespace(unichar character);
BOOL MPCharacterIsNewline(unichar character);
BOOL MPStringIsNewline(NSString *str);
