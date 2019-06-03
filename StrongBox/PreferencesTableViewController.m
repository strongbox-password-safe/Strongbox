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
#import "SelectItemTableViewController.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "GoogleDriveManager.h"
#import "OneDriveStorageProvider.h"

#import "PasswordGenerationSettingsTableView.h"
#import "AutoFillNewRecordSettingsController.h"
#import "CloudSessionsTableViewController.h"
#import "AboutViewController.h"
#import "AdvancedPreferencesTableViewController.h"

@interface PreferencesTableViewController () <MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *hideEmptyFields;
@property (weak, nonatomic) IBOutlet UISwitch *easyReadFontForAll;
@property (weak, nonatomic) IBOutlet UISwitch *showChildCountOnFolder;
@property (weak, nonatomic) IBOutlet UISwitch *showFlagsInBrowse;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAppLock;
@property (weak, nonatomic) IBOutlet UISwitch *appLockOnPreferences;
@property (weak, nonatomic) IBOutlet UISwitch *switchDeleteDataEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDeleteDataAttempts;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCloudSessions;
@property (weak, nonatomic) IBOutlet UILabel *labelDeleteDataAttemptCount;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutVersion;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutHelp;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmailSupport;
@property (weak, nonatomic) IBOutlet UILabel *labelVersion;
@property (weak, nonatomic) IBOutlet UILabel *labelCloudSessions;
@property (weak, nonatomic) IBOutlet UISwitch *clearClipboardEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellClearClipboardDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelClearClipboardDelay;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchDatabaseAutoLockEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAppLockDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelAppLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowPinCodeOpen;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTips;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotpBrowseView;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellReviewStrongbox;
@property (weak, nonatomic) IBOutlet UISwitch *switchStartWithSearch;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UILabel *labelBrowseItemSubtitle;

@end

@implementation PreferencesTableViewController

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onGenericPreferencesChanged:(id)sender {
    NSLog(@"Generic Preference Changed: [%@]", sender);

    Settings.sharedInstance.showEmptyFieldsInDetailsView = !self.hideEmptyFields.on;
    Settings.sharedInstance.easyReadFontForAll = self.easyReadFontForAll.on;
    Settings.sharedInstance.showChildCountOnFolderInBrowse = self.showChildCountOnFolder.on;
    Settings.sharedInstance.showFlagsInBrowse = self.showFlagsInBrowse.on;
    Settings.sharedInstance.appLockAppliesToPreferences = self.appLockOnPreferences.on;
    Settings.sharedInstance.immediateSearchOnBrowse = self.switchStartWithSearch.on;
    
    [self bindGenericPreferencesChanged];
}

- (void)bindGenericPreferencesChanged {
    self.hideEmptyFields.on = !Settings.sharedInstance.showEmptyFieldsInDetailsView;
    self.easyReadFontForAll.on = Settings.sharedInstance.easyReadFontForAll;
    self.showChildCountOnFolder.on = Settings.sharedInstance.showChildCountOnFolderInBrowse;
    self.showFlagsInBrowse.on = Settings.sharedInstance.showFlagsInBrowse;
    self.appLockOnPreferences.on = Settings.sharedInstance.appLockAppliesToPreferences;
    self.switchStartWithSearch.on = Settings.sharedInstance.immediateSearchOnBrowse;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindCloudSessions];
    [self bindAboutButton];
    [self bindAllowPinCodeOpen];
    [self bindAllowBiometric];
    [self bindDatabaseLock];
    [self bindHideTips];
    [self bindClearClipboard];
    [self bindHideTotp];
    [self bindShowRecycleBin];
    [self bindAppLock];
    [self bindDeleteOnFailedUnlock];
    [self customizeAppLockSectionFooter];
    [self bindGenericPreferencesChanged];
    [self bindBrowseItemSubtitle];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(cell == self.cellDeleteDataAttempts) {
        [self promptForInteger:@[@3, @5, @10, @15]
             formatAsIntervals:NO
                  currentValue:Settings.sharedInstance.deleteDataAfterFailedUnlockCount
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            Settings.sharedInstance.deleteDataAfterFailedUnlockCount = selectedValue;
                        }
                        [self bindDeleteOnFailedUnlock];
                    }];
    }
    else if(cell == self.cellAboutVersion) {
        // Auto Segue
    }
    else if(cell == self.cellAboutHelp) {
        [self onFaq];
    }
    else if(cell == self.cellEmailSupport) {
        [self onContactSupport];
    }
    else if (cell == self.cellClearClipboardDelay) {
        [self promptForInteger:@[@30, @45, @60, @90, @120, @180]
             formatAsIntervals:YES
                  currentValue:Settings.sharedInstance.clearClipboardAfterSeconds
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            Settings.sharedInstance.clearClipboardAfterSeconds = selectedValue;
                        }
                        [self bindClearClipboard];
                    }];
    }
    else if (cell == self.cellDatabaseAutoLockDelay) {
        [self promptForInteger:@[@0, @30, @60, @120, @180, @300, @600]
             formatAsIntervals:YES
                  currentValue:[Settings.sharedInstance getAutoLockTimeoutSeconds].integerValue
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            [Settings.sharedInstance setAutoLockTimeoutSeconds:@(selectedValue)];
                        }
                        [self bindDatabaseLock];
                    }];
    }
    else if (cell == self.cellAppLockDelay) {
        [self promptForInteger:@[@0, @60, @120, @180, @300, @600, @900]
             formatAsIntervals:YES
                  currentValue:Settings.sharedInstance.appLockDelay
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            Settings.sharedInstance.appLockDelay = selectedValue;
                        }
                        [self bindAppLock];
                    }];
    }
    else if (cell == self.cellReviewStrongbox) {
        [self onReviewInAppStore];
    }
    else if (cell == self.cellBrowseItemSubtitle) {
        [self onChangeBrowseItemSubtitle];
    }
}

- (void)customizeAppLockSectionFooter {
    [self.segmentAppLock setEnabled:[Settings isBiometricIdAvailable] forSegmentAtIndex:2];
    [self.segmentAppLock setTitle:[Settings.sharedInstance getBiometricIdName] forSegmentAtIndex:2];
    [self.segmentAppLock setEnabled:[Settings isBiometricIdAvailable] forSegmentAtIndex:3]; // Both
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];

    //self.navigationController.toolbar.hidden = YES;
    
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
    
    self.labelVersion.text = aboutString;
}

- (void)bindCloudSessions {
    int cloudSessionCount = 0;
    cloudSessionCount += [[GoogleDriveManager sharedInstance] isAuthorized] ? 1 : 0;
    cloudSessionCount += (DBClientsManager.authorizedClient != nil) ? 1 : 0;
    cloudSessionCount += [[OneDriveStorageProvider sharedInstance] isSignedIn] ? 1 : 0;

    self.cellCloudSessions.userInteractionEnabled = (cloudSessionCount > 0);
    self.labelCloudSessions.enabled = (cloudSessionCount > 0);
    self.labelCloudSessions.text = (cloudSessionCount > 0) ? [NSString stringWithFormat:@"Sessions (%d)", cloudSessionCount] : @"No Sessions";

    self.switchUseICloud.on = [[Settings sharedInstance] iCloudOn] && Settings.sharedInstance.iCloudAvailable;
    self.switchUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
    
    self.labelUseICloud.text = Settings.sharedInstance.iCloudAvailable ? @"Use iCloud" : @"Use iCloud (Unavailable)";
    self.labelUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
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

- (void)bindHideTips {
    self.switchShowTips.on = !Settings.sharedInstance.hideTips;
}

- (IBAction)onHideTips:(id)sender {
    Settings.sharedInstance.hideTips = !self.switchShowTips.on;
    [self bindHideTips];
}

- (void)bindAllowPinCodeOpen {
    self.switchAllowPinCodeOpen.on = !Settings.sharedInstance.disallowAllPinCodeOpens;
}

- (void)bindAllowBiometric {
    self.labelAllowBiometric.text = [NSString stringWithFormat:@"Allow %@", [Settings.sharedInstance getBiometricIdName]];
    self.switchAllowBiometric.on = !Settings.sharedInstance.disallowAllBiometricId;
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
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* vc1 = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    vc1.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                PinEntryController* vc2 = (PinEntryController*)[storyboard instantiateInitialViewController];
                vc2.info = @"Confirm PIN";
                vc2.onDone = ^(PinEntryResponse response2, NSString * _Nullable confirmPin) {
                    [self dismissViewControllerAnimated:YES completion:^{
                        if(response2 == kOk) {
                            if ([pin isEqualToString:confirmPin]) {
                                Settings.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
                                Settings.sharedInstance.appLockPin = pin;
                                [self bindAppLock];
                            }
                            else {
                                [Alerts warn:self title:@"PINs do not match" message:@"Your PINs do not match." completion:nil];
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
    self.switchShowTotpBrowseView.on = !Settings.sharedInstance.hideTotpInBrowse;
}

- (IBAction)onChangeHideTotp:(id)sender {
    Settings.sharedInstance.hideTotpInBrowse = !self.switchShowTotpBrowseView.on;
    
    [self bindHideTotp];
}

-(void)bindShowRecycleBin {
    self.switchShowRecycleBinInBrowse.on = !Settings.sharedInstance.doNotShowRecycleBinInBrowse;
}

- (IBAction)onShowRecycleBinInBrowse:(id)sender {
    Settings.sharedInstance.doNotShowRecycleBinInBrowse = !self.switchShowRecycleBinInBrowse.on;
    [self bindShowRecycleBin];
}

- (void)bindDeleteOnFailedUnlock {
    BOOL enabled = Settings.sharedInstance.deleteDataAfterFailedUnlockCount > 0;
    
    self.switchDeleteDataEnabled.on = enabled;
    self.cellDeleteDataAttempts.userInteractionEnabled = enabled;
    
    NSString* str = @(Settings.sharedInstance.deleteDataAfterFailedUnlockCount).stringValue;
        self.labelDeleteDataAttemptCount.text = enabled ? str : @"Disabled";
}

- (IBAction)onDeleteDataChanged:(id)sender {
    if(self.switchDeleteDataEnabled.on) {
        Settings.sharedInstance.deleteDataAfterFailedUnlockCount = 5; // Default
        
        [Alerts info:self title:@"DATA DELETION: Care Required" message:@"Please be extremely careful with this setting particularly if you are using Biometric ID for application lock. This will delete permanently any local device databases and all preferences."];
    }
    else {
        Settings.sharedInstance.deleteDataAfterFailedUnlockCount = 0; // Off
    }
    
    [self bindDeleteOnFailedUnlock];
}

- (void)onFaq {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://strongboxsafe.com/faq"]];
}

- (IBAction)onSwitchClearClipboardEnable:(id)sender {
    Settings.sharedInstance.clearClipboardEnabled = self.clearClipboardEnabled.on;
    
    [self bindClearClipboard];
}

- (void)bindClearClipboard {
    NSInteger seconds = Settings.sharedInstance.clearClipboardAfterSeconds;
    BOOL enabled = Settings.sharedInstance.clearClipboardEnabled;
    
    self.clearClipboardEnabled.on = enabled;
    self.cellClearClipboardDelay.userInteractionEnabled = enabled;
    
    NSLog(@"clearClipboard: [%d, %ld]", enabled, (long)seconds);
    
    if(!enabled) {
        self.labelClearClipboardDelay.text = @"Disabled";
        self.labelClearClipboardDelay.textColor = UIColor.darkGrayColor;
    }
    else {
        self.labelClearClipboardDelay.text = [self formatTimeInterval:seconds];
        self.labelClearClipboardDelay.textColor = UIColor.darkTextColor;
    }
}

- (NSString*)formatTimeInterval:(NSInteger)seconds {
    if(seconds == 0) {
        return @"None";
    }
    
    NSDateComponentsFormatter* fmt =  [[NSDateComponentsFormatter alloc] init];
    
    fmt.allowedUnits =  NSCalendarUnitMinute | NSCalendarUnitSecond;
    fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;

    return [fmt stringFromTimeInterval:seconds];
}

//////

- (IBAction)onSwitchDatabaseAutoLockEnabled:(id)sender {
    [Settings.sharedInstance setAutoLockTimeoutSeconds:self.switchDatabaseAutoLockEnabled.on ? @(60) : @(-1)];
    [self bindDatabaseLock];
}

-(void)bindDatabaseLock {
    NSNumber* seconds = [[Settings sharedInstance] getAutoLockTimeoutSeconds];
    
    if(seconds.integerValue == -1) {
        self.switchDatabaseAutoLockEnabled.on = NO;
        self.labelDatabaseAutoLockDelay.text = @"Disabled";
        self.labelDatabaseAutoLockDelay.textColor = UIColor.darkGrayColor;
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = NO;
    }
    else {
        self.switchDatabaseAutoLockEnabled.on = YES;
        self.labelDatabaseAutoLockDelay.text = [self formatTimeInterval:seconds.integerValue];
        self.labelDatabaseAutoLockDelay.textColor = UIColor.darkTextColor;
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = YES;
    }
}

//////

- (void)bindAppLock {
    NSInteger mode = Settings.sharedInstance.appLockMode;
    NSNumber* seconds = @(Settings.sharedInstance.appLockDelay);

    NSInteger effectiveMode = mode;
    if (mode == kBiometric && !Settings.isBiometricIdAvailable) {
        effectiveMode = kNoLock;
    }
    else if(mode == kBoth && !Settings.isBiometricIdAvailable) {
        effectiveMode = kPinCode;
    }

    [self.segmentAppLock setSelectedSegmentIndex:effectiveMode];
    
    self.labelAppLockDelay.text = effectiveMode == kNoLock ? @"Disabled" : [self formatTimeInterval:seconds.integerValue];
    self.labelAppLockDelay.textColor = effectiveMode == kNoLock ? UIColor.lightGrayColor : UIColor.darkTextColor;
    self.cellAppLockDelay.userInteractionEnabled = effectiveMode != kNoLock;
    
    self.appLockOnPreferences.enabled = effectiveMode != kNoLock;
    
    NSLog(@"AppLock: [%ld] - [%@]", (long)mode, seconds);
}

- (void)onReviewInAppStore {
    int appId = 897283731;
    
    static NSString *const iOS7AppStoreURLFormat = @"itms-apps://itunes.apple.com/app/id%d?action=write-review";
    static NSString *const iOSAppStoreURLFormat = @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%d&action=write-review";
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:([[UIDevice currentDevice].systemVersion floatValue] >= 7.0f)? iOS7AppStoreURLFormat: iOSAppStoreURLFormat, appId]];
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
        else {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
    else {
        [Alerts info:self title:@"Cannot open App Store" message:@"Please find Strongbox in the App Store and you can write a review there. Much appreciated! -Mark"];
    }
}

//

- (void)onChangeBrowseItemSubtitle {
    NSArray<NSNumber*>* options = @[@(kNoField), @(kUsername), @(kPassword), @(kUrl), @(kEmail), @(kModified)];
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getBrowseItemSubtitleFieldName:(BrowseItemSubtitleField)obj.integerValue];
    }];

    [self promptForString:optionStrings
             currentIndex:Settings.sharedInstance.browseItemSubtitleField
               completion:^(BOOL success, NSInteger selectedIdx) {
        if (success) {
            Settings.sharedInstance.browseItemSubtitleField = (BrowseItemSubtitleField)selectedIdx;
        }
                   
        [self bindBrowseItemSubtitle];
    }];
}

- (void)bindBrowseItemSubtitle {
    self.labelBrowseItemSubtitle.text = [self getBrowseItemSubtitleFieldName:Settings.sharedInstance.browseItemSubtitleField];
}

- (NSString*)getBrowseItemSubtitleFieldName:(BrowseItemSubtitleField)field {
    switch (field) {
        case kNoField:
            return @"None";
            break;
        case kUsername:
            return @"Username";
            break;
        case kPassword:
            return @"Plaintext Password (Careful)";
            break;
        case kUrl:
            return @"URL";
            break;
        case kEmail:
            return @"Email (Password Safe Only)";
            break;
        case kModified:
            return @"Date Modified";
        default:
            return @"None";
            break;
    }
}

- (void)promptForInteger:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [self formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.currentlySelectedIndex = currentlySelectIndex;
    vc.onDone = ^(BOOL success, NSInteger selectedIndex) {
        NSInteger selectedValue = -1;
        if (success) {
            selectedValue = options[selectedIndex].integerValue;
        }
        
        [self dismissViewControllerAnimated:YES completion:^{
            completion(success, selectedValue);
        }];
    };
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)promptForString:(NSArray<NSString*>*)options
           currentIndex:(NSInteger)currentIndex
             completion:(void(^)(BOOL success, NSInteger selectedIdx))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.items = options;
    vc.currentlySelectedIndex = currentIndex;
    vc.onDone = ^(BOOL success, NSInteger selectedIndex) {
        [self dismissViewControllerAnimated:YES completion:^{
            completion(success, selectedIndex);
        }];
    };
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"seguePrefToPasswordPrefs"]) {
        PasswordGenerationSettingsTableView* vc = (PasswordGenerationSettingsTableView*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"seguePrefsToNewEntryDefaults"]) {
        AutoFillNewRecordSettingsController* vc = (AutoFillNewRecordSettingsController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"seguePrefsToAdvanced"]) {
        AdvancedPreferencesTableViewController* vc = (AdvancedPreferencesTableViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"seguePrefsToCloudSessions"]) {
        CloudSessionsTableViewController* vc = (CloudSessionsTableViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"seguePrefsToAbout"]) {
        AboutViewController* vc = (AboutViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
}

@end
