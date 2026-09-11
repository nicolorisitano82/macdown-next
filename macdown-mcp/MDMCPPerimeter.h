//
//  MDMCPPerimeter.h
//  macdownext-mcp
//
//  What the server may touch, and what it refuses.
//
//  The part of this worth designing was never the protocol — JSON on two
//  pipes is two hundred lines — but the perimeter: which folders, which
//  files, how big, and what happens to a path that tries to leave. It is
//  here on its own, in functions that take strings and answer, so that the
//  refusals can be tested without a server, a client or a folder.
//

#import <Foundation/Foundation.h>


/// Why a path was refused, which is what the caller is told.
typedef NS_ENUM(NSUInteger, MDMCPVerdict) {
    MDMCPAllowed,
    /// Outside every declared root, or trying to climb out of one.
    MDMCPOutsideTheRoots,
    /// A kind of file this server does not read: an image, an archive, a
    /// binary. Markdown and text only.
    MDMCPNotText,
    /// Inside a folder that is excluded: .git, node_modules, a dot folder.
    MDMCPExcluded,
    /// There, readable, and too big to hand over.
    MDMCPTooBig,
    /// Nothing at that path.
    MDMCPNotThere,
};

/// What the server is allowed to change.
typedef NS_ENUM(NSUInteger, MDMCPWriting) {
    MDMCPReadOnly = 0,
    MDMCPAppendOnly,
    MDMCPFullWriting,
};


/// The folders this server may look in, and the rules it looks with.
@interface MDMCPPerimeter : NSObject

/// Nothing is allowed until the root is declared: there is no default,
/// and there is exactly one — two roots are two ways to get a path wrong.
- (instancetype)initWithRoot:(NSURL *)root;

@property (readonly, copy, nonatomic) NSURL *root;
/// Glob patterns excluded on top of the ones that always are.
@property (copy, nonatomic) NSArray<NSString *> *excluded;
@property (nonatomic) MDMCPWriting writing;
/// Bytes past which a file is refused rather than read. 2 MiB by default.
@property (nonatomic) unsigned long long sizeLimit;

/** Whether that path may be read, and why not when it may not.
 *
 * The path is standardized and its symbolic links resolved *before* it is
 * compared with the roots: a link inside the folder pointing at /etc is a
 * path that leaves, however it is spelled.
 */
- (MDMCPVerdict)verdictForPath:(NSString *)path;

/// The same, as the sentence the caller is given.
+ (NSString *)reasonFor:(MDMCPVerdict)verdict;

/// The file URL for a path a caller gave, or nil when it is refused.
- (NSURL *)urlForPath:(NSString *)path verdict:(MDMCPVerdict *)verdict;

/** Every document under `folder`, or under the root, in a stable order.
 *
 * A `.textbundle` counts as **one** document, not as the three files it
 * holds: that is what it is, and listing its `info.json` would be listing
 * its plumbing.
 */
- (NSArray<NSURL *> *)filesUnder:(NSURL *)folder;

/// The file to read for a document: the text inside a textbundle, or the
/// document itself.
+ (NSURL *)textFileFor:(NSURL *)document;

/// Whether that URL is a textbundle: the extension, and a folder under it.
+ (BOOL)isTextBundle:(NSURL *)url;

/// Whether a name is one of the folders nobody asked to search.
+ (BOOL)isExcludedComponent:(NSString *)component;

@end
