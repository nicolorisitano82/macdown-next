//
//  MPPlugIn.h
//  MacDown
//
//  Created by Tzu-ping Chung on 02/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPDOcument.h"
#import "MPExporterPlugIn.h"

@interface MPPlugIn : NSObject

@property (nonatomic, readonly) NSString *name;
/// The bundle identifier, or the file name when the bundle declares none.
/// Used to remember which plug-ins have been switched off.
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *version;
@property (nonatomic, readonly) NSURL *bundleURL;
/// Whether it ships inside the application rather than being installed.
@property (nonatomic, readonly) BOOL isBuiltIn;

/** Whether it adds a format to File ▸ Export rather than a command.
 *
 * An exporter is a format and not something to pick and watch happen, so it
 * stays out of the plug-ins menu — it would sit there doing nothing until a
 * save panel it never opened came back. See MPExporterPlugIn.
 */
@property (nonatomic, readonly) BOOL isExporter;

/** Whether it has already given itself a place in the menus.
 *
 * The plug-ins menu is where a plug-in goes when it has nowhere better.
 * One that imports a document belongs next to the one that exports it, in
 * File, and once it is there the entry under Plug-ins is the same command
 * written twice — which is also two places to look when it misbehaves. A
 * plug-in says so by answering `-placesItsOwnMenuItem` with YES; it stays
 * in the plug-in manager, where it can still be switched off.
 */
@property (nonatomic, readonly) BOOL placesItsOwnMenuItem;

/// What the format is called, for an exporter; nil for anything else.
- (NSString *)exportFormatName;
/// The extension its files get, without the dot.
- (NSString *)exportFileExtension;
/// A word about the format for the save panel, or nil.
- (NSString *)exportFormatDescription;

/// The bytes of the exported file, or nil with `error` set.
- (NSData *)exportDataFromHTML:(NSString *)html
                      markdown:(NSString *)markdown
                       fileURL:(NSURL *)fileURL
                         error:(NSError **)error;

- (instancetype)initWithBundle:(NSBundle *)bundle;

/// The same thing around an object that is already there, which is how a
/// test gets hold of a plug-in without a bundle to load.
- (instancetype)initWithContent:(id)content name:(NSString *)name
                     identifier:(NSString *)identifier;
- (BOOL)run:(id)sender;

- (void)plugInDidInitialize;

@end
