//
//  MPSidebarController.h
//  MacDown
//
//  A sidebar with two views of where you are: the headings in this document,
//  and the files sitting next to it.
//

#import <Cocoa/Cocoa.h>


/// Un documento che non sta su questo disco: quello che serve per
/// mostrarlo in elenco e per riaprirlo dal servizio da cui viene.
@interface MPSidebarRemoteFile : NSObject
@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *identifier;
@end


@protocol MPSidebarControllerDelegate <NSObject>

/// A heading was chosen. The range is into the Markdown source.
- (void)sidebarDidSelectHeadingRange:(NSRange)range;

/// A file was chosen.
- (void)sidebarDidSelectFileURL:(NSURL *)url;

@optional
/// Uno dei documenti che stanno nel servizio è stato scelto.
- (void)sidebarDidSelectRemoteDocument:(NSString *)identifier
                                 named:(NSString *)name;

/// La scheda degli allegati è stata aperta e vuole l'elenco di adesso.
- (void)sidebarNeedsTheAttachments;

/// Un allegato è stato scelto.
- (void)sidebarDidSelectAttachment:(NSURL *)file;

/// Di un allegato si vuole una copia altrove.
- (void)sidebarDidAskToSaveAttachment:(NSURL *)file;

@end


@interface MPSidebarController : NSObject

@property (weak, nonatomic) id<MPSidebarControllerDelegate> delegate;

/// The view to put in a window. Built on first access.
@property (readonly, nonatomic) NSView *view;

/// Rebuilds the outline. Cheap enough for every edit.
- (void)updateOutlineWithMarkdown:(NSString *)markdown;

/// The folder the file list shows. Nil for an unsaved document, which leaves
/// the list empty rather than guessing at somewhere to point it.
- (void)setRootURL:(NSURL *)url;

/** L'elenco dei file quando la cartella non è su questo disco.
 *
 * Un documento aperto da un servizio collegato ha dei vicini come ne ha
 * uno su disco: sono i documenti che stanno là dentro. Mostrare la
 * cartella temporanea da cui non viene, o niente, sarebbe rispondere a una
 * domanda diversa da quella che si fa aprendo la barra.
 *
 * Passare nil torna all'elenco del disco.
 */
- (void)showRemoteDocuments:(NSArray<MPSidebarRemoteFile *> *)documents
                       from:(NSString *)placeName;

/// Il nome del posto che l'elenco sta mostrando, o nil se è il disco.
@property (readonly, copy, nonatomic) NSString *remotePlaceName;

/// Gli allegati del documento, nella loro scheda: i file che il testo si
/// porta dietro, con l'icona che il sistema dà a ciascuno.
- (void)showAttachments:(NSArray<NSURL *> *)attachments;

/// Highlights the heading containing `location`, following the caret.
- (void)selectHeadingContainingLocation:(NSUInteger)location;

@end
