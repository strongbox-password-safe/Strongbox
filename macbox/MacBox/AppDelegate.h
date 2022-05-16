//
//  AppDelegate.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <StoreKit/StoreKit.h>
#import "NSArray+Extensions.h"

#define kAutoLockTime @"autoLockTime"

extern const NSInteger kTopLevelMenuItemTagStrongbox;
extern const NSInteger kTopLevelMenuItemTagFile;
extern const NSInteger kTopLevelMenuItemTagView;

extern NSString* const kUpdateNotificationQuickRevealStateChanged;

@interface AppDelegate : NSObject <NSApplicationDelegate, SKProductsRequestDelegate>

- (void)randomlyShowUpgradeMessage;
- (IBAction)onUpgradeToFullVersion:(id)sender;
- (void)showUpgradeModal:(NSInteger)delay;
- (void)clearClipboardWhereAppropriate;

@end

