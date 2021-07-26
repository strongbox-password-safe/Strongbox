//
//  UpgradeToProOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 05/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "UpgradeToProOnboardingModule.h"
#import "AppPreferences.h"
#import "UpgradeViewController.h"

@implementation UpgradeToProOnboardingModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {

    }
    return self;
}

- (BOOL)shouldDisplay {
    if( AppPreferences.sharedInstance.isProOrFreeTrial || ![self userHasAlreadyTriedAppForMoreThan90Days] ) {
        return NO;
    }

    const NSUInteger percentageChanceOfShowing = 2;
    NSInteger random = arc4random_uniform(100);

    return (random < percentageChanceOfShowing);
}

- (nonnull UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Upgrade" bundle:nil];
    UpgradeViewController* vc = [storyboard instantiateInitialViewController];

    if (@available(iOS 13.0, *)) {
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        vc.modalInPresentation = YES;
    }

    vc.onDone = ^{
        onDone(NO, NO);
    };
    
    return vc;
}

- (BOOL)userHasAlreadyTriedAppForMoreThan90Days {
    return (AppPreferences.sharedInstance.freeTrialHasBeenOptedInAndExpired || AppPreferences.sharedInstance.daysInstalled > 90);
}

@end
