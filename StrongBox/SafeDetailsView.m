//
//  SafeDetailsView.m
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "SafeDetailsView.h"
#import "IOsUtils.h"
#import "Alerts.h"
#import "Settings.h"
#import "ISMessages.h"
#import "Utils.h"
#import "KeyFileParser.h"
#import "PinsConfigurationController.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "AddNewSafeHelper.h"
#import "CacheManager.h"
#import "ExportOptionsTableViewController.h"
#import "AttachmentsPoolViewController.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "BiometricsManager.h"
#import "FavIconBulkViewController.h"

@interface SafeDetailsView ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellPinCodes;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometricSetting;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowAutoFillCache;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellChangeMasterCredentials;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellExport;
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPrint;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewAttachments;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFillAlwaysUseCache;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellBulkUpdateFavIcons;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchDatabaseAutoLockEnabled;

@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfGroups;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfRecords;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniqueUsernames;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniquePasswords;
@property (weak, nonatomic) IBOutlet UILabel * labelMostPopularUsername;
@property (weak, nonatomic) IBOutlet UILabel * labelExportByEmail;


@end

@implementation SafeDetailsView

- (IBAction)onGenericSettingChanged:(id)sender {
    self.viewModel.metadata.alwaysUseCacheForAutoFill = self.switchAutoFillAlwaysUseCache.on;
    
    [SafesList.sharedInstance update:self.viewModel.metadata];
    
    [self bindSettings];
}

- (IBAction)onReadOnlyChanged:(id)sender {
    self.viewModel.metadata.readOnly = self.switchReadOnly.on;
    [[SafesList sharedInstance] update:self.viewModel.metadata];
    
    [Alerts info:self
           title:NSLocalizedString(@"db_management_reopen_required_title", @"Re-Open Required")
         message:NSLocalizedString(@"db_management_reopen_required_message", @"You must close and reopen this database for Read-Only changes to take effect.")];
}

- (void)bindSettings {
    NSString *biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];

    if (![Settings.sharedInstance isProOrFreeTrial]) {
        self.labelAllowBiometricSetting.text = [NSString stringWithFormat:NSLocalizedString(@"db_management_biometric_unlock_fmt_pro_only", @"%@ Unlock"), biometricIdName];
    }
    else {
        self.labelAllowBiometricSetting.text = [NSString stringWithFormat:NSLocalizedString(@"db_management_biometric_unlock_fmt", @"%@ Unlock"), biometricIdName];
    }
    
    if (@available(iOS 13.0, *)) {
        self.labelAllowBiometricSetting.textColor = [self canToggleTouchId] ? UIColor.labelColor : UIColor.secondaryLabelColor;
    } else {
        self.labelAllowBiometricSetting.textColor = [self canToggleTouchId] ? UIColor.darkGrayColor : UIColor.lightGrayColor;
    }
    
    self.switchAllowBiometric.enabled = [self canToggleTouchId];
    self.switchAllowBiometric.on = self.viewModel.metadata.isTouchIdEnabled;

    self.switchAllowAutoFillCache.on = self.viewModel.metadata.autoFillEnabled;

//    self.labelAllowOfflineCahce.enabled = [self canToggleOfflineCache];
//    self.switchAllowOfflineCache.enabled = [self canToggleOfflineCache];
//    self.switchAllowOfflineCache.on = self.viewModel.metadata.offlineCacheEnabled;

    self.switchReadOnly.on = self.viewModel.metadata.readOnly;
    self.switchAutoFillAlwaysUseCache.on = self.viewModel.metadata.alwaysUseCacheForAutoFill;
    
    [self bindDatabaseLock];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupTableView];
}

- (void)setupTableView {
    [self cell:self.cellBulkUpdateFavIcons setHidden:self.viewModel.database.format == kPasswordSafe || self.viewModel.database.format == kKeePass1];
    [self cell:self.cellViewAttachments setHidden:self.viewModel.database.attachments.count == 0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self bindSettings];
    
    self.cellChangeMasterCredentials.userInteractionEnabled = [self canSetCredentials];
    
    if (@available(iOS 13.0, *)) {
        self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.secondaryLabelColor;
    } else {
        self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.lightGrayColor;
    }
    
    self.cellChangeMasterCredentials.textLabel.text = self.viewModel.database.format == kPasswordSafe ?
    NSLocalizedString(@"db_management_change_master_password", @"Change Master Password") :
    NSLocalizedString(@"db_management_change_master_credentials", @"Change Master Credentials");
    
    self.cellChangeMasterCredentials.tintColor =  [self canSetCredentials] ? nil : UIColor.lightGrayColor;
    
    // This must be done in code as Interface builder setting is not respected on iPhones
    // until cell gets selected

    self.cellChangeMasterCredentials.imageView.image = [UIImage imageNamed:@"key"];
    self.cellPinCodes.imageView.image = [UIImage imageNamed:@"keypad"];
    self.cellExport.imageView.image = [UIImage imageNamed:@"upload"];
    self.cellPrint.imageView.image = [UIImage imageNamed:@"print"];
    self.cellViewAttachments.imageView.image = [UIImage imageNamed:@"picture"];
    //
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:NO];

    self.labelMostPopularUsername.text = self.viewModel.database.mostPopularUsername ? self.viewModel.database.mostPopularUsername : NSLocalizedString(@"db_management_statistics_none", @"<None>");
    self.labelNumberOfUniqueUsernames.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.usernameSet count]];
    self.labelNumberOfUniquePasswords.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.passwordSet count]];
    self.labelNumberOfGroups.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.database.numberOfGroups];
    self.labelNumberOfRecords.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.database.numberOfRecords];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)onChangeMasterCredentials {
    [self performSegueWithIdentifier:@"segueToSetCredentials" sender:nil];
}

- (BOOL)canSetCredentials {
    return !(self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToPinsConfiguration"]) {
        PinsConfigurationController* vc = (PinsConfigurationController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToExportOptions"]) {
        ExportOptionsTableViewController* vc = (ExportOptionsTableViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToSetCredentials"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        
        scVc.mode = kCASGModeSetCredentials;
        scVc.initialFormat = self.viewModel.database.format;
        scVc.initialKeyFileUrl = self.viewModel.metadata.keyFileUrl;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [self setCredentials:creds.password keyFileUrl:creds.keyFileUrl oneTimeKeyFileData:creds.oneTimeKeyFileData];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToAttachmentsPool"]) {
        AttachmentsPoolViewController* vc = (AttachmentsPoolViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
}

- (void)setCredentials:(NSString*)password keyFileUrl:(NSURL*)keyFileUrl oneTimeKeyFileData:(NSData*)oneTimeKeyFileData {
    if(keyFileUrl != nil || oneTimeKeyFileData != nil) {
        NSError* error;
        self.viewModel.database.compositeKeyFactors.keyFileDigest = getKeyFileDigest(keyFileUrl, oneTimeKeyFileData, self.viewModel.database.format, &error);
        
        if(self.viewModel.database.compositeKeyFactors.keyFileDigest == nil) {
            [Alerts error:self
                    title:NSLocalizedString(@"db_management_error_title_couldnt_change_credentials", @"Could not change credentials")
                    error:error];
            return;
        }
    }
    else {
        self.viewModel.database.compositeKeyFactors.keyFileDigest = nil;
    }

    self.viewModel.database.compositeKeyFactors.password = password;
    
    [self.viewModel update:NO handler:^(NSError *error) {
        if (error == nil) {
            if (self.viewModel.metadata.isTouchIdEnabled && self.viewModel.metadata.isEnrolledForConvenience) {
                if(!oneTimeKeyFileData) {
                    self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.compositeKeyFactors.password;
                    self.viewModel.metadata.convenenienceYubikeySecret = self.viewModel.openedWithYubiKeySecret;
                    NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
                }
                else {
                    // We can't support Convenience unlock with a one time key file...
                    
                    self.viewModel.metadata.convenienceMasterPassword = nil;
                    self.viewModel.metadata.convenenienceYubikeySecret = nil;
                    self.viewModel.metadata.isEnrolledForConvenience = NO;
                }
            }
            
            self.viewModel.metadata.keyFileUrl = keyFileUrl; 
            [SafesList.sharedInstance update:self.viewModel.metadata];

            [ISMessages showCardAlertWithTitle:self.viewModel.database.format == kPasswordSafe ?
             NSLocalizedString(@"db_management_password_changed", @"Master Password Changed") :
             NSLocalizedString(@"db_management_credentials_changed", @"Master Credentials Changed")
                                       message:nil
                                      duration:3.f
                                   hideOnSwipe:YES
                                     hideOnTap:YES
                                     alertType:ISAlertTypeSuccess
                                 alertPosition:ISAlertPositionTop
                                       didHide:nil];
        }
        else {
            [Alerts error:self
                    title:NSLocalizedString(@"db_management_couldnt_change_credentials", @"Could not change credentials")
                    error:error];
        }
    }];
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
                   
                   [self bindSettings];
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
        [self bindSettings];

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
                       [self bindSettings];
                       
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
                      [self bindSettings];
                   }
               }];
    }
    else {
        [self.viewModel enableAutoFill];
        
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel.database databaseUuid:self.viewModel.metadata.uuid];
        
        [self.viewModel updateAutoFillCache:^{
            [self bindSettings];
            
            [ISMessages                 showCardAlertWithTitle:NSLocalizedString(@"db_management_enable_done", @"AutoFill Enabled")
                                                       message:nil
                                                      duration:3.f
                                                   hideOnSwipe:YES
                                                     hideOnTap:YES
                                                     alertType:ISAlertTypeSuccess
                                                 alertPosition:ISAlertPositionTop
                                                       didHide:nil];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellChangeMasterCredentials) {
        [self onChangeMasterCredentials];
    }
    else if (cell == self.cellPinCodes) {
        [self performSegueWithIdentifier:@"segueToPinsConfiguration" sender:nil];
    }
    else if (cell == self.cellExport) {
        [self onExport];
    }
    else if (cell == self.cellPrint) {
        [self onPrint];
    }
    else if (cell == self.cellViewAttachments) {
        [self viewAttachments];
    }
    else if (cell == self.cellDatabaseAutoLockDelay) {
        [self promptForAutoLockTimeout];
    }
    else if (cell == self.cellBulkUpdateFavIcons) {
        [self onBulkUpdateFavIcons];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)onBulkUpdateFavIcons {
    [FavIconBulkViewController presentModal:self
                                      nodes:self.viewModel.database.activeRecords
                                     onDone:^(BOOL go, NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
        [self dismissViewControllerAnimated:YES completion:nil];
        
        if(go && selectedFavIcons) {
            self.onDatabaseBulkIconUpdate(selectedFavIcons); // Browse will take care of updating itself here...
        }
    }];
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

-(void)bindDatabaseLock {
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

- (void)viewAttachments {
    [self performSegueWithIdentifier:@"segueToAttachmentsPool" sender:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if(indexPath.section == 3) {
        BasicOrderedDictionary<NSString*, NSString*> *metadataKvps = [self.viewModel.database.metadata kvpForUi];

        if(indexPath.row < metadataKvps.allKeys.count) // Hide extra metadata pairs beyond actual metadata
        {
            NSString* key = [metadataKvps.allKeys objectAtIndex:indexPath.row];
            cell.textLabel.text = key;
            cell.detailTextLabel.text = [metadataKvps objectForKey:key];
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BasicOrderedDictionary<NSString*, NSString*> *metadataKvps = [self.viewModel.database.metadata kvpForUi];
    if(indexPath.section == 3 && indexPath.row >= metadataKvps.allKeys.count) // Hide extra metadata pairs beyond actual metadata
    {
        return 0;
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)onExport {
    [self performSegueWithIdentifier:@"segueToExportOptions" sender:nil];
}

- (void)onPrint {
    NSString* htmlString = [self.viewModel.database getHtmlPrintString:self.viewModel.metadata.nickName];
    
    UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:htmlString];
    
    UIPrintInteractionController.sharedPrintController.printFormatter = formatter;
    
    [UIPrintInteractionController.sharedPrintController presentAnimated:YES completionHandler:nil];
}

- (BOOL)canToggleTouchId {
    return BiometricsManager.isBiometricIdAvailable && [Settings.sharedInstance isProOrFreeTrial];
}

- (BOOL)canToggleOfflineCache {
    return !(self.viewModel.isUsingOfflineCache || !self.viewModel.isCloudBasedStorage);
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selected = [NSIndexSet indexSetWithIndex:currentlySelectIndex];
    vc.onSelectionChanged = ^(NSIndexSet * _Nonnull selectedIndices) {
        NSInteger selectedValue = options[selectedIndices.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
