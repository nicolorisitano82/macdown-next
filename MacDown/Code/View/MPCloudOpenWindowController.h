//
//  MPCloudOpenWindowController.h
//  MacDown
//
//  I documenti che stanno in un servizio collegato, in una finestra che
//  somiglia a quella con cui si aprono i file di sempre.
//
//  A sinistra i servizi — anche quando è uno solo, perché è lì che si
//  guarda per sapere *dove* si è — e a destra i documenti con la data e la
//  dimensione, ordinabili per colonna. Non è un gestore di file: non si
//  rinomina, non si cancella, non si spostano cartelle. È il ponte fra «ho
//  collegato uno spazio» e «ci lavoro».
//

#import <Cocoa/Cocoa.h>

@class MPCloudService;
@class MPCloudDocument;


@interface MPCloudOpenWindowController : NSWindowController

/** Mostra i documenti e chiama `chosen` con quello scelto.
 *
 * `service` è quello da cui si parte; la barra laterale porta tutti quelli
 * collegati, quindi la risposta dice **da quale** viene il documento
 * invece di lasciarlo indovinare a chi chiama. Con nil si è chiuso senza
 * scegliere.
 */
+ (void)chooseFrom:(MPCloudService *)service
            chosen:(void (^)(MPCloudService *from,
                             MPCloudDocument *document))chosen;

@end
