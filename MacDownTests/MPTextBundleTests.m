//
//  MPTextBundleTests.m
//  MacDownTests
//
//  What goes into a Textbundle, and what stays outside it.
//

#import <XCTest/XCTest.h>

#import "MPTextBundle.h"
#import "MPZipArchive.h"


@interface MPTextBundleTests : XCTestCase
@property (strong) NSURL *folder;
@property (strong) NSURL *document;
@end

@implementation MPTextBundleTests

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

- (NSURL *)writePicture:(NSString *)name
{
    NSURL *file = [self.folder URLByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtURL:
        file.URLByDeletingLastPathComponent withIntermediateDirectories:YES
        attributes:nil error:NULL];
    [[NSMutableData dataWithLength:32] writeToURL:file atomically:YES];
    return file;
}


#pragma mark - Which pictures travel

- (void)testAPictureBesideTheDocumentBecomesAnAsset
{
    [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *out = MPTextBundleMarkdown(@"Testo\n\n![rete](rete.png)\n",
                                         self.document, &assets);
    XCTAssertEqualObjects(out, @"Testo\n\n![rete](assets/rete.png)\n");
    XCTAssertEqual(assets.count, 1u);
    XCTAssertEqualObjects(assets[0].name, @"rete.png");
    XCTAssertEqualObjects(assets[0].fileURL.lastPathComponent, @"rete.png");
}

- (void)testAPictureInASubfolderKeepsItsNameAndLosesItsPath
{
    [self writePicture:@"figure/schema.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *out = MPTextBundleMarkdown(@"![s](figure/schema.png)",
                                         self.document, &assets);
    XCTAssertEqualObjects(out, @"![s](assets/schema.png)");
    XCTAssertEqualObjects(assets[0].name, @"schema.png");
}

- (void)testTwoPicturesWithTheSameNameDoNotCollide
{
    [self writePicture:@"rete.png"];
    [self writePicture:@"vecchie/rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *out = MPTextBundleMarkdown(
        @"![a](rete.png) e ![b](vecchie/rete.png)", self.document, &assets);
    XCTAssertEqual(assets.count, 2u);
    XCTAssertTrue([out containsString:@"assets/rete.png"]);
    XCTAssertTrue([out containsString:@"assets/rete-2.png"], @"%@", out);
}

- (void)testTheSamePictureTwiceIsOneAsset
{
    [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *out = MPTextBundleMarkdown(
        @"![a](rete.png)\n\n![ancora](./rete.png)", self.document, &assets);
    XCTAssertEqual(assets.count, 1u);
    XCTAssertEqualObjects(out,
        @"![a](assets/rete.png)\n\n![ancora](assets/rete.png)");
}

- (void)testANameWithSpacesIsEncodedInTheLink
{
    [self writePicture:@"foto di prova.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *out = MPTextBundleMarkdown(@"![f](foto%20di%20prova.png)",
                                         self.document, &assets);
    XCTAssertEqualObjects(out, @"![f](assets/foto%20di%20prova.png)");
    XCTAssertEqualObjects(assets[0].name, @"foto di prova.png");
}

- (void)testATitleAfterTheDestinationSurvives
{
    [self writePicture:@"rete.png"];
    NSString *out = MPTextBundleMarkdown(@"![r](rete.png \"La rete\")",
                                         self.document, NULL);
    XCTAssertEqualObjects(out, @"![r](assets/rete.png \"La rete\")");
}

- (void)testADestinationInAngleBracketsIsRewrittenInside
{
    [self writePicture:@"foto di prova.png"];
    NSString *out = MPTextBundleMarkdown(@"![f](<foto di prova.png>)",
                                         self.document, NULL);
    XCTAssertEqualObjects(out, @"![f](<assets/foto%20di%20prova.png>)");
}

- (void)testAReferenceDefinitionIsRewrittenToo
{
    [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *out = MPTextBundleMarkdown(
        @"![rete][r]\n\n[r]: rete.png\n", self.document, &assets);
    XCTAssertEqual(assets.count, 1u);
    XCTAssertEqualObjects(out, @"![rete][r]\n\n[r]: assets/rete.png\n");
}


#pragma mark - What stays outside

- (void)testARemoteAddressStaysAnAddress
{
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *markdown = @"![fuori](https://esempio.it/rete.png)";
    NSString *out = MPTextBundleMarkdown(markdown, self.document, &assets);
    XCTAssertEqualObjects(out, markdown);
    XCTAssertEqual(assets.count, 0u);
    XCTAssertEqualObjects(MPTextBundleRemoteImages(markdown),
                          @[@"https://esempio.it/rete.png"]);
}

- (void)testAnAddressIsListedOnceHoweverOftenItIsUsed
{
    NSString *markdown = @"![a](https://esempio.it/x.png)\n\n"
        @"![b](https://esempio.it/x.png)\n\n![c](https://esempio.it/y.png)";
    NSArray<NSString *> *remote = MPTextBundleRemoteImages(markdown);
    XCTAssertEqual(remote.count, 2u);
    XCTAssertEqualObjects(remote[0], @"https://esempio.it/x.png");
}

- (void)testAPictureInsideCodeIsNotAPicture
{
    [self writePicture:@"rete.png"];
    NSString *markdown = @"Si scrive così:\n\n```\n![rete](rete.png)\n```\n"
        @"e anche `![rete](rete.png)`.\n";
    NSArray<MPTextBundleAsset *> *assets = nil;
    XCTAssertEqualObjects(MPTextBundleMarkdown(markdown, self.document,
                                               &assets), markdown);
    XCTAssertEqual(assets.count, 0u);
}

- (void)testALinkToANeighbouringDocumentIsLeftAlone
{
    [self writePicture:@"nota.md"];
    NSString *markdown = @"vedi [la nota](nota.md) e ![r](manca.png)";
    NSArray<MPTextBundleAsset *> *assets = nil;
    // A textbundle holds one text: the other documents stay where they are,
    // and a picture that is not there cannot travel.
    XCTAssertEqualObjects(MPTextBundleMarkdown(markdown, self.document,
                                               &assets), markdown);
    XCTAssertEqual(assets.count, 0u);
}

- (void)testAnUnsavedDocumentHasNothingToResolveAgainst
{
    [self writePicture:@"rete.png"];
    NSString *markdown = @"![r](rete.png)";
    NSArray<MPTextBundleAsset *> *assets = nil;
    XCTAssertEqualObjects(MPTextBundleMarkdown(markdown, nil, &assets),
                          markdown);
    XCTAssertEqual(assets.count, 0u);
}


#pragma mark - info.json

- (void)testTheInfoSaysWhatTheFormatAsksFor
{
    NSData *info = MPTextBundleInfo(@"com.esempio.app",
                                    @"https://esempio.it");
    NSDictionary *read = [NSJSONSerialization JSONObjectWithData:info
                                                        options:0
                                                          error:NULL];
    XCTAssertEqualObjects(read[@"version"], @2);
    XCTAssertEqualObjects(read[@"type"], @"net.daringfireball.markdown");
    XCTAssertEqualObjects(read[@"transient"], @NO);
    XCTAssertEqualObjects(read[@"creatorIdentifier"], @"com.esempio.app");
    XCTAssertEqualObjects(read[@"creatorURL"], @"https://esempio.it");
}


#pragma mark - The two containers

- (void)testTheFolderFormHasTheThreeThingsInIt
{
    NSURL *picture = [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *text = MPTextBundleMarkdown(@"![r](rete.png)", self.document,
                                          &assets);
    NSURL *bundle = [self.folder
        URLByAppendingPathComponent:@"verbale.textbundle"];
    NSError *error = nil;
    XCTAssertTrue(MPWriteTextBundle(bundle, text,
        MPTextBundleInfo(@"com.esempio.app", nil), assets, &error), @"%@",
        error);

    NSFileManager *manager = [NSFileManager defaultManager];
    XCTAssertTrue([manager fileExistsAtPath:
        [bundle URLByAppendingPathComponent:@"info.json"].path]);
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        [bundle URLByAppendingPathComponent:@"text.markdown"]
        encoding:NSUTF8StringEncoding error:NULL],
        @"![r](assets/rete.png)");
    NSURL *copied = [bundle
        URLByAppendingPathComponent:@"assets/rete.png"];
    XCTAssertTrue([manager fileExistsAtPath:copied.path]);
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:copied],
                          [NSData dataWithContentsOfURL:picture]);
}

- (void)testWritingOverAnOldBundleLeavesNothingOfIt
{
    NSURL *bundle = [self.folder
        URLByAppendingPathComponent:@"verbale.textbundle"];
    [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *text = MPTextBundleMarkdown(@"![r](rete.png)", self.document,
                                          &assets);
    XCTAssertTrue(MPWriteTextBundle(bundle, text,
        MPTextBundleInfo(@"a", nil), assets, NULL));
    // Nothing to bring this time: the old picture must not stay behind.
    XCTAssertTrue(MPWriteTextBundle(bundle, @"solo testo",
        MPTextBundleInfo(@"a", nil), @[], NULL));
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:
        [bundle URLByAppendingPathComponent:@"assets/rete.png"].path]);
}

- (void)testThePackIsTheFolderInsideAZip
{
    [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *text = MPTextBundleMarkdown(@"![r](rete.png)", self.document,
                                          &assets);
    NSData *pack = MPTextPackData(@"verbale.textbundle", text,
        MPTextBundleInfo(@"com.esempio.app", nil), assets);
    XCTAssertNotNil(pack);

    NSArray<MPZipEntry *> *entries = MPZipRead(pack);
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (MPZipEntry *entry in entries)
        [names addObject:entry.name];
    XCTAssertEqualObjects(names, (@[@"verbale.textbundle/info.json",
                                    @"verbale.textbundle/text.markdown",
                                    @"verbale.textbundle/assets/rete.png"]));
    XCTAssertEqualObjects(MPStringFromEntry(entries,
        @"verbale.textbundle/text.markdown"), @"![r](assets/rete.png)");
}

- (void)testThePackIsAZipTheSystemCanOpen
{
    // MPZipRead reading what MPZipWrite wrote proves the two agree with
    // each other, not that anybody else can open it. A textpack is meant to
    // arrive by mail and be unzipped by whatever is at the other end.
    [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *text = MPTextBundleMarkdown(@"![r](rete.png)", self.document,
                                          &assets);
    NSData *pack = MPTextPackData(@"verbale.textbundle", text,
        MPTextBundleInfo(@"com.esempio.app", nil), assets);
    NSURL *file = [self.folder
        URLByAppendingPathComponent:@"verbale.textpack"];
    XCTAssertTrue([pack writeToURL:file atomically:YES]);

    NSPipe *pipe = [NSPipe pipe];
    NSTask *unzip = [[NSTask alloc] init];
    unzip.executableURL = [NSURL fileURLWithPath:@"/usr/bin/unzip"];
    unzip.arguments = @[@"-p", file.path, @"verbale.textbundle/text.markdown"];
    unzip.standardOutput = pipe;
    NSError *error = nil;
    if (![unzip launchAndReturnError:&error])
    {
        XCTFail(@"unzip non è partito: %@", error);
        return;
    }
    NSData *out = [pipe.fileHandleForReading readDataToEndOfFile];
    [unzip waitUntilExit];
    XCTAssertEqual(unzip.terminationStatus, 0);
    XCTAssertEqualObjects([[NSString alloc] initWithData:out
        encoding:NSUTF8StringEncoding], @"![r](assets/rete.png)");
}

- (void)testAPackWithNoNameIsNotAPack
{
    XCTAssertNil(MPTextPackData(@"", @"testo",
                                MPTextBundleInfo(@"a", nil), @[]));
}

#pragma mark - Reading one

- (void)testWhatIsABundleAndWhatIsNot
{
    NSURL *bundle = [self.folder
        URLByAppendingPathComponent:@"verbale.textbundle"];
    [[NSFileManager defaultManager] createDirectoryAtURL:bundle
        withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertTrue(MPIsTextBundle(bundle));

    // A *file* with that extension is not a bundle, whatever it is called.
    NSURL *impostor = [self.folder
        URLByAppendingPathComponent:@"finto.textbundle"];
    [@"testo" writeToURL:impostor atomically:YES
                encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertFalse(MPIsTextBundle(impostor));
    XCTAssertFalse(MPIsTextBundle(self.document));
    XCTAssertTrue(MPIsTextPack([self.folder
        URLByAppendingPathComponent:@"verbale.textpack"]));
}

- (void)testTheTextInsideIsFoundByName
{
    NSURL *bundle = [self.folder
        URLByAppendingPathComponent:@"a.textbundle"];
    [[NSFileManager defaultManager] createDirectoryAtURL:bundle
        withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertNil(MPTextBundleTextURL(bundle));

    // Somebody else's bundle may use .md, or something else again.
    [@"x" writeToURL:[bundle URLByAppendingPathComponent:@"text.txt"]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertEqualObjects(MPTextBundleTextURL(bundle).lastPathComponent,
                          @"text.txt");
    [@"x" writeToURL:[bundle URLByAppendingPathComponent:@"text.md"]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertEqualObjects(MPTextBundleTextURL(bundle).lastPathComponent,
                          @"text.md");
    // The name the specification itself uses wins over the others.
    [@"x" writeToURL:[bundle URLByAppendingPathComponent:@"text.markdown"]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertEqualObjects(MPTextBundleTextURL(bundle).lastPathComponent,
                          @"text.markdown");
}

- (void)testAPackComesBackOutTheWayItWentIn
{
    NSURL *picture = [self writePicture:@"rete.png"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    NSString *text = MPTextBundleMarkdown(@"![r](rete.png)", self.document,
                                          &assets);
    NSURL *pack = [self.folder
        URLByAppendingPathComponent:@"verbale.textpack"];
    [MPTextPackData(@"verbale.textbundle", text,
        MPTextBundleInfo(@"com.esempio.app", nil), assets)
        writeToURL:pack atomically:YES];

    NSError *error = nil;
    NSURL *bundle = MPUnpackTextPack(pack, self.folder, &error);
    XCTAssertNotNil(bundle, @"%@", error);
    XCTAssertEqualObjects(bundle.lastPathComponent, @"verbale.textbundle");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        MPTextBundleTextURL(bundle) encoding:NSUTF8StringEncoding
        error:NULL], @"![r](assets/rete.png)");
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:
        [bundle URLByAppendingPathComponent:@"assets/rete.png"]],
        [NSData dataWithContentsOfURL:picture]);
}

- (void)testUnpackingTwiceKeepsBoth
{
    NSURL *pack = [self.folder
        URLByAppendingPathComponent:@"verbale.textpack"];
    [MPTextPackData(@"verbale.textbundle", @"testo",
        MPTextBundleInfo(@"a", nil), @[]) writeToURL:pack atomically:YES];

    XCTAssertEqualObjects(MPUnpackTextPack(pack, self.folder, NULL)
        .lastPathComponent, @"verbale.textbundle");
    XCTAssertEqualObjects(MPUnpackTextPack(pack, self.folder, NULL)
        .lastPathComponent, @"verbale-2.textbundle");
}

- (void)testAnArchiveThatWritesOutsideItsFolderIsRefused
{
    // Nothing in a textpack has any business naming a path of its own.
    NSData *hostile = MPZipWrite(@[
        MPStoredEntry(@"verbale.textbundle/text.markdown",
            [@"innocuo" dataUsingEncoding:NSUTF8StringEncoding]),
        MPStoredEntry(@"../rubato.md",
            [@"fuori" dataUsingEncoding:NSUTF8StringEncoding]),
    ]);
    NSURL *pack = [self.folder URLByAppendingPathComponent:@"male.textpack"];
    [hostile writeToURL:pack atomically:YES];

    NSError *error = nil;
    XCTAssertNil(MPUnpackTextPack(pack, self.folder, &error));
    XCTAssertNotNil(error);
    // Refused whole: not one entry of it is written.
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:
        [self.folder URLByAppendingPathComponent:@"verbale.textbundle"].path]);
}

- (void)testAPackWithNoTextIsNotAPack
{
    NSData *empty = MPZipWrite(@[MPStoredEntry(
        @"verbale.textbundle/info.json",
        MPTextBundleInfo(@"a", nil))]);
    NSURL *pack = [self.folder URLByAppendingPathComponent:@"vuoto.textpack"];
    [empty writeToURL:pack atomically:YES];

    NSError *error = nil;
    XCTAssertNil(MPUnpackTextPack(pack, self.folder, &error));
    XCTAssertNotNil(error);
    // And it cleans up after itself rather than leaving half a bundle.
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:
        [self.folder URLByAppendingPathComponent:@"verbale.textbundle"].path]);
}

- (void)testAPackSomebodyElseWroteIsRead
{
    // Our own writer stores everything; /usr/bin/zip deflates, which is
    // what a textpack from another application looks like.
    NSURL *bundle = [self.folder
        URLByAppendingPathComponent:@"altrui.textbundle"];
    NSArray<MPTextBundleAsset *> *assets = nil;
    [self writePicture:@"rete.png"];
    NSString *text = MPTextBundleMarkdown(@"![r](rete.png)\n\nE del testo "
        @"lungo abbastanza da comprimersi davvero, ripetuto: "
        @"testo testo testo testo testo testo testo testo.",
        self.document, &assets);
    XCTAssertTrue(MPWriteTextBundle(bundle, text,
        MPTextBundleInfo(@"com.esempio.app", nil), assets, NULL));

    NSTask *zip = [[NSTask alloc] init];
    zip.executableURL = [NSURL fileURLWithPath:@"/usr/bin/zip"];
    zip.currentDirectoryURL = self.folder;
    zip.arguments = @[@"-r", @"-q", @"altrui.textpack",
                      @"altrui.textbundle"];
    NSError *error = nil;
    XCTAssertTrue([zip launchAndReturnError:&error], @"%@", error);
    [zip waitUntilExit];
    XCTAssertEqual(zip.terminationStatus, 0);

    // Out of the way, so what is read comes from the archive.
    [[NSFileManager defaultManager] removeItemAtURL:bundle error:NULL];

    NSURL *read = MPUnpackTextPack([self.folder
        URLByAppendingPathComponent:@"altrui.textpack"], self.folder,
        &error);
    XCTAssertNotNil(read, @"%@", error);
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        MPTextBundleTextURL(read) encoding:NSUTF8StringEncoding error:NULL],
        text);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:
        [read URLByAppendingPathComponent:@"assets/rete.png"].path]);
}

@end
