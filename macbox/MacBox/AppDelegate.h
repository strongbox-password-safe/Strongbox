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
#define kPreferencesChangedNotification @"preferencesChangedNotification"

@interface AppDelegate : NSObject <NSApplicationDelegate, SKProductsRequestDelegate>

- (void)showUpgradeModal:(NSInteger)delay;
- (void)clearClipboardIfChangeCountMatches;

@end

