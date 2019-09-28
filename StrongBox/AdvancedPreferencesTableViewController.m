//
//  AdvancedPreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 27/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AdvancedPreferencesTableViewController.h"
#import "Settings.h"
#import "AutoFillManager.h"
#import "Alerts.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "OfflineDetector.h"

@interface AdvancedPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *instantPinUnlock;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideKeyFileName;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowAllFilesInKeyFilesLocal;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowYubikeySecretWorkaround;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowPinCodeOpen;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometric;
@property (weak, nonatomic) IBOutlet UISwitch *switchDetectOffline;

@end

@implementation AdvancedPreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    self.navigationController.navigationBar.hidden = NO;
    [self.navigationItem setPrompt:nil];
    [self.navigationController setNavigationBarHidden:NO];
    
    self.tableView.tableFooterView = [UIView new];
    
    [self bindPreferences];
    [self bindAllowPinCodeOpen];
    [self bindAllowBiometric];
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onPreferencesChanged:(id)sender {
    NSLog(@"Advanced Preference Changed: [%@]", sender);
    
    Settings.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    Settings.sharedInstance.hideKeyFileOnUnlock = self.switchHideKeyFileName.on;
    Settings.sharedInstance.showAllFilesInLocalKeyFiles = self.switchShowAllFilesInKeyFilesLocal.on;
    Settings.sharedInstance.showYubikeySecretWorkaroundField = self.switchShowYubikeySecretWorkaround.on;
    Settings.sharedInstance.monitorInternetConnectivity = self.switchDetectOffline.on;
    
    if(Settings.sharedInstance.monitorInternetConnectivity) {
        [OfflineDetector.sharedInstance startMonitoringConnectivitity];
    }
    else {
        [OfflineDetector.sharedInstance stopMonitoringConnectivitity];
    }
    
    [self bindPreferences];
}

- (void)bindPreferences {
    self.instantPinUnlock.on = Settings.sharedInstance.instantPinUnlocking;
    self.switchHideKeyFileName.on = Settings.sharedInstance.hideKeyFileOnUnlock;
    self.switchShowAllFilesInKeyFilesLocal.on = Settings.sharedInstance.showAllFilesInLocalKeyFiles;
    self.switchShowYubikeySecretWorkaround.on = Settings.sharedInstance.showYubikeySecretWorkaroundField;
    self.switchDetectOffline.on = Settings.sharedInstance.monitorInternetConnectivity;
}

- (void)bindAllowPinCodeOpen {
    self.switchAllowPinCodeOpen.on = !Settings.sharedInstance.disallowAllPinCodeOpens;
}

- (void)bindAllowBiometric {
    self.labelAllowBiometric.text = [NSString stringWithFormat:NSLocalizedString(@"prefs_vc_enable_biometric_fmt", @"Enable %@"), [Settings.sharedInstance getBiometricIdName]];
    self.switchAllowBiometric.on = !Settings.sharedInstance.disallowAllBiometricId;
}

- (IBAction)onAllowPinCodeOpen:(id)sender {
    if(self.switchAllowPinCodeOpen.on) {
        Settings.sharedInstance.disallowAllPinCodeOpens = !self.switchAllowPinCodeOpen.on;
        [self bindAllowPinCodeOpen];
    }
    else {
        [Alerts yesNo:self
                title:NSLocalizedString(@"prefs_vc_clear_pin_codes_yesno_title", @"Clear PIN Codes")
              message:NSLocalizedString(@"prefs_vc_clear_pin_codes_yesno_message", @"This will clear any existing databases with stored Master Credentials that are backed by PIN Codes")
               action:^(BOOL response) {
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
                           safe.convenenienceYubikeySecret = nil;
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
        [Alerts yesNo:self
                title:NSLocalizedString(@"prefs_vc_clear_biometrics_yesno_title", @"Clear Biometrics")
              message:NSLocalizedString(@"prefs_vc_clear_biometrics_yesno_message", @"This will clear any existing databases with stored Master Credentials that are backed by Biometric Open. Are you sure?")
               action:^(BOOL response) {
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
                           safe.convenenienceYubikeySecret = nil;
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

@end
