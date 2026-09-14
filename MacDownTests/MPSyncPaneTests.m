//
//  MPSyncPaneTests.m
//  MacDownTests
//
//  Che il pannello della sincronizzazione esista, si costruisca e risponda
//  come un pannello delle preferenze deve: un identificatore, un'etichetta,
//  e una vista che si carica. Un pannello che non si carica sparisce dalla
//  barra senza un errore, ed è successo.
//

#import <XCTest/XCTest.h>

#import "MPCloudService.h"
#import "MPCloudLedger.h"

extern NSData *MPGoogleUploadBody(NSString *boundary,
                                  NSDictionary *metadata,
                                  NSString *text);
extern NSString *MPConflictNameFor(NSString *name, NSDate *when);
#import "MPSyncPreferencesViewController.h"
#import "MPCloudOpenWindowController.h"


/// Quel tanto di privato che serve per guardare dentro le due finestre.
@interface MPCloudOpenWindowController (Prove)
- (instancetype)initWithService:(MPCloudService *)service chosen:(id)chosen;
@property (strong, nonatomic) NSViewController *list;
@property (strong, nonatomic) NSViewController *sidebar;
@end

@interface MPCloudService (Prove)
- (void)remember:(NSURL *)folder;
@end

@interface NSViewController (Prove)
- (void)show:(NSArray *)documents note:(NSString *)note;
- (void)setFilter:(NSString *)filter;
@end


@interface MPSyncPaneTests : XCTestCase
@end


@implementation MPSyncPaneTests

- (void)testItBuildsAndAnswersLikeAPane
{
    MPSyncPreferencesViewController *pane =
        [[MPSyncPreferencesViewController alloc] init];
    XCTAssertNotNil(pane);
    XCTAssertEqualObjects([pane viewIdentifier], @"SyncPreferences");
    XCTAssertTrue([pane toolbarItemLabel].length > 0);
    XCTAssertNotNil([pane toolbarItemImage]);
    // La vista: se -loadView solleva, è qui che si vede invece che in una
    // barra degli strumenti con una voce in meno.
    XCTAssertNotNil(pane.view);
    XCTAssertTrue(pane.view.subviews.count > 0);
}

- (void)testTheProvidersAreThereInOrder
{
    NSArray<MPCloudService *> *services = [MPCloudService services];
    XCTAssertEqual(services.count, 3u);
    XCTAssertEqualObjects(services[0].name, @"Google Drive");
    XCTAssertEqualObjects(services[1].name, @"iCloud Drive");
    XCTAssertEqualObjects(services[2].name, @"Dropbox");
    // L'ultimo è un segnaposto: si vede e non si tocca.
    XCTAssertTrue(services[0].available);
    XCTAssertTrue(services[1].available);
    XCTAssertFalse(services[2].available);
    // E lo dice, invece di lasciare una scheda vuota.
    XCTAssertTrue(services[2].explanation.length > 40);

    // iCloud non chiede niente da incollare, e la sua cartella porta con
    // sé quello che contiene: sono le due cose che lo rendono diverso.
    XCTAssertTrue(services[0].needsAClient);
    XCTAssertFalse(services[1].needsAClient);
    XCTAssertTrue(services[0].picksDocuments);
    XCTAssertFalse(services[1].picksDocuments);
    XCTAssertTrue(services[1].isConfigured);
}

- (void)testEachProviderRemembersItsOwnThings
{
    NSArray<MPCloudService *> *services = [MPCloudService services];
    NSString *wasGoogle = services[0].clientIdentifier;
    NSString *wasDropbox = services[1].clientIdentifier;

    services[0].clientIdentifier = @"uno.apps.googleusercontent.com";
    services[1].clientIdentifier = @"due";
    XCTAssertEqualObjects(services[0].clientIdentifier,
                          @"uno.apps.googleusercontent.com");
    XCTAssertEqualObjects(services[1].clientIdentifier, @"due");

    services[0].clientIdentifier = wasGoogle;
    services[1].clientIdentifier = wasDropbox;
}

- (void)testTheConsentURLIsTheOneGoogleDocuments
{
    MPCloudService *google = [MPCloudService services].firstObject;
    NSString *was = google.clientIdentifier;
    google.clientIdentifier = @"123.apps.googleusercontent.com";

    NSString *text = MPCloudConsentURL(google, @"http://127.0.0.1:5000/x",
                                       @"SFIDA").absoluteString;
    XCTAssertTrue([text hasPrefix:
        @"https://accounts.google.com/o/oauth2/v2/auth?"]);
    // I due che, su desktop, *sono* il Picker.
    XCTAssertTrue([text containsString:@"trigger_onepick=true"]);
    XCTAssertTrue([text containsString:@"allow_folder_selection=true"]);
    // L'ambito stretto, e nessun altro.
    XCTAssertTrue([text containsString:@"drive.file"]);
    XCTAssertFalse([text containsString:@"drive.readonly"]);
    // PKCE, e il codice che torna.
    XCTAssertTrue([text containsString:@"code_challenge=SFIDA"]);
    XCTAssertTrue([text containsString:@"code_challenge_method=S256"]);
    XCTAssertTrue([text containsString:@"access_type=offline"]);
    XCTAssertTrue([text containsString:@"client_id=123.apps"]);

    google.clientIdentifier = was;
}

- (void)testThePlaceholderHasNoConsentToGiveYet
{
    MPCloudService *dropbox = [MPCloudService services][1];
    XCTAssertNil(MPCloudConsentURL(dropbox, @"http://127.0.0.1:5000/x", @"S"));
}

- (void)testThePKCEChallengeIsTheSHA256InBase64URL
{
    // Il vettore di prova della RFC 7636.
    NSString *verifier = @"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    XCTAssertEqualObjects(MPCloudPKCEChallenge(verifier),
                          @"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
}

- (void)testNothingIsConfiguredUntilThereIsAClientThatLooksLikeOne
{
    MPCloudService *google = [MPCloudService services].firstObject;
    NSString *was = google.clientIdentifier;

    google.clientIdentifier = @"";
    XCTAssertFalse(google.isConfigured);
    google.clientIdentifier = @"non è un client";
    XCTAssertFalse(google.isConfigured);
    google.clientIdentifier = @" 123-abc.apps.googleusercontent.com ";
    XCTAssertTrue(google.isConfigured);
    // Gli spazi intorno a una cosa incollata non sono parte della cosa.
    XCTAssertEqualObjects(google.clientIdentifier,
                          @"123-abc.apps.googleusercontent.com");

    google.clientIdentifier = was;
}


- (void)testALongMessageFromTheServiceIsReadableAndItsLinkPressable
{
    MPSyncPreferencesViewController *pane =
        [[MPSyncPreferencesViewController alloc] init];
    (void)pane.view;

    // Le parole di Google, quelle vere, quando manca l'API nel progetto.
    [pane say:@"Google Drive API has not been used in project 832285497074 "
               @"before or it is disabled. Enable it by visiting "
               @"https://console.developers.google.com/apis/api/"
               @"drive.googleapis.com/overview?project=832285497074 then "
               @"retry. If you enabled this API recently, wait a few "
               @"minutes for the action to propagate to our systems and "
               @"retry."];

    NSAttributedString *written = pane.stateText;
    // Una frase per riga, invece di un'unica riga larga come la finestra.
    XCTAssertTrue([written.string containsString:@"\n"]);
    XCTAssertEqual([[written.string componentsSeparatedByString:@"\n"] count],
                   3u);

    // E l'indirizzo si può premere.
    __block NSURL *link = nil;
    [written enumerateAttribute:NSLinkAttributeName
                        inRange:NSMakeRange(0, written.length)
                        options:0
                     usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value)
            link = [value isKindOfClass:[NSURL class]] ? value
                 : [NSURL URLWithString:value];
    }];
    XCTAssertNotNil(link);
    XCTAssertEqualObjects(link.host, @"console.developers.google.com");
}

- (void)testAShortStateStaysOnOneLine
{
    MPSyncPreferencesViewController *pane =
        [[MPSyncPreferencesViewController alloc] init];
    (void)pane.view;
    [pane say:@"Non collegato."];
    XCTAssertFalse([pane.stateText.string containsString:@"\n"]);
}


- (void)testAnUploadIsTwoPiecesInOneBody
{
    NSData *body = MPGoogleUploadBody(@"CONFINE",
        @{@"name": @"nota.md", @"parents": @[@"CARTELLA"]},
        @"# Titolo\n\nUna riga.\n");
    NSString *written = [[NSString alloc] initWithData:body
                                              encoding:NSUTF8StringEncoding];

    // Prima cosa è, poi cos'è dentro, e un confine che chiude.
    XCTAssertTrue([written hasPrefix:@"--CONFINE\r\n"]);
    XCTAssertTrue([written containsString:@"application/json"]);
    XCTAssertTrue([written containsString:@"\"name\":\"nota.md\""]
                  || [written containsString:@"\"name\": \"nota.md\""]);
    XCTAssertTrue([written containsString:@"CARTELLA"]);
    XCTAssertTrue([written containsString:@"text/markdown"]);
    XCTAssertTrue([written containsString:@"# Titolo"]);
    XCTAssertTrue([written hasSuffix:@"--CONFINE--\r\n"]);
}

- (void)testTheConflictCopyIsNamedSoThatBothSurvive
{
    NSDate *when = [NSDate dateWithTimeIntervalSince1970:1757800800];
    NSString *name = MPConflictNameFor(@"verbale.md", when);
    // Il nome di prima, quello che è successo, e l'estensione: aprendo la
    // cartella si capisce cos'è senza doverlo chiedere a nessuno.
    XCTAssertTrue([name hasPrefix:@"verbale (copia in conflitto "]);
    XCTAssertTrue([name hasSuffix:@".md"]);
    XCTAssertFalse([name isEqualToString:@"verbale.md"]);
}

#pragma mark - La finestra dei documenti

/// La prima tabella che si trova, scendendo: l'elenco o la barra laterale.
static NSTableView *MPTableIn(NSView *view)
{
    if ([view isKindOfClass:[NSTableView class]])
        return (NSTableView *)view;
    for (NSView *child in view.subviews)
    {
        NSTableView *found = MPTableIn(child);
        if (found)
            return found;
    }
    return nil;
}

static NSArray<MPCloudDocument *> *MPSomeDocuments(void)
{
    NSArray *names = @[@"verbale.md", @"appunti.md", @"spesa.txt"];
    NSMutableArray *documents = [NSMutableArray array];
    for (NSUInteger i = 0; i < names.count; i++)
    {
        MPCloudDocument *one = [[MPCloudDocument alloc] init];
        one.identifier = [NSString stringWithFormat:@"id%lu",
                          (unsigned long)i];
        one.name = names[i];
        one.modified = [NSDate dateWithTimeIntervalSinceNow:-60.0 * (i + 1)];
        one.size = (long long)(1000 * (i + 1));
        [documents addObject:one];
    }
    return documents;
}

static MPCloudOpenWindowController *MPOpenWindow(void)
{
    MPCloudService *google = [MPCloudService services].firstObject;
    MPCloudOpenWindowController *open = [[MPCloudOpenWindowController alloc]
        initWithService:google chosen:nil];
    [open.list show:MPSomeDocuments() note:nil];
    return open;
}


/// I servizi collegati stanno a sinistra, sotto un'intestazione, anche
/// quando è uno solo: è lì che si guarda per sapere dove si è.
- (void)testTheSidebarNamesTheServicesUnderAHeader
{
    MPCloudOpenWindowController *open = MPOpenWindow();
    NSTableView *side = MPTableIn(open.sidebar.view);
    XCTAssertNotNil(side);
    XCTAssertEqual(side.style, NSTableViewStyleSourceList);
    // Una riga di intestazione più i servizi.
    XCTAssertTrue(side.numberOfRows >= 2);
    XCTAssertTrue([side.delegate tableView:side isGroupRow:0]);
    XCTAssertFalse([side.delegate tableView:side shouldSelectRow:0]);
    NSTableCellView *first = (NSTableCellView *)[side viewAtColumn:0 row:1
                                                   makeIfNecessary:YES];
    XCTAssertEqualObjects(first.textField.stringValue,
                          [MPCloudService services].firstObject.name);
    XCTAssertNotNil(first.imageView.image);
    [open close];
}


/// Tre colonne come in una cartella: nome, quando, quanto — e si possono
/// ordinare, che è la ragione per cui ci sono.
- (void)testTheListHasTheThreeColumnsOfAFolder
{
    MPCloudOpenWindowController *open = MPOpenWindow();
    NSTableView *list = MPTableIn(open.list.view);
    XCTAssertEqual(list.tableColumns.count, 3u);
    for (NSTableColumn *column in list.tableColumns)
    {
        XCTAssertNotNil(column.sortDescriptorPrototype);
        XCTAssertTrue(column.title.length > 0);
    }
    XCTAssertEqual(list.numberOfRows, 3);
    [open close];
}


- (void)testSortingChangesTheOrderAndSearchNarrowsTheList
{
    MPCloudOpenWindowController *open = MPOpenWindow();
    NSTableView *list = MPTableIn(open.list.view);

    NSString *(^nameOfRow)(NSInteger) = ^NSString *(NSInteger row) {
        NSTableCellView *cell = (NSTableCellView *)[list viewAtColumn:0
                                                                  row:row
                                                      makeIfNecessary:YES];
        return cell.textField.stringValue;
    };
    XCTAssertEqualObjects(nameOfRow(0), @"appunti.md");     // per nome

    list.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"size"
                                                           ascending:NO]];
    XCTAssertEqualObjects(nameOfRow(0), @"spesa.txt");      // il più grosso

    [open.list setFilter:@"verb"];
    XCTAssertEqual(list.numberOfRows, 1);
    XCTAssertEqualObjects(nameOfRow(0), @"verbale.md");

    [open.list setFilter:@""];
    XCTAssertEqual(list.numberOfRows, 3);
    [open close];
}


#pragma mark - Il pannello, dopo la sfoltita

/// Quello che si legge aprendo il pannello è poco: il resto sta dietro il
/// «?», e questa prova è lì perché non ci torni da solo.
- (void)testThePaneSaysLittleAndKeepsTheRestBehindTheHelpButton
{
    MPSyncPreferencesViewController *pane =
        [[MPSyncPreferencesViewController alloc] init];
    (void)pane.view;

    __block NSUInteger words = 0;
    __block BOOL help = NO;
    void (^__block walk)(NSView *) = nil;
    walk = ^(NSView *view) {
        for (NSView *child in view.subviews)
        {
            if (child.hidden)
                continue;
            if ([child isKindOfClass:[NSButton class]]
                    && [(NSButton *)child bezelStyle] == NSBezelStyleHelpButton)
                help = YES;
            if ([child isKindOfClass:[NSTextField class]]
                    && ![child isKindOfClass:[NSSecureTextField class]])
            {
                NSString *said = [(NSTextField *)child stringValue];
                words += [[said componentsSeparatedByCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]]
                        filteredArrayUsingPredicate:[NSPredicate
                            predicateWithFormat:@"length > 0"]].count;
            }
            walk(child);
        }
    };
    walk(pane.view);

    XCTAssertTrue(help, @"il «?» c'è");
    // Prima erano cinque paragrafi: una novantina di parole solo di
    // spiegazioni. Il tetto è largo — serve a fermare il ritorno del muro
    // di testo, non a misurare lo stile.
    XCTAssertLessThan(words, 40u);
}

#pragma mark - iCloud Drive, che è una cartella

/// Il servizio, puntato su una cartella qualunque: `link:` pretende che
/// stia dentro iCloud Drive, ma tutto il resto lavora su una cartella e
/// basta — ed è così che si prova senza toccare la roba di nessuno.
- (MPCloudService *)iCloudOn:(NSURL *)folder
{
    MPCloudService *service = [MPCloudService services][1];
    [service remember:folder];
    return service;
}

- (NSURL *)aFreshFolder
{
    NSURL *folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"icloud-%@",
            [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtURL:folder
        withIntermediateDirectories:YES attributes:nil error:NULL];
    return folder;
}

- (void)write:(NSString *)text named:(NSString *)name in:(NSURL *)folder
{
    [text writeToURL:[folder URLByAppendingPathComponent:name]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

/// Aspetta una risposta che arriva sulla coda principale.
- (void)waitFor:(void (^)(void (^done)(void)))work
{
    XCTestExpectation *waited = [self expectationWithDescription:@"servizio"];
    work(^{ [waited fulfill]; });
    [self waitForExpectations:@[waited] timeout:10.0];
}


- (void)testTheFolderIsTheListOfDocuments
{
    NSURL *folder = [self aFreshFolder];
    [self write:@"# Uno\n" named:@"uno.md" in:folder];
    [self write:@"due" named:@"due.txt" in:folder];
    [self write:@"non è un documento" named:@"foto.png" in:folder];
    MPCloudService *icloud = [self iCloudOn:folder];

    XCTAssertTrue(icloud.isLinked);
    XCTAssertEqualObjects(icloud.placeName, folder.lastPathComponent);

    __block NSArray<MPCloudDocument *> *found = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud documentsWithCompletion:^(NSArray<MPCloudDocument *> *got,
                                          NSString *problem) {
            found = got;
            done();
        }];
    }];

    XCTAssertEqual(found.count, 2u);        // il .png non è un documento
    NSMutableSet *names = [NSMutableSet set];
    for (MPCloudDocument *document in found)
    {
        [names addObject:document.name];
        XCTAssertTrue(document.revision.length > 0);
        XCTAssertNotNil(document.modified);
        XCTAssertTrue(document.size > 0);
    }
    XCTAssertEqualObjects(names, ([NSSet setWithArray:@[@"uno.md",
                                                        @"due.txt"]]));
    [icloud unlink];
}


- (void)testWritingANewDocumentNeverCoversOneThatIsThere
{
    NSURL *folder = [self aFreshFolder];
    [self write:@"quello di prima" named:@"nota.md" in:folder];
    MPCloudService *icloud = [self iCloudOn:folder];

    __block MPCloudDocument *made = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud createDocumentNamed:@"nota.md" text:@"quello nuovo"
                         completion:^(MPCloudDocument *got, NSString *bad) {
            made = got;
            done();
        }];
    }];
    XCTAssertEqualObjects(made.name, @"nota 2.md");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        [folder URLByAppendingPathComponent:@"nota.md"]
        encoding:NSUTF8StringEncoding error:NULL], @"quello di prima");
    [icloud unlink];
}


/// La prova che conta: due Mac sulla stessa cartella. Chi salva per
/// secondo non deve cancellare quello che ha scritto il primo.
- (void)testAWriteThatWouldCoverSomebodyElseStopsOrGoesBeside
{
    NSURL *folder = [self aFreshFolder];
    [self write:@"la mia riga\n" named:@"verbale.md" in:folder];
    MPCloudService *icloud = [self iCloudOn:folder];

    __block NSString *revision = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud documentsWithCompletion:^(NSArray<MPCloudDocument *> *got,
                                          NSString *bad) {
            revision = got.firstObject.revision;
            done();
        }];
    }];
    XCTAssertNotNil(revision);

    // Qualcun altro scrive lì, mentre noi avevamo il documento aperto.
    [NSThread sleepForTimeInterval:0.05];
    [self write:@"la riga di un altro\n" named:@"verbale.md" in:folder];

    __block BOOL moved = NO;
    [self waitFor:^(void (^done)(void)) {
        [icloud writeDocument:@"verbale.md" text:@"la mia versione\n"
                 fromRevision:revision ifMoved:MPCloudOnMovedAsk
                   completion:^(NSString *now, BOOL itMoved,
                                NSString *conflict, NSString *problem) {
            moved = itMoved;
            done();
        }];
    }];
    XCTAssertTrue(moved, @"si è fermato invece di scrivere");
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        [folder URLByAppendingPathComponent:@"verbale.md"]
        encoding:NSUTF8StringEncoding error:NULL], @"la riga di un altro\n");

    // «Tieni entrambi»: la nostra va accanto, con un nome che lo dice.
    __block NSString *conflictName = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud writeDocument:@"verbale.md" text:@"la mia versione\n"
                 fromRevision:revision ifMoved:MPCloudOnMovedCopy
                   completion:^(NSString *now, BOOL itMoved,
                                NSString *conflict, NSString *problem) {
            conflictName = conflict;
            done();
        }];
    }];
    XCTAssertTrue([conflictName hasPrefix:@"verbale (copia in conflitto "]);
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        [folder URLByAppendingPathComponent:conflictName]
        encoding:NSUTF8StringEncoding error:NULL], @"la mia versione\n");
    // E quella dell'altro è ancora lì, intera.
    XCTAssertEqualObjects([NSString stringWithContentsOfURL:
        [folder URLByAppendingPathComponent:@"verbale.md"]
        encoding:NSUTF8StringEncoding error:NULL], @"la riga di un altro\n");
    [icloud unlink];
}


- (void)testTheFirstLookIsQuietAndTheSecondOneCounts
{
    NSURL *folder = [self aFreshFolder];
    [self write:@"uno" named:@"uno.md" in:folder];
    MPCloudService *icloud = [self iCloudOn:folder];
    [[MPCloudLedger ledgerFor:@"icloud"] forget];

    __block MPCloudDelta *first = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud changesWithCompletion:^(MPCloudDelta *delta, NSString *bad) {
            first = delta;
            done();
        }];
    }];
    XCTAssertTrue(first.isQuiet, @"la prima occhiata è il punto di partenza");

    [self write:@"due" named:@"due.md" in:folder];
    __block MPCloudDelta *second = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud changesWithCompletion:^(MPCloudDelta *delta, NSString *bad) {
            second = delta;
            done();
        }];
    }];
    XCTAssertEqual(second.added, 1u);
    XCTAssertEqual(second.changed, 0u);

    // E quello che sparisce si conta come sparito.
    [[NSFileManager defaultManager] removeItemAtURL:
        [folder URLByAppendingPathComponent:@"uno.md"] error:NULL];
    __block MPCloudDelta *third = nil;
    [self waitFor:^(void (^done)(void)) {
        [icloud changesWithCompletion:^(MPCloudDelta *delta, NSString *bad) {
            third = delta;
            done();
        }];
    }];
    XCTAssertEqual(third.removed, 1u);
    XCTAssertEqual(icloud.visibleInPlace, 1);

    [[MPCloudLedger ledgerFor:@"icloud"] forget];
    [icloud unlink];
}

/// I servizi stanno in colonna, uno sotto l'altro: erano schede in fila, e
/// tre nomi lunghi in una riga sola si pestavano i piedi.
- (void)testTheServicesAreAColumnAndNotTabs
{
    MPSyncPreferencesViewController *pane =
        [[MPSyncPreferencesViewController alloc] init];
    NSView *view = pane.view;
    [view layoutSubtreeIfNeeded];

    NSTableView *list = (NSTableView *)[self find:[NSTableView class]
                                               in:view];
    XCTAssertNotNil(list, @"l'elenco dei servizi c'è");
    XCTAssertEqual(list.numberOfRows,
                   (NSInteger)[MPCloudService services].count);
    // E non ci sono schede.
    XCTAssertNil([self find:[NSSegmentedControl class] in:view]);

    NSArray<MPCloudService *> *services = [MPCloudService services];
    for (NSInteger row = 0; row < list.numberOfRows; row++)
    {
        NSTableCellView *cell = (NSTableCellView *)[list viewAtColumn:0
            row:row makeIfNecessary:YES];
        XCTAssertEqualObjects(cell.textField.stringValue,
                              services[(NSUInteger)row].name);
        // Il segnaposto si vede e non si sceglie.
        XCTAssertEqual([list.delegate tableView:list shouldSelectRow:row],
                       services[(NSUInteger)row].available);
    }

    // A sinistra, e il resto a destra: non sopra, non sotto.
    NSRect where = [list convertRect:list.bounds toView:view];
    NSRect field = [pane.clientFieldForTesting
        convertRect:pane.clientFieldForTesting.bounds toView:view];
    XCTAssertLessThanOrEqual(NSMaxX(where), NSMinX(field));
}


/// Niente si disegna sopra niente. È il guaio che si è visto davvero: una
/// NSBox non lega da sola quello che le si mette dentro, e la scheda
/// finiva stampata sopra la riga dei servizi.
- (void)testNothingInThePaneIsDrawnOverSomethingElse
{
    MPSyncPreferencesViewController *pane =
        [[MPSyncPreferencesViewController alloc] init];
    NSView *view = pane.view;
    [view layoutSubtreeIfNeeded];

    NSMutableArray *boxes = [NSMutableArray array];
    void (^__block collect)(NSView *) = nil;
    collect = ^(NSView *parent) {
        for (NSView *child in parent.subviews)
        {
            if (child.hidden)
                continue;
            BOOL interesting = [child isKindOfClass:[NSButton class]]
                || ([child isKindOfClass:[NSTextField class]]
                    && [(NSTextField *)child stringValue].length)
                || [child isKindOfClass:[NSTableView class]];
            if (interesting)
                [boxes addObject:@[[NSValue valueWithRect:
                    [child convertRect:child.bounds toView:view]],
                    child.className]];
            // Le righe di un elenco stanno *dentro* l'elenco: contarle
            // sarebbe contare un contenuto come se fosse un vicino.
            if ([child isKindOfClass:[NSTableView class]])
                continue;
            collect(child);
        }
    };
    collect(view);
    XCTAssertGreaterThan(boxes.count, 4u);

    for (NSUInteger i = 0; i < boxes.count; i++)
    {
        for (NSUInteger j = i + 1; j < boxes.count; j++)
        {
            NSRect one = NSInsetRect([boxes[i][0] rectValue], 1.0, 1.0);
            NSRect two = [boxes[j][0] rectValue];
            XCTAssertFalse(NSIntersectsRect(one, two), @"%@ %@ sopra %@ %@",
                boxes[i][1], NSStringFromRect(one), boxes[j][1],
                NSStringFromRect(two));
        }
    }
}


/// Il primo di una classe, dentro una vista.
- (NSView *)find:(Class)kind in:(NSView *)view
{
    for (NSView *child in view.subviews)
    {
        if ([child isKindOfClass:kind])
            return child;
        NSView *deeper = [self find:kind in:child];
        if (deeper)
            return deeper;
    }
    return nil;
}

@end
