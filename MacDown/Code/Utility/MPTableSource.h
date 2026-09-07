//
//  MPTableSource.h
//  MacDown
//

#import <Foundation/Foundation.h>

/// How a column's cells sit, as the separator row spells it.
typedef NS_ENUM(NSUInteger, MPTableAlignment) {
    MPTableAlignmentNone = 0,
    MPTableAlignmentLeft,
    MPTableAlignmentCenter,
    MPTableAlignmentRight,
};

/** A pipe table read out of Markdown source, and the edits you can make to it.
 *
 * Text in, text out: this knows nothing about views, which is what lets the
 * awkward parts — where a table starts, which column a character is in, what
 * a row looks like once a column has been taken out of it — be tested on
 * their own.
 *
 * Every edit returns the replacement for -range and says where the caret
 * should end up, so the caller does one substitution and puts the caret in
 * the cell the reader is about to type in.
 *
 * The whole table is re-emitted on every edit, with the bars lined up in the
 * source. Inserting a column has to touch every line anyway; doing the same
 * for a row keeps one way of writing a table instead of two, and it quietly
 * repairs a separator row that has been mangled — an em dash in it stops the
 * block being a table at all.
 */
@interface MPTableSource : NSObject

/** The table the character at `index` belongs to, or nil.
 *
 * A run of lines carrying unescaped bars. The separator row is not required:
 * a table still being typed does not have one yet, and refusing to help with
 * it is refusing at the moment help is wanted.
 */
+ (instancetype)tableCoveringIndex:(NSUInteger)index
                            inText:(NSString *)text;

/** An empty table, header row included, ready to be typed into.
 *
 * `rows` counts the rows you will put data in; the header and the separator
 * come on top of it, since a table without them is not one.
 */
+ (NSString *)emptyTableWithRows:(NSUInteger)rows
                         columns:(NSUInteger)columns;

/** Where the caret goes for one cell of the row beginning at `rowStart`.
 *
 * The preview names a cell by its position in its row, and the source has
 * the same cells in the same order with bars between them — so the line is
 * cut on its unescaped bars and the nth piece is the one wanted. Nothing
 * has to label every cell, and nothing has to be kept in step when the
 * table is edited.
 *
 * The answer is the first character the cell actually says, past the space
 * that separates it from the bar. NSNotFound if that row has no such cell.
 */
+ (NSUInteger)caretForColumn:(NSUInteger)column
                    inRowAt:(NSUInteger)rowStart
                     inText:(NSString *)text;

/// The lines the table occupies, without the break that ends the last one.
@property (readonly, nonatomic) NSRange range;

@property (readonly, nonatomic) NSUInteger rowCount;
@property (readonly, nonatomic) NSUInteger columnCount;

/** Whether the separator row is dashes that are not hyphens.
 *
 * An em dash instead of `---` stops the block being a table at all, and it
 * looks identical to a row that works.
 */
@property (readonly, nonatomic) BOOL separatorIsBroken;

/// Index of the `|---|` row, or NSNotFound while the table is still missing it.
@property (readonly, nonatomic) NSUInteger separatorRow;

/// Where `index` falls. Both answer NSNotFound if it is outside the table.
- (NSUInteger)rowContainingIndex:(NSUInteger)index;
- (NSUInteger)columnContainingIndex:(NSUInteger)index;

/// The alignment `column` is given now.
- (MPTableAlignment)alignmentOfColumn:(NSUInteger)column;

/** Rows are counted with the separator row among them, since that is what
 *  the caller has in hand; the edits keep it where it belongs by themselves.
 */
- (NSString *)textByInsertingRowAt:(NSUInteger)row caret:(NSUInteger *)caret;
- (NSString *)textByDeletingRow:(NSUInteger)row caret:(NSUInteger *)caret;
- (NSString *)textByInsertingColumnAt:(NSUInteger)column
                                caret:(NSUInteger *)caret;
- (NSString *)textByDeletingColumn:(NSUInteger)column
                             caret:(NSUInteger *)caret;
- (NSString *)textBySettingAlignment:(MPTableAlignment)alignment
                           forColumn:(NSUInteger)column
                               caret:(NSUInteger *)caret;

/** Moves a row up or down, or a column left or right.
 *
 * `delta` is -1 or 1; anything that would step over the header, over the
 * separator row or out of the table answers nil, and nothing is written.
 * Reordering a table by hand is retyping two lines and getting one of them
 * wrong, which is exactly the kind of work an editor should do.
 */
- (NSString *)textByMovingRow:(NSUInteger)row by:(NSInteger)delta
                        caret:(NSUInteger *)caret;
- (NSString *)textByMovingColumn:(NSUInteger)column by:(NSInteger)delta
                           caret:(NSUInteger *)caret;

/** The table's cells, header first and the separator row left out.
 *
 * For handing the thing to something that is not Markdown — a spreadsheet,
 * a message, a page.
 */
@property (readonly, nonatomic) NSArray<NSArray<NSString *> *> *cells;

/// The same cells with `separator` between them and a newline between rows.
- (NSString *)delimitedTextWithSeparator:(NSString *)separator;

/// The same cells as an HTML table, header row included.
- (NSString *)htmlText;

/// Gives a table that has none the separator row that makes it one.
- (NSString *)textByAddingSeparatorRowWithCaret:(NSUInteger *)caret;

/// Writes a mangled separator row back out with hyphens in it.
- (NSString *)textByRepairingSeparatorRowWithCaret:(NSUInteger *)caret;

@end
