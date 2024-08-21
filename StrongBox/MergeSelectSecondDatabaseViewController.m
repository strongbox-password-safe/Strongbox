//
//  MergeSelectSecondDatabaseViewController.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MergeSelectSecondDatabaseViewController.h"
#import "SelectDatabaseViewController.h"
#import "Alerts.h"
#import "SelectComparisonTypeViewController.h"
#import "IOSCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DuressActionHelper.h"
#import "NSDate+Extensions.h"

@implementation MergeSelectSecondDatabaseViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}



- (IBAction)onSelectSecond:(id)sender {
    [self performSegueWithIdentifier:@"segueToShowMergeSecondDatabasesList" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToShowMergeSecondDatabasesList"]) {
        UINavigationController *nav = segue.destinationViewController;
        SelectDatabaseViewController* vc = (SelectDatabaseViewController*)nav.topViewController;
        vc.disableDatabaseUuid = self.firstDatabase.metadata.uuid;
        
        __weak MergeSelectSecondDatabaseViewController* weakSelf = self;
        vc.onSelectedDatabase = ^(DatabasePreferences * _Nonnull secondDatabase, UIViewController *__weak  _Nonnull vcToDismiss) {
            [vcToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if ( secondDatabase ) {
                    [weakSelf onSecondDatabaseSelected:secondDatabase];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectComparisonType"]) {
        SelectComparisonTypeViewController* vc = segue.destinationViewController;
        vc.firstDatabase = self.firstDatabase;
        vc.secondDatabase = sender;
        vc.onDone = self.onDone;
    }
}

- (void)onSecondDatabaseSelected:(DatabasePreferences * _Nonnull)secondDatabase {
    if ( [NSDate isMoreThanXMinutesAgo:secondDatabase.lastSyncAttempt minutes:3] ||
         [NSDate isMoreThanXMinutesAgo:self.firstDatabase.metadata.lastSyncAttempt minutes:3] ) {
        [Alerts info:self
               title:NSLocalizedString(@"compare_merge_sync_possibly_required_title", @"Sync Possibly Required")
             message:NSLocalizedString(@"compare_merge_sync_possibly_required_message", @"One or both of these databases hasn't been sync'd very recently. It is recommended that you return to the Home screen and pull down to initiate the Sync process. This will ensure you are working with the latest versions.")
          completion:^{
            [self unlockSecondDatabase:secondDatabase];
        }];
    }
    else {
        [self unlockSecondDatabase:secondDatabase];
    }
}

- (void)unlockSecondDatabase:(DatabasePreferences*)database {
    CompositeKeyFactors* firstKey = self.firstDatabase.database.ckfs;

    Model* expressAttempt = [DatabaseUnlocker expressTryUnlockWithKey:database key:firstKey];
    if ( expressAttempt ) {
        slog(@"YAY - Express Unlocked Second DB with same CKFs! No need to re-request CKFs...");
        [self onUnlockDone:kUnlockDatabaseResultSuccess model:expressAttempt error:nil];
    }
    else {
        IOSCompositeKeyDeterminer* determiner = [IOSCompositeKeyDeterminer determinerWithViewController:self 
                                                                                               database:database
                                                                                         isAutoFillOpen:NO
                                                             transparentAutoFillBackgroundForBiometrics:NO
                                                                                    biometricPreCleared:NO
                                                                                    noConvenienceUnlock:NO];
        
        [determiner getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
            if (result == kGetCompositeKeyResultSuccess) {
                DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:database viewController:self forceReadOnly:NO isNativeAutoFillAppExtensionOpen:NO offlineMode:YES];
                [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {




                        [self onUnlockDone:result model:model error:error];

                }];
            }
            else if (result == kGetCompositeKeyResultError) {
                [self displayError:error];
            }
            else if (result == kGetCompositeKeyResultDuressIndicated) {
                [DuressActionHelper performDuressAction:self database:database isAutoFillOpen:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                    [self onUnlockDone:result model:model error:error];
                }];
            }
            else {
                self.onDone(NO, nil, nil);
            }
        }];
    }
}

- (void)onUnlockDone:(UnlockDatabaseResult)result model:(Model * _Nullable)model error:(NSError * _Nullable)error {
    if(result == kUnlockDatabaseResultSuccess) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToSelectComparisonType" sender:model];
        });
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        self.onDone(NO, nil, nil);
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
    [self dismiss];
}

- (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
