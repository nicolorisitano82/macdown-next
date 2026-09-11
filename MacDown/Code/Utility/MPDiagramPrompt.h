//
//  MPDiagramPrompt.h
//  MacDown
//
//  A diagram written from a description, by the model on this Mac.
//
//  The two halves that have nothing to do with windows: what the model is
//  told, and what is made of what it answers. A small model asked for
//  Mermaid answers with Mermaid *and* an explanation, or wraps it in a
//  fence, or starts with «Sure!» — every one of those has been measured —
//  so the answer is never used as it arrives.
//
//  Pure, so that the cleaning can be asked about the ugly answers in a test
//  instead of being discovered in a document.
//

#import <Foundation/Foundation.h>


/// What kind of diagram to ask for. Automatic lets the model choose, which
/// is right when the description already says «flow» or «sequence».
typedef NS_ENUM(NSUInteger, MPDiagramKind) {
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

extern const MPDiagramKind MPDiagramKindsInOrder[9];
extern const NSUInteger MPDiagramKindCount;

/// What the popup says for that kind.
extern NSString *MPDiagramKindTitle(MPDiagramKind kind);


/** What the model is told before it is given the description.
 *
 * Says three things, each of which was needed: answer with Mermaid source
 * and nothing else, keep the words of the description in the language they
 * are written in, and — when a kind is asked for — which kind.
 */
extern NSString *MPDiagramInstructionForKind(MPDiagramKind kind);

/** The Mermaid source inside whatever the model answered, or nil.
 *
 * Takes off a fence, drops anything before the first line that starts a
 * Mermaid diagram, and stops at a line that is plainly prose again. Answers
 * nil when there is no diagram in there at all, which is a thing to tell
 * the reader rather than to paste into their document.
 */
extern NSString *MPDiagramCodeFromAnswer(NSString *answer);

/// Whether a line starts a Mermaid diagram — `flowchart TD`, `sequenceDiagram`.
extern BOOL MPDiagramLineStartsADiagram(NSString *line);

/** What is plainly wrong with what the model wrote, or nil.
 *
 * One thing, checked because it keeps happening: a small model asked for a
 * diagram with a condition in it writes «if», «else» or «endif» inside the
 * labels, which Mermaid draws as words in a box rather than as a branch.
 * The sentence is for the reader, who can then ask again — the source is
 * theirs to correct either way, so nothing is refused over this.
 */
extern NSString *MPDiagramWarningForCode(NSString *code);

/// The fenced block that goes into the document, with its line endings.
extern NSString *MPDiagramBlockForCode(NSString *code);

/** What to put in at `where`, so that the block is a block.
 *
 * A fence has to start its own line and what follows it has to start
 * another: dropped in the middle of a paragraph, the same three backticks
 * are prose. Answers the text to insert, blank lines and all.
 */
extern NSString *MPDiagramInsertionForCode(NSString *code, NSString *text,
                                           NSRange where);
