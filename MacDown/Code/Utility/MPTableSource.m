//
//  MPTableSource.m
//  MacDown
//

#import "MPTableSource.h"


@interface MPTableSource ()
@property (assign, nonatomic) NSRange range;
/// Row by row, cell by cell, trimmed of the spaces that pad them.
@property (strong, nonatomic) NSMutableArray<NSMutableArray<NSString *> *> *rows;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *alignments;
@property (assign, nonatomic) NSUInteger separatorRow;
@property (assign, nonatomic) BOOL separatorIsBroken;
/// The character ranges of each row, to answer where a click landed.
@property (strong, nonatomic) NSMutableArray<NSValue *> *lineRanges;
/// The bar positions of each row, for the same question about columns.
@property (strong, nonatomic) NSMutableArray<NSArray<NSNumber *> *> *lineBars;
@end


@implementation MPTableSource

#pragma mark - Reading

/// The unescaped bars in one line. `\|` is a bar in a cell, not the end of one.
static NSMutableArray<NSNumber *> *MPBarsInLine(NSString *text, NSRange line)
{
    NSMutableArray<NSNumber *> *bars = [NSMutableArray array];
    BOOL escaped = NO;
    for (NSUInteger i = line.location; i < NSMaxRange(line); i++)
    {
        unichar c = [text characterAtIndex:i];
        if (escaped)
        {
            escaped = NO;
            continue;
        }
        if (c == '\\')
            escaped = YES;
        else if (c == '|')
            [bars addObject:@(i)];
    }
    return bars;
}

/// The line without the break that ends it.
static NSRange MPLineBody(NSString *text, NSUInteger index)
{
    NSRange line = [text lineRangeForRange:NSMakeRange(index, 0)];
    NSUInteger end = NSMaxRange(line);
    while (end > line.location)
    {
        unichar c = [text characterAtIndex:end - 1];
        if (c != '\n' && c != '\r')
            break;
        end--;
    }
    return NSMakeRange(line.location, end - line.location);
}

/// Whether a line is `|---|:--:|`, which is what makes the line above a header.
static BOOL MPIsSeparatorLine(NSString *text, NSRange line)
{
    BOOL sawDash = NO;
    for (NSUInteger i = line.location; i < NSMaxRange(line); i++)
    {
        unichar c = [text characterAtIndex:i];
        if (c == '-')
            sawDash = YES;
        else if (c != '|' && c != ':' && c != ' ' && c != '\t')
            return NO;
    }
    return sawDash;
}

/// The cells of one line, dropping the empty ones its outer bars produce.
static NSMutableArray<NSString *> *MPCellsInLine(NSString *text, NSRange line)
{
    NSMutableArray<NSNumber *> *bars = MPBarsInLine(text, line);
    NSMutableArray<NSString *> *cells = [NSMutableArray array];
    if (!bars.count)
        return cells;

    NSCharacterSet *spaces = [NSCharacterSet whitespaceCharacterSet];
    NSUInteger start = line.location;
    for (NSNumber *bar in bars)
    {
        NSUInteger at = bar.unsignedIntegerValue;
        [cells addObject:[[text substringWithRange:NSMakeRange(start,
                                                               at - start)]
            stringByTrimmingCharactersInSet:spaces]];
        start = at + 1;
    }
    [cells addObject:[[text substringWithRange:
        NSMakeRange(start, NSMaxRange(line) - start)]
            stringByTrimmingCharactersInSet:spaces]];

    // A row written `| a | b |` opens and closes with a bar, so the first and
    // last pieces are empty and are not cells.
    if (cells.count && !cells.firstObject.length)
        [cells removeObjectAtIndex:0];
    if (cells.count && !cells.lastObject.length)
        [cells removeLastObject];
    return cells;
}

/** Whether a line was *meant* to be the separator row but is not one.
 *
 * An em dash where a hyphen belongs is the commonest way a table stops being
 * a table, and it is invisible unless you go looking: the row still reads as
 * a row of dashes. Recognising it is what lets an edit put it right instead
 * of adding a second separator underneath it.
 */
static BOOL MPLooksLikeSeparatorLine(NSString *text, NSRange line)
{
    BOOL sawDash = NO;
    for (NSUInteger i = line.location; i < NSMaxRange(line); i++)
    {
        unichar c = [text characterAtIndex:i];
        // Every dash a keyboard, a substitution or a paste can produce.
        if (c == '-' || c == 0x2010 || c == 0x2011 || c == 0x2012
                || c == 0x2013 || c == 0x2014 || c == 0x2015 || c == 0x2212)
            sawDash = YES;
        else if (c != '|' && c != ':' && c != ' ' && c != '\t')
            return NO;
    }
    return sawDash;
}

static MPTableAlignment MPAlignmentOfSpec(NSString *spec)
{
    NSString *s = [spec stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceCharacterSet]];
    BOOL left = [s hasPrefix:@":"];
    BOOL right = [s hasSuffix:@":"];
    if (left && right)
        return MPTableAlignmentCenter;
    if (right)
        return MPTableAlignmentRight;
    if (left)
        return MPTableAlignmentLeft;
    return MPTableAlignmentNone;
}

+ (instancetype)tableCoveringIndex:(NSUInteger)index inText:(NSString *)text
{
    if (index > text.length)
        return nil;

    NSRange here = MPLineBody(text, MIN(index, text.length ? text.length - 1
                                                           : 0));
    if (!MPBarsInLine(text, here).count)
        return nil;

    // Outwards from the line the caret is on, for as long as the lines carry
    // bars. A blank line, or one without them, is where the table stops.
    NSRange first = here;
    while (first.location > 0)
    {
        NSRange above = MPLineBody(text, first.location - 1);
        if (!above.length || !MPBarsInLine(text, above).count)
            break;
        first = above;
    }
    NSRange last = here;
    while (NSMaxRange(last) + 1 <= text.length)
    {
        NSUInteger next = NSMaxRange(last);
        while (next < text.length && [text characterAtIndex:next] == '\r')
            next++;
        if (next >= text.length || [text characterAtIndex:next] != '\n')
            break;
        next++;
        if (next > text.length)
            break;
        NSRange below = MPLineBody(text, MIN(next, text.length - 1));
        if (below.location < next || !below.length
                || !MPBarsInLine(text, below).count)
            break;
        last = below;
    }

    MPTableSource *table = [[MPTableSource alloc] init];
    table.range = NSMakeRange(first.location,
                              NSMaxRange(last) - first.location);
    table.rows = [NSMutableArray array];
    table.alignments = [NSMutableArray array];
    table.lineRanges = [NSMutableArray array];
    table.lineBars = [NSMutableArray array];
    table.separatorRow = NSNotFound;

    // Advanced by the line *including* its terminator, and stopped at the end
    // of the last one. Stepping by the trimmed line instead left the cursor
    // on the final line when the file ended without a break, and the row was
    // counted twice.
    NSUInteger cursor = first.location;
    while (cursor < NSMaxRange(last))
    {
        NSRange line = MPLineBody(text, cursor);
        if (line.location > NSMaxRange(last))
            break;
        [table.lineRanges addObject:[NSValue valueWithRange:line]];
        [table.lineBars addObject:MPBarsInLine(text, line)];

        if (table.separatorRow == NSNotFound
                && MPLooksLikeSeparatorLine(text, line))
        {
            table.separatorRow = table.rows.count;
            table.separatorIsBroken = !MPIsSeparatorLine(text, line);
            for (NSString *spec in MPCellsInLine(text, line))
                [table.alignments addObject:@(MPAlignmentOfSpec(spec))];
        }
        [table.rows addObject:MPCellsInLine(text, line)];

        NSUInteger next = NSMaxRange([text lineRangeForRange:
            NSMakeRange(cursor, 0)]);
        if (next <= cursor)
            break;
        cursor = next;
    }

    return table.rows.count ? table : nil;
}


+ (NSString *)emptyTableWithRows:(NSUInteger)rows columns:(NSUInteger)columns
{
    NSUInteger cols = MAX(columns, (NSUInteger)1);
    NSUInteger body = MAX(rows, (NSUInteger)1);

    MPTableSource *table = [[MPTableSource alloc] init];
    table.range = NSMakeRange(0, 0);
    table.rows = [NSMutableArray array];
    table.alignments = [NSMutableArray array];
    table.lineRanges = [NSMutableArray array];
    table.lineBars = [NSMutableArray array];
    table.separatorRow = 1;

    for (NSUInteger c = 0; c < cols; c++)
        [table.alignments addObject:@(MPTableAlignmentNone)];
    for (NSUInteger r = 0; r < body + 2; r++)
    {
        NSMutableArray<NSString *> *row = [NSMutableArray array];
        for (NSUInteger c = 0; c < cols; c++)
            [row addObject:@""];
        [table.rows addObject:row];
    }

    return [table serialiseWithCaretRow:0 column:0 caret:NULL];
}


#pragma mark - Finding a cell

+ (NSUInteger)caretForColumn:(NSUInteger)column
                     inRowAt:(NSUInteger)rowStart
                      inText:(NSString *)text
{
    if (!text.length || rowStart >= text.length)
        return NSNotFound;

    NSRange line = [text lineRangeForRange:NSMakeRange(rowStart, 0)];
    while (line.length > 0)
    {
        unichar last = [text characterAtIndex:NSMaxRange(line) - 1];
        if (last != '\n' && last != '\r')
            break;
        line.length--;
    }
    if (!line.length)
        return NSNotFound;

    NSMutableArray<NSNumber *> *bars = [NSMutableArray array];
    BOOL escaped = NO;
    for (NSUInteger i = line.location; i < NSMaxRange(line); i++)
    {
        unichar c = [text characterAtIndex:i];
        if (escaped)
            escaped = NO;
        else if (c == '\\')
            escaped = YES;
        else if (c == '|')
            [bars addObject:@(i)];
    }
    if (!bars.count)
        return NSNotFound;

    NSMutableArray<NSValue *> *cells = [NSMutableArray array];
    NSUInteger start = line.location;
    for (NSNumber *bar in bars)
    {
        NSUInteger at = bar.unsignedIntegerValue;
        [cells addObject:[NSValue valueWithRange:NSMakeRange(start,
                                                             at - start)]];
        start = at + 1;
    }
    [cells addObject:[NSValue valueWithRange:
        NSMakeRange(start, NSMaxRange(line) - start)]];

    // The bar that opens a row and the one that closes it are punctuation,
    // not boundaries: `| a | b |` has two cells, and the empty pieces at
    // either end would otherwise count as a third and a fourth.
    NSCharacterSet *blank = [NSCharacterSet whitespaceCharacterSet];
    NSString *(^body)(NSValue *) = ^(NSValue *value) {
        return [[text substringWithRange:value.rangeValue]
            stringByTrimmingCharactersInSet:blank];
    };
    if (cells.count > 1 && !body(cells.firstObject).length)
        [cells removeObjectAtIndex:0];
    if (cells.count > 1 && !body(cells.lastObject).length)
        [cells removeLastObject];
    if (column >= cells.count)
        return NSNotFound;

    NSRange cell = cells[column].rangeValue;
    NSUInteger caret = cell.location;
    while (caret < NSMaxRange(cell)
           && [blank characterIsMember:[text characterAtIndex:caret]])
        caret++;
    return caret;
}


#pragma mark - Shape

- (NSUInteger)rowCount
{
    return self.rows.count;
}

- (NSUInteger)columnCount
{
    NSUInteger columns = 0;
    for (NSArray *row in self.rows)
        columns = MAX(columns, row.count);
    return columns;
}

- (NSUInteger)rowContainingIndex:(NSUInteger)index
{
    for (NSUInteger i = 0; i < self.lineRanges.count; i++)
    {
        NSRange line = self.lineRanges[i].rangeValue;
        if (index >= line.location && index <= NSMaxRange(line))
            return i;
    }
    return NSNotFound;
}

/// Which cell of its row `index` sits in: the bars before it, less the
/// opening one, which begins a cell rather than ending one.
- (NSUInteger)columnContainingIndex:(NSUInteger)index
{
    NSUInteger row = [self rowContainingIndex:index];
    if (row == NSNotFound)
        return NSNotFound;

    NSRange line = self.lineRanges[row].rangeValue;
    NSArray<NSNumber *> *bars = self.lineBars[row];
    BOOL leading = bars.count
        && bars.firstObject.unsignedIntegerValue == line.location;

    NSUInteger before = 0;
    for (NSNumber *bar in bars)
    {
        if (bar.unsignedIntegerValue < index)
            before++;
        else
            break;
    }
    if (leading && before)
        before--;

    NSUInteger last = self.columnCount ? self.columnCount - 1 : 0;
    return MIN(before, last);
}

- (MPTableAlignment)alignmentOfColumn:(NSUInteger)column
{
    if (column >= self.alignments.count)
        return MPTableAlignmentNone;
    return (MPTableAlignment)self.alignments[column].unsignedIntegerValue;
}


#pragma mark - Writing

/// The separator cell for one column, in the width the column will be drawn.
static NSString *MPSpecForAlignment(MPTableAlignment alignment, NSUInteger width)
{
    NSUInteger dashes = MAX(width, (NSUInteger)3);
    switch (alignment)
    {
        case MPTableAlignmentLeft:
        case MPTableAlignmentCenter:
        case MPTableAlignmentRight:
            dashes = MAX(dashes, (NSUInteger)4);
            break;
        default:
            break;
    }

    NSMutableString *spec = [NSMutableString string];
    NSUInteger fill = dashes;
    if (alignment == MPTableAlignmentLeft || alignment == MPTableAlignmentCenter)
    {
        [spec appendString:@":"];
        fill--;
    }
    if (alignment == MPTableAlignmentRight || alignment == MPTableAlignmentCenter)
        fill--;
    for (NSUInteger i = 0; i < fill; i++)
        [spec appendString:@"-"];
    if (alignment == MPTableAlignmentRight || alignment == MPTableAlignmentCenter)
        [spec appendString:@":"];
    return spec;
}

/** Writes the table back out with its bars in a column.
 *
 * Lining the source up is the reason the whole table is re-emitted rather
 * than one line patched: a table that has been edited should not be harder
 * to read than one that has not.
 */
- (NSString *)serialiseWithCaretRow:(NSUInteger)caretRow
                             column:(NSUInteger)caretColumn
                              caret:(NSUInteger *)caret
{
    NSUInteger columns = self.columnCount;
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    for (NSUInteger c = 0; c < columns; c++)
    {
        NSUInteger width = 3;
        for (NSUInteger r = 0; r < self.rows.count; r++)
        {
            if (r == self.separatorRow)
                continue;
            NSArray *row = self.rows[r];
            if (c < row.count)
                width = MAX(width, [row[c] length]);
        }
        [widths addObject:@(width)];
    }

    NSMutableString *out = [NSMutableString string];
    NSUInteger caretAt = NSNotFound;

    for (NSUInteger r = 0; r < self.rows.count; r++)
    {
        if (r)
            [out appendString:@"\n"];
        NSArray<NSString *> *row = self.rows[r];
        [out appendString:@"|"];
        for (NSUInteger c = 0; c < columns; c++)
        {
            NSUInteger width = widths[c].unsignedIntegerValue;
            NSString *cell;
            if (r == self.separatorRow)
            {
                cell = MPSpecForAlignment([self alignmentOfColumn:c], width);
            }
            else
            {
                cell = c < row.count ? row[c] : @"";
                NSMutableString *padded = [cell mutableCopy];
                while (padded.length < width)
                    [padded appendString:@" "];
                cell = padded;
            }

            [out appendString:@" "];
            if (r == caretRow && c == caretColumn)
                caretAt = self.range.location + out.length;
            [out appendString:cell];
            [out appendString:@" |"];
        }
    }

    if (caret)
        *caret = caretAt != NSNotFound ? caretAt : self.range.location;
    return out;
}

/// A row of empty cells, as wide as the table.
- (NSMutableArray<NSString *> *)blankRow
{
    NSMutableArray<NSString *> *row = [NSMutableArray array];
    for (NSUInteger c = 0; c < self.columnCount; c++)
        [row addObject:@""];
    return row;
}

- (NSString *)textByInsertingRowAt:(NSUInteger)row caret:(NSUInteger *)caret
{
    NSUInteger at = MIN(row, self.rows.count);
    // Never above the separator row: the header is the first line by
    // definition, and a row put over it would become the header instead.
    if (self.separatorRow != NSNotFound && at <= self.separatorRow)
        at = self.separatorRow + 1;
    [self.rows insertObject:[self blankRow] atIndex:at];
    if (self.separatorRow != NSNotFound && at <= self.separatorRow)
        self.separatorRow++;
    return [self serialiseWithCaretRow:at column:0 caret:caret];
}

- (NSString *)textByDeletingRow:(NSUInteger)row caret:(NSUInteger *)caret
{
    if (row >= self.rows.count || row == self.separatorRow)
        return nil;
    [self.rows removeObjectAtIndex:row];
    if (self.separatorRow != NSNotFound && row < self.separatorRow)
        self.separatorRow--;
    if (!self.rows.count)
        return nil;
    NSUInteger caretRow = MIN(row, self.rows.count - 1);
    return [self serialiseWithCaretRow:caretRow column:0 caret:caret];
}

- (NSString *)textByInsertingColumnAt:(NSUInteger)column
                                caret:(NSUInteger *)caret
{
    NSUInteger at = MIN(column, self.columnCount);
    for (NSMutableArray<NSString *> *row in self.rows)
    {
        while (row.count < at)
            [row addObject:@""];
        [row insertObject:@"" atIndex:at];
    }
    [self.alignments insertObject:@(MPTableAlignmentNone)
                          atIndex:MIN(at, self.alignments.count)];
    NSUInteger caretRow = self.separatorRow == NSNotFound ? 0
        : (self.separatorRow + 1 < self.rows.count ? self.separatorRow + 1 : 0);
    return [self serialiseWithCaretRow:caretRow column:at caret:caret];
}

- (NSString *)textByDeletingColumn:(NSUInteger)column
                             caret:(NSUInteger *)caret
{
    if (column >= self.columnCount || self.columnCount <= 1)
        return nil;
    for (NSMutableArray<NSString *> *row in self.rows)
    {
        if (column < row.count)
            [row removeObjectAtIndex:column];
    }
    if (column < self.alignments.count)
        [self.alignments removeObjectAtIndex:column];
    NSUInteger caretColumn = MIN(column, self.columnCount ? self.columnCount - 1
                                                          : 0);
    return [self serialiseWithCaretRow:0 column:caretColumn caret:caret];
}

- (NSString *)textByMovingRow:(NSUInteger)row by:(NSInteger)delta
                        caret:(NSUInteger *)caret
{
    if (row >= self.rows.count || row == self.separatorRow || !delta)
        return nil;
    NSInteger target = (NSInteger)row + delta;
    if (target < 0 || target >= (NSInteger)self.rows.count)
        return nil;
    // The header stays the header, and the separator stays under it: a row
    // cannot be moved across either.
    if (self.separatorRow != NSNotFound
            && (target == (NSInteger)self.separatorRow
                || (row < self.separatorRow) != (target < (NSInteger)self.separatorRow)))
        return nil;

    NSMutableArray<NSString *> *moving = self.rows[row];
    [self.rows removeObjectAtIndex:row];
    [self.rows insertObject:moving atIndex:(NSUInteger)target];
    return [self serialiseWithCaretRow:(NSUInteger)target column:0
                                 caret:caret];
}


- (NSString *)textByMovingColumn:(NSUInteger)column by:(NSInteger)delta
                           caret:(NSUInteger *)caret
{
    if (column >= self.columnCount || !delta)
        return nil;
    NSInteger target = (NSInteger)column + delta;
    if (target < 0 || target >= (NSInteger)self.columnCount)
        return nil;

    for (NSMutableArray<NSString *> *row in self.rows)
    {
        while (row.count < self.columnCount)
            [row addObject:@""];
        NSString *moving = row[column];
        [row removeObjectAtIndex:column];
        [row insertObject:moving atIndex:(NSUInteger)target];
    }
    // The alignment belongs to the column and travels with it.
    while (self.alignments.count < self.columnCount)
        [self.alignments addObject:@(MPTableAlignmentNone)];
    NSNumber *alignment = self.alignments[column];
    [self.alignments removeObjectAtIndex:column];
    [self.alignments insertObject:alignment atIndex:(NSUInteger)target];

    NSUInteger caretRow = self.separatorRow == NSNotFound ? 0
        : (self.separatorRow + 1 < self.rows.count ? self.separatorRow + 1 : 0);
    return [self serialiseWithCaretRow:caretRow column:(NSUInteger)target
                                 caret:caret];
}


#pragma mark - Handing the table to something else

- (NSArray<NSArray<NSString *> *> *)cells
{
    NSMutableArray<NSArray<NSString *> *> *out = [NSMutableArray array];
    for (NSUInteger r = 0; r < self.rows.count; r++)
    {
        if (r == self.separatorRow)
            continue;               // dashes are not data
        NSMutableArray<NSString *> *row = [NSMutableArray array];
        for (NSUInteger c = 0; c < self.columnCount; c++)
        {
            NSString *cell = c < self.rows[r].count ? self.rows[r][c] : @"";
            [row addObject:cell];
        }
        [out addObject:row];
    }
    return out;
}


/// A field as a delimited file wants it: quoted when it has to be.
static NSString *MPDelimitedField(NSString *cell, NSString *separator)
{
    BOOL quoting = [cell containsString:separator]
        || [cell containsString:@"\""] || [cell containsString:@"\n"];
    if (!quoting)
        return cell;
    NSString *escaped = [cell stringByReplacingOccurrencesOfString:@"\""
                                                       withString:@"\"\""];
    return [NSString stringWithFormat:@"\"%@\"", escaped];
}


- (NSString *)delimitedTextWithSeparator:(NSString *)separator
{
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSArray<NSString *> *row in self.cells)
    {
        NSMutableArray<NSString *> *fields = [NSMutableArray array];
        for (NSString *cell in row)
            [fields addObject:MPDelimitedField(cell, separator)];
        [lines addObject:[fields componentsJoinedByString:separator]];
    }
    return [[lines componentsJoinedByString:@"\n"]
        stringByAppendingString:@"\n"];
}


/// The five characters a cell must not carry into markup.
static NSString *MPEscapedForHTML(NSString *cell)
{
    NSMutableString *out = [cell mutableCopy];
    NSArray<NSArray<NSString *> *> *pairs = @[
        @[@"&", @"&amp;"], @[@"<", @"&lt;"], @[@">", @"&gt;"],
        @[@"\"", @"&quot;"], @[@"'", @"&#39;"],
    ];
    for (NSArray<NSString *> *pair in pairs)
    {
        [out replaceOccurrencesOfString:pair[0] withString:pair[1]
                                options:0 range:NSMakeRange(0, out.length)];
    }
    return out;
}


- (NSString *)htmlText
{
    NSArray<NSArray<NSString *> *> *cells = self.cells;
    if (!cells.count)
        return @"";

    NSMutableString *html = [NSMutableString stringWithString:@"<table>\n"];
    // The first row is the header when the table has a separator; without
    // one there is no header to promise.
    BOOL header = self.separatorRow != NSNotFound;
    for (NSUInteger r = 0; r < cells.count; r++)
    {
        [html appendString:@"  <tr>"];
        NSString *tag = (header && r == 0) ? @"th" : @"td";
        for (NSString *cell in cells[r])
        {
            [html appendFormat:@"<%@>%@</%@>", tag,
             MPEscapedForHTML(cell), tag];
        }
        [html appendString:@"</tr>\n"];
    }
    [html appendString:@"</table>\n"];
    return html;
}


- (NSString *)textBySettingAlignment:(MPTableAlignment)alignment
                           forColumn:(NSUInteger)column
                               caret:(NSUInteger *)caret
{
    if (column >= self.columnCount)
        return nil;
    if (self.separatorRow == NSNotFound)
    {
        // No separator row to carry the alignment; give it one first.
        [self.rows insertObject:[NSMutableArray array] atIndex:1];
        self.separatorRow = 1;
    }
    while (self.alignments.count < self.columnCount)
        [self.alignments addObject:@(MPTableAlignmentNone)];
    self.alignments[column] = @(alignment);
    return [self serialiseWithCaretRow:0 column:column caret:caret];
}

- (NSString *)textByRepairingSeparatorRowWithCaret:(NSUInteger *)caret
{
    if (!self.separatorIsBroken)
        return nil;
    // Re-emitting the table is the repair: the separator row is written from
    // the alignments rather than copied.
    return [self serialiseWithCaretRow:0 column:0 caret:caret];
}

- (NSString *)textByAddingSeparatorRowWithCaret:(NSUInteger *)caret
{
    if (self.separatorRow != NSNotFound || !self.rows.count)
        return nil;
    [self.rows insertObject:[NSMutableArray array] atIndex:1];
    self.separatorRow = 1;
    while (self.alignments.count < self.columnCount)
        [self.alignments addObject:@(MPTableAlignmentNone)];
    NSUInteger caretRow = self.rows.count > 2 ? 2 : 0;
    return [self serialiseWithCaretRow:caretRow column:0 caret:caret];
}

@end
