//
//  FirstUnlockWelcomeViewController.m
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "FirstUnlockWelcomeViewController.h"
#import "SafesList.h"

@interface FirstUnlockWelcomeViewController ()

@end

@implementation FirstUnlockWelcomeViewController

- (BOOL)shouldAutorotate {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (IBAction)onLetsGo:(id)sender {
    self.model.metadata.hasShownInitialOnboardingScreen = YES;
    [SafesList.sharedInstance update:self.model.metadata];
    
    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onNotRightNow:(id)sender {
    self.model.metadata.hasShownInitialOnboardingScreen = YES;
    [SafesList.sharedInstance update:self.model.metadata];

    if ( self.onDone ) {
        self.onDone(NO, YES);
    }
}

@end
