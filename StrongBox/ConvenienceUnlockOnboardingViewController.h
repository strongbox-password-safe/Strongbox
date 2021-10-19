//
//  ConvenienceUnlockOnboardingViewController.h
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OnboardingModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConvenienceUnlockOnboardingViewController : UIViewController

@property OnboardingModuleDoneBlock onDone;
@property (weak) Model* model;

@end

NS_ASSUME_NONNULL_END
