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

@interface Delegate : NSObject <CHCSVParserDelegate>
    @property (readonly) NSArray *lines;
@end

@interface SafeDetailsView () <MFMailComposeViewControllerDelegate>

@end

@implementation SafeDetailsView

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateTouchIdButtonText];
    [self updateOfflineCacheButtonText];
    
    self.labelChangeMasterPassword.enabled = [self canChangeMasterPassword];
    self.labelToggleTouchId.enabled = [self canToggleTouchId];
    self.labelToggleOfflineCache.enabled = [self canToggleOfflineCache];
    
    self.labelLastUpdateTime.text = [self formatDate:self.viewModel.lastUpdateTime];
    self.labelVersion.text = self.viewModel.version;
    self.labelLastUser.text = self.viewModel.lastUpdateUser;
    self.labelLastHost.text = self.viewModel.lastUpdateHost;
    self.labelLastApp.text = self.viewModel.lastUpdateApp;
    self.labelMostPopularUsername.text = self.viewModel.mostPopularUsername ? self.viewModel.mostPopularUsername : @"<None>";
    self.labelMostPopularEmail.text = self.viewModel.mostPopularEmail ? self.viewModel.mostPopularEmail : @"<None>";
    self.labelKeyStretchIterations.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.keyStretchIterations];
    self.labelNumberOfUniqueUsernames.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.usernameSet count]];
    self.labelNumberOfUniqueEmails.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.emailSet count]];
    self.labelNumberOfUniquePasswords.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.passwordSet count]];
    self.labelNumberOfGroups.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.numberOfGroups];
    self.labelNumberOfRecords.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.numberOfRecords];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:NO];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        if(indexPath.row == 0 && [self canChangeMasterPassword]) { // Change Master Password {
            [self onChangeMasterPassword];
        }
        else if (indexPath.row == 1 && [self canToggleOfflineCache]) { // Offline Cache
            [self onToggleOfflineCache];
        }
        else if (indexPath.row == 2) { // Export Safe
            [self onExport];
        }
        else if (indexPath.row == 3  && [self canToggleTouchId]) { // Toggle Touch ID
            [self onToggleTouchId];
        }
    }
}

- (BOOL)canChangeMasterPassword {
    return !(self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache);
}

- (BOOL)canToggleTouchId {
    return [IOsUtils isTouchIDAvailable] && !self.viewModel.isReadOnly;
}

- (BOOL)canToggleOfflineCache {
    return !(self.viewModel.isUsingOfflineCache || !self.viewModel.isCloudBasedStorage);
}

- (void)changeMasterPassword:(NSString *)password {
    self.viewModel.masterPassword = password;
    
    [self.viewModel update:^(NSError *error) {
        if (error == nil) {
            if (self.viewModel.metadata.isTouchIdEnabled && self.viewModel.metadata.isEnrolledForTouchId) {
                [self.viewModel.metadata setTouchIdPassword:self.viewModel.masterPassword];
                NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
            }
            
            [ISMessages             showCardAlertWithTitle:@"Master Password Changed"
                                                   message:nil
                                                  duration:3.f
                                               hideOnSwipe:YES
                                                 hideOnTap:YES
                                                 alertType:ISAlertTypeSuccess
                                             alertPosition:ISAlertPositionTop
                                                   didHide:nil];
        }
        else {
            [Alerts             error:self
                                title:@"Master Password NOT Changed!"
                                error:error];
        }
    }];
}

- (void)onChangeMasterPassword {
    Alerts *alerts = [[Alerts alloc] initWithTitle:@"Change Master Password"
                                           message:@"Enter the new password:"];
    
    [alerts OkCancelWithPasswordAndConfirm:self
                                completion:^(NSString *password, BOOL response) {
                                    if (response) {
                                        [self changeMasterPassword:password];
                                    }
                                }];
}

- (void)updateTouchIdButtonText {
    NSString *biometricIdName = [[Settings sharedInstance] getBiometricIdName];
    self.labelToggleTouchId.text = [NSString stringWithFormat:@"%@ %@", self.viewModel.metadata.isTouchIdEnabled ? @"Disable" : @"Enable", biometricIdName];
}

- (void)updateOfflineCacheButtonText {
    self.labelToggleOfflineCache.text = self.viewModel.metadata.offlineCacheEnabled ? @"Disable Offline Cache" : @"Enable Offline Cache";
}

- (void)onToggleTouchId {
    NSString* bIdName = [[Settings sharedInstance] getBiometricIdName];
    
    if (self.viewModel.metadata.isTouchIdEnabled) {
        NSString *message = self.viewModel.metadata.isEnrolledForTouchId ?
        @"Disabling %@ for this safe will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?" :
        @"Are you sure you want to disable %@ for this safe?";
        

        [Alerts yesNo:self
                title:[NSString stringWithFormat:@"Disable %@?", bIdName]
              message:[NSString stringWithFormat:message, bIdName]
               action:^(BOOL response) {
                   if (response) {
                       self.viewModel.metadata.isTouchIdEnabled = NO;
                       self.viewModel.metadata.isEnrolledForTouchId = NO;
                       
                       [self.viewModel.metadata removeTouchIdPassword];
                       
                       [[SafesList sharedInstance] update:self.viewModel.metadata];
                       [self updateTouchIdButtonText];
                       
                       [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"%@ Disabled", bIdName]
                                                  message:[NSString stringWithFormat:@"%@ for this safe has been disabled.", bIdName]
                                                 duration:3.f
                                              hideOnSwipe:YES
                                                hideOnTap:YES
                                                alertType:ISAlertTypeSuccess
                                            alertPosition:ISAlertPositionTop
                                                  didHide:nil];
                   }
               }];
    }
    else {
        self.viewModel.metadata.isTouchIdEnabled = YES;
        self.viewModel.metadata.isEnrolledForTouchId = NO;

        [self.viewModel.metadata removeTouchIdPassword];

        [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"%@ Enabled", bIdName]
                                   message:[NSString stringWithFormat:@"%@ has been enabled for this safe. You will be asked to enrol the next time you open it.", bIdName]
                                  duration:3.f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeSuccess
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];
    }
    
    [self updateTouchIdButtonText];
    [[SafesList sharedInstance] update:self.viewModel.metadata];
}

- (void)onToggleOfflineCache {
    if (self.viewModel.metadata.offlineCacheEnabled) {
        [Alerts yesNo:self
                title:@"Disable Offline Cache?"
              message:@"Disabling Offline Cache for this safe will remove the offline cache and you will not be able to access the safe when offline. Are you sure you want to do this?"
               action:^(BOOL response) {
                   if (response) {
                       [self.viewModel disableAndClearOfflineCache];
                       [self updateOfflineCacheButtonText];
                       
                       [ISMessages showCardAlertWithTitle:@"Offline Cache Disabled"
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
    else {
        [self.viewModel enableOfflineCache];
        [self.viewModel updateOfflineCache:^{
            [self updateOfflineCacheButtonText];
            
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

- (void)onExport {
    [Alerts threeOptions:self title:@"How would you like to export your safe?"
                 message:@"You can export your encrypted safe by email, or you can copy your safe in plaintext format (CSV) to the clipboard."
       defaultButtonText:@"Export (Encrypted) by Email"
        secondButtonText:@"Export as CSV by Email"
         thirdButtonText:@"Copy CSV to Clipboard"
                  action:^(int response) {
        if(response == 0) {
            [self exportEncryptedSafeByEmail];
        }
        else if(response == 1){
            NSData *newStr = [Csv getSafeAsCsv:self.viewModel.rootGroup];

            NSString* attachmentName = [NSString stringWithFormat:@"%@.csv", self.viewModel.metadata.nickName];
            [self composeEmail:attachmentName mimeType:@"text/csv" data:newStr];
        }
        else if(response == 2){
            NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.viewModel.rootGroup] encoding:NSUTF8StringEncoding];

            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = newStr;
            
            [ISMessages showCardAlertWithTitle:@"Safe Copied to Clipboard"
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

- (void)exportEncryptedSafeByEmail {
    [self.viewModel encrypt:^(NSData * _Nullable safeData, NSError * _Nullable error) {
        if(!safeData) {
            [Alerts error:self title:@"Could not get safe data" error:error];
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
             message:@"It looks like email is not setup on this device and so the safe cannot be exported by email."];
        
        return;
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    
    [picker setSubject:[NSString stringWithFormat:@"Strongbox Safe: '%@'", self.viewModel.metadata.nickName]];
    
    [picker addAttachmentData:data mimeType:mimeType fileName:attachmentName];
    
    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:@"Here's a copy of my '%@' Strongbox password safe.", self.viewModel.metadata.nickName] isHTML:NO];
    picker.mailComposeDelegate = self;
    
    [self presentViewController:picker animated:YES completion:^{ }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:^{ }];
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) {
        return @"<Unknown>";
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}

@end

