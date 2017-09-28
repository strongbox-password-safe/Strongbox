//
//  PreferencesTableViewController.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "PreferencesTableViewController.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "GoogleDriveManager.h"
#import "Alerts.h"
#import "Utils.h"
#import "Settings.h"
#import <MessageUI/MessageUI.h>
#import "SafesCollection.h"

@interface PreferencesTableViewController () <MFMailComposeViewControllerDelegate>

@end

@implementation PreferencesTableViewController {
    NSDictionary<NSNumber*, NSNumber*> *_autoLockList;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.toolbar.hidden = NO;
    
    _autoLockList = @{  @-1 : @0,
                        @0 : @1,
                        @60 : @2,
                        @600 :@3 };
    
    [self.buttonUnlinkDropbox setTitle:@"(No Current Dropbox Session)" forState:UIControlStateDisabled];
    [self.buttonUnlinkDropbox setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    
    [self.buttonSignoutGoogleDrive setTitle:@"(No Current Google Drive Session)" forState:UIControlStateDisabled];
    [self.buttonSignoutGoogleDrive setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];

    [self bindUseICloud];
    [self bindAboutButton];
    [self bindLongTouchCopy];
    [self bindShowPasswordOnDetails];
    [self bindAutoLock];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.buttonUnlinkDropbox.enabled = (DBClientsManager.authorizedClient != nil);
    self.buttonSignoutGoogleDrive.enabled =  [[GoogleDriveManager sharedInstance] isAuthorized];
}

- (void)bindAboutButton {
    NSString *aboutString;
    if([[Settings sharedInstance] isPro]) {
        aboutString = [NSString stringWithFormat:@"Version %@", [Utils getAppVersion]];
    }
    else {
        if([[Settings sharedInstance] isFreeTrial]) {
            aboutString = [NSString stringWithFormat:@"Version %@ (Trial - %ld Days Left)",
                           [Utils getAppVersion], (long)[[Settings sharedInstance] getFreeTrialDaysRemaining]];
        }
        else {
            aboutString = [NSString stringWithFormat:@"Version %@ (Lite - Please Upgrade)", [Utils getAppVersion]];
        }
    }
    
    [self.buttonAbout setTitle:aboutString forState:UIControlStateNormal];
    [self.buttonAbout setTitle:aboutString forState:UIControlStateHighlighted];
}

- (void)bindUseICloud {
    self.switchUseICloud.on = [[Settings sharedInstance] iCloudOn] && Settings.sharedInstance.iCloudAvailable;
    self.switchUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
    
    self.labelUseICloud.text = Settings.sharedInstance.iCloudAvailable ? @"Use iCloud" : @"Use iCloud (Unavailable)";
    self.labelUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
}

- (void)bindLongTouchCopy {
    self.switchLongTouchCopy.on = [[Settings sharedInstance] isCopyPasswordOnLongPress];
}

- (IBAction)onLongTouchCopy:(id)sender {
    NSLog(@"Setting longTouchCopyEnabled to %d", self.switchLongTouchCopy.on);
     
    [[Settings sharedInstance] setCopyPasswordOnLongPress:self.switchLongTouchCopy.on];
     
    [self bindLongTouchCopy];
}

- (void)bindShowPasswordOnDetails {
    self.switchShowPasswordOnDetails.on = [[Settings sharedInstance] isShowPasswordByDefaultOnEditScreen];
}

- (IBAction)onShowPasswordOnDetails:(id)sender {
    NSLog(@"Setting showPasswordOnDetails to %d", self.switchShowPasswordOnDetails.on);
    
    [[Settings sharedInstance] setShowPasswordByDefaultOnEditScreen:self.switchShowPasswordOnDetails.on];
    
    [self bindShowPasswordOnDetails];
}

- (IBAction)onSegmentAutoLockChanged:(id)sender {
    NSArray<NSNumber *> *keys = [_autoLockList allKeysForObject:@(self.segmentAutoLock.selectedSegmentIndex)];
    NSNumber *seconds = keys[0];

    NSLog(@"Setting Auto Lock Time to %@ Seconds", seconds);
    
    [[Settings sharedInstance] setAutoLockTimeoutSeconds: seconds];

    [self bindAutoLock];
}

-(void)bindAutoLock {
    NSNumber* seconds = [[Settings sharedInstance] getAutoLockTimeoutSeconds];
    NSNumber* index = [_autoLockList objectForKey:seconds];
    [self.segmentAutoLock setSelectedSegmentIndex:index.integerValue];
}

- (IBAction)onUnlinkDropbox:(id)sender {
    if (DBClientsManager.authorizedClient) {
        [Alerts yesNo:self
                title:@"Unlink Dropbox?"
              message:@"Are you sure you want to unlink Strongbox from Dropbox?"
               action:^(BOOL response) {
                   if (response) {
                       [DBClientsManager unlinkAndResetClients];
                       self.buttonUnlinkDropbox.enabled = NO;
                       
                       [Alerts info:self
                              title:@"Unlink Successful"
                            message:@"You have successfully unlinked Strongbox from Dropbox."];
                   }
               }];
    }
}


- (BOOL)hasLocalOrICloudSafes {
    return ([SafesCollection.sharedInstance getSafesOfProvider:kLocalDevice].count + [SafesCollection.sharedInstance getSafesOfProvider:kiCloud].count) > 0;
}

- (IBAction)onUseICloud:(id)sender {
    NSLog(@"Setting iCloudOn to %d", self.switchUseICloud.on);
    
    if([self hasLocalOrICloudSafes]) {
        [Alerts yesNo:self title:@"Master Password Warning"
             message:@"It is very important that you know your master password for your safes, and that you are not relying entirely on Touch ID.\n"
                     @"The migration and importation process makes every effort to maintain Touch ID data but it is not guaranteed. "
                     @"In any case it is important that you always know your master passwords.\n\n"
                     @"Do you want to continue changing iCloud usage settings?"
              action:^(BOOL response) {
            if(response) {
                [[Settings sharedInstance] setICloudOn:self.switchUseICloud.on];
                
                [self bindUseICloud];
            }
            else {
                self.switchUseICloud.on = !self.switchUseICloud.on;
            }
        }];
    }
    else {
        [[Settings sharedInstance] setICloudOn:self.switchUseICloud.on];
        
        [self bindUseICloud];
    }
}

- (IBAction)onSignoutGoogleDrive:(id)sender {
    if ([[GoogleDriveManager sharedInstance] isAuthorized]) {
        [Alerts yesNo:self
                title:@"Sign Out of Google Drive?"
              message:@"Are you sure you want to sign out of Google Drive?"
               action:^(BOOL response) {
                   if (response) {
                       [[GoogleDriveManager sharedInstance] signout];
                       self.buttonSignoutGoogleDrive.enabled = NO;
                       
                       [Alerts info:self
                              title:@"Sign Out Successful"
                            message:@"You have been successfully been signed out of Google Drive."];
                   }
               }];
    }
}

- (IBAction)onContactSupport:(id)sender {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:@"Email Not Available"
             message:@"It looks like email is not setup on this device.\n\nContact support@strongboxsafe.com for help."];
        
        return;
    }
    
    int i=0;
    NSString *safesMessage = @"Safes Collection<br />----------------<br />";
    for(SafeMetaData *safe in [SafesCollection sharedInstance].sortedSafes) {
        NSString *thisSafe = [NSString stringWithFormat:@"%d. [%@]<br />   [%@]-[%@]-[%d%d%d%d%d]<br />", i++,
                              safe.nickName,
                              safe.fileName,
                              safe.fileIdentifier,
                              safe.storageProvider,
                              safe.isTouchIdEnabled,
                              safe.isEnrolledForTouchId,
                              safe.offlineCacheEnabled,
                              safe.offlineCacheAvailable];
        
        safesMessage = [safesMessage stringByAppendingString:thisSafe];
    }
    safesMessage = [safesMessage stringByAppendingString:@"----------------"];

    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[Settings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[Settings sharedInstance] isFreeTrial] ? @"F" : @"";
    
    NSString* message = [NSString stringWithFormat:@"I'm having some trouble with Strongbox Password Safe... <br /><br />"
                         @"Please include as much detail as possible and screenshots if appropriate...<br /><br />"
                         @"Here is some debug information which might help:<br />"
                         @"%@<br />"
                         @"Model: %@<br />"
                         @"System Name: %@<br />"
                         @"System Version: %@<br />"
                         @"Flags: %@%@%@", safesMessage, model, systemName, systemVersion, pro, isFreeTrial, [Settings.sharedInstance getFlagsStringForDiagnostics]];
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    
    [picker setSubject:[NSString stringWithFormat:@"Help with Strongbox %@", [Utils getAppVersion]]];
    [picker setToRecipients:[NSArray arrayWithObjects:@"support@strongboxsafe.com", nil]];
    [picker setMessageBody:message isHTML:YES];
     
    picker.mailComposeDelegate = self;
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
