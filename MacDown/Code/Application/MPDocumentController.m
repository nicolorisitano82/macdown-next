//
//  MPDocumentController.m
//  MacDown
//

#import "MPDocumentController.h"

#import "MPActionLog.h"
#import "MPTextBundle.h"


@implementation MPDocumentController

- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)display
                    completionHandler:(void (^)(NSDocument *, BOOL,
                                                NSError *))completion
{
    NSURL *inside = [self documentInsideContainerAt:url error:NULL];
    if (inside)
    {
        MPNote(@"opening %@ from %@", inside.lastPathComponent,
               url.lastPathComponent);
        [super openDocumentWithContentsOfURL:inside display:display
                           completionHandler:completion];
        return;
    }
    [super openDocumentWithContentsOfURL:url display:display
                       completionHandler:completion];
}


/** The text file to open for a container, or nil for anything else.
 *
 * A textpack is unpacked into the folder it sits in rather than into a
 * temporary one: a document opened from a temporary folder is a document
 * whose next save goes somewhere nobody will look again.
 */
- (NSURL *)documentInsideContainerAt:(NSURL *)url error:(NSError **)error
{
    if (MPIsTextBundle(url))
    {
        NSURL *text = MPTextBundleTextURL(url);
        if (!text)
        {
            MPNote(@"  no text in %@", url.lastPathComponent);
            [self sayCannotOpen:url because:NSLocalizedString(
                @"This Textbundle holds no text",
                @"A .textbundle with no text.markdown in it")];
        }
        return text;
    }
    if (!MPIsTextPack(url))
        return nil;

    NSError *unpacking = nil;
    NSURL *bundle = MPUnpackTextPack(
        url, url.URLByDeletingLastPathComponent, &unpacking);
    if (!bundle)
    {
        MPNote(@"  not unpacked: %@", unpacking.localizedDescription);
        [self sayCannotOpen:url because:unpacking.localizedDescription];
        return nil;
    }
    MPNote(@"unpacked %@ into %@", url.lastPathComponent,
           bundle.lastPathComponent);
    return MPTextBundleTextURL(bundle);
}


/// Why a container did not open, said where the reader is looking.
- (void)sayCannotOpen:(NSURL *)url because:(NSString *)reason
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(
        @"“%@” could not be opened", @"A container that is not one"),
        url.lastPathComponent];
    alert.informativeText = reason ?: @"";
    [alert runModal];
}

@end
