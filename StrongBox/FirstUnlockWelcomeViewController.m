//
//  FirstUnlockWelcomeViewController.m
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "FirstUnlockWelcomeViewController.h"
#import "DatabasePreferences.h"

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
    
    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onNotRightNow:(id)sender {
    self.model.metadata.hasShownInitialOnboardingScreen = YES;
    
    if ( self.onDone ) {
        self.onDone(NO, YES);
    }
}

@end
