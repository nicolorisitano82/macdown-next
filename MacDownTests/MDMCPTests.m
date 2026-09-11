//
//  MDMCPTests.m
//  MacDownTests
//
//  The server that hands a folder to an agent: what it answers, and what
//  it refuses.
//

#import <XCTest/XCTest.h>

#import "MDMCPDiary.h"
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


#pragma mark - Reading the folder

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


#pragma mark - The folder as a set of notes

/// Everything in this section needs notes that cite each other and declare
/// things, which the documents in setUp deliberately do not.
- (void)writeTheNotes
{
    NSString *verbale = @"---\n"
        @"title: Verbale di prova\n"
        @"tags: [iso, qualità]\n"
        @"stato: chiuso\n"
        @"---\n\n"
        @"# Verbale di prova\n\nIl testo.\n";
    [self write:verbale to:@"note/verbale.md"];

    NSString *indice = @"---\n"
        @"tags:\n  - iso\n"
        @"stato: aperto\n"
        @"---\n\n"
        @"# Indice\n\n"
        @"Vedi [[verbale]] e anche [il verbale](verbale.md).\n\n"
        @"Questo no: `[[verbale]]` sta dentro il codice.\n";
    [self write:indice to:@"note/indice.md"];

    [self write:@"# Nota\n\nCita [il verbale](../verbale.md) da sotto.\n"
             to:@"note/sotto/nota.md"];
}

- (void)testBacklinksSayWhoCitesADocument
{
    [self writeTheNotes];
    NSString *error = nil;
    NSDictionary *answer = [self.tools run:@"backlinks"
        arguments:@{@"path": @"note/verbale.md"} error:&error];
    XCTAssertNil(error);

    NSMutableSet<NSString *> *citing = [NSMutableSet set];
    for (NSDictionary *one in answer[@"citations"])
        [citing addObject:one[@"path"]];
    NSSet *expected = [NSSet setWithArray:@[@"note/indice.md",
                                            @"note/sotto/nota.md"]];
    // Both kinds count — a [[wiki link]] and a Markdown link — and a
    // destination written from a subfolder is the same file.
    XCTAssertEqualObjects(citing, expected);
    // The document does not cite itself, and what is inside backticks is
    // not a citation: three references, not four, and none from itself.
    XCTAssertEqualObjects(answer[@"found"], @3);
}

- (void)testAPathOutsideHasNoCitationsAndSaysWhy
{
    NSString *error = nil;
    XCTAssertNil([self.tools run:@"backlinks"
        arguments:@{@"path": @"/etc/hosts"} error:&error]);
    XCTAssertTrue([error containsString:@"outside"]);
}

- (void)testFrontMatterComesBackAsAMap
{
    [self writeTheNotes];
    NSString *error = nil;
    NSDictionary *answer = [self.tools run:@"frontmatter"
        arguments:@{@"path": @"note/verbale.md"} error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(answer[@"has"], @YES);
    XCTAssertEqualObjects(answer[@"fields"][@"stato"], @"chiuso");
    NSArray *tags = @[@"iso", @"qualità"];
    XCTAssertEqualObjects(answer[@"fields"][@"tags"], tags);
    // And it is JSON, whatever YAML handed over.
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:answer[@"fields"]]);
}

- (void)testADocumentWithoutFrontMatterSaysSoPlainly
{
    [self writeTheNotes];
    NSString *error = nil;
    NSDictionary *answer = [self.tools run:@"frontmatter"
        arguments:@{@"path": @"note/sotto/nota.md"} error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(answer[@"has"], @NO);
    XCTAssertEqual([answer[@"fields"] count], 0u);
}

- (void)testFindByFieldAnswersOnTheFieldAndOnItsValue
{
    [self writeTheNotes];
    NSString *error = nil;

    NSDictionary *declared = [self.tools run:@"find_by_field"
        arguments:@{@"field": @"stato"} error:&error];
    XCTAssertEqualObjects(declared[@"found"], @2);

    NSDictionary *open = [self.tools run:@"find_by_field"
        arguments:@{@"field": @"stato", @"value": @"APERTO"} error:&error];
    // Case is not the question: the person writing the note and the one
    // asking for it later are the same person on two different days.
    XCTAssertEqualObjects(open[@"found"], @1);
    XCTAssertEqualObjects(open[@"documents"][0][@"path"], @"note/indice.md");

    // A field holding a list answers when any of its items does.
    NSDictionary *tagged = [self.tools run:@"find_by_field"
        arguments:@{@"field": @"tags", @"value": @"iso"} error:&error];
    XCTAssertEqualObjects(tagged[@"found"], @2);

    NSDictionary *none = [self.tools run:@"find_by_field"
        arguments:@{@"field": @"relatore"} error:&error];
    XCTAssertEqualObjects(none[@"found"], @0);
}

- (void)testFindByFieldNeedsAField
{
    NSString *error = nil;
    XCTAssertNil([self.tools run:@"find_by_field" arguments:@{}
                            error:&error]);
    XCTAssertTrue([error containsString:@"field"]);
}

- (void)testADocumentInASubfolderKeepsItsFolder
{
    [self writeTheNotes];
    NSString *error = nil;
    NSDictionary *answer = [self.tools run:@"list" arguments:@{} error:&error];

    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    for (NSDictionary *one in answer[@"files"])
        [paths addObject:one[@"path"]];
    // The temporary folder lives under /private, which standardizing a path
    // takes off: for a while that made every answer about a document in a
    // subfolder come back as a bare file name.
    XCTAssertTrue([paths containsObject:@"note/sotto/nota.md"]);
}


#pragma mark - Changing a document

/// The tools for a server started at a level, over the same folder.
- (MDMCPTools *)toolsWriting:(MDMCPWriting)level
{
    MDMCPPerimeter *perimeter = [[MDMCPPerimeter alloc]
        initWithRoot:self.root];
    perimeter.writing = level;
    return [[MDMCPTools alloc] initWithPerimeter:perimeter];
}

- (NSString *)textOf:(NSString *)name
{
    return [NSString stringWithContentsOfURL:
        [self.root URLByAppendingPathComponent:name]
        encoding:NSUTF8StringEncoding error:NULL];
}

- (void)testAReadOnlyServerRefusesEveryChange
{
    NSString *error = nil;
    NSDictionary *arguments = @{@"path": @"verbale.md", @"text": @"altro"};
    XCTAssertNil([self.tools run:@"append" arguments:arguments error:&error]);
    XCTAssertTrue([error containsString:@"permission"]);
    XCTAssertNil([self.tools run:@"create" arguments:arguments error:&error]);
    NSDictionary *swap = @{@"path": @"verbale.md", @"find": @"firewall",
                           @"with": @"router"};
    XCTAssertNil([self.tools run:@"replace" arguments:swap error:&error]);
    // And the document is exactly as it was.
    XCTAssertTrue([[self textOf:@"verbale.md"] containsString:@"firewall"]);
}

- (void)testOnlyWhatTheLevelAllowsIsEvenOffered
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSDictionary *tool in [self.tools declarations])
        [names addObject:tool[@"name"]];
    XCTAssertFalse([names containsObject:@"append"]);

    [names removeAllObjects];
    for (NSDictionary *tool in [[self toolsWriting:MDMCPAppendOnly]
            declarations])
        [names addObject:tool[@"name"]];
    // An assistant is not offered something it would only be refused.
    XCTAssertTrue([names containsObject:@"append"]);
    XCTAssertFalse([names containsObject:@"create"]);
    XCTAssertFalse([names containsObject:@"replace"]);

    [names removeAllObjects];
    for (NSDictionary *tool in [[self toolsWriting:MDMCPFullWriting]
            declarations])
        [names addObject:tool[@"name"]];
    XCTAssertTrue([names containsObject:@"create"]);
    XCTAssertTrue([names containsObject:@"replace"]);
}

- (void)testAppendAddsTheLineEndingTheDocumentWasMissing
{
    [self write:@"Prima riga." to:@"coda.md"];       // no newline at the end
    MDMCPTools *tools = [self toolsWriting:MDMCPAppendOnly];
    NSString *error = nil;
    NSDictionary *first = [tools run:@"append"
        arguments:@{@"path": @"coda.md", @"text": @"Seconda."} error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(first[@"lines"], @2);
    NSDictionary *second = [tools run:@"append"
        arguments:@{@"path": @"coda.md", @"text": @"Terza."} error:&error];
    XCTAssertEqualObjects(second[@"lines"], @3);
    // Three lines, not one long one, and what was there is still there.
    XCTAssertEqualObjects([self textOf:@"coda.md"],
                          @"Prima riga.\nSeconda.\nTerza.\n");
}

- (void)testAppendNeedsADocumentThatIsThere
{
    NSString *error = nil;
    NSDictionary *missing = @{@"path": @"mai-esistito.md", @"text": @"x"};
    XCTAssertNil([[self toolsWriting:MDMCPAppendOnly] run:@"append"
        arguments:missing error:&error]);
    XCTAssertTrue([error containsString:@"nothing at that path"]);
}

- (void)testCreateMakesADocumentAndWritesOverNothing
{
    MDMCPTools *tools = [self toolsWriting:MDMCPFullWriting];
    NSString *error = nil;
    NSDictionary *made = [tools run:@"create"
        arguments:@{@"path": @"nuovo.md", @"text": @"# Nuovo"}
            error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(made[@"path"], @"nuovo.md");
    XCTAssertEqualObjects([self textOf:@"nuovo.md"], @"# Nuovo\n");

    NSDictionary *again = @{@"path": @"nuovo.md", @"text": @"altro"};
    XCTAssertNil([tools run:@"create" arguments:again error:&error]);
    XCTAssertTrue([error containsString:@"already"]);
    // Refused means untouched, not half written.
    XCTAssertEqualObjects([self textOf:@"nuovo.md"], @"# Nuovo\n");
}

- (void)testCreateMakesNoFoldersAndLeavesNothingBehind
{
    MDMCPTools *tools = [self toolsWriting:MDMCPFullWriting];
    NSString *error = nil;
    NSDictionary *deep = @{@"path": @"cartella-che-manca/nota.md",
                           @"text": @"x"};
    XCTAssertNil([tools run:@"create" arguments:deep error:&error]);
    XCTAssertTrue([error containsString:@"folder"]);
    NSURL *folder = [self.root
        URLByAppendingPathComponent:@"cartella-che-manca"];
    XCTAssertFalse([[NSFileManager defaultManager]
        fileExistsAtPath:folder.path]);

    NSDictionary *outside = @{@"path": @"../fuori.md", @"text": @"x"};
    XCTAssertNil([tools run:@"create" arguments:outside error:&error]);
    XCTAssertTrue([error containsString:@"outside"]);
    NSDictionary *binary = @{@"path": @"appunti.exe", @"text": @"x"};
    XCTAssertNil([tools run:@"create" arguments:binary error:&error]);
    XCTAssertTrue([error containsString:@"Markdown and text"]);
}

- (void)testReplaceSaysHowManyTimesAndWhere
{
    [self write:@"# Rete\n\nIl firewall.\nAncora il firewall.\n"
             to:@"rete.md"];
    MDMCPTools *tools = [self toolsWriting:MDMCPFullWriting];
    NSString *error = nil;
    NSDictionary *once = [tools run:@"replace"
        arguments:@{@"path": @"rete.md", @"find": @"firewall",
                    @"with": @"router", @"count": @1} error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(once[@"replaced"], @1);
    NSArray *lines = @[@3];
    XCTAssertEqualObjects(once[@"lines"], lines);

    NSDictionary *rest = [tools run:@"replace"
        arguments:@{@"path": @"rete.md", @"find": @"firewall",
                    @"with": @"router"} error:&error];
    XCTAssertEqualObjects(rest[@"replaced"], @1);
    XCTAssertEqualObjects([self textOf:@"rete.md"],
        @"# Rete\n\nIl router.\nAncora il router.\n");
}

- (void)testReplaceRefusesToGuess
{
    MDMCPTools *tools = [self toolsWriting:MDMCPFullWriting];
    NSString *before = [self textOf:@"verbale.md"];
    NSString *error = nil;
    NSDictionary *absent = @{@"path": @"verbale.md",
                             @"find": @"parola che non c'è", @"with": @"x"};
    XCTAssertNil([tools run:@"replace" arguments:absent error:&error]);
    XCTAssertTrue([error containsString:@"not in the document"]);
    XCTAssertEqualObjects([self textOf:@"verbale.md"], before);
}

- (void)testReplacingTextWithTextThatContainsItEnds
{
    [self write:@"uno uno uno\n" to:@"ripetuto.md"];
    NSString *error = nil;
    NSDictionary *answer = [[self toolsWriting:MDMCPFullWriting]
        run:@"replace" arguments:@{@"path": @"ripetuto.md", @"find": @"uno",
                                   @"with": @"uno e uno"} error:&error];
    XCTAssertEqualObjects(answer[@"replaced"], @3);
    XCTAssertEqualObjects([self textOf:@"ripetuto.md"],
                          @"uno e uno uno e uno uno e uno\n");
}


#pragma mark - The diary

- (void)testEveryCallIsWrittenDown
{
    NSURL *log = [self.root URLByAppendingPathComponent:@"prova.log"];
    MDMCPTools *tools = [self toolsWriting:MDMCPFullWriting];
    tools.diary = [[MDMCPDiary alloc] initWithFile:log];

    NSString *error = nil;
    [tools run:@"read" arguments:@{@"path": @"verbale.md"} error:&error];
    [tools run:@"create" arguments:@{@"path": @"nuovo.md", @"text": @"x"}
         error:&error];
    [tools run:@"read" arguments:@{@"path": @"/etc/hosts"} error:&error];

    NSString *written = [NSString stringWithContentsOfURL:log
        encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertTrue([written containsString:@"read"]);
    XCTAssertTrue([written containsString:@"create"]);
    XCTAssertTrue([written containsString:@"verbale.md"]);
    // Refusals too, with their reason: that is the half worth having the
    // day after.
    XCTAssertTrue([written containsString:@"refused"]);
    XCTAssertTrue([written containsString:@"outside"]);
}

- (void)testADiaryWithNoFileWritesNothing
{
    MDMCPTools *tools = [self toolsWriting:MDMCPFullWriting];
    tools.diary = [[MDMCPDiary alloc] initWithFile:nil];
    NSString *error = nil;
    XCTAssertNotNil([tools run:@"list" arguments:@{} error:&error]);
    XCTAssertNil(error);
}


#pragma mark - What a caller can send that is not what was meant

/// Everything in this section is a thing that took the whole server down,
/// or let it out of its folder, before it was written down here.

- (void)testAnArgumentOfTheWrongKindIsRefusedAndNothingFalls
{
    NSArray *wrong = @[
        @[@"read", @{@"path": @42}],
        @[@"read", @{@"path": [NSNull null]}],
        @[@"outline", @{@"path": @{@"a": @1}}],
        @[@"list", @{@"folder": @7}],
        @[@"backlinks", @{@"path": @[@"a"]}],
        @[@"frontmatter", @{@"path": @0.5}],
        @[@"find_by_field", @{@"field": @"tags", @"value": @3}],
    ];
    for (NSArray *one in wrong)
    {
        NSString *error = nil;
        XCTAssertNil([self.tools run:one[0] arguments:one[1] error:&error]);
        XCTAssertTrue([error containsString:@"has to be text"], @"%@", one[0]);
    }
    // And the tools still work afterwards, which is the whole point.
    NSString *error = nil;
    XCTAssertNotNil([self.tools run:@"list" arguments:@{} error:&error]);
}

- (void)testALineRangeThatCannotExistIsRefused
{
    NSString *error = nil;
    NSDictionary *backwards = @{@"path": @"verbale.md", @"from": @(-5),
                                @"lines": @(-3)};
    // -3 lines used to become eighteen quintillion, and the range built
    // from it took the server with it.
    XCTAssertNil([self.tools run:@"read" arguments:backwards error:&error]);
    XCTAssertTrue([error containsString:@"negative"]);

    NSDictionary *enormous = @{@"path": @"verbale.md",
                               @"lines": @(NSUIntegerMax)};
    NSDictionary *answer = [self.tools run:@"read" arguments:enormous
                                     error:&error];
    XCTAssertNotNil(answer);
    XCTAssertEqualObjects(answer[@"lines"], answer[@"of"]);
}

- (void)testParametersThatAreNotAMapAreAnErrorAndNotAFall
{
    MDMCPServer *server = [self server];
    NSDictionary *asList = @{@"jsonrpc": @"2.0", @"id": @1,
                             @"method": @"tools/call", @"params": @[@1, @2]};
    XCTAssertEqualObjects([server answerTo:asList][@"error"][@"code"],
                          @(-32602));
    NSDictionary *asText = @{@"jsonrpc": @"2.0", @"id": @2,
                             @"method": @"initialize", @"params": @"ciao"};
    // The handshake still answers: params nobody can read are no params.
    XCTAssertNotNil([server answerTo:asText][@"result"][@"serverInfo"]);
}

- (void)testABundleWhoseTextPointsOutsideIsOutside
{
    NSURL *bundle = [self.root URLByAppendingPathComponent:@"trappola.textbundle"];
    [[NSFileManager defaultManager] createDirectoryAtURL:bundle
        withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *info = @"{\"version\":2,\"type\":\"net.daringfireball.markdown\"}";
    [info writeToURL:[bundle URLByAppendingPathComponent:@"info.json"]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] createSymbolicLinkAtURL:
        [bundle URLByAppendingPathComponent:@"text.markdown"]
        withDestinationURL:[NSURL fileURLWithPath:@"/etc/hosts"] error:NULL];

    // The bundle is inside the folder; its text is not, and that is what
    // gets read. For a while this was a way out of the perimeter.
    XCTAssertEqual([self.perimeter verdictForPath:@"trappola.textbundle"],
                   MDMCPOutsideTheRoots);
    NSString *error = nil;
    XCTAssertNil([self.tools run:@"read"
        arguments:@{@"path": @"trappola.textbundle"} error:&error]);

    NSDictionary *found = [self.tools run:@"search"
        arguments:@{@"query": @"localhost"} error:&error];
    XCTAssertEqualObjects(found[@"found"], @0);
    for (NSDictionary *file in [self.tools run:@"list" arguments:@{}
                                          error:&error][@"files"])
    {
        XCTAssertFalse([file[@"path"] containsString:@"trappola"]);
    }
}

- (void)testAFolderLeftAloneIsLeftAloneWhenWritingToo
{
    self.perimeter.excluded = @[@"bozze*"];
    self.perimeter.writing = MDMCPFullWriting;
    NSURL *folder = [self.root URLByAppendingPathComponent:@"bozze"];
    [[NSFileManager defaultManager] createDirectoryAtURL:folder
        withIntermediateDirectories:YES attributes:nil error:NULL];

    NSString *error = nil;
    NSDictionary *inside = @{@"path": @"bozze/nuova.md", @"text": @"x"};
    XCTAssertNil([self.tools run:@"create" arguments:inside error:&error]);
    XCTAssertTrue([error containsString:@"leaves alone"]);
    // Otherwise the server writes a document into a folder it cannot then
    // read, search or list.
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:
        [folder URLByAppendingPathComponent:@"nuova.md"].path]);
}

- (void)testListingABundleAnswersTheDocumentAndItsSize
{
    NSURL *bundle = [self.root URLByAppendingPathComponent:@"buono.textbundle"];
    [[NSFileManager defaultManager] createDirectoryAtURL:bundle
        withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *info = @"{\"version\":2,\"type\":\"net.daringfireball.markdown\"}";
    [info writeToURL:[bundle URLByAppendingPathComponent:@"info.json"]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"# Dentro\n" writeToURL:
        [bundle URLByAppendingPathComponent:@"text.markdown"]
        atomically:YES encoding:NSUTF8StringEncoding error:NULL];

    NSString *error = nil;
    NSDictionary *answer = [self.tools run:@"list"
        arguments:@{@"folder": @"buono.textbundle"} error:&error];
    XCTAssertEqualObjects(answer[@"count"], @1);
    XCTAssertEqualObjects(answer[@"files"][0][@"path"], @"buono.textbundle");
    // The size of the text, not of the folder, which weighs nothing.
    XCTAssertEqualObjects(answer[@"files"][0][@"bytes"], @9);
}

- (void)testAPathCannotWriteALineIntoTheDiary
{
    NSURL *log = [self.root URLByAppendingPathComponent:@"finta.log"];
    self.tools.diary = [[MDMCPDiary alloc] initWithFile:log];
    NSString *error = nil;
    NSString *forged = @"vero.md\n2020-01-01T00:00:00Z  create  ok  FINTO";
    [self.tools run:@"read" arguments:@{@"path": forged} error:&error];

    NSString *written = [NSString stringWithContentsOfURL:log
        encoding:NSUTF8StringEncoding error:NULL];
    NSArray *lines = [[written stringByTrimmingCharactersInSet:
        [NSCharacterSet newlineCharacterSet]]
        componentsSeparatedByString:@"\n"];
    // One call, one line — whatever the caller put in the path.
    XCTAssertEqual(lines.count, 1u);
    XCTAssertTrue([written containsString:@"FINTO"]);
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
    NSArray *expected = @[@"search", @"read", @"list", @"outline",
                          @"backlinks", @"frontmatter", @"find_by_field"];
    XCTAssertEqualObjects(names, expected);
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
