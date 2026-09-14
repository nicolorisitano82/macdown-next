//
//  MPAttachmentsTests.m
//  MacDownTests
//
//  Allegare un file a un documento Markdown: dove va, come viene scritto
//  nel testo, e quali file un documento si porta dietro quando esce da
//  qui — che è la parte che si dimentica.
//

#import <XCTest/XCTest.h>

#import "MPAttachments.h"
#import "MPTextBundle.h"


@interface MPAttachmentsTests : XCTestCase
@property (strong) NSURL *folder;
@end


@implementation MPAttachmentsTests

- (void)setUp
{
    [super setUp];
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"allegati-%@",
            [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}

- (NSURL *)fileNamed:(NSString *)name saying:(NSString *)text
{
    NSURL *url = [self.folder URLByAppendingPathComponent:name];
    [text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding
               error:NULL];
    return url;
}


#pragma mark - Dove finisce

- (void)testADocumentKeepsItsAttachmentsBesideIt
{
    NSURL *document = [self.folder URLByAppendingPathComponent:@"verbale.md"];
    XCTAssertEqualObjects(MPAttachmentsFolderNameFor(document),
                          @"verbale.assets");
    XCTAssertEqualObjects(MPAttachmentsFolderFor(document).lastPathComponent,
                          @"verbale.assets");
}

- (void)testATextbundleKeepsThemWhereTheFormatSays
{
    NSURL *bundle = [self.folder URLByAppendingPathComponent:@"nota.textbundle"];
    XCTAssertEqualObjects(MPAttachmentsFolderNameFor(bundle), @"assets");
    // Dentro il pacchetto, non accanto: il documento *è* la cartella.
    XCTAssertEqualObjects(MPAttachmentsFolderFor(bundle).path,
        [bundle URLByAppendingPathComponent:@"assets"].path);
}

- (void)testAttachingCopiesTheFileAndNeverCoversOneThatIsThere
{
    NSURL *source = [self fileNamed:@"conti.csv" saying:@"a,b\n1,2\n"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"verbale.md"];

    NSString *problem = nil;
    NSString *first = MPAttachFileToDocument(source, document, &problem);
    XCTAssertEqualObjects(first, @"conti.csv");
    XCTAssertNil(problem);

    NSURL *copied = [[MPAttachmentsFolderFor(document)
        URLByAppendingPathComponent:@"conti.csv"] URLByStandardizingPath];
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:copied
        encoding:NSUTF8StringEncoding error:NULL], @"a,b\n1,2\n");

    // Lo stesso nome, un'altra volta: si numera, non si sovrascrive.
    NSString *second = MPAttachFileToDocument(source, document, &problem);
    XCTAssertEqualObjects(second, @"conti-2.csv");
}

- (void)testWithoutADocumentOnDiskItSaysSo
{
    NSURL *source = [self fileNamed:@"conti.csv" saying:@"a\n"];
    NSString *problem = nil;
    XCTAssertNil(MPAttachFileToDocument(source, nil, &problem));
    XCTAssertTrue(problem.length > 0);
}


#pragma mark - Come viene scritto

- (void)testAFileIsALinkAndAPictureIsAPicture
{
    XCTAssertEqualObjects(MPAttachmentMarkdown(@"verbale.pdf",
                                               @"nota.assets"),
                          @"[verbale.pdf](nota.assets/verbale.pdf)");
    XCTAssertEqualObjects(MPAttachmentMarkdown(@"schema.png", @"assets"),
                          @"![schema](assets/schema.png)");
    // Uno spazio nel nome è percent-encoded, altrimenti il link finisce
    // dopo la prima parola.
    XCTAssertEqualObjects(MPAttachmentMarkdown(@"la nota.pdf", @"assets"),
                          @"[la nota.pdf](assets/la%20nota.pdf)");
}

- (void)testAFileCanTravelInsideTheDocument
{
    NSURL *source = [self fileNamed:@"conti.csv" saying:@"a,b\n"];
    NSString *uri = MPDataURIForFile(source, NULL);
    XCTAssertTrue([uri hasPrefix:@"data:text/csv;base64,"], @"%@", uri);
}


#pragma mark - Quali file fanno parte del documento

- (void)testTheAttachmentsOfADocumentAreItsLocalFilesThatAreNotPictures
{
    [self fileNamed:@"verbale.pdf" saying:@"%PDF-1.4\n"];
    [self fileNamed:@"schema.png" saying:@"png finto"];
    [self fileNamed:@"vicino.md" saying:@"# vicino\n"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];

    NSString *markdown =
        @"Ecco [il verbale](verbale.pdf) e ![lo schema](schema.png).\n\n"
        @"Il [documento vicino](vicino.md) resta dov'è, come\n"
        @"[la pagina](https://esempio.it/x.pdf) e [questo](#dentro).\n";

    NSArray<NSURL *> *found = MPAttachmentsIn(markdown, document);
    XCTAssertEqual(found.count, 1u);
    XCTAssertEqualObjects(found.firstObject.lastPathComponent,
                          @"verbale.pdf");
}

- (void)testTheSameAttachmentTwiceIsOneFile
{
    [self fileNamed:@"verbale.pdf" saying:@"%PDF-1.4\n"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];
    NSArray<NSURL *> *found = MPAttachmentsIn(
        @"[uno](verbale.pdf) e ancora [due](verbale.pdf)\n", document);
    XCTAssertEqual(found.count, 1u);
}

- (void)testAFileThatIsNotThereIsNotAnAttachment
{
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];
    XCTAssertEqual([MPAttachmentsIn(@"[niente](sparito.pdf)\n",
                                    document) count], 0u);
}


#pragma mark - Quando esce di qui

- (void)testAnExportedPageCarriesItsAttachmentsInside
{
    [self fileNamed:@"verbale.pdf" saying:@"%PDF-1.4\n"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];

    NSString *html = @"<p><a href=\"verbale.pdf\">il verbale</a> "
                     @"e <a href=\"https://esempio.it\">un sito</a> "
                     @"e <a href=\"#dentro\">un salto</a></p>";
    NSString *made = MPHTMLWithAttachmentsInlined(html, document);

    XCTAssertTrue([made containsString:@"href=\"data:application/pdf;base64,"],
                  @"%@", made);
    // Quello che non è un file resta com'era.
    XCTAssertTrue([made containsString:@"https://esempio.it"]);
    XCTAssertTrue([made containsString:@"#dentro"]);
    // E il testo del link non si tocca.
    XCTAssertTrue([made containsString:@">il verbale</a>"]);
}

/// Il textbundle è il formato che gli allegati li ha da sempre: devono
/// finire in `assets/` come ci finiscono le immagini.
- (void)testATextbundleCarriesTheAttachmentsToo
{
    [self fileNamed:@"verbale.pdf" saying:@"%PDF-1.4\n"];
    [self fileNamed:@"schema.png" saying:@"png finto"];
    [self fileNamed:@"vicino.md" saying:@"# vicino\n"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];

    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *made = MPTextBundleMarkdown(
        @"[il verbale](verbale.pdf), ![lo schema](schema.png), "
        @"[il vicino](vicino.md)\n", document, &assets);

    XCTAssertTrue([made containsString:@"(assets/verbale.pdf)"], @"%@", made);
    XCTAssertTrue([made containsString:@"(assets/schema.png)"]);
    // Il documento accanto non è un allegato: resta dov'è.
    XCTAssertTrue([made containsString:@"(vicino.md)"]);

    NSMutableSet *names = [NSMutableSet set];
    for (MPTextBundleAsset *asset in assets)
        [names addObject:asset.name];
    XCTAssertEqualObjects(names, ([NSSet setWithArray:@[@"verbale.pdf",
                                                        @"schema.png"]]));
}


@end
