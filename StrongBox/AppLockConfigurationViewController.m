//
//  AppLockConfigurationViewController.m
//  Strongbox
//
//  Created by Strongbox on 18/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AppLockConfigurationViewController.h"
#import "AppPreferences.h"
#import "BiometricsManager.h"
#import "Alerts.h"
#import "Utils.h"
#import "PinEntryController.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"

@interface AppLockConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAppLock;
@property (weak, nonatomic) IBOutlet UISwitch *appLockOnPreferences;
@property (weak, nonatomic) IBOutlet UISwitch *switchDeleteDataEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDeleteDataAttempts;
@property (weak, nonatomic) IBOutlet UILabel *labelDeleteDataAttemptCount;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAppLockDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelAppLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *appLockPasscodeFallback;
@property (weak, nonatomic) IBOutlet UILabel *labelAppLockPasscodeFallback;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowPasscode;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPreferences;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDeleteAllEnabled;
@property (weak, nonatomic) IBOutlet UISwitch *switchCoalesceBiometrics;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCoalesceBiometrics;

@end

@implementation AppLockConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.segmentAppLock setEnabled:BiometricsManager.isBiometricIdAvailable forSegmentAtIndex:2];
    [self.segmentAppLock setTitle:[BiometricsManager.sharedInstance getBiometricIdName] forSegmentAtIndex:2];
    [self.segmentAppLock setEnabled:BiometricsManager.isBiometricIdAvailable forSegmentAtIndex:3]; 

    [self bindAppLock];
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

    
}

- (IBAction)onAppLockChanged:(id)sender {
    if ( self.segmentAppLock.selectedSegmentIndex == kPinCode ) {
        [self requestAppLockPinCodeAndConfirm];
    }
    else if ( self.segmentAppLock.selectedSegmentIndex == kBiometric ) {
        [self requestBiometric:NO];
    }
    else if ( self.segmentAppLock.selectedSegmentIndex == kBoth) {
        [self requestBiometric:YES];
    }
    else {
        AppPreferences.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
        [self bindAppLock];
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
    
    self.labelAppLockDelay.textColor = effectiveMode == kNoLock ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    
    self.cellAppLockDelay.userInteractionEnabled = effectiveMode != kNoLock;
    
    self.appLockOnPreferences.enabled = effectiveMode != kNoLock;
    self.appLockPasscodeFallback.enabled = effectiveMode == kBiometric || effectiveMode == kBoth;

    slog(@"AppLock: [%ld] - [%@]", (long)mode, seconds);
    
    BOOL deleteOnOff = AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount > 0;
    BOOL deleteEnabled = (effectiveMode == kPinCode || effectiveMode == kBoth);
    
    self.switchDeleteDataEnabled.enabled = deleteEnabled;
    self.switchDeleteDataEnabled.on = deleteOnOff;
    self.cellDeleteDataAttempts.userInteractionEnabled = deleteOnOff && deleteEnabled;
    
    NSString* str = @(AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount).stringValue;
    
    self.labelDeleteDataAttemptCount.text = deleteOnOff && deleteEnabled ? str : NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
        
    self.labelDeleteDataAttemptCount.textColor = !(deleteOnOff && deleteEnabled) ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    
    NSString* fmt = NSLocalizedString(@"app_lock_allow_device_passcode_fallback_for_biometric_fmt", @"Passcode Fallback for %@");
    self.labelAppLockPasscodeFallback.text = [NSString stringWithFormat:fmt, BiometricsManager.sharedInstance.biometricIdName];
    
    self.appLockOnPreferences.on = AppPreferences.sharedInstance.appLockAppliesToPreferences;
    self.appLockPasscodeFallback.on = AppPreferences.sharedInstance.appLockAllowDevicePasscodeFallbackForBio;
    
    
    
    self.switchCoalesceBiometrics.on = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics;

    
    
    [self cell:self.cellAppLockDelay setHidden:effectiveMode == kNoLock];
    [self cell:self.cellAllowPasscode setHidden:effectiveMode == kNoLock || effectiveMode == kPinCode];
    [self cell:self.cellPreferences setHidden:effectiveMode == kNoLock];
    
    [self cell:self.cellDeleteAllEnabled setHidden:!deleteEnabled];
    [self cell:self.cellDeleteDataAttempts setHidden:!deleteOnOff];
        
    [self cell:self.cellCoalesceBiometrics setHidden:effectiveMode != kBiometric];
    
    [self reloadDataAnimated:YES];
}

- (IBAction)onAppLock2PreferencesChanged:(id)sender {
    slog(@"Generic Preference Changed: [%@]", sender);

    AppPreferences.sharedInstance.appLockAppliesToPreferences = self.appLockOnPreferences.on;
    AppPreferences.sharedInstance.appLockAllowDevicePasscodeFallbackForBio = self.appLockPasscodeFallback.on;
    AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics = self.switchCoalesceBiometrics.on;
    
    [self bindAppLock];
}

- (void)requestAppLockPinCodeAndConfirm {
    PinEntryController* vc1 = PinEntryController.newControllerForAppLock;
    
    vc1.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if(response == kPinEntryResponseOk ) {
            PinEntryController* vc2 = PinEntryController.newControllerForAppLock;
            
            vc2.info = NSLocalizedString(@"prefs_vc_confirm_pin", @"Confirm PIN");
            vc2.onDone = ^(PinEntryResponse response2, NSString * _Nullable confirmPin) {
                if(response2 == kPinEntryResponseOk ) {
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
            };
            
            [self presentViewController:vc2 animated:YES completion:nil];
        }
        else {
            [self bindAppLock];
        }
    };

    [self presentViewController:vc1 animated:YES completion:nil];
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

- (void)requestBiometric:(BOOL)requestPinCodeAfterwards {
    [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_prompt_title", @"Identify to Unlock Database")
                                           fallbackTitle:@""
                                              completion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( success ) {
                if ( requestPinCodeAfterwards ) {
                    [self requestAppLockPinCodeAndConfirm];
                }
                else {
                    AppPreferences.sharedInstance.appLockMode = self.segmentAppLock.selectedSegmentIndex;
                    [self bindAppLock];
                }
            }
            else {
                [self bindAppLock];
            }
        });
    }];
}

@end
