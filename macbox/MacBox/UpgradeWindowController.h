//
//  UpgradeWindowController.h
//  MacBox
//
//  Created by Mark on 22/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <StoreKit/StoreKit.h>

@interface UpgradeWindowController : NSWindowController<SKPaymentTransactionObserver>

+ (void)show:(NSInteger)cancelDelay;

@end
