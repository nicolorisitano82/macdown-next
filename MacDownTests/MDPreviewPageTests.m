//
//  MDPreviewPageTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "MDPreviewPage.h"


@interface MDPreviewPageTests : XCTestCase
@property (strong) NSURL *folder;
@property (strong) NSURL *document;
@end


@implementation MDPreviewPageTests

- (void)setUp
{
    [super setUp];
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
    self.document = [self.folder URLByAppendingPathComponent:@"verbale.md"];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}

- (MDPreviewPage *)pageFor:(NSString *)body
{
    return [MDPreviewPage pageForBody:body title:@"Verbale"
                           styleSheet:@"body { color: black; }"
                           documentAt:self.document];
}

- (NSURL *)writePictureOfBytes:(NSUInteger)bytes named:(NSString *)name
{
    NSURL *file = [self.folder URLByAppendingPathComponent:name];
    [[NSMutableData dataWithLength:bytes] writeToURL:file atomically:YES];
    return file;
}


#pragma mark - What the document is called

- (void)testTheFirstHeadingIsTheTitle
{
    XCTAssertEqualObjects(
        MDPreviewTitleForMarkdown(@"# Piano di test\n\ntesto\n", self.document),
        @"Piano di test");
    // Closed headings, and headings deeper than the first level.
    XCTAssertEqualObjects(
        MDPreviewTitleForMarkdown(@"### Riunione ###\n", self.document),
        @"Riunione");
}

- (void)testFrontMatterIsSteppedOver
{
    NSString *markdown = @"---\ntitle: altro\nsource: https://esempio.it\n"
                          @"---\n\n# Ritaglio\n\ntesto\n";
    XCTAssertEqualObjects(MDPreviewTitleForMarkdown(markdown, self.document),
                          @"Ritaglio");
}

- (void)testAHeadingUnderlinedInsteadOfHashed
{
    XCTAssertEqualObjects(
        MDPreviewTitleForMarkdown(@"Relazione annuale\n=====\n\ntesto\n",
                                  self.document),
        @"Relazione annuale");
}

- (void)testTheFileNameWhenTheDocumentHasNoTitleOfItsOwn
{
    // Prose first, a hash that is a word, and nothing at all.
    XCTAssertEqualObjects(
        MDPreviewTitleForMarkdown(@"Comincia senza titolo.\n", self.document),
        @"verbale");
    XCTAssertEqualObjects(
        MDPreviewTitleForMarkdown(@"#riunione è un'etichetta\n", self.document),
        @"verbale");
    XCTAssertEqualObjects(MDPreviewTitleForMarkdown(@"", self.document),
                          @"verbale");
}


#pragma mark - Front matter

- (void)testFrontMatterIsLeftOutOfTheDocument
{
    NSString *markdown = @"---\ntitle: Ritaglio\nsource: https://esempio.it\n"
                          @"---\n\n# Ritaglio\n\nIl testo vero.\n";
    NSString *body = MDMarkdownWithoutFrontMatter(markdown);
    XCTAssertFalse([body containsString:@"source:"]);
    XCTAssertTrue([body hasPrefix:@"\n# Ritaglio"]);
}

- (void)testFrontMatterClosedWithDotsAsYAMLAllows
{
    NSString *body = MDMarkdownWithoutFrontMatter(
        @"---\ntitle: x\n...\n\n# Vero\n");
    XCTAssertTrue([body containsString:@"# Vero"]);
    XCTAssertFalse([body containsString:@"title:"]);
}

- (void)testAnOpeningRuleThatIsNotFrontMatterIsKept
{
    // A document that opens with a horizontal rule and closes a section with
    // another one: taking the first for front matter would eat its title.
    NSString *rules = @"---\n\n# Titolo\n\n---\n\ntesto\n";
    XCTAssertEqualObjects(MDMarkdownWithoutFrontMatter(rules), rules);
    // Front matter that is never closed is not front matter either.
    XCTAssertEqualObjects(MDMarkdownWithoutFrontMatter(@"---\ntitle: x\n"),
                          @"---\ntitle: x\n");
    // And the title is still read from the document, not from the rule.
    XCTAssertEqualObjects(
        MDPreviewTitleForMarkdown(rules,
            [NSURL fileURLWithPath:@"/tmp/verbale.md"]), @"Titolo");
}

- (void)testADocumentWithNoFrontMatterIsUntouched
{
    XCTAssertEqualObjects(MDMarkdownWithoutFrontMatter(@"# Titolo\n\ntesto\n"),
                          @"# Titolo\n\ntesto\n");
}


#pragma mark - The page itself

- (void)testThePageCarriesItsStyleAndItsBody
{
    MDPreviewPage *page = [self pageFor:@"<h1>Ciao</h1>"];
    XCTAssertTrue([page.html hasPrefix:@"<!DOCTYPE html>"]);
    XCTAssertTrue([page.html containsString:@"<title>Verbale</title>"]);
    XCTAssertTrue([page.html containsString:@"body { color: black; }"]);
    XCTAssertTrue([page.html containsString:@"<h1>Ciao</h1>"]);
    // The styles are written for a light preview, so the page asks for one.
    XCTAssertTrue([page.html containsString:@"color-scheme: light"]);
}

- (void)testThePageIsNotAllowedToReachTheNetwork
{
    MDPreviewPage *page = [self pageFor:
        @"<p><img src=\"https://esempio.it/tracciante.png\"></p>"];
    XCTAssertTrue([page.html containsString:@"Content-Security-Policy"]);
    XCTAssertTrue([page.html containsString:@"default-src 'none'"]);
    // A picture somewhere else stays as written: it simply will not load.
    XCTAssertTrue([page.html
        containsString:@"https://esempio.it/tracciante.png"]);
    XCTAssertEqual(page.pictures.count, 0u);
}

- (void)testATitleWithMarkupInItIsNotMarkup
{
    MDPreviewPage *page = [MDPreviewPage pageForBody:@"<p>x</p>"
        title:@"<script>rubare()</script> & co" styleSheet:nil
        documentAt:self.document];
    XCTAssertFalse([page.html containsString:@"<script>"]);
    XCTAssertTrue([page.html containsString:@"&lt;script&gt;"]);
    XCTAssertTrue([page.html containsString:@"&amp; co"]);
}


#pragma mark - Things to do

- (void)testTaskListsBecomeBoxes
{
    MDPreviewPage *page = [self pageFor:
        @"<ul>\n<li>[ ] fare la spesa</li>\n<li>[x] pagare la bolletta</li>\n"
        @"<li>fatto e basta</li>\n</ul>"];
    XCTAssertTrue([page.html containsString:
        @"<li class=\"task\"><input type=\"checkbox\" disabled> fare la spesa"]);
    XCTAssertTrue([page.html containsString:
        @"<input type=\"checkbox\" disabled checked> pagare la bolletta"]);
    // An ordinary item is left as it is.
    XCTAssertTrue([page.html containsString:@"<li>fatto e basta</li>"]);
    XCTAssertFalse([page.html containsString:@"[ ]"]);
}

- (void)testTaskListsInAListWithParagraphs
{
    MDPreviewPage *page = [self pageFor:@"<ul>\n<li><p>[X] fatto</p></li>\n</ul>"];
    XCTAssertTrue([page.html containsString:
        @"<li class=\"task\"><p><input type=\"checkbox\" disabled checked> fatto"]);
}


#pragma mark - Pictures

- (void)testAPictureBesideTheDocumentTravelsWithThePage
{
    NSURL *file = [self writePictureOfBytes:64 named:@"rete.png"];
    MDPreviewPage *page = [self pageFor:@"<p><img src=\"rete.png\" alt=\"r\"></p>"];

    XCTAssertTrue([page.html containsString:@"src=\"cid:pict0\""]);
    XCTAssertEqualObjects(page.pictures[@"pict0"].path,
                          file.URLByStandardizingPath.path);
}

- (void)testPicturesAreNamedInTheOrderTheyAreRead
{
    [self writePictureOfBytes:64 named:@"prima.png"];
    [self writePictureOfBytes:64 named:@"seconda.png"];
    MDPreviewPage *page = [self pageFor:
        @"<p><img src=\"prima.png\"></p><p><img src=\"seconda.png\"></p>"];

    XCTAssertEqualObjects(page.pictures[@"pict0"].lastPathComponent,
                          @"prima.png");
    XCTAssertEqualObjects(page.pictures[@"pict1"].lastPathComponent,
                          @"seconda.png");
    NSRange first = [page.html rangeOfString:@"cid:pict0"];
    NSRange second = [page.html rangeOfString:@"cid:pict1"];
    XCTAssertLessThan(first.location, second.location);
}

- (void)testAPictureWithASpaceInItsName
{
    [self writePictureOfBytes:64 named:@"rete interna.png"];
    MDPreviewPage *page =
        [self pageFor:@"<p><img src=\"rete%20interna.png\"></p>"];
    XCTAssertEqualObjects(page.pictures[@"pict0"].lastPathComponent,
                          @"rete interna.png");
}

- (void)testAPictureThatIsNotThereIsLeftAlone
{
    MDPreviewPage *page = [self pageFor:@"<p><img src=\"mancante.png\"></p>"];
    XCTAssertEqual(page.pictures.count, 0u);
    XCTAssertTrue([page.html containsString:@"src=\"mancante.png\""]);
}

- (void)testAPictureTooBigToGlanceAtIsLeftBehind
{
    [self writePictureOfBytes:9 * 1024 * 1024 named:@"enorme.png"];
    MDPreviewPage *page = [self pageFor:@"<p><img src=\"enorme.png\"></p>"];
    XCTAssertEqual(page.pictures.count, 0u);
}

#pragma mark - WikiLinks

- (NSString *)wikiLinksIn:(NSString *)body
{
    return MDBodyWithWikiLinks(body, self.document);
}

- (void)testAWikiLinkToAFileBesideTheDocumentIsALink
{
    [self writePictureOfBytes:10 named:@"Appunti.md"];
    NSString *out = [self wikiLinksIn:@"<p>vedi [[Appunti]] per il resto</p>"];
    XCTAssertEqualObjects(out,
        @"<p>vedi <a href=\"Appunti\" class=\"wikilink\">Appunti</a>"
        @" per il resto</p>");
}

- (void)testAWikiLinkToNothingIsMarkedAsMissing
{
    NSString *out = [self wikiLinksIn:@"<p>[[Non c'è]]</p>"];
    XCTAssertTrue([out containsString:@"wikilink wikilink-missing"]);
    XCTAssertTrue([out containsString:@"title=\""]);
    // The label is what the document wrote, whether the page exists or not.
    XCTAssertTrue([out containsString:@">Non c'è</a>"]);
}

- (void)testALabelledWikiLinkKeepsItsLabel
{
    [self writePictureOfBytes:10 named:@"Appunti.md"];
    NSString *out = [self wikiLinksIn:@"<p>[[Appunti|gli appunti]]</p>"];
    XCTAssertEqualObjects(out,
        @"<p><a href=\"Appunti\" class=\"wikilink\">gli appunti</a></p>");
}

- (void)testTheTargetIsTriedWithTheUsualExtensions
{
    [self writePictureOfBytes:10 named:@"Note.markdown"];
    [self writePictureOfBytes:10 named:@"Testo.txt"];
    [self writePictureOfBytes:10 named:@"Esatto"];
    for (NSString *name in @[@"Note", @"Testo", @"Esatto"])
    {
        NSString *out = [self wikiLinksIn:[NSString stringWithFormat:
            @"<p>[[%@]]</p>", name]];
        XCTAssertFalse([out containsString:@"wikilink-missing"], @"%@", name);
    }
}

- (void)testAWikiLinkInsideCodeStaysCode
{
    [self writePictureOfBytes:10 named:@"Appunti.md"];
    NSString *fence = @"<pre><code>[[Appunti]]</code></pre>";
    XCTAssertEqualObjects([self wikiLinksIn:fence], fence);
    NSString *span = @"<p>si scrive <code>[[Appunti]]</code></p>";
    XCTAssertEqualObjects([self wikiLinksIn:span], span);
}

- (void)testASpaceInTheTargetIsEncodedInTheAddress
{
    [self writePictureOfBytes:10 named:@"Verbale di prova.md"];
    NSString *out = [self wikiLinksIn:@"<p>[[Verbale di prova]]</p>"];
    XCTAssertTrue([out containsString:@"href=\"Verbale%20di%20prova\""]);
    XCTAssertTrue([out containsString:@">Verbale di prova</a>"]);
    XCTAssertFalse([out containsString:@"wikilink-missing"]);
}

- (void)testADocumentWithoutWikiLinksIsLeftAlone
{
    NSString *body = @"<p>niente parentesi qui</p>";
    XCTAssertEqualObjects([self wikiLinksIn:body], body);
}

- (void)testEmptyBracketsAreNotALink
{
    NSString *body = @"<p>[[]] e [[ ]]</p>";
    XCTAssertEqualObjects([self wikiLinksIn:body], body);
}

@end
