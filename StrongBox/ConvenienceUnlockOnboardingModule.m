//
//  ConvenienceUnlockOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ConvenienceUnlockOnboardingModule.h"
#import "AppPreferences.h"
#import "BiometricsManager.h"
#import "ConvenienceUnlockOnboardingViewController.h"

@interface ConvenienceUnlockOnboardingModule ()

@property Model* model;

@end

@implementation ConvenienceUnlockOnboardingModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {
        self.model = model;
    }
    return self;
}

- (BOOL)shouldDisplay {
    return !self.model.metadata.hasBeenPromptedForConvenience && AppPreferences.sharedInstance.isPro;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"ConvenienceUnlockOnboardingModule" bundle:nil];
    ConvenienceUnlockOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.onDone = onDone;
    vc.model = self.model;
    
    return vc;
}

@end
