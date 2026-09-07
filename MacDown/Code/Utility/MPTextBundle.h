//
//  MPTextBundle.h
//  MacDown
//
//  Textbundle and Textpack: the document and its pictures, together.
//
//  A `.textbundle` is a folder Finder shows as one item — `info.json`, the
//  Markdown as `text.markdown`, and the pictures under `assets/`. A
//  `.textpack` is that folder inside a zip, which is what travels through
//  mail. The format is somebody else's, on purpose: Bear, Ulysses, iA
//  Writer and Marked read it, and a container only this application
//  understood would be a worse container however well made.
//
//  What comes out of here still works if it is taken apart by hand: the
//  Markdown is Markdown, the pictures are files, and the links between them
//  are relative. `info.json` says who wrote it and what kind of text it is;
//  nothing depends on reading it.
//

#import <Cocoa/Cocoa.h>


/// A picture that has to travel with the text.
@interface MPTextBundleAsset : NSObject
/// Where the picture is now.
@property (readonly, copy, nonatomic) NSURL *fileURL;
/// What it is called inside `assets/`.
@property (readonly, copy, nonatomic) NSString *name;
@end


/** The document rewritten to point at `assets/`, and the pictures it needs.
 *
 * A picture kept beside the document — or under it, or above it — becomes
 * `assets/<name>`; a name already taken gets a number after it, because two
 * folders can both hold a `rete.png`. The same file used twice is one
 * asset, and pictures inside code are not pictures.
 *
 * A remote address is left exactly as it is. A textbundle is a document
 * with its pictures, not an archive of the web, and a reader who wants
 * those has the preference for it on the way in.
 *
 * `assets` comes back through the pointer, in the order the pictures are
 * first written, or empty.
 */
extern NSString *MPTextBundleMarkdown(
    NSString *markdown, NSURL *documentURL,
    NSArray<MPTextBundleAsset *> * __autoreleasing *assets);

/// The remote addresses in the markdown that stay addresses, in order.
///
/// Told apart from the rest so that an export can say what it could not
/// bring with it: "five pictures are missing" tells a reader nothing they
/// can act on.
extern NSArray<NSString *> *MPTextBundleRemoteImages(NSString *markdown);

/** `info.json`, as version 2 of the format asks for it.
 *
 * `type` is the text's own UTI rather than the bundle's, which is what the
 * specification means by it, and `transient` says whether this is a
 * hand-off from a share sheet — it never is, here.
 */
extern NSData *MPTextBundleInfo(NSString *creatorIdentifier,
                                NSString *creatorURL);

/// The whole thing as a `.textpack`: the bundle folder inside a zip.
///
/// `bundleName` is the folder's name inside the archive, extension and all,
/// because a textpack that unzips to a bare `assets/` is not a textbundle.
extern NSData *MPTextPackData(NSString *bundleName, NSString *markdown,
                              NSData *info,
                              NSArray<MPTextBundleAsset *> *assets);

/// Writes the folder form, pictures and all.
extern BOOL MPWriteTextBundle(NSURL *bundleURL, NSString *markdown,
                              NSData *info,
                              NSArray<MPTextBundleAsset *> *assets,
                              NSError **error);


#pragma mark - Reading one

/// Whether that URL is a textbundle: the extension, and a folder under it.
extern BOOL MPIsTextBundle(NSURL *url);

/// Whether that URL is a textpack, which is a textbundle in a zip.
extern BOOL MPIsTextPack(NSURL *url);

/** The text file inside a textbundle, or nil if there is none.
 *
 * The specification says `text.` and an extension that matches the type,
 * and the extension in the wild is `.markdown` or `.md`; anything called
 * `text.something` is taken rather than refused, since the type is in
 * `info.json` and one text file is all a bundle has.
 */
extern NSURL *MPTextBundleTextURL(NSURL *bundleURL);

/** Unpacks a textpack into `folder`, and answers the bundle it made.
 *
 * The name comes from the archive's own root folder, which is what a
 * textpack is: one `.textbundle` and everything under it. A name already
 * taken gets a number, because unpacking twice must not overwrite what was
 * unpacked the first time.
 *
 * Entry names are checked before anything is written: an absolute path or a
 * `..` in an archive is somebody trying to write outside the folder they
 * were given, and the whole archive is refused rather than partly unpacked.
 */
extern NSURL *MPUnpackTextPack(NSURL *packURL, NSURL *folder,
                               NSError **error);
