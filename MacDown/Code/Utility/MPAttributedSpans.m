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


/** Reads the braces, and says whether they are attributes at all.
 *
 * Two different questions live in here and the difference matters: whether
 * what is written *is* an attribute list, and how much of it a document is
 * allowed to say. `{onclick="…"}` is the first without being any of the
 * second — well formed, and nothing survives — and the two callers want
 * different answers about it.
 */
static BOOL MPParseBraces(NSString *inside,
                          NSMutableDictionary<NSString *, NSString *> *into)
{
    NSMutableDictionary *attributes = into ?: [NSMutableDictionary dictionary];
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
                return NO;             // a lone dot is not an attribute
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
            return NO;                 // not attributes: leave it written
        NSString *key = [[inside substringWithRange:NSMakeRange(start, i - start)]
            lowercaseString];
        i++;                            // the =

        if (i >= length)
            return NO;
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
                return NO;             // a quote nobody closed
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
            return NO;

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
        return NO;                      // {} is not an attribute list
    if (classes.count)
        attributes[@"class"] = [classes componentsJoinedByString:@" "];
    return YES;
}


NSDictionary<NSString *, NSString *> *MPAttributesFromBraces(NSString *inside)
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (!MPParseBraces(inside, attributes))
        return nil;
    // Well formed and nothing left: the document asked for things it may
    // not have, and what it wrote stays written.
    return attributes.count ? attributes : nil;
}


/// Whether the braces are an attribute list, whatever survives of it.
NS_INLINE BOOL MPBracesAreWellFormed(NSString *inside)
{
    return MPParseBraces(inside, nil);
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


/** Whether the text has a blank line in it — a paragraph break.
 *
 * The line between two paragraphs, whether it is empty or only spaces.
 * What tells an inline construct from something that has outgrown the
 * idea.
 */
BOOL MPTextHasABlankLine(NSString *text)
{
    NSUInteger at = 0;
    BOOL previousWasBlank = NO;
    BOOL first = YES;
    while (at < text.length)
    {
        NSUInteger start = 0, end = 0, contentsEnd = 0;
        [text getLineStart:&start end:&end contentsEnd:&contentsEnd
                  forRange:NSMakeRange(at, 0)];
        BOOL blank = ![[text substringWithRange:
            NSMakeRange(start, contentsEnd - start)]
                stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]].length;
        // A blank line at the very start is a break only if something
        // follows it, which the loop finds on the next turn.
        if (blank && !first)
            return YES;
        if (blank && previousWasBlank)
            return YES;
        previousWasBlank = blank;
        first = NO;
        if (end <= at)
            break;
        at = end;
    }
    return NO;
}


@implementation MPAttributedSpan
@end


NSArray<MPAttributedSpan *> *MPAttributedSpansIn(NSString *text)
{
    NSMutableArray<MPAttributedSpan *> *found = [NSMutableArray array];
    NSUInteger length = text.length;
    if (!length || [text rangeOfString:@"{"].location == NSNotFound)
        return found;

    NSMutableArray<NSValue *> *code =
        [MPMarkdownCodeRanges(text) mutableCopy];
    [code addObjectsFromArray:MPIndentedCodeRanges(text)];
    [code sortUsingComparator:^NSComparisonResult (NSValue *a, NSValue *b) {
        NSUInteger one = a.rangeValue.location;
        NSUInteger two = b.rangeValue.location;
        return one < two ? NSOrderedAscending
             : one > two ? NSOrderedDescending : NSOrderedSame;
    }];

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

        // A span is inline, in Djot as in Pandoc: it lives inside one
        // paragraph. Without this a selection that happens to cover two
        // of them could be «styled» into something that is not a span at
        // all — brackets round half a document, and a `<span>` wrapped
        // round block markup on the page.
        NSRange content = NSMakeRange(i + 1, close - i - 1);
        if (MPTextHasABlankLine([text substringWithRange:content]))
        {
            i = close;
            continue;
        }

        MPAttributedSpan *span = [[MPAttributedSpan alloc] init];
        span.range = NSMakeRange(i, end - i + 1);
        span.content = content;
        span.attributes = attributes;
        [found addObject:span];
        i = end;
    }
    return found;
}


static NSString *MPSpansInText(NSString *text, NSUInteger depth)
{
    NSArray<MPAttributedSpan *> *spans = MPAttributedSpansIn(text);
    if (!spans.count)
        return text;

    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    NSUInteger copied = 0;

    for (MPAttributedSpan *span in spans)
    {
        NSDictionary *attributes = span.attributes;
        NSString *inner = [text substringWithRange:span.content];
        if (depth < kMPSpanDepth)
            inner = MPSpansInText(inner, depth + 1);

        [out appendString:[text substringWithRange:
            NSMakeRange(copied, span.range.location - copied)]];
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

        copied = NSMaxRange(span.range);
    }

    [out appendString:[text substringFromIndex:copied]];
    return out;
}


NSString *MPMarkdownWithAttributedSpans(NSString *text)
{
    return MPSpansInText(text ?: @"", 0);
}


#pragma mark - Writing one

NSString *MPStyleDeclaration(NSString *style, NSString *property)
{
    for (NSString *one in [style componentsSeparatedByString:@";"])
    {
        NSRange colon = [one rangeOfString:@":"];
        if (colon.location == NSNotFound)
            continue;
        NSCharacterSet *blank =
            [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *name = [[one substringToIndex:colon.location]
            stringByTrimmingCharactersInSet:blank];
        if ([name.lowercaseString isEqualToString:property.lowercaseString])
        {
            return [[one substringFromIndex:colon.location + 1]
                stringByTrimmingCharactersInSet:blank];
        }
    }
    return nil;
}


/** Where one attribute is inside the braces, as written.
 *
 * `item` covers `name=value` and `value` covers what is between the
 * quotes, both in the braces' own spelling. Everything that reads or
 * edits the braces goes through here, so there is one idea of where an
 * attribute begins and ends.
 */
static BOOL MPBracesFindAttribute(NSString *braces, NSString *name,
                                  NSRange *item, NSRange *value)
{
    NSUInteger length = braces.length;
    NSUInteger at = 0;

    while (at < length)
    {
        unichar c = [braces characterAtIndex:at];
        if (MPCharacterIsWhitespace(c))
        {
            at++;
            continue;
        }
        // A class or an identifier: a name, and on to the next.
        if (c == '.' || c == '#')
        {
            at++;
            while (at < length && MPIsNameCharacter([braces characterAtIndex:at]))
                at++;
            continue;
        }

        NSUInteger start = at;
        while (at < length && MPIsNameCharacter([braces characterAtIndex:at]))
            at++;
        if (at == start)
        {
            at++;                   // something unreadable: step over it
            continue;
        }
        NSString *found = [[braces substringWithRange:
            NSMakeRange(start, at - start)] lowercaseString];
        NSRange inside = NSMakeRange(NSNotFound, 0);

        if (at < length && [braces characterAtIndex:at] == '=')
        {
            at++;
            if (at < length && ([braces characterAtIndex:at] == '"'
                                || [braces characterAtIndex:at] == '\''))
            {
                unichar closing = [braces characterAtIndex:at++];
                NSUInteger from = at;
                while (at < length)
                {
                    unichar in = [braces characterAtIndex:at];
                    if (in == '\\' && at + 1 < length)
                        at++;
                    else if (in == closing)
                        break;
                    at++;
                }
                inside = NSMakeRange(from, at - from);
                if (at < length)
                    at++;           // the closing quote
            }
            else
            {
                NSUInteger from = at;
                while (at < length
                       && !MPCharacterIsWhitespace([braces characterAtIndex:at]))
                    at++;
                inside = NSMakeRange(from, at - from);
            }
        }

        if ([found isEqualToString:name.lowercaseString])
        {
            if (item)
                *item = NSMakeRange(start, at - start);
            if (value)
                *value = inside;
            return YES;
        }
    }
    return NO;
}


/// One attribute of a span's braces, exactly as it was written.
NS_INLINE NSString *MPRawAttribute(NSString *braces, NSString *name)
{
    NSRange value = NSMakeRange(NSNotFound, 0);
    if (!MPBracesFindAttribute(braces, name, NULL, &value)
            || value.location == NSNotFound)
        return nil;
    return [braces substringWithRange:value];
}


/** The braces with their style declaration replaced.
 *
 * Edited **as written** rather than rebuilt from what was understood.
 * Rebuilding would quietly delete whatever this does not handle — an
 * attribute it will not let through to the page, a declaration it has
 * never heard of — and a colour is no reason to throw away what somebody
 * else put in their own document.
 */
NS_INLINE NSString *MPBracesWithStyle(NSString *braces, NSString *style)
{
    NSString *written = style.length
        ? [NSString stringWithFormat:@"style=\"%@\"", style] : @"";
    NSRange item = NSMakeRange(NSNotFound, 0);

    if (!MPBracesFindAttribute(braces, @"style", &item, NULL))
    {
        if (!written.length)
            return braces;
        return braces.length
            ? [NSString stringWithFormat:@"%@ %@", braces, written]
            : written;
    }

    NSMutableString *out = [braces mutableCopy];
    [out replaceCharactersInRange:item withString:written];
    return [out stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


/// A style with one declaration put in, replaced, or taken out. Every
/// other declaration is kept, spelling and order included: this does not
/// know what they mean and has no business rewriting them.
NS_INLINE NSString *MPStyleSetting(NSString *style, NSString *property,
                                   NSString *value)
{
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    for (NSString *one in [style componentsSeparatedByString:@";"])
    {
        NSString *trimmed = [one stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!trimmed.length)
            continue;
        NSRange colon = [trimmed rangeOfString:@":"];
        NSString *name = colon.location == NSNotFound ? trimmed
            : [[trimmed substringToIndex:colon.location]
                stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]];
        if ([name.lowercaseString isEqualToString:property.lowercaseString])
            continue;               // the old one, on its way out
        [kept addObject:trimmed];
    }
    if (value.length)
        [kept addObject:[NSString stringWithFormat:@"%@:%@", property, value]];
    return [kept componentsJoinedByString:@";"];
}


NSString *MPSpanWithStyle(NSString *text, NSString *property, NSString *value)
{
    NSString *body = text ?: @"";

    // Words that are already a span are edited rather than wrapped again:
    // somebody who sets a colour and then a highlight should end up with
    // one span saying both.
    if ([body hasPrefix:@"["])
    {
        NSUInteger close = MPEndOfBrackets(body, 0);
        if (close != NSNotFound && close + 1 < body.length
                && [body characterAtIndex:close + 1] == '{'
                && MPEndOfBraces(body, close + 1) == body.length - 1)
        {
            NSString *braces = [body substringWithRange:
                NSMakeRange(close + 2, body.length - close - 3)];
            // Well formed is enough here: a span this will not let
            // through to the page is still a span somebody wrote, and
            // wrapping a second one round it would be a way of losing it.
            if (MPBracesAreWellFormed(braces))
            {
                NSString *inner = [body substringWithRange:
                    NSMakeRange(1, close - 1)];
                NSString *style = MPStyleSetting(
                    MPRawAttribute(braces, @"style") ?: @"", property, value);
                NSString *changed = MPBracesWithStyle(braces, style);
                // Braces left saying nothing are not braces: the words come
                // back as they were, which is what taking a colour off a
                // plain span should give.
                if (!changed.length)
                    return inner;
                return [NSString stringWithFormat:@"[%@]{%@}", inner,
                        changed];
            }
        }
    }

    NSString *style = MPStyleSetting(@"", property, value);
    if (!style.length)
        return body;
    return [NSString stringWithFormat:@"[%@]{style=\"%@\"}", body, style];
}


NSString *MPSpanColouring(NSString *text, NSString *colour)
{
    return MPSpanWithStyle(text, @"color", colour);
}
