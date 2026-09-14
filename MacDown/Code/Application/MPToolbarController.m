//
//  MPToolbarController.m
//  MacDown
//
//  Created by Niklas Berglund on 2017-02-12.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPToolbarController.h"

// Because we're creating selectors for methods which aren't in this class
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wundeclared-selector"



@implementation MPToolbarController
{
    NSArray *toolbarItems;
    NSArray *toolbarItemIdentifiers;
    
    /**
     * Map toolbar item identifier to it's NSToolbarItem or NSToolbarItemGroup object
     */
}

- (id)init
{
    self = [super init];
    
    if (!self)
    {
        return nil;
    }
    
    [self setupToolbarItems];
    
    return self;
}


#pragma mark - Private

- (void)setupToolbarItems
{
    // Set up layout drop down alternatives. title will be set in validateUserInterfaceItem:
    NSMenuItem *toggleEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleEditorPane:) keyEquivalent:@"e"];
    NSMenuItem *togglePreviewMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(togglePreviewPane:) keyEquivalent:@"p"];
    
    // Set up all available toolbar items
    self->toolbarItems = @[
        [self toolbarItemGroupWithIdentifier:@"indent-group" separated:YES label:NSLocalizedString(@"Shift Left/Right", @"") items:@[
            [self toolbarItemWithIdentifier:@"shift-left" label:NSLocalizedString(@"Shift Left", @"Shift text to the left toolbar button") icon:@"ToolbarIconShiftLeft" action:@selector(unindent:)],
            [self toolbarItemWithIdentifier:@"shift-right" label:NSLocalizedString(@"Shift Right", @"Shift text to the right toolbar button") icon:@"ToolbarIconShiftRight" action:@selector(indent:)]
            ]
        ],
        [self toolbarItemGroupWithIdentifier:@"text-formatting-group" separated:NO label:NSLocalizedString(@"Text Styles", @"") items:@[
            [self toolbarItemWithIdentifier:@"bold" label:NSLocalizedString(@"Strong", @"Strong toolbar button") icon:@"ToolbarIconBold" action:@selector(toggleStrong:)],
            [self toolbarItemWithIdentifier:@"italic" label:NSLocalizedString(@"Emphasize", @"Emphasize toolbar button") icon:@"ToolbarIconItalic" action:@selector(toggleEmphasis:)],
            [self toolbarItemWithIdentifier:@"underline" label:NSLocalizedString(@"Underline", @"Underline toolbar button") icon:@"ToolbarIconUnderlined" action:@selector(toggleUnderline:)]
            ]
         ],
        [self toolbarItemGroupWithIdentifier:@"heading-group" separated:NO label:NSLocalizedString(@"Headings", @"") items:@[
            [self toolbarItemWithIdentifier:@"heading1" label:NSLocalizedString(@"Heading 1", @"Heading 1 toolbar button") icon:@"ToolbarIconHeading1" action:@selector(convertToH1:)],
            [self toolbarItemWithIdentifier:@"heading2" label:NSLocalizedString(@"Heading 2", @"Heading 2 toolbar button") icon:@"ToolbarIconHeading2" action:@selector(convertToH2:)],
            [self toolbarItemWithIdentifier:@"heading3" label:NSLocalizedString(@"Heading 3", @"Heading 3 toolbar button") icon:@"ToolbarIconHeading3" action:@selector(convertToH3:)]
            ]
         ],
        [self toolbarItemGroupWithIdentifier:@"list-group" separated:YES label:NSLocalizedString(@"Ordered/Unordered List", @"") items:@[
            [self toolbarItemWithIdentifier:@"unordered-list" label:NSLocalizedString(@"Unordered List", @"Unordered list toolbar button") icon:@"ToolbarIconUnorderedList" action:@selector(toggleUnorderedList:)],
            [self toolbarItemWithIdentifier:@"ordered-list" label:NSLocalizedString(@"Ordered List", @"Ordered list toolbar button") icon:@"ToolbarIconOrderedList" action:@selector(toggleOrderedList:)]
            ]
         ],
        [self toolbarItemWithIdentifier:@"blockquote" label:NSLocalizedString(@"Blockquote", @"Blockquote toolbar button") icon:@"ToolbarIconBlockquote" action:@selector(toggleBlockquote:)],
        [self toolbarItemWithIdentifier:@"code" label:NSLocalizedString(@"Code", @"Code toolbar button") icon:@"ToolbarIconInlineCode" action:@selector(insertCode:)],
        [self toolbarItemWithIdentifier:@"link" label:NSLocalizedString(@"Link", @"Link toolbar button") icon:@"ToolbarIconLink" action:@selector(toggleLink:)],
        [self toolbarItemWithIdentifier:@"attach" label:NSLocalizedString(@"Attach", @"Button of the attachment chooser") icon:@"paperclip" action:@selector(attachFile:)],
        [self toolbarItemWithIdentifier:@"image" label:NSLocalizedString(@"Image", @"Image toolbar button") icon:@"ToolbarIconImage" action:@selector(toggleImage:)],
        [self toolbarItemWithIdentifier:@"table" label:NSLocalizedString(@"Table", @"Insert table toolbar button") icon:@"tablecells" action:@selector(insertTable:)],
        [self toolbarItemWithIdentifier:@"copy-html" label:NSLocalizedString(@"Copy HTML", @"Copy HTML toolbar button") icon:@"ToolbarIconCopyHTML" action:@selector(copyHtml:)],
        [self toolbarItemWithIdentifier:@"comment" label:NSLocalizedString(@"Comment", @"Comment toolbar button") icon:@"ToolbarIconComment" action:@selector(toggleComment:)],
        [self toolbarItemWithIdentifier:@"highlight" label:NSLocalizedString(@"Highlight", @"Highlight toolbar button") icon:@"ToolbarIconHighlight" action:@selector(toggleHighlight:)],
        [self toolbarItemWithIdentifier:@"strikethrough" label:NSLocalizedString(@"Strikethrough", @"Strikethrough toolbar button") icon:@"ToolbarIconStrikethrough" action:@selector(toggleStrikethrough:)],
        [self toolbarItemDropDownWithIdentifier:@"layout" label:NSLocalizedString(@"Layout", @"Layout toolbar button") icon:@"ToolbarIconEditorAndPreview" menuItems:
            @[
              toggleEditorMenuItem, togglePreviewMenuItem
            ]
        ]
    ];
    
    self->toolbarItemIdentifiers = [self toolbarItemIdentifiersFromItemsArray:self->toolbarItems];
}

/**
 * Returns an array with all item identifiers for the toolbar items in the passed in _toolbarItemsArray_.
 */
- (NSArray *)toolbarItemIdentifiersFromItemsArray:(NSArray *)toolbarItemsArray {
    NSMutableArray *orderedIdentifiers = [NSMutableArray new];
    
    for (NSToolbarItem *item in self->toolbarItems) {
        [orderedIdentifiers addObject:item.itemIdentifier];
    }
    
    return [orderedIdentifiers copy];
}

- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    // From toolbar item dictionary(setupToolbarItems)
    //NSArray *orderedToolbarItemIdentifiers = [self orderedToolbarDefaultItemKeysForDictionary:self->toolbarItems];
    NSArray *orderedToolbarItemIdentifiers = [self toolbarItemIdentifiersFromItemsArray:self->toolbarItems];
    
    // Mixed identifiers from dictionary and space at below specified indices
    NSMutableArray *defaultItemIdentifiers = [NSMutableArray new];
    
    // Flexible space after these item indices, grouping the buttons.
    //
    // Both counters used to run unbounded past the end of their arrays, and
    // the space array was declared empty, so every iteration read whatever
    // sat next to it on the stack. It happened not to crash here; it does
    // crash for others.
    // Gli indici sono nell'ordine dell'elenco qui sopra, quindi una voce
    // aggiunta in mezzo li sposta tutti quelli che vengono dopo: con
    // «allega» fra il link e l'immagine, lo spazio che stava dopo
    // l'immagine passa da 7 a 8, e quello in fondo da 11 a 12.
    static const int flexibleSpaceAfterIndices[] = {2, 3, 5, 8, 12};
    static const int flexibleSpaceCount =
        sizeof(flexibleSpaceAfterIndices) / sizeof(flexibleSpaceAfterIndices[0]);
    int i = 0;
    int k = 0;
    
    for (NSString *itemIdentifier in orderedToolbarItemIdentifiers)
    {
        // exclude some toolbar items from the default toolbar
        if ([itemIdentifier  isEqual: @"comment"]
            || [itemIdentifier  isEqual: @"highlight"]
            || [itemIdentifier  isEqual: @"strikethrough"]) {
            // do nothing here
        }else {
            [defaultItemIdentifiers addObject:itemIdentifier];
        }
        
        if (k < flexibleSpaceCount && i == flexibleSpaceAfterIndices[k])
        {
            [defaultItemIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
            k++;
        }
        
        i++;
    }
    
    return [defaultItemIdentifiers copy];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return self->toolbarItemIdentifiers;
}

- (NSArray<NSString *> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item;
    
    for (NSToolbarItem *currentItem in self->toolbarItems) {
        if ([currentItem.itemIdentifier isEqualToString:itemIdentifier]) {
            item = currentItem;
            break;
        }
    }
    
    return item;
}


#pragma mark - Toolbar item factory methods

/**
 * Factory method for creating and configuring a NSToolbarItemGroup object.
 *
 * The separated flag no longer drives anything. It used to pick a segment
 * style on a hand-built NSSegmentedControl; AppKit now decides how the
 * subitems are grouped and separated, which is what lets the group adopt the
 * toolbar material.
 */
- (NSToolbarItemGroup *)toolbarItemGroupWithIdentifier:(NSString *)itemIdentifier separated:(BOOL)separated label:(NSString *)label items:(NSArray <NSToolbarItem *>*)items {
    NSToolbarItemGroup *itemGroup =
        [[NSToolbarItemGroup alloc] initWithItemIdentifier:itemIdentifier];
    itemGroup.label = label;
    itemGroup.paletteLabel = label;
    itemGroup.controlRepresentation =
        NSToolbarItemGroupControlRepresentationAutomatic;
    itemGroup.subitems = items;

    return itemGroup;
}

/**
 * Factory method for creating and configuring a NSToolbarItem object.
 */
- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)itemIdentifier label:(NSString *)label icon:(NSString *)iconImageName action:(SEL)action {
    NSToolbarItem *toolbarItem =
        [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    toolbarItem.label = label;
    toolbarItem.paletteLabel = label;
    toolbarItem.toolTip = label;

    // A system symbol when the asset catalogue has no icon of that name:
    // a command added later does not need a drawing of its own, and a
    // symbol sits with the rest of the toolbar better than one would.
    NSImage *itemImage = [NSImage imageNamed:iconImageName];
    if (!itemImage)
    {
        itemImage = [NSImage imageWithSystemSymbolName:iconImageName
                              accessibilityDescription:label];
    }
    itemImage.template = YES;

    // No custom view on purpose. An item that carries its own NSButton is
    // drawn entirely by that button, so AppKit cannot place it on the
    // toolbar's material or tint the glyph against what shows through the
    // transparent titlebar: the glyph took one colour from the appearance and
    // vanished wherever the content behind it happened to match. A bordered
    // item gets both, and stays readable over a dark editor and a light
    // preview alike.
    toolbarItem.image = itemImage;
    toolbarItem.bordered = YES;

    // Target stays nil so the action travels the responder chain to whichever
    // document is in front, which is also what gets -validateUserInterfaceItem:
    // called on it. The old code assigned self.document here, which is still
    // nil at this point because the outlet is connected after init.
    toolbarItem.action = action;

    return toolbarItem;
}

/**
 * Factory method for creating and configuring a menu-backed NSToolbarItem
 * holding the options passed in the menuItems parameter.
 */
- (NSToolbarItem *)toolbarItemDropDownWithIdentifier:(NSString *)itemIdentifier label:(NSString *)label icon:(NSString *)iconImageName menuItems:(NSArray <NSMenuItem *>*)menuItems {
    NSMenuToolbarItem *toolbarItem =
        [[NSMenuToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    toolbarItem.label = label;
    toolbarItem.paletteLabel = label;
    toolbarItem.toolTip = label;

    // A system symbol when the asset catalogue has no icon of that name:
    // a command added later does not need a drawing of its own, and a
    // symbol sits with the rest of the toolbar better than one would.
    NSImage *itemImage = [NSImage imageNamed:iconImageName];
    if (!itemImage)
    {
        itemImage = [NSImage imageWithSystemSymbolName:iconImageName
                              accessibilityDescription:label];
    }
    itemImage.template = YES;
    toolbarItem.image = itemImage;
    toolbarItem.bordered = YES;
    toolbarItem.showsIndicator = YES;

    // These items are created with empty titles: MPDocument fills them in
    // from -validateUserInterfaceItem: so each one can read Hide or Restore.
    // Leaving the target nil is what routes validation there.
    NSMenu *menu = [[NSMenu alloc] initWithTitle:label];
    for (NSMenuItem *menuItem in menuItems)
        [menu addItem:menuItem];
    toolbarItem.menu = menu;

    return toolbarItem;
}

@end
