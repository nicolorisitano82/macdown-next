//
//  MPTableSourceTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "MPTableSource.h"

@interface MPTableSourceTests : XCTestCase
@end

@implementation MPTableSourceTests

static NSString *const kTable =
    @"prima\n"
    @"\n"
    @"| Trimestre | Ricavi |\n"
    @"|---|---:|\n"
    @"| Q1 | 12400 |\n"
    @"| Q2 | 15900 |\n"
    @"\n"
    @"dopo\n";

/// The whole document with one edit applied, which is how the view uses this.
- (NSString *)apply:(NSString *)replacement to:(MPTableSource *)table
                 in:(NSString *)text
{
    NSMutableString *out = [text mutableCopy];
    [out replaceCharactersInRange:table.range withString:replacement];
    return out;
}

- (MPTableSource *)tableAtWord:(NSString *)word in:(NSString *)text
{
    NSRange found = [text rangeOfString:word];
    XCTAssertNotEqual(found.location, NSNotFound, @"%@ non c'è", word);
    return [MPTableSource tableCoveringIndex:found.location inText:text];
}


#pragma mark - Reading

- (void)testFindsTheTableAndItsShape
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    XCTAssertNotNil(t);
    XCTAssertEqual(t.rowCount, (NSUInteger)4);      // header, separator, two
    XCTAssertEqual(t.columnCount, (NSUInteger)2);
    XCTAssertEqual(t.separatorRow, (NSUInteger)1);
    XCTAssertFalse(t.separatorIsBroken);

    // The range covers the table and nothing around it.
    NSString *block = [kTable substringWithRange:t.range];
    XCTAssertTrue([block hasPrefix:@"| Trimestre"]);
    XCTAssertTrue([block hasSuffix:@"15900 |"]);
}

- (void)testLocatesRowsAndColumns
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    XCTAssertEqual([t rowContainingIndex:[kTable rangeOfString:@"Q1"].location],
                   (NSUInteger)2);
    XCTAssertEqual([t columnContainingIndex:
        [kTable rangeOfString:@"Q1"].location], (NSUInteger)0);
    XCTAssertEqual([t columnContainingIndex:
        [kTable rangeOfString:@"12400"].location], (NSUInteger)1);
    XCTAssertEqual([t alignmentOfColumn:1], MPTableAlignmentRight);
    XCTAssertEqual([t alignmentOfColumn:0], MPTableAlignmentNone);
}

- (void)testTextWithNoBarsIsNotATable
{
    XCTAssertNil([MPTableSource tableCoveringIndex:2 inText:@"solo prosa\n"]);
}


#pragma mark - Editing

- (void)testInsertsARowWhereAsked
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSUInteger caret = 0;
    NSString *out = [self apply:[t textByInsertingRowAt:3 caret:&caret]
                             to:t in:kTable];
    NSArray<NSString *> *lines = [out componentsSeparatedByString:@"\n"];
    XCTAssertTrue([lines[4] hasPrefix:@"| Q1"]);
    XCTAssertTrue([lines[6] hasPrefix:@"| Q2"]);

    // The new line between them: two cells, both empty. Asserted on its
    // shape rather than its spacing, which is the serialiser's business and
    // would make this test break for the wrong reason.
    MPTableSource *after = [self tableAtWord:@"Q1" in:out];
    XCTAssertEqual(after.rowCount, (NSUInteger)5);
    NSString *blank = [lines[5] stringByReplacingOccurrencesOfString:@" "
                                                          withString:@""];
    XCTAssertEqualObjects(blank, @"|||");
}

/// A row asked for above the header would become the header, so it goes below.
- (void)testARowIsNeverInsertedAboveTheHeader
{
    MPTableSource *t = [self tableAtWord:@"Trimestre" in:kTable];
    NSUInteger caret = 0;
    NSString *out = [self apply:[t textByInsertingRowAt:0 caret:&caret]
                             to:t in:kTable];
    NSArray<NSString *> *lines = [out componentsSeparatedByString:@"\n"];
    XCTAssertTrue([lines[2] hasPrefix:@"| Trimestre"], @"intestazione intatta");
    XCTAssertTrue([lines[3] hasPrefix:@"| ---"], @"separatore subito sotto");
}

- (void)testDeletesARowButNotTheSeparator
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSUInteger caret = 0;
    NSString *out = [self apply:[t textByDeletingRow:2 caret:&caret]
                             to:t in:kTable];
    XCTAssertEqual([out rangeOfString:@"Q1"].location, (NSUInteger)NSNotFound);
    XCTAssertNotEqual([out rangeOfString:@"Q2"].location,
                      (NSUInteger)NSNotFound);

    MPTableSource *again = [self tableAtWord:@"Q1" in:kTable];
    XCTAssertNil([again textByDeletingRow:again.separatorRow caret:&caret]);
}

- (void)testInsertsAndDeletesAColumn
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSUInteger caret = 0;
    NSString *widened = [self apply:[t textByInsertingColumnAt:1 caret:&caret]
                                 to:t in:kTable];
    MPTableSource *w = [self tableAtWord:@"Q1" in:widened];
    XCTAssertEqual(w.columnCount, (NSUInteger)3);
    XCTAssertEqual([w alignmentOfColumn:2], MPTableAlignmentRight,
                   @"l'allineamento resta con la sua colonna");

    NSString *narrowed = [self apply:[w textByDeletingColumn:0 caret:&caret]
                                  to:w in:widened];
    MPTableSource *n = [self tableAtWord:@"12400" in:narrowed];
    XCTAssertEqual(n.columnCount, (NSUInteger)2);
    XCTAssertEqual([narrowed rangeOfString:@"Trimestre"].location,
                   (NSUInteger)NSNotFound);
}

- (void)testTheLastColumnCannotBeDeleted
{
    NSString *one = @"| solo |\n|---|\n| a |\n";
    MPTableSource *t = [self tableAtWord:@"solo" in:one];
    NSUInteger caret = 0;
    XCTAssertNil([t textByDeletingColumn:0 caret:&caret]);
}

- (void)testSetsTheAlignment
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSUInteger caret = 0;
    NSString *out = [self apply:
        [t textBySettingAlignment:MPTableAlignmentCenter forColumn:0
                            caret:&caret] to:t in:kTable];
    MPTableSource *after = [self tableAtWord:@"Q1" in:out];
    XCTAssertEqual([after alignmentOfColumn:0], MPTableAlignmentCenter);
    XCTAssertEqual([after alignmentOfColumn:1], MPTableAlignmentRight);
}


#pragma mark - Repairs

- (void)testAddsTheSeparatorRowATableIsMissing
{
    NSString *without = @"| a | b |\n| 1 | 2 |\n";
    MPTableSource *t = [self tableAtWord:@"a" in:without];
    XCTAssertEqual(t.separatorRow, (NSUInteger)NSNotFound);

    NSUInteger caret = 0;
    NSString *out = [self apply:[t textByAddingSeparatorRowWithCaret:&caret]
                             to:t in:without];
    MPTableSource *after = [self tableAtWord:@"a" in:out];
    XCTAssertEqual(after.separatorRow, (NSUInteger)1);
    XCTAssertEqual(after.rowCount, (NSUInteger)3);
    XCTAssertFalse(after.separatorIsBroken);
}

/// The em dash that a substitution leaves behind, which stops it being a table.
- (void)testRepairsASeparatorRowOfEmDashes
{
    NSString *broken = @"| a | b |\n|—|—|\n| 1 | 2 |\n";
    MPTableSource *t = [self tableAtWord:@"a" in:broken];
    XCTAssertEqual(t.separatorRow, (NSUInteger)1);
    XCTAssertTrue(t.separatorIsBroken);

    NSUInteger caret = 0;
    NSString *out = [self apply:[t textByRepairingSeparatorRowWithCaret:&caret]
                             to:t in:broken];
    XCTAssertEqual([out rangeOfString:@"—"].location,
                   (NSUInteger)NSNotFound, @"nessun trattino lungo rimasto");

    MPTableSource *after = [self tableAtWord:@"a" in:out];
    XCTAssertFalse(after.separatorIsBroken);
    XCTAssertEqual(after.rowCount, (NSUInteger)3, @"nessuna riga in più");
}

/// Any edit re-emits the separator row, so any edit repairs it.
- (void)testAnEditAlsoRepairsABrokenSeparator
{
    NSString *broken = @"| a | b |\n|—|—|\n| 1 | 2 |\n";
    MPTableSource *t = [self tableAtWord:@"1" in:broken];
    NSUInteger caret = 0;
    NSString *out = [self apply:[t textByInsertingRowAt:3 caret:&caret]
                             to:t in:broken];
    XCTAssertEqual([out rangeOfString:@"—"].location,
                   (NSUInteger)NSNotFound);
}

/// A file that ends on the table's last row, with no break after it.
- (void)testATableAtTheEndOfTheFile
{
    NSString *text = @"| a | b |\n|---|---|\n| 1 | 2 |";
    MPTableSource *t = [self tableAtWord:@"1" in:text];
    XCTAssertEqual(t.rowCount, (NSUInteger)3, @"l'ultima riga contata una volta");
    XCTAssertEqual([t rowContainingIndex:[text rangeOfString:@"1"].location],
                   (NSUInteger)2);
}

/// What the toolbar's command produces has to read back as what was asked for.
- (void)testTheEmptyTableItBuildsReadsBackTheSameSize
{
    for (NSUInteger rows = 1; rows <= 4; rows++)
    {
        for (NSUInteger columns = 1; columns <= 4; columns++)
        {
            NSString *text = [MPTableSource emptyTableWithRows:rows
                                                       columns:columns];
            MPTableSource *back = [MPTableSource tableCoveringIndex:2
                                                             inText:text];
            XCTAssertNotNil(back);
            XCTAssertEqual(back.columnCount, columns,
                           @"%lu x %lu", (unsigned long)rows,
                           (unsigned long)columns);
            // The header and its separator sit on top of the rows asked for.
            XCTAssertEqual(back.rowCount, rows + 2,
                           @"%lu x %lu", (unsigned long)rows,
                           (unsigned long)columns);
            XCTAssertEqual(back.separatorRow, (NSUInteger)1);
        }
    }
}

/// Escaped bars are content, not cell boundaries.
- (void)testAnEscapedBarDoesNotSplitACell
{
    NSString *text = @"| a | b\\|c |\n|---|---|\n| 1 | 2 |\n";
    MPTableSource *t = [self tableAtWord:@"b" in:text];
    XCTAssertEqual(t.columnCount, (NSUInteger)2);
}

#pragma mark - Finding a cell from the preview

/// The preview names a cell by its place in the row; the source has to agree.
- (void)testTheCaretLandsInTheCellThatWasClicked
{
    NSUInteger row = [kTable rangeOfString:@"| Q1"].location;
    NSUInteger first = [MPTableSource caretForColumn:0 inRowAt:row
                                             inText:kTable];
    NSUInteger second = [MPTableSource caretForColumn:1 inRowAt:row
                                              inText:kTable];
    XCTAssertEqual(first, [kTable rangeOfString:@"Q1"].location);
    XCTAssertEqual(second, [kTable rangeOfString:@"12400"].location);
}

- (void)testTheHeaderRowIsFoundTheSameWay
{
    NSUInteger row = [kTable rangeOfString:@"| Trimestre"].location;
    XCTAssertEqual([MPTableSource caretForColumn:1 inRowAt:row inText:kTable],
                   [kTable rangeOfString:@"Ricavi"].location);
}

/// Any character of the row will do: the preview reports where the row began.
- (void)testTheRowIsFoundFromAnywhereInIt
{
    NSUInteger inside = [kTable rangeOfString:@"15900"].location;
    XCTAssertEqual([MPTableSource caretForColumn:0 inRowAt:inside
                                          inText:kTable],
                   [kTable rangeOfString:@"Q2"].location);
}

- (void)testARowWithoutOuterBars
{
    NSString *text = @"a | b | c\n--- | --- | ---\n1 | 2 | 3\n";
    NSUInteger row = [text rangeOfString:@"1 | 2"].location;
    XCTAssertEqual([MPTableSource caretForColumn:2 inRowAt:row inText:text],
                   [text rangeOfString:@"3"].location);
}

- (void)testAnEscapedBarIsNotACellBoundary
{
    NSString *text = @"| a\\|b | c |\n|---|---|\n| 1 | 2 |\n";
    NSUInteger row = 0;
    XCTAssertEqual([MPTableSource caretForColumn:1 inRowAt:row inText:text],
                   [text rangeOfString:@"c"].location);
}

- (void)testAnEmptyCellStillHasAPlaceToStand
{
    NSString *text = @"| a |  | c |\n";
    NSUInteger caret = [MPTableSource caretForColumn:1 inRowAt:0 inText:text];
    XCTAssertNotEqual(caret, (NSUInteger)NSNotFound);
    // Between the two bars that hold the empty cell.
    XCTAssertTrue(caret > [text rangeOfString:@"a"].location);
    XCTAssertTrue(caret < [text rangeOfString:@"c"].location);
}

- (void)testAColumnThatIsNotThereAnswersNothing
{
    NSUInteger row = [kTable rangeOfString:@"| Q1"].location;
    XCTAssertEqual([MPTableSource caretForColumn:9 inRowAt:row inText:kTable],
                   (NSUInteger)NSNotFound);
    XCTAssertEqual([MPTableSource caretForColumn:0 inRowAt:0
                                          inText:@"solo prosa\n"],
                   (NSUInteger)NSNotFound);
}

#pragma mark - Moving a row or a column

- (void)testARowMovesDownAndComesBack
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSUInteger row = [t rowContainingIndex:[kTable rangeOfString:@"Q1"].location];
    NSUInteger caret = 0;
    NSString *moved = [self apply:[t textByMovingRow:row by:1 caret:&caret]
                               to:t in:kTable];
    XCTAssertLessThan([moved rangeOfString:@"Q2"].location,
                      [moved rangeOfString:@"Q1"].location);
    // The header and the dashes stay where they were.
    XCTAssertTrue([moved containsString:@"| Trimestre | Ricavi |"]);
    XCTAssertLessThan([moved rangeOfString:@"Trimestre"].location,
                      [moved rangeOfString:@"---"].location);

    MPTableSource *again = [self tableAtWord:@"Q1" in:moved];
    NSUInteger back = [again rowContainingIndex:
        [moved rangeOfString:@"Q1"].location];
    NSString *restored = [self apply:[again textByMovingRow:back by:-1
                                                      caret:&caret]
                                  to:again in:moved];
    // Back in the order it started in. Not character for character: every
    // edit re-emits the table with its bars lined up, which is the whole
    // point of doing it in one place.
    XCTAssertLessThan([restored rangeOfString:@"Q1"].location,
                      [restored rangeOfString:@"Q2"].location);
    XCTAssertTrue([restored hasPrefix:@"prima\n\n"]);
    XCTAssertTrue([restored hasSuffix:@"\ndopo\n"]);
}

- (void)testTheHeaderStaysTheHeader
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSUInteger caret = 0;
    // The first body row has nowhere to go up: over it are the dashes and
    // the header, and a row moved there would become one of them.
    NSUInteger first = [t rowContainingIndex:
        [kTable rangeOfString:@"Q1"].location];
    XCTAssertNil([t textByMovingRow:first by:-1 caret:&caret]);
    // Nor does the header itself move down.
    XCTAssertNil([t textByMovingRow:0 by:1 caret:&caret]);
    // Nor the separator, in either direction.
    XCTAssertNil([t textByMovingRow:t.separatorRow by:1 caret:&caret]);
    XCTAssertNil([t textByMovingRow:t.separatorRow by:-1 caret:&caret]);
}

- (void)testTheLastRowHasNowhereToGo
{
    MPTableSource *t = [self tableAtWord:@"Q2" in:kTable];
    NSUInteger last = [t rowContainingIndex:
        [kTable rangeOfString:@"Q2"].location];
    NSUInteger caret = 0;
    XCTAssertNil([t textByMovingRow:last by:1 caret:&caret]);
}

- (void)testAColumnMovesWithItsAlignment
{
    MPTableSource *t = [self tableAtWord:@"Ricavi" in:kTable];
    NSUInteger column = [t columnContainingIndex:
        [kTable rangeOfString:@"Ricavi"].location];
    XCTAssertEqual([t alignmentOfColumn:column], MPTableAlignmentRight);

    NSUInteger caret = 0;
    NSString *moved = [self apply:[t textByMovingColumn:column by:-1
                                                  caret:&caret]
                               to:t in:kTable];
    XCTAssertLessThan([moved rangeOfString:@"Ricavi"].location,
                      [moved rangeOfString:@"Trimestre"].location);
    XCTAssertLessThan([moved rangeOfString:@"12400"].location,
                      [moved rangeOfString:@"Q1"].location);

    // The alignment belongs to the column and travels with it.
    MPTableSource *after = [self tableAtWord:@"Ricavi" in:moved];
    XCTAssertEqual([after alignmentOfColumn:0], MPTableAlignmentRight);
    XCTAssertEqual([after alignmentOfColumn:1], MPTableAlignmentNone);
}

- (void)testTheEdgesOfTheTableAreEdges
{
    MPTableSource *t = [self tableAtWord:@"Trimestre" in:kTable];
    NSUInteger caret = 0;
    XCTAssertNil([t textByMovingColumn:0 by:-1 caret:&caret]);
    XCTAssertNil([t textByMovingColumn:t.columnCount - 1 by:1 caret:&caret]);
}


#pragma mark - Handing the table to something else

- (void)testTheCellsWithoutTheDashes
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSArray<NSArray<NSString *> *> *cells = t.cells;
    XCTAssertEqual(cells.count, (NSUInteger)3);     // header and two rows
    XCTAssertEqualObjects(cells[0], (@[@"Trimestre", @"Ricavi"]));
    XCTAssertEqualObjects(cells[2], (@[@"Q2", @"15900"]));
}

- (void)testCopiedWithTabsAndWithCommas
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    XCTAssertEqualObjects([t delimitedTextWithSeparator:@"\t"],
        @"Trimestre\tRicavi\nQ1\t12400\nQ2\t15900\n");
    XCTAssertEqualObjects([t delimitedTextWithSeparator:@","],
        @"Trimestre,Ricavi\nQ1,12400\nQ2,15900\n");
}

- (void)testAFieldThatWouldBreakTheFormatIsQuoted
{
    NSString *text = @"| Nome | Nota |\n|---|---|\n"
        @"| Rossi, Mario | disse \"sì\" |\n";
    MPTableSource *t = [self tableAtWord:@"Rossi" in:text];
    XCTAssertEqualObjects([t delimitedTextWithSeparator:@","],
        @"Nome,Nota\n\"Rossi, Mario\",\"disse \"\"sì\"\"\"\n");
    // A comma is nothing to a tab-separated file, and stays as it is.
    XCTAssertTrue([[t delimitedTextWithSeparator:@"\t"]
        containsString:@"Rossi, Mario"]);
}

- (void)testCopiedAsHTML
{
    MPTableSource *t = [self tableAtWord:@"Q1" in:kTable];
    NSString *html = [t htmlText];
    XCTAssertTrue([html containsString:
        @"<tr><th>Trimestre</th><th>Ricavi</th></tr>"], @"%@", html);
    XCTAssertTrue([html containsString:
        @"<tr><td>Q1</td><td>12400</td></tr>"], @"%@", html);
    XCTAssertFalse([html containsString:@"---"]);
}

- (void)testMarkupInACellIsEscapedOnTheWayOut
{
    NSString *text = @"| Tag | Nota |\n|---|---|\n| <b> | a & b |\n";
    MPTableSource *t = [self tableAtWord:@"Tag" in:text];
    NSString *html = [t htmlText];
    XCTAssertTrue([html containsString:@"&lt;b&gt;"], @"%@", html);
    XCTAssertTrue([html containsString:@"a &amp; b"], @"%@", html);
}

@end
