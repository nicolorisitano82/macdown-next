//
//  MDMCPDiary.h
//  macdownext-mcp
//
//  What was asked of the folder, and what happened.
//
//  Not telemetry: a file on this Mac, beside the other logs, that nothing
//  sends anywhere. It exists for the question that gets asked the day
//  after a session with an assistant — *who touched this file, and when* —
//  which the files themselves cannot answer once they have been changed.
//
//  Separate from the application's action log on purpose: that one is a
//  diagnostic recording somebody switches on, and this one is the record of
//  what an agent did, which is worth having whether or not anybody expected
//  to need it.
//

#import <Foundation/Foundation.h>


@interface MDMCPDiary : NSObject

/// Writes to `file`. A diary with no file writes nothing and costs nothing,
/// which is what `--no-log` gives.
- (instancetype)initWithFile:(NSURL *)file;

/// ~/Library/Logs/MacDown Next/mcp.log — beside the application's own, and
/// where the Console looks.
+ (NSURL *)standardFile;

@property (readonly, copy, nonatomic) NSURL *file;

/** One line: when, which tool, how it went, on what, and how much.
 *
 * `path` and `detail` may be nil; a refusal carries its reason as the
 * detail, because a refusal nobody can explain the day after is a refusal
 * that gets argued about.
 */
- (void)noteTool:(NSString *)tool
         outcome:(NSString *)outcome
            path:(NSString *)path
          detail:(NSString *)detail;

@end
