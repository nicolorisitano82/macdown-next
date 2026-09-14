//
//  MPAttachments.h
//  MacDown
//
//  Allegare un file a un documento Markdown.
//
//  Il Markdown, di suo, non ha allegati: ha link e immagini, e basta. Chi
//  ha provato a darglieli ha fatto tutti la stessa cosa — **il file accanto
//  al testo, e un link relativo** — cambiando solo dove sta la cartella:
//  `assets/` dentro un textbundle, la cartella degli allegati in un vault
//  di Obsidian, `data/` per ID in org-attach, `_resources/` all'uscita di
//  Joplin. Qui si fa lo stesso, con una regola sola:
//
//  * un documento **su disco** tiene i suoi allegati in `<nome>.assets`
//    accanto a sé;
//  * un **textbundle** li tiene in `assets/`, che è quello che il formato
//    dice da sempre;
//  * un documento **in un servizio collegato** li manda nella cartella
//    collegata, dove sta lui;
//  * chi vuole un documento che non dipende da niente li **incorpora**
//    come `data:`, che è un URL e quindi funziona in qualunque Markdown —
//    al prezzo di un file che diventa un terzo più grande, scritto su una
//    riga sola.
//
//  Quello che si allega non è quello che si linka: un `.md` accanto resta
//  un documento vicino, non un allegato, e le immagini hanno già la loro
//  strada. Un allegato è un file di **un altro genere** — un PDF, un
//  foglio, un archivio — che il documento si porta dietro.
//

#import <Cocoa/Cocoa.h>


/// La cartella degli allegati di un documento, che esista o no. Nil per un
/// documento che su disco non c'è ancora.
extern NSURL *MPAttachmentsFolderFor(NSURL *documentURL);

/// Come si chiama, nel link: `nota.assets` o `assets`.
extern NSString *MPAttachmentsFolderNameFor(NSURL *documentURL);

/** Mette il file fra gli allegati del documento e torna il nome che ha
 * preso — che è il suo, o il suo con un numero, se quel nome era occupato.
 *
 * Nil con il perché quando non si è potuto copiare.
 */
extern NSString *MPAttachFileToDocument(NSURL *source, NSURL *documentURL,
                                        NSString **problem);

/// Il pezzo di Markdown che punta a un allegato: un'immagine si vede, un
/// file si apre.
extern NSString *MPAttachmentMarkdown(NSString *name, NSString *folder);

/// Un file dentro un URL `data:`, per chi il documento lo vuole da solo.
extern NSString *MPDataURIForFile(NSURL *file, NSString **problem);

/// Se quel nome è un'immagine, che ha già la sua strada nel Markdown.
extern BOOL MPIsAPicture(NSString *name);

/// Se quel nome è un documento di testo: un vicino, non un allegato.
extern BOOL MPIsANeighbouringDocument(NSString *name);

/** Gli allegati di un documento, dal suo testo: i link locali che non sono
 * né immagini né documenti vicini.
 *
 * È quello che serve a chi deve portarseli dietro — il textbundle, l'email,
 * l'EPUB — per sapere **quali file** sono parte del documento.
 */
extern NSArray<NSURL *> *MPAttachmentsIn(NSString *markdown,
                                         NSURL *documentURL);

/** Gli allegati dentro l'HTML, portati dentro come `data:`.
 *
 * Un HTML esportato altrove porta link che puntano a una cartella rimasta
 * indietro. Le immagini restano come sono — quelle hanno già la loro
 * strada, e una pagina con dentro tutte le foto è un'altra decisione — ma
 * un allegato che era un file diventa il file stesso, dentro la pagina.
 */
extern NSString *MPHTMLWithAttachmentsInlined(NSString *html, NSURL *base);

/// Se quell'indirizzo è un allegato di qualcuno: un file che c'è, che non
/// è un'immagine e non è un documento di testo.
extern BOOL MPLooksLikeAnAttachment(NSURL *url);

/** L'HTML con l'icona del file davanti a ogni allegato.
 *
 * Nell'anteprima un allegato è un link come un altro, e non si distingue
 * da un rimando a una pagina: l'icona che il sistema dà a quel tipo di
 * file lo dice prima di leggerne il nome.
 */
extern NSString *MPHTMLWithAttachmentIcons(NSString *html, NSURL *base);

/// L'icona di un file, come `data:` da mettere in una pagina.
extern NSString *MPIconDataURIForFile(NSURL *file);
