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
#import "MPSpanStyler.h"


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

- (void)testASpanDoesNotCrossAParagraph
{
    // Inline, in Djot as in Pandoc. Found by selecting more than was
    // meant and asking the menu to colour it: what came out was brackets
    // round half a document and nothing different on the page.
    [self assertUntouched:@"[uno\n\ndue]{style=\"color:red\"}"];
    [self assertUntouched:@"[uno\n   \ndue]{.a}"];
    // A single line break inside a paragraph is not a break.
    [self assert:@"[uno\ndue]{.a}" gives:@"<span class=\"a\">uno\ndue</span>"];

    XCTAssertTrue(MPTextHasABlankLine(@"uno\n\ndue"));
    XCTAssertTrue(MPTextHasABlankLine(@"uno\n \t \ndue"));
    XCTAssertFalse(MPTextHasABlankLine(@"uno\ndue"));
    XCTAssertFalse(MPTextHasABlankLine(@"una riga sola"));
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

- (void)testTheHighlightAndTheColourLiveInTheSameSpan
{
    // Somebody who colours the words and then highlights them should end
    // up with one span saying both, not two nested.
    NSString *coloured = MPSpanWithStyle(@"ciao", @"color", @"#cc0000");
    NSString *both = MPSpanWithStyle(coloured, @"background-color",
                                     @"#ffff00");
    XCTAssertEqualObjects(both,
        @"[ciao]{style=\"color:#cc0000;background-color:#ffff00\"}");
    [self assert:both gives:@"<span style=\"color:#cc0000;"
                            @"background-color:#ffff00\">ciao</span>"];
}

- (void)testASizeIsJustAnotherDeclaration
{
    XCTAssertEqualObjects(
        MPSpanWithStyle(@"[ciao]{style=\"color:red\"}", @"font-size", @"1.6em"),
        @"[ciao]{style=\"color:red;font-size:1.6em\"}");
}

- (void)testWhatThisDoesNotHandleIsNotThrownAway
{
    // The one thing a document must be able to count on: an attribute or a
    // declaration this knows nothing about is still there afterwards.
    NSString *written = @"[x]{#q .a data-n=\"1\" onclick=\"alert(1)\" "
                        @"style=\"letter-spacing:2px;color:#000\"}";
    NSString *after = MPSpanWithStyle(written, @"color", @"#0a0");
    XCTAssertEqualObjects(after,
        @"[x]{#q .a data-n=\"1\" onclick=\"alert(1)\" "
        @"style=\"letter-spacing:2px;color:#0a0\"}");
}

- (void)testTakingOneDeclarationOffLeavesTheRest
{
    NSString *written = @"[x]{.a style=\"letter-spacing:2px;color:#000\"}";
    XCTAssertEqualObjects(MPSpanWithStyle(written, @"color", nil),
                          @"[x]{.a style=\"letter-spacing:2px\"}");
}

- (void)testASpanLeftSayingNothingGivesBackTheWords
{
    XCTAssertEqualObjects(
        MPSpanWithStyle(@"[ciao]{style=\"color:#000\"}", @"color", nil),
        @"ciao");
    // But one that still says something stays a span.
    XCTAssertEqualObjects(
        MPSpanWithStyle(@"[ciao]{.a style=\"color:#000\"}", @"color", nil),
        @"[ciao]{.a}");
}

- (void)testEditingASpanThisWouldNotRenderStillEditsIt
{
    // The style is refused by the page — it fetches — so nothing of it
    // survives the sanitising. It is still a span somebody wrote, and
    // wrapping a second one round it would be a way of losing it.
    NSString *written = @"[x]{style=\"background:url(http://e.it)\"}";
    XCTAssertEqualObjects(MPSpanWithStyle(written, @"color", @"#0a0"),
        @"[x]{style=\"background:url(http://e.it);color:#0a0\"}");
}

- (void)testASizeInEveryFormSomebodyWrites
{
    XCTAssertEqualWithAccuracy(MPSizeFromCSS(@"1.5em", 14.0), 21.0, 0.01);
    XCTAssertEqualWithAccuracy(MPSizeFromCSS(@"150%", 14.0), 21.0, 0.01);
    XCTAssertEqualWithAccuracy(MPSizeFromCSS(@"18pt", 14.0), 18.0, 0.01);
    XCTAssertEqualWithAccuracy(MPSizeFromCSS(@"18px", 14.0), 18.0, 0.01);
    XCTAssertEqualWithAccuracy(MPSizeFromCSS(@"larger", 10.0), 12.0, 0.01);
    // A unit this does not know is left to the preview, not guessed at.
    XCTAssertEqual(MPSizeFromCSS(@"2vw", 14.0), 0.0);
    XCTAssertEqual(MPSizeFromCSS(@"", 14.0), 0.0);
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


#pragma mark - Where they are, for the editor

- (void)testTheScannerSaysWhereTheWordsAre
{
    NSString *text = @"Una [parola]{style=\"color:#c00\"} qui";
    NSArray<MPAttributedSpan *> *spans = MPAttributedSpansIn(text);
    XCTAssertEqual(spans.count, 1u);

    MPAttributedSpan *span = spans.firstObject;
    // The whole construct, and the words inside it: the editor hides the
    // first and paints the second, so both have to be right.
    XCTAssertEqualObjects([text substringWithRange:span.range],
                          @"[parola]{style=\"color:#c00\"}");
    XCTAssertEqualObjects([text substringWithRange:span.content], @"parola");
    XCTAssertEqualObjects(span.attributes[@"style"], @"color:#c00");
}

- (void)testTheScannerAndTheRewritingAgree
{
    // Two readings of the same syntax would be two answers: the editor
    // would hide braces the preview had not turned into anything.
    NSString *text = @"[a]{.x} e [b](http://e.it) e `[c]{.y}` e [d]{#z}";
    NSArray<MPAttributedSpan *> *spans = MPAttributedSpansIn(text);
    XCTAssertEqual(spans.count, 2u);
    XCTAssertEqualObjects([text substringWithRange:spans[0].content], @"a");
    XCTAssertEqualObjects([text substringWithRange:spans[1].content], @"d");
}

- (void)testWhatTheScannerFindsInNothing
{
    XCTAssertEqual(MPAttributedSpansIn(@"").count, 0u);
    XCTAssertEqual(MPAttributedSpansIn(@"niente di niente").count, 0u);
}


#pragma mark - The colour the editor paints

- (void)testAColourInEveryFormSomebodyWrites
{
    NSColor *red = [NSColor colorWithSRGBRed:1.0 green:0.0 blue:0.0 alpha:1.0];
    for (NSString *written in @[@"#f00", @"#ff0000", @"red", @"RED",
                               @"  #FF0000 ", @"rgb(255, 0, 0)"])
    {
        NSColor *found = MPColourFromCSS(written);
        XCTAssertNotNil(found, @"«%@»", written);
        XCTAssertEqualWithAccuracy(found.redComponent, red.redComponent,
                                   0.01, @"«%@»", written);
        XCTAssertEqualWithAccuracy(found.greenComponent, 0.0, 0.01,
                                   @"«%@»", written);
    }
}

- (void)testAColourThisDoesNotReadIsNotGuessedAt
{
    // The preview still shows these; the editor leaves them alone rather
    // than painting something that is not what was asked for.
    XCTAssertNil(MPColourFromCSS(@"linear-gradient(red, blue)"));
    XCTAssertNil(MPColourFromCSS(@"color-mix(in srgb, red, blue)"));
    XCTAssertNil(MPColourFromCSS(@"#ff00"));
    XCTAssertNil(MPColourFromCSS(@"#zzzzzz"));
    XCTAssertNil(MPColourFromCSS(@""));
    XCTAssertNil(MPColourFromCSS(nil));
}

@end
