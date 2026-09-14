//
//  MPMailerTests.m
//  MacDownTests
//
//  Il documento come email: cosa finisce nel messaggio, e cosa viene
//  detto al programma di posta. Le due strade — Mail con uno script, tutti
//  gli altri con gli appunti — si provano qui senza aprire niente.
//

#import <XCTest/XCTest.h>

#import "MPMailer.h"


@interface MPMailerTests : XCTestCase
@property (strong) NSURL *folder;
@end


@implementation MPMailerTests

- (void)setUp
{
    [super setUp];
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"posta-%@",
            [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}


/// Una PNG vera, piccola, accanto al documento.
- (NSURL *)aPictureNamed:(NSString *)name
{
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(2.0, 2.0)];
    [image lockFocus];
    [[NSColor redColor] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, 2.0, 2.0));
    [image unlockFocus];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithCGImage:[image CGImageForProposedRect:NULL context:nil
                                                hints:nil]];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                    properties:@{}];
    NSURL *url = [self.folder URLByAppendingPathComponent:name];
    [png writeToURL:url atomically:YES];
    return url;
}


#pragma mark - Le immagini dentro il messaggio

- (void)testALocalPictureTravelsInsideTheMessage
{
    [self aPictureNamed:@"foto.png"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];
    NSString *html = @"<p><img src=\"foto.png\" alt=\"una foto\"></p>";

    NSString *made = MPHTMLWithLocalImagesInlined(html, document);
    XCTAssertTrue([made containsString:@"src=\"data:image/png;base64,"],
                  @"la foto è dentro: %@", made);
    XCTAssertFalse([made containsString:@"foto.png\""]);
    // E il resto del tag resta com'era.
    XCTAssertTrue([made containsString:@"alt=\"una foto\""]);
}


- (void)testWhatIsAlreadyInsideOrFarAwayIsLeftAlone
{
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];
    NSString *html = @"<img src=\"data:image/png;base64,AAAA\">"
                     @"<img src=\"https://esempio.it/logo.png\">"
                     @"<img src=\"non-c-e.png\">";
    NSString *made = MPHTMLWithLocalImagesInlined(html, document);
    XCTAssertEqualObjects(made, html);
}


- (void)testAPictureInASubfolderIsFoundFromTheDocument
{
    NSURL *inside = [self.folder URLByAppendingPathComponent:@"immagini"];
    [[NSFileManager defaultManager] createDirectoryAtURL:inside
        withIntermediateDirectories:YES attributes:nil error:NULL];
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(1.0, 1.0)];
    [image lockFocus];
    NSRectFill(NSMakeRect(0.0, 0.0, 1.0, 1.0));
    [image unlockFocus];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithCGImage:[image CGImageForProposedRect:NULL context:nil
                                                hints:nil]];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
        writeToURL:[inside URLByAppendingPathComponent:@"schema.png"]
        atomically:YES];

    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];
    NSString *made = MPHTMLWithLocalImagesInlined(
        @"<img src=\"immagini/schema.png\">", document);
    XCTAssertTrue([made containsString:@"data:image/png;base64,"]);
}


/// Uno spazio nel nome arriva nell'HTML come %20, e il file si trova
/// lo stesso.
- (void)testANameWithASpaceIsStillFound
{
    [self aPictureNamed:@"la foto.png"];
    NSURL *document = [self.folder URLByAppendingPathComponent:@"nota.md"];
    NSString *made = MPHTMLWithLocalImagesInlined(
        @"<img src=\"la%20foto.png\">", document);
    XCTAssertTrue([made containsString:@"data:image/png;base64,"]);
}


#pragma mark - Quello che si dice a Mail

- (void)testTheScriptForMailReadsTheFileInsteadOfCarryingIt
{
    NSString *script = [MPMailer appleMailScriptForSubject:@"Verbale"
                                                    htmlAt:@"/tmp/x.html"];
    XCTAssertTrue([script containsString:@"/tmp/x.html"]);
    XCTAssertTrue([script containsString:@"set html content"]);
    XCTAssertTrue([script containsString:@"subject:\"Verbale\""]);
    XCTAssertTrue([script containsString:@"visible:true"]);
}


- (void)testAnOddSubjectDoesNotBreakTheScript
{
    NSString *script = [MPMailer appleMailScriptForSubject:
        @"Il \"verbale\" di\\marzo" htmlAt:@"/tmp/x.html"];
    XCTAssertTrue([script containsString:@"\\\"verbale\\\""]);
    XCTAssertTrue([script containsString:@"di\\\\marzo"]);
    // E resta uno script che si compila.
    NSDictionary *bad = nil;
    NSAppleScript *made = [[NSAppleScript alloc] initWithSource:script];
    XCTAssertTrue([made compileAndReturnError:&bad], @"%@", bad);
}


#pragma mark - L'elenco dei programmi

- (void)testTheListHasSomethingInstalledAndTheWebOnes
{
    NSArray<MPMailClient *> *clients = [MPMailer clients];
    XCTAssertGreaterThanOrEqual(clients.count, 2u);

    BOOL gmail = NO, installed = NO;
    for (MPMailClient *client in clients)
    {
        XCTAssertTrue(client.name.length > 0);
        if ([client.name isEqualToString:@"Gmail"])
        {
            gmail = YES;
            XCTAssertEqual(client.way, MPMailWayWeb);
            XCTAssertTrue([client.composeFormat containsString:@"%@"]);
        }
        if (client.applicationURL)
        {
            installed = YES;
            XCTAssertNotEqual(client.way, MPMailWayWeb);
        }
    }
    XCTAssertTrue(gmail);
    XCTAssertTrue(installed, @"un Mac ha almeno un programma di posta");
}


- (void)testWithoutAProgramItSaysSoInsteadOfDoingSomething
{
    BOOL pasting = YES;
    NSString *problem = nil;
    BOOL went = [MPMailer open:nil subject:@"x" html:@"<p>x</p>" plain:@"x"
                  wantsPasting:&pasting problem:&problem];
    XCTAssertFalse(went);
    XCTAssertFalse(pasting);
    XCTAssertTrue(problem.length > 0);
}


#pragma mark - Il testo semplice

- (void)testThePlainTextIsTheWordsWithoutTheMarkup
{
    NSString *plain = [MPMailer plainTextFrom:
        @"<h1>Verbale</h1><p>Presenti: <b>Anna</b>.</p>"];
    XCTAssertTrue([plain containsString:@"Verbale"]);
    XCTAssertTrue([plain containsString:@"Presenti: Anna."]);
    XCTAssertFalse([plain containsString:@"<b>"]);
}

@end
