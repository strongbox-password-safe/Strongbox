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

+ (BOOL)run:(SKProduct*)product cancelDelay:(NSInteger)cancelDelay;

@property (weak) IBOutlet NSButton *buttonNoThanks;
@property (weak) IBOutlet NSButton *buttonUpgrade;
@property (weak) IBOutlet NSButton *buttonRestore;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (unsafe_unretained) IBOutlet NSTextView *textViewDetails;

@end
