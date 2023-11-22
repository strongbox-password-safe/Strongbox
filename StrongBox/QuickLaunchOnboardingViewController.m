//
//  QuickLaunchOnboardingViewController.m
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "QuickLaunchOnboardingViewController.h"
#import "AppPreferences.h"
#import "DatabasePreferences.h"

@implementation QuickLaunchOnboardingViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (IBAction)onUseQuickLaunch:(id)sender {
    AppPreferences.sharedInstance.quickLaunchUuid = self.model.metadata.uuid;
    AppPreferences.sharedInstance.autoFillQuickLaunchUuid = self.model.metadata.uuid;

    self.model.metadata.hasBeenPromptedForQuickLaunch = YES;

    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onNoThankYou:(id)sender {
    self.model.metadata.hasBeenPromptedForQuickLaunch = YES;

    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onDismiss:(id)sender {
    if ( self.onDone ) {
        self.onDone(NO, YES);
    }
}

@end
