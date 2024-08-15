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
#import "DatabasePreferences.h"
#import "NSArray+Extensions.h"
#import "OfflineDetector.h"
#import "BiometricsManager.h"
#import "StrongboxiOSFilesManager.h"
#import "WebDAVConnectionsViewController.h"
#import "SFTPConnectionsViewController.h"
#import "SelectItemTableViewController.h"
#import "Utils.h"
#import "CloudSessionsTableViewController.h"
#import "AutoFillNewRecordSettingsController.h"
#import "KeyFilesTableViewController.h"
#import "PasswordGenerationViewController.h"
#import "CustomizationManager.h"
#import <StoreKit/StoreKit.h>
#import "Strongbox-Swift.h"

@interface AdvancedPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordGeneration;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelPasswordStrengthAlgo;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAdversaryStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelAdversary;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellManageKeyFiles;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellCloudSessions;
@property (weak, nonatomic) IBOutlet UILabel *labelCloudSessions;

@property (weak, nonatomic) IBOutlet UISwitch *switchHideKeyFileName;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowAllFilesInKeyFilesLocal;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowMetadataOnDetailsScreen;
@property (weak, nonatomic) IBOutlet UISwitch *switchDetectOffline;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseColorBlindPalette;

@property (weak, nonatomic) IBOutlet UISwitch *switchSyncForcePull;
@property (weak, nonatomic) IBOutlet UISwitch *switchSyncForcePush;

@property (weak, nonatomic) IBOutlet UISwitch *switchBackupFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchBackupImportedKeyFiles;

@property (weak, nonatomic) IBOutlet UISwitch *switchAllowThirdPartyKeyboards;

@property (weak, nonatomic) IBOutlet UISwitch *switchAddLegacyTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchAddOtpAuthUrl;

@property (weak, nonatomic) IBOutlet UISwitch *switchPinYinSearch;

@property (weak, nonatomic) IBOutlet UISwitch *switchDropboxFolderOnly;

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

@property (weak, nonatomic) IBOutlet UISwitch *switchNewEntryUsesParentGroupIcon;

@property (weak, nonatomic) IBOutlet UISwitch *switchStripUnusedIcons;
@property (weak, nonatomic) IBOutlet UISwitch *stripHistoricalCustomIconsOnSave;

@property (weak, nonatomic) IBOutlet UISwitch *pinCodeHapticFeedback;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNewEntryDefaults;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellRedeemOfferCode;

@property (weak, nonatomic) IBOutlet UISwitch *switchAppendDateExportFilenames;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideExportOnDatabaseMenu;
@property (weak, nonatomic) IBOutlet UISwitch *switchZipExports;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellZipExports;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellHideExport;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellExportDate;

@property (weak, nonatomic) IBOutlet UISwitch *atomicSftpWrites;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAtomicSftpWrites;

@property (weak, nonatomic) IBOutlet UISwitch *switchWiFiSyncSource;
@property (weak, nonatomic) IBOutlet UILabel *labelPasscode;
@property (weak, nonatomic) IBOutlet UILabel *labelWiFiSyncServiceName;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWiFiSyncSwitch;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWiFiSyncPasscode;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWiFiSyncServiceName;

@property (weak, nonatomic) IBOutlet UILabel *wiFiSyncLastError;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWiFiSyncLastError;
@property (weak, nonatomic) IBOutlet ProLabel *wiFiSyncProLabel;
@property (weak, nonatomic) IBOutlet UILabel *labelWiFiSyncSwitch;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowDatabasesOnAppShortcutsMenu;
@property (weak, nonatomic) IBOutlet UILabel *labelStrongboxSyncStatus;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellStrongboxSyncStatus;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewStrongboxSyncStatus;

@property (weak, nonatomic) IBOutlet UISwitch *switchDisableHomeTab;
@property (weak, nonatomic) IBOutlet UISwitch *switchHardwareKeyCaching;

@end

@implementation AdvancedPreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
    
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    self.navigationController.navigationBar.hidden = NO;
    [self.navigationItem setPrompt:nil];
    [self.navigationController setNavigationBarHidden:NO];
    
    self.tableView.tableFooterView = [UIView new];
    
    
    
    if ( AppPreferences.sharedInstance.disableExport ) { 
        [self cell:self.cellZipExports setHidden:YES];
        [self cell:self.cellHideExport setHidden:YES];
        [self cell:self.cellExportDate setHidden:YES];
    }
    
    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        [self cell:self.cellSftpConnections setHidden:YES];
        [self cell:self.cellWebDAVConnections setHidden:YES];
        [self cell:self.cellDetectIfOffline setHidden:YES];
        [self cell:self.cellDropboxAppFolder setHidden:YES];
        [self cell:self.cellAtomicSftpWrites setHidden:YES];
        
        [self cell:self.cellForcePull setHidden:YES];
        [self cell:self.cellSyncForcePush setHidden:YES];

        [self cell:self.cellWiFiSyncSwitch setHidden:YES];
        [self cell:self.cellWiFiSyncPasscode setHidden:YES];
        [self cell:self.cellWiFiSyncServiceName setHidden:YES];
        
        [self cell:self.cellStrongboxSyncStatus setHidden:YES];
    }
    
    if ( AppPreferences.sharedInstance.disableThirdPartyStorageOptions ) {
        [self cell:self.cellDropboxAppFolder setHidden:YES];
    }
    
    [self cell:self.cellNewEntryDefaults setHidden:YES];

    if ( CustomizationManager.isAProBundle ) {
        [self cell:self.cellRedeemOfferCode setHidden:YES];
    }
    
    [self cell:self.cellWiFiSyncLastError setHidden:YES];
    
    [self bindPreferences];
    [self bindCloudSessions];
    [self bindPasswordStrength];
    [self bindWiFiSyncSource];
        
#ifndef NO_NETWORKING 
    __weak AdvancedPreferencesTableViewController* weakSelf = self;
    [NSNotificationCenter.defaultCenter addObserverForName:NSNotification.wiFiSyncServiceNameDidChange
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull notification) {
        [weakSelf bindWiFiSyncSource];
    }];
#endif
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];
    
    [self bindCloudSessions];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(cell == self.cellWebDAVConnections) {
        WebDAVConnectionsViewController* vc = [WebDAVConnectionsViewController instantiateFromStoryboard];
        [vc presentFromViewController:self];
    }
    else if (cell == self.cellPasswordGeneration) {
        [self performSegueWithIdentifier:@"seguePrefToPasswordPrefs" sender:nil];
    }
    else if ( cell == self.cellSftpConnections) {
        SFTPConnectionsViewController* vc = [SFTPConnectionsViewController instantiateFromStoryboard];
        [vc presentFromViewController:self];
    }
    else if  ( cell == self.cellViewAllBackups ) {
        [self performSegueWithIdentifier:@"segueToViewAllBackups" sender:nil];
    }
    else if (cell == self.cellManageKeyFiles) {
        [self performSegueWithIdentifier:@"segueToManageKeyFiles" sender:nil];
    }
    else if ( cell == self.cellRedeemOfferCode ) {
        SKPaymentQueue* queue = SKPaymentQueue.defaultQueue;
        [queue presentCodeRedemptionSheet];
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
             
            [self bindPasswordStrength];
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
            [self bindPasswordStrength];
        }];
    }
    else if ( cell == self.cellWiFiSyncPasscode ) {
        NSString* passcode = AppPreferences.sharedInstance.wiFiSyncPasscode;
        passcode = passcode.length ? passcode : NSLocalizedString(@"generic_error", @"Error");
        
        [Alerts OkCancelWithTextField:self
                      secureTextField:NO
                 textFieldPlaceHolder:NSLocalizedString(@"wifi_sync_passcode_noun", @"Passcode")
                        textFieldText:passcode
                                title:NSLocalizedString(@"wifi_sync_passcode_noun", @"Passcode")
                              message:NSLocalizedString(@"wifi_sync_change_passcode_message", @"Passcode is required on other devices to connect to this device.")
                           completion:^(NSString *text, BOOL response) {
            if ( response ) {
                if ( text.length == 0 ) {
                    text = [NSString stringWithFormat:@"%0.6d", arc4random_uniform(1000000)];
                }
                
                AppPreferences.sharedInstance.wiFiSyncPasscode = text;
                
                [self restartOrStopWiFiSyncSource];
            }
        }];
    }
    else if ( cell == self.cellWiFiSyncServiceName ) {
        [Alerts OkCancelWithTextField:self
                      secureTextField:NO
                 textFieldPlaceHolder:NSLocalizedString(@"wifi_sync_properties_service_name", @"Service Name")
                        textFieldText:AppPreferences.sharedInstance.wiFiSyncServiceName
                                title:NSLocalizedString(@"wifi_sync_properties_service_name", @"Service Name")
                              message:NSLocalizedString(@"wifi_sync_change_service_name_message", @"")
                           completion:^(NSString *text, BOOL response) {
            if ( response ) {
                AppPreferences.sharedInstance.wiFiSyncServiceName = text;
                
                [self restartOrStopWiFiSyncSource];
            }
        }];
    }
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onBackupSettingsChanged:(id)sender {
    AppPreferences.sharedInstance.backupFiles = self.switchBackupFiles.on;
    AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = self.switchBackupImportedKeyFiles.on;
    
    [StrongboxFilesManager.sharedInstance setDirectoryInclusionFromBackup:AppPreferences.sharedInstance.backupFiles
                                               importedKeyFiles:AppPreferences.sharedInstance.backupIncludeImportedKeyFiles];
    
    [self bindPreferences];
}

- (IBAction)onHardwareKeyCaching:(id)sender {
    if ( self.switchHardwareKeyCaching.on ) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"experimental_feature_warning_title", @"Experimental Feature Warning")
              message:NSLocalizedString(@"experimental_feature_warning_message_yes_no", @"Caution is required using this feature. While we have performed extensive testing, this is still an early release feature which could corrupt your database. You should only use this if you are an advanced and technical user with a regular backup system in place.\n\nThank you for helping to test Strongbox. Feedback welcome.")
               action:^(BOOL response) {
            if ( response ) {
                for ( DatabasePreferences* database in DatabasePreferences.allDatabases) {
                    [database clearCachedChallengeResponses];
                }

                [self onPreferencesChanged:sender];
            }
            else {
                [self bindPreferences];
            }
        }];
    }
    else {
        for ( DatabasePreferences* database in DatabasePreferences.allDatabases) {
            [database clearCachedChallengeResponses];
        }
        [self onPreferencesChanged:sender];
    }
}

- (IBAction)onPreferencesChanged:(id)sender {
    slog(@"Advanced Preference Changed: [%@]", sender);

    AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame = self.switchSyncForcePull.on;
    AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts = self.switchSyncForcePush.on;

    AppPreferences.sharedInstance.hideKeyFileOnUnlock = self.switchHideKeyFileName.on;
    AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles = self.switchShowAllFilesInKeyFilesLocal.on;
    AppPreferences.sharedInstance.monitorInternetConnectivity = self.switchDetectOffline.on;
    
    AppPreferences.sharedInstance.colorizeUseColorBlindPalette = self.switchUseColorBlindPalette.on;

    
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
    

    AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields = self.switchAddLegacyTotp.on;
    AppPreferences.sharedInstance.addOtpAuthUrl = self.switchAddOtpAuthUrl.on;

    AppPreferences.sharedInstance.pinYinSearchEnabled = self.switchPinYinSearch.on;
    
    AppPreferences.sharedInstance.useIsolatedDropbox = self.switchDropboxFolderOnly.on;

    AppPreferences.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    AppPreferences.sharedInstance.pinCodeHapticFeedback = self.pinCodeHapticFeedback.on;

    AppPreferences.sharedInstance.markdownNotes = self.switchMarkdownNotes.on;
    AppPreferences.sharedInstance.useParentGroupIconOnCreate = self.switchNewEntryUsesParentGroupIcon.on;
    
    AppPreferences.sharedInstance.stripUnusedIconsOnSave = self.switchStripUnusedIcons.on;
    AppPreferences.sharedInstance.stripUnusedHistoricalIcons = self.stripHistoricalCustomIconsOnSave.on;
        
    AppPreferences.sharedInstance.appendDateToExportFileName = self.switchAppendDateExportFilenames.on;
    AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu = self.switchHideExportOnDatabaseMenu.on;
    AppPreferences.sharedInstance.zipExports = self.switchZipExports.on;

    AppPreferences.sharedInstance.atomicSftpWrite = self.atomicSftpWrites.on;
    AppPreferences.sharedInstance.showDatabasesOnAppShortcutMenu = self.switchShowDatabasesOnAppShortcutsMenu.on;

    if ( !AppPreferences.sharedInstance.showDatabasesOnAppShortcutMenu ) {
        [[UIApplication sharedApplication] setShortcutItems:@[]]; 
    }
    
    AppPreferences.sharedInstance.disableHomeTab = self.switchDisableHomeTab.on;

    AppPreferences.sharedInstance.hardwareKeyCachingBeta = self.switchHardwareKeyCaching.on;

    [self bindPreferences];
}

- (void)bindPreferences {
    self.switchSyncForcePull.on = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;
    self.switchSyncForcePush.on = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    
    self.switchHideKeyFileName.on = AppPreferences.sharedInstance.hideKeyFileOnUnlock;
    self.switchShowAllFilesInKeyFilesLocal.on = AppPreferences.sharedInstance.showAllFilesInLocalKeyFiles;
    self.switchDetectOffline.on = AppPreferences.sharedInstance.monitorInternetConnectivity;
    self.switchUseColorBlindPalette.on = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;

    self.switchBackupFiles.on = AppPreferences.sharedInstance.backupFiles;
    self.switchBackupImportedKeyFiles.on = AppPreferences.sharedInstance.backupIncludeImportedKeyFiles;
    self.switchAllowThirdPartyKeyboards.on = AppPreferences.sharedInstance.allowThirdPartyKeyboards;
    
    self.switchShowMetadataOnDetailsScreen.on = AppPreferences.sharedInstance.showMetadataOnDetailsScreen;

    self.switchAddLegacyTotp.on = AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields;
    self.switchAddOtpAuthUrl.on = AppPreferences.sharedInstance.addOtpAuthUrl;
    self.switchPinYinSearch.on = AppPreferences.sharedInstance.pinYinSearchEnabled;
    
    self.switchDropboxFolderOnly.on = AppPreferences.sharedInstance.useIsolatedDropbox;

    self.instantPinUnlock.on = AppPreferences.sharedInstance.instantPinUnlocking;
    self.pinCodeHapticFeedback.on = AppPreferences.sharedInstance.pinCodeHapticFeedback;

    self.switchMarkdownNotes.on = AppPreferences.sharedInstance.markdownNotes;
    self.switchNewEntryUsesParentGroupIcon.on = AppPreferences.sharedInstance.useParentGroupIconOnCreate;
    
    self.switchStripUnusedIcons.on = AppPreferences.sharedInstance.stripUnusedIconsOnSave;
    self.stripHistoricalCustomIconsOnSave.on = AppPreferences.sharedInstance.stripUnusedHistoricalIcons;
    
    self.switchHideExportOnDatabaseMenu.on = AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu;
    self.switchZipExports.on = AppPreferences.sharedInstance.zipExports;
    self.switchAppendDateExportFilenames.on = AppPreferences.sharedInstance.appendDateToExportFileName;
    
    self.atomicSftpWrites.on = AppPreferences.sharedInstance.atomicSftpWrite;
    self.switchShowDatabasesOnAppShortcutsMenu.on = AppPreferences.sharedInstance.showDatabasesOnAppShortcutMenu;
    
    self.switchDisableHomeTab.on = AppPreferences.sharedInstance.disableHomeTab;
    
    self.switchHardwareKeyCaching.on = AppPreferences.sharedInstance.hardwareKeyCachingBeta;
    
#ifndef NO_NETWORKING
    [CloudKitDatabasesInteractor.shared getCloudKitAccountStatusWithCompletionHandler:^(CKAccountStatus status, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStrongboxSyncStatus:status error:error];
        });
    }];
#endif
}

#ifndef NO_NETWORKING
- (void)updateStrongboxSyncStatus:(CKAccountStatus)status
                            error:(NSError* _Nullable)error {
    if ( error ) {
        self.labelStrongboxSyncStatus.textColor = UIColor.systemRedColor;
        self.labelStrongboxSyncStatus.text = [NSString stringWithFormat:@"[%ld] - %@", error.code, error.localizedDescription];
        
        self.imageViewStrongboxSyncStatus.image = [UIImage systemImageNamed:@"exclamationmark.triangle" withConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:UIColor.systemRedColor]];
    }
    else {
        self.labelStrongboxSyncStatus.textColor = status == CKAccountStatusAvailable ? UIColor.secondaryLabelColor : UIColor.systemOrangeColor;
        self.labelStrongboxSyncStatus.text = [CloudKitDatabasesInteractor getAccountStatusStringWithStatus:status];
        
        if ( status == CKAccountStatusAvailable ) {
            self.imageViewStrongboxSyncStatus.image = [UIImage systemImageNamed:@"checkmark.circle" withConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:UIColor.systemGreenColor]];
        }
        else {
            self.imageViewStrongboxSyncStatus.image = [UIImage systemImageNamed:@"exclamationmark.triangle" withConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:UIColor.systemOrangeColor]];
        }
    }
}
#endif

- (void)bindCloudSessions {
    if ( AppPreferences.sharedInstance.disableThirdPartyStorageOptions ) {
        [self cell:self.cellCloudSessions setHidden:YES];
    }
        
    [self reloadDataAnimated:NO];
}

- (void)bindPasswordStrength {

    self.labelPasswordStrengthAlgo.text = stringForPasswordStrengthAlgo(AppPreferences.sharedInstance.passwordStrengthConfig.algorithm);
    self.labelAdversary.text = stringForAdversaryStrength(AppPreferences.sharedInstance.passwordStrengthConfig.adversaryGuessesPerSecond);
}

- (IBAction)onWiFiSyncSourceChanged:(id)sender {
    AppPreferences.sharedInstance.runAsWiFiSyncSourceDevice = self.switchWiFiSyncSource.on;
    
    [self restartOrStopWiFiSyncSource];
}

- (void)restartOrStopWiFiSyncSource {
#ifndef NO_NETWORKING 
    NSError* error;
    
    if ( ![WiFiSyncServer.shared startOrStopWiFiSyncServerAccordingToSettingsAndReturnError:&error] ) {
        slog(@"🔴 Error stopping/starting Wi-Fi Sync Source %@", error);
        
        [Alerts error:self error:error];
    }
    
    [self bindWiFiSyncSource];
#endif
}

- (void)bindWiFiSyncSource {
    BOOL isPro = AppPreferences.sharedInstance.isPro;
    BOOL isOn = AppPreferences.sharedInstance.runAsWiFiSyncSourceDevice && isPro;
    
    self.switchWiFiSyncSource.on = isOn;
    self.switchWiFiSyncSource.enabled = isPro;
    self.labelWiFiSyncSwitch.enabled = isPro;
    
    self.wiFiSyncProLabel.proFont = FontManager.sharedInstance.caption2Font;
    self.wiFiSyncProLabel.hidden = isPro;

#ifndef NO_NETWORKING 
    self.wiFiSyncLastError.text = WiFiSyncServer.shared.lastError;

    NSString* serviceName = WiFiSyncServer.shared.lastRegisteredServiceName.length != 0 ? WiFiSyncServer.shared.lastRegisteredServiceName : (AppPreferences.sharedInstance.wiFiSyncServiceName.length != 0 && !isOn ? AppPreferences.sharedInstance.wiFiSyncServiceName : NSLocalizedString(@"generic_loading", @"Loading..."));
    
    self.labelWiFiSyncServiceName.text = serviceName;
    
    self.labelWiFiSyncServiceName.enabled = WiFiSyncServer.shared.lastRegisteredServiceName.length != 0 || (AppPreferences.sharedInstance.wiFiSyncServiceName.length != 0 && !isOn);

    [self cell:self.cellWiFiSyncLastError setHidden:WiFiSyncServer.shared.lastError == nil];
#endif

    NSString* passcode = AppPreferences.sharedInstance.wiFiSyncPasscode;
    passcode = passcode.length ? passcode : NSLocalizedString(@"generic_error", @"Error");
    self.labelPasscode.text = passcode;
    
    [self cell:self.cellWiFiSyncPasscode setHidden:!isOn];
    [self cell:self.cellWiFiSyncServiceName setHidden:!isOn];

    [self reloadDataAnimated:YES];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"seguePrefToPasswordPrefs"]) {
        PasswordGenerationViewController* vc = (PasswordGenerationViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"seguePrefsToCloudSessions"]) {
        CloudSessionsTableViewController* vc = (CloudSessionsTableViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"seguePrefsToNewEntryDefaults"]) {
        AutoFillNewRecordSettingsController* vc = (AutoFillNewRecordSettingsController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueToManageKeyFiles"]) {
        KeyFilesTableViewController* vc = (KeyFilesTableViewController*)segue.destinationViewController;
        vc.manageMode = YES;
    }
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

@end
