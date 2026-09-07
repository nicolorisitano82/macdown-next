//
//  MPActionLogTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "MPActionLog.h"


@interface MPActionLogTests : XCTestCase
@end


@implementation MPActionLogTests

- (void)setUp
{
    [super setUp];
    [[MPActionLog sharedLog] clear];
}

- (void)tearDown
{
    [MPActionLog sharedLog].recording = NO;
    [[MPActionLog sharedLog] clear];
    [super tearDown];
}

- (void)testNothingIsWrittenUntilItIsSwitchedOn
{
    MPActionLog *log = [MPActionLog sharedLog];
    XCTAssertFalse(log.recording, @"si accende a mano, non da sola");

    MPNote(@"questo non deve finire da nessuna parte");
    XCTAssertEqualObjects(log.text, @"");
    XCTAssertFalse([[NSFileManager defaultManager]
        fileExistsAtPath:log.fileURL.path],
        @"con la registrazione spenta il file non si crea nemmeno");
}

- (void)testWhatIsWrittenAndHowItReads
{
    MPActionLog *log = [MPActionLog sharedLog];
    log.recording = YES;

    MPNote(@"piega la sezione a %lu: %@", (unsigned long)42, @"fatto");
    MPNote(@"sezioni: %lu", (unsigned long)3);

    // Written on a queue of its own, so the reading waits for it: -text
    // goes through the same queue, which is the point of having one.
    NSString *text = log.text;
    XCTAssertTrue([text containsString:@"piega la sezione a 42: fatto"]);
    XCTAssertTrue([text containsString:@"sezioni: 3"]);

    // A time and a number in front of each line: the number is what tells
    // two identical commands apart, and the time is where they went.
    NSArray *lines = [[text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]]
        componentsSeparatedByString:@"\n"];
    // The line that says the recording started, then the two above.
    XCTAssertEqual(lines.count, 3u);
    XCTAssertTrue([lines[0] containsString:@"recording started"]);
    XCTAssertTrue([lines[1] containsString:@"   2  "],
                  @"manca il numero di sequenza: %@", lines[1]);
}

- (void)testStoppingAndEmptyingIt
{
    MPActionLog *log = [MPActionLog sharedLog];
    log.recording = YES;
    MPNote(@"qualcosa");
    log.recording = NO;

    XCTAssertTrue([log.text containsString:@"recording stopped"]);
    MPNote(@"e questo no");
    XCTAssertFalse([log.text containsString:@"e questo no"]);

    [log clear];
    XCTAssertEqualObjects(log.text, @"");
}

- (void)testItLivesWhereLogsLive
{
    NSURL *url = [MPActionLog sharedLog].fileURL;
    XCTAssertTrue([url.path containsString:@"/Library/Logs/"],
                  @"%@", url.path);
    XCTAssertEqualObjects(url.lastPathComponent, @"actions.log");
}

@end
