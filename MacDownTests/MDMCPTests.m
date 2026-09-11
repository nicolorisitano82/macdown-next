//
//  MDMCPTests.m
//  MacDownTests
//
//  The server that hands a folder to an agent: what it answers, and what
//  it refuses.
//

#import <XCTest/XCTest.h>

#import "MDMCPIndex.h"
#import "MDMCPPerimeter.h"
#import "MDMCPServer.h"
#import "MDMCPTools.h"


@interface MDMCPTests : XCTestCase
@property (strong) NSURL *root;
@property (strong) MDMCPPerimeter *perimeter;
@property (strong) MDMCPTools *tools;
@end


@implementation MDMCPTests

- (void)setUp
{
    [super setUp];
    self.root = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [self write:@"# Verbale di agosto\n\nIl firewall è stato sostituito.\n"
             to:@"verbale.md"];
    [self write:@"# Note\n\n## Prima parte\n\n```\n# non un titolo\n```\n\n"
                @"## Seconda parte\n\nAltro sul firewall.\n" to:@"note.md"];
    [self write:@"niente" to:@"immagine.png"];
    [self write:@"segreti" to:@".git/config"];

    self.perimeter = [[MDMCPPerimeter alloc] initWithRoot:self.root];
    self.tools = [[MDMCPTools alloc] initWithPerimeter:self.perimeter];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.root error:NULL];
    [super tearDown];
}

- (NSURL *)write:(NSString *)text to:(NSString *)name
{
    NSURL *file = [self.root URLByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtURL:
        file.URLByDeletingLastPathComponent withIntermediateDirectories:YES
        attributes:nil error:NULL];
    [text writeToURL:file atomically:YES encoding:NSUTF8StringEncoding
               error:NULL];
    return file;
}


#pragma mark - The perimeter

- (void)testWhatIsInsideIsAllowed
{
    XCTAssertEqual([self.perimeter verdictForPath:@"verbale.md"],
                   MDMCPAllowed);
    XCTAssertEqual([self.perimeter verdictForPath:
        [self.root URLByAppendingPathComponent:@"note.md"].path],
        MDMCPAllowed);
}

- (void)testAPathThatClimbsOutIsRefused
{
    XCTAssertEqual([self.perimeter verdictForPath:@"../altrove.md"],
                   MDMCPOutsideTheRoots);
    XCTAssertEqual([self.perimeter verdictForPath:@"/etc/hosts"],
                   MDMCPOutsideTheRoots);
    XCTAssertEqual([self.perimeter verdictForPath:@"sotto/../../fuori.md"],
                   MDMCPOutsideTheRoots);
}

- (void)testALinkThatPointsOutIsAPathThatLeaves
{
    // However it is spelled: the link is resolved before it is compared.
    NSURL *link = [self.root URLByAppendingPathComponent:@"scorciatoia.md"];
    [[NSFileManager defaultManager] createSymbolicLinkAtURL:link
        withDestinationURL:[NSURL fileURLWithPath:@"/etc/hosts"] error:NULL];
    XCTAssertEqual([self.perimeter verdictForPath:@"scorciatoia.md"],
                   MDMCPOutsideTheRoots);
}

- (void)testOnlyTextAndOnlyUpToASize
{
    XCTAssertEqual([self.perimeter verdictForPath:@"immagine.png"],
                   MDMCPNotText);
    XCTAssertEqual([self.perimeter verdictForPath:@"manca.md"],
                   MDMCPNotThere);

    self.perimeter.sizeLimit = 8;
    XCTAssertEqual([self.perimeter verdictForPath:@"verbale.md"],
                   MDMCPTooBig);
}

- (void)testTheFoldersNobodyMeantAreLeftAlone
{
    XCTAssertEqual([self.perimeter verdictForPath:@".git/config"],
                   MDMCPExcluded);

    [self write:@"# Bozza\n" to:@"bozze/una.md"];
    self.perimeter.excluded = @[@"bozze*"];
    XCTAssertEqual([self.perimeter verdictForPath:@"bozze/una.md"],
                   MDMCPExcluded);
}

- (void)testEveryRefusalSaysWhy
{
    for (MDMCPVerdict v = MDMCPAllowed; v <= MDMCPNotThere; v++)
        XCTAssertGreaterThan([MDMCPPerimeter reasonFor:v].length, 3u);
}


#pragma mark - A textbundle is one document

- (void)testABundleIsOneDocumentAndNotThree
{
    NSURL *bundle = [self.root URLByAppendingPathComponent:@"conto.textbundle"];
    [self write:@"{\"version\":2}" to:@"conto.textbundle/info.json"];
    [self write:@"# Conto\n\nUna riga sul firewall.\n"
             to:@"conto.textbundle/text.markdown"];
    [self write:@"x" to:@"conto.textbundle/assets/rete.png"];

    NSArray<NSURL *> *documents = [self.perimeter filesUnder:nil];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSURL *url in documents)
        [names addObject:url.lastPathComponent];
    XCTAssertTrue([names containsObject:@"conto.textbundle"], @"%@", names);
    XCTAssertFalse([names containsObject:@"info.json"]);
    XCTAssertFalse([names containsObject:@"text.markdown"]);

    XCTAssertEqualObjects([MDMCPPerimeter textFileFor:bundle].lastPathComponent,
                          @"text.markdown");

    // And reading it reads the text inside it.
    NSString *refusal = nil;
    NSDictionary *answer = [self.tools run:@"read"
        arguments:@{@"path": @"conto.textbundle"} error:&refusal];
    XCTAssertNil(refusal);
    XCTAssertTrue([answer[@"text"] containsString:@"Una riga sul firewall"]);
}


#pragma mark - The four tools

- (void)testSearchSaysWhereAndWhat
{
    NSString *refusal = nil;
    NSDictionary *answer = [self.tools run:@"search"
        arguments:@{@"query": @"firewall"} error:&refusal];
    XCTAssertNil(refusal);
    XCTAssertEqualObjects(answer[@"found"], @2);
    NSArray *hits = answer[@"hits"];
    XCTAssertEqualObjects(hits[0][@"path"], @"note.md");
    XCTAssertEqualObjects(hits[0][@"line"], @11);
    XCTAssertTrue([hits[0][@"text"] containsString:@"firewall"]);
    // Paths are relative to the root: nothing says where this Mac keeps
    // its home folder.
    XCTAssertFalse([hits[0][@"path"] hasPrefix:@"/"]);
}

- (void)testSearchStopsWhereItIsTold
{
    NSDictionary *answer = [self.tools run:@"search"
        arguments:@{@"query": @"firewall", @"limit": @1} error:NULL];
    XCTAssertEqualObjects(answer[@"found"], @1);
    XCTAssertEqualObjects(answer[@"cut"], @YES);
}

- (void)testReadTakesTheLinesItIsAskedFor
{
    NSDictionary *answer = [self.tools run:@"read"
        arguments:@{@"path": @"verbale.md", @"from": @3, @"lines": @1}
            error:NULL];
    XCTAssertEqualObjects(answer[@"text"],
                          @"Il firewall è stato sostituito.");
    XCTAssertEqualObjects(answer[@"of"], @3);
    XCTAssertEqualObjects(answer[@"cut"], @YES);
}

- (void)testListCountsDocumentsAndNothingElse
{
    NSDictionary *answer = [self.tools run:@"list" arguments:@{} error:NULL];
    XCTAssertEqualObjects(answer[@"count"], @2);   // .png and .git are out
}

- (void)testOutlineIsTheShapeOfTheDocument
{
    NSDictionary *answer = [self.tools run:@"outline"
        arguments:@{@"path": @"note.md"} error:NULL];
    NSArray *headings = answer[@"headings"];
    XCTAssertEqual(headings.count, 3u);
    XCTAssertEqualObjects(headings[0][@"title"], @"Note");
    XCTAssertEqualObjects(headings[1][@"level"], @2);
    XCTAssertEqualObjects(headings[2][@"title"], @"Seconda parte");
}

- (void)testWhatIsInAFenceIsNotATitle
{
    NSArray *headings = MDMCPOutlineOfMarkdown(
        @"# Vero\n\n```\n# finto\n```\n\n#nonuntitolo\n\n## Vero anche\n");
    XCTAssertEqual(headings.count, 2u);
    XCTAssertEqualObjects(headings[0][@"title"], @"Vero");
    XCTAssertEqualObjects(headings[1][@"title"], @"Vero anche");
}

- (void)testAToolThatDoesNotExistSaysSo
{
    NSString *refusal = nil;
    XCTAssertNil([self.tools run:@"delete" arguments:@{} error:&refusal]);
    XCTAssertTrue([refusal containsString:@"delete"]);
}


#pragma mark - The index

- (void)testTheSecondQuestionReadsNothing
{
    MDMCPIndex *index = [[MDMCPIndex alloc] initWithPerimeter:self.perimeter];
    [index search:@"firewall" limit:10 cut:NULL];
    XCTAssertEqual(index.documentCount, 2u);
    XCTAssertEqual(index.lastReadCount, 2u);

    [index search:@"agosto" limit:10 cut:NULL];
    // Nothing has changed on disk, so nothing is read again.
    XCTAssertEqual(index.lastReadCount, 0u);
}

- (void)testAChangedFileIsReadAgain
{
    MDMCPIndex *index = [[MDMCPIndex alloc] initWithPerimeter:self.perimeter];
    [index search:@"firewall" limit:10 cut:NULL];

    // A file rewritten by somebody else while the server is up.
    [NSThread sleepForTimeInterval:1.1];   // the file system counts seconds
    [self write:@"# Verbale\n\nAdesso parla di un router.\n" to:@"verbale.md"];

    NSArray<MDMCPHit *> *hits = [index search:@"router" limit:10 cut:NULL];
    XCTAssertEqual(index.lastReadCount, 1u);
    XCTAssertEqual(hits.count, 1u);
    XCTAssertEqualObjects(hits[0].text, @"Adesso parla di un router.");
}

- (void)testADeletedFileIsForgotten
{
    MDMCPIndex *index = [[MDMCPIndex alloc] initWithPerimeter:self.perimeter];
    [index search:@"firewall" limit:10 cut:NULL];
    XCTAssertEqual(index.documentCount, 2u);

    [[NSFileManager defaultManager] removeItemAtURL:
        [self.root URLByAppendingPathComponent:@"note.md"] error:NULL];
    NSArray<MDMCPHit *> *hits = [index search:@"firewall" limit:10 cut:NULL];
    XCTAssertEqual(index.documentCount, 1u);
    XCTAssertEqual(hits.count, 1u);
}


#pragma mark - The envelope

- (MDMCPServer *)server
{
    return [[MDMCPServer alloc] initWithTools:self.tools];
}

- (void)testTheHandshakeAnswersInTheClientsVersion
{
    NSDictionary *answer = [[self server] answerTo:@{
        @"jsonrpc": @"2.0", @"id": @1, @"method": @"initialize",
        @"params": @{@"protocolVersion": @"2024-11-05"}}];
    XCTAssertEqualObjects(answer[@"result"][@"protocolVersion"],
                          @"2024-11-05");
    XCTAssertNotNil(answer[@"result"][@"capabilities"][@"tools"]);

    // And in ours when the client asks for something nobody knows.
    NSDictionary *other = [[self server] answerTo:@{
        @"jsonrpc": @"2.0", @"id": @1, @"method": @"initialize",
        @"params": @{@"protocolVersion": @"1999-01-01"}}];
    XCTAssertEqualObjects(other[@"result"][@"protocolVersion"],
                          MDMCPProtocolVersion);
}

- (void)testANotificationGetsNoAnswer
{
    NSDictionary *notification = @{@"jsonrpc": @"2.0",
                                   @"method": @"notifications/initialized"};
    XCTAssertNil([[self server] answerTo:notification]);
}

- (void)testTheToolsAreDeclared
{
    NSDictionary *answer = [[self server] answerTo:@{
        @"jsonrpc": @"2.0", @"id": @2, @"method": @"tools/list"}];
    NSArray *tools = answer[@"result"][@"tools"];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSDictionary *tool in tools)
    {
        [names addObject:tool[@"name"]];
        // A tool nobody can call is a tool nobody declared properly.
        XCTAssertNotNil(tool[@"description"]);
        XCTAssertEqualObjects(tool[@"inputSchema"][@"type"], @"object");
    }
    XCTAssertEqualObjects(names, (@[@"search", @"read", @"list", @"outline"]));
}

- (void)testACallComesBackAsTextAndAsStructure
{
    NSDictionary *answer = [[self server] answerTo:@{
        @"jsonrpc": @"2.0", @"id": @3, @"method": @"tools/call",
        @"params": @{@"name": @"outline",
                     @"arguments": @{@"path": @"note.md"}}}];
    NSDictionary *result = answer[@"result"];
    XCTAssertNil(result[@"isError"]);
    XCTAssertEqualObjects(result[@"content"][0][@"type"], @"text");
    XCTAssertEqualObjects(result[@"structuredContent"][@"count"], @3);
}

- (void)testARefusalIsAnAnswerAndNotAProtocolError
{
    NSDictionary *answer = [[self server] answerTo:@{
        @"jsonrpc": @"2.0", @"id": @4, @"method": @"tools/call",
        @"params": @{@"name": @"read",
                     @"arguments": @{@"path": @"/etc/hosts"}}}];
    // Inside the result, so a model can read the reason and try something
    // else — a protocol error would just be a broken call.
    XCTAssertNil(answer[@"error"]);
    XCTAssertEqualObjects(answer[@"result"][@"isError"], @YES);
    XCTAssertTrue([answer[@"result"][@"content"][0][@"text"]
        containsString:@"outside"]);
}

- (void)testAMethodNobodyHasIsAProtocolError
{
    NSDictionary *answer = [[self server] answerTo:@{
        @"jsonrpc": @"2.0", @"id": @5, @"method": @"resources/list"}];
    XCTAssertEqualObjects(answer[@"error"][@"code"], @(-32601));
}

@end
