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


/** What a character in the rendered page can have been in the source.
 *
 * The page is not what was typed. Smartypants turns a straight quote into a
 * curly one and two hyphens into a dash, and the renderer writes `&amp;`
 * for an ampersand; a reader selecting `l’editor` has `l\'editor` in front
 * of them in the editor. Each of those is one character in the page and
 * something else in the source, so the pattern accepts both.
 */
static NSString *MPPatternForCharacter(NSString *character)
{
    static NSDictionary<NSString *, NSString *> *alternatives;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        alternatives = @{
            @"\u201c": @"[\"\u201c\u201d]", @"\u201d": @"[\"\u201c\u201d]",
            @"\"": @"[\"\u201c\u201d]",
            @"\u2018": @"['\u2018\u2019]", @"\u2019": @"['\u2018\u2019]",
            @"'": @"['\u2018\u2019]",
            @"\u2013": @"(?:\u2013|--)",
            @"\u2014": @"(?:\u2014|---|--)",
            @"\u2026": @"(?:\u2026|\\.\\.\\.)",
            @"&": @"(?:&|&amp;)",
            @"<": @"(?:<|&lt;)",
            @">": @"(?:>|&gt;)",
        };
    });
    NSString *alternative = alternatives[character];
    return alternative ?: [NSRegularExpression
        escapedPatternForString:character];
}


/// The selection as a pattern: every run of whitespace matches any other,
/// everything else matches itself or whatever it was before the renderer
/// got to it.
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
        if (![scanner scanUpToCharactersFromSet:spaces intoString:&run])
            continue;
        [run enumerateSubstringsInRange:NSMakeRange(0, run.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *character, NSRange r,
                                          NSRange e, BOOL *stop) {
            [pattern appendString:MPPatternForCharacter(character)];
        }];
    }
    if (!pattern.length)
        return nil;
    return [NSRegularExpression regularExpressionWithPattern:pattern
                                                     options:0 error:NULL];
}


/** The match of that pattern inside `range` that the reader meant.
 *
 * With no idea where they were, the first one; with an idea, the one
 * nearest it. A paragraph that says "test" three times is the reason this
 * takes an argument at all.
 */
static NSRange MPMatchNear(NSRegularExpression *regex, NSString *source,
                           NSRange range, NSUInteger wanted)
{
    if (!regex || range.location == NSNotFound
            || NSMaxRange(range) > source.length)
        return NSMakeRange(NSNotFound, 0);

    __block NSRange best = NSMakeRange(NSNotFound, 0);
    __block NSUInteger closest = NSUIntegerMax;
    [regex enumerateMatchesInString:source options:0 range:range
                         usingBlock:^(NSTextCheckingResult *match,
                                      NSMatchingFlags flags, BOOL *stop) {
        if (!match)
            return;
        if (wanted == NSNotFound)
        {
            best = match.range;
            *stop = YES;
            return;
        }
        NSUInteger distance = match.range.location > wanted
            ? match.range.location - wanted : wanted - match.range.location;
        if (distance < closest)
        {
            closest = distance;
            best = match.range;
        }
    }];
    return best;
}


/// The first match of that pattern inside `range`, or a not-found range.
static NSRange MPFirstMatch(NSRegularExpression *regex, NSString *source,
                            NSRange range)
{
    return MPMatchNear(regex, source, range, NSNotFound);
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
                                    NSRange block, NSUInteger renderedOffset)
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

    // Where in the source the reader probably was: the block's own start
    // plus what the page counted before the selection. The source has more
    // characters than the page shows — markup — never fewer, so this is a
    // floor to measure distance from, not a guess at the answer.
    NSUInteger wanted = renderedOffset == NSNotFound
        ? NSNotFound : within.location + renderedOffset;

    NSRegularExpression *regex = MPPatternForText(text);

    // 1. Inside the block it came from, nearest to where they were.
    NSRange found = MPMatchNear(regex, source, within, wanted);
    if (found.location != NSNotFound)
        return found;

    // 2. Anywhere, for a block whose offset has moved.
    found = MPMatchNear(regex, source, NSMakeRange(0, source.length), wanted);
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
    // What was selected stays visible after the focus goes to the editor,
    // where the native selection would be dimmed or gone. Painted through
    // the highlight API rather than by changing the page: wrapping the
    // words in a span would move every offset after them.
    @"::highlight(macdown-picked){"
    @"background-color:color-mix(in srgb, Highlight 55%, transparent)}"
    // The same words when the editor could not find them: still marked, so
    // the reader knows which ones it was, and plainly not the same answer.
    @"::highlight(macdown-lost){"
    @"background-color:color-mix(in srgb, Highlight 15%, transparent);"
    @"text-decoration:underline dotted}"
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
    @"var action='';"
    @"function report(done,focus){"
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
    // Nothing above it says where it came from: the words are still worth
    // reporting, and the editor will look for them in the whole document.
    @"if(!node){"
    @"if(done&&!sel.isCollapsed){keep(sel);"
    @"window.webkit.messageHandlers.macdownSelection.postMessage("
    @"{begin:0,end:-1,cell:-1,offset:-1,text:sel.toString(),"
    @"done:true,focus:!!focus,action:action||''});}"
    @"return;}"
    @"var all=blocks(),i=all.indexOf(node);"
    @"var begin=parseInt(node.getAttribute('data-src'),10);"
    // How much of this block's text comes before the selection. It is what
    // tells the second "test" of a paragraph from the first, and it is
    // measured on the page because only the page knows what it shows.
    @"var offset=-1,r=null;"
    @"try{r=sel.getRangeAt(0);var pre=document.createRange();"
    @"pre.selectNodeContents(node);"
    @"pre.setEnd(r.startContainer,r.startOffset);"
    @"offset=pre.toString().length;}catch(e){offset=-1;}"
    // Where the selection *ends*, which is not always the block it began
    // in: three paragraphs dragged over are three blocks, and a window
    // that stopped at the first would send the search looking for them
    // somewhere else in the document.
    @"var last=begin;"
    @"try{var e=r.endContainer;"
    @"if(e.nodeType===3)e=e.parentElement;"
    @"while(e&&!e.hasAttribute('data-src'))e=e.parentElement;"
    @"if(e)last=parseInt(e.getAttribute('data-src'),10);}catch(x){}"
    @"if(last<begin)last=begin;"
    // The next block that starts somewhere *else*. A list and its first
    // item begin at the same character, and a block that ends where it
    // begins is no window to search in.
    @"var end=-1;"
    @"for(var k=0;k<all.length;k++){"
    @"var s=parseInt(all[k].getAttribute('data-src'),10);"
    @"if(s>last){end=s;break;}}"
    @"if(done&&!sel.isCollapsed)keep(sel);"
    @"window.webkit.messageHandlers.macdownSelection.postMessage("
    @"{begin:begin,end:end,cell:cell,offset:offset,"
    @"text:done?sel.toString():'',done:!!done,focus:!!focus,"
    @"action:action||''});}"
    // A cloned range, because the live one goes with the selection the
    // moment the editor takes the focus.
    @"var picked=null;"
    @"function keep(sel){"
    @"if(typeof CSS==='undefined'||!CSS.highlights)return;"
    @"try{picked=sel.getRangeAt(0).cloneRange();"
    @"CSS.highlights.delete('macdown-lost');"
    @"CSS.highlights.set('macdown-picked',new Highlight(picked));}"
    @"catch(e){}}"
    @"function forget(){"
    @"if(typeof CSS==='undefined'||!CSS.highlights)return;"
    @"CSS.highlights.delete('macdown-picked');"
    @"CSS.highlights.delete('macdown-lost');"
    @"picked=null;}"
    @"window.MacDownForgetPicked=forget;"
    // Said by the editor when it could not find those words in the source.
    @"window.MacDownPickedLost=function(){"
    @"if(typeof CSS==='undefined'||!CSS.highlights||!picked)return;"
    @"CSS.highlights.delete('macdown-picked');"
    @"try{CSS.highlights.set('macdown-lost',new Highlight(picked));}"
    @"catch(e){}};"
    @"var pending=false,quiet=null;"
    // A selection that has stopped changing has been made, however it was
    // made: with the keyboard, or by a drag that ended outside the page
    // where no mouseup of ours ever arrives. The editor follows it, but
    // the focus does not move — somebody holding shift and an arrow key is
    // not finished, and a reader who paused mid-drag is not either.
    @"function settle(){"
    @"clearTimeout(quiet);"
    @"quiet=setTimeout(function(){report(true,false);},400);}"
    // setTimeout rather than requestAnimationFrame: a frame callback only
    // arrives while the page is being drawn, and a preview whose pane is
    // collapsed is not. Measured — headless, nothing ever reported.
    @"document.addEventListener('selectionchange',function(){"
    @"settle();"
    @"if(pending)return;pending=true;"
    @"setTimeout(function(){pending=false;report(false,false);},0);"
    @"});"
    // The end of a gesture made with the mouse, and the one moment the
    // focus follows the selection: reporting it while the pointer is still
    // down would take the focus away from somebody mid-drag.
    @"document.addEventListener('mouseup',function(){"
    @"clearTimeout(quiet);"
    @"setTimeout(function(){report(true,true);},0);"
    @"});"
    // The start of the next gesture is the moment the last one stops being
    // what the reader means.
    @"document.addEventListener('mousedown',forget);"
    // Delete, pressed on a selection made in the preview, means the same
    // thing it means anywhere: take those words out. The page cannot do
    // it, so it says so and the editor does it — with the focus, since
    // what comes next is typing.
    @"document.addEventListener('keydown',function(e){"
    @"if(e.key!=='Backspace'&&e.key!=='Delete')return;"
    @"var sel=document.getSelection();"
    @"if(!sel||sel.isCollapsed)return;"
    @"e.preventDefault();"
    @"clearTimeout(quiet);"
    @"action='delete';report(true,true);action='';"
    @"});"
    @"})();";
}
