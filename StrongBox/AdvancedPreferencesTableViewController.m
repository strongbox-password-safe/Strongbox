//
//  AdvancedPreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 27/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AdvancedPreferencesTableViewController.h"
//#import "Settings.h"
#import "AppPreferences.h"
#import "AutoFillManager.h"
#import "Alerts.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "OfflineDetector.h"
#import "BiometricsManager.h"
#import "Settings.h"
#import "FileManager.h"

@interface AdvancedPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *instantPinUnlock;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideKeyFileName;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowAllFilesInKeyFilesLocal;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowMetadataOnDetailsScreen;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowPinCodeOpen;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometric;
@property (weak, nonatomic) IBOutlet UISwitch *switchDetectOffline;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowClipboardHandoff;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseColorBlindPalette;

@property (weak, nonatomic) IBOutlet UISwitch *switchSyncForcePull;
@property (weak, nonatomic) IBOutlet UISwitch *switchSyncForcePush;

@property (weak, nonatomic) IBOutlet UISwitch *switchBackupFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchBackupImportedKeyFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideExportOnDatabaseMenu;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowThirdPartyKeyboards;
@property (weak, nonatomic) IBOutlet UISwitch *switchCompleteFileProtection;
@property (weak, nonatomic) IBOutlet UISwitch *switchCoalesceBiometrics;

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

- (IBAction)onBackupSettingsChanged:(id)sender {
    Settings.sharedInstance.backupFiles = self.switchBackupFiles.on;
    Settings.sharedInstance.backupIncludeImportedKeyFiles = self.switchBackupImportedKeyFiles.on;
    
    [FileManager.sharedInstance setDirectoryInclusionFromBackup:Settings.sharedInstance.backupFiles
                                               importedKeyFiles:Settings.sharedInstance.backupIncludeImportedKeyFiles];
    
    [self bindPreferences];
}

- (IBAction)onFileProtectionChanged:(id)sender {
    Settings.sharedInstance.fullFileProtection = self.switchCompleteFileProtection.on;
    [FileManager.sharedInstance setFileProtection:Settings.sharedInstance.fullFileProtection];

    [self bindPreferences];
}

- (IBAction)onPreferencesChanged:(id)sender {
    NSLog(@"Advanced Preference Changed: [%@]", sender);

    AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame = self.switchSyncForcePull.on;
    AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts = self.switchSyncForcePush.on;
    
    AppPreferences.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    AppPreferences.sharedInstance.hideKeyFileOnUnlock = self.switchHideKeyFileName.on;
    AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles = self.switchShowAllFilesInKeyFilesLocal.on;
    AppPreferences.sharedInstance.monitorInternetConnectivity = self.switchDetectOffline.on;
    AppPreferences.sharedInstance.clipboardHandoff = self.switchAllowClipboardHandoff.on;
    AppPreferences.sharedInstance.colorizeUseColorBlindPalette = self.switchUseColorBlindPalette.on;
    Settings.sharedInstance.hideExportFromDatabaseContextMenu = self.switchHideExportOnDatabaseMenu.on;
    Settings.sharedInstance.allowThirdPartyKeyboards = self.switchAllowThirdPartyKeyboards.on;

    AppPreferences.sharedInstance.showMetadataOnDetailsScreen = self.switchShowMetadataOnDetailsScreen.on;
    
    if(AppPreferences.sharedInstance.monitorInternetConnectivity) {
        [OfflineDetector.sharedInstance startMonitoringConnectivitity];
    }
    else {
        [OfflineDetector.sharedInstance stopMonitoringConnectivitity];
    }
    
    AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics = self.switchCoalesceBiometrics.on;
    
    [self bindPreferences];
}

- (void)bindPreferences {
    self.switchSyncForcePull.on = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;
    self.switchSyncForcePush.on = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    
    self.instantPinUnlock.on = AppPreferences.sharedInstance.instantPinUnlocking;
    self.switchHideKeyFileName.on = AppPreferences.sharedInstance.hideKeyFileOnUnlock;
    self.switchShowAllFilesInKeyFilesLocal.on = AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles;
    self.switchDetectOffline.on = AppPreferences.sharedInstance.monitorInternetConnectivity;
    self.switchAllowClipboardHandoff.on = AppPreferences.sharedInstance.clipboardHandoff;
    self.switchUseColorBlindPalette.on = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;

    self.switchBackupFiles.on = Settings.sharedInstance.backupFiles;
    self.switchBackupImportedKeyFiles.on = Settings.sharedInstance.backupIncludeImportedKeyFiles;
    self.switchHideExportOnDatabaseMenu.on = Settings.sharedInstance.hideExportFromDatabaseContextMenu;
    self.switchAllowThirdPartyKeyboards.on = Settings.sharedInstance.allowThirdPartyKeyboards;
    
    self.switchShowMetadataOnDetailsScreen.on = AppPreferences.sharedInstance.showMetadataOnDetailsScreen;

    self.switchCompleteFileProtection.on = Settings.sharedInstance.fullFileProtection;
    self.switchCoalesceBiometrics.on = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics;
}

- (void)bindAllowPinCodeOpen {
    self.switchAllowPinCodeOpen.on = !AppPreferences.sharedInstance.disallowAllPinCodeOpens;
}

- (void)bindAllowBiometric {
    self.labelAllowBiometric.text = [NSString stringWithFormat:NSLocalizedString(@"prefs_vc_enable_biometric_fmt", @"Allow %@ Unlock"), [BiometricsManager.sharedInstance getBiometricIdName]];
    self.switchAllowBiometric.on = !AppPreferences.sharedInstance.disallowAllBiometricId;
}

- (IBAction)onAllowPinCodeOpen:(id)sender {
    if(self.switchAllowPinCodeOpen.on) {
        AppPreferences.sharedInstance.disallowAllPinCodeOpens = !self.switchAllowPinCodeOpen.on;
        [self bindAllowPinCodeOpen];
    }
    else {
        [Alerts yesNo:self
                title:NSLocalizedString(@"prefs_vc_clear_pin_codes_yesno_title", @"Clear PIN Codes")
              message:NSLocalizedString(@"prefs_vc_clear_pin_codes_yesno_message", @"This will clear any existing databases with stored Master Credentials that are backed by PIN Codes")
               action:^(BOOL response) {
                    if(response) {
                        AppPreferences.sharedInstance.disallowAllPinCodeOpens = !self.switchAllowPinCodeOpen.on;

                        

                        NSArray<SafeMetaData*>* clear = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
                            return obj.conveniencePin != nil && obj.isEnrolledForConvenience;
                        }];

                        for (SafeMetaData* safe in clear) {
                            safe.isEnrolledForConvenience = NO;
                            safe.isTouchIdEnabled = NO;
                            safe.convenienceMasterPassword = nil;
                            safe.conveniencePin = nil;
                            safe.duressPin = nil;
                            safe.hasBeenPromptedForConvenience = NO; 

                            [SafesList.sharedInstance update:safe];
                        }
                    }

                    [self bindAllowPinCodeOpen];
               }];
    }
}

- (IBAction)onAllowBiometric:(id)sender {
    if(self.switchAllowBiometric.on) {
        NSLog(@"Setting Allow Biometric Id to %d", self.switchAllowBiometric.on);
        
        AppPreferences.sharedInstance.disallowAllBiometricId = !self.switchAllowBiometric.on;
        
        [self bindAllowBiometric];
    }
    else {
        [Alerts yesNo:self
                title:NSLocalizedString(@"prefs_vc_clear_biometrics_yesno_title", @"Clear Biometrics")
              message:NSLocalizedString(@"prefs_vc_clear_biometrics_yesno_message", @"This will clear any existing databases with stored Master Credentials that are backed by Biometric Open. Are you sure?")
               action:^(BOOL response) {
                    if(response) {
                        NSLog(@"Setting Allow Biometric Id to %d", self.switchAllowBiometric.on);

                        AppPreferences.sharedInstance.disallowAllBiometricId = !self.switchAllowBiometric.on;

                        

                        NSArray<SafeMetaData*>* clear = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
                        return obj.isTouchIdEnabled && obj.isEnrolledForConvenience;
                        }];

                        for (SafeMetaData* safe in clear) {
                            safe.isEnrolledForConvenience = NO;
                            safe.convenienceMasterPassword = nil;
                            safe.conveniencePin = nil;
                            safe.isTouchIdEnabled = NO;
                            safe.duressPin = nil;
                            safe.hasBeenPromptedForConvenience = NO; 

                            [SafesList.sharedInstance update:safe];
                        }
                    }
            
                    [self bindAllowBiometric];
               }];
    }
}

@end
