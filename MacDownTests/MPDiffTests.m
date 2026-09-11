//
//  MPDiffTests.m
//  MacDownTests
//
//  What is different between two texts: the answers, and the awkward cases
//  that are easier to ask here than to find by reading a window.
//

#import <XCTest/XCTest.h>

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

@end
