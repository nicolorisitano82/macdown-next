//
//  MPPreviewSelectionTests.m
//  MacDownTests
//
//  Going from what the preview shows back to what the source says.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>

#import "MPPreviewSelection.h"


/// Long enough for a message to arrive, short enough not to hold the suite
/// up if none ever does.
static const NSTimeInterval kMPPatience = 5.0;

/// The page the script is asked about: two blocks, each with the source
/// offset the renderer would have given it.
static NSString * const kMPPage =
    @"<html><body>"
    @"<p data-src='0'>Questo è un test da cancellare, e un altro test.</p>"
    @"<p data-src='33'>E un secondo paragrafo.</p>"
    @"</body></html>";


@interface MPSelectionListener : NSObject <WKScriptMessageHandler>
@property (strong) NSMutableArray<NSDictionary *> *messages;
@property (copy) void (^onMessage)(NSDictionary *body);
@end

@implementation MPSelectionListener

- (instancetype)init
{
    self = [super init];
    if (self)
        _messages = [NSMutableArray array];
    return self;
}

- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    if (![message.body isKindOfClass:[NSDictionary class]])
        return;
    [self.messages addObject:message.body];
    if (self.onMessage)
        self.onMessage(message.body);
}

@end


@interface MPPreviewSelectionTests : XCTestCase
@property (strong) WKWebView *webView;
@property (strong) MPSelectionListener *listener;
@end

@implementation MPPreviewSelectionTests

#pragma mark - The script the preview runs

/// The application's own script, in a web view of the test's own.
- (void)loadPageWithScript
{
    self.listener = [[MPSelectionListener alloc] init];
    WKWebViewConfiguration *configuration =
        [[WKWebViewConfiguration alloc] init];
    [configuration.userContentController addScriptMessageHandler:self.listener
                                                            name:@"macdownSelection"];
    [configuration.userContentController addUserScript:
        [[WKUserScript alloc] initWithSource:MPSelectionWatchScript()
                               injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                            forMainFrameOnly:YES]];
    self.webView = [[WKWebView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 600.0, 400.0)
        configuration:configuration];

    XCTestExpectation *loaded = [self expectationWithDescription:@"loaded"];
    [self.webView loadHTMLString:kMPPage baseURL:nil];
    // No navigation delegate: asking the page a question is the only proof
    // that it is there.
    [self waitForPage:loaded];
}

- (void)waitForPage:(XCTestExpectation *)loaded
{
    __weak typeof(self) weakSelf = self;
    __block void (^again)(void) = nil;
    again = ^{
        [weakSelf.webView evaluateJavaScript:@"typeof window.MacDownMarkHere"
                          completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"function"])
            {
                [loaded fulfill];
                again = nil;
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(0.05 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ if (again) again(); });
        }];
    };
    again();
    [self waitForExpectations:@[loaded] timeout:kMPPatience];
}

/// Selects the word in the first paragraph, the way a reader would, and
/// then lets go of the mouse.
- (void)selectWordAndRelease:(BOOL)release
{
    [self selectOccurrence:1 release:release];
}

/// Selects the first or the second "test" of the first paragraph, the way a
/// reader would, and then lets go of the mouse.
- (void)selectOccurrence:(NSUInteger)which release:(BOOL)release
{
    NSString *script = [NSString stringWithFormat:
        @"var p = document.querySelector('p[data-src=\"0\"]');"
        @"var text = p.firstChild;"
        @"var start = text.data.indexOf('test');"
        @"for (var n = 1; n < %lu; n++)"
        @"start = text.data.indexOf('test', start + 1);",
        (unsigned long)which];
    script = [script stringByAppendingString:
        @"var range = document.createRange();"
        @"range.setStart(text, start);"
        @"range.setEnd(text, start + 4);"
        @"var sel = document.getSelection();"
        @"sel.removeAllRanges(); sel.addRange(range);"];
    if (release)
    {
        script = [script stringByAppendingString:
            @"p.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));"];
    }
    XCTestExpectation *done = [self expectationWithDescription:@"selected"];
    [self.webView evaluateJavaScript:script
                  completionHandler:^(id result, NSError *error) {
        XCTAssertNil(error);
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:kMPPatience];
}

- (NSDictionary *)waitForMessageWhere:(BOOL (^)(NSDictionary *))matches
{
    for (NSDictionary *body in self.listener.messages)
    {
        if (matches(body))
            return body;
    }
    XCTestExpectation *arrived =
        [self expectationWithDescription:@"messaggio"];
    __block NSDictionary *found = nil;
    self.listener.onMessage = ^(NSDictionary *body) {
        if (!found && matches(body))
        {
            found = body;
            [arrived fulfill];
        }
    };
    [self waitForExpectations:@[arrived] timeout:kMPPatience];
    return found;
}

- (void)testTheBlockIsReportedWhileTheSelectionIsBeingMade
{
    [self loadPageWithScript];
    [self selectWordAndRelease:NO];

    // Which block, so the editor can mark it — and no text, because the
    // gesture is not over: taking the focus now would throw the drag.
    NSDictionary *body = [self waitForMessageWhere:^BOOL (NSDictionary *b) {
        return ![b[@"done"] boolValue];
    }];
    XCTAssertEqualObjects(body[@"begin"], @0);
    XCTAssertEqualObjects(body[@"end"], @33);
    XCTAssertEqualObjects(body[@"text"], @"");
}

- (void)testTheTextArrivesWhenTheMouseIsReleased
{
    [self loadPageWithScript];
    [self selectWordAndRelease:YES];

    NSDictionary *body = [self waitForMessageWhere:^BOOL (NSDictionary *b) {
        return [b[@"done"] boolValue];
    }];
    XCTAssertEqualObjects(body[@"text"], @"test");
    XCTAssertEqualObjects(body[@"begin"], @0);

    // And the offsets it reports are the ones that place the word: the
    // block, and then the text inside it.
    NSString *source = @"Questo è un test da cancellare.\n\nE un secondo.";
    NSRange block = NSMakeRange(0, 31);
    NSRange range = MPSourceRangeForPreviewText(source, body[@"text"],
                                                block, NSNotFound);
    XCTAssertEqualObjects([source substringWithRange:range], @"test");
}

- (void)testThePageSaysWhichOccurrenceWasSelected
{
    [self loadPageWithScript];
    [self selectOccurrence:2 release:YES];

    NSDictionary *body = [self waitForMessageWhere:^BOOL (NSDictionary *b) {
        return [b[@"done"] boolValue];
    }];
    XCTAssertEqualObjects(body[@"text"], @"test");

    // The rendered offset of the *second* "test", counted in the page's own
    // text — which is what tells it from the first.
    NSString *rendered = @"Questo è un test da cancellare, e un altro test.";
    NSUInteger second = [rendered rangeOfString:@"test"
        options:NSBackwardsSearch].location;
    XCTAssertEqual((NSUInteger)[body[@"offset"] integerValue], second);

    // And with that offset the right one is placed in a source that says
    // "test" twice.
    NSString *source = @"Questo è un **test** da cancellare, e un altro "
        @"*test*.";
    NSRange range = MPSourceRangeForPreviewText(source, body[@"text"],
        NSMakeRange(0, source.length),
        (NSUInteger)[body[@"offset"] integerValue]);
    XCTAssertEqual(range.location, [source rangeOfString:@"test"
        options:NSBackwardsSearch].location);
}

/// The whole source as the search window, for the cases where the block
/// does not matter.
- (NSRange)rangeOf:(NSString *)selected in:(NSString *)source
{
    return MPSourceRangeForPreviewText(source, selected,
                                       NSMakeRange(0, source.length),
                                       NSNotFound);
}


#pragma mark - The plain case

- (void)testAWordIsFoundWhereItIs
{
    NSString *source = @"Questo è un test da cancellare.";
    NSRange range = [self rangeOf:@"test" in:source];
    XCTAssertEqualObjects([source substringWithRange:range], @"test");
    XCTAssertEqual(range.location, [source rangeOfString:@"test"].location);
}

- (void)testASentenceIsFoundWhole
{
    NSString *source = @"Prima riga.\n\nQuesto è il testo da prendere.\n";
    NSRange range = [self rangeOf:@"il testo da prendere" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"il testo da prendere");
}

- (void)testWhatTheBrowserTrimsIsTrimmedHere
{
    // A selection dragged past the end of a paragraph comes back with the
    // newline in it.
    NSString *source = @"Un paragrafo solo.\n\nUn altro.\n";
    NSRange range = [self rangeOf:@"  Un paragrafo solo.\n" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"Un paragrafo solo.");
}


#pragma mark - Where the rendered text is not the source

- (void)testALineBreakInTheSourceIsASpaceInThePreview
{
    // The source wrapped the line; the browser handed back one space.
    NSString *source = @"Una frase che\ncontinua sotto.\n";
    NSRange range = [self rangeOf:@"frase che continua" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"frase che\ncontinua");
}

- (void)testASelectionAcrossAnEmphasisSpansTheMarkup
{
    // The reader saw "questo è grassetto qui"; the source has asterisks in
    // it, so only the span from the first word to the last can be found.
    NSString *source = @"Dice questo è **grassetto** qui, e basta.";
    NSRange range = [self rangeOf:@"questo è grassetto qui" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"questo è **grassetto** qui");
}

- (void)testASpanThatWouldSwallowAParagraphIsRefused
{
    NSString *source = @"test all'inizio, e poi mille parole in mezzo che "
        @"non c'entrano niente con la selezione e continuano ancora per un "
        @"po', prima di arrivare alla fine.";
    // "test fine" as a selection would only make sense if the two were
    // close: they are a hundred characters apart.
    NSRange range = [self rangeOf:@"test fine" in:source];
    XCTAssertEqual(range.location, NSNotFound);
}


#pragma mark - Which one of many

- (void)testTheOccurrenceInsideTheBlockWins
{
    NSString *source = @"test in cima.\n\nAltro.\n\ntest in fondo.\n";
    NSRange block = [source rangeOfString:@"test in fondo"];
    block.length = source.length - block.location;
    NSRange range = MPSourceRangeForPreviewText(source, @"test", block,
                                                NSNotFound);
    XCTAssertEqual(range.location,
                   [source rangeOfString:@"test in fondo"].location);
}

- (void)testABlockThatHasMovedStillFindsItsText
{
    // The page was drawn before the reader typed a paragraph above: the
    // offsets are stale, and the text is still in the document.
    NSString *source = @"Aggiunto dopo.\n\nQuesto è il testo.\n";
    NSRange stale = NSMakeRange(source.length - 3, 3);
    NSRange range = MPSourceRangeForPreviewText(source, @"il testo", stale,
                                                NSNotFound);
    XCTAssertEqualObjects([source substringWithRange:range], @"il testo");
}

- (void)testABlockPastTheEndOfTheSourceIsIgnored
{
    NSString *source = @"Poche parole.";
    NSRange range = MPSourceRangeForPreviewText(source, @"parole",
                                                NSMakeRange(9000, 40),
                                                NSNotFound);
    XCTAssertEqualObjects([source substringWithRange:range], @"parole");
}


/// What the page is painting, if anything.
- (BOOL)highlightIsPainted
{
    XCTestExpectation *asked = [self expectationWithDescription:@"chiesto"];
    __block BOOL painted = NO;
    [self.webView evaluateJavaScript:
        @"(typeof CSS!=='undefined'&&CSS.highlights"
        @"&&CSS.highlights.has('macdown-picked'))?1:0"
                   completionHandler:^(id result, NSError *error) {
        painted = [result boolValue];
        [asked fulfill];
    }];
    [self waitForExpectations:@[asked] timeout:kMPPatience];
    return painted;
}

- (void)testWhatWasSelectedStaysPaintedWhenTheFocusLeaves
{
    [self loadPageWithScript];
    XCTAssertFalse([self highlightIsPainted]);

    [self selectWordAndRelease:YES];
    [self waitForMessageWhere:^BOOL (NSDictionary *b) {
        return [b[@"done"] boolValue];
    }];
    // The editor is about to take the focus, and the native selection with
    // it: this is what is left behind for the reader to see.
    XCTAssertTrue([self highlightIsPainted]);
}

- (void)testTheNextGestureTakesTheMarkAway
{
    [self loadPageWithScript];
    [self selectWordAndRelease:YES];
    [self waitForMessageWhere:^BOOL (NSDictionary *b) {
        return [b[@"done"] boolValue];
    }];
    XCTAssertTrue([self highlightIsPainted]);

    XCTestExpectation *pressed = [self expectationWithDescription:@"premuto"];
    [self.webView evaluateJavaScript:
        @"document.querySelector('p').dispatchEvent("
        @"new MouseEvent('mousedown',{bubbles:true}))"
                   completionHandler:^(id result, NSError *error) {
        [pressed fulfill];
    }];
    [self waitForExpectations:@[pressed] timeout:kMPPatience];
    XCTAssertFalse([self highlightIsPainted]);
}


#pragma mark - Which occurrence of the same words

/// Where the reader was, counted in the *rendered* text of the block.
- (NSRange)rangeOf:(NSString *)selected in:(NSString *)source
             after:(NSUInteger)renderedOffset
{
    return MPSourceRangeForPreviewText(source, selected,
                                       NSMakeRange(0, source.length),
                                       renderedOffset);
}

- (void)testTheSecondTestIsTheSecondTest
{
    NSString *source = @"Un test qui, e un altro test più in là, e basta.";
    NSUInteger first = [source rangeOfString:@"test"].location;
    NSUInteger second = [source rangeOfString:@"test"
        options:NSBackwardsSearch].location;
    XCTAssertNotEqual(first, second);

    // Senza sapere dove fosse il lettore, la prima.
    XCTAssertEqual([self rangeOf:@"test" in:source].location, first);
    // Sapendolo, quella vicina.
    XCTAssertEqual([self rangeOf:@"test" in:source after:3].location, first);
    XCTAssertEqual([self rangeOf:@"test" in:source
                           after:second].location, second);
}

- (void)testThePointerIsAFloorAndNotAnAnswer
{
    // The source has markup the page does not show, so the same words sit
    // further along in the source than the page counted. The nearest match
    // is still the right one.
    NSString *source = @"**test** in cima, e poi *test* in fondo.";
    NSUInteger second = [source rangeOfString:@"test"
        options:NSBackwardsSearch].location;
    XCTAssertEqual([self rangeOf:@"test" in:source after:20].location,
                   second);
}

- (void)testTheOffsetCountsInsideTheBlockAndNotTheDocument
{
    NSString *source = @"Prima riga.\n\ntest qui e test là.\n";
    NSRange block = [source rangeOfString:@"test qui e test là."];
    block.length = source.length - block.location;
    NSUInteger inBlock = [@"test qui e " length];
    NSRange range = MPSourceRangeForPreviewText(source, @"test", block,
                                                inBlock);
    XCTAssertEqual(range.location,
                   [source rangeOfString:@"test là"].location);
}


#pragma mark - What the renderer changed on the way out

- (void)testCurlyQuotesFindTheStraightOnes
{
    // Smartypants shows “così”; the writer typed "così".
    NSString *source = @"Dice \"così\" e poi basta.";
    NSRange range = [self rangeOf:@"“così” e poi" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"\"così\" e poi");
}

- (void)testACurlyApostropheFindsTheTypedOne
{
    NSString *source = @"Con l'editor aperto.";
    NSRange range = [self rangeOf:@"l’editor" in:source];
    XCTAssertEqualObjects([source substringWithRange:range], @"l'editor");
}

- (void)testADashFindsTheHyphens
{
    NSString *source = @"Le pagine 10--12 sono da rifare.";
    NSRange range = [self rangeOf:@"10–12 sono" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"10--12 sono");

    NSString *lungo = @"Un inciso --- messo lì --- che rompe.";
    XCTAssertEqualObjects([lungo substringWithRange:
        [self rangeOf:@"inciso — messo" in:lungo]], @"inciso --- messo");
}

- (void)testAnEllipsisFindsTheThreeDots
{
    NSString *source = @"Aspetta... e poi vai.";
    NSRange range = [self rangeOf:@"Aspetta… e poi" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"Aspetta... e poi");
}

- (void)testAnEntityFindsWhatItStandsFor
{
    NSString *source = @"Tizio &amp; Caio, soci.";
    NSRange range = [self rangeOf:@"Tizio & Caio" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"Tizio &amp; Caio");
}

- (void)testWhatIsAlreadyStraightStillMatches
{
    // The reader may have Smartypants off, and then the page shows exactly
    // what the source says.
    NSString *source = @"Dice \"così\" e l'altro \"cosà\".";
    XCTAssertEqualObjects([source substringWithRange:
        [self rangeOf:@"\"cosà\"" in:source]], @"\"cosà\"");
    XCTAssertEqualObjects([source substringWithRange:
        [self rangeOf:@"l'altro" in:source]], @"l'altro");
}


#pragma mark - When to do nothing

- (void)testTextThatIsNotThereIsNotPlaced
{
    NSRange range = [self rangeOf:@"non compare da nessuna parte"
                               in:@"Un documento breve."];
    XCTAssertEqual(range.location, NSNotFound);
}

- (void)testOneLetterSaysNothingAboutWhereItCameFrom
{
    NSRange range = [self rangeOf:@"a" in:@"a b a b a"];
    XCTAssertEqual(range.location, NSNotFound);
}

- (void)testNothingSelectedIsNothingToDo
{
    XCTAssertEqual([self rangeOf:@"" in:@"Testo."].location, NSNotFound);
    XCTAssertEqual([self rangeOf:@"   \n" in:@"Testo."].location,
                   NSNotFound);
    XCTAssertEqual([self rangeOf:@"testo" in:@""].location, NSNotFound);
}

- (void)testTheSelectionIsTextAndNotAPattern
{
    // Anything the reader can select can also be a regular expression, and
    // must not be treated as one.
    NSString *source = @"La formula (a+b)* vale sempre.";
    NSRange range = [self rangeOf:@"(a+b)*" in:source];
    XCTAssertEqualObjects([source substringWithRange:range], @"(a+b)*");

    XCTAssertEqual([self rangeOf:@"a+b" in:@"La formula aaab vale."].location,
                   NSNotFound);
}

- (void)testAccentedTextIsFoundWhereItIs
{
    NSString *source = @"Città e perché, così com'è scritto.";
    NSRange range = [self rangeOf:@"perché, così" in:source];
    XCTAssertEqualObjects([source substringWithRange:range],
                          @"perché, così");
}

@end
