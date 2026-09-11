//
//  MPCompareActionsTests.m
//  MacDownTests
//
//  What the comparison panel does *to* a document: copying a difference,
//  taking the other side's version, and going to a line. Everything here
//  goes through the two blocks the panel is given, which is the whole of
//  what it is allowed to do — so this is also the test that it cannot do
//  anything else.
//

#import <XCTest/XCTest.h>

#import "MPCompareWindowController.h"
#import "MPDiff.h"


@interface MPCompareBand : NSObject
@property (nonatomic) CGFloat from;
@property (nonatomic) CGFloat to;
@end


@interface MPCompareWindowController (Testing)
- (NSArray *)bandsOnTheMap;
- (void)rowPicked:(NSUInteger)row onTheLeft:(BOOL)left twice:(BOOL)twice;
- (NSMenu *)menuForRow:(NSUInteger)row onTheLeft:(BOOL)left;
- (void)copyPickedRow:(id)sender;
- (void)takeRightVersion:(id)sender;
- (NSRange)sourceRangeOf:(NSUInteger)row onTheLeft:(BOOL)left;
- (NSString *)sourceTextOf:(NSUInteger)row onTheLeft:(BOOL)left;
@end


@interface MPCompareActionsTests : XCTestCase
@property (strong) MPCompareWindowController *panel;
/// What the panel asked the document to do.
@property (assign) NSRange askedRange;
@property (copy) NSString *askedExpected;
@property (copy) NSString *askedReplacement;
@property (assign) BOOL letItHappen;
@property (assign) NSRange revealed;
@end


@implementation MPCompareActionsTests

- (void)setUp
{
    [super setUp];
    self.letItHappen = YES;
    self.revealed = NSMakeRange(NSNotFound, 0);

    NSString *mine = @"# Verbale\n\nPresenti: Anna.\n\n- una cosa\n";
    NSString *theirs = @"# Verbale\n\nPresenti: Anna, Bruno.\n\n- una cosa\n"
                       @"- due cose\n";
    self.panel = [MPCompareWindowController compare:mine named:@"mio.md"
                                                url:nil
                                               with:theirs named:@"loro.md"
                                                url:nil];

    __weak MPCompareActionsTests *weakSelf = self;
    self.panel.replaceInEditor = ^BOOL (NSRange range, NSString *expected,
                                        NSString *replacement) {
        MPCompareActionsTests *test = weakSelf;
        test.askedRange = range;
        test.askedExpected = expected;
        test.askedReplacement = replacement;
        return test.letItHappen;
    };
    self.panel.revealInEditor = ^BOOL (NSRange range) {
        weakSelf.revealed = range;
        return YES;
    };
}

- (void)tearDown
{
    [self.panel close];
    self.panel = nil;
    [super tearDown];
}


/// The row of the comparison that carries a given piece of text.
- (NSUInteger)rowSaying:(NSString *)text onTheLeft:(BOOL)left
{
    for (NSUInteger i = 0; i < 40; i++)
    {
        NSString *found = [self.panel sourceTextOf:i onTheLeft:left];
        if (found && [found containsString:text])
            return i;
    }
    return NSNotFound;
}


- (void)testARowKnowsWhereItIsInEachDocument
{
    NSUInteger row = [self rowSaying:@"Presenti" onTheLeft:YES];
    XCTAssertNotEqual(row, NSNotFound);
    NSRange mine = [self.panel sourceRangeOf:row onTheLeft:YES];
    XCTAssertNotEqual(mine.location, (NSUInteger)NSNotFound);
    // The two sides say different things in the same row, and each range is
    // its own side's.
    XCTAssertTrue([[self.panel sourceTextOf:row onTheLeft:NO]
        containsString:@"Bruno"]);
    XCTAssertFalse([[self.panel sourceTextOf:row onTheLeft:YES]
        containsString:@"Bruno"]);
}

- (void)testCopyingADifferenceTakesTheTextAndNotTheMargin
{
    NSUInteger row = [self rowSaying:@"Presenti" onTheLeft:NO];
    [self.panel rowPicked:row onTheLeft:NO twice:NO];
    [self.panel copyPickedRow:nil];

    NSString *copied = [[NSPasteboard generalPasteboard]
        stringForType:NSPasteboardTypeString];
    XCTAssertTrue([copied containsString:@"Presenti: Anna, Bruno."]);
    // Not the line number, not the + − ~ the panel draws in its margin.
    XCTAssertFalse([copied containsString:@"~"]);
    XCTAssertFalse([copied containsString:@"3"]);
}

- (void)testTakingTheRightVersionAsksTheDocumentWithWhatItExpects
{
    NSUInteger row = [self rowSaying:@"Presenti" onTheLeft:YES];
    [self.panel rowPicked:row onTheLeft:YES twice:NO];
    [self.panel takeRightVersion:nil];

    XCTAssertTrue([self.askedExpected containsString:@"Presenti: Anna."]);
    XCTAssertTrue([self.askedReplacement containsString:@"Anna, Bruno."]);
    // The range it asks for is the range of that paragraph in the document,
    // not of the row on screen.
    XCTAssertNotEqual(self.askedRange.location, (NSUInteger)NSNotFound);
    XCTAssertEqual(self.askedRange.length, self.askedExpected.length);
}

- (void)testTakingSomethingTheOtherSideOnlyHasPutsItIn
{
    NSUInteger row = [self rowSaying:@"due cose" onTheLeft:NO];
    XCTAssertNotEqual(row, NSNotFound);
    // Nothing on the left in that row: it is an addition, and taking it is
    // an insertion, with nothing replaced.
    XCTAssertEqual([self.panel sourceRangeOf:row onTheLeft:YES].location,
                   (NSUInteger)NSNotFound);

    [self.panel rowPicked:row onTheLeft:NO twice:NO];
    [self.panel takeRightVersion:nil];
    XCTAssertEqualObjects(self.askedExpected, @"");
    XCTAssertTrue([self.askedReplacement containsString:@"due cose"]);
}

- (void)testADocumentThatHasMovedOnIsNotWrittenInto
{
    self.letItHappen = NO;              // the document says no
    NSUInteger row = [self rowSaying:@"Presenti" onTheLeft:YES];
    [self.panel rowPicked:row onTheLeft:YES twice:NO];
    [self.panel takeRightVersion:nil];
    // Said, and not attempted again behind the reader's back.
    XCTAssertTrue([self.panel.window.title length] > 0);
}

- (void)testDoubleClickingOnTheLeftShowsItInTheEditor
{
    NSUInteger row = [self rowSaying:@"Presenti" onTheLeft:YES];
    [self.panel rowPicked:row onTheLeft:YES twice:YES];
    XCTAssertNotEqual(self.revealed.location, (NSUInteger)NSNotFound);

    // On the right there is nothing to show: that side is a file, not the
    // editor.
    self.revealed = NSMakeRange(NSNotFound, 0);
    [self.panel rowPicked:row onTheLeft:NO twice:YES];
    XCTAssertEqual(self.revealed.location, (NSUInteger)NSNotFound);
}

- (void)testTheStripFollowsWhereTheRowsActuallyAre
{
    // It drew one band per row at a fixed spacing, which points at the
    // wrong rows the moment two rows are of different heights — which is
    // every comparison by paragraph.
    NSArray *bands = [self.panel bandsOnTheMap];
    XCTAssertTrue(bands.count > 0);

    NSUInteger differences = 0;
    for (MPDiffRow *row in MPDiffRowsBetween(@"# Verbale\n\nPresenti: Anna.\n"
                                             @"\n- una cosa\n",
                                             @"# Verbale\n\n"
                                             @"Presenti: Anna, Bruno.\n\n"
                                             @"- una cosa\n- due cose\n"))
    {
        if (row.kind != MPDiffEqual)
            differences++;
    }
    XCTAssertEqual(bands.count, differences);

    CGFloat previous = -1.0;
    for (MPCompareBand *band in bands)
    {
        XCTAssertGreaterThanOrEqual(band.from, 0.0);
        XCTAssertLessThanOrEqual(band.to, 1.0001);
        XCTAssertGreaterThan(band.to, band.from);
        // In order, and never two rows sharing the same place.
        XCTAssertGreaterThanOrEqual(band.from, previous - 0.0001);
        previous = band.from;
    }
}

- (void)testWithNoEditorBehindItThePanelOffersNeither
{
    MPCompareWindowController *alone =
        [MPCompareWindowController compare:@"uno\n" named:@"a" url:nil
                                      with:@"due\n" named:@"b" url:nil];
    NSMenu *menu = [alone menuForRow:0 onTheLeft:YES];
    XCTAssertEqual(menu.numberOfItems, 1);   // only «copy this difference»
    [alone close];
}

@end
