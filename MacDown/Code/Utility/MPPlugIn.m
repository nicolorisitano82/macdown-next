//
//  MPPlugIn.m
//  MacDown
//
//  Created by Tzu-ping Chung on 02/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import "MPPlugIn.h"


@interface MPPlugIn ()
@property (nonatomic) id content;
@end


@implementation MPPlugIn

- (void)setName:(NSString *)name
{
    _name = name;
}

- (void)setIdentifier:(NSString *)identifier
{
    _identifier = identifier;
}

- (void)setVersion:(NSString *)version
{
    _version = version;
}

- (void)setBundleURL:(NSURL *)bundleURL
{
    _bundleURL = bundleURL;
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (!self)
        return nil;

    if (!bundle.isLoaded)
    {
        NSError *e = nil;
        BOOL ok = [bundle loadAndReturnError:&e];
        if (!ok)
            return nil;
    }
    Class plugInClass = bundle.principalClass;
    if (!plugInClass)
        return nil;
    self.content = [[plugInClass alloc] init];

    if ([self.content respondsToSelector:@selector(name)])
        self.name = [self.content name];
    if (!self.name)
    {
        NSURL *url = bundle.bundleURL;
        self.name = url.lastPathComponent.stringByDeletingPathExtension;
    }

    self.bundleURL = bundle.bundleURL;
    NSString *inside = [NSBundle mainBundle].builtInPlugInsURL.path;
    _isBuiltIn = inside.length
        && [bundle.bundleURL.path hasPrefix:inside];
    self.version = bundle.infoDictionary[@"CFBundleShortVersionString"];

    // The identifier is what the disabled list is keyed on, so it has to
    // exist even for a bundle that declares none: the file name is stable
    // enough, and is what such a plug-in is called in the menu anyway.
    NSString *identifier = bundle.bundleIdentifier;
    if (!identifier.length)
    {
        identifier = bundle.bundleURL.lastPathComponent
            .stringByDeletingPathExtension;
    }
    self.identifier = identifier;

    return self;
}

- (instancetype)initWithContent:(id)content name:(NSString *)name
                     identifier:(NSString *)identifier
{
    self = [super init];
    if (!self)
        return nil;
    self.content = content;
    self.name = name;
    self.identifier = identifier;
    return self;
}


- (BOOL)placesItsOwnMenuItem
{
    if (![self.content respondsToSelector:@selector(placesItsOwnMenuItem)])
        return NO;
    return [self.content placesItsOwnMenuItem];
}


#pragma mark - Exporting

- (BOOL)isExporter
{
    return [self.content conformsToProtocol:@protocol(MPExporterPlugIn)];
}

- (NSString *)exportFormatName
{
    if (![self isExporter])
        return nil;
    NSString *name = [self.content exportFormatName];
    // A format with no name of its own is still a format; the plug-in's
    // name is a better label than an empty menu item.
    return name.length ? name : self.name;
}

- (NSString *)exportFileExtension
{
    if (![self isExporter])
        return nil;
    NSString *extension = [self.content exportFileExtension];
    return extension.length ? extension : nil;
}

- (NSString *)exportFormatDescription
{
    if (![self isExporter]
        || ![self.content respondsToSelector:@selector(exportFormatDescription)])
        return nil;
    return [self.content exportFormatDescription];
}

- (NSData *)exportDataFromHTML:(NSString *)html
                      markdown:(NSString *)markdown
                       fileURL:(NSURL *)fileURL
                         error:(NSError **)error
{
    if (![self isExporter])
        return nil;
    return [self.content exportDataFromHTML:html markdown:markdown
                                    fileURL:fileURL error:error];
}


- (void)plugInDidInitialize
{
    if ([self.content respondsToSelector:@selector(plugInDidInitialize)])
        [self.content plugInDidInitialize];
}

- (BOOL)run:(id)sender
{
    if ([self.content respondsToSelector:@selector(run:)])
        return [self.content run:sender];
    return NO;
}

@end
