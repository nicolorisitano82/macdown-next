//
//  MPCloudOpenWindowController.h
//  MacDown
//
//  L'elenco dei documenti che stanno nel servizio collegato, e il modo di
//  aprirne uno.
//
//  Piccolo di proposito: un nome, quando è cambiato, e due pulsanti. Non è
//  un gestore di file — quello ce l'ha già il servizio, nel browser — è il
//  ponte fra «ho collegato una cartella» e «ci lavoro».
//

#import <Cocoa/Cocoa.h>

@class MPCloudService;
@class MPCloudDocument;


@interface MPCloudOpenWindowController : NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate>

/// Mostra i documenti di `service` e chiama `chosen` con quello scelto, o
/// con nil se si è chiuso senza scegliere.
+ (void)chooseFrom:(MPCloudService *)service
            chosen:(void (^)(MPCloudDocument *document))chosen;

@end
