//
//  MPDiff.m
//  MacDown
//

#import "MPDiff.h"


/// Past this many differences the comparison stops looking for the shortest
/// path and says «from here on, changed». Myers' algorithm costs about one
/// step per difference, which is nothing for two versions of a document and
/// a great deal for two texts that have nothing to do with each other.
static const NSUInteger kMPDiffEffortLimit = 20000;


@interface MPDiffRow ()
@property (nonatomic) MPDiffKind kind;
@property (copy, nonatomic) NSString *left;
@property (copy, nonatomic) NSString *right;
@property (nonatomic) NSUInteger leftLine;
@property (nonatomic) NSUInteger rightLine;
@end

@implementation MPDiffRow

- (NSString *)description
{
    static NSString * const names[] = {@"=", @"+", @"−", @"≠"};
    return [NSString stringWithFormat:@"%@ %lu|%lu %@ / %@", names[self.kind],
            (unsigned long)self.leftLine, (unsigned long)self.rightLine,
            self.left ?: @"—", self.right ?: @"—"];
}

@end


const MPDiffOptions MPDiffOptionsStrict = {
    .grain = MPDiffByLines, .ignoringSpace = NO, .ignoringCase = NO,
};


NSArray<NSString *> *MPDiffLinesOfText(NSString *text)
{
    if (!text.length)
        return @[];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        [lines addObject:line];
    }];
    return lines;
}


/// Whether a line is a fence, and not a line of prose showing one.
///
/// ```` ```mermaid ```` — four backticks quoting three — is how a document
/// about Markdown writes a fence it does not mean. Taken for a fence it
/// opens a code block that never closes, and every paragraph after it stops
/// being a paragraph. What follows a real backtick fence carries no
/// backtick at all, which is exactly the rule that tells them apart.
static BOOL MPDiffLineOpensAFence(NSString *trimmed)
{
    if (trimmed.length < 3)
        return NO;
    unichar first = [trimmed characterAtIndex:0];
    if (first != '`' && first != '~')
        return NO;

    NSUInteger run = 0;
    while (run < trimmed.length && [trimmed characterAtIndex:run] == first)
        run++;
    if (run < 3)
        return NO;
    if (first == '`'
            && [[trimmed substringFromIndex:run]
                rangeOfString:@"`"].location != NSNotFound)
        return NO;
    return YES;
}


/// Whether a line is prose that runs on, or something whose line ending is
/// part of what it says: a heading, a list item, a table row, a quotation,
/// an indented block, a fence — or the blank line between two paragraphs.
///
/// The rules are exact on purpose. A first version took any line starting
/// with a backtick or a dash as a block, and a paragraph that happened to
/// wrap onto «`markdown`, `txt`; …» was cut in two on one side and not on
/// the other — which put back the false differences this whole grain
/// exists to remove.
static BOOL MPDiffLineStandsAlone(NSString *line)
{
    NSString *trimmed = [line stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if (!trimmed.length)
        return YES;                            // the gap between paragraphs
    if ([line hasPrefix:@"    "] || [line hasPrefix:@"\t"])
        return YES;                            // code, by indentation
    if ([trimmed hasPrefix:@"|"])
        return YES;                            // a table row
    if (MPDiffLineOpensAFence(trimmed))
        return YES;                            // a fence
    if ([trimmed hasPrefix:@">"])
        return YES;                            // a quotation

    // A heading is hashes and then a space: «#tag» is a word.
    NSUInteger hashes = 0;
    while (hashes < trimmed.length && [trimmed characterAtIndex:hashes] == '#')
        hashes++;
    if (hashes > 0 && hashes <= 6 && hashes < trimmed.length
            && [trimmed characterAtIndex:hashes] == ' ')
        return YES;

    // A list item is a marker and then a space: «- questo» is a list,
    // «- 5 gradi» in the middle of a sentence is not, but it is also not
    // how anybody writes one.
    unichar first = [trimmed characterAtIndex:0];
    if ((first == '-' || first == '*' || first == '+')
            && trimmed.length > 1 && [trimmed characterAtIndex:1] == ' ')
        return YES;

    // A rule, or the underline of a setext heading: three or more of the
    // same, and nothing else.
    if (first == '-' || first == '=' || first == '_')
    {
        NSUInteger run = 0;
        while (run < trimmed.length && [trimmed characterAtIndex:run] == first)
            run++;
        if (run >= 3 && run == trimmed.length)
            return YES;
    }

    // "1. " and "12) ", which are list items and not sentences.
    NSScanner *scanner = [NSScanner scannerWithString:trimmed];
    NSInteger number = 0;
    if ([scanner scanInteger:&number] && scanner.scanLocation < trimmed.length)
    {
        unichar after = [trimmed characterAtIndex:scanner.scanLocation];
        if ((after == '.' || after == ')')
                && scanner.scanLocation + 1 < trimmed.length
                && [trimmed characterAtIndex:scanner.scanLocation + 1] == ' ')
            return YES;
    }
    return NO;
}


/// The units, and the line each one starts on, in one pass — the two
/// answers come from the same walk and must not disagree.
static void MPDiffWalkUnits(NSString *text, MPDiffGrain grain,
                            NSMutableArray<NSString *> *units,
                            NSMutableArray<NSNumber *> *firstLines)
{
    NSArray<NSString *> *lines = MPDiffLinesOfText(text);
    if (grain == MPDiffByLines)
    {
        [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger i,
                                            BOOL *stop) {
            [units addObject:line];
            [firstLines addObject:@(i + 1)];
        }];
        return;
    }

    NSMutableArray<NSString *> *paragraph = [NSMutableArray array];
    __block NSUInteger paragraphStarts = 0;
    void (^flush)(void) = ^{
        if (!paragraph.count)
            return;
        [units addObject:[paragraph componentsJoinedByString:@" "]];
        [firstLines addObject:@(paragraphStarts)];
        [paragraph removeAllObjects];
    };

    __block BOOL inFence = NO;
    [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger i,
                                        BOOL *stop) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        BOOL fence = MPDiffLineOpensAFence(trimmed);

        // Inside a fence every line stands alone, whatever it looks like:
        // it is code, and its line endings are its own.
        if (inFence || fence || MPDiffLineStandsAlone(line))
        {
            flush();
            [units addObject:line];
            [firstLines addObject:@(i + 1)];
            if (fence)
                inFence = !inFence;
            return;
        }

        if (!paragraph.count)
            paragraphStarts = i + 1;
        [paragraph addObject:[line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]]];
    }];
    flush();
}


NSArray<NSString *> *MPDiffUnitsOfText(NSString *text, MPDiffGrain grain)
{
    NSMutableArray<NSString *> *units = [NSMutableArray array];
    NSMutableArray<NSNumber *> *lines = [NSMutableArray array];
    MPDiffWalkUnits(text, grain, units, lines);
    return units;
}


NSArray<NSNumber *> *MPDiffFirstLinesOfUnits(NSString *text,
                                             MPDiffGrain grain)
{
    NSMutableArray<NSString *> *units = [NSMutableArray array];
    NSMutableArray<NSNumber *> *lines = [NSMutableArray array];
    MPDiffWalkUnits(text, grain, units, lines);
    return lines;
}


/// What two units are compared by. Never what is shown: ignoring case does
/// not mean showing the text in lower case.
static NSString *MPDiffKeyOf(NSString *unit, MPDiffOptions options)
{
    NSString *key = unit;
    if (options.ignoringSpace)
    {
        // Every run of blanks becomes one space, and the ends are trimmed:
        // indentation, double spaces after a full stop, a space left at the
        // end of a line.
        static NSRegularExpression *runs = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            runs = [[NSRegularExpression alloc] initWithPattern:@"[ \\t]+"
                                                        options:0 error:NULL];
        });
        key = [runs stringByReplacingMatchesInString:key options:0
                range:NSMakeRange(0, key.length) withTemplate:@" "];
        key = [key stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
    }
    if (options.ignoringCase)
        key = key.localizedLowercaseString;
    return key;
}


#pragma mark - The path between two lists

/// One step of the edit script: how many lines to take from each side.
typedef struct {
    NSUInteger left;
    NSUInteger right;
} MPDiffStep;


/** The shortest edit script between two lists, as Myers describes it.
 *
 * Answers the common lines as pairs of indices, in order. Everything not in
 * that list is an addition or a removal, which is what the caller works out
 * by walking the two lists alongside the pairs.
 *
 * Returns nil when the two texts are too far apart to be worth the search,
 * so that the caller can fall back to something honest and quick.
 */
static NSArray<NSValue *> *MPDiffCommonPairs(NSArray<NSString *> *left,
                                             NSArray<NSString *> *right)
{
    NSInteger n = (NSInteger)left.count;
    NSInteger m = (NSInteger)right.count;
    NSInteger max = n + m;
    if ((NSUInteger)max > kMPDiffEffortLimit * 2)
        return nil;

    // V[k] is how far along the left list a path of d differences reaches on
    // diagonal k. One snapshot per d, because the path is walked back at the
    // end to find out which lines were the same.
    NSInteger size = 2 * max + 1;
    NSInteger *v = calloc((size_t)size, sizeof(NSInteger));
    if (!v)
        return nil;
    NSMutableArray<NSData *> *trace = [NSMutableArray array];

    NSInteger found = -1;
    for (NSInteger d = 0; d <= max; d++)
    {
        if ((NSUInteger)d > kMPDiffEffortLimit)
            break;
        [trace addObject:[NSData dataWithBytes:v
                                        length:(NSUInteger)size * sizeof(NSInteger)]];

        for (NSInteger k = -d; k <= d; k += 2)
        {
            NSInteger index = k + max;
            NSInteger x;
            // Down (an addition) when the diagonal says so, right (a
            // removal) otherwise.
            if (k == -d || (k != d && v[index - 1] < v[index + 1]))
                x = v[index + 1];
            else
                x = v[index - 1] + 1;
            NSInteger y = x - k;

            while (x < n && y < m
                   && [left[(NSUInteger)x] isEqualToString:right[(NSUInteger)y]])
            {
                x++;
                y++;
            }
            v[index] = x;

            if (x >= n && y >= m)
            {
                found = d;
                break;
            }
        }
        if (found >= 0)
            break;
    }
    free(v);
    if (found < 0)
        return nil;

    // Back along the snapshots, collecting the lines both sides had.
    NSMutableArray<NSValue *> *pairs = [NSMutableArray array];
    NSInteger x = n;
    NSInteger y = m;
    for (NSInteger d = found; d > 0; d--)
    {
        const NSInteger *previous = [trace[(NSUInteger)d] bytes];
        NSInteger k = x - y;
        NSInteger index = k + max;
        NSInteger previousK;
        if (k == -d || (k != d && previous[index - 1] < previous[index + 1]))
            previousK = k + 1;
        else
            previousK = k - 1;

        NSInteger previousX = previous[previousK + max];
        NSInteger previousY = previousX - previousK;

        while (x > previousX && y > previousY)
        {
            x--;
            y--;
            [pairs addObject:[NSValue valueWithRange:
                NSMakeRange((NSUInteger)x, (NSUInteger)y)]];
        }
        x = previousX;
        y = previousY;
    }
    while (x > 0 && y > 0)
    {
        x--;
        y--;
        [pairs addObject:[NSValue valueWithRange:
            NSMakeRange((NSUInteger)x, (NSUInteger)y)]];
    }

    return [[pairs reverseObjectEnumerator] allObjects];
}


#pragma mark - The rows

static MPDiffRow *MPDiffMakeRow(MPDiffKind kind, NSString *left,
                                NSString *right, NSUInteger leftLine,
                                NSUInteger rightLine)
{
    MPDiffRow *row = [[MPDiffRow alloc] init];
    row.kind = kind;
    row.left = left;
    row.right = right;
    row.leftLine = leftLine;
    row.rightLine = rightLine;
    return row;
}


/** A run of removals and a run of additions, side by side.
 *
 * Two lines in the same place, one taken away and one put there, are one
 * change and not two events — that is how a person reads it. What is left
 * over when the two runs are of different lengths stays a removal or an
 * addition.
 */
static void MPDiffPairUp(NSMutableArray<MPDiffRow *> *rows,
                         NSArray<NSString *> *removed,
                         NSArray<NSString *> *added,
                         NSUInteger leftFrom, NSUInteger rightFrom)
{
    NSUInteger together = MIN(removed.count, added.count);
    for (NSUInteger i = 0; i < together; i++)
    {
        [rows addObject:MPDiffMakeRow(MPDiffChanged, removed[i], added[i],
                                      leftFrom + i + 1, rightFrom + i + 1)];
    }
    for (NSUInteger i = together; i < removed.count; i++)
    {
        [rows addObject:MPDiffMakeRow(MPDiffRemoved, removed[i], nil,
                                      leftFrom + i + 1, 0)];
    }
    for (NSUInteger i = together; i < added.count; i++)
    {
        [rows addObject:MPDiffMakeRow(MPDiffAdded, nil, added[i],
                                      0, rightFrom + i + 1)];
    }
}


NSArray<MPDiffRow *> *MPDiffRowsBetweenLines(NSArray<NSString *> *left,
                                             NSArray<NSString *> *right)
{
    left = left ?: @[];
    right = right ?: @[];

    NSMutableArray<MPDiffRow *> *rows = [NSMutableArray array];
    NSArray<NSValue *> *pairs = MPDiffCommonPairs(left, right);
    if (!pairs && (left.count || right.count))
    {
        // Too far apart to look for the shortest path: everything on the
        // left was taken away, everything on the right was put there. Said
        // plainly rather than approximated.
        MPDiffPairUp(rows, left, right, 0, 0);
        return rows;
    }

    NSUInteger leftAt = 0;
    NSUInteger rightAt = 0;
    for (NSValue *value in pairs)
    {
        NSRange pair = value.rangeValue;      // location: left, length: right
        NSUInteger x = pair.location;
        NSUInteger y = pair.length;

        if (x > leftAt || y > rightAt)
        {
            NSArray<NSString *> *removed = [left subarrayWithRange:
                NSMakeRange(leftAt, x - leftAt)];
            NSArray<NSString *> *added = [right subarrayWithRange:
                NSMakeRange(rightAt, y - rightAt)];
            MPDiffPairUp(rows, removed, added, leftAt, rightAt);
        }

        [rows addObject:MPDiffMakeRow(MPDiffEqual, left[x], right[y],
                                      x + 1, y + 1)];
        leftAt = x + 1;
        rightAt = y + 1;
    }

    if (leftAt < left.count || rightAt < right.count)
    {
        NSArray<NSString *> *removed = [left subarrayWithRange:
            NSMakeRange(leftAt, left.count - leftAt)];
        NSArray<NSString *> *added = [right subarrayWithRange:
            NSMakeRange(rightAt, right.count - rightAt)];
        MPDiffPairUp(rows, removed, added, leftAt, rightAt);
    }

    return rows;
}


NSArray<MPDiffRow *> *MPDiffRowsBetween(NSString *left, NSString *right)
{
    return MPDiffRowsBetweenWithOptions(left, right, MPDiffOptionsStrict);
}


NSArray<MPDiffRow *> *MPDiffRowsBetweenWithOptions(NSString *left,
                                                   NSString *right,
                                                   MPDiffOptions options)
{
    NSMutableArray<NSString *> *leftUnits = [NSMutableArray array];
    NSMutableArray<NSNumber *> *leftLines = [NSMutableArray array];
    MPDiffWalkUnits(left, options.grain, leftUnits, leftLines);
    NSMutableArray<NSString *> *rightUnits = [NSMutableArray array];
    NSMutableArray<NSNumber *> *rightLines = [NSMutableArray array];
    MPDiffWalkUnits(right, options.grain, rightUnits, rightLines);

    // Compared by the key, shown as it was written. The rows come back
    // against the keys and are then filled in with the real text, which is
    // what keeps «ignore case» from lowercasing somebody\'s document on
    // screen.
    NSMutableArray<NSString *> *leftKeys = [NSMutableArray array];
    for (NSString *unit in leftUnits)
        [leftKeys addObject:MPDiffKeyOf(unit, options)];
    NSMutableArray<NSString *> *rightKeys = [NSMutableArray array];
    for (NSString *unit in rightUnits)
        [rightKeys addObject:MPDiffKeyOf(unit, options)];

    NSArray<MPDiffRow *> *rows = MPDiffRowsBetweenLines(leftKeys, rightKeys);
    for (MPDiffRow *row in rows)
    {
        if (row.leftLine)
        {
            NSUInteger at = row.leftLine - 1;
            row.left = leftUnits[at];
            row.leftLine = leftLines[at].unsignedIntegerValue;
        }
        if (row.rightLine)
        {
            NSUInteger at = row.rightLine - 1;
            row.right = rightUnits[at];
            row.rightLine = rightLines[at].unsignedIntegerValue;
        }
    }
    return rows;
}


void MPDiffCounts(NSArray<MPDiffRow *> *rows, NSUInteger *added,
                  NSUInteger *removed, NSUInteger *changed)
{
    NSUInteger a = 0, r = 0, c = 0;
    for (MPDiffRow *row in rows)
    {
        switch (row.kind)
        {
            case MPDiffAdded:   a++; break;
            case MPDiffRemoved: r++; break;
            case MPDiffChanged: c++; break;
            case MPDiffEqual:   break;
        }
    }
    if (added)
        *added = a;
    if (removed)
        *removed = r;
    if (changed)
        *changed = c;
}


#pragma mark - Inside one changed line

/// A line as words and the gaps between them, so that a comparison inside a
/// line is made of things a reader recognises.
static NSArray<NSValue *> *MPDiffWordsOf(NSString *line)
{
    NSMutableArray<NSValue *> *words = [NSMutableArray array];
    NSCharacterSet *spaces = [NSCharacterSet whitespaceCharacterSet];
    NSUInteger at = 0;
    while (at < line.length)
    {
        BOOL space = [spaces characterIsMember:[line characterAtIndex:at]];
        NSUInteger start = at;
        while (at < line.length
               && [spaces characterIsMember:[line characterAtIndex:at]] == space)
            at++;
        [words addObject:[NSValue valueWithRange:
            NSMakeRange(start, at - start)]];
    }
    return words;
}


void MPDiffWordRanges(NSString *left, NSString *right,
                      NSArray<NSValue *> **leftRanges,
                      NSArray<NSValue *> **rightRanges)
{
    NSArray<NSValue *> *leftWords = MPDiffWordsOf(left ?: @"");
    NSArray<NSValue *> *rightWords = MPDiffWordsOf(right ?: @"");

    NSMutableArray<NSString *> *leftText = [NSMutableArray array];
    for (NSValue *value in leftWords)
        [leftText addObject:[left substringWithRange:value.rangeValue]];
    NSMutableArray<NSString *> *rightText = [NSMutableArray array];
    for (NSValue *value in rightWords)
        [rightText addObject:[right substringWithRange:value.rangeValue]];

    NSMutableArray<NSValue *> *onLeft = [NSMutableArray array];
    NSMutableArray<NSValue *> *onRight = [NSMutableArray array];
    NSArray<NSValue *> *pairs = MPDiffCommonPairs(leftText, rightText);

    if (!pairs)
    {
        // Nothing in common worth finding: the whole of each side is the
        // difference, which is true and says so.
        if (left.length)
            [onLeft addObject:[NSValue valueWithRange:
                NSMakeRange(0, left.length)]];
        if (right.length)
            [onRight addObject:[NSValue valueWithRange:
                NSMakeRange(0, right.length)]];
    }
    else
    {
        NSMutableIndexSet *sameLeft = [NSMutableIndexSet indexSet];
        NSMutableIndexSet *sameRight = [NSMutableIndexSet indexSet];
        for (NSValue *value in pairs)
        {
            NSRange pair = value.rangeValue;
            [sameLeft addIndex:pair.location];
            [sameRight addIndex:pair.length];
        }
        for (NSUInteger i = 0; i < leftWords.count; i++)
        {
            if (![sameLeft containsIndex:i])
                [onLeft addObject:leftWords[i]];
        }
        for (NSUInteger i = 0; i < rightWords.count; i++)
        {
            if (![sameRight containsIndex:i])
                [onRight addObject:rightWords[i]];
        }
    }

    // Neighbouring words become one mark: three marks on three words in a
    // row is three boxes where a reader sees one difference.
    NSArray<NSValue *> * (^joined)(NSArray<NSValue *> *) =
        ^(NSArray<NSValue *> *ranges) {
        NSMutableArray<NSValue *> *out = [NSMutableArray array];
        for (NSValue *value in ranges)
        {
            NSRange range = value.rangeValue;
            NSRange last = out.lastObject.rangeValue;
            if (out.count && NSMaxRange(last) == range.location)
            {
                out[out.count - 1] = [NSValue valueWithRange:
                    NSMakeRange(last.location, NSMaxRange(range) - last.location)];
                continue;
            }
            [out addObject:value];
        }
        return [out copy];
    };

    if (leftRanges)
        *leftRanges = joined(onLeft);
    if (rightRanges)
        *rightRanges = joined(onRight);
}
