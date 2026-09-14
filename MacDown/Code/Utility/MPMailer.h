//
//  MPMailer.h
//  MacDown
//
//  Il documento come email: quello che si vede nell'anteprima, dentro un
//  messaggio, nel programma di posta che si sceglie.
//
//  Il punto dolente è che **la posta non ha un modo solo**. Mail sa
//  ricevere un messaggio in HTML da uno script e lo mette in una finestra
//  di composizione vera; ogni altro programma, e la posta nel browser,
//  arrivano soltanto fin dove arriva `mailto:`, che è testo semplice e
//  nient'altro. Quindi due strade, dichiarate:
//
//  * **Mail**: il messaggio nasce già formattato, immagini comprese;
//  * **tutti gli altri**: la stessa email finisce negli **appunti** come
//    testo ricco, si apre la finestra nuova del programma, e si incolla.
//
//  Fingere che la seconda sia la prima — dire «inviato» quando si è solo
//  aperta una finestra vuota — sarebbe la cosa peggiore da fare qui.
//

#import <Cocoa/Cocoa.h>


/// Come si arriva al messaggio, per un programma dato.
typedef NS_ENUM(NSUInteger, MPMailWay) {
    MPMailWayAppleMail,     ///< con uno script: HTML vero e allegati
    MPMailWayOutlook,       ///< con uno script: allegati, corpo dagli appunti
    MPMailWayApplication,   ///< `mailto:` e gli appunti
    MPMailWayWeb,           ///< la finestra di composizione nel browser
};


/// Un programma di posta che si può scegliere.
@interface MPMailClient : NSObject
@property (copy, nonatomic) NSString *name;
/// Dov'è l'applicazione. Nil per la posta che sta nel browser.
@property (strong, nonatomic) NSURL *applicationURL;
/// L'indirizzo che apre una finestra di composizione, con `%@` al posto
/// dell'oggetto. Solo per il web.
@property (copy, nonatomic) NSString *composeFormat;
@property (nonatomic) MPMailWay way;
@property (strong, nonatomic) NSImage *icon;
@end


@interface MPMailer : NSObject

/// I programmi fra cui scegliere: quelli che il sistema dichiara capaci di
/// `mailto:`, più la posta che vive nel browser. Il primo è quello che il
/// sistema userebbe da sé.
+ (NSArray<MPMailClient *> *)clients;

/** Apre il messaggio dove è stato chiesto.
 *
 * Torna NO con il perché quando non si è potuto fare; torna YES anche
 * quando la strada era quella degli appunti — `wantsPasting` dice se chi
 * ha chiamato deve avvisare che l'email è lì e va incollata.
 */
+ (BOOL)open:(MPMailClient *)client
     subject:(NSString *)subject
        html:(NSString *)html
       plain:(NSString *)plain
 attachments:(NSArray<NSURL *> *)attachments
wantsPasting:(BOOL *)wantsPasting
     problem:(NSString **)problem;

/// Se quel programma sa ricevere allegati da fuori. `mailto:` no, e non
/// c'è modo: la RFC non li prevede, e chi li aveva li ha tolti.
+ (BOOL)takesAttachments:(MPMailClient *)client;

/// Il testo semplice di un HTML: l'alternativa che ogni email si porta.
+ (NSString *)plainTextFrom:(NSString *)html;

/// Lo script che Mail riceve, dato il file in cui sta l'HTML. Puro, così
/// si guarda in una prova invece che in un programma di posta.
+ (NSString *)appleMailScriptForSubject:(NSString *)subject
                                htmlAt:(NSString *)path
                           attachments:(NSArray<NSURL *> *)attachments;

/// Lo stesso per Outlook, che da uno script prende l'oggetto e gli
/// allegati ma non il corpo formattato: quello resta agli appunti.
+ (NSString *)outlookScriptForSubject:(NSString *)subject
                          attachments:(NSArray<NSURL *> *)attachments;

@end


/** Le immagini locali dentro l'HTML, portate dentro il messaggio.
 *
 * Un'email che rimanda a `/Users/qualcuno/foto.png` è un'email con un
 * riquadro vuoto per chiunque non sia quel qualcuno. Ogni `src` che punta a
 * un file diventa un `data:` — quelle già `data:`, e quelle remote, restano
 * dove sono.
 */
extern NSString *MPHTMLWithLocalImagesInlined(NSString *html, NSURL *base);
