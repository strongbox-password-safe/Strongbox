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
#import "SafesList.h"
#import "OneDriveStorageProvider.h"
#import "PinEntryController.h"

@interface PreferencesTableViewController () <MFMailComposeViewControllerDelegate>

@end

@implementation PreferencesTableViewController {
    NSDictionary<NSNumber*, NSNumber*> *_autoLockList;
    NSDictionary<NSNumber*, NSNumber*> *_appLockDelayList;
    NSDictionary<NSNumber*, NSNumber*> *_autoClearClipboardIndex;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.toolbar.hidden = NO;
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
    }
    
    _autoLockList = @{  @-1 : @0,
                        @0 : @1,
                        @60 : @2,
                        @600 :@3 };

    _appLockDelayList = @{ @0 : @0,
                           @60 : @1,
                           @600 :@2 };
    
    _autoClearClipboardIndex = @{   @0 : @0,
                                    @30 : @1,
                                    @60 : @2,
                                    @120 :@3 };
    
    [self.buttonUnlinkDropbox setTitle:@"(No Current Dropbox Session)" forState:UIControlStateDisabled];
    [self.buttonUnlinkDropbox setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    
    [self.buttonSignoutGoogleDrive setTitle:@"(No Current Google Drive Session)" forState:UIControlStateDisabled];
    [self.buttonSignoutGoogleDrive setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];

    [self.buttonSignoutOneDrive setTitle:@"(No Current OneDrive Session)" forState:UIControlStateDisabled];
    [self.buttonSignoutOneDrive setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];

    [self bindUseICloud];
    [self bindAboutButton];
    [self bindLongTouchCopy];
    [self bindAllowPinCodeOpen];
    [self bindAllowBiometric];
    [self bindShowPasswordOnDetails];
    [self bindAutoLock];
    [self bindAutoAddNewLocalSafes];
    [self bindShowKeePass1BackupFolder];
    [self bindHideTips];
    [self bindClearClipboard];
    [self bindAppLock];
    
    [self customizeAppLockSectionFooter];
}

- (void)customizeAppLockSectionFooter {
    [self.segmentAppLock setTitle:[Settings.sharedInstance getBiometricIdName] forSegmentAtIndex:2];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];

    self.navigationController.toolbar.hidden = YES;
    
    self.buttonUnlinkDropbox.enabled = (DBClientsManager.authorizedClient != nil);
    self.buttonSignoutGoogleDrive.enabled =  [[GoogleDriveManager sharedInstance] isAuthorized];
    self.buttonSignoutOneDrive.enabled = [[OneDriveStorageProvider sharedInstance] isSignedIn];
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

- (IBAction)onAllowPinCodeOpen:(id)sender {
    Settings.sharedInstance.disallowAllPinCodeOpens = !self.switchAllowPinCodeOpen.on;
    
    [self bindAllowPinCodeOpen];
}

- (IBAction)onAllowBiometric:(id)sender {
    NSLog(@"Setting Allow Biometric Id to %d", self.switchAllowBiometric.on);
    
    Settings.sharedInstance.disallowAllBiometricId = !self.switchAllowBiometric.on;
    
    [self bindAllowBiometric];
}

- (void)bindShowKeePass1BackupFolder {
    self.switchShowKeePass1BackupFolder.on = [[Settings sharedInstance] showKeePass1BackupGroup];
}

- (IBAction)onShowKeePass1BackupFolder:(id)sender {
    NSLog(@"Setting ShowKeePass1BackupFolder to %d", self.switchShowKeePass1BackupFolder.on);

    Settings.sharedInstance.showKeePass1BackupGroup = !self.switchShowKeePass1BackupFolder.on;

    [self bindShowKeePass1BackupFolder];
}

- (void)bindHideTips {
    self.switchHideTips.on = Settings.sharedInstance.hideTips;
}

- (IBAction)onHideTips:(id)sender {
    Settings.sharedInstance.hideTips = self.switchHideTips.on;
    [self bindHideTips];
}

- (IBAction)onHowTo:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://strongboxsafe.com/how-to-guide"]];
}

- (IBAction)onFaq:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://strongboxsafe.com/faq"]];
}

- (IBAction)onPrivacyPolicy:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://strongboxsafe.com/privacy-policy"]];
}

- (void)bindAllowPinCodeOpen {
    self.switchAllowPinCodeOpen.on = !Settings.sharedInstance.disallowAllPinCodeOpens;
}

- (void)bindAllowBiometric {
    self.labelAllowBiometric.text = [NSString stringWithFormat:@"Allow %@ Open", [Settings.sharedInstance getBiometricIdName]];
    self.switchAllowBiometric.on = !Settings.sharedInstance.disallowAllBiometricId;
}

- (void)bindShowPasswordOnDetails {
    self.switchShowPasswordOnDetails.on = [[Settings sharedInstance] isShowPasswordByDefaultOnEditScreen];
}

- (void)bindAutoAddNewLocalSafes {
    self.switchAutoAddNewLocalSafes.on = !Settings.sharedInstance.doNotAutoAddNewLocalSafes;
}

- (IBAction)onShowPasswordOnDetails:(id)sender {
    NSLog(@"Setting showPasswordOnDetails to %d", self.switchShowPasswordOnDetails.on);
    
    [[Settings sharedInstance] setShowPasswordByDefaultOnEditScreen:self.switchShowPasswordOnDetails.on];
    
    [self bindShowPasswordOnDetails];
}

- (IBAction)onAutoAddNewLocalSafesChanged:(id)sender {
    NSLog(@"Setting doNotAutoAddNewLocalSafes to %d", !self.switchAutoAddNewLocalSafes.on);
    
    Settings.sharedInstance.doNotAutoAddNewLocalSafes = !self.switchAutoAddNewLocalSafes.on;
    
    [self bindAutoAddNewLocalSafes];
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

- (IBAction)onSegmentClearClipboardChanged:(id)sender {
    NSArray<NSNumber *> *keys = [_autoClearClipboardIndex allKeysForObject:@(self.segmentAutoClearClipboard.selectedSegmentIndex)];
    NSNumber *seconds = keys[0];
    
    Settings.sharedInstance.clearClipboardEnabled = seconds.integerValue != 0;
    Settings.sharedInstance.clearClipboardAfterSeconds = seconds.integerValue;
    
    [self bindClearClipboard];
}

- (void)bindClearClipboard {
    NSInteger seconds = Settings.sharedInstance.clearClipboardAfterSeconds;
    BOOL enabled = Settings.sharedInstance.clearClipboardEnabled;

    NSLog(@"clearClipboard: [%d, %ld]", enabled, (long)seconds);
    
    if(!enabled) {
        seconds = 0;
    }
    
    NSNumber* index = [_autoClearClipboardIndex objectForKey:@(seconds)];
    index = index == nil ? @(2) : index;
    [self.segmentAutoClearClipboard setSelectedSegmentIndex:index.integerValue];
}

- (IBAction)onAppLockChanged:(id)sender {
    if(self.segmentAppLock.selectedSegmentIndex == kPinCode) {
        PinEntryController *vc1 = [[PinEntryController alloc] init];
        vc1.info = @"Please Enter a PIN";
        vc1.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(response == kOk) {
                    PinEntryController *vc2 = [[PinEntryController alloc] init];
                    vc2.info = @"Please Confirm Your PIN";
                    vc2.onDone = ^(PinEntryResponse response2, NSString * _Nullable confirmPin) {
                        [self dismissViewControllerAnimated:YES completion:^{
                            if(response2 == kOk) {
                                if ([pin isEqualToString:confirmPin]) {
                                    Settings.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
                                    Settings.sharedInstance.appLockPin = pin;
                                    [self bindAppLock];
                                }
                                else {
                                    [Alerts warn:self title:@"PINs do not match" message:@"Your PINs do not match. You can try again from Safe Settings." completion:nil];
                                    [self bindAppLock];
                                }
                            }
                            else {
                                [self bindAppLock];
                            }
                        }];
                    };
                    
                    [self presentViewController:vc2 animated:YES completion:nil];
                }
                else {
                    [self bindAppLock];
                }
            }];
        };
        
        [self presentViewController:vc1 animated:YES completion:nil];
    }
    else {
        Settings.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
        [self bindAppLock];
    }
}

- (IBAction)onAppLockDelayChanged:(id)sender {
    NSArray<NSNumber *> *keys = [_appLockDelayList allKeysForObject:@(self.segmentAppLockDelay.selectedSegmentIndex)];
    NSNumber *seconds = keys[0];
    
    Settings.sharedInstance.appLockDelay = seconds.integerValue;
    
    [self bindAppLock];
}

- (void)bindAppLock {
    NSInteger mode = Settings.sharedInstance.appLockMode;
    NSNumber* seconds = @(Settings.sharedInstance.appLockDelay);
    NSNumber* index = [_appLockDelayList objectForKey:seconds];
    
    [self.segmentAppLock setSelectedSegmentIndex:mode];
    [self.segmentAppLockDelay setSelectedSegmentIndex:index.integerValue];
    
    NSLog(@"AppLock: [%ld] - [%@]", (long)mode, seconds);
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

- (IBAction)onSignoutOneDrive:(id)sender {
    if ([OneDriveStorageProvider.sharedInstance isSignedIn]) {
        [Alerts yesNo:self
                title:@"Sign out of OneDrive?"
              message:@"Are you sure you want to sign out of One Drive?"
               action:^(BOOL response) {
                   if (response) {
                       [OneDriveStorageProvider.sharedInstance signout:^(NSError *error) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                               if(!error) {
                                   self.buttonSignoutOneDrive.enabled = NO;
                                   [Alerts info:self
                                          title:@"Signout Successful"
                                        message:@"You have successfully signed out of OneDrive."];
                               }
                               else {
                                   [Alerts error:self title:@"Error Signing out of OneDrive" error:error];
                               }
                           });
                       }];
                   }
               }];
   }
}

- (BOOL)hasLocalOrICloudSafes {
    return ([SafesList.sharedInstance getSafesOfProvider:kLocalDevice].count + [SafesList.sharedInstance getSafesOfProvider:kiCloud].count) > 0;
}

- (IBAction)onUseICloud:(id)sender {
    NSLog(@"Setting iCloudOn to %d", self.switchUseICloud.on);
    
    NSString *biometricIdName = [[Settings sharedInstance] getBiometricIdName];
    if([self hasLocalOrICloudSafes]) {
        [Alerts yesNo:self title:@"Master Password Warning"
              message:[NSString stringWithFormat:@"It is very important that you know your master password for your safes, and that you are not relying entirely on %@.\n"
                     @"The migration and importation process makes every effort to maintain %@ data but it is not guaranteed. "
                     @"In any case it is important that you always know your master passwords.\n\n"
                     @"Do you want to continue changing iCloud usage settings?", biometricIdName, biometricIdName]
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
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSString *thisSafe = [NSString stringWithFormat:@"%d. [%@]<br />   [%@]-[%@]-[%d%d%d%d%d]<br />", i++,
                              safe.nickName,
                              safe.fileName,
                              safe.fileIdentifier,
                              safe.storageProvider,
                              safe.isTouchIdEnabled,
                              safe.isEnrolledForConvenience,
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
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;
    
    NSString* message = [NSString stringWithFormat:@"I'm having some trouble with Strongbox Password Safe... <br /><br />"
                         @"Please include as much detail as possible and screenshots if appropriate...<br /><br />"
                         @"Here is some debug information which might help:<br />"
                         @"%@<br />"
                         @"Model: %@<br />"
                         @"System Name: %@<br />"
                         @"System Version: %@<br />"
                         @"Ep: %ld<br />"
                         @"Flags: %@%@%@", safesMessage, model, systemName, systemVersion, epoch, pro, isFreeTrial, [Settings.sharedInstance getFlagsStringForDiagnostics]];
    
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

- (IBAction)onBecomeAPatron:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.patreon.com/strongboxpasswordsafe"]];
}

@end
