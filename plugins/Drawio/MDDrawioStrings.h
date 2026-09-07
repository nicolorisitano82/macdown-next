//
//  MDDrawioStrings.h
//  Drawio
//
//  The plug-in's strings, read from the plug-in's own bundle.
//
//  NSLocalizedString asks the *main* bundle, which is the application: a
//  plug-in that used it would need MacDown Next to carry the plug-in's
//  translations, which is backwards — the plug-in is the thing being
//  installed. This asks the bundle the plug-in itself came in, so a
//  plug-in ships its own languages and can be written by anyone.
//

#import <Cocoa/Cocoa.h>

/// The bundle this plug-in was loaded from.
extern NSBundle *MDDrawioBundle(void);

#define MDLocalizedString(key, comment) \
    [MDDrawioBundle() localizedStringForKey:(key) value:@"" table:nil]
