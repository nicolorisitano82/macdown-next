//
//  main.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MPDocumentController.h"

int main(int argc, const char * argv[])
{
    // NSDocumentController's shared instance is whichever one exists first,
    // and after that it cannot be replaced. Ours opens the two containers —
    // .textbundle and .textpack — by opening the text inside them, so it
    // has to be here rather than in a nib that loads later.
    (void)[[MPDocumentController alloc] init];
    return NSApplicationMain(argc, argv);
}
