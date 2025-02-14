//
//  WelcomeFreemiumViewController.h
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"
#import "OnboardingModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface FreeTrialOnboardingViewController : UIViewController

@property (nullable) OnboardingModuleDoneBlock onDone;

@end

NS_ASSUME_NONNULL_END
