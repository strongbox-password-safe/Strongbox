//
//  AdvancedPreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 27/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AdvancedPreferencesTableViewController.h"
#import "AppPreferences.h"
#import "AutoFillManager.h"
#import "Alerts.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "OfflineDetector.h"
#import "BiometricsManager.h"
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
@property (weak, nonatomic) IBOutlet UISwitch *backgroundUpdateSync;
@property (weak, nonatomic) IBOutlet UISwitch *switchAddLegacyTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchAddOtpAuthUrl;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellFileProtection;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellInstantPin;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowPin;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowBio;
@property (weak, nonatomic) IBOutlet UISwitch *switchPinYinSearch;

@property (weak, nonatomic) IBOutlet UISwitch *switchDropboxFolderOnly;
@property (weak, nonatomic) IBOutlet UISwitch *switchLegacyDropboxApi;
@property (weak, nonatomic) IBOutlet UISwitch *switchMinimalDropboxScopes;
@property (weak, nonatomic) IBOutlet UISwitch *switchStreamReadLargeKeyFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchNativeKeePassEmailField;

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
    
    
    
    [self cell:self.cellFileProtection setHidden:YES];
    [self cell:self.cellInstantPin setHidden:YES];
    [self cell:self.cellAllowPin setHidden:YES];
    [self cell:self.cellAllowBio setHidden:YES];
    
    
    
    [self bindPreferences];
    [self bindAllowPinCodeOpen];
    [self bindAllowBiometric];
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onBackupSettingsChanged:(id)sender {
    AppPreferences.sharedInstance.backupFiles = self.switchBackupFiles.on;
    AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = self.switchBackupImportedKeyFiles.on;
    
    [FileManager.sharedInstance setDirectoryInclusionFromBackup:AppPreferences.sharedInstance.backupFiles
                                               importedKeyFiles:AppPreferences.sharedInstance.backupIncludeImportedKeyFiles];
    
    [self bindPreferences];
}

- (IBAction)onFileProtectionChanged:(id)sender {




}

- (IBAction)onPreferencesChanged:(id)sender {
    NSLog(@"Advanced Preference Changed: [%@]", sender);

    AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame = self.switchSyncForcePull.on;
    AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts = self.switchSyncForcePush.on;
    AppPreferences.sharedInstance.useBackgroundUpdates = self.backgroundUpdateSync.on;
    

    AppPreferences.sharedInstance.hideKeyFileOnUnlock = self.switchHideKeyFileName.on;
    AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles = self.switchShowAllFilesInKeyFilesLocal.on;
    AppPreferences.sharedInstance.monitorInternetConnectivity = self.switchDetectOffline.on;
    AppPreferences.sharedInstance.clipboardHandoff = self.switchAllowClipboardHandoff.on;
    AppPreferences.sharedInstance.colorizeUseColorBlindPalette = self.switchUseColorBlindPalette.on;
    AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu = self.switchHideExportOnDatabaseMenu.on;
    AppPreferences.sharedInstance.allowThirdPartyKeyboards = self.switchAllowThirdPartyKeyboards.on;

    AppPreferences.sharedInstance.showMetadataOnDetailsScreen = self.switchShowMetadataOnDetailsScreen.on;
    
    if(AppPreferences.sharedInstance.monitorInternetConnectivity) {
        [OfflineDetector.sharedInstance startMonitoringConnectivitity];
    }
    else {
        [OfflineDetector.sharedInstance stopMonitoringConnectivitity];
    }
    
    AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics = self.switchCoalesceBiometrics.on;
    AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields = self.switchAddLegacyTotp.on;
    AppPreferences.sharedInstance.addOtpAuthUrl = self.switchAddOtpAuthUrl.on;

    AppPreferences.sharedInstance.pinYinSearchEnabled = self.switchPinYinSearch.on;
    
    AppPreferences.sharedInstance.useIsolatedDropbox = self.switchDropboxFolderOnly.on;    
    AppPreferences.sharedInstance.useLegacyDropboxApi = self.switchLegacyDropboxApi.on;
    AppPreferences.sharedInstance.useMinimalDropboxScopes = self.switchMinimalDropboxScopes.on;
    AppPreferences.sharedInstance.streamReadLargeKeyFiles = self.switchStreamReadLargeKeyFiles.on;
    AppPreferences.sharedInstance.keePassEmailField = self.switchNativeKeePassEmailField.on;

    [self bindPreferences];
}

- (void)bindPreferences {
    self.switchSyncForcePull.on = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;
    self.switchSyncForcePush.on = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    self.backgroundUpdateSync.on = AppPreferences.sharedInstance.useBackgroundUpdates;
    
    self.instantPinUnlock.on = AppPreferences.sharedInstance.instantPinUnlocking;
    self.switchHideKeyFileName.on = AppPreferences.sharedInstance.hideKeyFileOnUnlock;
    self.switchShowAllFilesInKeyFilesLocal.on = AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles;
    self.switchDetectOffline.on = AppPreferences.sharedInstance.monitorInternetConnectivity;
    self.switchAllowClipboardHandoff.on = AppPreferences.sharedInstance.clipboardHandoff;
    self.switchUseColorBlindPalette.on = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;

    self.switchBackupFiles.on = AppPreferences.sharedInstance.backupFiles;
    self.switchBackupImportedKeyFiles.on = AppPreferences.sharedInstance.backupIncludeImportedKeyFiles;
    self.switchHideExportOnDatabaseMenu.on = AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu;
    self.switchAllowThirdPartyKeyboards.on = AppPreferences.sharedInstance.allowThirdPartyKeyboards;
    
    self.switchShowMetadataOnDetailsScreen.on = AppPreferences.sharedInstance.showMetadataOnDetailsScreen;


    self.switchCoalesceBiometrics.on = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics;
    self.switchAddLegacyTotp.on = AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields;
    self.switchAddOtpAuthUrl.on = AppPreferences.sharedInstance.addOtpAuthUrl;
    self.switchPinYinSearch.on = AppPreferences.sharedInstance.pinYinSearchEnabled;
    
    self.switchDropboxFolderOnly.on = AppPreferences.sharedInstance.useIsolatedDropbox;
    self.switchLegacyDropboxApi.on = AppPreferences.sharedInstance.useLegacyDropboxApi;
    self.switchMinimalDropboxScopes.on = AppPreferences.sharedInstance.useMinimalDropboxScopes;
    self.switchStreamReadLargeKeyFiles.on = AppPreferences.sharedInstance.streamReadLargeKeyFiles;
    self.switchNativeKeePassEmailField.on = AppPreferences.sharedInstance.keePassEmailField;
}

- (void)bindAllowPinCodeOpen {
    self.switchAllowPinCodeOpen.on = !AppPreferences.sharedInstance.disallowAllPinCodeOpens;
}

- (void)bindAllowBiometric {
    self.labelAllowBiometric.text = [NSString stringWithFormat:NSLocalizedString(@"prefs_vc_enable_biometric_fmt", @"Allow %@ Unlock"), [BiometricsManager.sharedInstance getBiometricIdName]];
    self.switchAllowBiometric.on = !AppPreferences.sharedInstance.disallowAllBiometricId;
}

- (IBAction)onAllowPinCodeOpen:(id)sender {

































}

- (IBAction)onAllowBiometric:(id)sender {






































}

@end
