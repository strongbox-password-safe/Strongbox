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
#import "FileManager.h"
#import "WebDAVConnectionsViewController.h"
#import "SFTPConnectionsViewController.h"
#import "SelectItemTableViewController.h"
#import "Utils.h"
#import "CloudSessionsTableViewController.h"
#import "AutoFillNewRecordSettingsController.h"
#import "KeyFilesTableViewController.h"
#import "PasswordGenerationViewController.h"

@interface AdvancedPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordGeneration;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPasswordStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelPasswordStrengthAlgo;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAdversaryStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelAdversary;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellManageKeyFiles;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellUseICloud;
@property (weak, nonatomic) IBOutlet UILabel *labelUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseICloud;
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
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNativeKeePassEmail;

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
    
    [self cell:self.cellNativeKeePassEmail setHidden:YES];
        
    [self bindPreferences];
    [self bindCloudSessions];
    [self bindGeneral];
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


    AppPreferences.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    AppPreferences.sharedInstance.markdownNotes = self.switchMarkdownNotes.on;
    
    [self bindPreferences];
}

- (IBAction)onUseICloud:(id)sender {
    NSLog(@"Setting iCloudOn to %d", self.switchUseICloud.on);
    


















        [[AppPreferences sharedInstance] setICloudOn:self.switchUseICloud.on];
        
        [self bindCloudSessions];

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
    self.switchHideExportOnDatabaseMenu.on = AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu;
    self.switchAllowThirdPartyKeyboards.on = AppPreferences.sharedInstance.allowThirdPartyKeyboards;
    
    self.switchShowMetadataOnDetailsScreen.on = AppPreferences.sharedInstance.showMetadataOnDetailsScreen;

    self.switchCoalesceBiometrics.on = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics;
    self.switchAddLegacyTotp.on = AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields;
    self.switchAddOtpAuthUrl.on = AppPreferences.sharedInstance.addOtpAuthUrl;
    self.switchPinYinSearch.on = AppPreferences.sharedInstance.pinYinSearchEnabled;
    
    self.switchDropboxFolderOnly.on = AppPreferences.sharedInstance.useIsolatedDropbox;

    
    self.instantPinUnlock.on = AppPreferences.sharedInstance.instantPinUnlocking;
    self.switchMarkdownNotes.on = AppPreferences.sharedInstance.markdownNotes;
}

- (void)bindCloudSessions {
    self.switchUseICloud.on = [[AppPreferences sharedInstance] iCloudOn] && AppPreferences.sharedInstance.iCloudAvailable;
    self.switchUseICloud.enabled = AppPreferences.sharedInstance.iCloudAvailable;
    
    self.labelUseICloud.text = AppPreferences.sharedInstance.iCloudAvailable ?    NSLocalizedString(@"prefs_vc_use_icloud_action", @"Use iCloud") :
                                                                            NSLocalizedString(@"prefs_vc_use_icloud_disabled", @"Use iCloud (Unavailable)");
    self.labelUseICloud.enabled = AppPreferences.sharedInstance.iCloudAvailable;
    
    if ( AppPreferences.sharedInstance.disableThirdPartyStorageOptions ) {
        [self cell:self.cellCloudSessions setHidden:YES];
    }
    
    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        [self cell:self.cellUseICloud setHidden:YES];
    }
    
    [self reloadDataAnimated:NO];
}

- (void)bindGeneral {

    self.labelPasswordStrengthAlgo.text = stringForPasswordStrengthAlgo(AppPreferences.sharedInstance.passwordStrengthConfig.algorithm);
    self.labelAdversary.text = stringForAdversaryStrength(AppPreferences.sharedInstance.passwordStrengthConfig.adversaryGuessesPerSecond);
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
