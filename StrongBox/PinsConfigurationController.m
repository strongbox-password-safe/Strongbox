//
//  PinsConfigurationController.m
//  Strongbox-iOS
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PinsConfigurationController.h"
#import "PinEntryController.h"
#import "Alerts.h"
#import "AppPreferences.h"
#import "DatabasePreferences.h"

@interface PinsConfigurationController ()

@property (weak, nonatomic) IBOutlet UILabel *labelRemoveDatabaseWarning;
@property (weak, nonatomic) IBOutlet UILabel *labelRemoveDatabaseWarning2;

@property (weak, nonatomic) IBOutlet UIButton *buttonPinOnOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonDuressPinOnOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonChangePin;
@property (weak, nonatomic) IBOutlet UIButton *buttonChangeDuressPin;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionOpenDummy;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionTechnicalError;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionRemoveDatabase;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionOpenDummyAndRemove;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressOn;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellChangeDuress;

@end

@implementation PinsConfigurationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = [UIView new];
    
    [self bindUiToModel];
}

- (void)bindUiToModel {
    if(self.viewModel.metadata.conveniencePin != nil) {
        [self.buttonPinOnOff setTitle:NSLocalizedString(@"pins_config_vc_button_title_turn_convenience_pin_off", @"Turn Convenience PIN Off")
                             forState:UIControlStateNormal];
        self.buttonChangePin.enabled = YES;
        self.buttonDuressPinOnOff.enabled = YES;
        self.buttonChangeDuressPin.enabled = YES;
    }
    else {
        [self.buttonPinOnOff setTitle:NSLocalizedString(@"pins_config_vc_button_title_turn_convenience_pin_on", @"Turn Convenience PIN On")
                             forState:UIControlStateNormal];
        self.buttonChangePin.enabled = NO;
        self.buttonDuressPinOnOff.enabled = NO;
        self.buttonChangeDuressPin.enabled = NO;
    }
    
    if(self.viewModel.metadata.duressPin != nil && self.viewModel.metadata.conveniencePin != nil) {
        [self.buttonDuressPinOnOff setTitle:NSLocalizedString(@"pins_config_vc_button_title_turn_duress_pin_off", @"Turn Duress PIN Off")
                                   forState:UIControlStateNormal];
        self.buttonChangeDuressPin.enabled = YES;

        self.cellDuressActionOpenDummy.userInteractionEnabled = YES;
        self.cellDuressActionOpenDummy.textLabel.enabled = YES;
        self.cellDuressActionTechnicalError.userInteractionEnabled = YES;
        self.cellDuressActionTechnicalError.textLabel.enabled = YES;
        self.cellDuressActionRemoveDatabase.userInteractionEnabled = YES;
        self.cellDuressActionRemoveDatabase.textLabel.enabled = YES;
        self.cellDuressActionOpenDummyAndRemove.userInteractionEnabled = YES;
        self.cellDuressActionOpenDummyAndRemove.textLabel.enabled = YES;
    }
    else {
        [self.buttonDuressPinOnOff setTitle:NSLocalizedString(@"pins_config_vc_button_title_turn_duress_pin_on", @"Turn Duress PIN On")
                                   forState:UIControlStateNormal];
        self.buttonChangeDuressPin.enabled = NO;
        
        self.cellDuressActionOpenDummy.userInteractionEnabled = NO;
        self.cellDuressActionOpenDummy.textLabel.enabled = NO;
        self.cellDuressActionTechnicalError.userInteractionEnabled = NO;
        self.cellDuressActionTechnicalError.textLabel.enabled = NO;
        self.cellDuressActionRemoveDatabase.userInteractionEnabled = NO;
        self.cellDuressActionRemoveDatabase.textLabel.enabled = NO;
        self.cellDuressActionOpenDummyAndRemove.userInteractionEnabled = NO;
        self.cellDuressActionOpenDummyAndRemove.textLabel.enabled = NO;
    }
    
    self.cellDuressActionTechnicalError.accessoryType = UITableViewCellAccessoryNone;
    self.cellDuressActionRemoveDatabase.accessoryType = UITableViewCellAccessoryNone;
    self.cellDuressActionOpenDummy.accessoryType = UITableViewCellAccessoryNone;
    self.cellDuressActionOpenDummyAndRemove.accessoryType = UITableViewCellAccessoryNone;

    if(self.viewModel.metadata.duressAction == kOpenDummy) {
        self.cellDuressActionOpenDummy.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else if(self.viewModel.metadata.duressAction == kRemoveDatabase) {
        self.cellDuressActionRemoveDatabase.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else if(self.viewModel.metadata.duressAction == kPresentError) {
        self.cellDuressActionTechnicalError.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else if(self.viewModel.metadata.duressAction == kOpenDummyAndRemoveDatabase) {
        self.cellDuressActionOpenDummyAndRemove.accessoryType = UITableViewCellAccessoryCheckmark;
    }

    if(self.viewModel.metadata.storageProvider == kLocalDevice) {
        self.labelRemoveDatabaseWarning.text = NSLocalizedString(@"pins_config_vc_label_delete_database_local_permanent", @"Local Device database will be permanently deleted.");
        self.labelRemoveDatabaseWarning.textColor = [UIColor systemRedColor];

        self.labelRemoveDatabaseWarning2.text = NSLocalizedString(@"pins_config_vc_label_delete_database_local_permanent", @"Local Device database will be permanently deleted.");
        self.labelRemoveDatabaseWarning2.textColor = [UIColor systemRedColor];

    }
    else if(self.viewModel.metadata.storageProvider == kiCloud) {
        self.labelRemoveDatabaseWarning.text = NSLocalizedString(@"pins_config_vc_label_delete_database_icloud_permanent", @"iCloud database will be permanently deleted from iCloud.");
        self.labelRemoveDatabaseWarning.textColor = [UIColor systemRedColor];
        self.labelRemoveDatabaseWarning2.text = NSLocalizedString(@"pins_config_vc_label_delete_database_icloud_permanent", @"iCloud database will be permanently deleted from iCloud.");
        self.labelRemoveDatabaseWarning2.textColor = [UIColor systemRedColor];
    }
    else if(self.viewModel.metadata.storageProvider == kCloudKit ) {
        self.labelRemoveDatabaseWarning.text = NSLocalizedString(@"pins_config_vc_label_delete_database_strongbox_sync_permanent", @"Database will be permanently deleted from Strongbox Sync and all devices.");
        self.labelRemoveDatabaseWarning.textColor = [UIColor systemRedColor];
        self.labelRemoveDatabaseWarning2.text = NSLocalizedString(@"pins_config_vc_label_delete_database_strongbox_sync_permanent", @"Database will be permanently deleted from Strongbox Sync and all devices.");
        self.labelRemoveDatabaseWarning2.textColor = [UIColor systemRedColor];
    }
    else {
        self.labelRemoveDatabaseWarning.text = NSLocalizedString(@"pins_config_vc_label_remove_database_warning", @"NB: Database file will remain on remote storage.");
        self.labelRemoveDatabaseWarning.textColor = [UIColor systemOrangeColor];
        self.labelRemoveDatabaseWarning2.text = NSLocalizedString(@"pins_config_vc_label_remove_database_warning", @"NB: Database file will remain on remote storage.");
        self.labelRemoveDatabaseWarning2.textColor = [UIColor systemOrangeColor];
    }
    
    if( !AppPreferences.sharedInstance.isPro ) {
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
        self.cellDuressActionOpenDummyAndRemove.userInteractionEnabled = NO;
        self.cellDuressActionOpenDummyAndRemove.textLabel.enabled = NO;
    }
    
    
    
    if(!AppPreferences.sharedInstance.isPro) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
        self.title = NSLocalizedString(@"pins_config_vc_title_pro_only", @"PIN Codes (Pro Feature Only)");
    }
    
    
    
    BOOL duressAvailable = AppPreferences.sharedInstance.isPro && self.viewModel.metadata.conveniencePin != nil;
    
    [self cell:self.cellDuressOn setHidden:!duressAvailable];
    [self cell:self.cellChangeDuress setHidden:!duressAvailable];
    
    BOOL duressEnabled = duressAvailable && self.viewModel.metadata.duressPin != nil;
    
    [self cell:self.cellDuressActionOpenDummy setHidden:!duressEnabled];
    [self cell:self.cellDuressActionTechnicalError setHidden:!duressEnabled];
    [self cell:self.cellDuressActionRemoveDatabase setHidden:!duressEnabled];
    [self cell:self.cellDuressActionOpenDummyAndRemove setHidden:!duressEnabled];
    
    
    [self reloadDataAnimated:YES];
}

- (IBAction)onPinOnOff:(id)sender {
    if(self.viewModel.metadata.conveniencePin != nil) {
       self.viewModel.metadata.conveniencePin = nil;
       
       if( !self.viewModel.metadata.isTouchIdEnabled ) {
           self.viewModel.metadata.conveniencePasswordHasBeenStored = NO;
           self.viewModel.metadata.convenienceMasterPassword = nil;
           self.viewModel.metadata.autoFillConvenienceAutoUnlockPassword = nil;
       }
                       
       [self bindUiToModel];
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
    PinEntryController* pinEntryVc = PinEntryController.newControllerForDatabaseUnlock;
    
    pinEntryVc.info = duressPin ? NSLocalizedString(@"pins_config_vc_enter_duress_pin", @"Enter Duress PIN") : @"";
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if( response == kPinEntryResponseOk ) {
            NSString* otherPin = duressPin ? self.viewModel.metadata.conveniencePin : self.viewModel.metadata.duressPin;
            
            if(otherPin == nil || (![pin isEqualToString:otherPin] && pin.length == otherPin.length)) {
                if(duressPin) {
                    self.viewModel.metadata.duressPin = pin;
                }
                else {
                    if (self.viewModel.database.ckfs.keyFileDigest && !self.viewModel.metadata.keyFileBookmark) {
                        [Alerts warn:self
                               title:NSLocalizedString(@"config_error_one_time_key_file_convenience_title", @"One Time Key File Problem")
                             message:NSLocalizedString(@"config_error_one_time_key_file_convenience_message", @"You cannot use convenience unlock with a one time key file.")];
                        
                        return;
                    }

                    self.viewModel.metadata.conveniencePin = pin;
                    self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.ckfs.password;
                    self.viewModel.metadata.conveniencePasswordHasBeenStored = YES;
                }
                
                [self bindUiToModel];
            }
            else {
                [Alerts warn:self
                       title:NSLocalizedString(@"pins_config_vc_error_pin_conflict_title", @"PIN Conflict")
                     message:NSLocalizedString(@"pins_config_vc_error_pin_conflict_message", @"Your Convenience PIN conflicts with your Duress PIN. Please select another.")];
            }
        }
    };
    
    [self presentViewController:pinEntryVc animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 2) {
        if(indexPath.row == 0) {
            self.viewModel.metadata.duressAction = kOpenDummy;
        }
        else if (indexPath.row == 1) {
            self.viewModel.metadata.duressAction = kPresentError;
        }
        else if ( indexPath.row == 2 || indexPath.row == 3 ) {
            BOOL delete =   self.viewModel.metadata.storageProvider == kLocalDevice ||
                            self.viewModel.metadata.storageProvider == kCloudKit ||
                            self.viewModel.metadata.storageProvider == kiCloud;
            
            [Alerts warn:self
                   title:NSLocalizedString(@"pins_config_vc_warn_remove_database_title", @"Warning")
                 message:delete ?
             NSLocalizedString(@"pins_config_vc_warn_remove_database_delete_message", @"This will permanently delete the database file.") :
             NSLocalizedString(@"pins_config_vc_warn_remove_database_remove_message", @"This will remove the database from Strongbox but the underlying file will remain on cloud storage")];
            
            self.viewModel.metadata.duressAction = indexPath.row == 2 ? kRemoveDatabase : kOpenDummyAndRemoveDatabase;
        }

        [self bindUiToModel];
    }
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
