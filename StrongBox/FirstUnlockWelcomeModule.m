//
//  FirstUnlockWelcomeModule.m
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "FirstUnlockWelcomeModule.h"
#import "FirstUnlockWelcomeViewController.h"

@interface FirstUnlockWelcomeModule ()

@property Model* model;

@end

@implementation FirstUnlockWelcomeModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {
        self.model = model;
    }
    return self;
}

- (BOOL)shouldDisplay {
    BOOL alreadyShown = self.model.metadata.hasShownInitialOnboardingScreen;
    return !alreadyShown;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"FirstUnlockWelcomeView" bundle:nil];
    FirstUnlockWelcomeViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.onDone = onDone;
    vc.model = self.model;
    
    return vc;
}

@end
