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

@interface SafeDetailsView ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellPinCodes;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometricSetting;
@property (weak, nonatomic) IBOutlet UILabel *labelOfflineCacheTime;
@property (weak, nonatomic) IBOutlet UILabel *labelAutoFillCacheTime;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowAutoFillCache;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowOfflineCache;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowOfflineCahce;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellChangeMasterCredentials;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellExport;
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPrint;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewAttachments;

@end

@implementation SafeDetailsView

- (IBAction)onSettingChanged:(id)sender {
    self.viewModel.metadata.readOnly = self.switchReadOnly.on;
    [[SafesList sharedInstance] update:self.viewModel.metadata];
    
    [Alerts info:self title:@"Re-Open Required" message:@"You must close and reopen this database for Read-Only changes to take effect."];
}

- (void)bindSettings {
    NSString *biometricIdName = [[Settings sharedInstance] getBiometricIdName];
    self.labelAllowBiometricSetting.text = [NSString stringWithFormat:@"Allow %@ Unlock", biometricIdName];
    self.labelAllowBiometricSetting.textColor = [self canToggleTouchId] ? UIColor.darkTextColor : UIColor.lightGrayColor;
    
    self.switchAllowBiometric.enabled = [self canToggleTouchId];
    self.switchAllowBiometric.on = self.viewModel.metadata.isTouchIdEnabled;


    NSDate* modDate = [[CacheManager sharedInstance] getAutoFillCacheModificationDate:self.viewModel.metadata];
    self.labelAutoFillCacheTime.text = self.viewModel.metadata.autoFillEnabled ? getLastCachedDate(modDate) : @"";
    self.switchAllowAutoFillCache.on = self.viewModel.metadata.autoFillEnabled;

    modDate = [[CacheManager sharedInstance] getOfflineCacheFileModificationDate:self.viewModel.metadata];
    self.labelOfflineCacheTime.text = self.viewModel.metadata.offlineCacheEnabled ? getLastCachedDate(modDate) : @"";
    
    self.labelAllowOfflineCahce.enabled = [self canToggleOfflineCache];
    self.switchAllowOfflineCache.enabled = [self canToggleOfflineCache];
    self.switchAllowOfflineCache.on = self.viewModel.metadata.offlineCacheEnabled;

    
    self.switchReadOnly.on = self.viewModel.metadata.readOnly;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupTableView];
}

- (void)setupTableView {
    [self cell:self.cellViewAttachments setHidden:self.viewModel.database.attachments.count == 0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self bindSettings];
    
    self.cellChangeMasterCredentials.userInteractionEnabled = [self canSetCredentials];
    self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.lightGrayColor;
    self.cellChangeMasterCredentials.textLabel.text = self.viewModel.database.format == kPasswordSafe ? @"Change Master Password" : @"Change Master Credentials";
    
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

    self.labelMostPopularUsername.text = self.viewModel.database.mostPopularUsername ? self.viewModel.database.mostPopularUsername : @"<None>";
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
        NSLog(@"Set Creds - XXXXXXXX");
        
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
            [Alerts error:self title:@"Could not change credentials" error:error];
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
                self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.compositeKeyFactors.password;
                self.viewModel.metadata.convenenienceKeyFileDigest = self.viewModel.database.compositeKeyFactors.keyFileDigest;
                self.viewModel.metadata.convenenienceYubikeySecret = self.viewModel.openedWithYubiKeySecret;
                
                NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
            }
            
            self.viewModel.metadata.keyFileUrl = keyFileUrl; 
            [SafesList.sharedInstance update:self.viewModel.metadata];

            [ISMessages showCardAlertWithTitle:self.viewModel.database.format == kPasswordSafe ? @"Master Password Changed" : @"Master Credentials Changed"
                                       message:nil
                                      duration:3.f
                                   hideOnSwipe:YES
                                     hideOnTap:YES
                                     alertType:ISAlertTypeSuccess
                                 alertPosition:ISAlertPositionTop
                                       didHide:nil];
        }
        else {
            [Alerts error:self title:@"Could not change credentials" error:error];
        }
    }];
}

- (IBAction)onSwitchBiometricUnlock:(id)sender {
    NSString* bIdName = [[Settings sharedInstance] getBiometricIdName];
    
    if (!self.switchAllowBiometric.on) {
        NSString *message = self.viewModel.metadata.isEnrolledForConvenience && self.viewModel.metadata.conveniencePin == nil ?
        @"Disabling %@ for this database will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?" :
        @"Are you sure you want to disable %@ for this database?";
        
        [Alerts yesNo:self
                title:[NSString stringWithFormat:@"Disable %@?", bIdName]
              message:[NSString stringWithFormat:message, bIdName]
               action:^(BOOL response) {
                   if (response) {
                       self.viewModel.metadata.isTouchIdEnabled = NO;
                       
                       if(self.viewModel.metadata.conveniencePin == nil) {
                           self.viewModel.metadata.isEnrolledForConvenience = NO;
                           self.viewModel.metadata.convenienceMasterPassword = nil;
                           self.viewModel.metadata.convenenienceKeyFileDigest = nil;
                           self.viewModel.metadata.convenenienceYubikeySecret = nil;
                       }
                       
                       [[SafesList sharedInstance] update:self.viewModel.metadata];

                       [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"%@ Disabled", bIdName]
                                                  message:[NSString stringWithFormat:@"%@ for this database has been disabled.", bIdName]
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
        self.viewModel.metadata.isTouchIdEnabled = YES;
        self.viewModel.metadata.isEnrolledForConvenience = YES;
        self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.compositeKeyFactors.password;
        self.viewModel.metadata.convenenienceKeyFileDigest = self.viewModel.database.compositeKeyFactors.keyFileDigest;
        self.viewModel.metadata.convenenienceYubikeySecret = self.viewModel.openedWithYubiKeySecret;
        
        [[SafesList sharedInstance] update:self.viewModel.metadata];
        [self bindSettings];

        [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"%@ Enabled", bIdName]
                                   message:[NSString stringWithFormat:@"%@ has been enabled for this database.", bIdName]
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
                title:@"Disable AutoFill?"
              message:@"Are you sure you want to do this?"
               action:^(BOOL response) {
                   if (response) {
                       [self.viewModel disableAndClearAutoFill];
                       [self bindSettings];
                       
                       [ISMessages showCardAlertWithTitle:@"AutoFill Disabled"
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
            
            [ISMessages                 showCardAlertWithTitle:@"AutoFill Enabled"
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

- (IBAction)onSwitchAllowOfflineCache:(id)sender {
    if (!self.switchAllowOfflineCache.on) {
        [Alerts yesNo:self
                title:@"Disable Offline Access?"
              message:@"Disabling offline access for this database will remove the offline cache and you will not be able to access the database when offline. Are you sure you want to do this?"
               action:^(BOOL response) {
                   if (response) {
                       [self.viewModel disableAndClearOfflineCache];
                       [self bindSettings];
                       [ISMessages showCardAlertWithTitle:@"Offline Disabled"
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
        [self.viewModel enableOfflineCache];
        [self.viewModel updateOfflineCache:^{
            [self bindSettings];
            
            [ISMessages                 showCardAlertWithTitle:@"Offline Enabled"
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
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)viewAttachments {
    [self performSegueWithIdentifier:@"segueToAttachmentsPool" sender:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if(indexPath.section == 2) {
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
    if(indexPath.section == 2 && indexPath.row >= metadataKvps.allKeys.count) // Hide extra metadata pairs beyond actual metadata
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
    return Settings.isBiometricIdAvailable;
}

- (BOOL)canToggleOfflineCache {
    return !(self.viewModel.isUsingOfflineCache || !self.viewModel.isCloudBasedStorage);
}

static NSString *getLastCachedDate(NSDate *modDate) {
    return modDate ? [NSString stringWithFormat:@"(Cached %@)", friendlyDateStringVeryShort(modDate)] : @"";
}


@end
