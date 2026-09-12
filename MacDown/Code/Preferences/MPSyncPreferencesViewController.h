//
//  MPSyncPreferencesViewController.h
//  MacDown
//

#import "MPPreferencesViewController.h"
#import <MASPreferences/MASPreferencesViewController.h>


/// Il collegamento a Google Drive: le credenziali che ognuno si porta, e
/// la cartella che ha dato all'applicazione.
@interface MPSyncPreferencesViewController : MPPreferencesViewController
    <MASPreferencesViewController, NSTextFieldDelegate>

@end
