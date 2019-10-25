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
#import "AutoFillNewRecordSettingsController.h"
#import "CloudSessionsTableViewController.h"
#import "AboutViewController.h"
#import "AdvancedPreferencesTableViewController.h"
#import "KeyFilesTableViewController.h"
#import "PasswordGenerationViewController.h"
#import "DebugHelper.h"
#import "BiometricsManager.h"

@interface PreferencesTableViewController () <MFMailComposeViewControllerDelegate>

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
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAppLockDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelAppLockDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTips;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellReviewStrongbox;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordGeneration;
@property (weak, nonatomic) IBOutlet UITableViewCell *tweetStrongbox;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellManageKeyFiles;

@end

@implementation PreferencesTableViewController

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onGenericPreferencesChanged:(id)sender {
    NSLog(@"Generic Preference Changed: [%@]", sender);

    Settings.sharedInstance.appLockAppliesToPreferences = self.appLockOnPreferences.on;
    
    [self bindGenericPreferencesChanged];
}

- (void)bindGenericPreferencesChanged {
    self.appLockOnPreferences.on = Settings.sharedInstance.appLockAppliesToPreferences;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindCloudSessions];
    [self bindAboutButton];
    [self bindHideTips];
    [self bindClearClipboard];
    [self bindAppLock];
    [self bindDeleteOnFailedUnlock];
    [self customizeAppLockSectionFooter];
    [self bindGenericPreferencesChanged];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(cell == self.cellDeleteDataAttempts) {
        [self promptForInteger:
         NSLocalizedString(@"prefs_vc_delete_data_attempt_count", @"Delete Data Failed Attempt Count")
                       options:@[@3, @5, @10, @15]
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
    else if(cell == self.tweetStrongbox) {
        [self launchStrongboxSafeTwitter];
    }
    else if(cell == self.cellAboutHelp) {
        [self onFaq];
    }
    else if(cell == self.cellEmailSupport) {
        [self onContactSupport];
    }
    else if (cell == self.cellClearClipboardDelay) {
        [self promptForInteger:NSLocalizedString(@"prefs_vc_clear_clipboard_delay", @"Clear Clipboard Delay")
                       options:@[@30, @45, @60, @90, @120, @180]
             formatAsIntervals:YES
                  currentValue:Settings.sharedInstance.clearClipboardAfterSeconds
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            Settings.sharedInstance.clearClipboardAfterSeconds = selectedValue;
                        }
                        [self bindClearClipboard];
                    }];
    }
    else if (cell == self.cellAppLockDelay) {
        [self promptForInteger:NSLocalizedString(@"prefs_vc_app_lock_delay", @"App Lock Delay")
                       options:@[@0, @60, @120, @180, @300, @600, @900]
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
    else if (cell == self.cellPasswordGeneration) {
        [self performSegueWithIdentifier:@"seguePrefToPasswordPrefs" sender:nil];
    }
    else if (cell == self.cellManageKeyFiles) {
        [self performSegueWithIdentifier:@"segueToManageKeyFiles" sender:nil];
    }
}

-(void)launchTweetAtStrongboxSafe {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitter://post?message=@StrongboxSafe%20Hi!"] options:@{} completionHandler:^(BOOL success) {
        if(!success) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/intent/tweet?text=@StrongboxSafe%20Hi!"]];
        }
    }];
}

- (void)launchStrongboxSafeTwitter {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/strongboxsafe"]];
}

- (void)customizeAppLockSectionFooter {
    [self.segmentAppLock setEnabled:BiometricsManager.isBiometricIdAvailable forSegmentAtIndex:2];
    [self.segmentAppLock setTitle:[BiometricsManager.sharedInstance getBiometricIdName] forSegmentAtIndex:2];
    [self.segmentAppLock setEnabled:BiometricsManager.isBiometricIdAvailable forSegmentAtIndex:3]; // Both
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
        aboutString = [NSString stringWithFormat:
                       NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"Pro Version %@"), [Utils getAppVersion]];
    }
    else {
        if([[Settings sharedInstance] isFreeTrial]) {
            aboutString = [NSString stringWithFormat:
                           NSLocalizedString(@"prefs_vc_app_version_info_pro_trial_fmt", @"Pro Version %@ (Trial - %ld days left)"),
                           [Utils getAppVersion], (long)[[Settings sharedInstance] getFreeTrialDaysRemaining]];
        }
        else {
            aboutString = [NSString stringWithFormat:
                           NSLocalizedString(@"prefs_vc_app_version_info_free_fmt", @"Lite Version %@ (Please Upgrade)"), [Utils getAppVersion]];
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
    self.labelCloudSessions.text = (cloudSessionCount > 0) ? [NSString stringWithFormat:
                                                              NSLocalizedString(@"prefs_vc_cloud_sessions_count_fmt", @"Sessions (%d)"), cloudSessionCount] :
    NSLocalizedString(@"prefs_vc_cloud_sessions_count_none", @"No Sessions");

    self.switchUseICloud.on = [[Settings sharedInstance] iCloudOn] && Settings.sharedInstance.iCloudAvailable;
    self.switchUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
    
    self.labelUseICloud.text = Settings.sharedInstance.iCloudAvailable ?    NSLocalizedString(@"prefs_vc_use_icloud_action", @"Use iCloud") :
                                                                            NSLocalizedString(@"prefs_vc_use_icloud_disabled", @"Use iCloud (Unavailable)");
    self.labelUseICloud.enabled = Settings.sharedInstance.iCloudAvailable;
}

- (void)bindHideTips {
    self.switchShowTips.on = !Settings.sharedInstance.hideTips;
}

- (IBAction)onHideTips:(id)sender {
    Settings.sharedInstance.hideTips = !self.switchShowTips.on;
    [self bindHideTips];
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
                vc2.info = NSLocalizedString(@"prefs_vc_confirm_pin", @"Confirm PIN");
                vc2.onDone = ^(PinEntryResponse response2, NSString * _Nullable confirmPin) {
                    [self dismissViewControllerAnimated:YES completion:^{
                        if(response2 == kOk) {
                            if ([pin isEqualToString:confirmPin]) {
                                Settings.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
                                Settings.sharedInstance.appLockPin = pin;
                                [self bindAppLock];
                            }
                            else {
                                [Alerts warn:self
                                       title:NSLocalizedString(@"prefs_vc_pins_dont_match_warning_title", @"PINs do not match")
                                     message:NSLocalizedString(@"prefs_vc_pins_dont_match_warning_message", @"Your PINs do not match.")
                                  completion:nil];
                                
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
    
    NSString *biometricIdName = [[BiometricsManager sharedInstance] getBiometricIdName];
    if([self hasLocalOrICloudSafes]) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"prefs_vc_master_password_icloud_migration_yesno_warning_title", @"Master Password Warning")
              message:[NSString stringWithFormat:
                       NSLocalizedString(@"prefs_vc_master_password_icloud_migration_yesno_warning_message_fmt", @"It is very important that you know your master password for your databases, and that you are not relying entirely on %@.\nThe migration and importation process makes every effort to maintain %@ data but it is not guaranteed. In any case it is important that you always know your master passwords.\n\nDo you want to continue changing iCloud usage settings?"), biometricIdName, biometricIdName]
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
    [Alerts threeOptionsWithCancel:self
                             title:NSLocalizedString(@"prefs_vc_info_email_support_options_title", @"Support Options")
                           message:NSLocalizedString(@"prefs_vc_info_email_support_options_message", @"Please make sure you check Twitter, Reddit and the FAQ before you email support to save development resources for improving Strongbox.")
               defaultButtonText:NSLocalizedString(@"prefs_vc_info_email_support_options_check_faq", @"Check FAQ")
                  secondButtonText:NSLocalizedString(@"prefs_vc_info_email_support_options_check_twitter", @"Check Twitter")
                   thirdButtonText:NSLocalizedString(@"prefs_vc_info_email_support_options_mail_support", @"Mail Support (English Only)")
                            action:^(int response) {
        if(response == 0) {
            [self onFaq];
        }
        else if (response == 1) {
            [self launchStrongboxSafeTwitter];
        }
        else if (response == 2) {
            [self mailSupport];
        }
    }];
}
 
- (void)mailSupport {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:NSLocalizedString(@"prefs_vc_info_email_not_available_title", @"Email Not Available")
             message:NSLocalizedString(@"prefs_vc_info_email_not_available_message", @"It looks like email is not setup on this device.\n\nContact support@strongboxsafe.com for help.")];
        
        return;
    }
    
    NSString* message = [DebugHelper getSupportEmailDebugString];
    
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

- (void)bindDeleteOnFailedUnlock {
    BOOL enabled = Settings.sharedInstance.deleteDataAfterFailedUnlockCount > 0;
    
    self.switchDeleteDataEnabled.on = enabled;
    self.cellDeleteDataAttempts.userInteractionEnabled = enabled;
    
    NSString* str = @(Settings.sharedInstance.deleteDataAfterFailedUnlockCount).stringValue;
        self.labelDeleteDataAttemptCount.text = enabled ? str : NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
    
    if (@available(iOS 13.0, *)) {
        self.labelDeleteDataAttemptCount.textColor = !enabled ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    }
    else {
        self.labelDeleteDataAttemptCount.textColor = !enabled ? UIColor.lightGrayColor : UIColor.darkTextColor;
    }
}

- (IBAction)onDeleteDataChanged:(id)sender {
    if(self.switchDeleteDataEnabled.on) {
        Settings.sharedInstance.deleteDataAfterFailedUnlockCount = 5; // Default
        
        [Alerts info:self
               title:NSLocalizedString(@"prefs_vc_info_data_deletion_care_required_title", @"DATA DELETION: Care Required")
             message:NSLocalizedString(@"prefs_vc_info_data_deletion_care_required_message", @"Please be extremely careful as this will delete permanently any local device databases and all preferences.")];
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
        self.labelClearClipboardDelay.text = NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
    }
    else {
        self.labelClearClipboardDelay.text = [Utils formatTimeInterval:seconds];
    }
}

//////

- (void)bindAppLock {
    NSInteger mode = Settings.sharedInstance.appLockMode;
    NSNumber* seconds = @(Settings.sharedInstance.appLockDelay);

    NSInteger effectiveMode = mode;
    if (mode == kBiometric && !BiometricsManager.isBiometricIdAvailable) {
        effectiveMode = kNoLock;
    }
    else if(mode == kBoth && !BiometricsManager.isBiometricIdAvailable) {
        effectiveMode = kPinCode;
    }

    [self.segmentAppLock setSelectedSegmentIndex:effectiveMode];
    
    self.labelAppLockDelay.text = effectiveMode == kNoLock ?
    NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled") : [Utils formatTimeInterval:seconds.integerValue];
    
    if (@available(iOS 13.0, *)) {
        self.labelAppLockDelay.textColor = effectiveMode == kNoLock ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    }
    else {
        self.labelAppLockDelay.textColor = effectiveMode == kNoLock ? UIColor.lightGrayColor : UIColor.darkTextColor;
    }
    
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
        [Alerts info:self
               title:NSLocalizedString(@"prefs_vc_info_cannot_open_app_store_title", @"Cannot open App Store")
             message:NSLocalizedString(@"prefs_vc_info_cannot_open_app_store_message", @"Please find Strongbox in the App Store and you can write a review there. Much appreciated!\n-Mark")];
    }
}

//

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selected = [NSIndexSet indexSetWithIndex:currentlySelectIndex];
    vc.onSelectionChanged = ^(NSIndexSet * _Nonnull selectedIndices) {
        NSInteger selectedValue = options[selectedIndices.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"seguePrefToPasswordPrefs"]) {
        //UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
//        PasswordGenerationSettingsTableView* vc = (PasswordGenerationSettingsTableView*)nav.topViewController;
//        vc.onDone = self.onDone;
//
        PasswordGenerationViewController* vc = (PasswordGenerationViewController*)segue.destinationViewController;
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
    else if ([segue.identifier isEqualToString:@"segueToManageKeyFiles"]) {
        KeyFilesTableViewController* vc = (KeyFilesTableViewController*)segue.destinationViewController;
        vc.manageMode = YES;
    }
}

@end
