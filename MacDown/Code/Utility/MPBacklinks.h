//
//  MPBacklinks.h
//  MacDown
//

#import <Foundation/Foundation.h>


/// One place where a document is cited: which file, which line, what it says.
@interface MPBacklink : NSObject

/// The document that does the citing.
@property (readonly, copy, nonatomic) NSURL *documentURL;
/// Its first heading, or its file name when it has none.
@property (readonly, copy, nonatomic) NSString *title;
/// Where in that document, counting lines from one.
@property (readonly, nonatomic) NSUInteger line;
/// The line as written, trimmed — the point is to recognise the sentence.
@property (readonly, copy, nonatomic) NSString *context;
/// The link itself, for going to it once that document is open.
@property (readonly, nonatomic) NSRange range;

- (instancetype)initWithDocumentURL:(NSURL *)documentURL
                              title:(NSString *)title
                               line:(NSUInteger)line
                            context:(NSString *)context
                              range:(NSRange)range;
@end


/** Every reference to `target` in `text`, which is the file at `from`.
 *
 * Both kinds count, because both are how a document gets cited here: a
 * `[[WikiLink]]`, with or without a label, and a Markdown link or image
 * whose destination resolves to the same file. Destinations are resolved
 * against the citing document's own folder, so `../verbali/x.md` from a
 * subfolder is the same file as `x.md` from beside it, and a destination
 * written with `%20` for its spaces is the same file as one without.
 *
 * What is inside code is not a citation: a fenced block explaining how to
 * write a link is not a link.
 */
extern NSArray<MPBacklink *> *MPBacklinksInText(NSString *text,
                                               NSURL *from,
                                               NSURL *target);

/// The document's own first heading, or nil when it has none.
extern NSString *MPFirstHeadingOfText(NSString *text);


/** Looks through a folder for the documents that cite one.
 *
 * The whole tree under the folder, since a set of notes that cite each
 * other is rarely one flat directory — but not the places that are nobody's
 * documents: anything hidden, and the bundles that only look like folders.
 */
@interface MPBacklinkFinder : NSObject

/// `done` is called on the main queue, with what was found in reading order.
+ (void)findLinksTo:(NSURL *)target
           inFolder:(NSURL *)folder
         completion:(void (^)(NSArray<MPBacklink *> *found,
                              NSUInteger documentsRead))done;

/// The extensions taken for documents worth reading.
+ (NSArray<NSString *> *)readableExtensions;

@end
