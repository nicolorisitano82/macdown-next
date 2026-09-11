//
//  MDMCPServer.m
//  macdownext-mcp
//

#import "MDMCPServer.h"


NSString * const MDMCPProtocolVersion = @"2025-06-18";

/// The revisions this server knows how to be. A client asking for one of
/// them is answered in its own version; one asking for anything else is
/// answered in ours, which is what the specification says to do.
static NSSet<NSString *> *MDKnownVersions(void)
{
    static NSSet *versions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        versions = [NSSet setWithArray:@[@"2024-11-05", @"2025-03-26",
                                         @"2025-06-18"]];
    });
    return versions;
}


@interface MDMCPServer ()
@property (nonatomic) MDMCPTools *tools;
@end


@implementation MDMCPServer

- (instancetype)initWithTools:(MDMCPTools *)tools
{
    self = [super init];
    if (self)
        _tools = tools;
    return self;
}


#pragma mark - One message at a time

- (NSDictionary *)answerTo:(NSDictionary *)message
{
    if (![message isKindOfClass:[NSDictionary class]])
        return [self failure:nil code:-32700 saying:@"that was not JSON"];

    id identifier = message[@"id"];
    NSString *method = message[@"method"];
    if (![method isKindOfClass:[NSString class]])
        return [self failure:identifier code:-32600
                      saying:@"a message needs a method"];

    // A notification has no id, and gets no answer — including the
    // "initialized" one every client sends after the handshake.
    BOOL wantsAnswer = identifier != nil && identifier != [NSNull null];

    if ([method isEqualToString:@"initialize"])
    {
        NSString *asked = message[@"params"][@"protocolVersion"];
        NSString *version = [MDKnownVersions() containsObject:asked]
            ? asked : MDMCPProtocolVersion;
        return [self result:@{
            @"protocolVersion": version,
            @"capabilities": @{@"tools": @{@"listChanged": @NO}},
            @"serverInfo": @{@"name": @"macdownext-mcp",
                             @"title": @"MacDown Next",
                             @"version": @"1"},
            @"instructions": @"Reads a folder of Markdown documents: search "
                             @"it, read a file, list what is there, see a "
                             @"document's headings, who cites a document, "
                             @"what its front matter declares, and which "
                             @"documents declare a field. It never leaves "
                             @"the folder it was given and it changes "
                             @"nothing."
        } for:identifier];
    }

    if ([method isEqualToString:@"ping"])
        return wantsAnswer ? [self result:@{} for:identifier] : nil;

    if ([method hasPrefix:@"notifications/"])
        return nil;

    if ([method isEqualToString:@"tools/list"])
        return [self result:@{@"tools": [self.tools declarations]}
                        for:identifier];

    if ([method isEqualToString:@"tools/call"])
    {
        NSDictionary *params = message[@"params"];
        NSString *name = params[@"name"];
        NSDictionary *arguments = params[@"arguments"];
        if (![name isKindOfClass:[NSString class]])
            return [self failure:identifier code:-32602
                          saying:@"a call needs the name of a tool"];
        if (![arguments isKindOfClass:[NSDictionary class]])
            arguments = @{};

        NSString *refusal = nil;
        NSDictionary *answer = [self.tools run:name arguments:arguments
                                         error:&refusal];
        if (!answer)
        {
            // A tool that says no is not a protocol error: the client is
            // told inside the result, which is what lets a model read the
            // reason and try something else.
            return [self result:@{
                @"content": @[@{@"type": @"text",
                                @"text": refusal ?: @"no"}],
                @"isError": @YES} for:identifier];
        }
        NSString *text = [self json:answer];
        return [self result:@{
            @"content": @[@{@"type": @"text", @"text": text}],
            @"structuredContent": answer} for:identifier];
    }

    if (!wantsAnswer)
        return nil;
    return [self failure:identifier code:-32601
                  saying:[NSString stringWithFormat:
                      @"this server has no method called %@", method]];
}


- (NSDictionary *)result:(NSDictionary *)result for:(id)identifier
{
    if (!identifier)
        return nil;
    return @{@"jsonrpc": @"2.0", @"id": identifier, @"result": result};
}


- (NSDictionary *)failure:(id)identifier code:(NSInteger)code
                   saying:(NSString *)message
{
    return @{@"jsonrpc": @"2.0", @"id": identifier ?: [NSNull null],
             @"error": @{@"code": @(code), @"message": message}};
}


- (NSString *)json:(id)object
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
        options:NSJSONWritingSortedKeys | NSJSONWritingWithoutEscapingSlashes
          error:NULL];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
        ?: @"{}";
}


#pragma mark - The two pipes

- (void)runReading:(NSFileHandle *)input writing:(NSFileHandle *)output
{
    NSMutableData *buffer = [NSMutableData data];
    while (YES)
    {
        @autoreleasepool {
            NSData *chunk = [input availableData];
            if (!chunk.length)
                break;              // the client closed the pipe
            [buffer appendData:chunk];

            // One JSON object per line, which is what stdio transports do.
            NSRange newline;
            while ((newline = [buffer rangeOfData:
                        [@"\n" dataUsingEncoding:NSUTF8StringEncoding]
                    options:0 range:NSMakeRange(0, buffer.length)]).location
                   != NSNotFound)
            {
                NSData *line = [buffer subdataWithRange:
                    NSMakeRange(0, newline.location)];
                [buffer replaceBytesInRange:
                    NSMakeRange(0, NSMaxRange(newline)) withBytes:NULL
                                     length:0];
                if (!line.length)
                    continue;

                id message = [NSJSONSerialization JSONObjectWithData:line
                    options:0 error:NULL];
                NSDictionary *answer = [self answerTo:message];
                if (!answer)
                    continue;
                NSString *text = [[self json:answer]
                    stringByAppendingString:@"\n"];
                [output writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
}

@end
