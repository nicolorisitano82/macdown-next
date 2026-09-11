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


/// The rows between two texts.
extern NSArray<MPDiffRow *> *MPDiffRowsBetween(NSString *left,
                                               NSString *right);

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

/// How many rows of each kind, for the sentence at the top of the window.
extern void MPDiffCounts(NSArray<MPDiffRow *> *rows, NSUInteger *added,
                         NSUInteger *removed, NSUInteger *changed);
