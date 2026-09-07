//
//  MPPlugInController.m
//  MacDown
//
//  Created by Tzu-ping Chung on 02/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import "NSString+Lookup.h"
#import "MPPlugIn.h"
#import "MPPlugInController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"
#import "MPPlugInsWindowController.h"


@implementation MPPlugInController

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    id q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(q, ^{
        NSArray *disabled = [MPPreferences sharedInstance].disabledPlugIns;
        for (MPPlugIn *plugin in [self buildPlugIns])
        {
            // A plug-in that is switched off should not get to run code at
            // launch either, which is half the point of switching it off.
            if ([disabled containsObject:plugin.identifier])
                continue;
            [plugin plugInDidInitialize];
        }
    });
    return self;
}


#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    [menu removeAllItems];

    // First, and always present: without it a plug-in folder is something
    // you have to know about to find.
    NSMenuItem *manage = [menu addItemWithTitle:
        NSLocalizedString(@"Manage Plug-ins…", @"Opens the plug-in manager")
                                         action:@selector(showPlugInManager:)
                                  keyEquivalent:@""];
    manage.target = self;
    [menu addItem:[NSMenuItem separatorItem]];

    NSArray *disabled = [MPPreferences sharedInstance].disabledPlugIns;
    NSUInteger shown = 0;
    for (MPPlugIn *plugin in [self buildPlugIns])
    {
        if ([disabled containsObject:plugin.identifier])
            continue;
        // An exporter is a format rather than a command: it belongs in
        // File ▸ Export, and here it would be an item that opens a save
        // panel out of a menu of things that act on the document now.
        if (plugin.isExporter)
            continue;
        NSMenuItem *item = [menu addItemWithTitle:plugin.name
                                           action:@selector(invokePlugIn:)
                                    keyEquivalent:@""];
        item.target = self;
        item.representedObject = plugin;
        shown++;
    }

    // An empty menu below the separator reads as broken, so say what is
    // going on instead.
    if (!shown)
    {
        NSMenuItem *none = [menu addItemWithTitle:
            NSLocalizedString(@"No plug-in is active",
                              @"Shown when every plug-in is off or absent")
                                           action:NULL keyEquivalent:@""];
        none.enabled = NO;
    }
}

+ (NSArray<MPPlugIn *> *)enabledExporters
{
    NSArray *disabled = [MPPreferences sharedInstance].disabledPlugIns;
    NSMutableArray<MPPlugIn *> *exporters = [NSMutableArray array];
    for (NSURL *url in MPPlugInBundleURLs())
    {
        MPPlugIn *plugin = [[MPPlugIn alloc]
            initWithBundle:[NSBundle bundleWithURL:url]];
        if (!plugin || !plugin.isExporter
            || [disabled containsObject:plugin.identifier])
            continue;
        // A format with no extension has nowhere to write to; better absent
        // than in the menu doing nothing.
        if (!plugin.exportFileExtension.length)
            continue;
        [exporters addObject:plugin];
    }
    return [exporters copy];
}

- (void)showPlugInManager:(id)sender
{
    [[MPPlugInsWindowController sharedController] showPanel:sender];
}


#pragma mark - Private

- (void)invokePlugIn:(NSMenuItem *)item
{
    MPPlugIn *plugin = item.representedObject;
    if (![plugin run:item])
        NSLog(@"Failed to run plugin %@", plugin.name);
}

- (NSArray<MPPlugIn *> *)buildPlugIns
{
    NSArray *urls = MPPlugInBundleURLs();
    NSMutableArray *plugins = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSURL *url in urls)
    {
        NSBundle *bundle = [NSBundle bundleWithURL:url];
        MPPlugIn *plugin = [[MPPlugIn alloc] initWithBundle:bundle];
        if (!plugin)
            continue;
        [plugins addObject:plugin];
    }
    return [plugins copy];
}

@end
