//
//  MPCloudLedgerTests.m
//  MacDownTests
//
//  Il registro: cosa si sa fra un'occhiata e l'altra, e cosa si conta come
//  «cambiato». È la parte che non ha bisogno di rete per essere sbagliata,
//  quindi è la parte che si prova qui.
//

#import <XCTest/XCTest.h>

#import "MPCloudLedger.h"


@interface MPCloudLedgerTests : XCTestCase
@property (strong) NSURL *folder;
@property (strong) MPCloudLedger *ledger;
@end


@implementation MPCloudLedgerTests

- (void)setUp
{
    [super setUp];
    // In una cartella sua: un registro di prova non ha niente da fare
    // dentro quello di chi sta usando l'applicazione.
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    self.ledger = [[MPCloudLedger alloc] initWithService:@"prova"
                                                inFolder:self.folder];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}


/// Una voce come la racconta Drive.
- (NSDictionary *)change:(NSString *)identifier
                    name:(NSString *)name
                revision:(NSString *)revision
{
    return @{@"fileId": identifier,
             @"file": @{@"name": name, @"headRevisionId": revision}};
}


- (void)testTheFirstTimeEverythingIsNew
{
    MPCloudDelta *delta = [self.ledger applyChanges:@[
        [self change:@"1" name:@"uno.md" revision:@"a"],
        [self change:@"2" name:@"due.md" revision:@"a"],
    ]];
    XCTAssertEqual(delta.added, 2u);
    XCTAssertEqual(delta.changed, 0u);
    XCTAssertEqual(delta.removed, 0u);
    XCTAssertEqual(self.ledger.count, 2u);
    XCTAssertFalse(delta.isQuiet);
}

- (void)testTheSameVersionTwiceIsNotAChange
{
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    // Il servizio racconta anche i propri rimescolamenti: un documento con
    // la stessa versione non è un documento cambiato.
    MPCloudDelta *again = [self.ledger applyChanges:@[
        [self change:@"1" name:@"uno.md" revision:@"a"]]];
    XCTAssertTrue(again.isQuiet);
    XCTAssertEqualObjects(again.summary, @"nothing has moved");
}

- (void)testANewVersionIsAChange
{
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    MPCloudDelta *delta = [self.ledger applyChanges:@[
        [self change:@"1" name:@"uno.md" revision:@"b"]]];
    XCTAssertEqual(delta.changed, 1u);
    XCTAssertEqual(delta.added, 0u);
    XCTAssertEqualObjects([self.ledger documentWithIdentifier:@"1"][@"revision"],
                          @"b");
}

- (void)testARenameIsNotAChangeOfContents
{
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    MPCloudDelta *delta = [self.ledger applyChanges:@[
        [self change:@"1" name:@"primo.md" revision:@"a"]]];
    XCTAssertTrue(delta.isQuiet);
    // Ma il nome nuovo lo si tiene: serve per ritrovarlo.
    XCTAssertEqualObjects([self.ledger documentWithIdentifier:@"1"][@"name"],
                          @"primo.md");
}

- (void)testSomethingGoneIsForgottenAndCounted
{
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    MPCloudDelta *delta = [self.ledger applyChanges:@[
        @{@"fileId": @"1", @"removed": @YES}]];
    XCTAssertEqual(delta.removed, 1u);
    XCTAssertEqual(self.ledger.count, 0u);
    // E qualcosa che non si era mai visto sparire non conta niente.
    MPCloudDelta *nothing = [self.ledger applyChanges:@[
        @{@"fileId": @"9", @"removed": @YES}]];
    XCTAssertTrue(nothing.isQuiet);
}

- (void)testSomethingInTheBinCountsAsGone
{
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    MPCloudDelta *delta = [self.ledger applyChanges:@[
        @{@"fileId": @"1",
          @"file": @{@"name": @"uno.md", @"trashed": @YES}}]];
    XCTAssertEqual(delta.removed, 1u);
}

- (void)testWhatIsWrittenComesBack
{
    self.ledger.startToken = @"SEGNALIBRO";
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    XCTAssertTrue([self.ledger save]);

    MPCloudLedger *again = [[MPCloudLedger alloc] initWithService:@"prova"
                                                         inFolder:self.folder];
    XCTAssertEqualObjects(again.startToken, @"SEGNALIBRO");
    XCTAssertEqual(again.count, 1u);
    XCTAssertEqualObjects([again documentWithIdentifier:@"1"][@"name"],
                          @"uno.md");
    // E riaperto così, quello che già sapeva non è una novità.
    MPCloudDelta *delta = [again applyChanges:@[
        [self change:@"1" name:@"uno.md" revision:@"a"]]];
    XCTAssertTrue(delta.isQuiet);
}

- (void)testForgettingLeavesNothingBehind
{
    [self.ledger applyChanges:@[[self change:@"1" name:@"uno.md" revision:@"a"]]];
    self.ledger.startToken = @"X";
    [self.ledger save];
    [self.ledger forget];
    XCTAssertEqual(self.ledger.count, 0u);
    XCTAssertNil(self.ledger.startToken);

    MPCloudLedger *again = [[MPCloudLedger alloc] initWithService:@"prova"
                                                         inFolder:self.folder];
    XCTAssertEqual(again.count, 0u);
    XCTAssertNil(again.startToken);
}

- (void)testTheSummaryIsReadable
{
    MPCloudDelta *delta = [[MPCloudDelta alloc] init];
    delta.added = 2;
    delta.changed = 1;
    XCTAssertEqualObjects(delta.summary, @"2 new, 1 changed");
    delta.removed = 3;
    XCTAssertTrue([delta.summary containsString:@"3 gone"]);
}

@end
