//
//  MPSpanStylerTests.m
//  MacDownTests
//
//  What the editor draws for `[testo]{style="…"}`.
//
//  The colour and the background are the easy half. The size is the half
//  that was wrong: applied while the braces were showing, it left a line
//  with the markup at one size and the words at twice it, rewrapping under
//  the caret as somebody tried to edit it. So the size waits until the
//  braces are out of the way, and comes back when the caret leaves.
//

#import <XCTest/XCTest.h>

#import "MPMarkerHider.h"
#import "MPSpanStyler.h"


@interface MPSpanStylerTests : XCTestCase
@property (strong) NSTextView *editor;
@property (strong) MPMarkerHider *hider;
@property (strong) MPSpanStyler *styler;
@end


@implementation MPSpanStylerTests

- (void)setUp
{
    [super setUp];
    self.editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)];
    self.editor.font = [NSFont userFixedPitchFontOfSize:14.0];
    self.hider = [[MPMarkerHider alloc] initWithTextView:self.editor];
    self.hider.enabled = YES;
    self.styler = [[MPSpanStyler alloc] initWithTextView:self.editor];
    self.styler.markerHider = self.hider;
}

- (void)write:(NSString *)markdown
{
    [self.editor setString:markdown];
    [self.editor.textStorage addAttribute:NSFontAttributeName
                                    value:self.editor.font
                                    range:NSMakeRange(0, markdown.length)];
    [self.hider updateWithElements:NULL];
    [self.styler apply];
}

/// The attribute the editor would draw the character at `index` with.
- (id)attribute:(NSString *)name at:(NSUInteger)index
{
    return [self.editor.textStorage attribute:name atIndex:index
                               effectiveRange:NULL];
}

- (NSUInteger)indexOf:(NSString *)text
{
    return [self.editor.string rangeOfString:text].location;
}


- (void)testTheWordsTakeTheColourTheyAskFor
{
    [self write:@"Una [parola]{style=\"color:#ff0000\"} qui"];
    NSColor *ink = [self attribute:NSForegroundColorAttributeName
                                at:[self indexOf:@"parola"]];
    NSColor *rgb = [ink colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertEqualWithAccuracy(rgb.redComponent, 1.0, 0.01);
    XCTAssertEqualWithAccuracy(rgb.greenComponent, 0.0, 0.01);
}

- (void)testAndTheColourBehindThem
{
    [self write:@"Una [parola]{style=\"background-color:#ffff00\"} qui"];
    NSColor *behind = [self attribute:NSBackgroundColorAttributeName
                                   at:[self indexOf:@"parola"]];
    XCTAssertNotNil(behind);
    NSColor *rgb = [behind colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertEqualWithAccuracy(rgb.blueComponent, 0.0, 0.01);
}

- (void)testTheSizeIsDrawnWhileTheBracesAreHidden
{
    [self write:@"Grande: [titolo]{style=\"font-size:2em\"}."];
    self.editor.selectedRange = NSMakeRange(0, 0);   // the caret is away
    [self.hider selectionDidChange];
    [self.styler selectionDidChange];

    NSFont *font = [self attribute:NSFontAttributeName
                                at:[self indexOf:@"titolo"]];
    XCTAssertEqualWithAccuracy(font.pointSize, 28.0, 0.01);
}

- (void)testAndNotWhileTheyAreShowing
{
    [self write:@"Grande: [titolo]{style=\"font-size:2em\"}."];
    // The caret goes in: the braces come back, and a line with the markup
    // at one size and the words at twice it is a line nobody can read.
    self.editor.selectedRange =
        NSMakeRange([self indexOf:@"titolo"] + 2, 0);
    [self.hider selectionDidChange];
    [self.styler selectionDidChange];

    NSFont *font = [self attribute:NSFontAttributeName
                                at:[self indexOf:@"titolo"]];
    XCTAssertEqualWithAccuracy(font.pointSize, 14.0, 0.01);

    // And back again when it leaves.
    self.editor.selectedRange = NSMakeRange(0, 0);
    [self.hider selectionDidChange];
    [self.styler selectionDidChange];
    font = [self attribute:NSFontAttributeName at:[self indexOf:@"titolo"]];
    XCTAssertEqualWithAccuracy(font.pointSize, 28.0, 0.01);
}

- (void)testTheColourStaysWhileTheBracesShow
{
    // Unlike the size, a colour moves nothing: it stays on while somebody
    // edits the braces, so the words do not flash black and back.
    [self write:@"Una [parola]{style=\"color:#ff0000;font-size:2em\"} qui"];
    self.editor.selectedRange =
        NSMakeRange([self indexOf:@"parola"] + 1, 0);
    [self.hider selectionDidChange];
    [self.styler selectionDidChange];

    NSColor *ink = [self attribute:NSForegroundColorAttributeName
                                at:[self indexOf:@"parola"]];
    NSColor *rgb = [ink colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertEqualWithAccuracy(rgb.redComponent, 1.0, 0.01);
}

- (void)testWithTheMarkersAlwaysVisibleNoSizeIsDrawn
{
    // Somebody who turned marker hiding off is asking to see the source as
    // it is; a size in the middle of it would be the same broken line.
    self.hider.enabled = NO;
    [self write:@"Grande: [titolo]{style=\"font-size:2em\"}."];
    NSFont *font = [self attribute:NSFontAttributeName
                                at:[self indexOf:@"titolo"]];
    XCTAssertEqualWithAccuracy(font.pointSize, 14.0, 0.01);
}

- (void)testADocumentWithNoSpansIsLeftAlone
{
    [self write:@"Una riga qualunque, con un [link](http://e.it)."];
    NSFont *font = [self attribute:NSFontAttributeName at:0];
    XCTAssertEqualWithAccuracy(font.pointSize, 14.0, 0.01);
    XCTAssertNil([self attribute:NSBackgroundColorAttributeName at:0]);
}

@end
