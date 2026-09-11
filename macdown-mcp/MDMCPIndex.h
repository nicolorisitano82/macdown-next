//
//  MDMCPIndex.h
//  macdownext-mcp
//
//  The folder, read once and kept in memory.
//
//  Searching a folder by opening every file every time is fine for fifty
//  documents and slow for five thousand, and a server that is asked three
//  questions in a row pays it three times. So the text is kept, and a file
//  is read again only when it has changed — which is a thing the file
//  system already knows and nobody has to write down.
//
//  Nothing is written to disk. An index on disk is a second copy of the
//  truth to keep right, and this project has spent its budget of those.
//

#import <Foundation/Foundation.h>

#import "MDMCPPerimeter.h"


/// One answer: which document, which line, and what it says.
@interface MDMCPHit : NSObject
@property (readonly, copy, nonatomic) NSURL *document;
@property (readonly, nonatomic) NSUInteger line;
@property (readonly, copy, nonatomic) NSString *text;
@end


@interface MDMCPIndex : NSObject

- (instancetype)initWithPerimeter:(MDMCPPerimeter *)perimeter;

/// How many documents it is holding, and how many it read last time it was
/// asked — the second number is what tells a warm index from a cold one.
@property (readonly, nonatomic) NSUInteger documentCount;
@property (readonly, nonatomic) NSUInteger lastReadCount;

/// Brings the index level with the folder: new documents read, changed
/// ones read again, deleted ones forgotten.
- (void)refresh;

/// The lines of every document that carry `query`, in document order.
- (NSArray<MDMCPHit *> *)search:(NSString *)query limit:(NSUInteger)limit
                            cut:(BOOL *)cut;

/// The text of one document, from the index when it is current.
- (NSString *)textOf:(NSURL *)document;

/** Every document with its text, in reading order.
 *
 * A question about the whole folder — who cites this, which notes declare
 * that field — is one pass over the index and not one read per document.
 */
- (void)eachDocument:(void (^)(NSURL *document, NSString *text))block;

@end
