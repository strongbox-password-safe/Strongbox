//
//  PreferencesTableViewController.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PreferencesTableViewController.h"
#import "Alerts.h"
#import "Utils.h"
#import "AppPreferences.h"
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

@interface PreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAppLock;
@property (weak, nonatomic) IBOutlet UISwitch *appLockOnPreferences;
@property (weak, nonatomic) IBOutlet UISwitch *switchDeleteDataEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDeleteDataAttempts;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCloudSessions;
@property (weak, nonatomic) IBOutlet UILabel *labelDeleteDataAttemptCount;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutVersion;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutHelp;
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
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordGeneration;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellManageKeyFiles;
@property (weak, nonatomic) IBOutlet UISwitch *appLockPasscodeFallback;
@property (weak, nonatomic) IBOutlet UILabel *labelAppLockPasscodeFallback;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPrivacyShield;
@property (weak, nonatomic) IBOutlet UILabel *labelPrivacyShield;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelPasswordStrengthAlgo;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAdversaryStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelAdversary;

@end

@implementation PreferencesTableViewController

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (void)bindGeneral {
    self.labelPrivacyShield.text = stringForPrivacyShieldMode(AppPreferences.sharedInstance.appPrivacyShieldMode);
    self.labelPasswordStrengthAlgo.text = stringForPasswordStrengthAlgo(AppPreferences.sharedInstance.passwordStrengthConfig.algorithm);
    self.labelAdversary.text = stringForAdversaryStrength(AppPreferences.sharedInstance.passwordStrengthConfig.adversaryGuessesPerSecond);
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindCloudSessions];
    [self bindAboutButton];
    [self bindHideTips];
    [self bindClearClipboard];
    [self bindAppLock];
    [self customizeAppLockSectionFooter];
    [self bindAppLock2Preferences];
    [self bindGeneral];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(cell == self.cellDeleteDataAttempts) {
        [self promptForInteger:
         NSLocalizedString(@"prefs_vc_delete_data_attempt_count", @"Delete Data Failed Attempt Count")
                       options:@[@3, @5, @10, @15]
             formatAsIntervals:NO
                  currentValue:AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount = selectedValue;
                        }
                        [self bindAppLock];
                    }];
    }
    else if(cell == self.cellAboutVersion) {
        
    }
    else if(cell == self.cellAboutHelp) {
        [self onHelp];
    }
    else if (cell == self.cellClearClipboardDelay) {
        [self promptForInteger:NSLocalizedString(@"prefs_vc_clear_clipboard_delay", @"Clear Clipboard Delay")
                       options:@[@30, @45, @60, @90, @120, @180]
             formatAsIntervals:YES
                  currentValue:AppPreferences.sharedInstance.clearClipboardAfterSeconds
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            AppPreferences.sharedInstance.clearClipboardAfterSeconds = selectedValue;
                        }
                        [self bindClearClipboard];
                    }];
    }
    else if (cell == self.cellAppLockDelay) {
        [self promptForInteger:NSLocalizedString(@"prefs_vc_app_lock_delay", @"App Lock Delay")
                       options:@[@0, @60, @120, @180, @300, @600, @900]
             formatAsIntervals:YES
                  currentValue:AppPreferences.sharedInstance.appLockDelay
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            AppPreferences.sharedInstance.appLockDelay = selectedValue;
                        }
                        [self bindAppLock];
                    }];
    }
    else if (cell == self.cellPasswordGeneration) {
        [self performSegueWithIdentifier:@"seguePrefToPasswordPrefs" sender:nil];
    }
    else if (cell == self.cellManageKeyFiles) {
        [self performSegueWithIdentifier:@"segueToManageKeyFiles" sender:nil];
    }
    else if ( cell == self.cellPrivacyShield ) {
        NSArray<NSNumber*>* options = @[@(kAppPrivacyShieldModeNone),
                                        @(kAppPrivacyShieldModeBlur),
                                        @(kAppPrivacyShieldModePixellate),
                                        @(kAppPrivacyShieldModeBlueScreen)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForPrivacyShieldMode(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString(@"prefs_vc_privacy_shield_view", @"Privacy Shield View")
                      options:optionStrings
         currentlySelectIndex:AppPreferences.sharedInstance.appPrivacyShieldMode
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                AppPreferences.sharedInstance.appPrivacyShieldMode = selectedIndex;
            }
            [self bindGeneral];
        }];
    }
    else if ( cell == self.cellPasswordStrength ) {
        NSArray<NSNumber*>* options = @[@(kPasswordStrengthAlgorithmBasic),
                                        @(kPasswordStrengthAlgorithmZxcvbn)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForPasswordStrengthAlgo(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString(@"prefs_vc_password_strength_algorithm", @"Password Strength Algorithm")
                      options:optionStrings
         currentlySelectIndex:AppPreferences.sharedInstance.passwordStrengthConfig.algorithm
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                PasswordStrengthConfig* config = AppPreferences.sharedInstance.passwordStrengthConfig;
                config.algorithm = selectedIndex;
                AppPreferences.sharedInstance.passwordStrengthConfig = config;
            }
             
            [self bindGeneral];
        }];
    }
    else if ( cell == self.cellAdversaryStrength ) {
        NSArray<NSNumber*>* options = @[
            @(1000),
            @(1000000),
            @(1000000000),
            @(100000000000),
            @(100000000000000),
            @(1000000000000000)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForAdversaryStrength(obj.integerValue);
        }];

        NSUInteger selected = [options indexOfObject:@(AppPreferences.sharedInstance.passwordStrengthConfig.adversaryGuessesPerSecond)];
        
        [self promptForChoice:NSLocalizedString(@"prefs_vc_password_strength_adversary_crack_rate", @"Adversary Guess Rate")
                      options:optionStrings
         currentlySelectIndex:selected
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                PasswordStrengthConfig* config = AppPreferences.sharedInstance.passwordStrengthConfig;
                config.adversaryGuessesPerSecond = options[selectedIndex].unsignedIntegerValue;
                AppPreferences.sharedInstance.passwordStrengthConfig = config;
            }
            [self bindGeneral];
        }];
    }
}

- (void)customizeAppLockSectionFooter {
    [self.segmentAppLock setEnabled:BiometricsManager.isBiometricIdAvailable forSegmentAtIndex:2];
    [self.segmentAppLock setTitle:[BiometricsManager.sharedInstance getBiometricIdName] forSegmentAtIndex:2];
    [self.segmentAppLock setEnabled:BiometricsManager.isBiometricIdAvailable forSegmentAtIndex:3]; 
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];

    
    
    [self bindCloudSessions];
}

- (void)bindAboutButton {
    NSString *aboutString;
    if([[AppPreferences sharedInstance] isPro]) {
        aboutString = [NSString stringWithFormat:
                       NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"About Strongbox Pro %@"), [Utils getAppVersion]];
    }
    else {
        if(AppPreferences.sharedInstance.hasOptedInToFreeTrial) {
            if([[AppPreferences sharedInstance] isFreeTrial]) {
                aboutString = [NSString stringWithFormat:
                               NSLocalizedString(@"prefs_vc_app_version_info_pro_trial_fmt", @"About Strongbox %@ (Pro Trial - %ld days left)"),
                               [Utils getAppVersion], (long)AppPreferences.sharedInstance.freeTrialDaysLeft];
            }
            else {
                aboutString = [NSString stringWithFormat:
                               NSLocalizedString(@"prefs_vc_app_version_info_free_fmt", @"About Strongbox %@ (Free version - Please Upgrade)"), [Utils getAppVersion]];
            }
        }
        else {
            aboutString = [NSString stringWithFormat:
                           NSLocalizedString(@"prefs_vc_app_version_info_free_fmt", @"About Strongbox %@ (Free version - Please Upgrade)"), [Utils getAppVersion]];
        }
    }
    
    self.labelVersion.text = aboutString;
}

- (void)bindCloudSessions {
    

    










    self.switchUseICloud.on = [[AppPreferences sharedInstance] iCloudOn] && AppPreferences.sharedInstance.iCloudAvailable;
    self.switchUseICloud.enabled = AppPreferences.sharedInstance.iCloudAvailable;
    
    self.labelUseICloud.text = AppPreferences.sharedInstance.iCloudAvailable ?    NSLocalizedString(@"prefs_vc_use_icloud_action", @"Use iCloud") :
                                                                            NSLocalizedString(@"prefs_vc_use_icloud_disabled", @"Use iCloud (Unavailable)");
    self.labelUseICloud.enabled = AppPreferences.sharedInstance.iCloudAvailable;
}

- (void)bindHideTips {
    self.switchShowTips.on = !AppPreferences.sharedInstance.hideTips;
}

- (IBAction)onHideTips:(id)sender {
    AppPreferences.sharedInstance.hideTips = !self.switchShowTips.on;
    [self bindHideTips];
}

- (IBAction)onAppLockChanged:(id)sender {
    if(self.segmentAppLock.selectedSegmentIndex == kPinCode || self.segmentAppLock.selectedSegmentIndex == kBoth) {
        [self requestAppLockPinCodeAndConfirm];
    }
    else {
        AppPreferences.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
        [self bindAppLock];
    }
}

- (void)requestAppLockPinCodeAndConfirm {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* vc1 = (PinEntryController*)[storyboard instantiateInitialViewController];
    vc1.isDatabasePIN = NO;
    
    vc1.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                PinEntryController* vc2 = (PinEntryController*)[storyboard instantiateInitialViewController];
                vc2.info = NSLocalizedString(@"prefs_vc_confirm_pin", @"Confirm PIN");
                vc2.isDatabasePIN = NO;
                vc2.onDone = ^(PinEntryResponse response2, NSString * _Nullable confirmPin) {
                    [self dismissViewControllerAnimated:YES completion:^{
                        if(response2 == kOk) {
                            if ([pin isEqualToString:confirmPin]) {
                                AppPreferences.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
                                AppPreferences.sharedInstance.appLockPin = pin;
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
                [[AppPreferences sharedInstance] setICloudOn:self.switchUseICloud.on];
                
                [self bindCloudSessions];
            }
            else {
                self.switchUseICloud.on = !self.switchUseICloud.on;
            }
        }];
    }
    else {
        [[AppPreferences sharedInstance] setICloudOn:self.switchUseICloud.on];
        
        [self bindCloudSessions];
    }
}

- (IBAction)onDeleteDataChanged:(id)sender {
    if(self.switchDeleteDataEnabled.on) {
        AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount = 5; 
        
        [Alerts info:self
               title:NSLocalizedString(@"prefs_vc_info_data_deletion_care_required_title", @"DATA DELETION: Care Required")
             message:NSLocalizedString(@"prefs_vc_info_data_deletion_care_required_message", @"Please be extremely careful as this will delete permanently any local device databases and all preferences.")];
    }
    else {
        AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount = 0; 
    }
    
    [self bindAppLock];
}

- (void)onHelp {
    [Alerts yesNo:self
            title:NSLocalizedString(@"prompt_title_copy_debug_info", @"Copy Debug Info?")
          message:NSLocalizedString(@"prompt_message_copy_debug_info", @"Would you like to copy some helpful debug information that you can share with support before proceeding?")
           action:^(BOOL response) {
        if ( response ) {
            [UIPasteboard.generalPasteboard setString:[DebugHelper getAboutDebugString]];
        }
    
        NSURL* url = [NSURL URLWithString:@"https:
        if (@available (iOS 10.0, *)) {
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }
        else {
            [UIApplication.sharedApplication openURL:url];
        }
    }];
}

- (IBAction)onSwitchClearClipboardEnable:(id)sender {
    AppPreferences.sharedInstance.clearClipboardEnabled = self.clearClipboardEnabled.on;
    
    [self bindClearClipboard];
}

- (void)bindClearClipboard {
    NSInteger seconds = AppPreferences.sharedInstance.clearClipboardAfterSeconds;
    BOOL enabled = AppPreferences.sharedInstance.clearClipboardEnabled;
    
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



- (void)bindAppLock {
    NSInteger mode = AppPreferences.sharedInstance.appLockMode;
    NSNumber* seconds = @(AppPreferences.sharedInstance.appLockDelay);

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
    self.appLockPasscodeFallback.enabled = effectiveMode == kBiometric || effectiveMode == kBoth;

    NSLog(@"AppLock: [%ld] - [%@]", (long)mode, seconds);
    
    BOOL deleteOnOff = AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount > 0;
    BOOL deleteEnabled = effectiveMode != kNoLock;
    
    self.switchDeleteDataEnabled.enabled = deleteEnabled;
    
    self.switchDeleteDataEnabled.on = deleteOnOff;
    self.cellDeleteDataAttempts.userInteractionEnabled = deleteOnOff && deleteEnabled;
    
    NSString* str = @(AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount).stringValue;
    
    self.labelDeleteDataAttemptCount.text = deleteOnOff && deleteEnabled ? str : NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
    
    if (@available(iOS 13.0, *)) {
        self.labelDeleteDataAttemptCount.textColor = !(deleteOnOff && deleteEnabled) ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    }
    else {
        self.labelDeleteDataAttemptCount.textColor = !(deleteOnOff && deleteEnabled) ? UIColor.lightGrayColor : UIColor.darkTextColor;
    }
    
    NSString* fmt = NSLocalizedString(@"app_lock_allow_device_passcode_fallback_for_biometric_fmt", @"Passcode Fallback for %@");
    self.labelAppLockPasscodeFallback.text = [NSString stringWithFormat:fmt, BiometricsManager.sharedInstance.biometricIdName];
}

- (IBAction)onAppLock2PreferencesChanged:(id)sender {
    NSLog(@"Generic Preference Changed: [%@]", sender);

    AppPreferences.sharedInstance.appLockAppliesToPreferences = self.appLockOnPreferences.on;
    AppPreferences.sharedInstance.appLockAllowDevicePasscodeFallbackForBio = self.appLockPasscodeFallback.on;
    
    [self bindAppLock2Preferences];
}

- (void)bindAppLock2Preferences {
    self.appLockOnPreferences.on = AppPreferences.sharedInstance.appLockAppliesToPreferences;
    self.appLockPasscodeFallback.on = AppPreferences.sharedInstance.appLockAllowDevicePasscodeFallbackForBio;
}

static NSString* stringForPrivacyShieldMode(AppPrivacyShieldMode mode ){
    if ( mode == kAppPrivacyShieldModeBlur ) {
        return NSLocalizedString(@"app_privacy_shield_mode_blur", @"Blur");
    }
    else if (mode == kAppPrivacyShieldModePixellate ) {
        return NSLocalizedString(@"app_privacy_shield_mode_pixellate", @"Pixellate");
    }
    else if ( mode == kAppPrivacyShieldModeNone ) {
        return NSLocalizedString(@"generic_none", @"None");
    }
    else {
        return NSLocalizedString(@"app_privacy_shield_mode_blue_screen", @"Blue Screen");
    }
}

static NSString* stringForAdversaryStrength(NSUInteger strength){
    NSNumber* number = @(strength);
    
    
    
    long long num = [number longLongValue];

    int s = ( (num < 0) ? -1 : (num > 0) ? 1 : 0 );
    NSString* sign = (s == -1 ? @"-" : @"" );

    num = llabs(num);

    if (num < 1000000) {

        return [NSString stringWithFormat:NSLocalizedString(@"adversary_guess_rate_fmt", @"%@ / second"), @(num)];
    }
    
    int exp = (int) (log10l(num) / 3.f); 

    NSArray* units = @[ NSLocalizedString(@"number_suffix_thousand", @"Thousand"),
                        NSLocalizedString(@"number_suffix_million", @"Million"),
                        NSLocalizedString(@"number_suffix_billion", @"Billion"),
                        NSLocalizedString(@"number_suffix_trillion", @"Trillion"),
                        NSLocalizedString(@"number_suffix_quadrillion", @"Quadrillion"),
                        NSLocalizedString(@"number_suffix_quintillion", @"Quintillion")];

    NSString* numerator = [NSString stringWithFormat:@"%@%d %@" ,sign, (int)(num / pow(1000, exp)), [units objectAtIndex:(exp-1)]];
    
    return [NSString stringWithFormat:NSLocalizedString(@"adversary_guess_rate_fmt", @"%@ / second"), numerator];
}

static NSString* stringForPasswordStrengthAlgo(PasswordStrengthAlgorithm algo ){
    if ( algo == kPasswordStrengthAlgorithmZxcvbn ) {
        return NSLocalizedString(@"password_strength_algo_zxcvbn_title", @"Zxcvbn (Smart)");
    }
    else {
        return NSLocalizedString(@"password_strength_algo_basic_title", @"Basic (Pooled Entropy)");
    }
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];
    vc.groupItems = @[items];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        
        NSInteger selectedValue = options[set.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
    currentlySelectIndex:(NSInteger)currentlySelectIndex
              completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.groupItems = @[items];
    
    if ( currentlySelectIndex != NSNotFound ) {
        vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    }
    else {
        vc.selectedIndexPaths = nil;
    }
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"seguePrefToPasswordPrefs"]) {
        



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
