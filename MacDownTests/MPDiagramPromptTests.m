//
//  MPDiagramPromptTests.m
//  MacDownTests
//
//  A diagram described in words: what the model is told, and what is made
//  of what it answers — including the answers a small model actually gives,
//  which are rarely the one that was asked for.
//

#import <XCTest/XCTest.h>

#import "MPDiagramPrompt.h"


@interface MPDiagramPromptTests : XCTestCase
@end


@implementation MPDiagramPromptTests

#pragma mark - What the model is told

- (void)testTheInstructionAsksForSourceAndNothingElse
{
    NSString *instruction = MPDiagramInstructionForKind(MPDiagramKindAutomatic);
    XCTAssertTrue([instruction containsString:@"Mermaid"]);
    XCTAssertTrue([instruction containsString:@"no explanation"]);
    // The labels have to come back in the language the description is in:
    // measured on a 3B model, without that sentence an Italian description
    // comes back with English boxes.
    XCTAssertTrue([instruction containsString:@"language the description"]);
}

- (void)testAskingForAKindSaysTheFirstLine
{
    NSString *sequence = MPDiagramInstructionForKind(MPDiagramKindSequence);
    XCTAssertTrue([sequence containsString:@"sequenceDiagram"]);
    NSString *gantt = MPDiagramInstructionForKind(MPDiagramKindGantt);
    XCTAssertTrue([gantt containsString:@"gantt"]);
    // Automatic names no first line, or it would not be automatic.
    NSString *automatic = MPDiagramInstructionForKind(MPDiagramKindAutomatic);
    XCTAssertFalse([automatic containsString:@"must be exactly"]);
}

- (void)testEveryKindHasATitleAndAnInstruction
{
    for (NSUInteger i = 0; i < MPDiagramKindCount; i++)
    {
        MPDiagramKind kind = MPDiagramKindsInOrder[i];
        XCTAssertTrue(MPDiagramKindTitle(kind).length > 0);
        XCTAssertTrue(MPDiagramInstructionForKind(kind).length > 0);
    }
}


#pragma mark - What is made of the answer

- (void)testAnAnswerThatIsAlreadyTheDiagram
{
    NSString *code = MPDiagramCodeFromAnswer(
        @"flowchart TD\n  A[Inizio] --> B[Fine]");
    XCTAssertEqualObjects(code, @"flowchart TD\n  A[Inizio] --> B[Fine]");
}

- (void)testTheFenceItWasToldNotToWrite
{
    NSString *code = MPDiagramCodeFromAnswer(
        @"```mermaid\nflowchart TD\n  A --> B\n```");
    XCTAssertEqualObjects(code, @"flowchart TD\n  A --> B");
}

- (void)testThePolitenessBeforeAndTheExplanationAfter
{
    NSString *answer = @"Certo! Ecco il diagramma:\n\n"
                       @"```mermaid\nsequenceDiagram\n  Anna->>Bruno: ciao\n```\n\n"
                       @"Questo diagramma mostra il saluto.";
    NSString *code = MPDiagramCodeFromAnswer(answer);
    XCTAssertEqualObjects(code, @"sequenceDiagram\n  Anna->>Bruno: ciao");
}

- (void)testAnExplanationWithNoFenceAroundTheDiagram
{
    NSString *code = MPDiagramCodeFromAnswer(
        @"flowchart LR\n  A --> B\n\nSpero sia utile.");
    XCTAssertEqualObjects(code, @"flowchart LR\n  A --> B");
}

- (void)testAnAnswerWithNoDiagramInIt
{
    XCTAssertNil(MPDiagramCodeFromAnswer(
        @"Mi dispiace, non posso aiutarti con questo."));
    XCTAssertNil(MPDiagramCodeFromAnswer(@""));
    XCTAssertNil(MPDiagramCodeFromAnswer(nil));
    // A keyword with nothing under it draws nothing: it is not a diagram,
    // and it would go into the document as an error where a picture was
    // meant.
    XCTAssertNil(MPDiagramCodeFromAnswer(@"flowchart TD"));
}

- (void)testTheKeywordsMermaidKnows
{
    XCTAssertTrue(MPDiagramLineStartsADiagram(@"flowchart TD"));
    XCTAssertTrue(MPDiagramLineStartsADiagram(@"  graph LR;"));
    XCTAssertTrue(MPDiagramLineStartsADiagram(@"sequenceDiagram"));
    XCTAssertTrue(MPDiagramLineStartsADiagram(@"mindmap"));
    XCTAssertFalse(MPDiagramLineStartsADiagram(@"Ecco il diagramma:"));
    XCTAssertFalse(MPDiagramLineStartsADiagram(@""));
}


#pragma mark - What is plainly wrong with it

- (void)testTheControlWordsASmallModelWritesIntoLabels
{
    // Measured, from the 3B model on this machine, before the instruction
    // was given the shape of a branch to follow.
    NSString *wrong = @"sequenceDiagram\n"
        @"Il cliente ->> Il magazzino: invia un ordine\n"
        @"Il magazzino --> Il corriere: consegna spedizione if disponibilità\n"
        @"Il magazzino --> Ufficio acquisti: ordina al fornitore else\n"
        @"Il magazzino --> Il magazzino: ricomincia controllo endif";
    XCTAssertNotNil(MPDiagramWarningForCode(wrong));
}

- (void)testMermaidsOwnBlockWordsAreNotTheTrouble
{
    NSString *right = @"sequenceDiagram\n"
        @"alt disponibile\n  M->>C: spedisce\n"
        @"else non disponibile\n  M->>A: ordina\nend";
    XCTAssertNil(MPDiagramWarningForCode(right));

    NSString *flow = @"flowchart TD\n  A[\"Ordine\"] --> C{\"C'è?\"}\n"
        @"  C -->|sì| D[\"Spedisce\"]\n  C -->|no| E[\"Ordina\"]";
    XCTAssertNil(MPDiagramWarningForCode(flow));
}

- (void)testAWordThatMerelyContainsIfIsNotAControlWord
{
    NSString *innocent = @"flowchart TD\n"
        @"  A[\"Verificare il magazzino\"] --> B[\"Notifica al cliente\"]";
    XCTAssertNil(MPDiagramWarningForCode(innocent));
    XCTAssertNil(MPDiagramWarningForCode(nil));
}


#pragma mark - What goes into the document

- (void)testTheBlockIsAFencedMermaidBlock
{
    NSString *block = MPDiagramBlockForCode(@"flowchart TD\n  A --> B");
    XCTAssertEqualObjects(block, @"```mermaid\nflowchart TD\n  A --> B\n```\n");
    XCTAssertEqualObjects(MPDiagramBlockForCode(@""), @"");
}

- (void)testAFenceGetsTheBlankLinesThatMakeItABlock
{
    NSString *code = @"flowchart TD\n  A --> B";

    // In the middle of a paragraph: onto its own line, with a blank line
    // before it, or the three backticks are prose.
    NSString *inside = MPDiagramInsertionForCode(code, @"Una riga qui.",
                                                 NSMakeRange(13, 0));
    XCTAssertTrue([inside hasPrefix:@"\n\n```mermaid"]);

    // Already on an empty line after a blank one: nothing is added.
    NSString *after = MPDiagramInsertionForCode(code, @"Testo.\n\n",
                                                NSMakeRange(8, 0));
    XCTAssertTrue([after hasPrefix:@"```mermaid"]);

    // At the very beginning of an empty document: no blank line before it.
    NSString *start = MPDiagramInsertionForCode(code, @"", NSMakeRange(0, 0));
    XCTAssertTrue([start hasPrefix:@"```mermaid"]);

    // With text following, the block ends with a line ending of its own.
    NSString *before = MPDiagramInsertionForCode(code, @"\n\nAltro testo.",
                                                 NSMakeRange(2, 0));
    XCTAssertTrue([before hasSuffix:@"```\n\n"]);
}

- (void)testARangeOutsideTheTextDoesNotCrash
{
    NSString *insertion = MPDiagramInsertionForCode(@"flowchart TD\n A-->B",
                                                    @"breve",
                                                    NSMakeRange(400, 12));
    XCTAssertTrue([insertion containsString:@"```mermaid"]);
}

@end
