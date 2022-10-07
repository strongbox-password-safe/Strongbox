//
//  AppDelegate.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kAutoLockTime @"autoLockTime"

extern const NSInteger kTopLevelMenuItemTagStrongbox;
extern const NSInteger kTopLevelMenuItemTagFile;
extern const NSInteger kTopLevelMenuItemTagView;

extern NSString* const kUpdateNotificationQuickRevealStateChanged;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)onUpgradeToFullVersion:(id)sender;



- (void)clearClipboardWhereAppropriate;
- (void)onStrongboxDidChangeClipboard; 

@end

