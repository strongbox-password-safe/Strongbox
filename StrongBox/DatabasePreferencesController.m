//
//  DatabasePreferencesController.m
//  Strongbox-iOS
//
//  Created by Mark on 21/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabasePreferencesController.h"
#import "DatabaseOperations.h"
#import "BrowsePreferencesTableViewController.h"
#import "Utils.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "Alerts.h"
#import "BiometricsManager.h"
#import "Settings.h"
#import "ISMessages.h"
#import "AutoFillManager.h"
#import "PinsConfigurationController.h"
#import "StatisticsPropertiesViewController.h"
#import "AuditConfigurationVcTableViewController.h"
#import "SharedAppAndAutoFillSettings.h"
#import "SyncManager.h"

@interface DatabasePreferencesController ()

@property (weak, nonatomic) IBOutlet UILabel *labelDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchDatabaseAutoLockEnabled;

@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometricSetting;


@property (weak, nonatomic) IBOutlet UISwitch *switchAllowAutoFillCache;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFillAlwaysUseCache;
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellBiometric;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewBiometric;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPinCodes;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewPinCodes;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseOperations;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewDatabaseOperations;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewPreferences;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewPreferences;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellStats;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewStats;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAudit;

@end

@implementation DatabasePreferencesController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageViewDatabaseOperations.image = [UIImage imageNamed:@"maintenance"];
    self.imageViewPreferences.image = [UIImage imageNamed:@"list"];
    self.imageViewStats.image = [UIImage imageNamed:@"statistics"];
    self.imageViewBiometric.image = [BiometricsManager.sharedInstance isFaceId] ? [UIImage imageNamed:@"face_ID"] : [UIImage imageNamed:@"biometric"];
    self.imageViewPinCodes.image = [UIImage imageNamed:@"keypad"];
    self.imageViewAudit.image = [UIImage imageNamed:@"security_checked"];
    
    [self bindUi];
}

- (IBAction)onReadOnlyChanged:(id)sender {
    self.viewModel.metadata.readOnly = self.switchReadOnly.on;
    [[SafesList sharedInstance] update:self.viewModel.metadata];
    
    [Alerts info:self
           title:NSLocalizedString(@"db_management_reopen_required_title", @"Re-Open Required")
         message:NSLocalizedString(@"db_management_reopen_required_message", @"You must close and reopen this database for Read-Only changes to take effect.")];
}

- (IBAction)onSwitchBiometricUnlock:(id)sender {
    NSString* bIdName = [BiometricsManager.sharedInstance getBiometricIdName];
    
    if (!self.switchAllowBiometric.on) {
        NSString *message = self.viewModel.metadata.isEnrolledForConvenience && self.viewModel.metadata.conveniencePin == nil ?
        
        NSLocalizedString(@"db_management_disable_biometric_warning_fmt", @"Disabling %@ for this database will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?") :
        
        NSLocalizedString(@"db_management_disable_biomtric_simple_fmt", @"Are you sure you want to disable %@ for this database?");
        
        [Alerts yesNo:self
                title:[NSString stringWithFormat:NSLocalizedString(@"db_management_disable_biometric_question_fmt", @"Disable %@?"), bIdName]
              message:[NSString stringWithFormat:message, bIdName]
               action:^(BOOL response) {
                   if (response) {
                       self.viewModel.metadata.isTouchIdEnabled = NO;
                       
                       if(self.viewModel.metadata.conveniencePin == nil) {
                           self.viewModel.metadata.isEnrolledForConvenience = NO;
                           self.viewModel.metadata.convenienceMasterPassword = nil;
                           self.viewModel.metadata.convenenienceYubikeySecret = nil;
                       }
                       
                       [[SafesList sharedInstance] update:self.viewModel.metadata];

                       [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:
                                                           NSLocalizedString(@"db_management_disable_biometric_notify_title_fmt", @"%@ Disabled"), bIdName]
                                                  message:[NSString stringWithFormat:
                                            
                                                           NSLocalizedString(@"db_management_disable_biometric_notify_message_fmt", @"%@ for this database has been disabled."), bIdName]
                                                 duration:3.f
                                              hideOnSwipe:YES
                                                hideOnTap:YES
                                                alertType:ISAlertTypeSuccess
                                            alertPosition:ISAlertPositionTop
                                                  didHide:nil];
                   }
                   
                   [self bindUi];
               }];
    }
    else {
        if (self.viewModel.database.compositeKeyFactors.keyFileDigest && !self.viewModel.metadata.keyFileUrl) {
            [Alerts warn:self
                   title:NSLocalizedString(@"config_error_one_time_key_file_convenience_title", @"One Time Key File Problem")
                 message:NSLocalizedString(@"config_error_one_time_key_file_convenience_message", @"You cannot use convenience unlock with a one time key file.")];
            
            return;
        }

        self.viewModel.metadata.isTouchIdEnabled = YES;
        self.viewModel.metadata.isEnrolledForConvenience = YES;
        self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.compositeKeyFactors.password;
        self.viewModel.metadata.convenenienceYubikeySecret = self.viewModel.openedWithYubiKeySecret;
        
        [[SafesList sharedInstance] update:self.viewModel.metadata];
        [self bindUi];

        [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:
                                            NSLocalizedString(@"db_management_enable_biometric_notify_title_fmt", @"%@ Enabled"), bIdName]
                                   message:[NSString stringWithFormat:
                                            NSLocalizedString(@"db_management_enable_biometric_notify_message_fmt", @"%@ has been enabled for this database."), bIdName]
                                  duration:3.f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeSuccess
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];
    }
}

- (IBAction)onSwitchAllowAutoFillCache:(id)sender {
    if (!self.switchAllowAutoFillCache.on) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"db_management_disable_autofill_yesno_title", @"Disable AutoFill?")
              message:NSLocalizedString(@"db_management_disable_autofill_yesno_message", @"Are you sure you want to do this?")
               action:^(BOOL response) {
                   if (response) {
                       [self.viewModel disableAndClearAutoFill];
                       [self bindUi];
                       
                       [ISMessages showCardAlertWithTitle:NSLocalizedString(@"db_management_disable_done", @"AutoFill Disabled")
                                                  message:nil
                                                 duration:3.f
                                              hideOnSwipe:YES
                                                hideOnTap:YES
                                                alertType:ISAlertTypeSuccess
                                            alertPosition:ISAlertPositionTop
                                                  didHide:nil];
                   }
                   else {
                      [self bindUi];
                   }
               }];
    }
    else {
        [self.viewModel enableAutoFill];
        
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel.database
                                                           databaseUuid:self.viewModel.metadata.uuid];
        
        [self bindUi];

        [ISMessages                 showCardAlertWithTitle:NSLocalizedString(@"db_management_enable_done", @"AutoFill Enabled")
                                                   message:nil
                                                  duration:3.f
                                               hideOnSwipe:YES
                                                 hideOnTap:YES
                                                 alertType:ISAlertTypeSuccess
                                             alertPosition:ISAlertPositionTop
                                                   didHide:nil];
    }
}

- (IBAction)onAlwaysUseAutoFillCache:(id)sender {
    self.viewModel.metadata.alwaysUseCacheForAutoFill = self.switchAutoFillAlwaysUseCache.on;
    
    [SafesList.sharedInstance update:self.viewModel.metadata];
    
    [self bindUi];
}

- (void)bindUi {
    [self bindDatabaseLock];
    
    NSString *biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];

    if (![SharedAppAndAutoFillSettings.sharedInstance isProOrFreeTrial]) {
        self.labelAllowBiometricSetting.text = [NSString stringWithFormat:NSLocalizedString(@"db_management_biometric_unlock_fmt_pro_only", @"%@ Unlock"), biometricIdName];
    }
    else {
        self.labelAllowBiometricSetting.text = [NSString stringWithFormat:NSLocalizedString(@"db_management_biometric_unlock_fmt", @"%@ Unlock"), biometricIdName];
    }
    
    if (@available(iOS 13.0, *)) {
        self.labelAllowBiometricSetting.textColor = [self canToggleTouchId] ? UIColor.labelColor : UIColor.secondaryLabelColor;
    } else {
        self.labelAllowBiometricSetting.textColor = [self canToggleTouchId] ? UIColor.blackColor : UIColor.lightGrayColor;
    }
    
    self.switchAllowBiometric.enabled = [self canToggleTouchId];
    self.switchAllowBiometric.on = self.viewModel.metadata.isTouchIdEnabled;

    self.switchAllowAutoFillCache.on = self.viewModel.metadata.autoFillEnabled;

//    self.labelAllowOfflineCahce.enabled = [self canToggleOfflineCache];
//    self.switchAllowOfflineCache.enabled = [self canToggleOfflineCache];
//    self.switchAllowOfflineCache.on = self.viewModel.metadata.offlineCacheEnabled;

    self.switchReadOnly.on = self.viewModel.metadata.readOnly;
    self.switchAutoFillAlwaysUseCache.on = self.viewModel.metadata.alwaysUseCacheForAutoFill;
}

- (IBAction)onDone:(id)sender {
    self.onDone(NO);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToPinsConfiguration"]) {
        PinsConfigurationController* vc = (PinsConfigurationController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToOperations"]) {
        DatabaseOperations *vc = (DatabaseOperations *)segue.destinationViewController;
        vc.viewModel = self.viewModel;
        vc.onDatabaseBulkIconUpdate = self.onDatabaseBulkIconUpdate;
    }
    else if([segue.identifier isEqualToString:@"segueToViewPreferences"]) {
        BrowsePreferencesTableViewController* vc = (BrowsePreferencesTableViewController*)segue.destinationViewController;
        vc.format = self.viewModel.database.format;
        vc.databaseMetaData = self.viewModel.metadata;
    }
    else if ([segue.identifier isEqualToString:@"segueToStatistics"]) {
        StatisticsPropertiesViewController* vc = (StatisticsPropertiesViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToAudit"]) {
        AuditConfigurationVcTableViewController* vc = (AuditConfigurationVcTableViewController*)segue.destinationViewController;
        vc.model = self.viewModel;
        vc.onDone = self.onDone;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.cellDatabaseAutoLockDelay) {
        [self promptForAutoLockTimeout];
    }
    else if (cell == self.cellPinCodes) {
        [self performSegueWithIdentifier:@"segueToPinsConfiguration" sender:nil];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)promptForAutoLockTimeout {
    [self promptForInteger:NSLocalizedString(@"prefs_vc_auto_lock_database_delay", @"Auto Lock Delay")
                   options:@[@0, @30, @60, @120, @180, @300, @600]
         formatAsIntervals:YES
              currentValue:self.viewModel.metadata.autoLockTimeoutSeconds ? self.viewModel.metadata.autoLockTimeoutSeconds.integerValue : 60
                completion:^(BOOL success, NSInteger selectedValue) {
                    if (success) {
                        self.viewModel.metadata.autoLockTimeoutSeconds = @(selectedValue);
                        [SafesList.sharedInstance update:self.viewModel.metadata];
                    }
                    [self bindDatabaseLock];
                }];
}

- (IBAction)onSwitchDatabaseAutoLockEnabled:(id)sender {
    self.viewModel.metadata.autoLockTimeoutSeconds = self.switchDatabaseAutoLockEnabled.on ? @(60) : @(-1);
    [SafesList.sharedInstance update:self.viewModel.metadata];
    [self bindDatabaseLock];
}

- (void)bindDatabaseLock {
    NSNumber* seconds = self.viewModel.metadata.autoLockTimeoutSeconds ? self.viewModel.metadata.autoLockTimeoutSeconds : @(-1);
    
    if(seconds.integerValue == -1) {
        self.switchDatabaseAutoLockEnabled.on = NO;
        self.labelDatabaseAutoLockDelay.text = NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
//        self.labelDatabaseAutoLockDelay.textColor = UIColor.darkGrayColor;
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = NO;
    }
    else {
        self.switchDatabaseAutoLockEnabled.on = YES;
        self.labelDatabaseAutoLockDelay.text = [Utils formatTimeInterval:seconds.integerValue];
//        self.labelDatabaseAutoLockDelay.textColor = UIColor.darkTextColor;
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = YES;
    }
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];
    
    vc.groupItems = @[items];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        NSInteger selectedValue = options[set.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (BOOL)canToggleTouchId {
    return BiometricsManager.isBiometricIdAvailable && [SharedAppAndAutoFillSettings.sharedInstance isProOrFreeTrial];
}

@end
