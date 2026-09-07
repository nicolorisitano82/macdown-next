//
//  MDQuickLookStrings.h
//  MacDownQuickLook
//
//  The extension's strings, read from the extension's own bundle.
//
//  NSLocalizedString asks the main bundle. For an extension the main bundle
//  is the extension, which would work — but only by accident of where the
//  code runs, and the same file is read by the control suite's harness,
//  where the main bundle is a command line tool. Asking by class is true in
//  both places.
//

#import <Foundation/Foundation.h>

/// The bundle this extension was loaded from.
extern NSBundle *MDQuickLookBundle(void);

#define MDQLLocalizedString(key, comment) \
    [MDQuickLookBundle() localizedStringForKey:(key) value:@"" table:nil]
