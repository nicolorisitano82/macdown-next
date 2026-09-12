//
//  MDOfficeImport.m
//  DocumentImport — a MacDown Next plug-in
//

#import "MDOfficeImport.h"


@interface MDImportPicture ()
@property (copy, nonatomic) NSString *entry;
@property (copy, nonatomic) NSString *name;
@end

@implementation MDImportPicture

- (instancetype)initWithEntry:(NSString *)entry name:(NSString *)name
{
    self = [super init];
    if (self)
    {
        _entry = [entry copy];
        _name = [name copy];
    }
    return self;
}

@end


@interface MDImportResult ()
@property (copy, nonatomic) NSString *markdown;
@property (copy, nonatomic) NSArray<MDImportPicture *> *pictures;
@property (copy, nonatomic) NSArray<NSString *> *lost;
@end

@implementation MDImportResult
@end


#pragma mark - The plain text underneath

NSString *MDImportEscaped(NSString *text)
{
    if (!text.length)
        return @"";

    // Only what would be read as markup when the document is opened again.
    // Escaping everything that *could* be special turns ordinary prose into
    // a hedge of backslashes.
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    NSCharacterSet *dangerous =
        [NSCharacterSet characterSetWithCharactersInString:@"\\`*_[]<>|"];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *piece, NSRange r, NSRange e,
                                       BOOL *stop) {
        if (piece.length == 1
                && [dangerous characterIsMember:[piece characterAtIndex:0]])
            [out appendString:@"\\"];
        [out appendString:piece];
    }];
    return out;
}


/// The text of a run, with its emphasis around it. Empty runs and runs of
/// only spaces keep their spaces but lose the markers: `** **` is not bold,
/// it is two asterisks and a space.
static NSString *MDImportRun(NSString *text, BOOL bold, BOOL italic,
                             BOOL strike, BOOL code)
{
    if (!text.length)
        return @"";

    NSString *trimmed = [text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if (!trimmed.length)
        return text;                        // spaces between two runs

    // The spaces at the ends stay outside the markers, or the emphasis does
    // not take: `** bold **` is literal asterisks in every reader.
    NSRange first = [text rangeOfString:trimmed];
    NSString *before = [text substringToIndex:first.location];
    NSString *after = [text substringFromIndex:NSMaxRange(first)];

    NSString *middle = code ? [NSString stringWithFormat:@"`%@`", trimmed]
                            : MDImportEscaped(trimmed);
    if (strike)
        middle = [NSString stringWithFormat:@"~~%@~~", middle];
    if (bold && italic)
        middle = [NSString stringWithFormat:@"***%@***", middle];
    else if (bold)
        middle = [NSString stringWithFormat:@"**%@**", middle];
    else if (italic)
        middle = [NSString stringWithFormat:@"*%@*", middle];

    return [NSString stringWithFormat:@"%@%@%@", before, middle, after];
}


/// Blank lines between blocks, without piling them up.
static void MDImportAppendBlock(NSMutableString *out, NSString *block)
{
    NSString *trimmed = [block stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length)
        return;
    if (out.length)
        [out appendString:@"\n"];
    [out appendString:trimmed];
    [out appendString:@"\n"];
}


#pragma mark - Word

/// The children of `element` with that qualified name, in order.
static NSArray<NSXMLElement *> *MDChildren(NSXMLElement *element,
                                           NSString *name)
{
    NSMutableArray<NSXMLElement *> *found = [NSMutableArray array];
    for (NSXMLNode *node in element.children)
    {
        if (node.kind == NSXMLElementKind
                && [node.name isEqualToString:name])
            [found addObject:(NSXMLElement *)node];
    }
    return found;
}

static NSXMLElement *MDChild(NSXMLElement *element, NSString *name)
{
    return MDChildren(element, name).firstObject;
}

/// Every descendant with that name, however deep — for the parts of these
/// formats that nest without a rule (a picture inside a run inside a
/// paragraph inside a cell).
static NSArray<NSXMLElement *> *MDDescendants(NSXMLElement *element,
                                              NSString *name)
{
    NSMutableArray<NSXMLElement *> *found = [NSMutableArray array];
    for (NSXMLNode *node in element.children)
    {
        if (node.kind != NSXMLElementKind)
            continue;
        NSXMLElement *child = (NSXMLElement *)node;
        if ([child.name isEqualToString:name])
            [found addObject:child];
        [found addObjectsFromArray:MDDescendants(child, name)];
    }
    return found;
}

static NSString *MDAttribute(NSXMLElement *element, NSString *name)
{
    return [element attributeForName:name].stringValue;
}


/// numId → whether that list is numbered, from word/numbering.xml.
static NSDictionary<NSString *, NSNumber *> *MDWordNumbering(NSString *xml)
{
    NSMutableDictionary *numbered = [NSMutableDictionary dictionary];
    if (!xml.length)
        return numbered;

    NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml
        options:NSXMLNodeOptionsNone error:NULL];
    if (!document)
        return numbered;

    // abstractNumId → format, then num → abstractNumId. Only the first
    // level is read: a numbered list whose third level is bulleted is a
    // thing Word can make and nobody does.
    NSMutableDictionary<NSString *, NSNumber *> *abstract =
        [NSMutableDictionary dictionary];
    for (NSXMLElement *element in MDDescendants(document.rootElement,
                                                @"w:abstractNum"))
    {
        NSString *identifier = MDAttribute(element, @"w:abstractNumId");
        NSXMLElement *level = MDDescendants(element, @"w:lvl").firstObject;
        NSXMLElement *format = level ? MDChild(level, @"w:numFmt") : nil;
        NSString *kind = format ? MDAttribute(format, @"w:val") : nil;
        if (identifier)
            abstract[identifier] = @(kind && ![kind isEqualToString:@"bullet"]);
    }
    for (NSXMLElement *element in MDDescendants(document.rootElement, @"w:num"))
    {
        NSString *identifier = MDAttribute(element, @"w:numId");
        NSXMLElement *points = MDChild(element, @"w:abstractNumId");
        NSString *to = points ? MDAttribute(points, @"w:val") : nil;
        if (identifier && to && abstract[to])
            numbered[identifier] = abstract[to];
    }
    return numbered;
}


/// r:id → target, from word/_rels/document.xml.rels.
static NSDictionary<NSString *, NSString *> *MDWordRelationships(NSString *xml)
{
    NSMutableDictionary *targets = [NSMutableDictionary dictionary];
    if (!xml.length)
        return targets;

    NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:xml
        options:NSXMLNodeOptionsNone error:NULL];
    for (NSXMLElement *element in MDDescendants(document.rootElement,
                                                @"Relationship"))
    {
        NSString *identifier = MDAttribute(element, @"Id");
        NSString *target = MDAttribute(element, @"Target");
        if (identifier && target)
            targets[identifier] = target;
    }
    return targets;
}


/** A line with the emphasis that wraps the whole of it taken off.
 *
 * `**Titolo**` on its own is what Word gives for a heading whose runs say
 * bold as well as the style. Inside a heading that emphasis says nothing —
 * everything in there is already a heading — and `# **Titolo**` is the
 * same thing written twice. Emphasis that covers only part of the line is
 * left alone: there it means something.
 */
static NSString *MDImportWithoutWholeEmphasis(NSString *line)
{
    NSString *text = line;
    for (NSString *marker in @[@"**", @"*", @"__", @"_"])
    {
        while (text.length > marker.length * 2
               && [text hasPrefix:marker] && [text hasSuffix:marker])
        {
            NSString *inside = [text substringWithRange:NSMakeRange(
                marker.length, text.length - marker.length * 2)];
            // Only when the marker is the one pair that wraps everything:
            // `**a** e **b**` is two of them, and taking the ends off
            // would leave `a** e **b`.
            if ([inside rangeOfString:marker].location != NSNotFound)
                break;
            text = inside;
        }
    }
    return text;
}


/// How deep a heading is, from a style's *name* — «heading 1», «Title» —
/// or from an identifier that spells the same thing, «Heading1».
static NSUInteger MDWordHeadingLevel(NSString *style)
{
    if (!style.length)
        return 0;
    NSString *lower = style.lowercaseString;
    if ([lower isEqualToString:@"title"])
        return 1;
    if ([lower isEqualToString:@"subtitle"])
        return 2;
    if (![lower hasPrefix:@"heading"])
        return 0;
    NSString *rest = [lower substringFromIndex:@"heading".length];
    NSInteger level = rest.integerValue;
    return (level >= 1 && level <= 6) ? (NSUInteger)level : 0;
}


/** Which styles are headings, and how deep, read from `word/styles.xml`.
 *
 * A paragraph names its style by an identifier, and that identifier is in
 * the language Word happened to be in: `Titolo1` in Italian, `berschrift1`
 * in German. The definition of the style, though, carries two things that
 * are not translated — the built-in name (`heading 1`) and the outline
 * level — and either of them settles the question.
 *
 * `w:basedOn` is followed for a style that says neither: somebody's
 * «Titolo capitolo» based on `Titolo1` is a heading, and Word writes plenty
 * of those.
 */
static NSDictionary<NSString *, NSNumber *> *MDWordHeadingStyles(NSString *xml)
{
    NSMutableDictionary<NSString *, NSNumber *> *levels =
        [NSMutableDictionary dictionary];
    if (!xml.length)
        return levels;

    NSXMLDocument *document = [[NSXMLDocument alloc]
        initWithXMLString:xml options:NSXMLNodeOptionsNone error:NULL];
    if (!document)
        return levels;

    // First pass: what each style says about itself, and what it is based on.
    NSMutableDictionary<NSString *, NSString *> *basedOn =
        [NSMutableDictionary dictionary];
    for (NSXMLElement *style in MDDescendants(document.rootElement, @"w:style"))
    {
        NSString *identifier = MDAttribute(style, @"w:styleId");
        if (!identifier.length)
            continue;
        NSString *kind = MDAttribute(style, @"w:type");
        if (kind.length && ![kind isEqualToString:@"paragraph"])
            continue;

        NSUInteger level = 0;
        NSXMLElement *name = MDChild(style, @"w:name");
        if (name)
            level = MDWordHeadingLevel(MDAttribute(name, @"w:val"));
        if (!level)
        {
            // An outline level is 0 for the first heading, and a paragraph
            // that is not a heading at all uses 9.
            NSXMLElement *properties = MDChild(style, @"w:pPr");
            NSXMLElement *outline = properties
                ? MDChild(properties, @"w:outlineLvl") : nil;
            NSInteger written = outline
                ? [MDAttribute(outline, @"w:val") integerValue] : -1;
            if (written >= 0 && written <= 5)
                level = (NSUInteger)(written + 1);
        }
        if (!level)
            level = MDWordHeadingLevel(identifier);

        if (level)
            levels[identifier] = @(level);
        else
        {
            NSXMLElement *parent = MDChild(style, @"w:basedOn");
            NSString *from = parent ? MDAttribute(parent, @"w:val") : nil;
            if (from.length)
                basedOn[identifier] = from;
        }
    }

    // Second pass: a style that says nothing inherits from the one it is
    // based on. Ten steps is a chain nobody writes; it is there so that a
    // style based on itself cannot spin.
    for (NSString *identifier in basedOn)
    {
        NSString *walk = basedOn[identifier];
        for (NSUInteger step = 0; step < 10 && walk.length; step++)
        {
            NSNumber *level = levels[walk];
            if (level)
            {
                levels[identifier] = level;
                break;
            }
            walk = basedOn[walk];
        }
    }
    return levels;
}


@interface MDWordReader : NSObject
@property (nonatomic) NSDictionary<NSString *, NSString *> *targets;
/// style identifier → heading level, from styles.xml.
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *headings;
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *numbered;
@property (nonatomic) NSString *pictureFolder;
@property (nonatomic) NSMutableArray<MDImportPicture *> *pictures;
@property (nonatomic) NSMutableOrderedSet<NSString *> *lost;
@end


@implementation MDWordReader

/** How deep this paragraph's heading is, or zero.
 *
 * Three answers, in the order they can be trusted: what styles.xml says
 * about the style the paragraph names; the outline level the paragraph
 * carries itself, which is how a heading made by hand says so; and the
 * identifier read as if it were a name, which is all there is when the
 * document arrives without its styles.
 */
- (NSUInteger)headingLevelOf:(NSString *)styleName
                  properties:(NSXMLElement *)properties
{
    NSNumber *known = styleName.length ? self.headings[styleName] : nil;
    if (known)
        return known.unsignedIntegerValue;

    NSXMLElement *outline = properties ? MDChild(properties, @"w:outlineLvl")
                                       : nil;
    if (outline)
    {
        NSInteger written = [MDAttribute(outline, @"w:val") integerValue];
        if (written >= 0 && written <= 5)
            return (NSUInteger)(written + 1);
    }
    return MDWordHeadingLevel(styleName);
}


/// One paragraph's runs, as Markdown, with the links and pictures in place.
- (NSString *)inlineOf:(NSXMLElement *)paragraph
{
    NSMutableString *line = [NSMutableString string];
    for (NSXMLNode *node in paragraph.children)
    {
        if (node.kind != NSXMLElementKind)
            continue;
        NSXMLElement *child = (NSXMLElement *)node;

        if ([child.name isEqualToString:@"w:hyperlink"])
        {
            NSString *inside = [self inlineOf:child];
            NSString *target = self.targets[MDAttribute(child, @"r:id")];
            NSString *anchor = MDAttribute(child, @"w:anchor");
            if (target.length)
                [line appendFormat:@"[%@](%@)", inside, target];
            else if (anchor.length)
                [line appendFormat:@"[%@](#%@)", inside, anchor];
            else
                [line appendString:inside];
            continue;
        }
        if (![child.name isEqualToString:@"w:r"])
            continue;

        NSXMLElement *properties = MDChild(child, @"w:rPr");
        BOOL bold = properties && MDChild(properties, @"w:b") != nil;
        BOOL italic = properties && MDChild(properties, @"w:i") != nil;
        BOOL strike = properties && MDChild(properties, @"w:strike") != nil;
        NSXMLElement *style = properties ? MDChild(properties, @"w:rStyle") : nil;
        NSString *styleName = style ? MDAttribute(style, @"w:val") : nil;
        BOOL code = [styleName.lowercaseString containsString:@"code"]
            || [styleName.lowercaseString containsString:@"verbatim"];

        for (NSXMLNode *inside in child.children)
        {
            if (inside.kind != NSXMLElementKind)
                continue;
            NSXMLElement *piece = (NSXMLElement *)inside;

            if ([piece.name isEqualToString:@"w:t"])
            {
                [line appendString:MDImportRun(piece.stringValue ?: @"",
                                               bold, italic, strike, code)];
            }
            else if ([piece.name isEqualToString:@"w:tab"])
            {
                [line appendString:@" "];
            }
            else if ([piece.name isEqualToString:@"w:br"])
            {
                [line appendString:@"  \n"];    // a line break, kept
            }
            else if ([piece.name isEqualToString:@"w:drawing"]
                     || [piece.name isEqualToString:@"w:pict"])
            {
                [line appendString:[self pictureIn:piece]];
            }
        }
    }
    return line;
}


/// The link to a picture, and the picture put on the list to be written.
- (NSString *)pictureIn:(NSXMLElement *)drawing
{
    NSXMLElement *blip = MDDescendants(drawing, @"a:blip").firstObject;
    NSString *identifier = blip ? MDAttribute(blip, @"r:embed") : nil;
    NSString *target = identifier ? self.targets[identifier] : nil;
    if (!target.length)
    {
        [self.lost addObject:@"a picture whose file could not be found"];
        return @"";
    }

    NSString *entry = [target hasPrefix:@"/"] ? [target substringFromIndex:1]
        : [@"word/" stringByAppendingString:target];
    NSString *name = entry.lastPathComponent;
    for (MDImportPicture *already in self.pictures)
    {
        if ([already.entry isEqualToString:entry])
            name = already.name;
    }
    [self.pictures addObject:[[MDImportPicture alloc] initWithEntry:entry
                                                              name:name]];

    // The description Word keeps for a screen reader becomes the alt text,
    // which is the same job in another format.
    NSXMLElement *properties =
        MDDescendants(drawing, @"wp:docPr").firstObject;
    NSString *described = properties ? MDAttribute(properties, @"descr") : nil;
    if (!described.length && properties)
        described = MDAttribute(properties, @"name");

    return [NSString stringWithFormat:@"![%@](%@/%@)",
            MDImportEscaped(described ?: @""), self.pictureFolder, name];
}


- (NSString *)tableOf:(NSXMLElement *)table
{
    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
    for (NSXMLElement *row in MDChildren(table, @"w:tr"))
    {
        NSMutableArray<NSString *> *cells = [NSMutableArray array];
        for (NSXMLElement *cell in MDChildren(row, @"w:tc"))
        {
            NSMutableArray<NSString *> *pieces = [NSMutableArray array];
            for (NSXMLElement *paragraph in MDChildren(cell, @"w:p"))
            {
                NSString *text = [self inlineOf:paragraph];
                if (text.length)
                    [pieces addObject:text];
            }
            // A cell with two paragraphs becomes one cell: a table row is
            // one line, and a line ending inside it would end the table.
            NSString *joined = [[pieces componentsJoinedByString:@" "]
                stringByReplacingOccurrencesOfString:@"  \n" withString:@" "];
            [cells addObject:[joined stringByReplacingOccurrencesOfString:@"|"
                                                               withString:@"\\|"]];
        }
        if (cells.count)
            [rows addObject:cells];
    }
    if (!rows.count)
        return @"";

    NSUInteger columns = 0;
    for (NSArray *row in rows)
        columns = MAX(columns, row.count);

    NSMutableString *out = [NSMutableString string];
    [rows enumerateObjectsUsingBlock:^(NSArray<NSString *> *row, NSUInteger i,
                                       BOOL *stop) {
        NSMutableArray<NSString *> *cells = [row mutableCopy];
        while (cells.count < columns)
            [cells addObject:@""];
        [out appendFormat:@"| %@ |\n", [cells componentsJoinedByString:@" | "]];

        if (i == 0)
        {
            NSMutableArray<NSString *> *rule = [NSMutableArray array];
            for (NSUInteger c = 0; c < columns; c++)
                [rule addObject:@"---"];
            [out appendFormat:@"| %@ |\n", [rule componentsJoinedByString:@" | "]];
        }
    }];
    return out;
}


- (NSString *)markdownOfBody:(NSXMLElement *)body
{
    NSMutableString *out = [NSMutableString string];
    NSMutableArray<NSString *> *list = [NSMutableArray array];
    __block NSString *listId = nil;

    void (^flushList)(void) = ^{
        if (!list.count)
            return;
        MDImportAppendBlock(out, [list componentsJoinedByString:@"\n"]);
        [list removeAllObjects];
        listId = nil;
    };

    for (NSXMLNode *node in body.children)
    {
        if (node.kind != NSXMLElementKind)
            continue;
        NSXMLElement *element = (NSXMLElement *)node;

        if ([element.name isEqualToString:@"w:tbl"])
        {
            flushList();
            MDImportAppendBlock(out, [self tableOf:element]);
            continue;
        }
        if (![element.name isEqualToString:@"w:p"])
            continue;

        NSXMLElement *properties = MDChild(element, @"w:pPr");
        NSXMLElement *style = properties ? MDChild(properties, @"w:pStyle") : nil;
        NSString *styleName = style ? MDAttribute(style, @"w:val") : nil;
        NSXMLElement *numbering = properties ? MDChild(properties, @"w:numPr")
                                             : nil;
        NSString *text = [self inlineOf:element];

        if (numbering)
        {
            NSXMLElement *level = MDChild(numbering, @"w:ilvl");
            NSXMLElement *identifier = MDChild(numbering, @"w:numId");
            NSUInteger depth = level
                ? (NSUInteger)[MDAttribute(level, @"w:val") integerValue] : 0;
            NSString *numId = identifier ? MDAttribute(identifier, @"w:val")
                                         : nil;
            BOOL ordered = numId ? self.numbered[numId].boolValue : NO;

            // A list that follows another with a different numbering is
            // another list: run together, the bullets and the numbers
            // become one list with something odd in the middle of it.
            if (depth == 0 && listId && ![listId isEqualToString:numId ?: @""])
                flushList();
            if (depth == 0)
                listId = numId ?: @"";

            NSString *indent = [@"" stringByPaddingToLength:depth * 2
                withString:@" " startingAtIndex:0];
            [list addObject:[NSString stringWithFormat:@"%@%@ %@", indent,
                             ordered ? @"1." : @"-", text]];
            continue;
        }

        flushList();
        if (!text.length)
            continue;

        NSUInteger heading = [self headingLevelOf:styleName
                                       properties:properties];
        if (heading)
        {
            NSString *hashes = [@"" stringByPaddingToLength:heading
                withString:@"#" startingAtIndex:0];
            // Word's heading styles are bold, and the runs usually say so
            // as well: `# **Titolo**` is the same heading written twice.
            MDImportAppendBlock(out, [NSString stringWithFormat:@"%@ %@",
                                      hashes, MDImportWithoutWholeEmphasis(text)]);
            continue;
        }
        if ([styleName.lowercaseString containsString:@"quote"])
        {
            MDImportAppendBlock(out, [NSString stringWithFormat:@"> %@", text]);
            continue;
        }
        MDImportAppendBlock(out, text);
    }
    flushList();
    return out;
}

@end


MDImportResult *MDMarkdownFromWordXML(NSString *documentXML,
                                      NSString *relationshipsXML,
                                      NSString *numberingXML,
                                      NSString *stylesXML,
                                      NSString *pictureFolder)
{
    MDImportResult *result = [[MDImportResult alloc] init];
    result.markdown = @"";
    result.pictures = @[];
    result.lost = @[];
    if (!documentXML.length)
        return result;

    NSError *error = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc]
        initWithXMLString:documentXML options:NSXMLNodeOptionsNone
                    error:&error];
    if (!document)
    {
        result.lost = @[@"the document could not be read as XML"];
        return result;
    }

    MDWordReader *reader = [[MDWordReader alloc] init];
    reader.targets = MDWordRelationships(relationshipsXML);
    reader.numbered = MDWordNumbering(numberingXML);
    reader.headings = MDWordHeadingStyles(stylesXML);
    reader.pictureFolder = pictureFolder ?: @"media";
    reader.pictures = [NSMutableArray array];
    reader.lost = [NSMutableOrderedSet orderedSet];

    NSXMLElement *body = MDDescendants(document.rootElement, @"w:body").firstObject;
    if (!body)
        body = document.rootElement;

    result.markdown = [reader markdownOfBody:body];
    result.pictures = reader.pictures;
    result.lost = reader.lost.array;
    return result;
}


#pragma mark - OpenDocument

@interface MDOpenDocumentReader : NSObject
/// style name → bold, italic, or both: OpenDocument has no b and no i, only
/// names that have to be looked up in the automatic styles.
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *bold;
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *italic;
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *struck;
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *monospaced;
/// list style name → whether it numbers.
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *ordered;
@property (nonatomic) NSString *pictureFolder;
@property (nonatomic) NSMutableArray<MDImportPicture *> *pictures;
@property (nonatomic) NSMutableOrderedSet<NSString *> *lost;
@end


@implementation MDOpenDocumentReader

- (NSString *)inlineOf:(NSXMLElement *)element
                  bold:(BOOL)bold italic:(BOOL)italic
                strike:(BOOL)strike code:(BOOL)code
{
    NSMutableString *line = [NSMutableString string];
    for (NSXMLNode *node in element.children)
    {
        if (node.kind == NSXMLTextKind)
        {
            [line appendString:MDImportRun(node.stringValue ?: @"", bold,
                                           italic, strike, code)];
            continue;
        }
        if (node.kind != NSXMLElementKind)
            continue;
        NSXMLElement *child = (NSXMLElement *)node;
        NSString *name = child.name;

        if ([name isEqualToString:@"text:span"])
        {
            NSString *style = MDAttribute(child, @"text:style-name");
            [line appendString:[self inlineOf:child
                bold:(bold || self.bold[style].boolValue)
                italic:(italic || self.italic[style].boolValue)
                strike:(strike || self.struck[style].boolValue)
                code:(code || self.monospaced[style].boolValue)]];
        }
        else if ([name isEqualToString:@"text:a"])
        {
            NSString *inside = [self inlineOf:child bold:bold italic:italic
                                       strike:strike code:code];
            NSString *target = MDAttribute(child, @"xlink:href") ?: @"";
            [line appendFormat:@"[%@](%@)", inside, target];
        }
        else if ([name isEqualToString:@"text:s"])
        {
            NSInteger many = [MDAttribute(child, @"text:c") integerValue];
            [line appendString:[@"" stringByPaddingToLength:MAX(many, 1)
                withString:@" " startingAtIndex:0]];
        }
        else if ([name isEqualToString:@"text:tab"])
        {
            [line appendString:@" "];
        }
        else if ([name isEqualToString:@"text:line-break"])
        {
            [line appendString:@"  \n"];
        }
        else if ([name isEqualToString:@"draw:frame"]
                 || [name isEqualToString:@"draw:image"])
        {
            [line appendString:[self pictureIn:child]];
        }
        else
        {
            [line appendString:[self inlineOf:child bold:bold italic:italic
                                       strike:strike code:code]];
        }
    }
    return line;
}


- (NSString *)pictureIn:(NSXMLElement *)frame
{
    NSXMLElement *image = [frame.name isEqualToString:@"draw:image"]
        ? frame : MDDescendants(frame, @"draw:image").firstObject;
    NSString *entry = image ? MDAttribute(image, @"xlink:href") : nil;
    if (!entry.length)
    {
        [self.lost addObject:@"a picture whose file could not be found"];
        return @"";
    }
    if ([entry hasPrefix:@"./"])
        entry = [entry substringFromIndex:2];

    NSString *name = entry.lastPathComponent;
    [self.pictures addObject:[[MDImportPicture alloc] initWithEntry:entry
                                                              name:name]];
    NSString *described = MDAttribute(frame, @"draw:name") ?: @"";
    return [NSString stringWithFormat:@"![%@](%@/%@)",
            MDImportEscaped(described), self.pictureFolder, name];
}


- (NSString *)tableOf:(NSXMLElement *)table
{
    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
    NSMutableArray<NSXMLElement *> *rowElements = [NSMutableArray array];
    [rowElements addObjectsFromArray:MDDescendants(table, @"table:table-row")];

    for (NSXMLElement *row in rowElements)
    {
        NSMutableArray<NSString *> *cells = [NSMutableArray array];
        for (NSXMLElement *cell in MDChildren(row, @"table:table-cell"))
        {
            NSMutableArray<NSString *> *pieces = [NSMutableArray array];
            for (NSXMLElement *paragraph in MDChildren(cell, @"text:p"))
            {
                NSString *text = [self inlineOf:paragraph bold:NO italic:NO
                                         strike:NO code:NO];
                if (text.length)
                    [pieces addObject:text];
            }
            NSString *joined = [[pieces componentsJoinedByString:@" "]
                stringByReplacingOccurrencesOfString:@"  \n" withString:@" "];
            [cells addObject:[joined stringByReplacingOccurrencesOfString:@"|"
                                                               withString:@"\\|"]];
        }
        if (cells.count)
            [rows addObject:cells];
    }
    if (!rows.count)
        return @"";

    NSUInteger columns = 0;
    for (NSArray *row in rows)
        columns = MAX(columns, row.count);

    NSMutableString *out = [NSMutableString string];
    [rows enumerateObjectsUsingBlock:^(NSArray<NSString *> *row, NSUInteger i,
                                       BOOL *stop) {
        NSMutableArray<NSString *> *cells = [row mutableCopy];
        while (cells.count < columns)
            [cells addObject:@""];
        [out appendFormat:@"| %@ |\n", [cells componentsJoinedByString:@" | "]];
        if (i == 0)
        {
            NSMutableArray<NSString *> *rule = [NSMutableArray array];
            for (NSUInteger c = 0; c < columns; c++)
                [rule addObject:@"---"];
            [out appendFormat:@"| %@ |\n", [rule componentsJoinedByString:@" | "]];
        }
    }];
    return out;
}


/// A list, with the lists inside it: OpenDocument nests them properly, so
/// the indentation follows the nesting instead of a level attribute.
- (NSString *)listOf:(NSXMLElement *)list depth:(NSUInteger)depth
             ordered:(BOOL)ordered
{
    NSString *style = MDAttribute(list, @"text:style-name");
    if (style && self.ordered[style])
        ordered = self.ordered[style].boolValue;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSString *indent = [@"" stringByPaddingToLength:depth * 2
        withString:@" " startingAtIndex:0];

    for (NSXMLElement *item in MDChildren(list, @"text:list-item"))
    {
        for (NSXMLNode *node in item.children)
        {
            if (node.kind != NSXMLElementKind)
                continue;
            NSXMLElement *child = (NSXMLElement *)node;
            if ([child.name isEqualToString:@"text:p"]
                    || [child.name isEqualToString:@"text:h"])
            {
                NSString *text = [self inlineOf:child bold:NO italic:NO
                                         strike:NO code:NO];
                if (text.length)
                    [lines addObject:[NSString stringWithFormat:@"%@%@ %@",
                                      indent, ordered ? @"1." : @"-", text]];
            }
            else if ([child.name isEqualToString:@"text:list"])
            {
                NSString *inside = [self listOf:child depth:depth + 1
                                        ordered:ordered];
                if (inside.length)
                    [lines addObject:inside];
            }
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}


- (NSString *)markdownOfText:(NSXMLElement *)text
{
    NSMutableString *out = [NSMutableString string];
    for (NSXMLNode *node in text.children)
    {
        if (node.kind != NSXMLElementKind)
            continue;
        NSXMLElement *element = (NSXMLElement *)node;
        NSString *name = element.name;

        if ([name isEqualToString:@"text:h"])
        {
            NSInteger level = [MDAttribute(element, @"text:outline-level")
                integerValue];
            level = MIN(MAX(level, 1), 6);
            NSString *line = [self inlineOf:element bold:NO italic:NO
                                     strike:NO code:NO];
            if (line.length)
            {
                NSString *hashes = [@"" stringByPaddingToLength:(NSUInteger)level
                    withString:@"#" startingAtIndex:0];
                MDImportAppendBlock(out, [NSString stringWithFormat:@"%@ %@",
                                          hashes, line]);
            }
        }
        else if ([name isEqualToString:@"text:p"])
        {
            NSString *line = [self inlineOf:element bold:NO italic:NO
                                     strike:NO code:NO];
            NSString *style = MDAttribute(element, @"text:style-name") ?: @"";
            if ([style.lowercaseString containsString:@"quotation"])
                line = [NSString stringWithFormat:@"> %@", line];
            MDImportAppendBlock(out, line);
        }
        else if ([name isEqualToString:@"text:list"])
        {
            MDImportAppendBlock(out, [self listOf:element depth:0 ordered:NO]);
        }
        else if ([name isEqualToString:@"table:table"])
        {
            MDImportAppendBlock(out, [self tableOf:element]);
        }
        else if ([name isEqualToString:@"text:section"])
        {
            MDImportAppendBlock(out, [self markdownOfText:element]);
        }
    }
    return out;
}

@end


MDImportResult *MDMarkdownFromOpenDocumentXML(NSString *contentXML,
                                              NSString *pictureFolder)
{
    MDImportResult *result = [[MDImportResult alloc] init];
    result.markdown = @"";
    result.pictures = @[];
    result.lost = @[];
    if (!contentXML.length)
        return result;

    NSXMLDocument *document = [[NSXMLDocument alloc]
        initWithXMLString:contentXML options:NSXMLNodeOptionsNone error:NULL];
    if (!document)
    {
        result.lost = @[@"the document could not be read as XML"];
        return result;
    }

    // The automatic styles first: they are what bold and italic are called
    // in this document.
    NSMutableDictionary *bold = [NSMutableDictionary dictionary];
    NSMutableDictionary *italic = [NSMutableDictionary dictionary];
    NSMutableDictionary *struck = [NSMutableDictionary dictionary];
    NSMutableDictionary *monospaced = [NSMutableDictionary dictionary];
    for (NSXMLElement *style in MDDescendants(document.rootElement,
                                              @"style:style"))
    {
        NSString *name = MDAttribute(style, @"style:name");
        NSXMLElement *properties = MDChild(style, @"style:text-properties");
        if (!name || !properties)
            continue;
        NSString *weight = MDAttribute(properties, @"fo:font-weight");
        NSString *posture = MDAttribute(properties, @"fo:font-style");
        NSString *line = MDAttribute(properties, @"style:text-line-through-style");
        NSString *family = MDAttribute(properties, @"style:font-name")
            ?: MDAttribute(properties, @"fo:font-family");
        if ([weight isEqualToString:@"bold"])
            bold[name] = @YES;
        if ([posture isEqualToString:@"italic"]
                || [posture isEqualToString:@"oblique"])
            italic[name] = @YES;
        if (line.length && ![line isEqualToString:@"none"])
            struck[name] = @YES;
        if ([family.lowercaseString containsString:@"mono"]
                || [family.lowercaseString containsString:@"courier"])
            monospaced[name] = @YES;
    }

    NSMutableDictionary *ordered = [NSMutableDictionary dictionary];
    for (NSXMLElement *style in MDDescendants(document.rootElement,
                                              @"text:list-style"))
    {
        NSString *name = MDAttribute(style, @"style:name");
        if (!name)
            continue;
        BOOL numbers = MDDescendants(style,
            @"text:list-level-style-number").count > 0;
        ordered[name] = @(numbers);
    }

    MDOpenDocumentReader *reader = [[MDOpenDocumentReader alloc] init];
    reader.bold = bold;
    reader.italic = italic;
    reader.struck = struck;
    reader.monospaced = monospaced;
    reader.ordered = ordered;
    reader.pictureFolder = pictureFolder ?: @"media";
    reader.pictures = [NSMutableArray array];
    reader.lost = [NSMutableOrderedSet orderedSet];

    NSXMLElement *text = MDDescendants(document.rootElement,
                                       @"office:text").firstObject;
    if (!text)
    {
        result.lost = @[@"there is no text in this document"];
        return result;
    }

    result.markdown = [reader markdownOfText:text];
    result.pictures = reader.pictures;
    result.lost = reader.lost.array;
    return result;
}
