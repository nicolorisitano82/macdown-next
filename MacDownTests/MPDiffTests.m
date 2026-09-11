//
//  MPDiffTests.m
//  MacDownTests
//
//  What is different between two texts: the answers, and the awkward cases
//  that are easier to ask here than to find by reading a window.
//

#import <XCTest/XCTest.h>

#import "MPCompareWindowController.h"
#import "MPDiff.h"


@interface MPDiffTests : XCTestCase
@end


@implementation MPDiffTests

/// "=1|1 …" for each row, which is short enough to compare in one line.
- (NSString *)shapeOf:(NSArray<MPDiffRow *> *)rows
{
    NSMutableArray<NSString *> *pieces = [NSMutableArray array];
    for (MPDiffRow *row in rows)
    {
        NSString *mark = @"=";
        if (row.kind == MPDiffAdded)
            mark = @"+";
        else if (row.kind == MPDiffRemoved)
            mark = @"-";
        else if (row.kind == MPDiffChanged)
            mark = @"~";
        [pieces addObject:mark];
    }
    return [pieces componentsJoinedByString:@""];
}


- (void)testTwoTextsTheSameHaveNoDifferences
{
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(@"uno\ndue\ntre\n",
                                                   @"uno\ndue\ntre\n");
    XCTAssertEqualObjects([self shapeOf:rows], @"===");
    NSUInteger added = 1, removed = 1, changed = 1;
    MPDiffCounts(rows, &added, &removed, &changed);
    XCTAssertEqual(added, 0u);
    XCTAssertEqual(removed, 0u);
    XCTAssertEqual(changed, 0u);
}

- (void)testALineChangedIsOneRowAndNotTwo
{
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(@"uno\ndue\ntre\n",
                                                   @"uno\ndue e mezzo\ntre\n");
    // A removal followed by an addition in the same place is one change:
    // that is how a person reads it, and how a merge will have to offer it.
    XCTAssertEqualObjects([self shapeOf:rows], @"=~=");
    MPDiffRow *middle = rows[1];
    XCTAssertEqualObjects(middle.left, @"due");
    XCTAssertEqualObjects(middle.right, @"due e mezzo");
    XCTAssertEqual(middle.leftLine, 2u);
    XCTAssertEqual(middle.rightLine, 2u);
}

- (void)testWhatWasAddedAndWhatWasTakenAway
{
    NSArray<MPDiffRow *> *added = MPDiffRowsBetween(@"uno\ntre\n",
                                                    @"uno\ndue\ntre\n");
    XCTAssertEqualObjects([self shapeOf:added], @"=+=");
    XCTAssertEqual(added[1].leftLine, 0u);
    XCTAssertEqual(added[1].rightLine, 2u);
    XCTAssertNil(added[1].left);

    NSArray<MPDiffRow *> *removed = MPDiffRowsBetween(@"uno\ndue\ntre\n",
                                                      @"tre\n");
    XCTAssertEqualObjects([self shapeOf:removed], @"--=");
    XCTAssertNil(removed[0].right);
}

- (void)testOneSideEmpty
{
    XCTAssertEqualObjects([self shapeOf:MPDiffRowsBetween(@"", @"a\nb\n")],
                          @"++");
    XCTAssertEqualObjects([self shapeOf:MPDiffRowsBetween(@"a\nb\n", @"")],
                          @"--");
    XCTAssertEqual(MPDiffRowsBetween(@"", @"").count, 0u);
    XCTAssertEqual(MPDiffRowsBetween(nil, nil).count, 0u);
}

- (void)testTheLastLineCountsWithOrWithoutALineEnding
{
    // A file somebody's editor left without a final newline is not a file
    // with one line fewer.
    NSArray<NSString *> *lines = MPDiffLinesOfText(@"uno\ndue");
    XCTAssertEqual(lines.count, 2u);
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(@"uno\ndue", @"uno\ndue\n");
    XCTAssertEqualObjects([self shapeOf:rows], @"==");
}

- (void)testALineMovedReadsAsOneRemovalAndOneAddition
{
    // Not as a move: this comparison is by line, and saying «moved» would
    // be a guess. What matters is that the unchanged lines stay unchanged.
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(@"a\nb\nc\n",
                                                   @"b\nc\na\n");
    XCTAssertEqualObjects([self shapeOf:rows], @"-==+");
}

- (void)testTwoTextsWithNothingInCommon
{
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(@"alfa\nbeta\n",
                                                   @"uno\ndue\n");
    XCTAssertEqualObjects([self shapeOf:rows], @"~~");
}

- (void)testLineNumbersAreEachSidesOwn
{
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(@"a\nb\nc\nd\n",
                                                   @"a\nc\nd\n");
    XCTAssertEqualObjects([self shapeOf:rows], @"=-==");
    // The right side does not count the line it does not have.
    XCTAssertEqual(rows[2].leftLine, 3u);
    XCTAssertEqual(rows[2].rightLine, 2u);
}

- (void)testAWholeFileOfDifferencesStillAnswers
{
    // Past the effort limit the comparison stops looking for the shortest
    // path; it still has to answer, and answer something true.
    NSMutableString *left = [NSMutableString string];
    NSMutableString *right = [NSMutableString string];
    for (NSUInteger i = 0; i < 30000; i++)
    {
        [left appendFormat:@"sinistra %lu\n", (unsigned long)i];
        [right appendFormat:@"destra %lu\n", (unsigned long)i];
    }
    NSDate *started = [NSDate date];
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetween(left, right);
    XCTAssertEqual(rows.count, 30000u);
    for (MPDiffRow *row in rows)
        XCTAssertNotEqual(row.kind, MPDiffEqual);
    XCTAssertLessThan([[NSDate date] timeIntervalSinceDate:started], 10.0);
}

#pragma mark - By paragraph, and what can be ignored

- (void)testAReWrappedDocumentIsNotAChangedDocument
{
    NSString *before = @"# Nota\n\n"
        @"Una frase lunga che sta\nsu due righe.\n\n"
        @"E un secondo paragrafo,\nanche questo su due.\n";
    NSString *after = @"# Nota\n\n"
        @"Una frase lunga\nche sta su due\nrighe.\n\n"
        @"E un secondo\nparagrafo, anche questo\nsu due.\n";

    // The measurement this whole grain exists for: by line, a document that
    // has only been re-wrapped reads as changed nearly everywhere.
    NSUInteger changed = 0, added = 0, removed = 0;
    MPDiffCounts(MPDiffRowsBetween(before, after), &added, &removed, &changed);
    XCTAssertGreaterThan(changed + added + removed, 3u);

    MPDiffOptions byParagraph = MPDiffOptionsStrict;
    byParagraph.grain = MPDiffByParagraphs;
    NSArray<MPDiffRow *> *rows =
        MPDiffRowsBetweenWithOptions(before, after, byParagraph);
    XCTAssertEqualObjects([self shapeOf:rows], @"=====");
}

- (void)testByParagraphAWordIsStillAWord
{
    NSString *before = @"Una frase lunga che sta\nsu due righe.\n";
    NSString *after = @"Una frase corta\nche sta su due righe.\n";
    MPDiffOptions byParagraph = MPDiffOptionsStrict;
    byParagraph.grain = MPDiffByParagraphs;
    NSArray<MPDiffRow *> *rows =
        MPDiffRowsBetweenWithOptions(before, after, byParagraph);
    XCTAssertEqualObjects([self shapeOf:rows], @"~");
    // And the row says which line the paragraph starts on, not which line
    // the difference is on: a paragraph has one beginning.
    XCTAssertEqual(rows[0].leftLine, 1u);
}

- (void)testWhatIsNotProseKeepsItsOwnLines
{
    NSString *text = @"# Titolo\n\n- primo\n- secondo\n\n| a | b |\n"
                     @"|---|---|\n\n```\nuno\ndue\n```\n\nProsa che\ncontinua.\n";
    NSArray<NSString *> *units = MPDiffUnitsOfText(text, MPDiffByParagraphs);
    // Everything above stands on its own line; only the last two lines are
    // one paragraph.
    XCTAssertEqualObjects(units.lastObject, @"Prosa che continua.");
    XCTAssertTrue([units containsObject:@"- primo"]);
    XCTAssertTrue([units containsObject:@"| a | b |"]);
    XCTAssertTrue([units containsObject:@"uno"]);   // inside a fence
}

- (void)testADocumentThatShowsAFenceIsNotAllCode
{
    // Four backticks quoting three, which is how a document about Markdown
    // shows a fence. Taken for one, every paragraph after it stopped being
    // a paragraph — and the comparison by paragraph became a comparison by
    // line without saying so.
    NSString *text = @"Un recinto ```` ```mermaid ```` si scrive cosi.\n\n"
                     @"Prosa che\ncontinua su due righe.\n";
    NSArray<NSString *> *units = MPDiffUnitsOfText(text, MPDiffByParagraphs);
    XCTAssertEqualObjects(units.lastObject, @"Prosa che continua su due righe.");
}

- (void)testIgnoringSpacesAndCase
{
    NSString *before = @"  Una riga  con   spazi\nSECONDA\n";
    NSString *after = @"Una riga con spazi\nseconda\n";

    MPDiffOptions space = MPDiffOptionsStrict;
    space.ignoringSpace = YES;
    XCTAssertEqualObjects([self shapeOf:
        MPDiffRowsBetweenWithOptions(before, after, space)], @"=~");

    MPDiffOptions both = space;
    both.ignoringCase = YES;
    XCTAssertEqualObjects([self shapeOf:
        MPDiffRowsBetweenWithOptions(before, after, both)], @"==");

    // What is shown is what was written: ignoring case is not lowercasing
    // somebody's document.
    NSArray<MPDiffRow *> *rows =
        MPDiffRowsBetweenWithOptions(before, after, both);
    XCTAssertEqualObjects(rows[1].left, @"SECONDA");
    XCTAssertEqualObjects(rows[1].right, @"seconda");
}


- (void)testTheWordsThatDifferInsideALine
{
    NSArray<NSValue *> *left = nil;
    NSArray<NSValue *> *right = nil;
    NSString *before = @"il gatto nero dorme";
    NSString *after = @"il cane nero dorme sempre";
    MPDiffWordRanges(before, after, &left, &right);

    NSMutableArray<NSString *> *onLeft = [NSMutableArray array];
    for (NSValue *value in left)
        [onLeft addObject:[before substringWithRange:value.rangeValue]];
    NSMutableArray<NSString *> *onRight = [NSMutableArray array];
    for (NSValue *value in right)
        [onRight addObject:[after substringWithRange:value.rangeValue]];

    NSArray *expectedLeft = @[@"gatto"];
    XCTAssertEqualObjects(onLeft, expectedLeft);
    // The space before a word added at the end belongs to the addition, so
    // that what is marked reads as one thing.
    NSArray *expectedRight = @[@"cane", @" sempre"];
    XCTAssertEqualObjects(onRight, expectedRight);
}

- (void)testTwoIdenticalLinesHaveNoWordsToMark
{
    NSArray<NSValue *> *left = nil;
    NSArray<NSValue *> *right = nil;
    MPDiffWordRanges(@"stessa riga", @"stessa riga", &left, &right);
    XCTAssertEqual(left.count, 0u);
    XCTAssertEqual(right.count, 0u);
}

#pragma mark - Sending it to somebody else

- (void)testTheUnifiedDiffIsTheOneEveryToolReads
{
    NSString *before = @"uno\ndue\ntre\nquattro\ncinque\nsei\nsette\n";
    NSString *after = @"uno\ndue\ntre e mezzo\nquattro\ncinque\nsei\nsette\notto\n";
    NSString *patch = MPDiffUnifiedText(MPDiffRowsBetween(before, after),
                                        @"a.md", @"b.md", 2, NO);

    // Measured against diff -U2 on the same pair, which writes exactly this.
    NSString *expected = @"--- a.md\n+++ b.md\n@@ -1,7 +1,8 @@\n uno\n due\n"
        @"-tre\n+tre e mezzo\n quattro\n cinque\n sei\n sette\n+otto\n";
    XCTAssertEqualObjects(patch, expected);
}

- (void)testAPatchOfParagraphsSaysSo
{
    MPDiffOptions byParagraph = MPDiffOptionsStrict;
    byParagraph.grain = MPDiffByParagraphs;
    NSArray<MPDiffRow *> *rows = MPDiffRowsBetweenWithOptions(
        @"Una frase\nsu due righe.\n", @"Un'altra frase\nsu due righe.\n",
        byParagraph);
    NSString *patch = MPDiffUnifiedText(rows, @"a.md", @"b.md", 3, YES);
    XCTAssertTrue([patch containsString:@"# compared by paragraph"]);
    XCTAssertTrue([patch containsString:@"-Una frase su due righe."]);
    XCTAssertTrue([patch containsString:@"+Un'altra frase su due righe."]);
}

- (void)testTwoDocumentsTheSameExportNothing
{
    NSString *same = @"uno\ndue\n";
    XCTAssertEqual(MPDiffUnifiedText(MPDiffRowsBetween(same, same),
                                     @"a", @"b", 3, NO).length, 0u);
}

- (void)testFarApartDifferencesAreTwoHunks
{
    NSMutableString *before = [NSMutableString string];
    for (NSUInteger i = 0; i < 40; i++)
        [before appendFormat:@"riga %lu\n", (unsigned long)i];
    NSMutableString *after = [before mutableCopy];
    [after replaceOccurrencesOfString:@"riga 2\n" withString:@"riga due\n"
                              options:0 range:NSMakeRange(0, after.length)];
    [after replaceOccurrencesOfString:@"riga 33\n" withString:@"riga trentatre\n"
                              options:0 range:NSMakeRange(0, after.length)];
    NSString *patch = MPDiffUnifiedText(MPDiffRowsBetween(before, after),
                                        @"a", @"b", 3, NO);
    NSUInteger hunks = [patch componentsSeparatedByString:@"@@ -"].count - 1;
    XCTAssertEqual(hunks, 2u);
}


#pragma mark - What the window is called

- (void)testTheTitleCarriesTheCountSoTheWindowMenuIsReadable
{
    NSString *none = [MPCompareWindowController titleForLeft:@"a.md"
        right:@"b.md" differences:0];
    XCTAssertTrue([none containsString:@"a.md"]);
    XCTAssertTrue([none containsString:@"b.md"]);

    NSString *one = [MPCompareWindowController titleForLeft:@"a.md"
        right:@"b.md" differences:1];
    NSString *many = [MPCompareWindowController titleForLeft:@"a.md"
        right:@"b.md" differences:9];
    // One is not «1 differences», and nine says nine.
    XCTAssertNotEqualObjects(one, many);
    XCTAssertTrue([many containsString:@"9"]);
    XCTAssertFalse([one containsString:@"1 "]);
}

- (void)testAComparisonWindowOpensAndCarriesBothSides
{
    // The window is built in code, and a mistake in building it is an
    // exception AppKit swallows: the menu item then does nothing at all,
    // which is exactly how this test came to exist.
    MPCompareWindowController *panel = [MPCompareWindowController
        compare:@"uno\ndue\ntre\n" named:@"mio.md" url:nil
           with:@"uno\ndue e mezzo\ntre\nquattro\n" named:@"loro.md"
            url:nil];
    XCTAssertNotNil(panel.window);
    XCTAssertTrue([panel.window.title containsString:@"mio.md"]);
    XCTAssertTrue([panel.window.title containsString:@"loro.md"]);
    [panel close];
}

- (void)testATitleWithNothingToPutInIt
{
    NSString *title = [MPCompareWindowController titleForLeft:@"" right:nil
                                                  differences:3];
    XCTAssertTrue(title.length > 0);
}

@end
