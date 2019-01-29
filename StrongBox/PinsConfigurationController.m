//
//  PinsConfigurationController.m
//  Strongbox-iOS
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PinsConfigurationController.h"
#import "PinEntryController.h"
#import "Alerts.h"
#import "Settings.h"

@interface PinsConfigurationController ()

@end

@implementation PinsConfigurationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = [UIView new];
    
    [self bindUiToModel];
}

- (void)bindUiToModel {
    if(self.viewModel.metadata.conveniencePin != nil) {
        [self.buttonPinOnOff setTitle:@"Turn Convenience PIN Off" forState:UIControlStateNormal];
        self.buttonChangePin.enabled = YES;
        self.buttonDuressPinOnOff.enabled = YES;
        self.buttonChangeDuressPin.enabled = YES;
    }
    else {
        [self.buttonPinOnOff setTitle:@"Turn Convenience PIN On" forState:UIControlStateNormal];
        self.buttonChangePin.enabled = NO;
        self.buttonDuressPinOnOff.enabled = NO;
        self.buttonChangeDuressPin.enabled = NO;
    }
    
    if(self.viewModel.metadata.duressPin != nil && self.viewModel.metadata.conveniencePin != nil) {
        [self.buttonDuressPinOnOff setTitle:@"Turn Duress PIN Off" forState:UIControlStateNormal];
        self.buttonChangeDuressPin.enabled = YES;

        self.cellDuressActionOpenDummy.userInteractionEnabled = YES;
        self.cellDuressActionOpenDummy.textLabel.enabled = YES;
        self.cellDuressActionTechnicalError.userInteractionEnabled = YES;
        self.cellDuressActionTechnicalError.textLabel.enabled = YES;
        self.cellDuressActionRemoveDatabase.userInteractionEnabled = YES;
        self.cellDuressActionRemoveDatabase.textLabel.enabled = YES;
    }
    else {
        [self.buttonDuressPinOnOff setTitle:@"Turn Duress PIN On" forState:UIControlStateNormal];
        self.buttonChangeDuressPin.enabled = NO;
        
        self.cellDuressActionOpenDummy.userInteractionEnabled = NO;
        self.cellDuressActionOpenDummy.textLabel.enabled = NO;
        self.cellDuressActionTechnicalError.userInteractionEnabled = NO;
        self.cellDuressActionTechnicalError.textLabel.enabled = NO;
        self.cellDuressActionRemoveDatabase.userInteractionEnabled = NO;
        self.cellDuressActionRemoveDatabase.textLabel.enabled = NO;
    }
    
    self.cellDuressActionTechnicalError.accessoryType = UITableViewCellAccessoryNone;
    self.cellDuressActionRemoveDatabase.accessoryType = UITableViewCellAccessoryNone;
    self.cellDuressActionOpenDummy.accessoryType = UITableViewCellAccessoryNone;
    
    if(self.viewModel.metadata.duressAction == kOpenDummy) {
        self.cellDuressActionOpenDummy.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else if(self.viewModel.metadata.duressAction == kRemoveDatabase) {
        self.cellDuressActionRemoveDatabase.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else if(self.viewModel.metadata.duressAction == kPresentError) {
        self.cellDuressActionTechnicalError.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    if(self.viewModel.metadata.storageProvider == kLocalDevice) {
        self.labelRemoveDatabase.text = @"Delete Database";
        self.labelRemoveDatabaseWarning.text = @"Local Device database will be permanently deleted.";
        self.labelRemoveDatabaseWarning.textColor = [UIColor redColor];
    }
    else if(self.viewModel.metadata.storageProvider == kLocalDevice) {
        self.labelRemoveDatabase.text = @"Delete Database";
        self.labelRemoveDatabaseWarning.text = @"iCloud Device database will be permanently deleted from iCloud.";
        self.labelRemoveDatabaseWarning.textColor = [UIColor redColor];
    }
    else {
        self.labelRemoveDatabase.text = @"Remove Database from Strongbox";
        self.labelRemoveDatabaseWarning.text = @"NB: Database file will remain on remote storage.";
        self.labelRemoveDatabaseWarning.textColor = [UIColor orangeColor];
    }
    
    if(!Settings.sharedInstance.isProOrFreeTrial) {
        self.buttonPinOnOff.enabled = NO;
        self.buttonChangePin.enabled = NO;
        self.buttonDuressPinOnOff.enabled = NO;
        self.buttonChangeDuressPin.enabled = NO;
        
        self.cellDuressActionOpenDummy.userInteractionEnabled = NO;
        self.cellDuressActionOpenDummy.textLabel.enabled = NO;
        self.cellDuressActionTechnicalError.userInteractionEnabled = NO;
        self.cellDuressActionTechnicalError.textLabel.enabled = NO;
        self.cellDuressActionRemoveDatabase.userInteractionEnabled = NO;
        self.cellDuressActionRemoveDatabase.textLabel.enabled = NO;
    }
    
    if(!Settings.sharedInstance.isPro) {
        if (@available(iOS 11.0, *)) {
            self.navigationController.navigationBar.prefersLargeTitles = NO;
        }
        self.title = @"PIN Codes (Pro Feature Only)";
    }
}

- (IBAction)onPinOnOff:(id)sender {
    if(self.viewModel.metadata.conveniencePin != nil) {
        NSString *message = self.viewModel.metadata.isEnrolledForConvenience && !self.viewModel.metadata.isTouchIdEnabled ?
            @"Turning the PIN Off for this safe will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?" :
            @"Are you sure you want to turn off the PIN for this safe?";
        
        [Alerts yesNo:self
                title:@"Turn off PIN?"
              message:message
               action:^(BOOL response) {
                   if (response) {
                       self.viewModel.metadata.conveniencePin = nil;
                       
                       if(!self.viewModel.metadata.isTouchIdEnabled) {
                           self.viewModel.metadata.isEnrolledForConvenience = NO;
                           self.viewModel.metadata.convenienceMasterPassword = nil;
                           self.viewModel.metadata.convenenienceKeyFileDigest = nil;
                       }
                       
                       [[SafesList sharedInstance] update:self.viewModel.metadata];
                       [self bindUiToModel];
                   }
               }];
    }
    else {
        [self getNewPin:NO];
    }
}

- (IBAction)onChangePin:(id)sender {
    [self getNewPin:NO];
}

- (IBAction)onDuressPinOnOff:(id)sender {
    if(self.viewModel.metadata.duressPin != nil) {
        self.viewModel.metadata.duressPin = nil;
        [[SafesList sharedInstance] update:self.viewModel.metadata];
        [self bindUiToModel];
    }
    else {
        [self getNewPin:YES];
    }
}

- (IBAction)onChangeDuressPin:(id)sender {
    [self getNewPin:YES];
}

- (void)getNewPin:(BOOL)duressPin {
    PinEntryController *vc1 = [[PinEntryController alloc] init];
    vc1.info = duressPin ? @"Please Enter a new Duress PIN" : @"Please Enter a new PIN";
    vc1.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                NSString* otherPin = duressPin ? self.viewModel.metadata.conveniencePin : self.viewModel.metadata.duressPin;
                
                if(!(otherPin != nil && [pin isEqualToString:otherPin])) {
                    if(duressPin) {
                        self.viewModel.metadata.duressPin = pin;
                    } else {
                        self.viewModel.metadata.conveniencePin = pin;
                        self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.masterPassword;
                        self.viewModel.metadata.convenenienceKeyFileDigest = self.viewModel.database.keyFileDigest;
                        self.viewModel.metadata.isEnrolledForConvenience = YES;
                    }
                    
                    [[SafesList sharedInstance] update:self.viewModel.metadata];
                    [self bindUiToModel];
                }
                else {
                    [Alerts warn:self title:@"PIN Conflict" message:@"Your Convenience PIN conflicts with your Duress PIN. Please select another."];
                }
            }
            else {
                [Alerts warn:self title:@"PINs do not match" message:@"Your PINs do not match. Please try again."];
            }}];
    };
    
    [self presentViewController:vc1 animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 2) {
        if(indexPath.row == 0) {
            self.viewModel.metadata.duressAction = kOpenDummy;
        }
        else if (indexPath.row == 1) {
            self.viewModel.metadata.duressAction = kPresentError;
        }
        else if (indexPath.row == 2) {
            BOOL delete = self.viewModel.metadata.storageProvider == kLocalDevice || self.viewModel.metadata.storageProvider == kiCloud;
            
            [Alerts warn:self title:@"Warning" message:delete ? @"This will permanently delete the safe file." : @"This will remove the safe from Strongbox but the underlying file will remain on cloud storage"];
            self.viewModel.metadata.duressAction = kRemoveDatabase;
        }

        [[SafesList sharedInstance] update:self.viewModel.metadata];
        [self bindUiToModel];
    }
}

@end
