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
#import "WebDAVConnectionsViewController.h"
#import "SFTPConnectionsViewController.h"

@interface AdvancedPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchHideKeyFileName;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowAllFilesInKeyFilesLocal;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowMetadataOnDetailsScreen;
@property (weak, nonatomic) IBOutlet UISwitch *switchDetectOffline;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowClipboardHandoff;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseColorBlindPalette;

@property (weak, nonatomic) IBOutlet UISwitch *switchSyncForcePull;
@property (weak, nonatomic) IBOutlet UISwitch *switchSyncForcePush;

@property (weak, nonatomic) IBOutlet UISwitch *switchBackupFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchBackupImportedKeyFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideExportOnDatabaseMenu;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowThirdPartyKeyboards;
@property (weak, nonatomic) IBOutlet UISwitch *switchCoalesceBiometrics;

@property (weak, nonatomic) IBOutlet UISwitch *switchAddLegacyTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchAddOtpAuthUrl;

@property (weak, nonatomic) IBOutlet UISwitch *switchPinYinSearch;

@property (weak, nonatomic) IBOutlet UISwitch *switchDropboxFolderOnly;
@property (weak, nonatomic) IBOutlet UISwitch *switchNativeKeePassEmailField;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellInstantPin;
@property (weak, nonatomic) IBOutlet UISwitch *instantPinUnlock;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSftpConnections;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWebDAVConnections;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellForcePull;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSyncForcePush;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewAllBackups;
@property (weak, nonatomic) IBOutlet UISwitch *switchMarkdownNotes;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDetectIfOffline;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDropboxAppFolder;

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
    
    
    
    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        [self cell:self.cellSftpConnections setHidden:YES];
        [self cell:self.cellWebDAVConnections setHidden:YES];
        [self cell:self.cellDetectIfOffline setHidden:YES];
        [self cell:self.cellDropboxAppFolder setHidden:YES];
    }
    
    if ( AppPreferences.sharedInstance.disableThirdPartyStorageOptions && AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        [self cell:self.cellForcePull setHidden:YES];
        [self cell:self.cellSyncForcePush setHidden:YES];
        [self cell:self.cellDropboxAppFolder setHidden:YES];
    }
    
        [self bindPreferences];
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

- (IBAction)onPreferencesChanged:(id)sender {
    NSLog(@"Advanced Preference Changed: [%@]", sender);

    AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame = self.switchSyncForcePull.on;
    AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts = self.switchSyncForcePush.on;

    AppPreferences.sharedInstance.hideKeyFileOnUnlock = self.switchHideKeyFileName.on;
    AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles = self.switchShowAllFilesInKeyFilesLocal.on;
    AppPreferences.sharedInstance.monitorInternetConnectivity = self.switchDetectOffline.on;
    AppPreferences.sharedInstance.clipboardHandoff = self.switchAllowClipboardHandoff.on;
    AppPreferences.sharedInstance.colorizeUseColorBlindPalette = self.switchUseColorBlindPalette.on;
    AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu = self.switchHideExportOnDatabaseMenu.on;
    AppPreferences.sharedInstance.allowThirdPartyKeyboards = self.switchAllowThirdPartyKeyboards.on;

    AppPreferences.sharedInstance.showMetadataOnDetailsScreen = self.switchShowMetadataOnDetailsScreen.on;
    
#if !defined(NO_OFFLINE_DETECTION)
    if(AppPreferences.sharedInstance.monitorInternetConnectivity) {
        [OfflineDetector.sharedInstance startMonitoringConnectivitity];
    }
    else {
        [OfflineDetector.sharedInstance stopMonitoringConnectivitity];
    }
#endif
    
    AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics = self.switchCoalesceBiometrics.on;
    AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields = self.switchAddLegacyTotp.on;
    AppPreferences.sharedInstance.addOtpAuthUrl = self.switchAddOtpAuthUrl.on;

    AppPreferences.sharedInstance.pinYinSearchEnabled = self.switchPinYinSearch.on;
    
    AppPreferences.sharedInstance.useIsolatedDropbox = self.switchDropboxFolderOnly.on;    
    AppPreferences.sharedInstance.keePassEmailField = self.switchNativeKeePassEmailField.on;

    AppPreferences.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    AppPreferences.sharedInstance.markdownNotes = self.switchMarkdownNotes.on;
    
    [self bindPreferences];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(cell == self.cellWebDAVConnections) {
        WebDAVConnectionsViewController* vc = [WebDAVConnectionsViewController instantiateFromStoryboard];
        [vc presentFromViewController:self];
    }
    else if ( cell == self.cellSftpConnections) {
        SFTPConnectionsViewController* vc = [SFTPConnectionsViewController instantiateFromStoryboard];
        [vc presentFromViewController:self];
    }
    else if  ( cell == self.cellViewAllBackups ) {
        [self performSegueWithIdentifier:@"segueToViewAllBackups" sender:nil];
    }
}

- (void)bindPreferences {
    self.switchSyncForcePull.on = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;
    self.switchSyncForcePush.on = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    
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
    self.switchNativeKeePassEmailField.on = AppPreferences.sharedInstance.keePassEmailField;
    
    self.instantPinUnlock.on = AppPreferences.sharedInstance.instantPinUnlocking;
    self.switchMarkdownNotes.on = AppPreferences.sharedInstance.markdownNotes;
}

@end
