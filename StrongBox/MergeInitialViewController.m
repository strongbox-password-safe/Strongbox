//
//  MergeInitialViewController.m
//  Strongbox
//
//  Created by Mark on 07/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "MergeInitialViewController.h"
#import "OpenSafeSequenceHelper.h"
#import "Alerts.h"

@interface MergeInitialViewController ()

@end

@implementation MergeInitialViewController

- (BOOL)shouldAutorotate {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
        return YES; /* Device is iPad */
    }
    else {
        return NO;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
        return UIInterfaceOrientationMaskAll; /* Device is iPad */
    }
    else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (IBAction)onUnlock:(id)sender {
    [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                       safe:self.destinationDatabase
                                        canConvenienceEnrol:NO
                                             isAutoFillOpen:NO
                                              openLocalOnly:NO
                                                 completion:^(UnlockDatabaseResult result, Model * _Nullable model, const NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultError ) {
            [Alerts error:self error:error];
            [self dismiss];
        }
        else if ( result == kUnlockDatabaseResultSuccess ) {
            [Alerts info:self title:@"Yo!" message:@"Bar"];
            
        }
        else {
            [self dismiss];
        }
    }];
}

- (IBAction)onCancel:(id)sender {
    [self dismiss];
}

- (void)dismiss {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
