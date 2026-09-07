//
//  MPLinkPreviewTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "MPLinkPreview.h"


@interface MPLinkPreviewTests : XCTestCase
@property (strong) NSURL *folder;
@property (strong) NSURL *document;
@end


@implementation MPLinkPreviewTests

- (void)setUp
{
    [super setUp];
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
    self.document = [self.folder
        URLByAppendingPathComponent:@"verbale.md"];
    [@"# Verbale\n" writeToURL:self.document atomically:YES
                      encoding:NSUTF8StringEncoding error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}

- (MPLinkPreview *)previewOf:(NSString *)href
{
    return [MPLinkPreview previewForHref:href inDocument:self.document];
}

- (NSURL *)write:(NSString *)text to:(NSString *)name
{
    NSURL *url = [self.folder URLByAppendingPathComponent:name];
    [text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding
               error:NULL];
    return url;
}


#pragma mark - A document beside this one

- (void)testItReadsTheDocumentTheLinkLeadsTo
{
    [self write:@"# Piano di test\n\nPrima riga utile.\nSeconda riga.\n"
             to:@"piano.md"];

    MPLinkPreview *preview = [self previewOf:@"piano.md"];
    XCTAssertEqual(preview.kind, MPLinkPreviewKindDocument);
    // The heading is the title, and it is not repeated in the body.
    XCTAssertEqualObjects(preview.title, @"Piano di test");
    XCTAssertTrue([preview.body containsString:@"Prima riga utile."]);
    XCTAssertFalse([preview.body containsString:@"Piano di test"]);
    // How much there is to read, which is the other half of "what is over
    // there".
    XCTAssertTrue([preview.footnote containsString:@"parole"]);
}

- (void)testTheNameWhenThereIsNoHeading
{
    [self write:@"solo testo, senza titolo\n" to:@"appunti.md"];
    XCTAssertEqualObjects([self previewOf:@"appunti.md"].title, @"appunti");
}

- (void)testTheWayALinkCanBeWritten
{
    [self write:@"# Rete interna\n\ntesto\n" to:@"rete interna.md"];

    // Escaped, with an anchor, and through a folder that goes nowhere.
    for (NSString *href in @[@"rete%20interna.md",
                             @"rete%20interna.md#collaudo",
                             @"./rete%20interna.md",
                             @"sotto/../rete%20interna.md"])
    {
        XCTAssertEqualObjects([self previewOf:href].title, @"Rete interna",
                              @"«%@» non ha trovato il file", href);
    }
}

- (void)testAWikiLinkHasNoExtensionAndStillFindsTheFile
{
    [self write:@"# Appunti\n\ntesto\n" to:@"appunti.md"];
    // What the editor writes for [[appunti]] is an href with no extension.
    MPLinkPreview *preview = [self previewOf:@"appunti"];
    XCTAssertEqual(preview.kind, MPLinkPreviewKindDocument);
    XCTAssertEqualObjects(preview.title, @"Appunti");
}

- (void)testAFileThatIsNotThereYetSaysSo
{
    MPLinkPreview *preview = [self previewOf:@"ancora-niente.md"];
    XCTAssertEqual(preview.kind, MPLinkPreviewKindMissingFile);
    XCTAssertEqualObjects(preview.title, @"ancora-niente");
    // Whatever language the interface is in: the same string the code asks
    // for, not the English it is keyed by.
    XCTAssertEqualObjects(preview.body, NSLocalizedString(
        @"This file is not there yet.", @"A link to a file that is missing"));
}


#pragma mark - Somewhere else

- (void)testAnAddressIsTakenApartAndNothingIsFetched
{
    MPLinkPreview *preview = [self previewOf:
        @"https://esempio.it/molto/lungo/percorso?q=1"];
    XCTAssertEqual(preview.kind, MPLinkPreviewKindAddress);
    XCTAssertEqualObjects(preview.title, @"esempio.it");
    XCTAssertEqualObjects(preview.body, @"/molto/lungo/percorso?q=1");
    XCTAssertTrue([preview.footnote hasPrefix:@"https"]);
    // There is no file behind it, and nothing was read to find that out.
    XCTAssertNil(preview.fileURL);
}

- (void)testAnAnchorInThePageIsNotSomewhereToGo
{
    XCTAssertNil([self previewOf:@"#collaudo"]);
    XCTAssertNil([self previewOf:@""]);
    XCTAssertNil([self previewOf:nil]);
}


#pragma mark - Pictures

- (void)testAPictureShowsItself
{
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(4.0, 4.0)];
    [image lockFocus];
    [[NSColor redColor] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, 4.0, 4.0));
    [image unlockFocus];
    NSData *png = [[[NSBitmapImageRep alloc] initWithCGImage:
        [image CGImageForProposedRect:NULL context:nil hints:nil]]
        representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSURL *file = [self.folder URLByAppendingPathComponent:@"rete.png"];
    [png writeToURL:file atomically:YES];

    MPLinkPreview *preview = [self previewOf:@"rete.png"];
    XCTAssertEqual(preview.kind, MPLinkPreviewKindImage);
    XCTAssertEqualObjects(preview.title, @"rete.png");
    XCTAssertEqualObjects(preview.fileURL.URLByStandardizingPath.path,
                          file.URLByStandardizingPath.path);
    // Its size, since that is what a picture's card can say in words.
    XCTAssertGreaterThan(preview.footnote.length, 0u);
}

- (void)testFrontMatterIsNotWhatTheDocumentSays
{
    [self write:@"---\ntitle: \"Ritaglio\"\nsource: https://esempio.it\n---\n"
        @"\n# Ritaglio\n\nIl testo vero.\n" to:@"ritaglio.md"];
    MPLinkPreview *preview = [self previewOf:@"ritaglio.md"];
    XCTAssertEqualObjects(preview.title, @"Ritaglio");
    XCTAssertTrue([preview.body containsString:@"Il testo vero."]);
}

#pragma mark - What a page says about itself

- (void)testAPageThatWritesItsOwnSummary
{
    NSString *html = @"<html><head><title>Rete interna — Esempio</title>"
        @"<meta property=\"og:description\" content=\"Come è fatta la rete "
        @"dell'ufficio, in breve.\">"
        @"<meta name=\"description\" content=\"Meno buona di quella sopra.\">"
        @"</head><body><p>Testo.</p></body></html>";

    NSString *title = nil;
    NSString *summary = nil;
    MPPageSummaryFromHTML(html, &title, &summary);

    XCTAssertEqualObjects(title, @"Rete interna — Esempio");
    // og:description first: it is the line written for exactly this.
    XCTAssertEqualObjects(summary, @"Come è fatta la rete dell'ufficio, in breve.");
}

- (void)testTheOrdinaryDescriptionWhenThereIsNoOther
{
    NSString *html = @"<html><head><title>Verbale</title>"
        @"<meta name=\"description\" content=\"Il verbale della riunione.\">"
        @"</head><body></body></html>";
    NSString *title = nil;
    NSString *summary = nil;
    MPPageSummaryFromHTML(html, &title, &summary);
    XCTAssertEqualObjects(title, @"Verbale");
    XCTAssertEqualObjects(summary, @"Il verbale della riunione.");
}

- (void)testAttributesWrittenTheOtherWayRound
{
    NSString *html = @"<head><title>X</title>"
        @"<meta content=\"Prima il contenuto.\" name=\"description\"></head>";
    NSString *summary = nil;
    MPPageSummaryFromHTML(html, NULL, &summary);
    XCTAssertEqualObjects(summary, @"Prima il contenuto.");
}

- (void)testEntitiesAreReadAsCharacters
{
    NSString *html = @"<head><title>A &amp; B</title>"
        @"<meta name=\"description\" content=\"Perch&eacute; no&nbsp;?\">"
        @"</head>";
    NSString *title = nil;
    NSString *summary = nil;
    MPPageSummaryFromHTML(html, &title, &summary);
    XCTAssertEqualObjects(title, @"A & B");
    XCTAssertTrue([summary hasPrefix:@"Perché no"], @"%@", summary);
}

- (void)testAPageThatSaysNothingAboutItself
{
    NSString *title = nil;
    NSString *summary = nil;
    MPPageSummaryFromHTML(@"<html><body><p>Solo testo.</p></body></html>",
                          &title, &summary);
    XCTAssertNil(title);
    XCTAssertNil(summary);

    MPPageSummaryFromHTML(nil, &title, &summary);
    XCTAssertNil(title);
    XCTAssertNil(summary);
}

@end
