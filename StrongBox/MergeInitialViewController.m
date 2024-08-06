//
//  MergeInitialViewController.m
//  Strongbox
//
//  Created by Mark on 07/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MergeInitialViewController.h"
#import "Alerts.h"
#import "MergeSelectSecondDatabaseViewController.h"
#import "IOSCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DuressActionHelper.h"

@implementation MergeInitialViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (IBAction)onUnlock:(id)sender {
    IOSCompositeKeyDeterminer* determiner = [IOSCompositeKeyDeterminer determinerWithViewController:self 
                                                                                           database:self.firstMetadata
                                                                                     isAutoFillOpen:NO
                                                         transparentAutoFillBackgroundForBiometrics:NO
                                                                                biometricPreCleared:NO
                                                                                noConvenienceUnlock:NO];
    [determiner getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if (result == kGetCompositeKeyResultSuccess) {
            DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:self.firstMetadata viewController:self forceReadOnly:NO isNativeAutoFillAppExtensionOpen:NO offlineMode:YES];
            [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {




                    [self onUnlockDone:result model:model error:error];

            }];
        }
        else if (result == kGetCompositeKeyResultError) {
            [self displayError:error];
        }
        else if (result == kGetCompositeKeyResultDuressIndicated) {
            [DuressActionHelper performDuressAction:self database:self.firstMetadata isAutoFillOpen:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                [self onUnlockDone:result model:model error:error];
            }];
        }
        else {
            [self onCancel:nil];
        }
    }];
}

- (void)onUnlockDone:(UnlockDatabaseResult)result model:(Model * _Nullable)model error:(NSError * _Nullable)error {
    if(result == kUnlockDatabaseResultSuccess) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToSelectSecondDatabase" sender:model];
        });
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        [self onCancel:nil];
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        
        slog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
    }
    else if (result == kUnlockDatabaseResultError) {
        [self displayError:error];
    }
}

- (void)displayError:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Alerts error:self
                title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                error:error];
    });
}

- (IBAction)onCancel:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onDone(NO, nil, nil);
    });
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToSelectSecondDatabase"]) {
        MergeSelectSecondDatabaseViewController* vc = segue.destinationViewController;
        
        vc.firstDatabase = sender;
        vc.onDone = self.onDone;
    }
}

@end
