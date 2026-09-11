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
    /// Asked to make a file that is already there. Nothing is written over.
    MDMCPAlreadyThere,
    /// The folder that path would go in does not exist, and this server
    /// does not make folders.
    MDMCPNoFolder,
    /// A change asked of a server that was not started with the level for
    /// it: read-only cannot append, append-only cannot create or replace.
    MDMCPNotAllowedToChange,
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

/** The file URL for a path that is meant not to exist yet.
 *
 * Same perimeter as reading — inside the root, not excluded, a text
 * extension — and then the two things that only matter when making a file:
 * there must be nothing there already, and the folder it would go in must
 * exist. This server does not make folders: a typo in a path would
 * otherwise leave one behind, and nothing here removes anything.
 */
- (NSURL *)urlForNewPath:(NSString *)path verdict:(MDMCPVerdict *)verdict;

/// Whether the level this server was started at covers that change.
- (BOOL)allowsWriting:(MDMCPWriting)needed;

/** Every document under `folder`, or under the root, in a stable order.
 *
 * A `.textbundle` counts as **one** document, not as the three files it
 * holds: that is what it is, and listing its `info.json` would be listing
 * its plumbing.
 */
- (NSArray<NSURL *> *)filesUnder:(NSURL *)folder;

/** A path as the caller should see it: relative to the root.
 *
 * Nothing in an answer says where this Mac keeps its home folder, and the
 * comparison is made on paths standardized the way the root was — a root
 * under /private and a file the enumerator hands back with the /private
 * still on it are the same place, and used to come back missing their
 * folder.
 */
- (NSString *)relativePathFor:(NSURL *)url;

/// The file to read for a document: the text inside a textbundle, or the
/// document itself.
+ (NSURL *)textFileFor:(NSURL *)document;

/// Whether that URL is a textbundle: the extension, and a folder under it.
+ (BOOL)isTextBundle:(NSURL *)url;

/// Whether a name is one of the folders nobody asked to search.
+ (BOOL)isExcludedComponent:(NSString *)component;

@end
