//
//  PreferencesTableViewController.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "PreferencesTableViewController.h"
#import "Alerts.h"
#import "Utils.h"
#import "Settings.h"
#import <MessageUI/MessageUI.h>
#import "SafesList.h"
#import "PinEntryController.h"
#import "NSArray+Extensions.h"
#import "AutoFillManager.h"
#import "SelectStringViewController.h"

#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "GoogleDriveManager.h"
#import "OneDriveStorageProvider.h"

@interface PreferencesTableViewController () <MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFavIcon;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoDetectKeyFiles;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInSearch;
@property (weak, nonatomic) IBOutlet UISwitch *switchCopyTotpAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseQuickTypeAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *switchViewDereferenced;
@property (weak, nonatomic) IBOutlet UISwitch *switchSearchDereferenced;
@property (weak, nonatomic) IBOutlet UISwitch *hideEmptyFields;
@property (weak, nonatomic) IBOutlet UISwitch *easyReadFontForAll;
@property (weak, nonatomic) IBOutlet UISwitch *instantPinUnlock;
@property (weak, nonatomic) IBOutlet UISwitch *showChildCountOnFolder;
@property (weak, nonatomic) IBOutlet UISwitch *showFlagsInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *showUsernameInBrowse;

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAutoClearClipboard;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAppLock;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAppLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *appLockOnPreferences;

@property (weak, nonatomic) IBOutlet UISwitch *switchDeleteDataEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDeleteDataAttempts;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCloudSessions;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutVersion;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutHelp;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmailSupport;

@end

@implementation PreferencesTableViewController {
    NSDictionary<NSNumber*, NSNumber*> *_autoLockList;
    NSDictionary<NSNumber*, NSNumber*> *_appLockDelayList;
    NSDictionary<NSNumber*, NSNumber*> *_autoClearClipboardIndex;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onGenericPreferencesChanged:(id)sender {
    NSLog(@"Generic Preference Changed: [%@]", sender);

    Settings.sharedInstance.hideEmptyFieldsInDetailsView = self.hideEmptyFields.on;
    Settings.sharedInstance.easyReadFontForAll = self.easyReadFontForAll.on;
    Settings.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    Settings.sharedInstance.showChildCountOnFolderInBrowse = self.showChildCountOnFolder.on;
    Settings.sharedInstance.showUsernameInBrowse = self.showUsernameInBrowse.on;
    Settings.sharedInstance.showFlagsInBrowse = self.showFlagsInBrowse.on;
    Settings.sharedInstance.appLockAppliesToPreferences = self.appLockOnPreferences.on;
    
    [self bindGenericPreferencesChanged];
}

- (void)bindGenericPreferencesChanged {
    self.hideEmptyFields.on = Settings.sharedInstance.hideEmptyFieldsInDetailsView;
    self.easyReadFontForAll.on = Settings.sharedInstance.easyReadFontForAll;
    self.instantPinUnlock.on = Settings.sharedInstance.instantPinUnlocking;
    self.showChildCountOnFolder.on = Settings.sharedInstance.showChildCountOnFolderInBrowse;
    self.showUsernameInBrowse.on = Settings.sharedInstance.showUsernameInBrowse;
    self.showFlagsInBrowse.on = Settings.sharedInstance.showFlagsInBrowse;
    self.appLockOnPreferences.on = Settings.sharedInstance.appLockAppliesToPreferences;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)bindViewDereferenced {
    self.switchViewDereferenced.on = Settings.sharedInstance.viewDereferencedFields;
}

- (void)bindSearchDereferenced {
    self.switchSearchDereferenced.on = Settings.sharedInstance.searchDereferencedFields;
}

- (IBAction)onViewDereferenced:(id)sender {
    NSLog(@"Setting viewDereferencedFields to %d", self.switchViewDereferenced.on);

    Settings.sharedInstance.viewDereferencedFields = self.switchViewDereferenced.on;
    [self bindViewDereferenced];
}

- (IBAction)onSearchDereferenced:(id)sender {
    NSLog(@"Setting searchDereferencedFields to %d", self.switchSearchDereferenced.on);

    Settings.sharedInstance.searchDereferencedFields = self.switchSearchDereferenced.on;
    [self bindSearchDereferenced];
}

- (IBAction)onUseQuickTypeAutoFill:(id)sender {
    NSLog(@"Setting doNotUseQuickTypeAutoFill to %d", !self.switchUseQuickTypeAutoFill.on);
    Settings.sharedInstance.doNotUseQuickTypeAutoFill = !self.switchUseQuickTypeAutoFill.on;
    
    if(!self.switchUseQuickTypeAutoFill.on) {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }
    
    [self bindQuickTypeAutoFill];
}

- (void)bindQuickTypeAutoFill {
    self.switchUseQuickTypeAutoFill.on = !Settings.sharedInstance.doNotUseQuickTypeAutoFill;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.toolbar.hidden = NO;
    self.navigationController.toolbarHidden = NO;

    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
    }
    
    _autoLockList = @{  @-1 : @0,
                        @0 : @1,
                        @60 : @2,
                        @600 :@3 };

    _appLockDelayList = @{ @0 : @0,
                           @60 : @1,
                           @180 : @2,
                           @300 : @3,
                           @600 : @4 };
    
    _autoClearClipboardIndex = @{   @0 : @0,
                                    @30 : @1,
                                    @60 : @2,
                                    @120 :@3 };
    
    [self bindCloudSessions];
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
    [self bindHideTotp];
    [self bindKeePassNoSorting];
    [self bindAutoFavIcon];
    [self bindAutoDetectKeyFiles];
    [self bindShowRecycleBin];
    [self bindCopyTotpAutoFill];
    [self bindQuickTypeAutoFill];
    [self bindViewDereferenced];
    [self bindSearchDereferenced];
    [self bindAppLock];
    [self bindDeleteOnFailedUnlock];
    
    [self customizeAppLockSectionFooter];
    
    [self bindGenericPreferencesChanged];
}

- (void)customizeAppLockSectionFooter {
    [self.segmentAppLock setEnabled:[Settings isBiometricIdAvailable] forSegmentAtIndex:2];
    [self.segmentAppLock setTitle:[Settings.sharedInstance getBiometricIdName] forSegmentAtIndex:2];
    [self.segmentAppLock setEnabled:[Settings isBiometricIdAvailable] forSegmentAtIndex:3]; // Both
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];

    self.navigationController.toolbar.hidden = YES;
    
    [self bindCloudSessions];
}

- (void)bindAboutButton {
    NSString *aboutString;
    if([[Settings sharedInstance] isPro]) {
        aboutString = [NSString stringWithFormat:@"Version %@", [Utils getAppVersion]];
    }
    else {
        if([[Settings sharedInstance] isFreeTrial]) {
            aboutString = [NSString stringWithFormat:@"Version %@ (Trial - %ld days left)",
                           [Utils getAppVersion], (long)[[Settings sharedInstance] getFreeTrialDaysRemaining]];
        }
        else {
            aboutString = [NSString stringWithFormat:@"Version %@ (Lite - Please Upgrade)", [Utils getAppVersion]];
        }
    }
    
    self.cellAboutVersion.textLabel.text = aboutString;
}

- (void)bindCloudSessions {
    int cloudSessionCount = 0;
    cloudSessionCount += [[GoogleDriveManager sharedInstance] isAuthorized] ? 1 : 0;
    cloudSessionCount += (DBClientsManager.authorizedClient != nil) ? 1 : 0;
    cloudSessionCount += [[OneDriveStorageProvider sharedInstance] isSignedIn] ? 1 : 0;

    self.cellCloudSessions.userInteractionEnabled = (cloudSessionCount > 0);
    self.cellCloudSessions.textLabel.enabled = (cloudSessionCount > 0);
    self.cellCloudSessions.textLabel.text = (cloudSessionCount > 0) ? [NSString stringWithFormat:@"Native Cloud Sessions (%d)", cloudSessionCount] : @"No Sessions";
    
    self.switchUseICloud.on = [[Settings sharedInstance] iCloudOn] && Settings.sharedInstance.iCloudAvailable;
    self.switchUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
    
    self.labelUseICloud.text = Settings.sharedInstance.iCloudAvailable ? @"Use iCloud" : @"Use iCloud (Unavailable)";
    self.labelUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
}

- (void)bindAutoDetectKeyFiles {
    self.switchAutoDetectKeyFiles.on = !Settings.sharedInstance.doNotAutoDetectKeyFiles;
}

- (IBAction)onAutoDetectKeyFiles:(id)sender {
    NSLog(@"Setting autoDetectKeyFiles to %d", self.switchAutoDetectKeyFiles.on);
    
    Settings.sharedInstance.doNotAutoDetectKeyFiles = !self.switchAutoDetectKeyFiles.on;

    [self bindAutoDetectKeyFiles];
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
    if(self.switchAllowPinCodeOpen.on) {
        Settings.sharedInstance.disallowAllPinCodeOpens = !self.switchAllowPinCodeOpen.on;
        [self bindAllowPinCodeOpen];
    }
    else {
        [Alerts yesNo:self title:@"Clear PIN Codes" message:@"This will clear any existing databases with stored Master Credentials that are backed by PIN Codes" action:^(BOOL response) {
            if(response) {
                Settings.sharedInstance.disallowAllPinCodeOpens = !self.switchAllowPinCodeOpen.on;
                
                // Clear any Convenience Enrolled PIN Using Safes
                
                NSArray<SafeMetaData*>* clear = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
                    return obj.conveniencePin != nil && obj.isEnrolledForConvenience;
                }];
                
                for (SafeMetaData* safe in clear) {
                    safe.isEnrolledForConvenience = NO;
                    safe.isTouchIdEnabled = NO;
                    safe.convenienceMasterPassword = nil;
                    safe.convenenienceKeyFileDigest = nil;
                    safe.conveniencePin = nil;
                    safe.duressPin = nil;
                    safe.hasBeenPromptedForConvenience = NO; // If switched back on we can ask if they want to enrol
                    
                    [SafesList.sharedInstance update:safe];
                }
                
                [self bindAllowPinCodeOpen];
            }
        }];
    }
}

- (IBAction)onAllowBiometric:(id)sender {
    if(self.switchAllowBiometric.on) {
        NSLog(@"Setting Allow Biometric Id to %d", self.switchAllowBiometric.on);
        
        Settings.sharedInstance.disallowAllBiometricId = !self.switchAllowBiometric.on;
        
        [self bindAllowBiometric];
    }
    else {
        [Alerts yesNo:self title:@"Clear Biometrics" message:@"This will clear any existing databases with stored Master Credentials that are backed by Biometric Open. Are you sure?" action:^(BOOL response) {
            if(response) {
                NSLog(@"Setting Allow Biometric Id to %d", self.switchAllowBiometric.on);
                
                Settings.sharedInstance.disallowAllBiometricId = !self.switchAllowBiometric.on;
                
                // Clear any Convenience Enrolled Biometric Using Safes
                
                NSArray<SafeMetaData*>* clear = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
                    return obj.isTouchIdEnabled && obj.isEnrolledForConvenience;
                }];
                
                for (SafeMetaData* safe in clear) {
                    safe.isEnrolledForConvenience = NO;
                    safe.convenienceMasterPassword = nil;
                    safe.convenenienceKeyFileDigest = nil;
                    safe.conveniencePin = nil;
                    safe.isTouchIdEnabled = NO;
                    safe.duressPin = nil;
                    safe.hasBeenPromptedForConvenience = NO; // If switched back on we can ask if they want to enrol

                    [SafesList.sharedInstance update:safe];
                }
                
                [self bindAllowBiometric];
            }
        }];
    }
}

- (void)bindAutoFavIcon {
    self.switchAutoFavIcon.on = [[Settings sharedInstance] tryDownloadFavIconForNewRecord];
}

- (IBAction)onAutoFavIcon:(id)sender {
    NSLog(@"Setting tryDownloadFavIconForNewRecord to %d", self.switchAutoFavIcon.on);
    
    Settings.sharedInstance.tryDownloadFavIconForNewRecord = self.switchAutoFavIcon.on;
    
    [self bindAutoFavIcon];
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
    if(self.segmentAppLock.selectedSegmentIndex == kPinCode || self.segmentAppLock.selectedSegmentIndex == kBoth) {
        [self requestAppLockPinCodeAndConfirm];
    }
    else {
        Settings.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
        [self bindAppLock];
    }
}

- (void)requestAppLockPinCodeAndConfirm {
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
                                // TODO: Believe this message string is incorrect copy/pasta mistaje
                                [Alerts warn:self title:@"PINs do not match" message:@"Your PINs do not match. You can try again from Database Settings." completion:nil];
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
    
    if (mode == kBiometric && !Settings.isBiometricIdAvailable) {
        [self.segmentAppLock setSelectedSegmentIndex:kNoLock];
    }
    else if(mode == kBoth && !Settings.isBiometricIdAvailable) {
        [self.segmentAppLock setSelectedSegmentIndex:kPinCode];
    }
    else {
        [self.segmentAppLock setSelectedSegmentIndex:mode];
    }
    
    [self.segmentAppLockDelay setSelectedSegmentIndex:index.integerValue];
    
    NSLog(@"AppLock: [%ld] - [%@]", (long)mode, seconds);
}


- (BOOL)hasLocalOrICloudSafes {
    return ([SafesList.sharedInstance getSafesOfProvider:kLocalDevice].count + [SafesList.sharedInstance getSafesOfProvider:kiCloud].count) > 0;
}

- (IBAction)onUseICloud:(id)sender {
    NSLog(@"Setting iCloudOn to %d", self.switchUseICloud.on);
    
    NSString *biometricIdName = [[Settings sharedInstance] getBiometricIdName];
    if([self hasLocalOrICloudSafes]) {
        [Alerts yesNo:self title:@"Master Password Warning"
              message:[NSString stringWithFormat:@"It is very important that you know your master password for your databases, and that you are not relying entirely on %@.\n"
                     @"The migration and importation process makes every effort to maintain %@ data but it is not guaranteed. "
                     @"In any case it is important that you always know your master passwords.\n\n"
                     @"Do you want to continue changing iCloud usage settings?", biometricIdName, biometricIdName]
              action:^(BOOL response) {
            if(response) {
                [[Settings sharedInstance] setICloudOn:self.switchUseICloud.on];
                
                [self bindCloudSessions];
            }
            else {
                self.switchUseICloud.on = !self.switchUseICloud.on;
            }
        }];
    }
    else {
        [[Settings sharedInstance] setICloudOn:self.switchUseICloud.on];
        
        [self bindCloudSessions];
    }
}

- (void)onContactSupport {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:@"Email Not Available"
             message:@"It looks like email is not setup on this device.\n\nContact support@strongboxsafe.com for help."];
        
        return;
    }
    
    int i=0;
    NSString *safesMessage = @"Databases Collection<br />----------------<br />";
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
    
    NSString* message = [NSString stringWithFormat:@"I'm having some trouble with Strongbox... <br /><br />"
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

- (void)bindHideTotp {
    self.switchHideTotp.on = Settings.sharedInstance.hideTotp;
    self.switchHideTotpBrowseView.on = Settings.sharedInstance.hideTotpInBrowse;
    self.switchHideTotpAutoFill.on = Settings.sharedInstance.hideTotpInAutoFill;
}

- (IBAction)onChangeHideTotp:(id)sender {
    Settings.sharedInstance.hideTotp = self.switchHideTotp.on;
    Settings.sharedInstance.hideTotpInBrowse = self.switchHideTotpBrowseView.on;
    Settings.sharedInstance.hideTotpInAutoFill = self.switchHideTotpAutoFill.on;

    [self bindHideTotp];
}

- (void)bindKeePassNoSorting {
    self.switchNoSortingKeePassInBrowse.on = Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView;
}

- (IBAction)onKeePassNoSortingChanged:(id)sender {
    Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView = self.switchNoSortingKeePassInBrowse.on;
    
    [self bindKeePassNoSorting];
}

-(void)bindShowRecycleBin {
    self.switchShowRecycleBinInBrowse.on = !Settings.sharedInstance.doNotShowRecycleBinInBrowse;
    self.switchShowRecycleBinInSearch.on = Settings.sharedInstance.showRecycleBinInSearchResults;
}

- (IBAction)onShowRecycleBinInBrowse:(id)sender {
    Settings.sharedInstance.doNotShowRecycleBinInBrowse = !self.switchShowRecycleBinInBrowse.on;
    [self bindShowRecycleBin];
}

- (IBAction)onShowRecycleBinInSearch:(id)sender {
    Settings.sharedInstance.showRecycleBinInSearchResults = self.switchShowRecycleBinInSearch.on;
    [self bindShowRecycleBin];
}

- (IBAction)onCopyTotpAutoFill:(id)sender {
    Settings.sharedInstance.doNotCopyOtpCodeOnAutoFillSelect = !self.switchCopyTotpAutoFill.on;
    [self bindCopyTotpAutoFill];
}

- (void)bindCopyTotpAutoFill {
    self.switchCopyTotpAutoFill.on = !Settings.sharedInstance.doNotCopyOtpCodeOnAutoFillSelect;
}

- (void)bindDeleteOnFailedUnlock {
    BOOL enabled = Settings.sharedInstance.deleteDataAfterFailedUnlockCount > 0;
    
    self.switchDeleteDataEnabled.on = enabled;
    self.cellDeleteDataAttempts.userInteractionEnabled = enabled;
    
    NSString* str = @(Settings.sharedInstance.deleteDataAfterFailedUnlockCount).stringValue;
    self.cellDeleteDataAttempts.detailTextLabel.text = enabled ? str : @"Disabled";
}

- (IBAction)onDeleteDataChanged:(id)sender {
    if(self.switchDeleteDataEnabled.on) {
        Settings.sharedInstance.deleteDataAfterFailedUnlockCount = 5; // Default
        
        [Alerts info:self title:@"DATA DELETION: Care Required" message:@"Please be extremely careful with this setting particularly if you are using Biometric ID for application lock. This will delete permanently any local device safes and settings."];
    }
    else {
        Settings.sharedInstance.deleteDataAfterFailedUnlockCount = 0; // Off
    }
    
    [self bindDeleteOnFailedUnlock];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    if(cell == self.cellDeleteDataAttempts) {
        SelectStringViewController *vc = [[SelectStringViewController alloc] init];
        
        NSArray<NSNumber*>* options = @[@3, @5, @10, @15];
        vc.items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return obj.stringValue;
        }];
        NSInteger i = [options indexOfObject:@(Settings.sharedInstance.deleteDataAfterFailedUnlockCount)];
        
        vc.currentlySelectedIndex = i;
        vc.onDone = ^(BOOL success, NSInteger selectedIndex) {
            if (success) {
                Settings.sharedInstance.deleteDataAfterFailedUnlockCount = options[selectedIndex].integerValue;
            }
            
            [self dismissViewControllerAnimated:YES completion:^{
                [self bindDeleteOnFailedUnlock];
            }];
        };
        
        [self presentViewController:vc animated:YES completion:nil];
    }
    else if(cell == self.cellAboutVersion) {

    }
    else if(cell == self.cellAboutHelp) {
        [self onFaq];
    }
    else if(cell == self.cellEmailSupport) {
        [self onContactSupport];
    }
}


- (void)onFaq {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://strongboxsafe.com/faq"]];
}


@end
