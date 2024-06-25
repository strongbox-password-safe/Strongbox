//
//  AutoFIllOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AutoFillOnboardingModule.h"
#import "AutoFillManager.h"
#import "AutoFillOnboardingViewController.h"
#import "NSDate+Extensions.h"

@interface AutoFillOnboardingModule ()

@property Model* model;

@end

@implementation AutoFillOnboardingModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {
        self.model = model;
    }
    return self;
}

- (BOOL)shouldDisplay {




    NSDate* cutoff = [NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2024-01-08"];
    BOOL newish = [self.model.metadata.databaseCreated isLaterThan:cutoff]; 
    
    return !self.model.metadata.autoFillOnboardingDone && !self.model.metadata.autoFillEnabled && AutoFillManager.sharedInstance.isOnForStrongbox && newish;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"AutoFillOnboarding" bundle:nil];
    AutoFillOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.onDone = onDone;
    vc.model = self.model;
    
    return vc;
}

@end
