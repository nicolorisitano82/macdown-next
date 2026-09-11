//
//  MPMarkdownText.m
//  MacDown
//

#import "MPMarkdownText.h"


NSUInteger MPLineNumberForLocation(NSString *text, NSUInteger location)
{
    if (!text.length)
        return 1;
    location = MIN(location, text.length);

    // One more line for each line ending passed, and not for the last line
    // of a text that does not end with one: its end is on it, not after it.
    NSUInteger line = 1;
    NSUInteger at = 0;
    while (at < location)
    {
        NSUInteger start = 0, end = 0, contentsEnd = 0;
        [text getLineStart:&start end:&end contentsEnd:&contentsEnd
                  forRange:NSMakeRange(at, 0)];
        if (end <= at || end > location || contentsEnd == end)
            break;
        line++;
        at = end;
    }
    return line;
}


NSArray<NSValue *> *MPMarkdownCodeRanges(NSString *text)
{
    NSMutableArray *ranges = [NSMutableArray array];

    // Fenced blocks first, line by line, because a fence is a whole line
    // and an inline span inside one is part of the block.
    NSUInteger at = 0;
    NSUInteger openedAt = NSNotFound;
    unichar fence = 0;
    NSUInteger fenceLength = 0;

    while (at < text.length)
    {
        NSUInteger start = 0, end = 0, contentsEnd = 0;
        [text getLineStart:&start end:&end contentsEnd:&contentsEnd
                  forRange:NSMakeRange(at, 0)];
        NSString *line = [text substringWithRange:
            NSMakeRange(start, contentsEnd - start)];
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];

        NSUInteger run = 0;
        unichar character = 0;
        if (trimmed.length >= 3)
        {
            character = [trimmed characterAtIndex:0];
            if (character == '`' || character == '~')
            {
                while (run < trimmed.length
                       && [trimmed characterAtIndex:run] == character)
                    run++;
                if (run < 3)
                    run = 0;
            }
        }

        if (run && openedAt == NSNotFound)
        {
            openedAt = start;
            fence = character;
            fenceLength = run;
        }
        else if (run && character == fence && run >= fenceLength)
        {
            [ranges addObject:[NSValue valueWithRange:
                NSMakeRange(openedAt, contentsEnd - openedAt)]];
            openedAt = NSNotFound;
        }

        if (end <= at)
            break;
        at = end;
    }
    // A fence that never closes takes the rest of the document with it,
    // which is what the parser does too.
    if (openedAt != NSNotFound)
    {
        [ranges addObject:[NSValue valueWithRange:
            NSMakeRange(openedAt, text.length - openedAt)]];
    }

    static NSRegularExpression *inlineCode = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        inlineCode = [[NSRegularExpression alloc]
            initWithPattern:@"`+[^`\\n]*`+" options:0 error:NULL];
    });
    for (NSTextCheckingResult *span in [inlineCode matchesInString:text
            options:0 range:NSMakeRange(0, text.length)])
    {
        [ranges addObject:[NSValue valueWithRange:span.range]];
    }

    return ranges;
}


BOOL MPCharacterIsWhitespace(unichar character)
{
    static NSCharacterSet *whitespaces = nil;
    if (!whitespaces)
        whitespaces = [NSCharacterSet whitespaceCharacterSet];
    return [whitespaces characterIsMember:character];
}

BOOL MPCharacterIsNewline(unichar character)
{
    static NSCharacterSet *newlines = nil;
    if (!newlines)
        newlines = [NSCharacterSet newlineCharacterSet];
    return [newlines characterIsMember:character];
}

BOOL MPStringIsNewline(NSString *str)
{
    if (str.length != 1)
        return NO;
    return MPCharacterIsNewline([str characterAtIndex:0]);
}
