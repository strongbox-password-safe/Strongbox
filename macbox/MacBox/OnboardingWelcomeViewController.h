//
//  OnboardingWelcomeViewController.h
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface OnboardingWelcomeViewController : NSViewController

@property (nonatomic, copy) void (^onNext)(BOOL userCancelled, BOOL enableTouchID, BOOL enableAutoFill);

@property BOOL showTouchID;
@property BOOL showAutoFill;
@property BOOL enableAutoFill;

@end

NS_ASSUME_NONNULL_END
