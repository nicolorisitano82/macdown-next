//
//  MPSpanStyler.m
//  MacDown
//

#import "MPSpanStyler.h"

#import "MPAttributedSpans.h"
#import "MPMarkerHider.h"


#pragma mark - Reading a colour

/// The colour words CSS names, kept to the ones somebody actually types.
NS_INLINE NSDictionary<NSString *, NSString *> *MPColourWords(void)
{
    static NSDictionary *words = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        words = @{@"black": @"#000000", @"silver": @"#c0c0c0",
                  @"gray": @"#808080", @"grey": @"#808080",
                  @"white": @"#ffffff", @"maroon": @"#800000",
                  @"red": @"#ff0000", @"purple": @"#800080",
                  @"fuchsia": @"#ff00ff", @"magenta": @"#ff00ff",
                  @"green": @"#008000", @"lime": @"#00ff00",
                  @"olive": @"#808000", @"yellow": @"#ffff00",
                  @"navy": @"#000080", @"blue": @"#0000ff",
                  @"teal": @"#008080", @"aqua": @"#00ffff",
                  @"cyan": @"#00ffff", @"orange": @"#ffa500",
                  @"pink": @"#ffc0cb", @"brown": @"#a52a2a",
                  @"gold": @"#ffd700", @"indigo": @"#4b0082",
                  @"violet": @"#ee82ee", @"tomato": @"#ff6347",
                  @"salmon": @"#fa8072", @"coral": @"#ff7f50",
                  @"crimson": @"#dc143c", @"turquoise": @"#40e0d0"};
    });
    return words;
}


NS_INLINE NSColor *MPColourFromComponents(CGFloat r, CGFloat g, CGFloat b)
{
    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1.0];
}


NSColor *MPColourFromCSS(NSString *value)
{
    NSString *text = [[value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!text.length)
        return nil;

    NSString *word = MPColourWords()[text];
    if (word)
        text = word;

    if ([text hasPrefix:@"#"])
    {
        NSString *digits = [text substringFromIndex:1];
        // #abc is #aabbcc: the short form is not a different colour, it is
        // the same one written once.
        if (digits.length == 3)
        {
            NSMutableString *full = [NSMutableString string];
            for (NSUInteger i = 0; i < 3; i++)
            {
                unichar c = [digits characterAtIndex:i];
                [full appendFormat:@"%C%C", c, c];
            }
            digits = full;
        }
        if (digits.length != 6)
            return nil;
        unsigned int number = 0;
        NSScanner *scanner = [NSScanner scannerWithString:digits];
        if (![scanner scanHexInt:&number] || !scanner.isAtEnd)
            return nil;
        return MPColourFromComponents(((number >> 16) & 0xff) / 255.0,
                                      ((number >> 8) & 0xff) / 255.0,
                                      (number & 0xff) / 255.0);
    }

    if ([text hasPrefix:@"rgb("] && [text hasSuffix:@")"])
    {
        NSString *inside = [text substringWithRange:
            NSMakeRange(4, text.length - 5)];
        NSArray *parts = [inside componentsSeparatedByString:@","];
        if (parts.count != 3)
            return nil;
        CGFloat channel[3] = {0.0, 0.0, 0.0};
        for (NSUInteger i = 0; i < 3; i++)
        {
            NSString *one = [parts[i] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if (!one.length)
                return nil;
            if ([one hasSuffix:@"%"])
            {
                channel[i] = [one doubleValue] / 100.0;
                continue;
            }
            channel[i] = [one doubleValue] / 255.0;
        }
        return MPColourFromComponents(channel[0], channel[1], channel[2]);
    }
    return nil;
}


CGFloat MPSizeFromCSS(NSString *value, CGFloat base)
{
    NSString *text = [[value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!text.length || base <= 0.0)
        return 0.0;

    // The words CSS has for a size are relative to the body too, and a
    // document that says «larger» means it.
    NSDictionary<NSString *, NSNumber *> *words = @{
        @"xx-small": @0.6, @"x-small": @0.75, @"small": @0.875,
        @"medium": @1.0, @"large": @1.125, @"x-large": @1.5,
        @"xx-large": @2.0, @"smaller": @0.85, @"larger": @1.2};
    NSNumber *word = words[text];
    if (word)
        return base * word.doubleValue;

    double number = 0.0;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    if (![scanner scanDouble:&number] || number <= 0.0)
        return 0.0;
    NSString *unit = [text substringFromIndex:scanner.scanLocation];
    unit = [unit stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];

    if ([unit isEqualToString:@"%"])
        return base * number / 100.0;
    if ([unit isEqualToString:@"em"] || [unit isEqualToString:@"rem"])
        return base * number;
    // A point is a point, and a pixel in a document written for a screen
    // is what the reader would call a point: treating it as 1/96 inch here
    // would make every such document a size smaller than it looks.
    if ([unit isEqualToString:@"pt"] || [unit isEqualToString:@"px"]
            || !unit.length)
        return number;
    return 0.0;                     // a unit this does not know
}


#pragma mark - Putting it in the editor

/// A span that asks for a size, and the font that was there before.
@interface MPSizedSpan : NSObject
@property (assign, nonatomic) NSRange range;        // the whole construct
@property (assign, nonatomic) NSRange content;      // the words in it
@property (strong, nonatomic) NSFont *before;
@property (strong, nonatomic) NSFont *sized;
@property (assign, nonatomic) BOOL applied;
@end

@implementation MPSizedSpan
@end


@interface MPSpanStyler ()
@property (weak, nonatomic) NSTextView *textView;
/// The spans that ask for a size, from the last pass over the document.
@property (strong, nonatomic) NSMutableArray<MPSizedSpan *> *sizes;
@end


@implementation MPSpanStyler

- (instancetype)initWithTextView:(NSTextView *)textView
{
    self = [super init];
    if (!self)
        return nil;
    _textView = textView;
    _sizes = [NSMutableArray array];
    return self;
}


- (void)apply
{
    NSTextStorage *storage = self.textView.textStorage;
    NSString *text = self.textView.string;
    if (!storage.length || !text.length)
        return;

    NSArray<MPAttributedSpan *> *spans = MPAttributedSpansIn(text);
    if (!spans.count)
        return;

    [self.sizes removeAllObjects];
    [storage beginEditing];
    for (MPAttributedSpan *span in spans)
    {
        NSRange range = span.content;
        // A list that outlived an edit would be a crash rather than a
        // wrongly coloured word.
        if (!range.length || NSMaxRange(range) > storage.length)
            continue;

        NSString *style = span.attributes[@"style"];
        if (!style.length)
            continue;

        NSColor *ink = MPColourFromCSS(MPStyleDeclaration(style, @"color"));
        if (ink)
        {
            [storage addAttribute:NSForegroundColorAttributeName value:ink
                            range:range];
        }
        NSColor *behind =
            MPColourFromCSS(MPStyleDeclaration(style, @"background-color"))
            ?: MPColourFromCSS(MPStyleDeclaration(style, @"background"));
        if (behind)
        {
            [storage addAttribute:NSBackgroundColorAttributeName
                            value:behind range:range];
        }

        // Resized from whatever is already there, so the weight and face
        // the theme asked for come along — the same way headings are
        // scaled rather than replaced.
        NSFont *current = [storage attribute:NSFontAttributeName
                                     atIndex:range.location
                              effectiveRange:NULL] ?: self.textView.font;
        CGFloat size = MPSizeFromCSS(MPStyleDeclaration(style, @"font-size"),
                                     current.pointSize);
        if (!current || size <= 0.0 || fabs(size - current.pointSize) < 0.01)
            continue;
        NSFont *sized = [[NSFontManager sharedFontManager]
            convertFont:current toSize:size];
        if (!sized)
            continue;

        MPSizedSpan *remembered = [[MPSizedSpan alloc] init];
        remembered.range = span.range;
        remembered.content = range;
        remembered.before = current;
        remembered.sized = sized;
        // The size waits until the braces are hidden: see -markerHider.
        remembered.applied = [self.markerHider isDrawnAsMeaning:span.range];
        if (remembered.applied)
        {
            [storage addAttribute:NSFontAttributeName value:sized
                            range:range];
        }
        [self.sizes addObject:remembered];
    }
    [storage endEditing];
}


- (void)selectionDidChange
{
    if (!self.sizes.count)
        return;
    NSTextStorage *storage = self.textView.textStorage;

    for (MPSizedSpan *span in self.sizes)
    {
        BOOL wanted = [self.markerHider isDrawnAsMeaning:span.range];
        if (wanted == span.applied)
            continue;
        NSRange range = span.content;
        if (!range.length || NSMaxRange(range) > storage.length)
            continue;

        // An edit can move a span before the next parse rebuilds this
        // list. Writing a font into whatever is now at that place would
        // be worse than doing nothing, so what is there is checked first.
        NSFont *there = [storage attribute:NSFontAttributeName
                                   atIndex:range.location
                            effectiveRange:NULL];
        NSFont *expected = span.applied ? span.sized : span.before;
        if (there && expected && ![there isEqual:expected])
            continue;

        [storage beginEditing];
        [storage addAttribute:NSFontAttributeName
                        value:(wanted ? span.sized : span.before)
                        range:range];
        [storage endEditing];
        span.applied = wanted;
    }
}

@end
