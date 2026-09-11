//
//  MPAgentsPreferencesViewController.h
//  MacDown
//

#import "MPPreferencesViewController.h"
#import <MASPreferences/MASPreferencesViewController.h>


/// The folder an assistant may read: the line to paste into its
/// configuration, the level that line asks for, and what has been done with
/// it so far.
@interface MPAgentsPreferencesViewController : MPPreferencesViewController
    <MASPreferencesViewController>

@end
