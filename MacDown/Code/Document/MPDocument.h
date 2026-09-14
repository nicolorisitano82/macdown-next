//
//  MPDocument.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPPreferences;
@class MPCloudDocument;
@class MPCloudService;


@interface MPDocument : NSDocument


/// Da dove viene, quando viene da un servizio: l'identificatore del
/// documento là fuori e la versione da cui si è partiti. Servono per
/// risalvarlo **lì** invece di farne un secondo, e per accorgersi che nel
/// frattempo qualcun altro ci ha scritto.
@property (copy, nonatomic) NSString *cloudIdentifier;
@property (copy, nonatomic) NSString *cloudRevision;
@property (copy, nonatomic) NSString *cloudService;

/** Lo scrive sul servizio da cui viene, e dice com'è andata.
 *
 * Un documento aperto da una cartella remota si salva **lì**: ⌘S passa da
 * qui invece che dal pannello di salvataggio, perché una cartella collegata
 * deve comportarsi come una cartella, non come un posto da cui si esporta.
 */
- (void)saveToCloudWithCompletion:(void (^)(BOOL done,
                                            NSString *conflict,
                                            NSString *problem))finished;

/** Apre un documento che sta in un servizio, o porta davanti il suo.
 *
 * Una strada sola per le due porte da cui ci si arriva — la finestra dei
 * documenti del servizio e l'elenco nella barra laterale — perché aprire
 * due volte lo stesso documento vorrebbe dire due finestre che si scrivono
 * sopra a vicenda.
 */
+ (void)openRemote:(MPCloudDocument *)remote from:(MPCloudService *)service;
@property (nonatomic, readonly) MPPreferences *preferences;
@property (readonly) BOOL previewVisible;
@property (readonly) BOOL editorVisible;

@property (nonatomic, readwrite) NSString *markdown;
@property (nonatomic, readonly) NSString *html;

@end
