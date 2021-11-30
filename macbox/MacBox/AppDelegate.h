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

extern NSString* const kStrongboxPasteboardName;
extern NSString* const kDragAndDropInternalUti;
extern NSString* const kDragAndDropExternalUti;

extern const NSInteger kTopLevelMenuItemTagStrongbox;
extern const NSInteger kTopLevelMenuItemTagFile;
extern const NSInteger kTopLevelMenuItemTagView;

@interface AppDelegate : NSObject <NSApplicationDelegate, SKProductsRequestDelegate>

- (void)randomlyShowUpgradeMessage;
- (void)showUpgradeModal:(NSInteger)delay;
- (void)clearClipboardWhereAppropriate;

@end

