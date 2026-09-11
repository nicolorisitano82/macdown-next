//
//  MPMissingFileTests.m
//  MacDownTests
//
//  A document whose file has gone out from under it.
//

#import <XCTest/XCTest.h>

#import "MPDocument.h"
#import "MPUtilities.h"


/// A menu item is what asks whether a command applies.
@interface MPFakeItem : NSObject <NSValidatedUserInterfaceItem>
@property (nonatomic) SEL action;
@property (nonatomic) NSInteger tag;
@end

@implementation MPFakeItem
@end


@interface MPMissingFileTests : XCTestCase
@property (strong) NSURL *folder;
@end

@implementation MPMissingFileTests

- (void)setUp
{
    [super setUp];
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}


- (void)testAFileThatIsThereIsNotMissing
{
    NSURL *file = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    [@"# Verbale\n" writeToURL:file atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertFalse(MPFileIsMissing(file));
}

- (void)testAFileTakenAwayIsMissing
{
    NSURL *file = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    [@"# Verbale\n" writeToURL:file atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertFalse(MPFileIsMissing(file));

    // What `git mv`, a script, or another program does while the
    // application is not looking.
    NSURL *elsewhere = [self.folder
        URLByAppendingPathComponent:@"altrove.md"];
    [[NSFileManager defaultManager] moveItemAtURL:file toURL:elsewhere
                                            error:NULL];
    XCTAssertTrue(MPFileIsMissing(file));
    XCTAssertFalse(MPFileIsMissing(elsewhere));
}

- (void)testADocumentWithNoFileIsMissingNothing
{
    // Never saved: there is no file to lose, and nothing to warn about.
    XCTAssertFalse(MPFileIsMissing(nil));
    XCTAssertFalse(MPFileIsMissing(
        [NSURL URLWithString:@"https://esempio.it/verbale.md"]));
}

- (void)testTheFolderItselfCounts
{
    // A document inside a folder somebody deleted whole.
    NSURL *inside = [self.folder
        URLByAppendingPathComponent:@"sotto/verbale.md"];
    XCTAssertTrue(MPFileIsMissing(inside));
}


#pragma mark - What the menu offers

- (void)testRevertIsNotOfferedForADocumentThatHasNoFile
{
    MPDocument *document = [[MPDocument alloc] init];
    MPFakeItem *item = [[MPFakeItem alloc] init];
    item.action = @selector(revertDocumentToSaved:);
    // Never saved: there is nothing to revert to, and the command says so
    // by not being there.
    XCTAssertFalse([document validateUserInterfaceItem:item]);
}

@end
