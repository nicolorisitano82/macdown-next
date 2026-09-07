//
//  MPPreviewSelection.m
//  MacDown
//

#import "MPPreviewSelection.h"


/// How far past the selection's own length the first-to-last-word span may
/// reach before it stops being that selection. `**test** e **ancora**` is
/// four characters of asterisks over eighteen of text; a span three times
/// the length plus a little is generous and still refuses a match that has
/// swallowed a paragraph.
static const NSUInteger kMPSpanSlack = 40;

/// A selection shorter than this says nothing about where it came from —
/// one letter appears everywhere — so nothing is selected in the editor.
static const NSUInteger kMPSelectionAtLeast = 2;


/// The selection as a pattern: every run of whitespace matches any other,
/// everything else matches itself.
static NSRegularExpression *MPPatternForText(NSString *text)
{
    NSMutableString *pattern = [NSMutableString string];
    NSScanner *scanner = [NSScanner scannerWithString:text];
    scanner.charactersToBeSkipped = nil;
    NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    while (!scanner.isAtEnd)
    {
        NSString *run = nil;
        if ([scanner scanCharactersFromSet:spaces intoString:&run])
        {
            [pattern appendString:@"\\s+"];
            continue;
        }
        if ([scanner scanUpToCharactersFromSet:spaces intoString:&run])
            [pattern appendString:
                [NSRegularExpression escapedPatternForString:run]];
    }
    if (!pattern.length)
        return nil;
    return [NSRegularExpression regularExpressionWithPattern:pattern
                                                     options:0 error:NULL];
}


/// The first match of that pattern inside `range`, or a not-found range.
static NSRange MPFirstMatch(NSRegularExpression *regex, NSString *source,
                            NSRange range)
{
    if (!regex || range.location == NSNotFound
            || NSMaxRange(range) > source.length)
        return NSMakeRange(NSNotFound, 0);
    NSTextCheckingResult *match = [regex firstMatchInString:source options:0
                                                      range:range];
    return match ? match.range : NSMakeRange(NSNotFound, 0);
}


/// The first and last words of the selection, for the third attempt.
static NSArray<NSString *> *MPEdgeWords(NSString *text)
{
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *piece in [text componentsSeparatedByCharactersInSet:
             [NSCharacterSet whitespaceAndNewlineCharacterSet]])
    {
        if (piece.length)
            [words addObject:piece];
    }
    // One word only: there is nothing to span between, and the first two
    // attempts have already looked for that word as written.
    if (words.count < 2)
        return nil;
    return @[words.firstObject, words.lastObject];
}


NSRange MPSourceRangeForPreviewText(NSString *source, NSString *selected,
                                    NSRange block)
{
    NSRange nowhere = NSMakeRange(NSNotFound, 0);
    if (!source.length || !selected.length)
        return nowhere;

    NSString *text = [selected stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length < kMPSelectionAtLeast)
        return nowhere;

    // The block as the page reported it, clamped to a source that may have
    // been typed in since.
    NSRange within = block;
    if (within.location == NSNotFound || within.location > source.length)
        within = NSMakeRange(0, source.length);
    else if (NSMaxRange(within) > source.length)
        within.length = source.length - within.location;

    NSRegularExpression *regex = MPPatternForText(text);

    // 1. Inside the block it came from.
    NSRange found = MPFirstMatch(regex, source, within);
    if (found.location != NSNotFound)
        return found;

    // 2. Anywhere, for a block whose offset has moved.
    found = MPFirstMatch(regex, source, NSMakeRange(0, source.length));
    if (found.location != NSNotFound)
        return found;

    // 3. First word to last word, inside the block: what is left when the
    // selection crossed markup the reader never saw.
    NSArray<NSString *> *edges = MPEdgeWords(text);
    if (edges.count != 2)
        return nowhere;

    NSRange first = MPFirstMatch(MPPatternForText(edges[0]), source, within);
    if (first.location == NSNotFound)
        return nowhere;

    NSRange rest = NSMakeRange(NSMaxRange(first),
                               NSMaxRange(within) - NSMaxRange(first));
    NSRange last = MPFirstMatch(MPPatternForText(edges[1]), source, rest);
    if (last.location == NSNotFound)
        return nowhere;

    NSRange span = NSMakeRange(first.location,
                               NSMaxRange(last) - first.location);
    if (span.length > text.length * 3 + kMPSpanSlack)
        return nowhere;         // that is no longer the selection
    return span;
}


#pragma mark - What the page reports

/** Keeps the two panes pointing at the same block.
 *
 * The blocks carry data-src, the byte offset they were rendered from; see
 * the patch to hoedown. Everything here works off that.
 *
 * The style is injected rather than added to the renderer's stylesheets on
 * purpose: a bar marking where the reader is working is an aid to editing,
 * and has no business in an exported document.
 */
NSString *MPSelectionWatchScript(void)
{
    return
    @"(function(){"
    @"var style=document.createElement('style');"
    @"style.textContent='"
    // Never on a table row. An absolutely positioned pseudo-element is
    // still a child of the row, and a row lays its children out in cells:
    // the browser makes an anonymous one to hold it, and the whole header
    // shifts a column to the right. The row hangs its bar from its first
    // cell instead, which is an ordinary block and takes one happily.
    @"[data-src]:not(tr){position:relative}"
    @"tr.macdown-here>:first-child{position:relative}"
    @".macdown-here:not(tr)::before,"
    @"tr.macdown-here>:first-child::before{content:\"\";position:absolute;"
    @"left:-14px;top:0;bottom:0;width:3px;border-radius:2px;"
    @"background:currentColor;opacity:0.35}"
    @"';"
    @"document.head.appendChild(style);"
    @"function blocks(){"
    @"return Array.prototype.slice.call("
    @"document.querySelectorAll('[data-src]'));}"
    @"window.MacDownMarkHere=function(offset){"
    @"var all=blocks(),found=null;"
    @"for(var i=0;i<all.length;i++){"
    @"if(parseInt(all[i].getAttribute('data-src'),10)<=offset)found=all[i];"
    @"else break;}"
    @"for(var j=0;j<all.length;j++)"
    @"all[j].classList.toggle('macdown-here',all[j]===found);"
    @"};"
    @"function report(done){"
    @"var sel=document.getSelection();"
    @"if(!sel||!sel.anchorNode)return;"
    @"var node=sel.anchorNode;"
    @"if(node.nodeType===3)node=node.parentElement;"
    // Which cell of its row, when the click landed in one. Only for a
    // click that selects nothing: dragging across a table is someone
    // copying out of the preview, and taking the focus away mid-drag
    // would throw the selection they were making.
    @"var cell=-1;"
    @"if(sel.isCollapsed){"
    @"var c=node;"
    @"while(c&&c.tagName!=='TD'&&c.tagName!=='TH'&&c.tagName!=='TABLE')"
    @"c=c.parentElement;"
    @"if(c&&c.tagName!=='TABLE'&&c.parentElement)"
    @"cell=Array.prototype.indexOf.call(c.parentElement.children,c);}"
    @"while(node&&!node.hasAttribute('data-src'))node=node.parentElement;"
    @"if(!node)return;"
    @"var all=blocks(),i=all.indexOf(node);"
    @"var begin=parseInt(node.getAttribute('data-src'),10);"
    @"var end=(i>=0&&i+1<all.length)"
    @"?parseInt(all[i+1].getAttribute('data-src'),10):-1;"
    @"window.webkit.messageHandlers.macdownSelection.postMessage("
    @"{begin:begin,end:end,cell:cell,text:done?sel.toString():'',"
    @"done:!!done});}"
    @"var pending=false;"
    // setTimeout rather than requestAnimationFrame: a frame callback only
    // arrives while the page is being drawn, and a preview whose pane is
    // collapsed is not. Measured — headless, nothing ever reported.
    @"document.addEventListener('selectionchange',function(){"
    @"if(pending)return;pending=true;"
    @"setTimeout(function(){pending=false;report(false);},0);"
    @"});"
    // The end of the gesture, and the only moment the selected text is
    // worth sending: reporting it while the pointer is still down would
    // take the focus away from a reader in the middle of dragging one.
    @"document.addEventListener('mouseup',function(){"
    @"setTimeout(function(){report(true);},0);"
    @"});"
    @"})();";
}
