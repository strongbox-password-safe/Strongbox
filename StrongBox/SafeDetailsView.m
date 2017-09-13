//
//  SafeDetailsView.m
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "SafeDetailsView.h"
#import "JNKeychain.h"
#import "IOsUtils.h"
#import <MessageUI/MessageUI.h>
#import "Alerts.h"
#import "ISMessages/ISMessages.h"

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
    self.labelKeyStretchIterations.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.keyStretchIterations];
    self.labelNumberOfUniqueUsernames.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.usernameSet count]];
    self.labelNumberOfUniquePasswords.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.passwordSet count]];
    self.labelNumberOfGroups.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.numberOfGroups];
    self.labelNumberOfRecords.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.numberOfRecords];
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
                [JNKeychain         saveValue:self.viewModel.masterPassword
                                       forKey:self.viewModel.metadata.nickName];
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
    self.labelToggleTouchId.text = self.viewModel.metadata.isTouchIdEnabled ? @"Disable Touch ID" : @"Enable Touch ID";
}

- (void)updateOfflineCacheButtonText {
    self.labelToggleOfflineCache.text = self.viewModel.metadata.offlineCacheEnabled ? @"Disable Offline Cache" : @"Enable Offline Cache";
}

- (void)onToggleTouchId {
    if (self.viewModel.metadata.isTouchIdEnabled) {
        NSString *message = self.viewModel.metadata.isEnrolledForTouchId ?
        @"Disabling Touch ID for this safe will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?" :
        @"Are you sure you want to disable Touch ID for this safe?";
        
        [Alerts yesNo:self
                title:@"Disable Touch ID?"
              message:message
               action:^(BOOL response) {
                   if (response) {
                       self.viewModel.metadata.isTouchIdEnabled = NO;
                       self.viewModel.metadata.isEnrolledForTouchId = NO;
                       
                       [JNKeychain deleteValueForKey:self.viewModel.metadata.nickName];
                       
                       [[SafesCollection sharedInstance] save];
                       [self updateTouchIdButtonText];
                       
                       [ISMessages showCardAlertWithTitle:@"Touch ID Disabled"
                                                  message:@"Touch ID for this safe has been disabled."
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
        [JNKeychain deleteValueForKey:self.viewModel.metadata.nickName];
        
        [ISMessages showCardAlertWithTitle:@"Touch ID Enabled"
                                   message:@"Touch ID has been enabled for this safe. You will be asked to enrol the next time you open it."
                                  duration:3.f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeSuccess
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];
    }
    
    [self updateTouchIdButtonText];
    [[SafesCollection sharedInstance] save];
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
    [self.viewModel encrypt:^(NSData * _Nullable safeData, NSError * _Nullable error) {
        if(!safeData) {
            [Alerts error:self title:@"Could not get safe data" error:error];
            return;
        }
        
        if(![MFMailComposeViewController canSendMail]) {
            [Alerts info:self
                   title:@"Email Not Available"
                 message:@"It looks like email is not setup on this device and so the safe cannot be exported by email."];
            
            return;
        }
        
        MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
        
        [picker setSubject:[NSString stringWithFormat:@"Strongbox Safe: '%@'", self.viewModel.metadata.nickName]];
        
        NSString *attachmentName = [NSString stringWithFormat:@"%@%@", self.viewModel.metadata.fileName,
                                    ([self.viewModel.metadata.fileName hasSuffix:@".dat"] || [self.viewModel.metadata.fileName hasSuffix:@"psafe3"]) ? @"" : @".dat"];
        
        [picker addAttachmentData:safeData mimeType:@"application/octet-stream" fileName:attachmentName];
        
        [picker setToRecipients:[NSArray array]];
        [picker setMessageBody:[NSString stringWithFormat:@"Here's a copy of my '%@' Strongbox password safe.", self.viewModel.metadata.nickName] isHTML:NO];
        picker.mailComposeDelegate = self;
        
        [self presentViewController:picker animated:YES completion:^{ }];
    }];
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

