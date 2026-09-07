//
//  MPMarkdownRenderingTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "document.h"
#import "html.h"
#import "hoedown_html_patch.h"

/** What the renderer makes of the constructs people actually write.
 *
 * Nothing tested the rendering at all before this: the Markdown went into a
 * vendored C parser and whatever came out was the answer. That is a poor
 * place to be standing when the parser's own block rules need changing, so
 * this is first the net and then the specification — the cases that hold
 * today, so a patch cannot quietly break one, and the cases the patches are
 * for.
 */
@interface MPMarkdownRenderingTests : XCTestCase
@end

@implementation MPMarkdownRenderingTests

/// The renderer assembled the way MPRenderer assembles it, patches included.
- (NSString *)render:(NSString *)markdown
{
    // Every extension the preferences can switch on, since the point here
    // is what the parser does rather than which switches are set.
    int extensions = HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE
        | HOEDOWN_EXT_AUTOLINK | HOEDOWN_EXT_STRIKETHROUGH
        | HOEDOWN_EXT_FOOTNOTES | HOEDOWN_EXT_QUOTE
        | HOEDOWN_EXT_SUPERSCRIPT | HOEDOWN_EXT_UNDERLINE
        | HOEDOWN_EXT_HIGHLIGHT | HOEDOWN_EXT_NO_INTRA_EMPHASIS
        | HOEDOWN_EXT_SPACE_HEADERS;
    unsigned int htmlFlags = HOEDOWN_HTML_USE_TASK_LIST;

    hoedown_renderer *renderer = hoedown_html_renderer_new(htmlFlags, 6);
    renderer->listitem = hoedown_patch_render_listitem;

    hoedown_document *document =
        hoedown_document_new(renderer, extensions, 16);
    hoedown_buffer *out = hoedown_buffer_new(64);
    NSData *input = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_document_render(document, out, input.bytes, input.length);

    NSString *html = @(hoedown_buffer_cstr(out));
    hoedown_document_free(document);
    hoedown_buffer_free(out);
    hoedown_html_renderer_free(renderer);
    return html;
}

- (void)assert:(NSString *)markdown contains:(NSString *)fragment
{
    NSString *html = [self render:markdown];
    XCTAssertNotEqual([html rangeOfString:fragment].location,
                      (NSUInteger)NSNotFound,
                      @"«%@» non contiene «%@»:\n%@", markdown, fragment, html);
}

- (void)assert:(NSString *)markdown lacks:(NSString *)fragment
{
    NSString *html = [self render:markdown];
    XCTAssertEqual([html rangeOfString:fragment].location,
                   (NSUInteger)NSNotFound,
                   @"«%@» contiene «%@»:\n%@", markdown, fragment, html);
}


#pragma mark - The net: what holds today

- (void)testGitHubExtensions
{
    [self assert:@"~~via~~" contains:@"<del>via</del>"];
    [self assert:@"vedi https://esempio.it qui"
        contains:@"<a href=\"https://esempio.it\">"];
    [self assert:@"vedi www.esempio.it qui"
        contains:@"<a href=\"http://www.esempio.it\">"];
    [self assert:@"~~~python\nx = 1\n~~~\n"
        contains:@"class=\"language-python\""];
    [self assert:@"nota[^1]\n\n[^1]: il testo\n" contains:@"rel=\"footnote\""];
    [self assert:@"| a | b |\n|:--|--:|\n| 1 | 2 |\n"
        contains:@"style=\"text-align: right\""];
}

- (void)testTaskLists
{
    [self assert:@"- [ ] da fare" contains:@"<input type=\"checkbox\">"];
    [self assert:@"- [x] fatto" contains:@"checked"];
}

/** The ones MacDown Next has that CommonMark does not, and would lose.
 *
 * The syntax is measured, not assumed: with the underline extension on a
 * single underscore is an underline rather than emphasis, and a
 * superscript takes no closing mark.
 */
- (void)testTheExtensionsThatAreOurs
{
    [self assert:@"==giallo==" contains:@"<mark>giallo</mark>"];
    [self assert:@"_sotto_" contains:@"<u>sotto</u>"];
    [self assert:@"x^2" contains:@"<sup>2</sup>"];
    [self assert:@"x^(2n)" contains:@"<sup>2n</sup>"];
    [self assert:@"\"citato\"" contains:@"<q>citato</q>"];
}

- (void)testEmphasisAndEscapes
{
    [self assert:@"***forte e corsivo***"
        contains:@"<strong><em>forte e corsivo</em></strong>"];
    [self assert:@"\\*non enfasi\\*" contains:@"*non enfasi*"];
    [self assert:@"foo_bar_baz" lacks:@"<em>"];
    [self assert:@"riga  \nsuccessiva" contains:@"<br>"];
    [self assert:@"&copy; 2026" contains:@"&copy;"];
}


#pragma mark - The specification: what the patches are for

/// CommonMark: a hash with no space after it is not a heading.
- (void)testAHashWithoutASpaceIsNotAHeading
{
    // `<h1` and not `<h1>`: the renderer writes a source offset into the
    // tag, so the closing bracket is not where a naive search expects it —
    // and an assertion that looked for one passed while the heading was
    // being rendered all along.
    [self assert:@"#senzaspazio" lacks:@"<h1"];
    [self assert:@"#senzaspazio" contains:@"#senzaspazio"];
    // And a real heading still is one, with or without its closing hashes.
    [self assert:@"# Titolo" contains:@"<h1"];
    [self assert:@"## Titolo ##" contains:@"<h2"];
    // A hash on its own line is a heading with nothing in it, not prose.
    [self assert:@"# " lacks:@"<p"];
}

/// CommonMark: `)` closes an ordered list marker just as `.` does.
- (void)testAnOrderedListWithParentheses
{
    // The tags carry where they came from now, so what is asserted is the
    // tag and its own attributes rather than the whole of it.
    [self assert:@"1) prima\n2) seconda\n" contains:@"<ol"];
    [self assert:@"1) prima\n2) seconda\n" contains:@">prima</li>"];
    // Not in the middle of a sentence, though: `Vedi 1) qui` is prose.
    [self assert:@"Vedi il punto 1) qui" lacks:@"<ol"];
}

/// CommonMark: a list that starts at five is numbered from five.
- (void)testAnOrderedListKeepsItsFirstNumber
{
    [self assert:@"5. quinta\n6. sesta\n" contains:@"start=\"5\">"];
    // One is the default and says nothing.
    [self assert:@"1. prima\n2. seconda\n" contains:@"<ol"];
    [self assert:@"1. prima\n2. seconda\n" lacks:@"start="];
}

/// Every block says where it came from, lists and their items included:
/// it is what lets a selection in one pane be found in the other.
- (void)testAListSaysWhereEachItemStarts
{
    NSString *html = [self render:@"- primo\n- secondo\n"];
    XCTAssertTrue([html containsString:@"<ul data-src=\"0\">"], @"%@", html);
    XCTAssertTrue([html containsString:@"<li data-src=\"0\">primo"],
                  @"%@", html);
    XCTAssertTrue([html containsString:@"<li data-src=\"8\">secondo"],
                  @"%@", html);
}

/// CommonMark: a backslash at the end of a line is a hard break.
- (void)testABackslashEndsALine
{
    [self assert:@"riga\\\nsuccessiva" contains:@"<br>"];
    [self assert:@"riga\\\nsuccessiva" lacks:@"\\"];
    // A backslash anywhere else still escapes what follows it.
    [self assert:@"\\*testo\\*" contains:@"*testo*"];
}

/// GitHub accepts either case in a task list marker.
- (void)testATaskListMarkerInEitherCase
{
    [self assert:@"- [X] fatto" contains:@"checked"];
    [self assert:@"- [X] fatto" lacks:@"[X]"];
}

@end
