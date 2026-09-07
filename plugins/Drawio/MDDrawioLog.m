//
//  MDDrawioLog.m
//  MacDown Next — draw.io plug-in
//

#import "MDDrawioLog.h"
#import "MDDrawioStrings.h"


@interface MDDrawioLog ()
@property (strong, nonatomic) NSMutableArray<NSString *> *lines;
@property (strong, nonatomic) NSDate *began;
@property (strong, nonatomic) NSWindow *panel;
@end


@implementation MDDrawioLog

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _lines = [NSMutableArray array];
    _began = [NSDate date];
    return self;
}

- (void)note:(NSString *)line
{
    // Seconds since the start rather than the time of day: what one wants
    // to know from a log of an import is where the twenty seconds went.
    // Never below zero: the clock can hand back a hair of negative when
    // two calls land in the same instant, and "-0.000" reads as a fault.
    NSTimeInterval elapsed = MAX(0.0, -[self.began timeIntervalSinceNow]);
    [self.lines addObject:[NSString stringWithFormat:@"%7.3f  %@",
        elapsed, line ?: @""]];
}

- (void)noteFormat:(NSString *)format, ...
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format
                                            arguments:arguments];
    va_end(arguments);
    [self note:line];
}

- (NSString *)text
{
    return [self.lines componentsJoinedByString:@"\n"];
}

- (void)showOnWindow:(NSWindow *)window
{
    NSRect frame = NSMakeRect(0.0, 0.0, 640.0, 400.0);
    NSWindow *panel = [[NSPanel alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
          backing:NSBackingStoreBuffered defer:NO];
    panel.title = MDLocalizedString(@"Import Log",
                                    @"Title of the log window");
    panel.releasedWhenClosed = NO;

    NSScrollView *scroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0.0, 44.0, frame.size.width,
                                 frame.size.height - 44.0)];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = NO;
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.borderType = NSNoBorder;

    NSTextView *view = [[NSTextView alloc]
        initWithFrame:scroll.contentView.bounds];
    view.editable = NO;
    view.richText = NO;
    view.font = [NSFont monospacedSystemFontOfSize:11.0
                                            weight:NSFontWeightRegular];
    view.string = self.text;
    view.autoresizingMask = NSViewWidthSizable;
    scroll.documentView = view;
    [panel.contentView addSubview:scroll];

    NSButton *copy = [NSButton buttonWithTitle:
        MDLocalizedString(@"Copy", @"Copy the log") target:self
                                        action:@selector(copyLog:)];
    copy.frame = NSMakeRect(frame.size.width - 200.0, 10.0, 88.0, 24.0);
    copy.autoresizingMask = NSViewMinXMargin;
    [panel.contentView addSubview:copy];

    NSButton *close = [NSButton buttonWithTitle:
        MDLocalizedString(@"Close", @"Close the log window") target:self
                                         action:@selector(closeLog:)];
    close.frame = NSMakeRect(frame.size.width - 104.0, 10.0, 88.0, 24.0);
    close.keyEquivalent = @"\r";
    close.autoresizingMask = NSViewMinXMargin;
    [panel.contentView addSubview:close];

    self.panel = panel;
    // A window rather than a sheet: with a sheet the alert underneath
    // cannot be read, and the two together are what one is comparing.
    [panel center];
    [panel makeKeyAndOrderFront:nil];
}

- (void)copyLog:(id)sender
{
    NSPasteboard *board = [NSPasteboard generalPasteboard];
    [board clearContents];
    [board setString:self.text forType:NSPasteboardTypeString];
}

- (void)closeLog:(id)sender
{
    [self.panel close];
    self.panel = nil;
}

@end
