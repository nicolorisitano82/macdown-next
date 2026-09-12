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

#import "MPGoogleDrive.h"
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

- (void)testTheConsentURLIsTheOneGoogleDocuments
{
    NSURL *url = MPGoogleConsentURL(@"123.apps.googleusercontent.com",
                                    @"http://127.0.0.1:5000/x", @"SFIDA");
    NSString *text = url.absoluteString;
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
}

- (void)testThePKCEChallengeIsTheSHA256InBase64URL
{
    // Il vettore di prova della RFC 7636.
    NSString *verifier = @"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    XCTAssertEqualObjects(MPGooglePKCEChallenge(verifier),
                          @"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
}

- (void)testNothingIsConfiguredUntilThereIsAClientThatLooksLikeOne
{
    MPGoogleDrive *drive = [MPGoogleDrive sharedDrive];
    NSString *was = drive.clientIdentifier;

    drive.clientIdentifier = @"";
    XCTAssertFalse(drive.isConfigured);
    drive.clientIdentifier = @"non è un client";
    XCTAssertFalse(drive.isConfigured);
    drive.clientIdentifier = @" 123-abc.apps.googleusercontent.com ";
    XCTAssertTrue(drive.isConfigured);
    // Gli spazi intorno a una cosa incollata non sono parte della cosa.
    XCTAssertEqualObjects(drive.clientIdentifier,
                          @"123-abc.apps.googleusercontent.com");

    drive.clientIdentifier = was;
}

@end
