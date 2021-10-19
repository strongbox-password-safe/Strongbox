//
//  PreferencesWindowController.h
//  Strongbox
//
//  Created by Mark on 03/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PreferencesWindowController : NSWindowController

+ (instancetype)sharedInstance;

- (void)show;
- (void)showFavIconPreferences;
- (void)showPasswordSettings;
- (void)showGeneralSettings;

@end
