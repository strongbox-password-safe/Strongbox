//
//  QuickLaunchOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "QuickLaunchOnboardingModule.h"
#import "QuickLaunchOnboardingViewController.h"
#import "AppPreferences.h"

@interface QuickLaunchOnboardingModule ()

@property Model* model;

@end

@implementation QuickLaunchOnboardingModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {
        self.model = model;
    }
    return self;
}

- (BOOL)shouldDisplay {
    return (!self.model.metadata.hasBeenPromptedForQuickLaunch && AppPreferences.sharedInstance.quickLaunchUuid == nil );
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"QuickLaunchOnboarding" bundle:nil];
    QuickLaunchOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.onDone = onDone;
    vc.model = self.model;
    
    return vc;
}

@end
