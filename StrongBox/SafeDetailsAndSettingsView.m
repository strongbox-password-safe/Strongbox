//
//  SafeDetailsAndSettingsView.m
//  StrongBox
//
//  Created by Mark McGuill on 04/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeDetailsAndSettingsView.h"
#import "MBProgressHUD.h"
#import "UIAlertView+Blocks.h"
#import "JNKeychain.h"
#import "IOsUtils.h"
#import <MessageUI/MessageUI.h>

@interface SafeDetailsAndSettingsView () <MFMailComposeViewControllerDelegate>

@end

@implementation SafeDetailsAndSettingsView
{
    NSString* firstPasswordEntry;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.labelUpdateApp.text = self.viewModel.safe.lastUpdateApp;
    self.labelUpdateHost.text = self.viewModel.safe.lastUpdateHost;
    self.labelUpdateUser.text = self.viewModel.safe.lastUpdateUser;
    
    self.labelUpdateTime.text = [self formatDate:self.viewModel.safe.lastUpdateTime];
    
    [self updateTouchIdButtonText];
    [self updateOfflineCacheButtonText];
    
    self.buttonTouchId.hidden = ![IOsUtils isTouchIDAvailable];
    self.buttonOfflineCache.hidden = self.viewModel.isUsingOfflineCache;
}

- (IBAction)onChangeMasterPassword:(id)sender
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Change Master Password" message:@"Enter the new password:" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
    
    alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
    alertView.tag = 1;
    [alertView show];
}

- (void) updateTouchIdButtonText
{
    NSString *title = self.viewModel.metadata.isTouchIdEnabled ? @"Disable Touch Id" : @"Enable Touch Id";
    
    [self.buttonTouchId setTitle:title forState:UIControlStateNormal];
    [self.buttonTouchId setTitle:title forState:UIControlStateHighlighted];
}

- (void) updateOfflineCacheButtonText
{
    NSString *title = self.viewModel.metadata.offlineCacheEnabled ? @"Disable Offline Cache" : @"Enable Offline Cache";
    
    [self.buttonOfflineCache setTitle:title forState:UIControlStateNormal];
    [self.buttonOfflineCache setTitle:title forState:UIControlStateHighlighted];
}

- (IBAction)onButtonTouchId:(id)sender
{
    if(self.viewModel.metadata.isTouchIdEnabled)
    {
        NSString* message = self.viewModel.metadata.isEnrolledForTouchId ? @"Disabling Touch Id for this safe will remove the securely stored password and you will have to enter it again. Are you sure you want to do this?" : @"Are you sure you want to disable Touch Id for this safe?";
        
        [UIAlertView showWithTitle:@"Disable Touch Id?" message:message cancelButtonTitle:@"No" otherButtonTitles:@[@"Yes"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
        {
            if(buttonIndex == 1){
                self.viewModel.metadata.isTouchIdEnabled = NO;
                self.viewModel.metadata.isEnrolledForTouchId = NO;
                
                [JNKeychain deleteValueForKey:self.viewModel.metadata.nickName];
                
                [self.viewModel.safes save];
                
                [UIAlertView showWithTitle:@"Touch Id Disabled" message:
                 @"Touch Id for this safe has been disabled."
                         cancelButtonTitle:@"Got it" otherButtonTitles:@[] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex){}];
                
                [self updateTouchIdButtonText];
            }
        }];
    }
    else
    {
        self.viewModel.metadata.isTouchIdEnabled = YES;
        self.viewModel.metadata.isEnrolledForTouchId = NO;
        [JNKeychain deleteValueForKey:self.viewModel.metadata.nickName];
        
        [UIAlertView showWithTitle:@"Touch Id Enabled" message:
         @"Touch Id has been enabled for this safe. You will be asked to enrol the next time you open it." cancelButtonTitle:@"Got it" otherButtonTitles:@[] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex){}];
    }
    
    [self updateTouchIdButtonText];
    [self.viewModel.safes save];
}

- (IBAction)onToggleOfflineCache:(id)sender
{
    if(self.viewModel.metadata.offlineCacheEnabled)
    {
        [UIAlertView showWithTitle:@"Disable Offline Cache?" message:@"Disabling Offline Cache for this safe will remove the offline cache and you will not be able to access the safe when offline. Are you sure you want to do this?" cancelButtonTitle:@"No" otherButtonTitles:@[@"Yes"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
         {
             if(buttonIndex == 1){
                 [self.viewModel disableAndClearOfflineCache];
                 [self updateOfflineCacheButtonText];
             }
         }];
    }
    else
    {
        [self.viewModel enableOfflineCache];
        
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        
        [self.viewModel updateOfflineCache:^{
            [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
            
            [self updateOfflineCacheButtonText];
            
            [UIAlertView showWithTitle:@"Offline Cache Enabled"
                                       message:@"The Offline Cache has been enabled for this safe."
                             cancelButtonTitle:@"OK" otherButtonTitles:@[] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex){  }];
        }];
    }
}

- (IBAction)onExport:(id)sender
{
    NSData *safeData = [self.viewModel.safe getAsData];
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    [picker setSubject:[NSString stringWithFormat:@"StrongBox Safe: '%@'", self.viewModel.metadata.nickName]];
    
    NSString *attachmentName = [NSString stringWithFormat:@"%@%@",self.viewModel.metadata.fileName,
                                ([self.viewModel.metadata.fileName hasSuffix:@".dat"] || [self.viewModel.metadata.fileName hasSuffix:@"psafe3"]) ? @"" : @".dat"];
    
    [picker addAttachmentData:safeData mimeType:@"application/octet-stream" fileName:attachmentName];
    
    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:@"Here's a copy of my '%@' StrongBox password safe.", self.viewModel.metadata.nickName] isHTML:NO];
    [picker setMailComposeDelegate:self];
    
    [self presentViewController:picker animated:YES completion:^{ }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:^{ }];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        if(alertView.tag == 1)
        {
            UITextField *passwordTextField = [alertView textFieldAtIndex:0];
            
            firstPasswordEntry = passwordTextField.text;
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Change Master Password" message:@"Please confirm the new password:" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
                
            alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
            alertView.tag = 2;
                
            [alertView show];
        }
        else if (alertView.tag == 2)
        {
            UITextField *passwordTextField = [alertView textFieldAtIndex:0];
            
            if([firstPasswordEntry isEqualToString:passwordTextField.text])
            {
                [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                
                self.viewModel.safe.masterPassword = firstPasswordEntry;
                
                [self.viewModel update:self completionHandler:^(NSError *error) {
                    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                    
                    if(error == nil)
                    {
                        if(self.viewModel.metadata.isTouchIdEnabled && self.viewModel.metadata.isEnrolledForTouchId)
                        {
                            [JNKeychain saveValue:self.viewModel.safe.masterPassword forKey:self.viewModel.metadata.nickName];
                            NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
                        }
                        
                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Master Password Changed" message:@"The Master Password has been changed." delegate:self cancelButtonTitle:@"Awesome!" otherButtonTitles:nil];
                        alertView.tag = 3;
                        [alertView show];
                    }
                    else
                    {
                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Master Password NOT Changed" message:@"There was an error changing the Master Password." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                        [alertView show];
                    }
                }];
            }
            else
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Passwords Don't Match" message:@"The two passwords you entered do not match." delegate:self cancelButtonTitle:@"Oops" otherButtonTitles:nil];
                alertView.tag = 3;
                [alertView show];
            }
        }
    }
}

-(NSString*)formatDate:(NSDate*)date
{
    if(!date)
    {
        return @"[Unknown]";
    }
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}

@end
