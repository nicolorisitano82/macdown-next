//
//  MDMCPTools.h
//  macdownext-mcp
//
//  What a reader can ask of a folder: search it, read a file, list what is
//  there, see the shape of a document — and, since phase two, who cites a
//  document, what its front matter declares, and which documents declare a
//  field.
//
//  The last three are not written here: citations come from MPBacklinks and
//  the front matter from NSString+Lookup, the same code the application
//  runs, so that a document cannot be cited in the editor and uncited over
//  the wire.
//
//  Each answers a dictionary ready to be turned into JSON, and each is a
//  function of a perimeter and its arguments — no server, no protocol, no
//  state. What the protocol adds is the envelope.
//

#import <Foundation/Foundation.h>

#import "MDMCPIndex.h"
#import "MDMCPPerimeter.h"


@interface MDMCPTools : NSObject

- (instancetype)initWithPerimeter:(MDMCPPerimeter *)perimeter;

@property (readonly, nonatomic) MDMCPPerimeter *perimeter;
@property (readonly, nonatomic) MDMCPIndex *index;

/// What the server says it can do, as MCP wants it described.
- (NSArray<NSDictionary *> *)declarations;

/** Runs one tool.
 *
 * `error` is filled with the sentence the caller is given when the answer
 * is no — a path outside the folder, a file that is not text, a tool that
 * does not exist. Answering nil is always explained.
 */
- (NSDictionary *)run:(NSString *)tool
            arguments:(NSDictionary *)arguments
                error:(NSString **)error;

@end


/// The headings of a Markdown text, with the line each one is on.
///
/// Fences are skipped, because `# not a heading` inside a code block is
/// code. Separate from the tool so that it can be tested on a string.
extern NSArray<NSDictionary *> *MDMCPOutlineOfMarkdown(NSString *text);
