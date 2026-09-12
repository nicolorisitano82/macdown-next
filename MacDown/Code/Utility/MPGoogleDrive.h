//
//  MPGoogleDrive.h
//  MacDown
//
//  Il collegamento a Google Drive: le credenziali di chi lo usa, e il giro
//  che le trasforma in un permesso.
//
//  **Ognuno usa le sue.** Questa applicazione non porta dentro un client
//  OAuth suo, e non è pigrizia: un client che viaggia dentro un binario è
//  un client che chiunque può estrarre, e uno solo per tutti vuol dire una
//  verifica sola, una quota sola e una schermata di consenso che parla di
//  qualcun altro. Chi vuole collegare il suo Drive crea un client di tipo
//  «applicazione desktop» nella sua console, lo incolla nel pannello, e da
//  lì in poi il permesso è fra lui e Google: noi siamo il programma che
//  chiede, non l'intermediario.
//
//  Dove sta cosa, e perché:
//
//  | | Dove | Perché |
//  |---|---|---|
//  | ID client | preferenze | è pubblico per costruzione: sta nell'URL del consenso |
//  | Segreto | **portachiavi** | per un client desktop Google lo dichiara facoltativo, ma resta una credenziale che una persona ha incollato |
//  | Gettoni | **portachiavi** | non finiscono mai in un file di preferenze, né nel diario |
//
//  L'ambito è uno solo, `drive.file`: i file che l'applicazione crea e
//  quelli che la persona le dà dal Picker. Niente che assomigli a «vedi
//  tutto il mio Drive», che sarebbe *restricted* e un'altra storia.
//

#import <Foundation/Foundation.h>


/// Come è andato un collegamento.
typedef NS_ENUM(NSUInteger, MPGoogleLinkOutcome) {
    MPGoogleLinkDone,
    MPGoogleLinkCancelled,      ///< chiusa la finestra, o «annulla»
    MPGoogleLinkRefused,        ///< Google ha detto di no, con le sue parole
    MPGoogleLinkBroken,         ///< non si è potuto nemmeno cominciare
};


@interface MPGoogleDrive : NSObject

/// Uno, perché il pannello e il documento parlano dello stesso account.
+ (instancetype)sharedDrive;

/// L'ID client di chi usa l'applicazione, `…apps.googleusercontent.com`.
/// Vuoto finché non lo incolla.
@property (copy, nonatomic) NSString *clientIdentifier;

/// Il segreto, facoltativo. Scritto nel portachiavi, riletto solo da qui.
@property (copy, nonatomic) NSString *clientSecret;

/// Se le due cose sopra bastano per provare a collegarsi.
@property (readonly, nonatomic) BOOL isConfigured;

/// Se c'è un gettone di rinnovo nel portachiavi: siamo collegati.
@property (readonly, nonatomic) BOOL isLinked;

/// Chi ha dato il permesso, per dirlo nel pannello. Nil se non collegati.
@property (readonly, copy, nonatomic) NSString *accountName;

/// La cartella scelta col Picker: identificatore e nome.
@property (readonly, copy, nonatomic) NSString *folderIdentifier;
@property (readonly, copy, nonatomic) NSString *folderName;

/** Apre il consenso nel browser, col Picker acceso, e aspetta il richiamo.
 *
 * Il Picker, per un'applicazione desktop, **è** la schermata di consenso:
 * due parametri in più e il richiamo torna con quello che è stato scelto.
 * Niente vista web nostra, che sarebbe il posto sbagliato dove far
 * digitare la password di qualcuno a qualcun altro.
 *
 * `done` viene chiamato sulla coda principale.
 */
- (void)linkWithCompletion:(void (^)(MPGoogleLinkOutcome outcome,
                                     NSString *message))done;

/// Dimentica tutto: gettoni fuori dal portachiavi, cartella scelta via.
/// L'ID client resta, che è l'unica cosa che non è un segreto.
- (void)unlink;

@end


/// L'indirizzo del consenso, col Picker acceso: pura, così si può
/// guardare in una prova invece che in un browser.
extern NSURL *MPGoogleConsentURL(NSString *clientIdentifier,
                                 NSString *redirect,
                                 NSString *challenge);

/// La sfida PKCE di un verificatore: SHA-256 in base64url.
extern NSString *MPGooglePKCEChallenge(NSString *verifier);
