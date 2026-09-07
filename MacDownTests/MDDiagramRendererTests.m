//
//  MDDiagramRendererTests.m
//  MacDownTests
//
//  Reading the fences, drawing them, and putting the drawings back.
//

#import <XCTest/XCTest.h>

#import "MDDiagramRenderer.h"


@interface MDDiagramRendererTests : XCTestCase
@end

@implementation MDDiagramRendererTests

#pragma mark - Finding the fences

- (void)testTheBareFenceIsFound
{
    NSString *html = @"<p>prima</p>\n"
        @"<pre><code class=\"language-mermaid\">graph TD\n  A --&gt; B\n"
        @"</code></pre>\n<p>dopo</p>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    XCTAssertEqual(fences.count, 1u);
    XCTAssertEqualObjects(fences[0].source, @"graph TD\n  A --> B\n");
    XCTAssertEqualObjects([html substringWithRange:fences[0].range],
        @"<pre><code class=\"language-mermaid\">graph TD\n  A --&gt; B\n"
        @"</code></pre>");
}

- (void)testTheWrappedFenceIsFoundWithItsDiv
{
    NSString *html = @"<div data-src=\"12\"><pre><code "
        @"class=\"language-mermaid\">graph TD</code></pre></div>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    XCTAssertEqual(fences.count, 1u);
    // The whole wrapper goes, or the drawing would sit inside a code block's
    // frame.
    XCTAssertEqual(fences[0].range.length, html.length);
}

- (void)testAnotherLanguageIsNotADiagram
{
    NSString *html = @"<pre><code class=\"language-swift\">let a = 1"
        @"</code></pre>";
    XCTAssertEqual(MDDiagramFencesInHTML(html).count, 0u);
}

- (void)testTwoFencesComeBackInOrder
{
    NSString *html = @"<pre><code class=\"language-mermaid\">uno"
        @"</code></pre><p>fra i due</p>"
        @"<pre><code class=\"language-mermaid\">due</code></pre>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    XCTAssertEqual(fences.count, 2u);
    XCTAssertEqualObjects(fences[0].source, @"uno");
    XCTAssertEqualObjects(fences[1].source, @"due");
}

- (void)testTheEscapingIsUndone
{
    // What hoedown wrote is HTML; what mermaid reads is not.
    NSString *html = @"<pre><code class=\"language-mermaid\">"
        @"A --&gt;|&quot;sì&quot;| B &amp;&amp; C &lt;br&gt; &amp;amp;lt;"
        @"</code></pre>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    XCTAssertEqualObjects(fences[0].source,
        @"A -->|\"sì\"| B && C <br> &amp;lt;");
}

- (void)testAnEmptyFenceIsNothingToDraw
{
    NSString *html = @"<pre><code class=\"language-mermaid\"></code></pre>";
    XCTAssertEqual(MDDiagramFencesInHTML(html).count, 0u);
}


#pragma mark - Putting the drawings back

- (void)testADrawingTakesTheFencesPlace
{
    NSString *html = @"<p>a</p><pre><code class=\"language-mermaid\">graph"
        @"</code></pre><p>b</p>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    NSString *drawn = MDHTMLByDrawingFences(html, fences, @[@"<svg>x</svg>"]);
    XCTAssertEqualObjects(drawn,
        @"<p>a</p><div class=\"macdown-diagram\"><svg>x</svg></div><p>b</p>");
    XCTAssertFalse([drawn containsString:@"language-mermaid"]);
}

- (void)testAFenceWithNoDrawingStaysAsSource
{
    NSString *html = @"<pre><code class=\"language-mermaid\">graph"
        @"</code></pre>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    XCTAssertEqualObjects(MDHTMLByDrawingFences(html, fences,
        @[[NSNull null]]), html);
    XCTAssertEqualObjects(MDHTMLByDrawingFences(html, fences, @[@""]), html);
    XCTAssertEqualObjects(MDHTMLByDrawingFences(html, fences, @[]), html);
}

- (void)testOneDiagramFailingLeavesTheOtherDrawn
{
    NSString *html = @"<pre><code class=\"language-mermaid\">uno"
        @"</code></pre><pre><code class=\"language-mermaid\">due"
        @"</code></pre>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    NSString *drawn = MDHTMLByDrawingFences(html, fences,
        @[[NSNull null], @"<svg>due</svg>"]);
    XCTAssertTrue([drawn containsString:@"language-mermaid\">uno"]);
    XCTAssertTrue([drawn containsString:@"<svg>due</svg>"]);
}


#pragma mark - What is taken out of a drawing

- (void)testAScriptIsTakenOutOfTheDrawing
{
    NSString *svg = @"<svg><script>alert(1)</script><g>ok</g></svg>";
    NSString *safe = MDSVGWithoutScripts(svg);
    XCTAssertFalse([safe containsString:@"script"]);
    XCTAssertTrue([safe containsString:@"<g>ok</g>"]);
}

- (void)testAnEventAttributeIsTakenOut
{
    NSString *svg = @"<svg><rect onclick=\"steal()\" fill=\"red\"/>"
        @"<rect onmouseover='x'/></svg>";
    NSString *safe = MDSVGWithoutScripts(svg);
    XCTAssertFalse([safe containsString:@"onclick"]);
    XCTAssertFalse([safe containsString:@"onmouseover"]);
    XCTAssertTrue([safe containsString:@"fill=\"red\""]);
}

- (void)testALinkThatRunsIsTakenOut
{
    NSString *svg = @"<svg><a xlink:href=\"javascript:alert(1)\">t</a>"
        @"<a href=\"https://esempio.it\">u</a></svg>";
    NSString *safe = MDSVGWithoutScripts(svg);
    XCTAssertFalse([safe containsString:@"javascript:"]);
    XCTAssertTrue([safe containsString:@"https://esempio.it"]);
}

- (void)testTheDrawingIsCleanedOnTheWayIn
{
    NSString *html = @"<pre><code class=\"language-mermaid\">graph"
        @"</code></pre>";
    NSArray<MDDiagramFence *> *fences = MDDiagramFencesInHTML(html);
    NSString *drawn = MDHTMLByDrawingFences(html, fences,
        @[@"<svg><script>alert(1)</script></svg>"]);
    XCTAssertFalse([drawn containsString:@"alert"]);
}


#pragma mark - Drawing them for real

/// mermaid as the extension ships it: the app carries the same file.
- (NSURL *)mermaid
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"mermaid.min"
                                         withExtension:@"js"
                                          subdirectory:@"Extensions"];
    XCTAssertNotNil(url, @"mermaid non è nel bundle");
    return url;
}

- (void)testNothingToDrawAnswersAtOnce
{
    XCTestExpectation *done = [self expectationWithDescription:@"answered"];
    [MDDiagramRenderer drawSources:@[] mermaidScript:[self mermaid]
                            within:1.0 completion:^(NSArray *drawings) {
        XCTAssertEqual(drawings.count, 0u);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testWithoutMermaidNothingIsDrawn
{
    XCTestExpectation *done = [self expectationWithDescription:@"answered"];
    [MDDiagramRenderer drawSources:@[@"graph TD\n A --> B"]
                     mermaidScript:nil within:1.0
                        completion:^(NSArray *drawings) {
        // The fences stay as source, which is what the preview showed before
        // it could draw anything at all.
        XCTAssertEqual(drawings.count, 0u);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAFlowchartIsDrawn
{
    XCTestExpectation *done = [self expectationWithDescription:@"drawn"];
    [MDDiagramRenderer drawSources:@[@"graph TD\n  A[Inizio] --> B[Fine]"]
                     mermaidScript:[self mermaid] within:20.0
                        completion:^(NSArray *drawings) {
        XCTAssertEqual(drawings.count, 1u);
        XCTAssertTrue([drawings[0] isKindOfClass:[NSString class]],
                      @"%@", drawings[0]);
        NSString *svg = drawings[0];
        XCTAssertTrue([svg containsString:@"<svg"]);
        XCTAssertTrue([svg containsString:@"Inizio"]);
        XCTAssertTrue([svg containsString:@"Fine"]);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void)testADiagramWithAMistakeDoesNotCostTheOthers
{
    XCTestExpectation *done = [self expectationWithDescription:@"drawn"];
    [MDDiagramRenderer drawSources:@[@"graph TD\n  A --> B",
                                     @"questo non è un diagramma {{{",
                                     @"graph LR\n  C --> D"]
                     mermaidScript:[self mermaid] within:20.0
                        completion:^(NSArray *drawings) {
        XCTAssertEqual(drawings.count, 3u);
        XCTAssertTrue([drawings[0] isKindOfClass:[NSString class]]);
        XCTAssertEqualObjects(drawings[1], [NSNull null]);
        XCTAssertTrue([drawings[2] isKindOfClass:[NSString class]]);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

@end
