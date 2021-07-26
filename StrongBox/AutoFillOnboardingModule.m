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
    return !self.model.metadata.autoFillOnboardingDone && !self.model.metadata.autoFillEnabled && AutoFillManager.sharedInstance.isOnForStrongbox;
}

- (nonnull UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"AutoFillOnboarding" bundle:nil];
    AutoFillOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.onDone = onDone;
    vc.model = self.model;
    
    return vc;
}

@end
