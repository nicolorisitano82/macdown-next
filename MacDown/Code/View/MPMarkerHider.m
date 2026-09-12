//
//  MPMarkerHider.m
//  MacDown
//

#import "MPMarkerHider.h"

#import "MPAttributedSpans.h"
#import "MPEditorView.h"


@interface MPMarkerHider ()
@property (weak, nonatomic) NSTextView *textView;
/// Every marker character in the document.
@property (strong, nonatomic) NSMutableIndexSet *markers;
/// The constructs themselves, so the caret can be placed inside one.
@property (strong, nonatomic) NSMutableArray<NSValue *> *constructs;
/// The hidden run at each end, in step with -constructs. Emphasis has two
/// of the same length; a link has `[` at one end and `](url)` at the other.
@property (strong, nonatomic) NSMutableArray<NSValue *> *openings;
@property (strong, nonatomic) NSMutableArray<NSValue *> *closings;
/// The markers currently shown because the caret is in their construct.
@property (strong, nonatomic) NSIndexSet *revealed;
@end


@implementation MPMarkerHider

- (instancetype)initWithTextView:(NSTextView *)textView
{
    self = [super init];
    if (!self)
        return nil;
    _textView = textView;
    _markers = [NSMutableIndexSet indexSet];
    _constructs = [NSMutableArray array];
    _openings = [NSMutableArray array];
    _closings = [NSMutableArray array];
    _revealed = [NSIndexSet indexSet];
    textView.layoutManager.delegate = self;

    // The parse arrives after a pause, and the text keeps moving in the
    // meantime. Without this the recorded positions are a description of a
    // document that no longer exists, and a deletion aimed at a marker
    // lands on a letter.
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(textStorageDidProcessEditing:)
               name:NSTextStorageDidProcessEditingNotification
             object:textView.textStorage];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Keeping up with the text

/** Moves the recorded constructs to where the edit left them.
 *
 * Three things can happen to a construct. An edit before it slides it along;
 * an edit inside its content stretches it; an edit that touches one of its
 * delimiters destroys it as a construct, and it is forgotten until the next
 * parse says otherwise.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
    NSTextStorage *storage = notification.object;
    if (!(storage.editedMask & NSTextStorageEditedCharacters))
        return;
    if (!self.constructs.count)
        return;

    NSInteger delta = storage.changeInLength;
    NSRange edited = storage.editedRange;
    // The range as it was before the edit, which is what the recorded
    // positions are still describing.
    NSRange was = NSMakeRange(edited.location,
                              edited.length >= (NSUInteger)MAX(delta, 0)
                                  ? edited.length - delta : 0);

    NSMutableArray<NSValue *> *constructs = [NSMutableArray array];
    NSMutableArray<NSValue *> *openings = [NSMutableArray array];
    NSMutableArray<NSValue *> *closings = [NSMutableArray array];
    NSMutableIndexSet *markers = [NSMutableIndexSet indexSet];

    for (NSUInteger i = 0; i < self.constructs.count; i++)
    {
        NSRange construct = self.constructs[i].rangeValue;
        NSRange opening = self.openings[i].rangeValue;
        NSRange closing = self.closings[i].rangeValue;

        if (NSMaxRange(was) <= construct.location)
        {
            construct.location += delta;
            opening.location += delta;
            closing.location += delta;
        }
        else if (was.location >= NSMaxRange(construct))
        {
            // Untouched.
        }
        else if (was.location >= NSMaxRange(opening)
                 && NSMaxRange(was) <= closing.location)
        {
            construct.length += delta;
            closing.location += delta;
        }
        else
        {
            continue;
        }

        if (NSMaxRange(construct) > storage.length
                || closing.location < NSMaxRange(opening))
            continue;

        [constructs addObject:[NSValue valueWithRange:construct]];
        [openings addObject:[NSValue valueWithRange:opening]];
        [closings addObject:[NSValue valueWithRange:closing]];
        [markers addIndexesInRange:opening];
        [markers addIndexesInRange:closing];
    }

    self.constructs = constructs;
    self.openings = openings;
    self.closings = closings;
    self.markers = markers;
    [self recomputeRevealed];
}

- (void)setEnabled:(BOOL)enabled
{
    if (_enabled == enabled)
        return;
    _enabled = enabled;
    [self invalidateRange:NSMakeRange(0, self.textView.textStorage.length)];
}


#pragma mark - Finding the markers

/** The delimiters of one construct, measured rather than assumed.
 *
 * The parser reports the whole of `**bold**` as one element and says nothing
 * about the asterisks, and the length is not fixed by the type: emphasis and
 * strong are the same type of thing with one or two markers, and inline code
 * takes as many backticks as the writer felt like. So both ends are measured
 * — the run of the same character inwards from each — and they have to
 * agree, or this is not a construct worth touching.
 */
- (BOOL)markerLength:(NSUInteger *)outLength
             inRange:(NSRange)range
                text:(NSString *)text
{
    if (range.length < 2 || NSMaxRange(range) > text.length)
        return NO;

    unichar first = [text characterAtIndex:range.location];
    if (first != '*' && first != '_' && first != '`')
        return NO;

    NSUInteger opening = 0;
    while (opening < range.length
           && [text characterAtIndex:range.location + opening] == first)
        opening++;

    NSUInteger closing = 0;
    while (closing < range.length
           && [text characterAtIndex:NSMaxRange(range) - 1 - closing] == first)
        closing++;

    // Unbalanced, or nothing left between them: leave it alone. A construct
    // whose markers are longer than its content is more likely a row of
    // asterisks than something to hide.
    if (opening != closing || opening == 0 || opening * 2 >= range.length)
        return NO;

    *outLength = opening;
    return YES;
}

/// Records one construct and the two runs to hide at its ends.
- (void)addConstruct:(NSRange)range
             opening:(NSRange)opening
             closing:(NSRange)closing
{
    [self.markers addIndexesInRange:opening];
    [self.markers addIndexesInRange:closing];
    [self.constructs addObject:[NSValue valueWithRange:range]];
    [self.openings addObject:[NSValue valueWithRange:opening]];
    [self.closings addObject:[NSValue valueWithRange:closing]];
}

/** The two ends of an inline link, which are not the same length.
 *
 * `[text](url)` shows its text and hides the rest: the bracket at the front,
 * and everything from the closing bracket to the end. Inline links only — a
 * reference link points at a definition elsewhere, and hiding the pointer
 * would leave no way to see which definition it meant.
 */
- (BOOL)linkEnds:(NSRange)range
            text:(NSString *)text
         opening:(NSRange *)opening
         closing:(NSRange *)closing
{
    if (range.length < 4 || [text characterAtIndex:range.location] != '[')
        return NO;
    if ([text characterAtIndex:NSMaxRange(range) - 1] != ')')
        return NO;

    // The bracket that closes the text, taken as the last one before the
    // parenthesis so that a link whose text contains brackets still works.
    NSRange search = NSMakeRange(range.location,
                                 range.length - 1);
    NSRange bracket = [text rangeOfString:@"](" options:NSBackwardsSearch
                                    range:search];
    if (bracket.location == NSNotFound)
        return NO;

    // Nothing left to show once both ends are gone: not worth hiding.
    if (bracket.location <= range.location)
        return NO;

    *opening = NSMakeRange(range.location, 1);
    *closing = NSMakeRange(bracket.location,
                           NSMaxRange(range) - bracket.location);
    return YES;
}

/** The two ends of `[testo]{...}`, which the parser knows nothing about.
 *
 * The same treatment as an inline link, and for the same reason: the words
 * are what the document says, the braces are how it says it. So the
 * opening bracket goes and everything from the closing one to the last
 * brace goes with it, until the caret arrives.
 *
 * pmh has never heard of this syntax, so the ranges come from the reading
 * that does the rewriting — one reading, one answer.
 */
- (void)addAttributedSpans:(NSString *)text
{
    for (MPAttributedSpan *span in MPAttributedSpansIn(text))
    {
        // Nothing left to look at once both ends are hidden.
        if (!span.content.length)
            continue;
        [self addConstruct:span.range
                   opening:NSMakeRange(span.range.location, 1)
                   closing:NSMakeRange(NSMaxRange(span.content),
                                       NSMaxRange(span.range)
                                           - NSMaxRange(span.content))];
    }
}


/** The hashes at the front of a heading, and any at the back.
 *
 * ATX only — `# Titolo`. A setext heading is underlined on the line below,
 * and suppressing a whole line's glyphs leaves the line itself behind: the
 * marks go, the empty row does not, and a gap under every such heading
 * would be worse than the two equals signs it replaced.
 *
 * The space after the hashes goes with them. Hiding `##` but keeping its
 * space would indent the heading by one character for no reason anybody
 * could see.
 */
- (BOOL)headingEnds:(NSRange)range
               text:(NSString *)text
            opening:(NSRange *)opening
            closing:(NSRange *)closing
{
    if (!range.length || [text characterAtIndex:range.location] != '#')
        return NO;

    NSUInteger head = 0;
    while (head < range.length
           && [text characterAtIndex:range.location + head] == '#')
        head++;
    if (head > 6)
        return NO;
    while (range.location + head < NSMaxRange(range)
           && [text characterAtIndex:range.location + head] == ' ')
        head++;
    if (head >= range.length)
        return NO;      // Hashes and nothing else.

    // The optional closing run, with the spaces that separate it from the
    // words: `# Titolo #` is a heading called Titolo, not `Titolo #`.
    NSUInteger tail = 0;
    while (tail < range.length - head
           && [text characterAtIndex:NSMaxRange(range) - 1 - tail] == '#')
        tail++;
    if (tail)
    {
        while (tail < range.length - head
               && [text characterAtIndex:NSMaxRange(range) - 1 - tail] == ' ')
            tail++;
    }
    if (head + tail >= range.length)
        return NO;

    *opening = NSMakeRange(range.location, head);
    *closing = NSMakeRange(NSMaxRange(range) - tail, tail);
    return YES;
}

/** Records one `>` at the head of a quoted line.
 *
 * The parser hands over the marker itself, two characters, not the
 * quotation it introduces — so there is one of these per line already, and
 * the line it sits on supplies the words it applies to.
 *
 * A construct per line rather than one for the whole quotation is right
 * anyway: the marks are not a pair around the text, they are a prefix
 * repeated down the side of it, and revealing, deleting and stepping over
 * all work a construct at a time.
 *
 * With the marks gone a quotation reads as indented text with a rule beside
 * it, which is what the block layout already draws.
 */
- (void)addQuoteMarker:(NSRange)marker text:(NSString *)text
{
    NSRange line = [text lineRangeForRange:NSMakeRange(marker.location, 0)];
    NSUInteger end = NSMaxRange(line);
    while (end > line.location)
    {
        unichar c = [text characterAtIndex:end - 1];
        if (c != '\n' && c != '\r')
            break;
        end--;
    }

    // The space the marker is customarily followed by belongs with it.
    NSUInteger head = NSMaxRange(marker);
    if (head < end && [text characterAtIndex:head] == ' ')
        head++;

    // A line that is nothing but its marker keeps it: hiding it would leave
    // a blank line with no hint of why it is there.
    if (head >= end || marker.location < line.location)
        return;

    [self addConstruct:NSMakeRange(line.location, end - line.location)
               opening:NSMakeRange(line.location, head - line.location)
               closing:NSMakeRange(end, 0)];
}

- (void)updateWithElements:(pmh_element **)elements
{
    NSString *text = self.textView.string;
    NSUInteger length = text.length;

    NSRange previous = NSMakeRange(0, length);
    [self.markers removeAllIndexes];
    [self.constructs removeAllObjects];
    [self.openings removeAllObjects];
    [self.closings removeAllObjects];

    NSMutableArray<NSValue *> *rules = [NSMutableArray array];
    if (elements != NULL && length && self.hidesRules)
    {
        NSCharacterSet *blank =
            [NSCharacterSet whitespaceAndNewlineCharacterSet];
        for (pmh_element *cursor = elements[pmh_HRULE]; cursor != NULL;
             cursor = cursor->next)
        {
            if (cursor->end <= cursor->pos || cursor->end > length)
                continue;
            NSRange range = NSMakeRange(cursor->pos,
                                        cursor->end - cursor->pos);

            // Down to the dashes themselves. The parser hands over the blank
            // line before them and the break after, and either one included
            // would put the drawn line on the wrong row — or, for the break,
            // run the rule into the paragraph that follows it.
            while (range.length > 0
                   && [blank characterIsMember:
                           [text characterAtIndex:NSMaxRange(range) - 1]])
                range.length--;
            while (range.length > 0
                   && [blank characterIsMember:
                           [text characterAtIndex:range.location]])
            {
                range.location++;
                range.length--;
            }
            if (!range.length)
                continue;

            // All delimiter and no content: deleting it deletes the rule,
            // which is the only sensible reading of backspacing over one.
            [self addConstruct:range opening:range
                       closing:NSMakeRange(NSMaxRange(range), 0)];
            [rules addObject:[NSValue valueWithRange:range]];
        }
    }

    if (elements != NULL && length)
    {
        NSCharacterSet *breaks = [NSCharacterSet newlineCharacterSet];
        for (pmh_element_type type = pmh_H1; type <= pmh_H6; type++)
        {
            for (pmh_element *cursor = elements[type]; cursor != NULL;
                 cursor = cursor->next)
            {
                if (cursor->end <= cursor->pos || cursor->end > length)
                    continue;
                NSRange range = NSMakeRange(cursor->pos,
                                            cursor->end - cursor->pos);
                while (range.length > 0
                       && [breaks characterIsMember:
                               [text characterAtIndex:NSMaxRange(range) - 1]])
                    range.length--;

                NSRange opening = NSMakeRange(0, 0);
                NSRange closing = NSMakeRange(0, 0);
                if ([self headingEnds:range text:text opening:&opening
                              closing:&closing])
                    [self addConstruct:range opening:opening closing:closing];
            }
        }

        for (pmh_element *cursor = elements[pmh_BLOCKQUOTE]; cursor != NULL;
             cursor = cursor->next)
        {
            if (cursor->end <= cursor->pos || cursor->end > length)
                continue;
            [self addQuoteMarker:NSMakeRange(cursor->pos,
                                             cursor->end - cursor->pos)
                            text:text];
        }

        [self addAttributedSpans:text];

        pmh_element_type types[] = {pmh_EMPH, pmh_STRONG, pmh_CODE,
                                    pmh_LINK};
        for (size_t t = 0; t < sizeof(types) / sizeof(types[0]); t++)
        {
            for (pmh_element *cursor = elements[types[t]]; cursor != NULL;
                 cursor = cursor->next)
            {
                if (cursor->end <= cursor->pos)
                    continue;
                NSRange range = NSMakeRange(cursor->pos,
                                            cursor->end - cursor->pos);
                // A stale list outliving an edit would be a crash rather
                // than a misplaced marker.
                if (NSMaxRange(range) > length)
                    continue;

                if (types[t] == pmh_LINK)
                {
                    NSRange opening = NSMakeRange(0, 0);
                    NSRange closing = NSMakeRange(0, 0);
                    if ([self linkEnds:range text:text opening:&opening
                               closing:&closing])
                    {
                        [self addConstruct:range opening:opening
                                   closing:closing];
                    }
                    continue;
                }

                NSUInteger marker = 0;
                if (![self markerLength:&marker inRange:range text:text])
                    continue;

                [self addConstruct:range
                           opening:NSMakeRange(range.location, marker)
                           closing:NSMakeRange(NSMaxRange(range) - marker,
                                               marker)];
            }
        }
    }

    // The view draws the line, but the ranges come from here: these are the
    // exact characters that stopped being drawn, and a second measurement
    // elsewhere could disagree with this one.
    if ([self.textView isKindOfClass:[MPEditorView class]])
        [(MPEditorView *)self.textView setRuleRanges:rules];

    [self recomputeRevealed];
    [self invalidateRange:previous];
}


#pragma mark - The caret

/** The markers to show, because the caret is working on their construct.
 *
 * Touching one is enough; being strictly inside it was not.
 *
 * A hidden delimiter takes no width, so the front of `_pippo_` and the
 * front of `pippo` are the same point on screen. A caret put there — by a
 * click, by Home, by arriving from the line above — sits at the
 * construct's edge while the reader believes it is at the start of the
 * word, and with the edges excluded the underscores stayed invisible at
 * precisely the two places someone goes to delete or change them. The same
 * at the far end. So the edges count as being in it.
 *
 * What this costs is the collapse on the closing delimiter: a construct
 * now stays open until the caret leaves it, rather than snapping shut the
 * moment its last asterisk is typed. That is the smaller surprise — what
 * is still under the caret is still being written.
 *
 * Every selected range, since a second caret is somewhere about to be
 * typed in as well.
 */
- (void)recomputeRevealed
{
    NSMutableIndexSet *shown = [NSMutableIndexSet indexSet];
    NSArray<NSValue *> *selections = self.textView.selectedRanges;

    for (NSValue *value in self.constructs)
    {
        NSRange construct = value.rangeValue;
        for (NSValue *selected in selections)
        {
            NSRange selection = selected.rangeValue;
            BOOL touching;
            if (selection.length)
            {
                // A selection that merely stops at the edge is not in it;
                // one that covers any of it is.
                touching =
                    NSIntersectionRange(selection, construct).length > 0;
            }
            else
            {
                touching = selection.location >= construct.location
                    && selection.location <= NSMaxRange(construct);
            }
            if (touching)
            {
                [shown addIndexesInRange:construct];
                break;
            }
        }
    }
    self.revealed = shown;
}

- (void)selectionDidChange
{
    if (!self.enabled)
        return;

    NSIndexSet *before = self.revealed;
    [self recomputeRevealed];
    if ([before isEqualToIndexSet:self.revealed])
        return;

    // Only what changed: the markers that were shown and no longer are, and
    // the other way round. Invalidating the document on every arrow key
    // would relayout it on every arrow key.
    NSMutableIndexSet *changed = [before mutableCopy];
    [changed addIndexes:self.revealed];
    if (!changed.count)
        return;

    NSUInteger first = changed.firstIndex;
    NSUInteger last = changed.lastIndex;
    [self invalidateRange:NSMakeRange(first, last - first + 1)];
}

- (void)invalidateRange:(NSRange)range
{
    NSLayoutManager *manager = self.textView.layoutManager;
    NSUInteger length = self.textView.textStorage.length;
    if (!manager || !length)
        return;

    range = NSIntersectionRange(range, NSMakeRange(0, length));
    if (!range.length)
        return;

    [manager invalidateGlyphsForCharacterRange:range changeInLength:0
                          actualCharacterRange:NULL];
    [manager invalidateLayoutForCharacterRange:range
                            actualCharacterRange:NULL];
}


- (BOOL)isHiddenMarkerAtIndex:(NSUInteger)index
{
    return self.enabled && [self.markers containsIndex:index]
        && ![self.revealed containsIndex:index];
}

- (BOOL)construct:(NSRange *)outRange
          content:(NSRange *)outContent
    coveringMarkerAtIndex:(NSUInteger)index
{
    // Only while this marker is hidden. Once it is drawn, deleting one
    // asterisk of a pair is ordinary text editing and not this class's
    // business — and taking the whole construct away instead would remove
    // characters the reader can see and did not aim at.
    if (![self isHiddenMarkerAtIndex:index])
        return NO;

    for (NSUInteger i = 0; i < self.constructs.count; i++)
    {
        NSRange range = self.constructs[i].rangeValue;
        if (!NSLocationInRange(index, range))
            continue;

        NSRange opening = self.openings[i].rangeValue;
        NSRange closing = self.closings[i].rangeValue;
        if (!NSLocationInRange(index, opening)
                && !NSLocationInRange(index, closing))
            continue;

        if (outRange)
            *outRange = range;
        if (outContent)
        {
            *outContent = NSMakeRange(NSMaxRange(opening),
                                      closing.location - NSMaxRange(opening));
        }
        return YES;
    }
    return NO;
}


#pragma mark - NSLayoutManagerDelegate

- (NSUInteger)layoutManager:(NSLayoutManager *)layoutManager
       shouldGenerateGlyphs:(const CGGlyph *)glyphs
                 properties:(const NSGlyphProperty *)properties
           characterIndexes:(const NSUInteger *)characterIndexes
                       font:(NSFont *)font
            forGlyphRange:(NSRange)glyphRange
{
    if (!self.enabled || !self.markers.count)
        return 0;

    // Only worth rewriting the run if it actually contains a hidden marker.
    BOOL any = NO;
    for (NSUInteger i = 0; i < glyphRange.length; i++)
    {
        NSUInteger index = characterIndexes[i];
        if ([self.markers containsIndex:index]
                && ![self.revealed containsIndex:index])
        {
            any = YES;
            break;
        }
    }
    if (!any)
        return 0;

    NSGlyphProperty *rewritten = calloc(glyphRange.length,
                                        sizeof(NSGlyphProperty));
    if (!rewritten)
        return 0;

    for (NSUInteger i = 0; i < glyphRange.length; i++)
    {
        NSUInteger index = characterIndexes[i];
        BOOL hide = [self.markers containsIndex:index]
            && ![self.revealed containsIndex:index];
        // Null rather than ControlCharacter: the character keeps its place
        // in the text and its position in the layout, and simply draws
        // nothing. Deleting it still deletes one character, which is what
        // someone pressing backspace at that spot expects.
        rewritten[i] = hide ? NSGlyphPropertyNull : properties[i];
    }

    [layoutManager setGlyphs:glyphs properties:rewritten
            characterIndexes:characterIndexes font:font
                   forGlyphRange:glyphRange];
    free(rewritten);
    return glyphRange.length;
}

@end
