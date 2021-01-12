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
#import "MergeSelectSecondDatabaseViewController.h"

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
                                                       safe:self.firstMetadata
                                        canConvenienceEnrol:NO
                                             isAutoFillOpen:NO
                                              openLocalOnly:NO
                                                 completion:^(UnlockDatabaseResult result, Model * _Nullable model, const NSError * _Nullable error) {
        if(result == kUnlockDatabaseResultSuccess) {
            [self performSegueWithIdentifier:@"segueToSelectSecondDatabase" sender:model];
        }
        else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
            self.onDone();
        }
        else if (result == kUnlockDatabaseResultError) {
            [Alerts error:self
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
        }
    }];
}

- (IBAction)onCancel:(id)sender {
    self.onDone();
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToSelectSecondDatabase"]) {
        MergeSelectSecondDatabaseViewController* vc = segue.destinationViewController;
        
        vc.firstDatabase = sender;
        vc.onDone = self.onDone;
    }
}

@end
