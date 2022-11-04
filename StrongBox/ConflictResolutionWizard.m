//
//  ConflictResolutionWizard.m
//  Strongbox
//
//  Created by Strongbox on 05/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ConflictResolutionWizard.h"
#import <UIKit/UIKit.h>
#import "RoundedBlueButton.h"
#import "AppPreferences.h"
#import "NSDate+Extensions.h"
#import "Alerts.h"

@interface ConflictResolutionWizard ()

@property (weak, nonatomic) IBOutlet UILabel *labelLocalMod;
@property (weak, nonatomic) IBOutlet UILabel *labelRemoteMod;
@property (weak, nonatomic) IBOutlet UILabel *labelRemoteLocation;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonCompare;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonSyncLater;

@end

@implementation ConflictResolutionWizard

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = YES;
    
    BOOL pro = AppPreferences.sharedInstance.isPro;
    self.buttonCompare.enabled = pro;


    if (!pro) {
        [self.buttonCompare setTitle:NSLocalizedString(@"conflict_resolution_compare_pro_only", @"Compare & Merge (Pro)") forState:UIControlStateNormal];
        self.buttonCompare.backgroundColor = UIColor.systemGrayColor;

    }
    
    self.labelLocalMod.text = self.localModDate.friendlyDateTimeStringPrecise;
    self.labelRemoteMod.text = self.remoteModified.friendlyDateTimeStringPrecise;
    self.labelRemoteLocation.text = [NSString stringWithFormat:NSLocalizedString(@"conflict_resolution_remote_fmt", @"Remote (%@)"), self.remoteStorage];
}

- (IBAction)onAutoMerge:(id)sender {
    self.completion(kConflictWizardResultAutoMerge);
}

- (IBAction)onAlwaysAutoMerge:(id)sender {
    self.completion(kConflictWizardResultAlwaysAutoMerge);
}

- (IBAction)onCompare:(id)sender {
    self.completion(kConflictWizardResultCompare);
}

- (IBAction)onSyncLater:(id)sender {
    self.completion(kConflictWizardResultSyncLater);
}

- (IBAction)onForce:(id)sender {
    [Alerts twoOptionsWithCancel:self
                           title:NSLocalizedString(@"conflict_resolution_force_overwrite_title", @"Force Overwrite?")
                         message:NSLocalizedString(@"conflict_resolution_force_overwrite_message", @"You can overwrite changes in either your local copy or in the remote copy.")
               defaultButtonText:NSLocalizedString(@"conflict_resolution_force_overwrite_take_remote", @"Take Remote Copy, Overwrite Local")
                secondButtonText:NSLocalizedString(@"conflict_resolution_force_overwrite_keep_lacal", @"Keep Local Copy, Overwrite Remote")
                          action:^(int response) {
        if (response == 0) {
            self.completion(kConflictWizardResultForcePullRemote);
        }
        else if (response == 1) {
            self.completion(kConflictWizardResultForcePushLocal);
        }
    }];
}

- (IBAction)onCancel:(id)sender {
    self.completion(kConflictWizardCancel);
}

@end
