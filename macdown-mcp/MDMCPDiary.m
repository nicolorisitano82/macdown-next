//
//  MDMCPDiary.m
//  macdownext-mcp
//

#import "MDMCPDiary.h"


/// Big enough for a long session, small enough to read and to send. Past
/// it the file starts again rather than rotating: what is wanted is the
/// last session, not last month's.
static const unsigned long long kMDDiaryLimit = 2 * 1024 * 1024;


/// Columns, so that a person reading the file can follow one of them down
/// the page. Nothing is cut: a long path pushes its line out rather than
/// losing the end of itself, which is the half that says which file.
static NSString *MDMCPPadded(NSString *text, NSUInteger width)
{
    if (text.length >= width)
        return text;
    return [text stringByPaddingToLength:width withString:@" "
                    startingAtIndex:0];
}


@interface MDMCPDiary ()
@property (copy, nonatomic) NSURL *file;
@property (strong, nonatomic) NSFileHandle *handle;
@property (strong, nonatomic) NSISO8601DateFormatter *clock;
@end


@implementation MDMCPDiary

- (instancetype)initWithFile:(NSURL *)file
{
    self = [super init];
    if (self)
    {
        _file = file;
        _clock = [[NSISO8601DateFormatter alloc] init];
    }
    return self;
}


+ (NSURL *)standardFile
{
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(
        NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *folder = [libraries.firstObject
        stringByAppendingPathComponent:@"Logs/MacDown Next"];
    return [NSURL fileURLWithPath:
        [folder stringByAppendingPathComponent:@"mcp.log"]];
}


- (void)noteTool:(NSString *)tool
         outcome:(NSString *)outcome
            path:(NSString *)path
          detail:(NSString *)detail
{
    if (!self.file || !tool.length)
        return;

    NSString *line = [NSString stringWithFormat:@"%@  %@ %@ %@ %@\n",
        [self.clock stringFromDate:[NSDate date]],
        MDMCPPadded(tool, 14), MDMCPPadded(outcome, 8),
        MDMCPPadded(path.length ? path : @"-", 36), detail ?: @""];
    [[self openHandle] writeData:
        [line dataUsingEncoding:NSUTF8StringEncoding]];
}


/// The file, opened at the end, made if it is not there. A diary that
/// cannot be written to is not an error the caller should hear about: the
/// answer they asked for is still an answer.
- (NSFileHandle *)openHandle
{
    if (self.handle)
        return self.handle;

    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:self.file.URLByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:NULL];
    if (![manager fileExistsAtPath:self.file.path])
        [manager createFileAtPath:self.file.path contents:nil attributes:nil];

    self.handle = [NSFileHandle fileHandleForWritingAtPath:self.file.path];
    [self.handle seekToEndOfFile];
    if ([self.handle offsetInFile] > kMDDiaryLimit)
    {
        [self.handle truncateFileAtOffset:0];
        [self.handle seekToEndOfFile];
    }
    return self.handle;
}

@end
