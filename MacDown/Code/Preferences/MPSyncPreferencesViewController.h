//
//  MPSyncPreferencesViewController.h
//  MacDown
//

#import "MPPreferencesViewController.h"
#import <MASPreferences/MASPreferencesViewController.h>


/// Il collegamento a Google Drive: le credenziali che ognuno si porta, e
/// la cartella che ha dato all'applicazione.
@interface MPSyncPreferencesViewController : MPPreferencesViewController
    <MASPreferencesViewController, NSTextFieldDelegate>

/** Scrive la riga di stato, e rende premibile quello che è un indirizzo.
 *
 * Pubblica perché è la parte che si prova: i messaggi che contano sono
 * quelli del servizio, e quello di Google quando manca un'API è una frase
 * lunga col link che la risolve dentro.
 */
- (void)say:(NSString *)text;

/// Quello che la riga di stato dice adesso, com'è scritto.
@property (readonly, nonatomic) NSAttributedString *stateText;

@end
