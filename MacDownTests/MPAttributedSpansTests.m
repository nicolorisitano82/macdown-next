//
//  MPAttributedSpansTests.m
//  MacDownTests
//
//  `[testo]{...}` — what becomes a span, what stays written, and what is
//  not let through. The last one is the reason this file is long: a
//  Markdown file is often something somebody else wrote, and the preview
//  is a web view.
//

#import <XCTest/XCTest.h>

#import "MPAttributedSpans.h"


@interface MPAttributedSpansTests : XCTestCase
@end


@implementation MPAttributedSpansTests

- (void)assert:(NSString *)markdown gives:(NSString *)html
{
    XCTAssertEqualObjects(MPMarkdownWithAttributedSpans(markdown), html);
}

/// What a document that was not understood should get back: itself.
- (void)assertUntouched:(NSString *)markdown
{
    XCTAssertEqualObjects(MPMarkdownWithAttributedSpans(markdown), markdown,
                          @"«%@» should have been left as written", markdown);
}


#pragma mark - The spelling Djot and Pandoc agree on

- (void)testAColourBecomesASpan
{
    [self assert:@"Rosso: [acceso]{style=\"color:#c00\"}."
           gives:@"Rosso: <span style=\"color:#c00\">acceso</span>."];
}

- (void)testAClassAndAnIdentifier
{
    [self assert:@"[a]{.avviso}" gives:@"<span class=\"avviso\">a</span>"];
    [self assert:@"[b]{#qui}" gives:@"<span id=\"qui\">b</span>"];
    [self assert:@"[c]{.x .y}" gives:@"<span class=\"x y\">c</span>"];
}

- (void)testTheAttributesComeOutInTheSameOrderEveryTime
{
    // Otherwise the same document renders differently twice, and a preview
    // that reshuffles itself is a difference nobody asked for.
    NSString *once = MPMarkdownWithAttributedSpans(
        @"[x]{lang=it .a #b style=\"color:red\" title=\"t\"}");
    XCTAssertEqualObjects(once, @"<span id=\"b\" class=\"a\" "
                                @"style=\"color:red\" title=\"t\" "
                                @"lang=\"it\">x</span>");
}

- (void)testAValueMayHoldSpacesAndBraces
{
    [self assert:@"[x]{title=\"a } b\"}"
           gives:@"<span title=\"a } b\">x</span>"];
}

- (void)testWhatIsInsideIsStillMarkdown
{
    // hoedown reads the span as inline HTML and goes on parsing round it,
    // so the emphasis inside has to survive this pass untouched.
    [self assert:@"[**forte**]{.a}" gives:@"<span class=\"a\">**forte**</span>"];
}

- (void)testASpanInsideASpan
{
    [self assert:@"[fuori [dentro]{.b}]{.a}"
           gives:@"<span class=\"a\">fuori <span class=\"b\">dentro</span>"
                 @"</span>"];
}


#pragma mark - What it must not touch

- (void)testALinkIsALink
{
    [self assertUntouched:@"un [collegamento](http://esempio.it) e basta"];
    [self assertUntouched:@"un [riferimento][1] e basta"];
    [self assertUntouched:@"[1]: http://esempio.it"];
}

- (void)testAnImageKeepsItsOwnBrackets
{
    [self assertUntouched:@"![schema]{.a}"];
}

- (void)testCodeIsLeftAlone
{
    [self assertUntouched:@"`[x]{.a}` fra apici"];
    [self assertUntouched:@"```\n[x]{.a}\n```\n"];
    [self assertUntouched:@"    [x]{.a}\n"];
}

- (void)testBracesThatAreNotAttributes
{
    [self assertUntouched:@"[x]{}"];
    [self assertUntouched:@"[x]{ }"];
    [self assertUntouched:@"[x]{non attributi}"];
    [self assertUntouched:@"[x]{.}"];
    [self assertUntouched:@"[x]{a=\"non chiuso}"];
    [self assertUntouched:@"niente { } qui"];
    // Attributes do not cross a line: this is a paragraph, not a span.
    [self assertUntouched:@"[x]{style=\"color:red\"\n}"];
}

- (void)testTextWithNoBracesComesBackAsItself
{
    NSString *plain = @"# Titolo\n\nUna riga qualunque.\n";
    [self assertUntouched:plain];
}


#pragma mark - What a document is not allowed to do

- (void)testAnEventHandlerIsNotAnAttribute
{
    [self assertUntouched:@"[x]{onclick=\"alert(1)\"}"];
    [self assertUntouched:@"[x]{onmouseover=\"alert(1)\"}"];
}

- (void)testAnHandlerNextToARealAttributeIsDroppedAndTheRestKept
{
    [self assert:@"[x]{.ok onclick=\"alert(1)\"}"
           gives:@"<span class=\"ok\">x</span>"];
}

- (void)testStyleThatFetchesIsDroppedWhole
{
    // Half-cleaned CSS is how these get through, so the declaration goes
    // rather than the offending word inside it.
    [self assertUntouched:@"[x]{style=\"background:url(http://esempio.it/a)\"}"];
    [self assertUntouched:@"[x]{style=\"@import 'http://esempio.it/a'\"}"];
    [self assertUntouched:@"[x]{style=\"color:javascript:alert(1)\"}"];
}

- (void)testWhatGoesIntoAnAttributeIsEscaped
{
    [self assert:@"[x]{title=\"<b> & </b>\"}"
           gives:@"<span title=\"&lt;b&gt; &amp; &lt;/b&gt;\">x</span>"];
}

- (void)testABackslashInAValueTakesTheNextCharacterAsItself
{
    // Which is the only way a value can carry the quote that ends it.
    [self assert:@"[x]{title=\"dice \\\"ciao\\\"\"}"
           gives:@"<span title=\"dice &quot;ciao&quot;\">x</span>"];
}

- (void)testDataAttributesAreAllowedBecauseTheyDoNothing
{
    [self assert:@"[x]{data-nota=\"tre\"}"
           gives:@"<span data-nota=\"tre\">x</span>"];
}


#pragma mark - Writing one

- (void)testColouringPlainWords
{
    XCTAssertEqualObjects(MPSpanColouring(@"ciao", @"#cc0000"),
                          @"[ciao]{style=\"color:#cc0000\"}");
}

- (void)testColouringSomethingAlreadyColouredChangesTheColour
{
    // Not a span around a span: somebody who changes their mind twice
    // should not end up two deep.
    XCTAssertEqualObjects(
        MPSpanColouring(@"[ciao]{style=\"color:#000000\"}", @"#00aa00"),
        @"[ciao]{style=\"color:#00aa00\"}");
}

- (void)testColouringKeepsTheOtherAttributes
{
    XCTAssertEqualObjects(MPSpanColouring(@"[ciao]{.avviso}", @"#00aa00"),
                          @"[ciao]{.avviso style=\"color:#00aa00\"}");
    XCTAssertEqualObjects(
        MPSpanColouring(@"[ciao]{style=\"font-weight:bold\"}", @"#00aa00"),
        @"[ciao]{style=\"font-weight:bold;color:#00aa00\"}");
}

- (void)testWhatIsWrittenIsWhatIsRead
{
    NSString *written = MPSpanColouring(@"parola", @"#123456");
    [self assert:written
           gives:@"<span style=\"color:#123456\">parola</span>"];
}

@end
