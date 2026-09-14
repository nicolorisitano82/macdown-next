//
//  MPSidebarFilesTests.m
//  MacDownTests
//
//  La scheda «File» della barra laterale, quando il documento non sta su
//  questo disco ma in un servizio collegato: i vicini sono i documenti che
//  stanno là dentro, e sono quelli che l'elenco deve mostrare.
//

#import <XCTest/XCTest.h>

#import "MPSidebarController.h"


/// Quello che serve per guardare dentro senza aprire una finestra.
@interface MPSidebarController (Prove)
- (NSArray *)childrenOfItem:(id)item;
- (void)setMode:(NSUInteger)mode;
- (NSMenu *)menuForAttachmentAt:(NSInteger)row;
- (NSOutlineView *)outlineView;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
@end


@interface MPSidebarFilesTests : XCTestCase
@property (strong) MPSidebarController *sidebar;
@property (strong) NSURL *folder;
@end


@implementation MPSidebarFilesTests

- (void)setUp
{
    [super setUp];
    self.sidebar = [[MPSidebarController alloc] init];
    [self.sidebar setMode:1];       // la scheda dei file
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"barra-%@",
            [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"# vicino\n" writeToURL:[self.folder
        URLByAppendingPathComponent:@"vicino.md"] atomically:YES
        encoding:NSUTF8StringEncoding error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    self.sidebar = nil;
    [super tearDown];
}


- (MPSidebarRemoteFile *)fileNamed:(NSString *)name
{
    MPSidebarRemoteFile *file = [[MPSidebarRemoteFile alloc] init];
    file.name = name;
    file.identifier = [@"id-" stringByAppendingString:name];
    return file;
}


- (void)testTheListShowsWhatIsInTheService
{
    [self.sidebar showRemoteDocuments:@[[self fileNamed:@"verbale.md"],
                                        [self fileNamed:@"appunti.md"]]
                                 from:@"appunti"];
    XCTAssertEqualObjects(self.sidebar.remotePlaceName, @"appunti");

    NSArray *rows = [self.sidebar childrenOfItem:nil];
    XCTAssertEqual(rows.count, 2u);
    XCTAssertEqualObjects([rows.firstObject name], @"verbale.md");
    XCTAssertEqualObjects([rows.firstObject identifier], @"id-verbale.md");
    // Sono documenti, non cartelle: là dentro non si scende.
    XCTAssertFalse([self.sidebar outlineView:nil
                              isItemExpandable:rows.firstObject]);
    XCTAssertEqual([[self.sidebar childrenOfItem:rows.firstObject] count], 0u);
}


/// Un documento che sta in un servizio non ha una cartella su questo
/// disco: l'elenco del servizio non deve sparire perché qualcuno ha
/// passato un URL vuoto.
- (void)testAnEmptyFolderDoesNotWipeTheServiceList
{
    [self.sidebar showRemoteDocuments:@[[self fileNamed:@"verbale.md"]]
                                 from:@"appunti"];
    [self.sidebar setRootURL:nil];
    XCTAssertEqualObjects(self.sidebar.remotePlaceName, @"appunti");
    XCTAssertEqual([[self.sidebar childrenOfItem:nil] count], 1u);
}


/// Una cartella vera invece sì: si sta guardando un'altra cosa.
- (void)testARealFolderTakesTheListBack
{
    [self.sidebar showRemoteDocuments:@[[self fileNamed:@"verbale.md"]]
                                 from:@"appunti"];
    [self.sidebar setRootURL:self.folder];
    XCTAssertNil(self.sidebar.remotePlaceName);

    NSArray *rows = [self.sidebar childrenOfItem:nil];
    XCTAssertEqual(rows.count, 1u);
    XCTAssertEqualObjects([rows.firstObject name], @"vicino.md");
}


- (void)testGivingUpTheServiceListGoesBackToTheFolder
{
    [self.sidebar setRootURL:self.folder];
    [self.sidebar showRemoteDocuments:@[[self fileNamed:@"verbale.md"]]
                                 from:@"appunti"];
    XCTAssertEqual([[self.sidebar childrenOfItem:nil] count], 1u);
    XCTAssertEqualObjects([[self.sidebar childrenOfItem:nil].firstObject name],
                          @"verbale.md");

    [self.sidebar showRemoteDocuments:nil from:nil];
    XCTAssertNil(self.sidebar.remotePlaceName);
    // La cartella va ridata: l'elenco del servizio l'aveva messa via.
    [self.sidebar setRootURL:self.folder];
    XCTAssertEqualObjects([[self.sidebar childrenOfItem:nil].firstObject name],
                          @"vicino.md");
}

#pragma mark - La scheda degli allegati

- (void)testTheAttachmentsHaveATabOfTheirOwn
{
    NSURL *one = [self.folder URLByAppendingPathComponent:@"verbale.pdf"];
    NSURL *two = [self.folder URLByAppendingPathComponent:@"conti.csv"];
    [self.sidebar setMode:2];
    [self.sidebar showAttachments:@[one, two]];

    NSArray *rows = [self.sidebar childrenOfItem:nil];
    XCTAssertEqual(rows.count, 2u);
    XCTAssertEqualObjects([rows.firstObject lastPathComponent],
                          @"verbale.pdf");
    // Non è l'elenco dei file, che resta quello che era.
    [self.sidebar setMode:1];
    [self.sidebar setRootURL:self.folder];
    XCTAssertEqualObjects([[self.sidebar childrenOfItem:nil].firstObject name],
                          @"vicino.md");
}


/// Il tasto destro su un allegato offre le tre cose che si fanno con un
/// file, e la prima è tenerne una copia.
- (void)testTheRightClickMenuOffersToKeepACopy
{
    NSURL *one = [self.folder URLByAppendingPathComponent:@"verbale.pdf"];
    [@"%PDF-1.4\n" writeToURL:one atomically:YES
                      encoding:NSUTF8StringEncoding error:NULL];
    [self.sidebar setMode:2];
    [self.sidebar showAttachments:@[one]];
    (void)self.sidebar.view;
    [[self.sidebar outlineView] reloadData];

    NSMenu *menu = [self.sidebar menuForAttachmentAt:0];
    XCTAssertEqual(menu.numberOfItems, 3);
    XCTAssertEqualObjects([menu itemAtIndex:0].representedObject, one);
    for (NSMenuItem *item in menu.itemArray)
    {
        XCTAssertTrue(item.title.length > 0);
        XCTAssertNotNil(item.target);
    }
}


- (void)testThereIsNoMenuOnSomethingThatIsNotAnAttachment
{
    [self.sidebar setMode:1];
    [self.sidebar setRootURL:self.folder];
    (void)self.sidebar.view;
    [[self.sidebar outlineView] reloadData];
    XCTAssertNil([self.sidebar menuForAttachmentAt:0]);
}


@end
