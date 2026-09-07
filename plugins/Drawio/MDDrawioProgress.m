//
//  MDDrawioProgress.m
//  MacDown Next — draw.io plug-in
//

#import "MDDrawioProgress.h"
#import "MDDrawioStrings.h"


@interface MDDrawioProgress ()
@property (strong, nonatomic) NSWindow *panel;
@property (weak, nonatomic) NSWindow *host;
@property (strong, nonatomic) NSTextField *label;
@property (strong, nonatomic) NSTextField *detail;
@property (strong, nonatomic) NSProgressIndicator *bar;
@property (nonatomic, readwrite) BOOL isCancelled;
@end


@implementation MDDrawioProgress

- (void)showOnWindow:(NSWindow *)window title:(NSString *)title
{
    NSRect frame = NSMakeRect(0.0, 0.0, 420.0, 128.0);
    NSWindow *panel = [[NSPanel alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled
          backing:NSBackingStoreBuffered defer:NO];
    panel.title = title ?: @"";

    NSView *content = panel.contentView;

    _label = [NSTextField labelWithString:title ?: @""];
    _label.font = [NSFont boldSystemFontOfSize:
        [NSFont systemFontSize]];
    _label.frame = NSMakeRect(20.0, 92.0, 380.0, 20.0);
    [content addSubview:_label];

    _detail = [NSTextField labelWithString:@""];
    _detail.textColor = [NSColor secondaryLabelColor];
    _detail.font = [NSFont systemFontOfSize:
        [NSFont smallSystemFontSize]];
    _detail.frame = NSMakeRect(20.0, 68.0, 380.0, 18.0);
    [content addSubview:_detail];

    _bar = [[NSProgressIndicator alloc]
        initWithFrame:NSMakeRect(20.0, 44.0, 380.0, 20.0)];
    _bar.style = NSProgressIndicatorStyleBar;
    _bar.indeterminate = YES;
    [_bar startAnimation:nil];
    [content addSubview:_bar];

    NSButton *stop = [NSButton buttonWithTitle:
        MDLocalizedString(@"Cancel", @"Stop the import") target:self
                                        action:@selector(cancel:)];
    stop.frame = NSMakeRect(312.0, 12.0, 88.0, 24.0);
    stop.keyEquivalent = @"\033";   // Escape, which is what one presses
    [content addSubview:stop];

    self.panel = panel;
    self.host = window;

    if (window)
        [window beginSheet:panel completionHandler:nil];
    else
        [panel makeKeyAndOrderFront:nil];
}

- (void)showPage:(NSUInteger)index of:(NSUInteger)count
            named:(NSString *)name
{
    // Determinate only when there is more than one page: a bar that fills
    // once says less than one that is plainly busy.
    if (count > 1)
    {
        self.bar.indeterminate = NO;
        self.bar.minValue = 0.0;
        self.bar.maxValue = (double)count;
        self.bar.doubleValue = (double)(index - 1);
        self.label.stringValue = [NSString stringWithFormat:
            MDLocalizedString(@"Drawing page %lu of %lu",
                              @"Which page of how many is being drawn"),
            (unsigned long)index,
            (unsigned long)count];
    }
    else
    {
        self.label.stringValue = MDLocalizedString(
            @"Drawing the diagram", @"One page, so no page number");
    }
    self.detail.stringValue = name.length ? name : @"";

    // The drawing happens on this thread, in a web view: without a turn of
    // the run loop the text above would change only when it was all over.
    [self.panel displayIfNeeded];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate date]];
}

- (void)cancel:(id)sender
{
    self.isCancelled = YES;
    self.detail.stringValue = MDLocalizedString(
        @"Stopping…", @"The import was asked to stop");
}

- (void)finish
{
    if (self.host)
        [self.host endSheet:self.panel];
    else
        [self.panel orderOut:nil];
    self.panel = nil;
}

@end
