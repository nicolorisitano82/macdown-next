//
//  MPDiagramPrompt.m
//  MacDown
//

#import "MPDiagramPrompt.h"


const MPDiagramKind MPDiagramKindsInOrder[9] = {
    MPDiagramKindAutomatic,
    MPDiagramKindFlowchart,
    MPDiagramKindSequence,
    MPDiagramKindState,
    MPDiagramKindClass,
    MPDiagramKindEntity,
    MPDiagramKindGantt,
    MPDiagramKindMindMap,
    MPDiagramKindPie,
};
const NSUInteger MPDiagramKindCount = 9;


NSString *MPDiagramKindTitle(MPDiagramKind kind)
{
    switch (kind)
    {
        case MPDiagramKindAutomatic:
            return NSLocalizedString(@"whatever fits",
                                     @"Diagram kind: let the model choose");
        case MPDiagramKindFlowchart:
            return NSLocalizedString(@"a flowchart", @"Diagram kind");
        case MPDiagramKindSequence:
            return NSLocalizedString(@"a sequence diagram", @"Diagram kind");
        case MPDiagramKindState:
            return NSLocalizedString(@"a state diagram", @"Diagram kind");
        case MPDiagramKindClass:
            return NSLocalizedString(@"a class diagram", @"Diagram kind");
        case MPDiagramKindEntity:
            return NSLocalizedString(@"an entity relationship diagram",
                                     @"Diagram kind");
        case MPDiagramKindGantt:
            return NSLocalizedString(@"a gantt chart", @"Diagram kind");
        case MPDiagramKindMindMap:
            return NSLocalizedString(@"a mind map", @"Diagram kind");
        case MPDiagramKindPie:
            return NSLocalizedString(@"a pie chart", @"Diagram kind");
    }
}


/// What the model is asked for, in Mermaid's own words, so that the first
/// line of the answer is already the first line of the diagram.
static NSString *MPDiagramHeaderForKind(MPDiagramKind kind)
{
    switch (kind)
    {
        case MPDiagramKindAutomatic: return nil;
        case MPDiagramKindFlowchart: return @"flowchart TD";
        case MPDiagramKindSequence:  return @"sequenceDiagram";
        case MPDiagramKindState:     return @"stateDiagram-v2";
        case MPDiagramKindClass:     return @"classDiagram";
        case MPDiagramKindEntity:    return @"erDiagram";
        case MPDiagramKindGantt:     return @"gantt";
        case MPDiagramKindMindMap:   return @"mindmap";
        case MPDiagramKindPie:       return @"pie";
    }
}


/// How a branch is written, per kind. A small model asked for a diagram
/// with a condition in it writes «if», «else» and «endif» *inside the
/// labels* — measured, on a 3B model — which draws a box with the word
/// "endif" in it rather than a branch. So it is told the shape.
///
/// The shapes are shown with letters and dots and no words at all: given an
/// example with English labels in it, the same model copied the labels into
/// its answer. An example is a shape to follow, and a small model reads it
/// as text to reuse.
static NSString *MPDiagramBranchRuleForKind(MPDiagramKind kind)
{
    switch (kind)
    {
        case MPDiagramKindSequence:
            return @"Write a condition as an alt block, in this shape:\n"
                   @"alt …\n  A->>B: …\nelse …\n  A->>C: …\nend\n"
                   @"Never write the words if, else, then or endif inside a "
                   @"message: they are not Mermaid and they draw as text.";
        case MPDiagramKindAutomatic:
        case MPDiagramKindFlowchart:
            return @"Write a condition as a rhombus node with labelled "
                   @"arrows out of it, in this shape:\n"
                   @"C{\"…\"}\nC -->|…| D[\"…\"]\nC -->|…| E[\"…\"]\n"
                   @"Never write the words if, else, then or endif inside a "
                   @"node or an arrow label: they are not Mermaid and they "
                   @"draw as text.";
        case MPDiagramKindState:
            return @"Write a condition as two transitions out of the same "
                   @"state, each with its own label after a colon.";
        default:
            return nil;
    }
}


NSString *MPDiagramInstructionForKind(MPDiagramKind kind)
{
    // In English, like every other instruction to the model, and about the
    // model's job rather than the reader's: what comes after it is the
    // description, in whatever language it was written in.
    NSMutableString *instruction = [NSMutableString stringWithString:
        @"You write Mermaid diagram source. The user describes a process, a "
        @"structure or a sequence of events, in their own language. Answer "
        @"with Mermaid source and nothing else: no explanation, no code "
        @"fence, no backticks, no introduction. Keep every label in the "
        @"language the description is written in, and keep the words the "
        @"user used. Put labels that contain spaces or punctuation in "
        @"double quotes. Do not invent steps that are not described. Put "
        @"every statement on its own line, and never copy the words of an "
        @"example into your answer: an example shows the shape, not the "
        @"words."];

    NSString *header = MPDiagramHeaderForKind(kind);
    if (header)
    {
        [instruction appendFormat:@" The first line of your answer must be "
                                  @"exactly: %@.", header];
    }
    else
    {
        // Left to itself, a small model answers a process that has a
        // condition in it with a sequence diagram, where a condition has no
        // shape. A flow is a flowchart unless the description is about
        // messages between people or systems.
        [instruction appendString:@" Begin with the Mermaid keyword for the "
                                  @"kind of diagram that fits: flowchart TD "
                                  @"for a process, steps or decisions; "
                                  @"sequenceDiagram only when the "
                                  @"description is about messages between "
                                  @"people or systems, in order."];
    }

    NSString *branch = MPDiagramBranchRuleForKind(kind);
    if (branch)
        [instruction appendFormat:@" %@", branch];
    return instruction;
}


/// The words Mermaid starts a diagram with. Those of the version that ships
/// here; one it does not know would draw an error where a diagram was meant.
static NSArray<NSString *> *MPDiagramKeywords(void)
{
    static NSArray<NSString *> *keywords = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keywords = @[@"flowchart", @"graph", @"sequencediagram", @"classdiagram",
                     @"statediagram", @"statediagram-v2", @"erdiagram",
                     @"journey", @"gantt", @"pie", @"quadrantchart",
                     @"requirementdiagram", @"gitgraph", @"mindmap",
                     @"timeline", @"sankey-beta", @"xychart-beta",
                     @"block-beta", @"packet-beta", @"architecture-beta",
                     @"kanban", @"radar-beta", @"c4context", @"zenuml"];
    });
    return keywords;
}


BOOL MPDiagramLineStartsADiagram(NSString *line)
{
    NSString *trimmed = [line stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if (!trimmed.length)
        return NO;

    // The keyword is the first word; what follows it is the direction, the
    // title, or nothing.
    NSString *first = [[trimmed componentsSeparatedByString:@" "]
        firstObject].lowercaseString;
    // "flowchart TD;" and "graph LR:" have both been answered.
    first = [first stringByTrimmingCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@";:,"]];
    return [MPDiagramKeywords() containsObject:first];
}


/// A line that is prose again: the explanation a model adds after the
/// diagram, which has no business in a fenced block.
static BOOL MPDiagramLineIsProse(NSString *line)
{
    NSString *trimmed = [line stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if (!trimmed.length)
        return NO;
    // Indented lines are the body of the diagram, whatever they say.
    if ([line hasPrefix:@" "] || [line hasPrefix:@"\t"])
        return NO;
    // Mermaid's own lines at the left margin: another diagram keyword, a
    // directive, an arrow, a node, a comment, or the end of a block.
    if (MPDiagramLineStartsADiagram(trimmed))
        return NO;
    NSArray<NSString *> *marks = @[@"-->", @"---", @"->>", @"-->>", @"--x",
                                   @"==>", @"-.", @"..>", @"|", @"[", @"{",
                                   @"(", @"%%", @"end", @"subgraph", @"class",
                                   @"style", @"click", @"linkStyle",
                                   @"classDef", @"direction", @"section",
                                   @"title", @"note", @"participant",
                                   @"actor", @"loop", @"alt", @"else",
                                   @"opt", @"par", @"rect", @"activate",
                                   @"deactivate", @"state", @"dateFormat",
                                   @"axisFormat", @"excludes", @":"];
    for (NSString *mark in marks)
    {
        if ([trimmed hasPrefix:mark] || [trimmed containsString:mark])
            return NO;
    }
    // A line of words and nothing else, after a diagram, is a sentence.
    return YES;
}


NSString *MPDiagramCodeFromAnswer(NSString *answer)
{
    if (!answer.length)
        return nil;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [answer enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        [lines addObject:line];
    }];

    NSMutableArray<NSString *> *code = [NSMutableArray array];
    BOOL started = NO;
    BOOL inFence = NO;

    for (NSString *line in lines)
    {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];

        if ([trimmed hasPrefix:@"```"] || [trimmed hasPrefix:@"~~~"])
        {
            // The fence it was told not to write. Its end is the end of the
            // diagram, whatever comes after it.
            if (inFence || started)
                break;
            inFence = YES;
            continue;
        }

        if (!started)
        {
            if (!MPDiagramLineStartsADiagram(trimmed))
                continue;       // «Sure! Here is the diagram:»
            started = YES;
            [code addObject:trimmed];
            continue;
        }

        if (MPDiagramLineIsProse(line))
            break;              // «This diagram shows…»
        [code addObject:line];
    }

    // Blank lines at the end are the model breathing, not the diagram.
    while (code.count && ![[code.lastObject stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]] length])
        [code removeLastObject];

    if (code.count < 2)
        return nil;             // A keyword with nothing under it is not one
    return [code componentsJoinedByString:@"\n"];
}


NSString *MPDiagramWarningForCode(NSString *code)
{
    if (!code.length)
        return nil;

    // The words on their own, not inside another word: "endif" at the end
    // of a label, "if" between spaces. «Verificare» must not match "if".
    static NSRegularExpression *loose = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        loose = [[NSRegularExpression alloc] initWithPattern:
            @"(?:^|[\\s\"\\]\\}\\)|:])(if|else|elif|endif|then|fi)"
            @"(?:$|[\\s\"\\[\\{\\(|:;])"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });

    __block BOOL found = NO;
    [code enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        // Mermaid's own block words are not the trouble: `alt … else … end`
        // in a sequence diagram is exactly what was asked for.
        if ([trimmed hasPrefix:@"alt "] || [trimmed hasPrefix:@"else "]
                || [trimmed isEqualToString:@"else"]
                || [trimmed hasPrefix:@"opt "] || [trimmed hasPrefix:@"loop "]
                || [trimmed hasPrefix:@"par "] || [trimmed isEqualToString:@"end"])
            return;
        if ([loose firstMatchInString:line options:0
                                range:NSMakeRange(0, line.length)])
        {
            found = YES;
            *stop = YES;
        }
    }];

    if (!found)
        return nil;
    return NSLocalizedString(
        @"The model wrote if, else or endif inside the labels: Mermaid draws "
        @"those as words, not as a branch. Ask again, or correct the source "
        @"below.",
        @"Diagram sheet, when the model writes control words into labels");
}


NSString *MPDiagramBlockForCode(NSString *code)
{
    if (!code.length)
        return @"";
    return [NSString stringWithFormat:@"```mermaid\n%@\n```\n", code];
}


NSString *MPDiagramInsertionForCode(NSString *code, NSString *text,
                                    NSRange where)
{
    NSString *block = MPDiagramBlockForCode(code);
    if (!block.length)
        return @"";

    text = text ?: @"";
    if (where.location > text.length)
        where.location = text.length;
    if (NSMaxRange(where) > text.length)
        where.length = text.length - where.location;

    NSMutableString *insertion = [NSMutableString string];
    // A blank line before it, unless there is one already or the block
    // starts the document: a fence that follows a paragraph directly is
    // legal Markdown and looks like a mistake.
    if (where.location > 0)
    {
        unichar before = [text characterAtIndex:where.location - 1];
        if (before != '\n')
            [insertion appendString:@"\n\n"];
        else if (where.location > 1
                 && [text characterAtIndex:where.location - 2] != '\n')
            [insertion appendString:@"\n"];
    }

    [insertion appendString:block];

    if (NSMaxRange(where) < text.length
            && [text characterAtIndex:NSMaxRange(where)] != '\n')
        [insertion appendString:@"\n"];
    return insertion;
}
