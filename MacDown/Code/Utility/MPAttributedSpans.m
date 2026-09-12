//
//  MPAttributedSpans.m
//  MacDown
//

#import "MPAttributedSpans.h"

#import "MPMarkdownText.h"


/// How deep a span inside a span is followed. Past this the inside is left
/// as written: a document that nests attributes fifty deep is not a
/// document, and a recursion with no floor is a crash waiting for it.
static const NSUInteger kMPSpanDepth = 8;


#pragma mark - What a document may say about itself

/** The attributes a piece of text is allowed to carry.
 *
 * Not a blacklist. A document describes itself — how it reads, what it is
 * called, which language it is in — and everything on this list does that.
 * What is missing is everything that *acts*: `onclick` and its forty
 * relatives, `src`, `href`. A Markdown file is often something somebody
 * else wrote, and the preview is a web view.
 */
NS_INLINE BOOL MPAttributeIsAllowed(NSString *key)
{
    static NSSet *allowed = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        allowed = [NSSet setWithArray:@[@"class", @"id", @"style", @"title",
                                        @"lang", @"dir"]];
    });
    return [allowed containsObject:key] || [key hasPrefix:@"data-"];
}


/** Whether a style declaration is only style.
 *
 * CSS can fetch: `url(…)` in a background reaches the network from a
 * document that looks like text, and `@import` does the same. Neither has
 * anything to do with colouring a word, so a declaration carrying one is
 * dropped whole rather than cleaned — half-cleaned CSS is how these things
 * get through.
 */
NS_INLINE BOOL MPStyleIsHarmless(NSString *style)
{
    NSString *flat = style.lowercaseString;
    for (NSString *bad in @[@"url(", @"@import", @"expression(",
                            @"javascript:", @"behavior:", @"-moz-binding"])
    {
        if ([flat rangeOfString:bad].location != NSNotFound)
            return NO;
    }
    return YES;
}


NS_INLINE NSString *MPEscapedForAttribute(NSString *value)
{
    NSMutableString *out = [value mutableCopy];
    [out replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0
                              range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0
                              range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@">" withString:@"&gt;" options:0
                              range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0
                              range:NSMakeRange(0, out.length)];
    return out;
}


#pragma mark - Reading the braces

NS_INLINE BOOL MPIsNameCharacter(unichar c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.'
        || c == ':' || c >= 128;
}


NSDictionary<NSString *, NSString *> *MPAttributesFromBraces(NSString *inside)
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *classes = [NSMutableArray array];
    NSUInteger length = inside.length;
    NSUInteger i = 0;
    BOOL sawSomething = NO;

    while (i < length)
    {
        unichar c = [inside characterAtIndex:i];
        if (MPCharacterIsWhitespace(c))
        {
            i++;
            continue;
        }

        // .class and #id: a name, and nothing else allowed in it.
        if (c == '.' || c == '#')
        {
            NSUInteger start = ++i;
            while (i < length && MPIsNameCharacter([inside characterAtIndex:i]))
                i++;
            if (i == start)
                return nil;             // a lone dot is not an attribute
            NSString *name = [inside substringWithRange:
                NSMakeRange(start, i - start)];
            if (c == '.')
                [classes addObject:name];
            else
                attributes[@"id"] = name;
            sawSomething = YES;
            continue;
        }

        // key=value, the value bare or in quotes.
        NSUInteger start = i;
        while (i < length && MPIsNameCharacter([inside characterAtIndex:i]))
            i++;
        if (i == start || i >= length || [inside characterAtIndex:i] != '=')
            return nil;                 // not attributes: leave it written
        NSString *key = [[inside substringWithRange:NSMakeRange(start, i - start)]
            lowercaseString];
        i++;                            // the =

        if (i >= length)
            return nil;
        NSString *value = nil;
        unichar quote = [inside characterAtIndex:i];
        if (quote == '"' || quote == '\'')
        {
            // A backslash takes the next character as itself, which is how
            // a value says a quote: title="dice \"ciao\"".
            NSMutableString *read = [NSMutableString string];
            i++;
            BOOL closed = NO;
            while (i < length)
            {
                unichar in = [inside characterAtIndex:i];
                if (in == '\\' && i + 1 < length)
                {
                    [read appendFormat:@"%C", [inside characterAtIndex:++i]];
                    i++;
                    continue;
                }
                if (in == quote)
                {
                    closed = YES;
                    i++;
                    break;
                }
                [read appendFormat:@"%C", in];
                i++;
            }
            if (!closed)
                return nil;             // a quote nobody closed
            value = read;
        }
        else
        {
            NSUInteger from = i;
            while (i < length
                   && !MPCharacterIsWhitespace([inside characterAtIndex:i]))
                i++;
            value = [inside substringWithRange:NSMakeRange(from, i - from)];
        }
        if (!value.length)
            return nil;

        sawSomething = YES;
        if (!MPAttributeIsAllowed(key))
            continue;                   // dropped, and said so by staying put
        if ([key isEqualToString:@"style"] && !MPStyleIsHarmless(value))
            continue;
        if ([key isEqualToString:@"class"])
            [classes addObject:value];
        else
            attributes[key] = value;
    }

    if (!sawSomething)
        return nil;                     // {} is not an attribute list
    if (classes.count)
        attributes[@"class"] = [classes componentsJoinedByString:@" "];
    return attributes.count ? attributes : nil;
}


#pragma mark - Finding them in a document

/// The end of the brace block that starts at `start`, quotes respected, or
/// NSNotFound. A `}` inside a quoted value does not close anything.
NS_INLINE NSUInteger MPEndOfBraces(NSString *text, NSUInteger start)
{
    NSUInteger length = text.length;
    unichar quote = 0;
    for (NSUInteger i = start + 1; i < length; i++)
    {
        unichar c = [text characterAtIndex:i];
        if (quote)
        {
            if (c == quote)
                quote = 0;
            continue;
        }
        if (c == '"' || c == '\'')
            quote = c;
        else if (c == '}')
            return i;
        else if (MPCharacterIsNewline(c))
            return NSNotFound;          // attributes do not cross a line
    }
    return NSNotFound;
}


/// The `]` that closes the `[` at `start`, brackets inside counted.
NS_INLINE NSUInteger MPEndOfBrackets(NSString *text, NSUInteger start)
{
    NSUInteger length = text.length;
    NSInteger depth = 0;
    for (NSUInteger i = start; i < length; i++)
    {
        unichar c = [text characterAtIndex:i];
        if (c == '\\')
        {
            i++;                        // an escaped bracket is a bracket
            continue;
        }
        if (c == '[')
            depth++;
        else if (c == ']')
        {
            depth--;
            if (!depth)
                return i;
        }
    }
    return NSNotFound;
}


/** The lines that are code because of where they start.
 *
 * MPMarkdownCodeRanges knows fences and backticks and stops there, on
 * purpose: four spaces are also how the second paragraph of a list item is
 * written, and calling those code would be worse than missing them. Here
 * the safer half of the rule is enough — four spaces or a tab, after a
 * blank line or after another such line — because what it buys is *not*
 * rewriting something, and not rewriting is the harmless mistake.
 */
static NSArray<NSValue *> *MPIndentedCodeRanges(NSString *text)
{
    NSMutableArray *ranges = [NSMutableArray array];
    NSUInteger at = 0;
    BOOL previousWasBlank = YES;        // the start of a document counts
    BOOL previousWasCode = NO;

    while (at < text.length)
    {
        NSUInteger start = 0, end = 0, contentsEnd = 0;
        [text getLineStart:&start end:&end contentsEnd:&contentsEnd
                  forRange:NSMakeRange(at, 0)];
        NSString *line = [text substringWithRange:
            NSMakeRange(start, contentsEnd - start)];
        BOOL blank = ![line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]].length;
        BOOL indented = !blank
            && ([line hasPrefix:@"    "] || [line hasPrefix:@"\t"]);
        BOOL isCode = indented && (previousWasBlank || previousWasCode);

        if (isCode)
        {
            [ranges addObject:[NSValue valueWithRange:
                NSMakeRange(start, contentsEnd - start)]];
        }
        previousWasBlank = blank;
        previousWasCode = isCode || (blank && previousWasCode);

        if (end <= at)
            break;
        at = end;
    }
    return ranges;
}


NS_INLINE BOOL MPRangeIsInside(NSUInteger location, NSArray<NSValue *> *ranges)
{
    for (NSValue *value in ranges)
    {
        NSRange range = value.rangeValue;
        if (NSLocationInRange(location, range))
            return YES;
        if (range.location > location)
            break;                      // they come in order
    }
    return NO;
}


static NSString *MPSpansInText(NSString *text, NSUInteger depth)
{
    if (!text.length || [text rangeOfString:@"{"].location == NSNotFound)
        return text;

    NSMutableArray<NSValue *> *code =
        [MPMarkdownCodeRanges(text) mutableCopy];
    [code addObjectsFromArray:MPIndentedCodeRanges(text)];
    [code sortUsingComparator:^NSComparisonResult (NSValue *a, NSValue *b) {
        NSUInteger one = a.rangeValue.location;
        NSUInteger two = b.rangeValue.location;
        return one < two ? NSOrderedAscending
             : one > two ? NSOrderedDescending : NSOrderedSame;
    }];
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    NSUInteger length = text.length;
    NSUInteger copied = 0;

    for (NSUInteger i = 0; i < length; i++)
    {
        unichar c = [text characterAtIndex:i];
        if (c == '\\')
        {
            i++;
            continue;
        }
        if (c != '[' || MPRangeIsInside(i, code))
            continue;
        // An image carries its own brackets and its own meaning.
        if (i > 0 && [text characterAtIndex:i - 1] == '!')
            continue;

        NSUInteger close = MPEndOfBrackets(text, i);
        if (close == NSNotFound)
            break;                      // nothing closes: the rest is text
        if (close + 1 >= length || [text characterAtIndex:close + 1] != '{')
        {
            i = close;                  // a link, a reference, a footnote
            continue;
        }
        NSUInteger end = MPEndOfBraces(text, close + 1);
        if (end == NSNotFound)
        {
            i = close;
            continue;
        }

        NSString *braces = [text substringWithRange:
            NSMakeRange(close + 2, end - close - 2)];
        NSDictionary *attributes = MPAttributesFromBraces(braces);
        if (!attributes)
        {
            i = close;                  // not attributes: leave it written
            continue;
        }

        NSString *inner = [text substringWithRange:
            NSMakeRange(i + 1, close - i - 1)];
        if (depth < kMPSpanDepth)
            inner = MPSpansInText(inner, depth + 1);

        [out appendString:[text substringWithRange:
            NSMakeRange(copied, i - copied)]];
        [out appendString:@"<span"];
        // In a fixed order, so that the same document always gives the same
        // HTML — a preview that reshuffles its own attributes is a diff
        // nobody asked for.
        for (NSString *key in @[@"id", @"class", @"style", @"title",
                                @"lang", @"dir"])
        {
            NSString *value = attributes[key];
            if (value)
                [out appendFormat:@" %@=\"%@\"", key,
                                  MPEscapedForAttribute(value)];
        }
        for (NSString *key in [attributes.allKeys sortedArrayUsingSelector:
                                   @selector(compare:)])
        {
            if ([key hasPrefix:@"data-"])
                [out appendFormat:@" %@=\"%@\"", key,
                                  MPEscapedForAttribute(attributes[key])];
        }
        [out appendFormat:@">%@</span>", inner];

        copied = end + 1;
        i = end;
    }

    if (!copied)
        return text;
    [out appendString:[text substringFromIndex:copied]];
    return out;
}


NSString *MPMarkdownWithAttributedSpans(NSString *text)
{
    return MPSpansInText(text ?: @"", 0);
}


#pragma mark - Writing one

NSString *MPSpanColouring(NSString *text, NSString *colour)
{
    NSString *body = text ?: @"";
    // Text that is already a span of its own gets the colour put into it
    // rather than a second span wrapped around the first: two spans deep
    // is what happens when somebody changes their mind twice.
    if ([body hasPrefix:@"["] )
    {
        NSUInteger close = MPEndOfBrackets(body, 0);
        if (close != NSNotFound && close + 1 < body.length
                && [body characterAtIndex:close + 1] == '{'
                && MPEndOfBraces(body, close + 1) == body.length - 1)
        {
            NSString *braces = [body substringWithRange:
                NSMakeRange(close + 2, body.length - close - 3)];
            NSDictionary *attributes = MPAttributesFromBraces(braces);
            if (attributes)
            {
                NSMutableArray *kept = [NSMutableArray array];
                NSString *style = attributes[@"style"];
                NSMutableArray *declarations = [NSMutableArray array];
                for (NSString *one in [style componentsSeparatedByString:@";"])
                {
                    NSString *trimmed = [one stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceCharacterSet]];
                    if (trimmed.length
                            && ![trimmed.lowercaseString hasPrefix:@"color:"])
                        [declarations addObject:trimmed];
                }
                [declarations addObject:
                    [NSString stringWithFormat:@"color:%@", colour]];
                if (attributes[@"id"])
                    [kept addObject:[@"#" stringByAppendingString:
                        attributes[@"id"]]];
                for (NSString *name in [attributes[@"class"]
                        componentsSeparatedByString:@" "])
                {
                    if (name.length)
                        [kept addObject:[@"." stringByAppendingString:name]];
                }
                [kept addObject:[NSString stringWithFormat:@"style=\"%@\"",
                    [declarations componentsJoinedByString:@";"]]];
                for (NSString *key in [attributes.allKeys sortedArrayUsingSelector:
                                           @selector(compare:)])
                {
                    if ([key isEqualToString:@"id"]
                            || [key isEqualToString:@"class"]
                            || [key isEqualToString:@"style"])
                        continue;
                    [kept addObject:[NSString stringWithFormat:@"%@=\"%@\"",
                        key, attributes[key]]];
                }
                NSString *inner = [body substringWithRange:
                    NSMakeRange(1, close - 1)];
                return [NSString stringWithFormat:@"[%@]{%@}", inner,
                    [kept componentsJoinedByString:@" "]];
            }
        }
    }
    return [NSString stringWithFormat:@"[%@]{style=\"color:%@\"}",
            body, colour];
}
