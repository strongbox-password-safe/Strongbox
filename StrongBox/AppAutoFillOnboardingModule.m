//
//  AppAutoFillOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 01/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AppAutoFillOnboardingModule.h"
#import "TurnOnAutoFillViewController.h"
#import "AutoFillManager.h"
#import "AppPreferences.h"
#import "NSDate+Extensions.h"

@implementation AppAutoFillOnboardingModule

- (nonnull instancetype)initWithModel:(Model * _Nullable)model {
    return [super init];
}

- (BOOL)shouldDisplay {
    if ( !AppPreferences.sharedInstance.promptToEnableAutoFill ) {

        return NO;
    }


    
    if ( AppPreferences.sharedInstance.lastAskToEnableAutoFill != nil ) {
        if ( ![AppPreferences.sharedInstance.lastAskToEnableAutoFill isMoreThanXDaysAgo:2] ) {
            slog(@"Not asking about AutoFill as last asked less than 2 days ago.");
            return NO;
        }
    }
    
    return !AutoFillManager.sharedInstance.isOnForStrongbox;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Welcome" bundle:nil];
    TurnOnAutoFillViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"AutoFill"];
    
    vc.onDone = ^{
        onDone(NO, NO);
    };
    
    return vc;
}

@end
