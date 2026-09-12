//
//  MPCloudService.h
//  MacDown
//
//  Un servizio a cui questa applicazione si collega — Google Drive,
//  Dropbox — e le credenziali con cui lo fa.
//
//  **Ognuno porta le sue.** Questa applicazione non ha un client OAuth
//  dentro il binario, e non è pigrizia: un client che viaggia dentro un
//  programma lo estrae chiunque, e uno solo per tutti vuol dire una
//  verifica sola, una quota sola e una schermata di consenso col nome di
//  qualcun altro. Chi vuole collegare il suo spazio si registra
//  un'applicazione desktop nella console del servizio, incolla l'ID nel
//  pannello, e da lì in poi il permesso è fra lui e il servizio: noi siamo
//  il programma che chiede, non l'intermediario.
//
//  Dove sta cosa, e vale per tutti e due:
//
//  | | Dove | Perché |
//  |---|---|---|
//  | ID client | preferenze | è pubblico per costruzione: sta nell'URL del consenso |
//  | Segreto | **portachiavi** | per un client desktop è dichiarato facoltativo, ma resta una credenziale incollata da qualcuno |
//  | Gettoni | **portachiavi** | non finiscono mai in un file di preferenze, né nel diario |
//
//  Quello che cambia da un servizio all'altro sta tutto in questa classe:
//  l'indirizzo del consenso, quello dei gettoni, e cosa si sceglie. Il
//  resto — PKCE, l'ascolto su 127.0.0.1, lo scambio del codice — è uguale,
//  ed è scritto una volta sola.
//

#import <Foundation/Foundation.h>


/// Come è andato un collegamento.
typedef NS_ENUM(NSUInteger, MPCloudLinkOutcome) {
    MPCloudLinkDone,
    MPCloudLinkCancelled,       ///< chiusa la finestra, o «annulla»
    MPCloudLinkRefused,         ///< il servizio ha detto di no, con le sue parole
    MPCloudLinkBroken,          ///< non si è potuto nemmeno cominciare
};


@interface MPCloudService : NSObject

/// I servizi che l'applicazione conosce, nell'ordine in cui si mostrano.
+ (NSArray<MPCloudService *> *)services;

/// Come si chiama nel pannello: «Google Drive», «Dropbox».
@property (readonly, copy, nonatomic) NSString *name;

/// Il nome corto senza spazi, che è anche la chiave sotto cui le cose
/// vengono ricordate: `google`, `dropbox`.
@property (readonly, copy, nonatomic) NSString *identifier;

/// Se si può usare davvero, o è solo annunciato. Un servizio che non c'è
/// ancora si mostra lo stesso, spento: nasconderlo vorrebbe dire far
/// cercare alla gente una cosa che è in programma.
@property (readonly, nonatomic) BOOL available;

/// Il pulsante che apre la console dove ci si registra, e dove porta.
@property (readonly, copy, nonatomic) NSString *consoleButtonTitle;
@property (readonly, copy, nonatomic) NSURL *consoleURL;

/// Le due spiegazioni che il pannello mostra: cos'è, e come si ottiene un
/// client. Stanno qui perché sono diverse per ogni servizio.
@property (readonly, copy, nonatomic) NSString *explanation;
@property (readonly, copy, nonatomic) NSString *howToGetAClient;

/// Quello che si vede nel campo dell'ID quando è vuoto.
@property (readonly, copy, nonatomic) NSString *clientPlaceholder;

/// Che cosa si sta chiedendo al servizio, detto in una riga.
@property (readonly, copy, nonatomic) NSString *scopeExplanation;

/// L'ID client di chi usa l'applicazione. Vuoto finché non lo incolla.
@property (copy, nonatomic) NSString *clientIdentifier;

/// Il segreto, facoltativo. Scritto nel portachiavi, riletto solo da qui.
@property (copy, nonatomic) NSString *clientSecret;

/// Se quello che c'è basta per provare a collegarsi.
@property (readonly, nonatomic) BOOL isConfigured;

/// Se c'è un gettone di rinnovo nel portachiavi: siamo collegati.
@property (readonly, nonatomic) BOOL isLinked;

/// Su cosa: la cartella scelta, per chi la fa scegliere; la cartella
/// dell'applicazione, per chi non lo fa. Nil quando non si sa.
@property (readonly, copy, nonatomic) NSString *placeIdentifier;
@property (readonly, copy, nonatomic) NSString *placeName;

/** Apre il consenso nel browser e aspetta il richiamo su 127.0.0.1.
 *
 * Il consenso si dà nel browser, che è l'unico posto dove ha senso darlo:
 * una vista web nostra sarebbe il posto sbagliato in cui far digitare a
 * qualcuno la password di qualcun altro.
 *
 * `done` viene chiamato sulla coda principale.
 */
- (void)linkWithCompletion:(void (^)(MPCloudLinkOutcome outcome,
                                     NSString *message))done;

/// Dimentica tutto: gettoni fuori dal portachiavi, posto scelto via.
/// L'ID client resta, che è l'unica cosa che non è un segreto.
- (void)unlink;

@end


/// La sfida PKCE di un verificatore: SHA-256 in base64url.
extern NSString *MPCloudPKCEChallenge(NSString *verifier);

/// L'indirizzo del consenso di un servizio, con la sua sfida. Pura, così
/// si guarda in una prova invece che in un browser.
extern NSURL *MPCloudConsentURL(MPCloudService *service,
                                NSString *redirect, NSString *challenge);
