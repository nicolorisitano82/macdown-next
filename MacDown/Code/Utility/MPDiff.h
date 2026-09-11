//
//  MPDiff.h
//  MacDown
//
//  What is different between two texts, line by line.
//
//  Pure: two strings in, a list of rows out. No view, no files, no state —
//  so the awkward cases (a file with no line ending at the end, one empty
//  side, two texts with nothing in common) can be asked in a test rather
//  than found by a reader.
//
//  The rows are aligned for two columns: a line that was changed appears
//  once, with both versions on it, rather than as a removal followed by an
//  addition. That is what somebody comparing two documents wants to look
//  at, and it is also what a merge will one day have to offer.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, MPDiffKind) {
    /// The same on both sides.
    MPDiffEqual,
    /// On the right only: added.
    MPDiffAdded,
    /// On the left only: taken away.
    MPDiffRemoved,
    /// On both sides, and different.
    MPDiffChanged,
};


/// One row of the comparison: what is on the left, what is on the right.
@interface MPDiffRow : NSObject

@property (readonly, nonatomic) MPDiffKind kind;
/// The line on that side, or nil when that side has none.
@property (readonly, copy, nonatomic) NSString *left;
@property (readonly, copy, nonatomic) NSString *right;
/// Which line it is in its own text, counting from one; 0 when there is no
/// line on that side.
@property (readonly, nonatomic) NSUInteger leftLine;
@property (readonly, nonatomic) NSUInteger rightLine;

@end


/// What counts as a unit, and what counts as a difference.
typedef NS_ENUM(NSUInteger, MPDiffGrain) {
    /// Line against line, which is what a `diff` does.
    MPDiffByLines,
    /** Paragraph against paragraph, which is what a reader does.
     *
     * Measured on a document of 298 lines: one word changed is one changed
     * row; the same word changed in a document that has *also* been
     * re-wrapped at 72 columns is 166 changed rows, 14 added and one taken
     * away — the real difference lost among a hundred and eighty false
     * ones. By paragraph, the same pair gives six.
     *
     * What is not prose stays a line of its own: a heading, a table row, a
     * list item, a line inside a fence. There the line ending *is* the
     * content.
     */
    MPDiffByParagraphs,
};

/// How two units are compared. The text shown is always the original: what
/// these change is only whether two units count as the same.
typedef struct {
    MPDiffGrain grain;
    /// Indentation, runs of spaces and the space at the end of a line.
    BOOL ignoringSpace;
    /// Upper and lower case.
    BOOL ignoringCase;
} MPDiffOptions;

/// Line by line, everything significant: what the panel started as.
extern const MPDiffOptions MPDiffOptionsStrict;

/// The rows between two texts, line by line.
extern NSArray<MPDiffRow *> *MPDiffRowsBetween(NSString *left,
                                               NSString *right);

/// The rows between two texts, compared as `options` says.
extern NSArray<MPDiffRow *> *MPDiffRowsBetweenWithOptions(
    NSString *left, NSString *right, MPDiffOptions options);

/** The units of a text: its lines, or its paragraphs.
 *
 * Answers one string per unit; a paragraph is its lines joined with single
 * spaces, so that what is compared is the words and not where they happened
 * to break.
 */
extern NSArray<NSString *> *MPDiffUnitsOfText(NSString *text,
                                              MPDiffGrain grain);

/// The line each unit starts on, counting from one — what the panel shows
/// in its margin, and what «go to this line» would need.
extern NSArray<NSNumber *> *MPDiffFirstLinesOfUnits(NSString *text,
                                                    MPDiffGrain grain);

/// The same, given the lines already split — which is how the tests ask.
extern NSArray<MPDiffRow *> *MPDiffRowsBetweenLines(
    NSArray<NSString *> *left, NSArray<NSString *> *right);

/// The lines of a text, as the comparison counts them: the last line counts
/// whether or not the text ends with a line ending, and a text that is
/// nothing at all has no lines.
extern NSArray<NSString *> *MPDiffLinesOfText(NSString *text);

/** What changed inside one changed row, word by word.
 *
 * Two lines that differ by a word should not be read character by
 * character: the ranges answered here are the words to mark on each side,
 * with what they have in common left alone.
 */
extern void MPDiffWordRanges(NSString *left, NSString *right,
                             NSArray<NSValue *> **leftRanges,
                             NSArray<NSValue *> **rightRanges);

/** The comparison as a unified diff, the way `diff -u` writes one.
 *
 * For sending to somebody who was not looking at the window: a format every
 * tool already reads, with `context` unchanged lines around each run of
 * differences. The two names go in the header lines.
 *
 * By paragraph the rows are paragraphs, so the patch is one of paragraphs —
 * readable, and not something `patch` should be pointed at. That is said in
 * the header rather than left to be discovered.
 */
extern NSString *MPDiffUnifiedText(NSArray<MPDiffRow *> *rows,
                                   NSString *leftName, NSString *rightName,
                                   NSUInteger context, BOOL byParagraph);

/// How many rows of each kind, for the sentence at the top of the window.
extern void MPDiffCounts(NSArray<MPDiffRow *> *rows, NSUInteger *added,
                         NSUInteger *removed, NSUInteger *changed);
