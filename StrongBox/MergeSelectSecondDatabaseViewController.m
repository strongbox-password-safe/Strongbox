//
//  MergeSelectSecondDatabaseViewController.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "MergeSelectSecondDatabaseViewController.h"
#import "SecondDatabaseListTableViewController.h"
#import "ShowMergeDiffTableViewController.h"
#import "OpenSafeSequenceHelper.h"
#import "Alerts.h"

@interface MergeSelectSecondDatabaseViewController ()

@end

@implementation MergeSelectSecondDatabaseViewController

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

- (IBAction)onUnlockSecond:(id)sender {
    [self performSegueWithIdentifier:@"segueToShowMergeSecondDatabasesList" sender:nil];
}

- (IBAction)onCancel:(id)sender {
    [self dismiss];
}

- (void)dismiss {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)unlockSecondDatabase:(SafeMetaData*)database {
    [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                       safe:database
                                        canConvenienceEnrol:NO
                                             isAutoFillOpen:NO
                                              openLocalOnly:NO
                                                 completion:^(UnlockDatabaseResult result, Model * _Nullable model, const NSError * _Nullable error) {
        if(result == kUnlockDatabaseResultSuccess) {
            [self performSegueWithIdentifier:@"segueToDiffDatabases" sender:model];
        }
        else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
            self.onDone(YES);
        }
        else if (result == kUnlockDatabaseResultError) {
            [Alerts error:self
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
        }
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToShowMergeSecondDatabasesList"]) {
        UINavigationController *nav = segue.destinationViewController;
        SecondDatabaseListTableViewController* vc = (SecondDatabaseListTableViewController*)nav.topViewController;
        vc.firstDatabase = self.firstDatabase;
        vc.onSelectedDatabase = ^(SafeMetaData * _Nonnull secondDatabase) {
            [self dismissViewControllerAnimated:YES completion:^{
                [self unlockSecondDatabase:secondDatabase];
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToDiffDatabases"]) {
        ShowMergeDiffTableViewController* vc = segue.destinationViewController;
        vc.firstDatabase = self.firstDatabase;
        vc.secondDatabase = sender;
        vc.onDone = self.onDone;
    }
}

@end
