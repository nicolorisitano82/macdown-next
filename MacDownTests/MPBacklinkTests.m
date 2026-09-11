//
//  MPBacklinkTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "MPBacklinks.h"


@interface MPBacklinkTests : XCTestCase
@property (strong) NSURL *folder;
@end


@implementation MPBacklinkTests

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

- (NSURL *)write:(NSString *)text to:(NSString *)name
{
    NSURL *url = [self.folder URLByAppendingPathComponent:name];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:url.URLByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:NULL];
    [text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding
               error:NULL];
    return url;
}

/// The lines the citations sit on, which is what the list shows.
- (NSArray *)linesOf:(NSArray<MPBacklink *> *)found
{
    NSMutableArray *lines = [NSMutableArray array];
    for (MPBacklink *link in found)
        [lines addObject:@(link.line)];
    return lines;
}


#pragma mark - What counts as a citation

- (void)testBothKindsOfLinkCount
{
    NSURL *target = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    NSURL *from = [self.folder URLByAppendingPathComponent:@"piano.md"];

    NSString *text =
        @"# Piano di test\n"                       // 1
        @"\n"                                      // 2
        @"Vedi [[verbale]] per il collaudo.\n"     // 3
        @"E anche [[verbale|il verbale]].\n"       // 4
        @"Oppure [il verbale](verbale.md).\n"      // 5
        @"O [così](./verbale.md).\n";              // 6

    NSArray *found = MPBacklinksInText(text, from, target);
    XCTAssertEqualObjects([self linesOf:found], (@[@3, @4, @5, @6]));

    // The title of the citing document, for the row, and the line as
    // written, which is what tells two citations apart.
    XCTAssertEqualObjects([found.firstObject title], @"Piano di test");
    XCTAssertEqualObjects([found.firstObject context],
                          @"Vedi [[verbale]] per il collaudo.");
    XCTAssertEqualObjects([found.firstObject documentURL], from);
}

- (void)testTheSameFileWrittenSeveralWays
{
    NSURL *target = [self.folder
        URLByAppendingPathComponent:@"verbale di collaudo.md"];
    NSURL *from = [self.folder
        URLByAppendingPathComponent:@"sotto/piano.md"];

    NSString *text =
        @"[a](../verbale%20di%20collaudo.md)\n"    // 1: escaped
        @"[b](<../verbale di collaudo.md>)\n"      // 2: in angle brackets
        @"[c](../verbale di collaudo.md \"titolo\")\n"  // 3: with a title
        @"[d](../verbale%20di%20collaudo.md#collaudo)\n"  // 4: an anchor
        @"[e](../sotto/../verbale%20di%20collaudo.md)\n"; // 5: the long way
    XCTAssertEqualObjects([self linesOf:MPBacklinksInText(text, from, target)],
                          (@[@1, @2, @3, @4, @5]));
}

- (void)testWhatIsNotACitation
{
    NSURL *target = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    NSURL *from = [self.folder URLByAppendingPathComponent:@"altro.md"];

    NSString *text =
        @"Un altro file: [x](verbale-2.md) e [y](verbali/verbale.md).\n"
        @"Un indirizzo: [z](https://esempio.it/verbale.md).\n"
        @"Una mail: [w](mailto:verbale.md).\n"
        @"In linea: `[[verbale]]` non è un collegamento.\n"
        @"\n"
        @"```markdown\n"
        @"Nel recinto [[verbale]] è testo, non un collegamento.\n"
        @"[q](verbale.md)\n"
        @"```\n";
    XCTAssertEqualObjects(MPBacklinksInText(text, from, target), @[]);
}

- (void)testADocumentDoesNotCiteItself
{
    NSURL *target = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    NSString *text = @"# Verbale\n\nRimando a [[verbale]] per abitudine.\n";
    XCTAssertEqualObjects(MPBacklinksInText(text, target, target), @[]);
}

- (void)testTheWikiLinkExtensionsMacDownItselfTries
{
    NSString *text = @"vedi [[appunti]]\n";
    NSURL *from = [self.folder URLByAppendingPathComponent:@"x.md"];

    for (NSString *name in @[@"appunti.md", @"appunti.markdown",
                             @"appunti.txt", @"appunti"])
    {
        NSURL *target = [self.folder URLByAppendingPathComponent:name];
        XCTAssertEqual(MPBacklinksInText(text, from, target).count, 1u,
                       @"«%@» non è stato riconosciuto", name);
    }
    // And not a file that merely starts the same way.
    NSURL *other = [self.folder
        URLByAppendingPathComponent:@"appunti-vecchi.md"];
    XCTAssertEqualObjects(MPBacklinksInText(text, from, other), @[]);
}

- (void)testADocumentThatExplainsFencesIsNotAllCode
{
    // Four backticks quoting three is how a document about Markdown shows a
    // fence it does not mean. Taken for a fence it opened a code block that
    // never closed, and every citation after that line stopped counting —
    // found while writing the comparison by paragraph, which was cut into
    // lines by the same mistake.
    NSString *text = @"# Note\n\n"
        @"Un recinto ````` ```mermaid ````` si scrive con quattro apici.\n\n"
        @"E questo cita [[verbale]] dopo di esso.\n";
    NSURL *from = [self.folder URLByAppendingPathComponent:@"note.md"];
    NSURL *target = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    NSArray<MPBacklink *> *found = MPBacklinksInText(text, from, target);
    XCTAssertEqual(found.count, 1u);
}

- (void)testTheFirstHeadingIsTheTitle
{
    XCTAssertEqualObjects(MPFirstHeadingOfText(@"## Collaudo\ntesto"),
                          @"Collaudo");
    XCTAssertEqualObjects(MPFirstHeadingOfText(@"testo\n\n# Titolo\n"),
                          @"Titolo");
    XCTAssertEqualObjects(MPFirstHeadingOfText(@"# Chiuso #\n"), @"Chiuso");
    XCTAssertNil(MPFirstHeadingOfText(@"solo testo\n#senzaspazio\n"));
}


#pragma mark - Looking through the folder

- (void)testTheFolderIsReadAndTheAnswerIsOrdered
{
    NSURL *target = [self write:@"# Verbale\n" to:@"verbale.md"];
    [self write:@"# Piano\n\n[[verbale]]\n\ne di nuovo [x](verbale.md)\n"
             to:@"piano.md"];
    [self write:@"# Note\n\nvedi [v](../verbale.md)\n" to:@"sotto/note.md"];
    [self write:@"niente qui\n" to:@"altro.md"];
    [self write:@"[[verbale]]\n" to:@"immagine.png"];   // not a document

    XCTestExpectation *done = [self expectationWithDescription:@"cercato"];
    __block NSArray<MPBacklink *> *found = nil;
    __block NSUInteger read = 0;
    [MPBacklinkFinder findLinksTo:target inFolder:self.folder
                       completion:^(NSArray<MPBacklink *> *links,
                                    NSUInteger documents) {
        found = links;
        read = documents;
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:10.0];

    XCTAssertEqual(found.count, 3u);
    // By document name, then by line: piano twice, then note.
    XCTAssertEqualObjects([found[0] documentURL].lastPathComponent,
                          @"note.md");
    XCTAssertEqualObjects([found[1] documentURL].lastPathComponent,
                          @"piano.md");
    XCTAssertEqual([found[1] line], 3u);
    XCTAssertEqual([found[2] line], 5u);

    // Four documents read: the three above and the target itself, which
    // was read and found to cite nothing. The PNG was not.
    XCTAssertEqual(read, 4u);
}

- (void)testAnUnsavedDocumentHasNowhereToLook
{
    XCTestExpectation *done = [self expectationWithDescription:@"risposto"];
    [MPBacklinkFinder findLinksTo:[NSURL URLWithString:@"https://esempio.it"]
                         inFolder:self.folder
                       completion:^(NSArray<MPBacklink *> *links,
                                    NSUInteger documents) {
        XCTAssertEqualObjects(links, @[]);
        XCTAssertEqual(documents, 0u);
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:10.0];
}

@end
