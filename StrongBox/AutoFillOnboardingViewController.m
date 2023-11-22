//
//  AutoFillOnboardingViewController.m
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AutoFillOnboardingViewController.h"
#import "AutoFillManager.h"
#import "DatabasePreferences.h"

@implementation AutoFillOnboardingViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (IBAction)onUseAutoFill:(id)sender {
    self.model.metadata.autoFillEnabled = YES;
    self.model.metadata.autoFillOnboardingDone = YES;

    if( self.model.metadata.quickTypeEnabled ) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model clearFirst:NO];
    }
    
    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onNoThankYou:(id)sender {
    self.model.metadata.autoFillEnabled = NO;
    self.model.metadata.autoFillOnboardingDone = YES;
        
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
