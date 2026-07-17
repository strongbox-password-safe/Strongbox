//
//  FreeTrialOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 01/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "FreeTrialOnboardingModule.h"
#import "FreeTrialOnboardingViewController.h"
#import "AppPreferences.h"
#import "ProUpgradeIAPManager.h"
#import "Strongbox-Swift.h"

@implementation FreeTrialOnboardingModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {

    }
    return self;
}

- (BOOL)shouldDisplay {
    if ( AppPreferences.sharedInstance.isPro ) {
        return NO;
    }

    if ( !ProUpgradeIAPManager.sharedInstance.isFreeTrialAvailable ) {
        return NO;
    }
         
    if ( AppPreferences.sharedInstance.freeTrialNudgeCount == 0 ) { 
        return YES;
    }

    NSUInteger kProNudgeIntervalDays = 7; 
    if ( AppPreferences.sharedInstance.freeTrialNudgeCount < 3 ) { 
        kProNudgeIntervalDays = 1;
    }
    
    NSDate* dueDate = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay
                                                             value:kProNudgeIntervalDays
                                                            toDate:AppPreferences.sharedInstance.lastFreeTrialNudge
                                                           options:kNilOptions];
    
    slog(@"Nudge Due: [%@] - Nudge Count: [%lu]", dueDate, (unsigned long)AppPreferences.sharedInstance.freeTrialNudgeCount);
    
    BOOL nudgeDue = dueDate.timeIntervalSinceNow < 0; 

    return nudgeDue;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    #ifdef SUBSCRIPTIONS
    SuperwallOnboardingViewController* vc = [SuperwallOnboardingViewController makeOnDone:^{
        
        onDone(NO, NO);
    }];

    AppPreferences.sharedInstance.freeTrialNudgeCount++;
    AppPreferences.sharedInstance.lastFreeTrialNudge = NSDate.date;

    return vc;
    #else
    UIViewController* vc = [UIViewController init];
    return vc;
    #endif
}

@end
