//
//  SafeDetailsView.m
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "SafeDetailsView.h"
#import "IOsUtils.h"
#import <MessageUI/MessageUI.h>
#import "Alerts.h"
#import "CHCSVParser.h"
#import "Settings.h"
#import "ISMessages.h"
#import "Utils.h"
#import "Csv.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "KeyFileParser.h"
#import "PinsConfigurationController.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "AddNewSafeHelper.h"

@interface Delegate : NSObject <CHCSVParserDelegate>

@property (readonly) NSArray *lines;

@end

@interface SafeDetailsView () <MFMailComposeViewControllerDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
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


    NSDate* modDate = [[LocalDeviceStorageProvider sharedInstance] getAutoFillCacheModificationDate:self.viewModel.metadata];
    self.labelAutoFillCacheTime.text = self.viewModel.metadata.autoFillCacheEnabled ? getLastCachedDate(modDate) : @"";
    self.switchAllowAutoFillCache.on = self.viewModel.metadata.autoFillCacheEnabled;

    modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:self.viewModel.metadata];
    self.labelOfflineCacheTime.text = self.viewModel.metadata.offlineCacheEnabled ? getLastCachedDate(modDate) : @"";
    
    self.labelAllowOfflineCahce.enabled = [self canToggleOfflineCache];
    self.switchAllowOfflineCache.enabled = [self canToggleOfflineCache];
    self.switchAllowOfflineCache.on = self.viewModel.metadata.offlineCacheEnabled;

    
    self.switchReadOnly.on = self.viewModel.metadata.readOnly;
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

    //
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:NO];

    self.labelMostPopularUsername.text = self.viewModel.database.mostPopularUsername ? self.viewModel.database.mostPopularUsername : @"<None>";
    self.labelMostPopularEmail.text = self.viewModel.database.mostPopularEmail ? self.viewModel.database.mostPopularEmail : @"<None>";
    self.labelNumberOfUniqueUsernames.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.usernameSet count]];
    self.labelNumberOfUniqueEmails.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.emailSet count]];
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
}

- (void)setCredentials:(NSString*)password keyFileUrl:(NSURL*)keyFileUrl oneTimeKeyFileData:(NSData*)oneTimeKeyFileData {
    if(keyFileUrl != nil || oneTimeKeyFileData != nil) {
        NSError* error;
        self.viewModel.database.keyFileDigest = getKeyFileDigest(keyFileUrl, oneTimeKeyFileData, self.viewModel.database.format, &error);
        
        if(self.viewModel.database.keyFileDigest == nil) {
            [Alerts error:self title:@"Could not change credentials" error:error];
            return;
        }
    }
    else {
        self.viewModel.database.keyFileDigest = nil;
    }

    self.viewModel.database.masterPassword = password;
    
    [self.viewModel update:^(NSError *error) {
        if (error == nil) {
            if (self.viewModel.metadata.isTouchIdEnabled && self.viewModel.metadata.isEnrolledForConvenience) {
                self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.masterPassword;
                self.viewModel.metadata.convenenienceKeyFileDigest = self.viewModel.database.keyFileDigest;
                
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
        self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.masterPassword;
        self.viewModel.metadata.convenenienceKeyFileDigest = self.viewModel.database.keyFileDigest;
        
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
                title:@"Disable AutoFill Cache?"
              message:@"Disabling the AutoFill Cache will remove the AutoFill cache and you will not be able to use AutoFill in certain contexts. Are you sure you want to do this?"
               action:^(BOOL response) {
                   if (response) {
                       [self.viewModel disableAndClearAutoFillCache];
                       [self bindSettings];
                       
                       [ISMessages showCardAlertWithTitle:@"AutoFill Cache Disabled"
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
        [self.viewModel enableAutoFillCache];
        [self.viewModel updateAutoFillCache:^{
            [self bindSettings];
            
            [ISMessages                 showCardAlertWithTitle:@"AutoFill Cache Enabled"
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
                title:@"Disable Offline Cache?"
              message:@"Disabling Offline Cache for this database will remove the offline cache and you will not be able to access the database when offline. Are you sure you want to do this?"
               action:^(BOOL response) {
                   if (response) {
                       [self.viewModel disableAndClearOfflineCache];
                       [self bindSettings];
                       [ISMessages showCardAlertWithTitle:@"Offline Cache Disabled"
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
            
            [ISMessages                 showCardAlertWithTitle:@"Offline Cache Enabled"
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
    [Alerts threeOptionsWithCancel:self title:@"How would you like to export your database?"
                           message:@"You can export your encrypted database by email, or you can copy your database in plaintext format (CSV) to the clipboard."
                 defaultButtonText:@"Export (Encrypted) by Email"
                  secondButtonText:@"Export as CSV by Email"
                   thirdButtonText:@"Copy CSV to Clipboard"
                            action:^(int response) {
                                if(response == 0) {
                                    [self exportEncryptedSafeByEmail];
                                }
                                else if(response == 1){
                                    NSData *newStr = [Csv getSafeAsCsv:self.viewModel.database.rootGroup];
                                    
                                    NSString* attachmentName = [NSString stringWithFormat:@"%@.csv", self.viewModel.metadata.nickName];
                                    [self composeEmail:attachmentName mimeType:@"text/csv" data:newStr];
                                }
                                else if(response == 2){
                                    NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.viewModel.database.rootGroup] encoding:NSUTF8StringEncoding];
                                    
                                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                    pasteboard.string = newStr;
                                    
                                    [ISMessages showCardAlertWithTitle:@"Database Copied to Clipboard"
                                                               message:nil
                                                              duration:3.f
                                                           hideOnSwipe:YES
                                                             hideOnTap:YES
                                                             alertType:ISAlertTypeSuccess
                                                         alertPosition:ISAlertPositionTop
                                                               didHide:nil];
                                }
                            }];
    
}

- (BOOL)canToggleTouchId {
    return Settings.isBiometricIdAvailable && !self.viewModel.isReadOnly;
}

- (BOOL)canToggleOfflineCache {
    return !(self.viewModel.isUsingOfflineCache || !self.viewModel.isCloudBasedStorage);
}

- (void)exportEncryptedSafeByEmail {
    [self.viewModel encrypt:^(NSData * _Nullable safeData, NSError * _Nullable error) {
        if(!safeData) {
            [Alerts error:self title:@"Could not get database data" error:error];
            return;
        }
      
        NSString *attachmentName = [NSString stringWithFormat:@"%@%@", self.viewModel.metadata.fileName,
                                    ([self.viewModel.metadata.fileName hasSuffix:@".dat"] || [self.viewModel.metadata.fileName hasSuffix:@"psafe3"]) ? @"" : @".dat"];
        
        [self composeEmail:attachmentName mimeType:@"application/octet-stream" data:safeData];
    }];
}

- (void)composeEmail:(NSString*)attachmentName mimeType:(NSString*)mimeType data:(NSData*)data {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:@"Email Not Available"
             message:@"It looks like email is not setup on this device and so the database cannot be exported by email."];
        
        return;
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    
    [picker setSubject:[NSString stringWithFormat:@"Strongbox Database: '%@'", self.viewModel.metadata.nickName]];
    
    [picker addAttachmentData:data mimeType:mimeType fileName:attachmentName];
    
    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:@"Here's a copy of my '%@' Strongbox Database.", self.viewModel.metadata.nickName] isHTML:NO];
    picker.mailComposeDelegate = self;
    
    [self presentViewController:picker animated:YES completion:^{ }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:^{ }];
}


static NSString *getLastCachedDate(NSDate *modDate) {
    if(!modDate) { return @""; }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.timeStyle = NSDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterShortStyle;
    df.doesRelativeDateFormatting = YES;
    df.locale = NSLocale.currentLocale;
    
    NSString *modDateStr = [df stringFromDate:modDate];
    return [NSString stringWithFormat:@"(Cached %@)", modDateStr];
}


@end
