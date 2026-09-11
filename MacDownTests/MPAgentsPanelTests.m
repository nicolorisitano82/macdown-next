//
//  MPAgentsPanelTests.m
//  MacDownTests
//
//  The panel that says what an assistant may do with a folder: the line it
//  hands over, and the log it shows.
//

#import <XCTest/XCTest.h>

#import "MPAgentsPreferencesViewController.h"
#import "MPPreferences.h"


@interface MPAgentsPreferencesViewController (Testing)
- (NSString *)command;
- (NSURL *)logURL;
- (void)showWhatWeKnow;
- (void)showTheDiary;
- (void)clearLog:(id)sender;
@end


@interface MPAgentsPanelTests : XCTestCase
@property (strong) MPAgentsPreferencesViewController *panel;
@property (strong) NSString *oldFolder;
@property (assign) NSInteger oldLevel;
@property (assign) BOOL oldAllowed;
@end


@implementation MPAgentsPanelTests

- (void)setUp
{
    [super setUp];
    MPPreferences *preferences = [MPPreferences sharedInstance];
    self.oldFolder = [preferences.agentsFolderPath copy];
    self.oldLevel = preferences.agentsWritingLevel;
    self.oldAllowed = preferences.agentsAllowed;

    self.panel = [[MPAgentsPreferencesViewController alloc] init];
    [self.panel loadView];
}

- (void)tearDown
{
    MPPreferences *preferences = [MPPreferences sharedInstance];
    preferences.agentsFolderPath = self.oldFolder;
    preferences.agentsWritingLevel = self.oldLevel;
    preferences.agentsAllowed = self.oldAllowed;
    [preferences synchronize];
    [super tearDown];
}

- (void)testThePanelIsAPanel
{
    XCTAssertNotNil(self.panel.view);
    XCTAssertEqualObjects([self.panel viewIdentifier], @"AgentsPreferences");
    XCTAssertTrue([self.panel toolbarItemLabel].length > 0);
    XCTAssertNotNil([self.panel toolbarItemImage]);
}

- (void)testTheLineSaysTheFolderAndTheLevel
{
    MPPreferences *preferences = [MPPreferences sharedInstance];
    preferences.agentsFolderPath = @"/Users/qualcuno/Verbali";
    preferences.agentsWritingLevel = 0;
    NSString *reading = [self.panel command];
    XCTAssertTrue([reading containsString:@"macdownext-mcp"]);
    XCTAssertTrue([reading containsString:@"--root \"/Users/qualcuno/Verbali\""]);
    // Reading asks for nothing: the level that can do damage has to be
    // typed on purpose, even by the panel that offers it.
    XCTAssertFalse([reading containsString:@"--append"]);
    XCTAssertFalse([reading containsString:@"--write"]);

    preferences.agentsWritingLevel = 1;
    XCTAssertTrue([[self.panel command] containsString:@"--append"]);
    preferences.agentsWritingLevel = 2;
    XCTAssertTrue([[self.panel command] containsString:@"--write"]);
}

- (void)testWithNoFolderTheLineIsStillReadable
{
    MPPreferences *preferences = [MPPreferences sharedInstance];
    preferences.agentsFolderPath = nil;
    NSString *line = [self.panel command];
    // A stand-in rather than an empty pair of quotes: somebody reading the
    // line should see where their own folder goes.
    XCTAssertTrue([line containsString:@"--root"]);
    XCTAssertFalse([line containsString:@"--root \"\""]);
}

- (void)testAFolderWithAQuoteInItDoesNotBreakTheLine
{
    MPPreferences *preferences = [MPPreferences sharedInstance];
    preferences.agentsFolderPath = @"/Users/qualcuno/di \"prova\"";
    NSString *line = [self.panel command];
    // The quote is escaped rather than closing the argument early, which is
    // what a shell would otherwise make of it.
    XCTAssertTrue([line containsString:@"\\\"prova\\\""]);
}

- (void)testTheSwitchIsThePreference
{
    MPPreferences *preferences = [MPPreferences sharedInstance];
    preferences.agentsAllowed = NO;
    [self.panel showWhatWeKnow];
    NSButton *box = nil;
    for (NSView *view in [self allViewsIn:self.panel.view])
    {
        if (![view isKindOfClass:[NSButton class]])
            continue;
        // By what it does, not by how it looks: the switch is the button
        // that answers to toggleAllowed:.
        if ([(NSButton *)view action] == @selector(toggleAllowed:))
        {
            box = (NSButton *)view;
            break;
        }
    }
    XCTAssertNotNil(box);
    XCTAssertEqual(box.state, NSControlStateValueOff);

    preferences.agentsAllowed = YES;
    [self.panel showWhatWeKnow];
    XCTAssertEqual(box.state, NSControlStateValueOn);
}

- (void)testTheLogIsShownAndCanBeEmptied
{
    NSURL *log = [self.panel logURL];
    XCTAssertEqualObjects(log.lastPathComponent, @"mcp.log");

    NSString *kept = [NSString stringWithContentsOfURL:log
        encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtURL:
        log.URLByDeletingLastPathComponent withIntermediateDirectories:YES
        attributes:nil error:NULL];
    NSString *line = @"2026-09-11T20:00:00Z  read  ok  prova.md  1 di 1\n";
    [line writeToURL:log atomically:YES encoding:NSUTF8StringEncoding
               error:NULL];

    [self.panel showTheDiary];
    NSTextView *view = [self diaryViewIn:self.panel.view];
    XCTAssertNotNil(view);
    XCTAssertTrue([view.string containsString:@"prova.md"]);

    [self.panel clearLog:nil];
    XCTAssertFalse([[NSFileManager defaultManager]
        fileExistsAtPath:log.path]);
    XCTAssertEqual(view.string.length, 0u);

    // Somebody's own log is not this test's to throw away.
    if (kept)
        [kept writeToURL:log atomically:YES encoding:NSUTF8StringEncoding
                   error:NULL];
}


#pragma mark - Looking through the panel

- (NSArray<NSView *> *)allViewsIn:(NSView *)view
{
    NSMutableArray<NSView *> *found = [NSMutableArray arrayWithObject:view];
    for (NSView *child in view.subviews)
        [found addObjectsFromArray:[self allViewsIn:child]];
    return found;
}

- (NSTextView *)diaryViewIn:(NSView *)view
{
    for (NSView *one in [self allViewsIn:view])
    {
        if ([one isKindOfClass:[NSTextView class]])
            return (NSTextView *)one;
    }
    return nil;
}

@end
