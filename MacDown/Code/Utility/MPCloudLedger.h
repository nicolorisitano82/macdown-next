//
//  MPCloudLedger.h
//  MacDown
//
//  Il registro: cosa questa applicazione sa, di un servizio, fra una
//  occhiata e l'altra.
//
//  È il pezzo che separa una sincronizzazione da un carica-e-scarica.
//  Senza, ogni volta si rifà l'elenco di tutto e si confronta a occhio;
//  con, si chiede al servizio **cosa è cambiato da quando ho guardato**, e
//  si sa rispondere a «questo l'ho già visto?».
//
//  Due cose dentro, e nessuna è un segreto:
//
//  * il **gettone di partenza**, che è il segnalibro del servizio: «da qui
//    in poi raccontami»;
//  * quello che si sa di ogni documento — identificatore, nome, versione,
//    e dove sta qui se è sceso.
//
//  Sta in un file dentro Application Support, non nelle preferenze: le
//  preferenze sono per le scelte di chi usa l'applicazione, e questo è un
//  quaderno che cresce.
//

#import <Foundation/Foundation.h>


/// Cosa è cambiato, da un'occhiata alla successiva.
@interface MPCloudDelta : NSObject
@property (assign, nonatomic) NSUInteger added;
@property (assign, nonatomic) NSUInteger changed;
@property (assign, nonatomic) NSUInteger removed;
/// Se non è successo niente. Una sincronizzazione che non dice niente
/// quando non c'è niente da dire è una sincronizzazione educata.
@property (readonly, nonatomic) BOOL isQuiet;
/// Detto a parole, per una riga di pannello.
@property (readonly, copy, nonatomic) NSString *summary;
@end


@interface MPCloudLedger : NSObject

/// Il registro di un servizio, letto dal disco. Uno per identificatore.
+ (instancetype)ledgerFor:(NSString *)service;

/// Lo stesso, in una cartella data: è così che si prova senza toccare la
/// cartella vera di chi sta usando l'applicazione.
- (instancetype)initWithService:(NSString *)service
                       inFolder:(NSURL *)folder;

/// Il segnalibro del servizio: da dove riprendere a farsi raccontare.
@property (copy, nonatomic) NSString *startToken;

/// Quanti documenti conosce.
@property (readonly, nonatomic) NSUInteger count;

/// Quello che sa di un documento: `name`, `revision`, `path`, o nil.
- (NSDictionary *)documentWithIdentifier:(NSString *)identifier;

/** Prende quello che il servizio ha raccontato e lo mette a registro.
 *
 * Ogni voce è come la dà Drive: un `fileId`, un `file` con dentro nome e
 * versione, e `removed` quando è sparito. Quello che torna è il conto di
 * cosa è cambiato, che è la sola cosa che interessa a chi guarda.
 */
- (MPCloudDelta *)applyChanges:(NSArray<NSDictionary *> *)changes;

/// Scrive il registro dove sta. Chiamata dopo ogni occhiata.
- (BOOL)save;

/// Dimentica tutto: si usa quando ci si scollega.
- (void)forget;

@end
