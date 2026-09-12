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
#import "MPSyncPreferencesViewController.h"


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

@end
