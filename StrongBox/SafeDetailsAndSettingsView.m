//
//  SafeDetailsAndSettingsView.m
//  StrongBox
//
//  Created by Mark McGuill on 04/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeDetailsAndSettingsView.h"
#import "JNKeychain.h"
#import "IOsUtils.h"
#import <MessageUI/MessageUI.h>
#import "Alerts.h"
#import "ISMessages/ISMessages.h"

@interface SafeDetailsAndSettingsView () <MFMailComposeViewControllerDelegate>

@end

@implementation SafeDetailsAndSettingsView {
    NSString *firstPasswordEntry;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.labelUpdateApp.text = self.viewModel.lastUpdateApp;
    self.labelUpdateHost.text = self.viewModel.lastUpdateHost;
    self.labelUpdateUser.text = self.viewModel.lastUpdateUser;
    self.labelUpdateTime.text = [self formatDate:self.viewModel.lastUpdateTime];

    [self updateTouchIdButtonText];
    [self updateOfflineCacheButtonText];
    
    self.buttonChangeMasterPassword.hidden = (self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache);
    self.buttonTouchId.hidden = ![IOsUtils isTouchIDAvailable] || self.viewModel.isReadOnly;
    self.buttonOfflineCache.hidden = self.viewModel.isUsingOfflineCache || !self.viewModel.isCloudBasedStorage;
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

- (IBAction)onChangeMasterPassword:(id)sender {
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
    NSString *title = self.viewModel.metadata.isTouchIdEnabled ? @"Disable Touch Id" : @"Enable Touch Id";

    [self.buttonTouchId setTitle:title forState:UIControlStateNormal];
    [self.buttonTouchId setTitle:title forState:UIControlStateHighlighted];
}

- (void)updateOfflineCacheButtonText {
    NSString *title = self.viewModel.metadata.offlineCacheEnabled ? @"Disable Offline Cache" : @"Enable Offline Cache";

    [self.buttonOfflineCache setTitle:title forState:UIControlStateNormal];
    [self.buttonOfflineCache setTitle:title forState:UIControlStateHighlighted];
}

- (IBAction)onButtonTouchId:(id)sender {
    if (self.viewModel.metadata.isTouchIdEnabled) {
        NSString *message = self.viewModel.metadata.isEnrolledForTouchId ?
            @"Disabling Touch Id for this safe will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?" :
            @"Are you sure you want to disable Touch Id for this safe?";

        [Alerts yesNo:self
                title:@"Disable Touch Id?"
              message:message
               action:^(BOOL response) {
                   if (response) {
                   self.viewModel.metadata.isTouchIdEnabled = NO;
                   self.viewModel.metadata.isEnrolledForTouchId = NO;

                   [JNKeychain deleteValueForKey:self.viewModel.metadata.nickName];

                   [self.viewModel.safes save];
                   [self updateTouchIdButtonText];

                   [ISMessages showCardAlertWithTitle:@"Touch Id Disabled"
                                           message:@"Touch Id for this safe has been disabled."
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

        [ISMessages showCardAlertWithTitle:@"Touch Id Enabled"
                                   message:@"Touch Id has been enabled for this safe. You will be asked to enrol the next time you open it."
                                  duration:3.f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeSuccess
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];
    }

    [self updateTouchIdButtonText];
    [self.viewModel.safes save];
}

- (IBAction)onToggleOfflineCache:(id)sender {
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

- (IBAction)onExport:(id)sender {
    NSData *safeData = [self.viewModel getSafeAsData];

    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:@"Email Not Available"
             message:@"It looks like email is not setup on this device and so the safe cannot be exported by email."];
        
        return;
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];

    [picker setSubject:[NSString stringWithFormat:@"StrongBox Safe: '%@'", self.viewModel.metadata.nickName]];

    NSString *attachmentName = [NSString stringWithFormat:@"%@%@", self.viewModel.metadata.fileName,
                                ([self.viewModel.metadata.fileName hasSuffix:@".dat"] || [self.viewModel.metadata.fileName hasSuffix:@"psafe3"]) ? @"" : @".dat"];

    [picker addAttachmentData:safeData mimeType:@"application/octet-stream" fileName:attachmentName];

    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:@"Here's a copy of my '%@' StrongBox password safe.", self.viewModel.metadata.nickName] isHTML:NO];
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
        return @"[Unknown]";
    }

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];

    NSString *dateString = [dateFormatter stringFromDate:date];

    return dateString;
}

@end
