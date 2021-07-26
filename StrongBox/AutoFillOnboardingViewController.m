//
//  AutoFillOnboardingViewController.m
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AutoFillOnboardingViewController.h"
#import "AutoFillManager.h"

@implementation AutoFillOnboardingViewController

- (BOOL)shouldAutorotate {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (IBAction)onUseAutoFill:(id)sender {
    self.model.metadata.autoFillEnabled = YES;
    self.model.metadata.autoFillOnboardingDone = YES;
    [SafesList.sharedInstance update:self.model.metadata];

    if( self.model.metadata.quickTypeEnabled ) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.database
                                                           databaseUuid:self.model.metadata.uuid
                                                          displayFormat:self.model.metadata.quickTypeDisplayFormat];
    }
    
    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onNoThankYou:(id)sender {
    self.model.metadata.autoFillEnabled = NO;
    self.model.metadata.autoFillOnboardingDone = YES;
    [SafesList.sharedInstance update:self.model.metadata];
        
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
