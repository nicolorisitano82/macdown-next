//
//  MDOfficeImport.h
//  DocumentImport — a MacDown Next plug-in
//
//  A .docx or an .odt turned into Markdown.
//
//  Both formats are a zip of XML: `word/document.xml` for one,
//  `content.xml` for the other. What is in here is only the second half —
//  XML in, Markdown out — with no file, no zip and no window in sight, so
//  that the awkward parts (a list inside a list, a table whose cells hold
//  paragraphs, a run of bold that begins in the middle of a word) can be
//  asked in a test rather than found in somebody's document.
//

#import <Foundation/Foundation.h>


/// A picture the document carries: where it was inside the archive, and the
/// name it should be written under beside the Markdown.
@interface MDImportPicture : NSObject
@property (readonly, copy, nonatomic) NSString *entry;   // word/media/image1.png
@property (readonly, copy, nonatomic) NSString *name;    // image1.png
- (instancetype)initWithEntry:(NSString *)entry name:(NSString *)name;
@end


/// What a conversion produced.
@interface MDImportResult : NSObject
@property (readonly, copy, nonatomic) NSString *markdown;
/// The pictures the Markdown refers to, in the order it refers to them.
@property (readonly, copy, nonatomic) NSArray<MDImportPicture *> *pictures;
/// What could not be carried over, in the reader's words — an empty list
/// when everything came through.
@property (readonly, copy, nonatomic) NSArray<NSString *> *lost;
@end


/** A Word document's XML turned into Markdown.
 *
 * `relationships` is `word/_rels/document.xml.rels`, which is where a
 * hyperlink's address and a picture's file name actually live — the
 * document itself only carries an identifier. `numbering` is
 * `word/numbering.xml`, which says whether a list is bulleted or numbered;
 * without it every list is bulleted, which is the safer guess.
 *
 * `pictureFolder` is the name of the folder the pictures will be written
 * into, and only ends up inside the links.
 */
extern MDImportResult *MDMarkdownFromWordXML(NSString *documentXML,
                                             NSString *relationshipsXML,
                                             NSString *numberingXML,
                                             NSString *pictureFolder);

/** An OpenDocument text's XML turned into Markdown.
 *
 * `contentXML` carries the text and, in its automatic styles, what bold and
 * italic mean in this particular document — there are no b and i elements
 * in OpenDocument, only style names that have to be looked up.
 */
extern MDImportResult *MDMarkdownFromOpenDocumentXML(NSString *contentXML,
                                                     NSString *pictureFolder);

/// The Markdown escaping of a piece of plain text: what would otherwise be
/// read as markup when the document is opened again.
extern NSString *MDImportEscaped(NSString *text);
