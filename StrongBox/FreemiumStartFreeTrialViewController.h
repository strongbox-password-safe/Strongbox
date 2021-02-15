//
//  FreemiumStartFreeTrialViewController.h
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FreemiumStartFreeTrialViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL purchasedOrRestoredFreeTrial);

@end

NS_ASSUME_NONNULL_END
