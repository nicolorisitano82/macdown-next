//
//  MPZipArchive.h
//  MacDown
//
//  Just enough of the zip format to read and write the archives that .docx
//  and .epub files are. Foundation has no zip API, and taking on a library
//  for the handful of entries these formats need would be out of proportion.
//

#import <Foundation/Foundation.h>


@interface MPZipEntry : NSObject
@property (copy) NSString *name;
@property uint16_t method;      // 0 stored, 8 deflated
@property uint32_t crc;
@property (copy) NSData *payload;   // as stored, matching method
@property uint32_t uncompressedSize;
@end


/// Entries in the order they appear, or nil if the archive cannot be read.
NSArray<MPZipEntry *> *MPZipRead(NSData *zip);

/// Writes the entries in the order given, which EPUB depends on: its
/// mimetype entry has to come first, and stored rather than deflated.
NSData *MPZipWrite(NSArray<MPZipEntry *> *entries);

/// An entry holding `data` uncompressed.
MPZipEntry *MPStoredEntry(NSString *name, NSData *data);

/// The bytes of that entry, inflated if it was deflated.
///
/// An archive this application wrote stores everything; one written by
/// somebody else deflates it, and reading theirs is the point of having
/// this separately from -MPStringFromEntry.
NSData *MPDataFromEntry(MPZipEntry *entry);

/// The named entry decoded as UTF-8, or nil if it is not in the archive.
NSString *MPStringFromEntry(NSArray<MPZipEntry *> *entries, NSString *name);
