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
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqual(jobs.count, 1u);
    XCTAssertEqualObjects(jobs[0].source, @"graph TD\n  A --> B\n");
    XCTAssertEqualObjects([html substringWithRange:jobs[0].range],
        @"<pre><code class=\"language-mermaid\">graph TD\n  A --&gt; B\n"
        @"</code></pre>");
}

- (void)testTheWrappedFenceIsFoundWithItsDiv
{
    NSString *html = @"<div data-src=\"12\"><pre><code "
        @"class=\"language-mermaid\">graph TD</code></pre></div>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqual(jobs.count, 1u);
    // The whole wrapper goes, or the drawing would sit inside a code block's
    // frame.
    XCTAssertEqual(jobs[0].range.length, html.length);
}

- (void)testAnotherLanguageIsNotADiagram
{
    NSString *html = @"<pre><code class=\"language-swift\">let a = 1"
        @"</code></pre>";
    XCTAssertEqual(MDDrawingJobsInHTML(html).count, 0u);
}

- (void)testTwoFencesComeBackInOrder
{
    NSString *html = @"<pre><code class=\"language-mermaid\">uno"
        @"</code></pre><p>fra i due</p>"
        @"<pre><code class=\"language-mermaid\">due</code></pre>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqual(jobs.count, 2u);
    XCTAssertEqualObjects(jobs[0].source, @"uno");
    XCTAssertEqualObjects(jobs[1].source, @"due");
}

- (void)testTheEscapingIsUndone
{
    // What hoedown wrote is HTML; what mermaid reads is not.
    NSString *html = @"<pre><code class=\"language-mermaid\">"
        @"A --&gt;|&quot;sì&quot;| B &amp;&amp; C &lt;br&gt; &amp;amp;lt;"
        @"</code></pre>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqualObjects(jobs[0].source,
        @"A -->|\"sì\"| B && C <br> &amp;lt;");
}

- (void)testAnEmptyFenceIsNothingToDraw
{
    NSString *html = @"<pre><code class=\"language-mermaid\"></code></pre>";
    XCTAssertEqual(MDDrawingJobsInHTML(html).count, 0u);
}


#pragma mark - Putting the drawings back

- (void)testADrawingTakesTheFencesPlace
{
    NSString *html = @"<p>a</p><pre><code class=\"language-mermaid\">graph"
        @"</code></pre><p>b</p>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    NSString *drawn = MDHTMLByDrawingJobs(html, jobs, @[@"<svg>x</svg>"]);
    XCTAssertEqualObjects(drawn,
        @"<p>a</p><div class=\"macdown-diagram\"><svg>x</svg></div><p>b</p>");
    XCTAssertFalse([drawn containsString:@"language-mermaid"]);
}

- (void)testAFenceWithNoDrawingStaysAsSource
{
    NSString *html = @"<pre><code class=\"language-mermaid\">graph"
        @"</code></pre>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqualObjects(MDHTMLByDrawingJobs(html, jobs,
        @[[NSNull null]]), html);
    XCTAssertEqualObjects(MDHTMLByDrawingJobs(html, jobs, @[@""]), html);
    XCTAssertEqualObjects(MDHTMLByDrawingJobs(html, jobs, @[]), html);
}

- (void)testOneDiagramFailingLeavesTheOtherDrawn
{
    NSString *html = @"<pre><code class=\"language-mermaid\">uno"
        @"</code></pre><pre><code class=\"language-mermaid\">due"
        @"</code></pre>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    NSString *drawn = MDHTMLByDrawingJobs(html, jobs,
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
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    NSString *drawn = MDHTMLByDrawingJobs(html, jobs,
        @[@"<svg><script>alert(1)</script></svg>"]);
    XCTAssertFalse([drawn containsString:@"alert"]);
}


#pragma mark - The other engines, and the formulas

- (void)testEveryGraphvizEngineIsRecognized
{
    for (NSString *engine in @[@"dot", @"neato", @"fdp", @"circo",
                               @"twopi", @"osage"])
    {
        NSString *html = [NSString stringWithFormat:
            @"<pre><code class=\"language-%@\">digraph { a -&gt; b }"
            @"</code></pre>", engine];
        NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
        XCTAssertEqual(jobs.count, 1u, @"%@", engine);
        XCTAssertEqual(jobs[0].kind, MDDrawingGraphviz, @"%@", engine);
        XCTAssertEqualObjects(jobs[0].engine, engine);
        XCTAssertEqualObjects(jobs[0].source, @"digraph { a -> b }");
    }
}

- (void)testAMermaidFenceHasNoEngine
{
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(
        @"<pre><code class=\"language-mermaid\">graph TD</code></pre>");
    XCTAssertEqual(jobs[0].kind, MDDrawingMermaid);
    XCTAssertNil(jobs[0].engine);
}

- (void)testADisplayFormulaIsFound
{
    // What hoedown leaves behind for $$…$$, which is what MathJax looks for.
    NSString *html = @"<p>prima</p><p>\\[\\int_0^1 x\\,dx\\]</p>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqual(jobs.count, 1u);
    XCTAssertEqual(jobs[0].kind, MDDrawingMathDisplay);
    XCTAssertEqualObjects(jobs[0].source, @"\\int_0^1 x\\,dx");
    // The delimiters go with it: they are not text to keep.
    XCTAssertEqualObjects([html substringWithRange:jobs[0].range],
                          @"\\[\\int_0^1 x\\,dx\\]");
}

- (void)testAnInlineFormulaIsFound
{
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(
        @"<p>vale \\(a^2 + b^2\\) e basta</p>");
    XCTAssertEqual(jobs.count, 1u);
    XCTAssertEqual(jobs[0].kind, MDDrawingMathInline);
    XCTAssertEqualObjects(jobs[0].source, @"a^2 + b^2");
}

- (void)testAFormulaInsideCodeIsShownAndNotTypeset
{
    // A block that *talks* about a formula is not a formula.
    XCTAssertEqual(MDDrawingJobsInHTML(
        @"<pre><code>\\[x^2\\]</code></pre>").count, 0u);
    XCTAssertEqual(MDDrawingJobsInHTML(
        @"<p>si scrive <code>\\(x\\)</code></p>").count, 0u);
}

- (void)testEverythingComesBackInDocumentOrder
{
    NSString *html = @"<pre><code class=\"language-mermaid\">graph TD"
        @"</code></pre><p>\\(a\\)</p>"
        @"<pre><code class=\"language-twopi\">graph { b }</code></pre>"
        @"<p>\\[c\\]</p>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertEqual(jobs.count, 4u);
    XCTAssertEqual(jobs[0].kind, MDDrawingMermaid);
    XCTAssertEqual(jobs[1].kind, MDDrawingMathInline);
    XCTAssertEqual(jobs[2].kind, MDDrawingGraphviz);
    XCTAssertEqual(jobs[3].kind, MDDrawingMathDisplay);
}

- (void)testAFormulaIsNotWrappedLikeADiagram
{
    NSString *html = @"<p>vale \\(a\\) qui</p>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    NSString *drawn = MDHTMLByDrawingJobs(html, jobs,
        @[@"<mjx-container><svg>a</svg></mjx-container>"]);
    // A formula carries its own placement; a block around it would put it on
    // a line of its own.
    XCTAssertEqualObjects(drawn,
        @"<p>vale <mjx-container><svg>a</svg></mjx-container> qui</p>");
}

- (void)testAGraphIsWrappedLikeADiagram
{
    NSString *html = @"<pre><code class=\"language-dot\">digraph { a }"
        @"</code></pre>";
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    NSString *drawn = MDHTMLByDrawingJobs(html, jobs, @[@"<svg>g</svg>"]);
    XCTAssertEqualObjects(drawn,
        @"<div class=\"macdown-diagram\"><svg>g</svg></div>");
}


#pragma mark - Drawing them for real

/// The three libraries as the extension ships them: the app carries the
/// same files, in its own folders.
- (NSDictionary<NSString *, NSURL *> *)libraries
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *mermaid = [bundle URLForResource:@"mermaid.min" withExtension:@"js"
                               subdirectory:@"Extensions"];
    NSURL *viz = [bundle URLForResource:@"viz" withExtension:@"js"
                           subdirectory:@"Extensions"];
    NSURL *math = [bundle URLForResource:@"tex-svg" withExtension:@"js"
                            subdirectory:@"MathJax"];
    XCTAssertNotNil(mermaid, @"mermaid non è nel bundle");
    XCTAssertNotNil(viz, @"viz.js non è nel bundle");
    XCTAssertNotNil(math, @"MathJax non è nel bundle");
    return @{MDMermaidResource: mermaid, MDGraphvizResource: viz,
             MDMathResource: math};
}

/// The jobs of a page, which is how the extension gets them too.
- (NSArray<MDDrawingJob *> *)jobsFor:(NSString *)html
{
    NSArray<MDDrawingJob *> *jobs = MDDrawingJobsInHTML(html);
    XCTAssertGreaterThan(jobs.count, 0u, @"niente da disegnare in %@", html);
    return jobs;
}

- (void)testNothingToDrawAnswersAtOnce
{
    XCTestExpectation *done = [self expectationWithDescription:@"answered"];
    [MDDiagramRenderer drawJobs:@[] resources:[self libraries] within:1.0
                     completion:^(NSArray *drawings, NSString *styles) {
        XCTAssertEqual(drawings.count, 0u);
        XCTAssertNil(styles);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testWithoutTheLibraryNothingIsDrawn
{
    XCTestExpectation *done = [self expectationWithDescription:@"answered"];
    [MDDiagramRenderer drawJobs:[self jobsFor:@"<pre><code "
                                  @"class=\"language-mermaid\">graph TD\n"
                                  @"A --&gt; B</code></pre>"]
                      resources:@{} within:1.0
                     completion:^(NSArray *drawings, NSString *styles) {
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
    [MDDiagramRenderer drawJobs:[self jobsFor:@"<pre><code "
                                  @"class=\"language-mermaid\">"
                                  @"graph TD\n  A[Inizio] --&gt; B[Fine]"
                                  @"</code></pre>"]
                      resources:[self libraries] within:20.0
                     completion:^(NSArray *drawings, NSString *styles) {
        XCTAssertEqual(drawings.count, 1u);
        XCTAssertTrue([drawings[0] isKindOfClass:[NSString class]],
                      @"%@", drawings[0]);
        NSString *svg = drawings[0];
        XCTAssertTrue([svg containsString:@"<svg"]);
        XCTAssertTrue([svg containsString:@"Inizio"]);
        XCTAssertTrue([svg containsString:@"Fine"]);
        // No formulas, so nothing MathJax needs to be added to the page.
        XCTAssertTrue(!styles.length);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void)testAGraphvizGraphIsDrawn
{
    XCTestExpectation *done = [self expectationWithDescription:@"drawn"];
    [MDDiagramRenderer drawJobs:[self jobsFor:@"<pre><code "
                                  @"class=\"language-dot\">digraph { "
                                  @"Inizio -&gt; Fine }</code></pre>"]
                      resources:[self libraries] within:20.0
                     completion:^(NSArray *drawings, NSString *styles) {
        XCTAssertEqual(drawings.count, 1u);
        XCTAssertTrue([drawings[0] isKindOfClass:[NSString class]],
                      @"%@", drawings[0]);
        NSString *svg = drawings[0];
        XCTAssertTrue([svg containsString:@"<svg"]);
        XCTAssertTrue([svg containsString:@"Inizio"]);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void)testAFormulaIsTypeset
{
    XCTestExpectation *done = [self expectationWithDescription:@"typeset"];
    [MDDiagramRenderer drawJobs:[self jobsFor:@"<p>\\[x^2 + y^2 = z^2\\]</p>"]
                      resources:[self libraries] within:20.0
                     completion:^(NSArray *drawings, NSString *styles) {
        XCTAssertEqual(drawings.count, 1u);
        XCTAssertTrue([drawings[0] isKindOfClass:[NSString class]],
                      @"%@", drawings[0]);
        NSString *svg = drawings[0];
        XCTAssertTrue([svg containsString:@"<svg"]);
        XCTAssertTrue([svg containsString:@"mjx-container"]);
        // The formula sits on the line by MathJax's rules, which come back
        // with it.
        XCTAssertTrue(styles.length > 0);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void)testAllThreeInOneDocument
{
    NSString *html = @"<pre><code class=\"language-mermaid\">graph TD\n"
        @"A --&gt; B</code></pre><p>\\(a+b\\)</p>"
        @"<pre><code class=\"language-neato\">graph { a -- b }"
        @"</code></pre>";
    XCTestExpectation *done = [self expectationWithDescription:@"drawn"];
    [MDDiagramRenderer drawJobs:[self jobsFor:html]
                      resources:[self libraries] within:30.0
                     completion:^(NSArray *drawings, NSString *styles) {
        XCTAssertEqual(drawings.count, 3u);
        for (id drawing in drawings)
            XCTAssertTrue([drawing isKindOfClass:[NSString class]],
                          @"%@", drawing);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testADiagramWithAMistakeDoesNotCostTheOthers
{
    NSString *html = @"<pre><code class=\"language-mermaid\">graph TD\n"
        @"A --&gt; B</code></pre>"
        @"<pre><code class=\"language-mermaid\">questo non è un diagramma "
        @"{{{</code></pre>"
        @"<pre><code class=\"language-dot\">questo nemmeno {{{"
        @"</code></pre>"
        @"<pre><code class=\"language-mermaid\">graph LR\n C --&gt; D"
        @"</code></pre>";
    XCTestExpectation *done = [self expectationWithDescription:@"drawn"];
    [MDDiagramRenderer drawJobs:[self jobsFor:html]
                      resources:[self libraries] within:30.0
                     completion:^(NSArray *drawings, NSString *styles) {
        XCTAssertEqual(drawings.count, 4u);
        XCTAssertTrue([drawings[0] isKindOfClass:[NSString class]]);
        XCTAssertEqualObjects(drawings[1], [NSNull null]);
        XCTAssertEqualObjects(drawings[2], [NSNull null]);
        XCTAssertTrue([drawings[3] isKindOfClass:[NSString class]]);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:60.0 handler:nil];
}

@end
