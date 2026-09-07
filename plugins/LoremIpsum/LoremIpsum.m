//
//  LoremIpsum.m
//  A demonstration MacDown plug-in.
//
//  Inserts placeholder text at the insertion point, in a chosen flavour and
//  length. It exists as much to show what a plug-in can do as to be useful:
//  everything a plug-in needs is here, and it is one file.
//
//  A plug-in is a bundle whose principal class answers three optional
//  messages. MacDown calls -name to label the menu item, -plugInDidInitialize
//  once at launch, and -run: when the item is chosen.
//
//  Nothing links against MacDown. The text goes in through the responder
//  chain, which is both the least invasive way and the one that behaves
//  correctly: the editor is the first responder while you are typing, and
//  -insertText:replacementRange: respects the selection and registers an
//  undo, so ⌘Z takes the paragraphs back out in one go.
//

#import <Cocoa/Cocoa.h>


#pragma mark - The text

typedef NS_ENUM(NSInteger, LIFlavour) {
    LIFlavourLatin = 0,
    LIFlavourItalian,
    LIFlavourMarkdown,
};

static NSArray<NSString *> *LILatinSentences(void)
{
    return @[
        @"Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        @"Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        @"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.",
        @"Duis aute irure dolor in reprehenderit in voluptate velit esse.",
        @"Excepteur sint occaecat cupidatat non proident, sunt in culpa.",
        @"Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit.",
        @"Neque porro quisquam est qui dolorem ipsum quia dolor sit amet.",
        @"At vero eos et accusamus et iusto odio dignissimos ducimus.",
    ];
}

/// Italian filler that reads like prose rather than like Latin, which is
/// what you want when you are checking line breaks and hyphenation.
///
/// translation-check: content — sample text stays in the language it shows
/// off, so these sentences are not interface strings and are not localized.
static NSArray<NSString *> *LIItalianSentences(void)
{
    return @[
        @"Il testo di prova serve a vedere come si comporta la pagina.",
        @"Le righe si spezzano dove capita, e va bene così.",
        (@"Una frase più lunga aiuta a capire come cade la giustificazione "
         @"quando il paragrafo si allarga oltre la misura comoda."),
        (@"Le parole accentate — perché, città, così — mettono alla prova "
         @"il carattere."),
        @"Un inciso, messo lì per rompere il ritmo, cambia la lettura.",
        @"Qui invece la frase è corta.",
        (@"Numeri come 1.234,56 e date come 28 agosto 2026 occupano spazio "
         @"in modo diverso dalle lettere."),
        @"Alla fine quello che conta è che il blocco sembri un testo vero.",
    ];
}

static NSString *LIParagraph(NSArray<NSString *> *pool, NSUInteger sentences)
{
    NSMutableArray *picked = [NSMutableArray arrayWithCapacity:sentences];
    for (NSUInteger i = 0; i < sentences; i++)
    {
        uint32_t index = arc4random_uniform((uint32_t)pool.count);
        [picked addObject:pool[index]];
    }
    return [picked componentsJoinedByString:@" "];
}

/// A sampler of Markdown rather than flat prose: headings, a list, a quote,
/// a table, code. Useful for trying a stylesheet or an export without
/// writing a document first.
///
/// translation-check: content — the sample is the thing being inserted, not
/// something the interface says.
static NSString *LIMarkdownBlock(NSUInteger index)
{
    NSArray<NSString *> *blocks = @[
        (@"## Un titolo di secondo livello\n\nUn paragrafo con del "
         @"**grassetto**, del *corsivo* e un po' di `codice in linea`."),

        @"- Primo punto\n- Secondo punto\n  - Annidato\n- Terzo punto",

        (@"> Una citazione, per vedere come viene resa dal foglio di stile.\n"
         @">\n> Anche su due capoversi."),

        (@"| Colonna | Valore |\n|:--------|-------:|\n"
         @"| Uno     |    120 |\n| Due     |    340 |"),

        @"```python\ndef saluta(nome):\n    return f\"Ciao, {nome}\"\n```",

        @"1. Primo\n2. Secondo\n3. Terzo",
    ];
    return blocks[index % blocks.count];
}

static NSString *LITextWithFlavour(LIFlavour flavour, NSUInteger paragraphs)
{
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:paragraphs];
    for (NSUInteger i = 0; i < paragraphs; i++)
    {
        switch (flavour)
        {
            case LIFlavourLatin:
                [parts addObject:LIParagraph(LILatinSentences(), 4)];
                break;
            case LIFlavourItalian:
                [parts addObject:LIParagraph(LIItalianSentences(), 4)];
                break;
            case LIFlavourMarkdown:
                [parts addObject:LIMarkdownBlock(i)];
                break;
        }
    }
    // A blank line between paragraphs, and one after, so what follows in the
    // document does not end up glued to the last paragraph.
    return [[parts componentsJoinedByString:@"\n\n"]
        stringByAppendingString:@"\n\n"];
}


#pragma mark - The plug-in

@interface LoremIpsum : NSObject
@property (nonatomic) NSPopUpButton *flavourPopUp;
@property (nonatomic) NSTextField *countField;
@property (nonatomic) NSStepper *countStepper;
@end


// NSLocalizedString asks the *main* bundle, which is MacDown Next: a plug-in
// that used it would need the application to carry the plug-in's languages.
// A plug-in carries its own — Localization/it-IT.lproj is copied into the
// bundle by build.sh — so ask the bundle this class was loaded from.
#define LILocalizedString(key, comment) \
    [[NSBundle bundleForClass:[LoremIpsum class]] \
        localizedStringForKey:(key) value:@"" table:nil]


@implementation LoremIpsum

- (NSString *)name
{
    return LILocalizedString(@"Lorem Ipsum…",
                             @"Plug-in menu item; the ellipsis promises a "
                             @"dialogue rather than an immediate insertion");
}

/// Where the text has to go. The editor is the first responder while you are
/// typing, so the responder chain finds it without this plug-in knowing
/// anything about MacDown's classes.
- (NSTextView *)targetTextView
{
    NSResponder *responder = [NSApp keyWindow].firstResponder;
    if ([responder isKindOfClass:[NSTextView class]])
        return (NSTextView *)responder;
    return nil;
}

- (NSView *)optionsView
{
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 62)];

    NSTextField *flavourLabel = [NSTextField labelWithString:
        LILocalizedString(@"Kind:", @"Which kind of filler text")];
    flavourLabel.alignment = NSTextAlignmentRight;
    flavourLabel.frame = NSMakeRect(0, 36, 80, 18);
    [box addSubview:flavourLabel];

    NSPopUpButton *popUp =
        [[NSPopUpButton alloc] initWithFrame:NSMakeRect(88, 32, 200, 26)];
    [popUp addItemsWithTitles:@[
        LILocalizedString(@"Lorem ipsum", @"Classic Latin filler"),
        LILocalizedString(@"Italian", @"Italian filler prose"),
        LILocalizedString(@"Sample Markdown", @"A sampler of Markdown"),
    ]];
    [box addSubview:popUp];
    self.flavourPopUp = popUp;

    NSTextField *countLabel = [NSTextField labelWithString:
        LILocalizedString(@"Paragraphs:", @"How many paragraphs to insert")];
    countLabel.alignment = NSTextAlignmentRight;
    countLabel.frame = NSMakeRect(0, 6, 80, 18);
    [box addSubview:countLabel];

    NSTextField *field =
        [[NSTextField alloc] initWithFrame:NSMakeRect(88, 2, 60, 22)];
    field.alignment = NSTextAlignmentRight;
    field.stringValue = @"3";
    [box addSubview:field];
    self.countField = field;

    NSStepper *stepper =
        [[NSStepper alloc] initWithFrame:NSMakeRect(152, 0, 19, 27)];
    stepper.minValue = 1;
    stepper.maxValue = 50;
    stepper.increment = 1;
    stepper.integerValue = 3;
    stepper.target = self;
    stepper.action = @selector(stepperChanged:);
    [box addSubview:stepper];
    self.countStepper = stepper;

    return box;
}

- (void)stepperChanged:(NSStepper *)sender
{
    self.countField.integerValue = sender.integerValue;
}

- (BOOL)run:(id)sender
{
    NSTextView *editor = [self targetTextView];
    if (!editor)
    {
        // Nothing is focused: say so rather than failing silently, since
        // MacDown only logs a failed run.
        NSAlert *problem = [[NSAlert alloc] init];
        problem.messageText = LILocalizedString(
            @"There is no insertion point",
            @"Shown when no editor has focus");
        problem.informativeText = LILocalizedString(
            @"Click in the editor where you want the text, and try again.",
            @"How to recover from having no focus");
        [problem runModal];
        return NO;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = LILocalizedString(@"Insert Sample Text",
                                          @"Dialogue title");
    alert.informativeText = LILocalizedString(
        @"The text is inserted where the cursor is.",
        @"Explains where the text lands");
    [alert addButtonWithTitle:LILocalizedString(@"Insert", @"Confirm")];
    [alert addButtonWithTitle:LILocalizedString(@"Cancel", @"Cancel")];
    alert.accessoryView = [self optionsView];

    // So the number can be typed as well as stepped.
    [alert.window setInitialFirstResponder:self.countField];

    if ([alert runModal] != NSAlertFirstButtonReturn)
        return YES;     // Cancelled on purpose; not a failure.

    NSInteger count = self.countField.integerValue;
    if (count < 1)
        count = 1;
    else if (count > 50)
        count = 50;

    NSString *text = LITextWithFlavour(
        (LIFlavour)self.flavourPopUp.indexOfSelectedItem, (NSUInteger)count);

    // Through the text view rather than by editing its string directly, so
    // the insertion is undoable and lands on the selection.
    if (![editor shouldChangeTextInRange:editor.selectedRange
                       replacementString:text])
        return NO;
    [editor insertText:text replacementRange:editor.selectedRange];
    [editor didChangeText];

    return YES;
}

@end
