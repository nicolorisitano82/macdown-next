//
//  MDMCPServer.h
//  macdownext-mcp
//
//  The envelope: JSON-RPC 2.0, one object per line, on standard input and
//  output. What a client sends and what it gets back, with nothing in
//  between that knows about files.
//

#import <Foundation/Foundation.h>

#import "MDMCPTools.h"


/// The version of the protocol this speaks when the client does not say.
extern NSString * const MDMCPProtocolVersion;


@interface MDMCPServer : NSObject

- (instancetype)initWithTools:(MDMCPTools *)tools;

/** The answer to one request, or nil for a notification.
 *
 * A function of the message, so that every exchange in the protocol can be
 * tested by handing it a line and reading the line that comes back —
 * without a pipe, a client, or a process.
 */
- (NSDictionary *)answerTo:(NSDictionary *)message;

/// Reads lines from `input` and writes answers to `output` until the end.
- (void)runReading:(NSFileHandle *)input writing:(NSFileHandle *)output;

@end
