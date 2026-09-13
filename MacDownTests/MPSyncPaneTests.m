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

- (void)testBothProvidersAreThere
{
    NSArray<MPCloudService *> *services = [MPCloudService services];
    XCTAssertEqual(services.count, 2u);
    XCTAssertEqualObjects(services[0].name, @"Google Drive");
    XCTAssertEqualObjects(services[1].name, @"Dropbox");
    // Il secondo è un segnaposto: si vede e non si tocca.
    XCTAssertTrue(services[0].available);
    XCTAssertFalse(services[1].available);
    // E lo dice, invece di lasciare una scheda vuota.
    XCTAssertTrue(services[1].explanation.length > 40);
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


@end
