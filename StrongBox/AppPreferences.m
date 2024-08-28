//
//  SharedAppAndAutoFillSettings.m
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AppPreferences.h"
#import "Constants.h"
#import "NSArray+Extensions.h"
#import "SecretStore.h"
#import "PasswordMaker.h"

static NSString* const kDefaultAppGroupName = @"group.strongbox.mcguill";
static NSString* cachedAppGroupName;

static const NSInteger kDefaultClearClipboardTimeout = 90;

static NSString* const kIsProKey = @"isPro";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kClipboardHandoff = @"clipboardHandoff";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kHideTips = @"hideTips";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kQuickLaunchUuid = @"quickLaunchUuid";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kHideKeyFileOnUnlock = @"hideKeyFileOnUnlock";
static NSString* const kShowAllFilesInLocalKeyFiles = @"showAllFilesInLocalKeyFiles";
static NSString* const kMonitorInternetConnectivity = @"monitorInternetConnectivity";
static NSString* const kInstantPinUnlocking = @"instantPinUnlocking";

static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kShowDatabaseIcon = @"showDatabaseIcon";
static NSString* const kShowDatabaseStatusIcon = @"showDatabaseStatusIcon";
static NSString* const kDatabaseCellTopSubtitle = @"databaseCellTopSubtitle";
static NSString* const kDatabaseCellSubtitle1 = @"databaseCellSubtitle1";
static NSString* const kDatabaseCellSubtitle2 = @"databaseCellSubtitle2";
static NSString* const kShowDatabasesSeparator = @"showDatabasesSeparator";

static NSString* const kSyncPullEvenIfModifiedDateSame = @"syncPullEvenIfModifiedDateSame";
static NSString* const kSyncForcePushDoNotCheckForConflicts = @"syncForcePushDoNotCheckForConflicts";

static NSString* const kMainAppDidChangeDatabases = @"mainAppDidChangeDatabases";
static NSString* const kAutoFillDidChangeDatabases = @"autoFillDidChangeDatabases";
static NSString* const kShowMetadataOnDetailsScreen  = @"legacyShowMetadataOnDetailsScreen";
static NSString* const kQuickTypeTitleThenUsername = @"quickTypeTitleThenUsername";
static NSString* const kUserHasOptedInToThirdPartyStorageLibraries = @"userHasOptedInToThirdPartyStorageLibraries";


static NSString* const kAutoFillExitedCleanly = @"autoFillExitedCleanly";
static NSString* const kAutoFillWroteCleanly = @"autoFillWroteCleanly";
static NSString* const kHaveWarnedAboutAutoFillCrash = @"haveWarnedAboutAutoFillCrash";
static NSString* const KDontNotifyToSwitchToMainAppForSync = @"dontNotifyToSwitchToMainAppForSync";
static NSString* const kStoreAutoFillServiceIdentifiersInNotes = @"storeAutoFillServiceIdentifiersInNotes";
static NSString* const kUseFullUrlAsURLSuggestion = @"useFullUrlAsURLSuggestion";
static NSString* const kAutoProceedOnSingleMatch = @"autoProceedOnSingleMatch";
static NSString* const kShowAutoFillTotpCopiedMessage = @"showAutoFillTotpCopiedMessage";
static NSString* const kHasOnboardedForAutoFillConvenienceAutoUnlock = @"hasOnboardedForAutoFillConvenienceAutoUnlock";
static NSString* const kAutoFillAutoLaunchSingleDatabase = @"autoFillAutoLaunchSingleDatabase";
static NSString* const kAutoFillQuickLaunchUuid = @"autoFillQuickLaunchUuid";
static NSString* const kMigratedQuickLaunchToAutoFill = @"migratedQuickLaunchToAutoFill";
static NSString* const kAutoFillShowFavourites = @"autoFillShowPinned";
static NSString* const kCoalesceAppLockAndQuickLaunchBiometrics = @"coalesceAppLockAndQuickLaunchBiometrics";
static NSString* const kAppPrivacyShieldMode = @"appPrivacyShieldMode";
static NSString* const kMigratedOfflineDetectedBehaviour = @"migratedOfflineDetectedBehaviour";



static NSString* const kLaunchCountKey = @"launchCount";

static NSString* const kInstallDate = @"installDate";
static NSString* const kShowKeePassCreateSafeOptions = @"showKeePassCreateSafeOptions";

static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails";
static NSString* const kDeleteDataAfterFailedUnlockCount = @"deleteDataAfterFailedUnlockCount";
static NSString* const kFailedUnlockAttempts = @"failedUnlockAttempts";
static NSString* const kAppLockAppliesToPreferences = @"appLockAppliesToPreferences";

static NSString* const kAppLockMode = @"appLockMode2.0";
static NSString* const kAppLockPin = @"appLockPin2.0";
static NSString* const kAppLockDelay = @"appLockDelay2.0";

static NSString* const kLastFreeTrialNudge = @"lastFreeTrialNudge";

static NSString* const kBackupFiles = @"backupFiles";
static NSString* const kBackupIncludeImportedKeyFiles = @"backupIncludeImportedKeyFiles";
static NSString* const kHaveAskedAboutBackupSettings = @"haveAskedAboutBackupSettings";
static NSString* const kHideExportFromDatabaseContextMenu = @"hideExportFromDatabaseContextMenu";
static NSString* const kAllowThirdPartyKeyboards = @"allowThirdPartyKeyboards";
static NSString* const kAppLockAllowDevicePasscodeFallbackForBio = @"appLockAllowDevicePasscodeFallbackForBio";
static NSString* const kFullFileProtection = @"fullFileProtection";
static NSString* const kHaveAttemptedMigrationToFullFileProtection = @"haveAttemptedMigrationToFullFileProtection";
static NSString* const kPasswordStrengthConfig = @"passwordStrengthConfig";

static NSString* const kAddLegacySupplementaryTotpCustomFields = @"addLegacySupplementaryTotpCustomFields";
static NSString* const kAddOtpAuthUrl = @"addOtpAuthUrl";

static NSString* const kPromptedForSale = @"promptedForSale3";
static NSString* const kPinYinSearchEnabled = @"pinYinSearchEnabled";

static NSString* const kLastKnownGoodDatabaseState = @"lastKnownGoodDatabaseState";
static NSString* const kAutoFillLastKnownGoodDatabaseState = @"autoFillLastKnownGoodDatabaseState";

static NSString* const kScheduledTipsCheckDone = @"scheduledTipsCheckDone";
static NSString* const kHasShownFirstRunWelcome = @"hasShownFirstRunWelcome";
static NSString* const kHasShownFirstRunFinalWelcome = @"hasShownFirstRunFinalWelcome";

static NSString* const kPromptToEnableAutoFill = @"promptToEnableAutoFill";
static NSString* const kLastAskToEnableAutoFill = @"lastAskToEnableAutoFill";

static NSString* const kFreeTrialNudgeCount = @"freeTrialNudgeCount";

static NSString* const kHasPromptedThatFreeTrialWillEndSoon = @"hasPromptedThatFreeTrialWillEndSoon";
static NSString* const kAppHasBeenDowngradedToFreeEdition = @"appHasBeenDowngradedToFreeEdition";
static NSString* const kHasPromptedThatAppHasBeenDowngradedToFreeEdition = @"hasPromptedThatAppHasBeenDowngradedToFreeEdition";

static NSString* const kDisableFavIconFeature = @"disableFavIconFeature";
static NSString* const kDisableNativeNetworkStorageOptions = @"disableNativeNetworkStorageOptions";

static NSString* const kUseIsolatedDropbox = @"useIsolatedDropbox";


static NSString* const kExportItemsPreserveUUIDs = @"exportItemsPreserveUUIDs";
static NSString* const kExportItemsReplaceExisting = @"exportItemsReplaceExisting";

static NSString* const kExportItemsPreserveTimestamps = @"exportItemsPreserveTimestamps";
static NSString* const kDuplicateItemPreserveTimestamp = @"duplicateItemPreserveTimestamp";
static NSString* const kDuplicateItemReferencePassword = @"duplicateItemReferencePassword";
static NSString* const kDuplicateItemReferenceUsername = @"duplicateItemReferenceUsername";

static NSString* const kDuplicateItemEditAfterwards = @"duplicateItemEditAfterwards";
static NSString* const kDisableThirdPartyStorageOptions = @"disableThirdPartyStorageOptions";

static NSString* const kMarkdownNotes = @"markdownNotes";
static NSString* const kAutoFillLongTapPreview = @"autoFillLongTapPreview";
static NSString* const kHideTipJar = @"hideTipJar";
static NSString* const kUseParentGroupIconOnCreate = @"useParentGroupIconOnCreate";
static NSString* const kStripUnusedIconsOnSave = @"stripUnusedIconsOnSave";
static NSString* const kPinCodeHapticFeedback = @"pinCodeHapticFeedback";
static NSString* const kHasMigratedToLazySync = @"hasMigratedToLazySync-Iteration-5-RB-OneDrive";
static NSString* const kVisibleBrowseTabs = @"visibleBrowseTabs";
static NSString* const kBusinessOrganisationName = @"businessOrganisationName";
static NSString* const kLastQuickTypeMultiDbRegularClear = @"lastQuickTypeMultiDbRegularClear";
static NSString* const kAppendDateToExportFileName = @"appendDateToExportFileName";

static NSString* const kDatabasesAreAlwaysReadOnly = @"databasesAreAlwaysReadOnly";
static NSString* const kDisableExport = @"disableExport";
static NSString* const kDisablePrinting = @"disablePrinting";
static NSString* const kAtomicSftpWrite = @"atomicSftpWrite";
static NSString* const kStripUnusedHistoricalIcons = @"stripUnusedHistoricalIcons";
static NSString* const kDatabasesSerializationError = @"databasesSerializationError";
static NSString* const kWiFiSyncHasBeenGrantedPermission = @"wiFiSyncHasBeenGrantedPermission";
static NSString* const kDisableWiFiSync = @"disableWiFiSync";
static NSString* const kZipExports = @"zipExports";

static NSString* const kWiFiSyncOn = @"wiFiSyncOn";
static NSString* const kWiFiSyncServiceName = @"wiFiSyncServiceName";
static NSString* const kWiFiSyncPasscodeSSKey = @"wiFiSyncPasscodeSSKey";
static NSString* const kCloudKitZoneCreated = @"cloudKitZoneCreated";
static NSString* const kChangeNotificationsSubscriptionCreated = @"changeNotificationsSubscriptionCreated";
static NSString* const kShowDatabasesOnAppShortcutMenu = @"showDatabasesOnAppShortcutMenu";
static NSString* const kHasWarnedAboutCloudKitUnavailability = @"hasWarnedAboutCloudKitUnavailability";
static NSString* const kHasGotUserNotificationsPermissions = @"hasGotUserNotificationsPermissions";
static NSString* const kLastAskToEnableNotifications = @"lastAskToEnableNotifications";
static NSString* const kWiFiSyncPasscodeSSKeyHasBeenInitialized = @"wiFiSyncPasscodeSSKeyHasBeenInitialized";
static NSString* const kLastWiFiSyncPasscodeError = @"lastWiFiSyncPasscodeError";
static NSString* const kUseUSGovAuthority = @"useUSGovAuthority";
static NSString* const kAppAppearance = @"appAppearance";
static NSString* const kShowDatabaseNamesInBrowse = @"showDatabaseNamesInBrowse";
static NSString* const kWarnAboutLocalDeviceDatabases = @"warnAboutLocalDeviceDatabases";

static NSString* const kDisableCopyTo = @"disableCopyTo";
static NSString* const kDisableMakeVisibleInFiles = @"disableMakeVisibleInFiles";
static NSString* const kLastCloudKitRefresh = @"lastCloudKitRefresh";
static NSString* const kDisableHomeTab = @"disableHomeTab"; 
static NSString* const kHardwareKeyCachingBeta = @"hardwareKeyCachingBeta2"; 
static NSString* const kHasMigratedInconsistentHardwareKeysForCachingFeature = @"hasMigratedInconsistentHardwareKeysForCachingFeature"; 

@implementation AppPreferences

+ (void)initialize {
    if(self == [AppPreferences class]) {
        
        
        

        cachedAppGroupName = kDefaultAppGroupName;
    }
}

+ (instancetype)sharedInstance {
    static AppPreferences *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AppPreferences alloc] init];
    });
    
    return sharedInstance;
}



- (NSString *)appGroupName {
    return cachedAppGroupName;
}

- (NSUserDefaults *)sharedAppGroupDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
    
    if(defaults == nil) {
        slog(@"ERROR: Could not get NSUserDefaults for Suite Name: [%@]", self.appGroupName);
    }
    
    return defaults;
}



- (BOOL)hasMigratedInconsistentHardwareKeysForCachingFeature {
    return [self getBool:kHasMigratedInconsistentHardwareKeysForCachingFeature];
}

- (void)setHasMigratedInconsistentHardwareKeysForCachingFeature:(BOOL)hasMigratedInconsistentHardwareKeysForCachingFeature {
    [self setBool:kHasMigratedInconsistentHardwareKeysForCachingFeature value:hasMigratedInconsistentHardwareKeysForCachingFeature];
}

- (BOOL)hardwareKeyCachingBeta {
    return [self getBool:kHardwareKeyCachingBeta fallback:YES];
}

- (void)setHardwareKeyCachingBeta:(BOOL)hardwareKeyCachingBeta {
    [self setBool:kHardwareKeyCachingBeta value:hardwareKeyCachingBeta];
}

- (BOOL)disableHomeTab {
    return [self getBool:kDisableHomeTab];
}

- (void)setDisableHomeTab:(BOOL)disableHomeTab {
    [self setBool:kDisableHomeTab value:disableHomeTab];
}

- (NSDate *)lastCloudKitRefresh {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    return [userDefaults objectForKey:kLastCloudKitRefresh];
}

- (void)setLastCloudKitRefresh:(NSDate *)lastCloudKitRefresh {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:lastCloudKitRefresh forKey:kLastCloudKitRefresh];
    
    [userDefaults synchronize];
}

- (BOOL)disableCopyTo {
    return [self getBool:kDisableCopyTo fallback:self.disableExport];
}

- (void)setDisableCopyTo:(BOOL)disableCopyTo {
    [self setBool:kDisableCopyTo value:disableCopyTo];
}

- (BOOL)disableMakeVisibleInFiles {
    return [self getBool:kDisableMakeVisibleInFiles fallback:self.disableExport];
}

- (void)setDisableMakeVisibleInFiles:(BOOL)disableMakeVisibleInFiles {
    [self setBool:kDisableMakeVisibleInFiles value:disableMakeVisibleInFiles];
}

- (BOOL)warnAboutLocalDeviceDatabases {
    return [self getBool:kWarnAboutLocalDeviceDatabases fallback:YES];
}

- (void)setWarnAboutLocalDeviceDatabases:(BOOL)warnAboutLocalDeviceDatabases {
    [self setBool:kWarnAboutLocalDeviceDatabases value:warnAboutLocalDeviceDatabases];
}

- (BOOL)showDatabaseNamesInBrowse {
    return [self getBool:kShowDatabaseNamesInBrowse fallback:YES];
}

- (void)setShowDatabaseNamesInBrowse:(BOOL)showDatabaseNamesInBrowse {
    [self setBool:kShowDatabaseNamesInBrowse value:showDatabaseNamesInBrowse];
}

- (AppAppearance)appAppearance {
    return [self getInteger:kAppAppearance];
}

- (void)setAppAppearance:(AppAppearance)appAppearance {
    [self setInteger:kAppAppearance value:appAppearance];
}

- (BOOL)useOneDriveUSGovCloudInstance {
    return NO;

}

- (void)setUseOneDriveUSGovCloudInstance:(BOOL)useOneDriveUSGovCloudInstance {

}

- (BOOL)hasGotUserNotificationsPermissions {
    return [self getBool:kHasGotUserNotificationsPermissions];
}

- (void)setHasGotUserNotificationsPermissions:(BOOL)hasGotUserNotificationsPermissions {
    [self setBool:kHasGotUserNotificationsPermissions value:hasGotUserNotificationsPermissions];
}

- (BOOL)hasWarnedAboutCloudKitUnavailability {
    return [self getBool:kHasWarnedAboutCloudKitUnavailability];
}

- (void)setHasWarnedAboutCloudKitUnavailability:(BOOL)hasWarnedAboutCloudKitUnavailability {
    [self setBool:kHasWarnedAboutCloudKitUnavailability value:hasWarnedAboutCloudKitUnavailability];
}

- (BOOL)showDatabasesOnAppShortcutMenu {
#ifndef NO_NETWORKING
    return [self getBool:kShowDatabasesOnAppShortcutMenu fallback:YES];
#else
    return [self getBool:kShowDatabasesOnAppShortcutMenu fallback:NO];
#endif
}

- (void)setShowDatabasesOnAppShortcutMenu:(BOOL)showDatabasesOnAppShortcutMenu {
    [self setBool:kShowDatabasesOnAppShortcutMenu value:showDatabasesOnAppShortcutMenu];
}

- (BOOL)changeNotificationsSubscriptionCreated {
    return [self getBool:kChangeNotificationsSubscriptionCreated];
}

- (void)setChangeNotificationsSubscriptionCreated:(BOOL)changeNotificationsSubscriptionCreated {
    [self setBool:kChangeNotificationsSubscriptionCreated value:changeNotificationsSubscriptionCreated];
}

- (BOOL)cloudKitZoneCreated {
    return [self getBool:kCloudKitZoneCreated];
}

- (void)setCloudKitZoneCreated:(BOOL)cloudKitZoneCreated {
    [self setBool:kCloudKitZoneCreated value:cloudKitZoneCreated];
}

- (BOOL)disableWiFiSyncClientMode {
    return [self getBool:kDisableWiFiSync];
}

- (void)setDisableWiFiSyncClientMode:(BOOL)disableWiFiSync {
    [self setBool:kDisableWiFiSync value:disableWiFiSync];
}

- (BOOL)runAsWiFiSyncSourceDevice {
    return [self getBool:kWiFiSyncOn fallback:NO];
}

- (void)setRunAsWiFiSyncSourceDevice:(BOOL)wiFiSyncOn {
    [self setBool:kWiFiSyncOn value:wiFiSyncOn];
}

- (BOOL)wiFiSyncPasscodeSSKeyHasBeenInitialized {
    return [self getBool:kWiFiSyncPasscodeSSKeyHasBeenInitialized];
}

- (void)setWiFiSyncPasscodeSSKeyHasBeenInitialized:(BOOL)wiFiSyncPasscodeSSKeyHasBeenInitialized {
    [self setBool:kWiFiSyncPasscodeSSKeyHasBeenInitialized value:wiFiSyncPasscodeSSKeyHasBeenInitialized];
}

- (NSString *)lastWiFiSyncPasscodeError {
    return [self getString:kLastWiFiSyncPasscodeError fallback:nil];
}

- (void)setLastWiFiSyncPasscodeError:(NSString *)lastWiFiSyncPasscodeError {
    [self setString:kLastWiFiSyncPasscodeError value:lastWiFiSyncPasscodeError];
}

- (NSString *)wiFiSyncPasscode {
    NSError* error;
    NSString* thePasscode = [SecretStore.sharedInstance getSecureString:kWiFiSyncPasscodeSSKey error:&error];
    
    [self setLastWiFiSyncPasscodeError:error ? [NSString stringWithFormat:@"%@", error] : nil];
    
    if ( self.wiFiSyncPasscodeSSKeyHasBeenInitialized ) {
        if ( thePasscode == nil ) {
            slog(@"🔴 WiFiSync Passcode nil but has already been initialized. Something very wrong... [%@]", error);
        }
        
        return thePasscode;
    }
    else {
        if (  thePasscode != nil ) {
            self.wiFiSyncPasscodeSSKeyHasBeenInitialized = YES;
            return thePasscode;
        }
        else {
            NSString* passcode = [NSString stringWithFormat:@"%0.6d", arc4random_uniform(1000000)];
            
            [self setWiFiSyncPasscode:passcode];
            
            self.wiFiSyncPasscodeSSKeyHasBeenInitialized = YES;
            
            return passcode;
        }
    }
}

- (void)setWiFiSyncPasscode:(NSString *)wiFiSyncPasscode {
    [SecretStore.sharedInstance setSecureString:wiFiSyncPasscode forIdentifier:kWiFiSyncPasscodeSSKey];
}

- (NSString *)wiFiSyncServiceName {
    return [self getString:kWiFiSyncServiceName fallback:nil];
}

- (void)setWiFiSyncServiceName:(NSString *)wiFiSyncServiceName {
    [self setString:kWiFiSyncServiceName value:wiFiSyncServiceName];
}

- (BOOL)zipExports {
    return [self getBool:kZipExports fallback:YES];
}

- (void)setZipExports:(BOOL)zipExports {
    [self setBool:kZipExports value:zipExports];
}

- (BOOL)wiFiSyncHasRequestedNetworkPermissions {
    return [self getBool:kWiFiSyncHasBeenGrantedPermission];
}

- (void)setWiFiSyncHasRequestedNetworkPermissions:(BOOL)wiFiSyncHasBeenGrantedPermission {
    [self setBool:kWiFiSyncHasBeenGrantedPermission value:wiFiSyncHasBeenGrantedPermission];
}

- (NSString *)databasesSerializationError {
    return [self getString:kDatabasesSerializationError];
}

- (void)setDatabasesSerializationError:(NSString *)databasesSerializationError {
    [self setString:kDatabasesSerializationError value:databasesSerializationError];
}

- (BOOL)stripUnusedHistoricalIcons {
    return [self getBool:kStripUnusedHistoricalIcons fallback:AppPreferences.sharedInstance.stripUnusedIconsOnSave];
}

- (void)setStripUnusedHistoricalIcons:(BOOL)stripUnusedHistoricalIcons {
    [self setBool:kStripUnusedHistoricalIcons value:stripUnusedHistoricalIcons];
}

- (BOOL)atomicSftpWrite {
    return [self getBool:kAtomicSftpWrite fallback:YES];
}

- (void)setAtomicSftpWrite:(BOOL)atomicSftpWrite {
    [self setBool:kAtomicSftpWrite value:atomicSftpWrite];
}

- (BOOL)disableExport {
    return [self getBool:kDisableExport];
}

- (void)setDisableExport:(BOOL)disableExport {
    [self setBool:kDisableExport value:disableExport];
}

- (BOOL)disablePrinting {
    return [self getBool:kDisablePrinting];
}

- (void)setDisablePrinting:(BOOL)disablePrinting {
    [self setBool:kDisablePrinting value:disablePrinting];
}

- (BOOL)appendDateToExportFileName {
    return [self getBool:kAppendDateToExportFileName fallback:YES];
}

- (void)setAppendDateToExportFileName:(BOOL)appendDateToExportFileName {
    [self setBool:kAppendDateToExportFileName value:appendDateToExportFileName];
}

- (NSDate *)lastQuickTypeMultiDbRegularClear {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    return [userDefaults objectForKey:kLastQuickTypeMultiDbRegularClear];
}

- (void)setLastQuickTypeMultiDbRegularClear:(NSDate *)lastQuickTypeMultiDbRegularClear {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:lastQuickTypeMultiDbRegularClear forKey:kLastQuickTypeMultiDbRegularClear];
    
    [userDefaults synchronize];
}

- (NSString *)businessOrganisationName {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults objectForKey:kBusinessOrganisationName];
}

- (void)setBusinessOrganisationName:(NSString *)businessOrganisationName {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setObject:businessOrganisationName forKey:kBusinessOrganisationName];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (BOOL)hasMigratedToLazySync {
    return [self getBool:kHasMigratedToLazySync];
}

- (void)setHasMigratedToLazySync:(BOOL)hasMigratedToLazySync {
    [self setBool:kHasMigratedToLazySync value:hasMigratedToLazySync];
}

- (BOOL)pinCodeHapticFeedback {
    return [self getBool:kPinCodeHapticFeedback fallback:YES];
}

- (void)setPinCodeHapticFeedback:(BOOL)pinCodeHapticFeedback {
    [self setBool:kPinCodeHapticFeedback value:pinCodeHapticFeedback];
}

- (BOOL)stripUnusedIconsOnSave {
    return [self getBool:kStripUnusedIconsOnSave fallback:YES];
}

- (void)setStripUnusedIconsOnSave:(BOOL)stripUnusedIconsOnSave {
    return [self setBool:kStripUnusedIconsOnSave value:stripUnusedIconsOnSave];
}

- (BOOL)useParentGroupIconOnCreate {
    return [self getBool:kUseParentGroupIconOnCreate fallback:YES];
}

- (void)setUseParentGroupIconOnCreate:(BOOL)useParentGroupIconOnCreate {
    [self setBool:kUseParentGroupIconOnCreate value:useParentGroupIconOnCreate];
}

- (BOOL)hideTipJar {
    return [self getBool:kHideTipJar];
}

- (void)setHideTipJar:(BOOL)hideTipJar {
    return [self setBool:kHideTipJar value:hideTipJar];
}

- (BOOL)autoFillLongTapPreview {
    return [self getBool:kAutoFillLongTapPreview fallback:YES];
}

- (void)setAutoFillLongTapPreview:(BOOL)autoFillLongTapPreview {
    [self setBool:kAutoFillLongTapPreview value:autoFillLongTapPreview];
}

- (BOOL)markdownNotes {
    return [self getBool:kMarkdownNotes fallback:YES];
}

- (void)setMarkdownNotes:(BOOL)markdownNotes {
    [self setBool:kMarkdownNotes value:markdownNotes];
}

- (BOOL)disableThirdPartyStorageOptions {
    return [self getBool:kDisableThirdPartyStorageOptions];
}

- (void)setDisableThirdPartyStorageOptions:(BOOL)disableThirdPartyStorageOptions {
    [self setBool:kDisableThirdPartyStorageOptions value:disableThirdPartyStorageOptions];
}

- (BOOL)duplicateItemEditAfterwards {
    return [self getBool:kDuplicateItemEditAfterwards];
}

- (void)setDuplicateItemEditAfterwards:(BOOL)duplicateItemEditAfterwards {
    [self setBool:kDuplicateItemEditAfterwards value:duplicateItemEditAfterwards];
}

- (BOOL)exportItemsPreserveTimestamps {
    return [self getBool:kExportItemsPreserveTimestamps fallback:YES];
}

- (void)setExportItemsPreserveTimestamps:(BOOL)exportItemsPreserveTimestamps {
    [self setBool:kExportItemsPreserveTimestamps value:exportItemsPreserveTimestamps];
}

- (BOOL)duplicateItemPreserveTimestamp {
    return [self getBool:kDuplicateItemPreserveTimestamp];
}

- (void)setDuplicateItemPreserveTimestamp:(BOOL)duplicateItemPreserveTimestamp {
    [self setBool:kDuplicateItemPreserveTimestamp value:duplicateItemPreserveTimestamp];
}

- (BOOL)duplicateItemReferencePassword {
    return [self getBool:kDuplicateItemReferencePassword];
}

- (void)setDuplicateItemReferencePassword:(BOOL)duplicateItemReferencePassword {
    [self setBool:kDuplicateItemReferencePassword value:duplicateItemReferencePassword];
}

- (BOOL)duplicateItemReferenceUsername {
    return [self getBool:kDuplicateItemReferenceUsername];
}

- (void)setDuplicateItemReferenceUsername:(BOOL)duplicateItemReferenceUsername {
    [self setBool:kDuplicateItemReferenceUsername value:duplicateItemReferenceUsername];
}

- (BOOL)exportItemsPreserveUUIDs {
    return [self getBool:kExportItemsPreserveUUIDs fallback:YES];
}

- (void)setExportItemsPreserveUUIDs:(BOOL)exportItemsPreserveUUIDs {
    [self setBool:kExportItemsPreserveUUIDs value:exportItemsPreserveUUIDs];
}

- (BOOL)exportItemsReplaceExisting {
    return [self getBool:kExportItemsReplaceExisting fallback:YES];
}

- (void)setExportItemsReplaceExisting:(BOOL)exportItemsReplaceExisting {
    [self setBool:kExportItemsReplaceExisting value:exportItemsReplaceExisting];
}









- (BOOL)useIsolatedDropbox {
    return [self getBool:kUseIsolatedDropbox];
}

- (void)setUseIsolatedDropbox:(BOOL)useIsolatedDropbox {
    [self setBool:kUseIsolatedDropbox value:useIsolatedDropbox];
}

- (BOOL)disableNetworkBasedFeatures {
    return [self getBool:kDisableNativeNetworkStorageOptions];
}

- (void)setDisableNetworkBasedFeatures:(BOOL)disableNativeNetworkStorageOptions {
    [self setBool:kDisableNativeNetworkStorageOptions value:disableNativeNetworkStorageOptions];
}

- (BOOL)databasesAreAlwaysReadOnly {
    return [self getBool:kDatabasesAreAlwaysReadOnly];
}

- (void)setDatabasesAreAlwaysReadOnly:(BOOL)databasesAreAlwaysReadOnly {
    [self setBool:kDatabasesAreAlwaysReadOnly value:databasesAreAlwaysReadOnly];
}

- (BOOL)disableFavIconFeature {
    return [self getBool:kDisableFavIconFeature];
}

- (void)setDisableFavIconFeature:(BOOL)disableFavIconFeature {
    [self setBool:kDisableFavIconFeature value:disableFavIconFeature];
}

- (BOOL)appHasBeenDowngradedToFreeEdition {
    return [self getBool:kAppHasBeenDowngradedToFreeEdition];
}

- (void)setAppHasBeenDowngradedToFreeEdition:(BOOL)appHasBeenDowngradedToFreeEdition {
    [self setBool:kAppHasBeenDowngradedToFreeEdition value:appHasBeenDowngradedToFreeEdition];
}

- (BOOL)hasPromptedThatAppHasBeenDowngradedToFreeEdition {
    return [self getBool:kHasPromptedThatAppHasBeenDowngradedToFreeEdition];
}

- (void)setHasPromptedThatAppHasBeenDowngradedToFreeEdition:(BOOL)hasPromptedThatAppHasBeenDowngradedToFreeEdition {
    [self setBool:kHasPromptedThatAppHasBeenDowngradedToFreeEdition value:hasPromptedThatAppHasBeenDowngradedToFreeEdition];
}

- (BOOL)hasPromptedThatFreeTrialWillEndSoon {
    return [self getBool:kHasPromptedThatFreeTrialWillEndSoon];
}

- (void)setHasPromptedThatFreeTrialWillEndSoon:(BOOL)hasPromptedThatFreeTrialWillEndSoon {
    [self setBool:kHasPromptedThatFreeTrialWillEndSoon value:hasPromptedThatFreeTrialWillEndSoon];
}

- (NSUInteger)freeTrialNudgeCount {
    return [self getInteger:kFreeTrialNudgeCount fallback:0];
}

- (void)setFreeTrialNudgeCount:(NSUInteger)freeTrialNudgeCount {
    [self setInteger:kFreeTrialNudgeCount value:freeTrialNudgeCount];
}

- (BOOL)promptToEnableAutoFill {
    return [self getBool:kPromptToEnableAutoFill fallback:YES];
}

- (void)setPromptToEnableAutoFill:(BOOL)promptToEnableAutoFill {
    return [self setBool:kPromptToEnableAutoFill value:promptToEnableAutoFill];
}

- (NSDate *)lastAskToEnableNotifications {
    return [self getDate:kLastAskToEnableNotifications];
}

- (void)setLastAskToEnableNotifications:(NSDate *)lastAskToEnableNotifications {
    [self setDate:kLastAskToEnableNotifications value:lastAskToEnableNotifications];
}

- (NSDate *)lastAskToEnableAutoFill {
    return [self getDate:kLastAskToEnableAutoFill];
}

- (void)setLastAskToEnableAutoFill:(NSDate *)lastAskToEnableAutoFill {
    [self setDate:kLastAskToEnableAutoFill value:lastAskToEnableAutoFill];
}

- (BOOL)hasShownFirstRunFinalWelcome {
    return [self getBool:kHasShownFirstRunFinalWelcome];
}

- (void)setHasShownFirstRunFinalWelcome:(BOOL)hasShownFirstRunFinalWelcome {
    return [self setBool:kHasShownFirstRunFinalWelcome value:hasShownFirstRunFinalWelcome];
}

- (BOOL)hasShownFirstRunWelcome {
    return [self getBool:kHasShownFirstRunWelcome];
}

- (void)setHasShownFirstRunWelcome:(BOOL)hasShownFirstRunWelcome {
    [self setBool:kHasShownFirstRunWelcome value:hasShownFirstRunWelcome];
}

- (BOOL)scheduledTipsCheckDone {
    return [self getBool:kScheduledTipsCheckDone];
}

- (void)setScheduledTipsCheckDone:(BOOL)scheduledTipsCheckDone {
    [self setBool:kScheduledTipsCheckDone value:scheduledTipsCheckDone];
}

- (NSData *)lastKnownGoodBiometricsDatabaseState {
    return [self.sharedAppGroupDefaults objectForKey:kLastKnownGoodDatabaseState];
}

- (void)setLastKnownGoodBiometricsDatabaseState:(NSData *)lastKnownGoodBiometricsDatabaseState {
    [self.sharedAppGroupDefaults setObject:lastKnownGoodBiometricsDatabaseState forKey:kLastKnownGoodDatabaseState];
    [self.sharedAppGroupDefaults synchronize];
}

- (NSData *)autoFillLastKnownGoodBiometricsDatabaseState {
    return [self.sharedAppGroupDefaults objectForKey:kAutoFillLastKnownGoodDatabaseState];
}

- (void)setAutoFillLastKnownGoodBiometricsDatabaseState:(NSData *)autoFillLastKnownGoodBiometricsDatabaseState {
    [self.sharedAppGroupDefaults setObject:autoFillLastKnownGoodBiometricsDatabaseState forKey:kAutoFillLastKnownGoodDatabaseState];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)checkPinYin {
    return self.pinYinSearchEnabled;
}

- (void)setCheckPinYin:(BOOL)checkPinYin {
    self.pinYinSearchEnabled = checkPinYin;
}

- (BOOL)pinYinSearchEnabled {
    return [self getBool:kPinYinSearchEnabled fallback:NO];
}

- (void)setPinYinSearchEnabled:(BOOL)pinYinSearchEnabled {
    [self setBool:kPinYinSearchEnabled value:pinYinSearchEnabled];
}

- (BOOL)addOtpAuthUrl {
    return [self getBool:kAddOtpAuthUrl fallback:YES];
}

- (void)setAddOtpAuthUrl:(BOOL)addOtpAuthUrl {
    [self setBool:kAddOtpAuthUrl value:addOtpAuthUrl];
}

- (BOOL)addLegacySupplementaryTotpCustomFields {
    return [self getBool:kAddLegacySupplementaryTotpCustomFields fallback:NO];
}

- (void)setAddLegacySupplementaryTotpCustomFields:(BOOL)addLegacySupplementaryTotpCustomFields {
    [self setBool:kAddLegacySupplementaryTotpCustomFields value:addLegacySupplementaryTotpCustomFields];
}

- (NSInteger)promptedForSale {
    return [self getInteger:kPromptedForSale fallback:-1];
}

- (void)setPromptedForSale:(NSInteger)promptedForSale {
    [self setInteger:kPromptedForSale value:promptedForSale];
}

- (PasswordStrengthConfig *)passwordStrengthConfig {
    NSData *encodedObject = [self.sharedAppGroupDefaults objectForKey:kPasswordStrengthConfig];

    if(encodedObject == nil) {
        return PasswordStrengthConfig.defaults;
    }

    PasswordStrengthConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setPasswordStrengthConfig:(PasswordStrengthConfig *)passwordStrengthConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordStrengthConfig];
    [self.sharedAppGroupDefaults setObject:encodedObject forKey:kPasswordStrengthConfig];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)migratedOfflineDetectedBehaviour {
    return [self getBool:kMigratedOfflineDetectedBehaviour];
}

- (void)setMigratedOfflineDetectedBehaviour:(BOOL)migratedOfflineDetectedBehaviour {
    [self setBool:kMigratedOfflineDetectedBehaviour value:migratedOfflineDetectedBehaviour];
}

- (AppPrivacyShieldMode)appPrivacyShieldMode {
    return [self getInteger:kAppPrivacyShieldMode fallback:kAppPrivacyShieldModeBlur];
}

- (void)setAppPrivacyShieldMode:(AppPrivacyShieldMode)appPrivacyShieldMode {
    [self setInteger:kAppPrivacyShieldMode value:appPrivacyShieldMode];
}

- (BOOL)coalesceAppLockAndQuickLaunchBiometrics {
    return [self getBool:kCoalesceAppLockAndQuickLaunchBiometrics fallback:YES];
}

- (void)setCoalesceAppLockAndQuickLaunchBiometrics:(BOOL)coalesceAppLockAndQuickLaunchBiometrics {
    [self setBool:kCoalesceAppLockAndQuickLaunchBiometrics value:coalesceAppLockAndQuickLaunchBiometrics];
}

- (BOOL)autoFillShowFavourites {
    return [self getBool:kAutoFillShowFavourites fallback:YES];
}

- (void)setAutoFillShowFavourites:(BOOL)autoFillShowPinned {
    [self setBool:kAutoFillShowFavourites value:autoFillShowPinned];
}



- (BOOL)migratedQuickLaunchToAutoFill {
    return [self getBool:kMigratedQuickLaunchToAutoFill];
}

- (void)setMigratedQuickLaunchToAutoFill:(BOOL)migratedQuickLaunchToAutoFill {
    [self setBool:kMigratedQuickLaunchToAutoFill value:migratedQuickLaunchToAutoFill];
}

- (NSString *)autoFillQuickLaunchUuid {
    return [self getString:kAutoFillQuickLaunchUuid];
}

- (void)setAutoFillQuickLaunchUuid:(NSString *)autoFillQuickLaunchUuid {
    [self setString:kAutoFillQuickLaunchUuid value:autoFillQuickLaunchUuid];
}

- (BOOL)autoFillAutoLaunchSingleDatabase {
    return [self getBool:kAutoFillAutoLaunchSingleDatabase fallback:YES];
}

- (void)setAutoFillAutoLaunchSingleDatabase:(BOOL)autoFillAutoLaunchSingleDatabase {
    [self setBool:kAutoFillAutoLaunchSingleDatabase value:autoFillAutoLaunchSingleDatabase];
}

- (BOOL)showAutoFillTotpCopiedMessage {
    return [self getBool:kShowAutoFillTotpCopiedMessage fallback:YES];
}

- (void)setShowAutoFillTotpCopiedMessage:(BOOL)showAutoFillTotpCopiedMessage {
    [self setBool:kShowAutoFillTotpCopiedMessage value:showAutoFillTotpCopiedMessage];
}

- (BOOL)autoFillWroteCleanly {
    return [self getBool:kAutoFillWroteCleanly fallback:YES]; 
}

- (void)setAutoFillWroteCleanly:(BOOL)autoFillWroteCleanly {
    [self setBool:kAutoFillWroteCleanly value:autoFillWroteCleanly];
}

- (BOOL)useFullUrlAsURLSuggestion {
    return [self getBool:kUseFullUrlAsURLSuggestion];
}

- (void)setUseFullUrlAsURLSuggestion:(BOOL)useFullUrlAsURLSuggestion {
    [self setBool:kUseFullUrlAsURLSuggestion value:useFullUrlAsURLSuggestion];
}

- (BOOL)autoProceedOnSingleMatch {
    return [self getBool:kAutoProceedOnSingleMatch];
}

- (void)setAutoProceedOnSingleMatch:(BOOL)autoProceedOnSingleMatch {
    return [self setBool:kAutoProceedOnSingleMatch value:autoProceedOnSingleMatch];
}

- (BOOL)storeAutoFillServiceIdentifiersInNotes {
    return [self getBool:kStoreAutoFillServiceIdentifiersInNotes];
}

- (void)setStoreAutoFillServiceIdentifiersInNotes:(BOOL)storeAutoFillServiceIdentifiersInNotes {
    [self setBool:kStoreAutoFillServiceIdentifiersInNotes value:storeAutoFillServiceIdentifiersInNotes];
}

- (BOOL)autoFillExitedCleanly {
    return [self getBool:kAutoFillExitedCleanly fallback:YES];
}

- (void)setAutoFillExitedCleanly:(BOOL)autoFillExitedCleanly {
    return [self setBool:kAutoFillExitedCleanly value:autoFillExitedCleanly];
}

- (BOOL)haveWarnedAboutAutoFillCrash {
    return [self getBool:kHaveWarnedAboutAutoFillCrash];
}

- (void)setHaveWarnedAboutAutoFillCrash:(BOOL)haveWarnedAboutAutoFillCrash {
    [self setBool:kHaveWarnedAboutAutoFillCrash value:haveWarnedAboutAutoFillCrash];
}

- (BOOL)dontNotifyToSwitchToMainAppForSync {
    return [self getBool:KDontNotifyToSwitchToMainAppForSync];
}

- (void)setDontNotifyToSwitchToMainAppForSync:(BOOL)dontNotifyToSwitchToMainAppForSync {
    [self setBool:KDontNotifyToSwitchToMainAppForSync value:dontNotifyToSwitchToMainAppForSync];
}



- (BOOL)userHasOptedInToThirdPartyStorageLibraries {
    return [self getBool:kUserHasOptedInToThirdPartyStorageLibraries];
}

- (void)setUserHasOptedInToThirdPartyStorageLibraries:(BOOL)userHasOptedInToThirdPartyStorageLibraries {
    [self setBool:kUserHasOptedInToThirdPartyStorageLibraries value:userHasOptedInToThirdPartyStorageLibraries];
}

- (BOOL)quickTypeTitleThenUsername {
    return [self getBool:kQuickTypeTitleThenUsername fallback:YES];
}

- (void)setQuickTypeTitleThenUsername:(BOOL)quickTypeTitleThenUsername {
    [self setBool:kQuickTypeTitleThenUsername value:quickTypeTitleThenUsername];
}

- (BOOL)showMetadataOnDetailsScreen {
    return [self getBool:kShowMetadataOnDetailsScreen fallback:YES];
}

- (void)setShowMetadataOnDetailsScreen:(BOOL)legacyShowMetadataOnDetailsScreen {
    [self setBool:kShowMetadataOnDetailsScreen value:legacyShowMetadataOnDetailsScreen];
}

- (BOOL)mainAppDidChangeDatabases {
    return [self getBool:kMainAppDidChangeDatabases];
}

- (void)setMainAppDidChangeDatabases:(BOOL)mainAppDidChangeDatabases {
    return [self setBool:kMainAppDidChangeDatabases value:mainAppDidChangeDatabases];
}

- (BOOL)autoFillDidChangeDatabases {
    return [self getBool:kAutoFillDidChangeDatabases];
    
}

- (void)setAutoFillDidChangeDatabases:(BOOL)autoFillDidChangeDatabases {
    [self setBool:kAutoFillDidChangeDatabases value:autoFillDidChangeDatabases];
}

- (BOOL)syncForcePushDoNotCheckForConflicts {
    return [self getBool:kSyncForcePushDoNotCheckForConflicts];
}

- (void)setSyncForcePushDoNotCheckForConflicts:(BOOL)syncForcePushDoNotCheckForConflicts {
    [self setBool:kSyncForcePushDoNotCheckForConflicts value:syncForcePushDoNotCheckForConflicts];
}

- (BOOL)syncPullEvenIfModifiedDateSame {
    return [self getBool:kSyncPullEvenIfModifiedDateSame];
}

- (void)setSyncPullEvenIfModifiedDateSame:(BOOL)syncPullEvenIfModifiedDateSame {
    [self setBool:kSyncPullEvenIfModifiedDateSame value:syncPullEvenIfModifiedDateSame];
}



- (NSData *)duressDummyData {
    return [self.sharedAppGroupDefaults objectForKey:@"dd-safe"];
}

- (void)setDuressDummyData:(NSData *)duressDummyData {
    NSUserDefaults* defaults = self.sharedAppGroupDefaults;
    [defaults setObject:duressDummyData forKey:@"dd-safe"];
    [defaults synchronize];
}



- (void)setPro:(BOOL)value {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    
    [userDefaults setBool:value forKey:kIsProKey];
    
    [userDefaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotification object:nil];
}

- (BOOL)isPro {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    return [userDefaults boolForKey:kIsProKey];
}



- (BOOL)colorizeUseColorBlindPalette {
    return [self getBool:kColorizeUseColorBlindPalette];
}

- (void)setColorizeUseColorBlindPalette:(BOOL)colorizeUseColorBlindPalette {
    [self setBool:kColorizeUseColorBlindPalette value:colorizeUseColorBlindPalette];
}

- (BOOL)clipboardHandoff {
    return [self getBool:kClipboardHandoff];
}

- (void)setClipboardHandoff:(BOOL)clipboardHandoff {
    return [self setBool:kClipboardHandoff value:clipboardHandoff];
}

- (PasswordGenerationConfig *)passwordGenerationConfig {
    NSUserDefaults *defaults = self.sharedAppGroupDefaults;
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return [PasswordGenerationConfig defaults];
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setPasswordGenerationConfig:(PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationConfig];
    NSUserDefaults *defaults = self.sharedAppGroupDefaults;
    [defaults setObject:encodedObject forKey:kPasswordGenerationConfig];
    [defaults synchronize];
}

- (BOOL)hideTips {
    return [self getBool:kHideTips];
}

- (void)setHideTips:(BOOL)hideTips {
    [self setBool:kHideTips value:hideTips];
}

- (BOOL)clearClipboardEnabled {
    return [self getBool:kClearClipboardEnabled fallback:YES];
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [self setBool:kClearClipboardEnabled value:clearClipboardEnabled];
}

- (NSInteger)clearClipboardAfterSeconds {
    NSInteger ret = [self getInteger:kClearClipboardAfterSeconds fallback:kDefaultClearClipboardTimeout];

    if(ret <= 0) { 
        [self setClearClipboardAfterSeconds:kDefaultClearClipboardTimeout];
        return kDefaultClearClipboardTimeout;
    }
    
    return ret;
}

-(void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    return [self setInteger:kClearClipboardAfterSeconds value:clearClipboardAfterSeconds];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [self.sharedAppGroupDefaults objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [self.sharedAppGroupDefaults setObject:encoded forKey:kAutoFillNewRecordSettings];
    [self.sharedAppGroupDefaults synchronize];
}

- (NSString *)quickLaunchUuid {
    return [self getString:kQuickLaunchUuid];
}

- (void)setQuickLaunchUuid:(NSString *)quickLaunchUuid {
    [self setString:kQuickLaunchUuid value:quickLaunchUuid];
}

- (BOOL)allowEmptyOrNoPasswordEntry {
    return [self getBool:kAllowEmptyOrNoPasswordEntry fallback:NO];
}

- (void)setAllowEmptyOrNoPasswordEntry:(BOOL)allowEmptyOrNoPasswordEntry {
    [self setBool:kAllowEmptyOrNoPasswordEntry value:allowEmptyOrNoPasswordEntry];
}

- (BOOL)hideKeyFileOnUnlock {
    return [self getBool:kHideKeyFileOnUnlock];
}

- (void)setHideKeyFileOnUnlock:(BOOL)hideKeyFileOnUnlock {
    [self setBool:kHideKeyFileOnUnlock value:hideKeyFileOnUnlock];
}

- (BOOL)showAllFilesInLocalKeyFiles {
    return [self getBool:kShowAllFilesInLocalKeyFiles];
}

- (void)setShowAllFilesInLocalKeyFiles:(BOOL)showAllFilesInLocalKeyFiles {
    [self setBool:kShowAllFilesInLocalKeyFiles value:showAllFilesInLocalKeyFiles];
}

- (BOOL)monitorInternetConnectivity {
    return [self getBool:kMonitorInternetConnectivity fallback:YES];
}

- (void)setMonitorInternetConnectivity:(BOOL)monitorInternetConnectivity {
    [self setBool:kMonitorInternetConnectivity value:monitorInternetConnectivity];
}

- (BOOL)instantPinUnlocking {
    return [self getBool:kInstantPinUnlocking fallback:YES];
}

- (void)setInstantPinUnlocking:(BOOL)instantPinUnlocking {
    [self setBool:kInstantPinUnlocking value:instantPinUnlocking];
}

- (FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [self.sharedAppGroupDefaults objectForKey:kFavIconDownloadOptions];

    if(encodedObject == nil) {
        return FavIconDownloadOptions.defaults;
    }

    FavIconDownloadOptions *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setFavIconDownloadOptions:(FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:favIconDownloadOptions];
    [self.sharedAppGroupDefaults setObject:encodedObject forKey:kFavIconDownloadOptions];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)showDatabasesSeparator {
    return [self getBool:kShowDatabasesSeparator];
}

- (void)setShowDatabasesSeparator:(BOOL)showDatabasesSeparator {
    [self setBool:kShowDatabasesSeparator value:showDatabasesSeparator];
}

- (BOOL)showDatabaseIcon {
    return [self getBool:kShowDatabaseIcon fallback:YES];
}

- (void)setShowDatabaseIcon:(BOOL)showDatabaseIcon {
    [self setBool:kShowDatabaseIcon value:showDatabaseIcon];
}

- (BOOL)showDatabaseStatusIcon {
    return [self getBool:kShowDatabaseStatusIcon fallback:YES];
}

- (void)setShowDatabaseStatusIcon:(BOOL)showDatabaseStatusIcon {
    [self setBool:kShowDatabaseStatusIcon value:showDatabaseStatusIcon];
}

- (DatabaseCellSubtitleField)databaseCellTopSubtitle {
    return[self getInteger:kDatabaseCellTopSubtitle fallback:kDatabaseCellSubtitleFieldFileSize];
}

- (void)setDatabaseCellTopSubtitle:(DatabaseCellSubtitleField)databaseCellTopSubtitle {
    [self setInteger:kDatabaseCellTopSubtitle value:databaseCellTopSubtitle];
}

- (DatabaseCellSubtitleField)databaseCellSubtitle1 {
    return[self getInteger:kDatabaseCellSubtitle1 fallback:kDatabaseCellSubtitleFieldStorage];
}

- (void)setDatabaseCellSubtitle1:(DatabaseCellSubtitleField)databaseCellSubtitle1 {
    [self setInteger:kDatabaseCellSubtitle1 value:databaseCellSubtitle1];
}

- (DatabaseCellSubtitleField)databaseCellSubtitle2 {
    return[self getInteger:kDatabaseCellSubtitle2 fallback:kDatabaseCellSubtitleFieldLastModifiedDate];
}

- (void)setDatabaseCellSubtitle2:(DatabaseCellSubtitleField)databaseCellSubtitle2 {
    [self setInteger:kDatabaseCellSubtitle2 value:databaseCellSubtitle2];
}



- (BOOL)haveAttemptedMigrationToFullFileProtection {
    return [self getBool:kHaveAttemptedMigrationToFullFileProtection];
}

- (void)setHaveAttemptedMigrationToFullFileProtection:(BOOL)haveAttemptedMigrationToFullFileProtection {
    [self setBool:kHaveAttemptedMigrationToFullFileProtection value:haveAttemptedMigrationToFullFileProtection];
}

- (BOOL)fullFileProtection {
    return [self getBool:kFullFileProtection fallback:YES]; 
}

- (void)setFullFileProtection:(BOOL)fullFileProtection {
    [self setBool:kFullFileProtection value:fullFileProtection];
}

- (BOOL)appLockAllowDevicePasscodeFallbackForBio {
    return [self getBool:kAppLockAllowDevicePasscodeFallbackForBio fallback:YES];
}

- (void)setAppLockAllowDevicePasscodeFallbackForBio:(BOOL)appLockAllowDevicePasscodeFallbackForBio {
    [self setBool:kAppLockAllowDevicePasscodeFallbackForBio value:appLockAllowDevicePasscodeFallbackForBio];
}

- (BOOL)allowThirdPartyKeyboards {
    return [self getBool:kAllowThirdPartyKeyboards];
}

- (void)setAllowThirdPartyKeyboards:(BOOL)allowThirdPartyKeyboards {
    [self setBool:kAllowThirdPartyKeyboards value:allowThirdPartyKeyboards];
}

- (BOOL)hideExportFromDatabaseContextMenu {
    return [self getBool:kHideExportFromDatabaseContextMenu];
}

- (void)setHideExportFromDatabaseContextMenu:(BOOL)hideExportFromDatabaseContextMenu {
    [self setBool:kHideExportFromDatabaseContextMenu value:hideExportFromDatabaseContextMenu];
}

- (BOOL)haveAskedAboutBackupSettings {
    return [self getBool:kHaveAskedAboutBackupSettings fallback:NO];
}

- (void)setHaveAskedAboutBackupSettings:(BOOL)haveAskedAboutBackupSettings {
    [self setBool:kHaveAskedAboutBackupSettings value:haveAskedAboutBackupSettings];
}

- (BOOL)backupFiles {
    return [self getBool:kBackupFiles fallback:YES];
}

- (void)setBackupFiles:(BOOL)backupFiles {
    [self setBool:kBackupFiles value:backupFiles];
}

- (BOOL)backupIncludeImportedKeyFiles {
    return [self getBool:kBackupIncludeImportedKeyFiles fallback:NO];
}

- (void)setBackupIncludeImportedKeyFiles:(BOOL)backupIncludeImportedKeyFiles {
    return [self setBool:kBackupIncludeImportedKeyFiles value:backupIncludeImportedKeyFiles];
}

- (NSDate *)lastFreeTrialNudge {
    NSDate* date = [AppPreferences.sharedInstance.sharedAppGroupDefaults objectForKey:kLastFreeTrialNudge];
    return date ? date : NSDate.date; 
}

- (void)setLastFreeTrialNudge:(NSDate *)lastFreeTrialNudge {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    [userDefaults setObject:lastFreeTrialNudge forKey:kLastFreeTrialNudge];
    [userDefaults synchronize];
}

- (NSDate*)installDate {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:installDate forKey:kInstallDate];
    [userDefaults synchronize];
}

- (void)clearInstallDate {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults removeObjectForKey:kInstallDate];
    [userDefaults synchronize];
}

- (NSInteger)daysInstalled {
    NSDate* installDate = self.installDate;

    if(!installDate) {
        return 0;
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                fromDate:installDate
                                                  toDate:[NSDate date]
                                                 options:0];

    NSInteger daysInstalled = [components day];
    
    return daysInstalled;
}

- (NSUInteger)launchCount {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    NSInteger launchCount = [userDefaults integerForKey:kLaunchCountKey];
    
    return launchCount;
}

- (void)resetLaunchCount {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults removeObjectForKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (void)incrementLaunchCount {
    NSUInteger launchCount = self.launchCount;
    
    launchCount++;
    

    
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    [userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}



- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d[%ld]]", AppPreferences.sharedInstance.isPro, (long)self.launchCount];
}

- (BOOL)showKeePassCreateSafeOptions {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults boolForKey:kShowKeePassCreateSafeOptions];
}

- (void)setShowKeePassCreateSafeOptions:(BOOL)showKeePassCreateSafeOptions {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setBool:showKeePassCreateSafeOptions forKey:kShowKeePassCreateSafeOptions];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    
    
    return [userDefaults objectForKey:kLastEntitlementCheckAttempt];
}

- (void)setLastEntitlementCheckAttempt:(NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:lastEntitlementCheckAttempt forKey:kLastEntitlementCheckAttempt];
    
    [userDefaults synchronize];
}

- (NSUInteger)numberOfEntitlementCheckFails {
    NSInteger ret =  [AppPreferences.sharedInstance.sharedAppGroupDefaults integerForKey:kNumberOfEntitlementCheckFails];
    return ret;
}

- (void)setNumberOfEntitlementCheckFails:(NSUInteger)numberOfEntitlementCheckFails {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setInteger:numberOfEntitlementCheckFails forKey:kNumberOfEntitlementCheckFails];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}



- (AppLockMode)appLockMode {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults integerForKey:kAppLockMode];
}

- (void)setAppLockMode:(AppLockMode)appLockMode {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setInteger:appLockMode forKey:kAppLockMode];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSString *)appLockPin {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults objectForKey:kAppLockPin];
}

-(void)setAppLockPin:(NSString *)appLockPin {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setObject:appLockPin forKey:kAppLockPin];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSInteger)appLockDelay {
    NSInteger ret =  [AppPreferences.sharedInstance.sharedAppGroupDefaults integerForKey:kAppLockDelay];
    return ret;
}

-(void)setAppLockDelay:(NSInteger)appLockDelay {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setInteger:appLockDelay forKey:kAppLockDelay];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSInteger)deleteDataAfterFailedUnlockCount {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults integerForKey:kDeleteDataAfterFailedUnlockCount];
}

- (void)setDeleteDataAfterFailedUnlockCount:(NSInteger)deleteDataAfterFailedUnlockCount {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setInteger:deleteDataAfterFailedUnlockCount forKey:kDeleteDataAfterFailedUnlockCount];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSUInteger)failedUnlockAttempts {
    return [AppPreferences.sharedInstance.sharedAppGroupDefaults integerForKey:kFailedUnlockAttempts];
}

- (void)setFailedUnlockAttempts:(NSUInteger)failedUnlockAttempts {
    [AppPreferences.sharedInstance.sharedAppGroupDefaults setInteger:failedUnlockAttempts forKey:kFailedUnlockAttempts];
    [AppPreferences.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (BOOL)appLockAppliesToPreferences {
    return [self getBool:kAppLockAppliesToPreferences];
}

- (void)setAppLockAppliesToPreferences:(BOOL)appLockAppliesToPreferences {
    [self setBool:kAppLockAppliesToPreferences value:appLockAppliesToPreferences];
}



+ (NSString*)getAppGroupFromProvisioningProfile {
    NSString* profilePath = [NSBundle.mainBundle pathForResource:@"embedded" ofType:@"mobileprovision"];
    
    if (profilePath == nil) {
        slog(@"INFO: getAppGroupFromProvisioningProfile - Could not find embedded.mobileprovision file");
        return nil;
    }
    
    NSData* plistData = [NSData dataWithContentsOfFile:profilePath];
    if(!plistData) {
        slog(@"Error: getAppGroupFromProvisioningProfile - dataWithContentsOfFile nil");
        return nil;
    }
    
    NSString* plistDataString = [NSString stringWithFormat:@"%@", plistData];
    if(plistDataString == nil) {
        slog(@"Error: getAppGroupFromProvisioningProfile - plistData - stringWithFormat nil");
        return nil;
    }
    
    NSString* plistString = [self extractPlist:plistDataString];
    if(!plistString) {
        slog(@"Error: getAppGroupFromProvisioningProfile - extractPlist nil");
        return nil;
    }
    
    NSError* error;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"<key>com.apple.security.application-groups</key>.*?<array>.*?<string>(.*?)</string>.*?</array>" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                             error:&error];
    
    if(error || regex == nil) {
        slog(@"Error: getAppGroupFromProvisioningProfile - regularExpressionWithPattern %@", error);
        return nil;
    }
    
    NSTextCheckingResult* res = [regex firstMatchInString:plistString options:kNilOptions range:NSMakeRange(0, plistString.length)];
    
    if(res && [res numberOfRanges] > 1) {
        NSRange rng = [res rangeAtIndex:1];
        NSString* appGroup = [plistString substringWithRange:rng];
        return appGroup;
    }
    else {
        slog(@"INFO: getAppGroupFromProvisioningProfile - App Group Not Found - [%@]", res);
        return nil;
    }
}

+ (NSString*)extractPlist:(NSString*)str {
    
    if(!str || str.length < 10) { 
        return nil;
    }
    
    str = [str substringWithRange:NSMakeRange(1, str.length-2)];
    str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    
    
    NSString* profileText = [self hexStringtoAscii:str];
    return profileText;
}

+ (NSString*)hexStringtoAscii:(NSString*)hexString {
    NSString* pattern = @"(0x)?([0-9a-f]{2})";
    NSError* error;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    
    if(error) {
        slog(@"hexStringToAscii Error: %@", error);
        return nil;
    }
    
    NSArray<NSTextCheckingResult*>* matches = [regex matchesInString:hexString options:kNilOptions range:NSMakeRange(0, hexString.length)];
    if(!matches) {
        slog(@"hexStringToAscii Error: Matches nil");
        return nil;
    }
    
    NSArray<NSNumber*> *characters = [matches map:^id _Nonnull(NSTextCheckingResult * _Nonnull obj, NSUInteger idx) {
        if(obj.numberOfRanges > 1) {
            NSRange range = [obj rangeAtIndex:2];
            NSString *sub = [hexString substringWithRange:range];
            
            
            NSScanner *scanner = [NSScanner scannerWithString:sub];
            uint32_t u32;
            [scanner scanHexInt:&u32];
            return @(u32);
        }
        else {
            slog(@"Do not know how to decode.");
            return @(32); 
        }
    }];
    
    NSMutableString* foo = [NSMutableString string];
    for (NSNumber* ch in characters) {
        [foo appendFormat:@"%c", ch.unsignedCharValue];
    }
    
    return foo.copy;
}



- (NSString*)getString:(NSString*)key {
    return [self getString:key fallback:nil];
}

- (NSString*)getString:(NSString*)key fallback:(NSString*)fallback {
    NSString* obj = [self.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [self.sharedAppGroupDefaults setObject:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [self.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [self.sharedAppGroupDefaults setBool:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

- (NSInteger)getInteger:(NSString*)key {
    return [self.sharedAppGroupDefaults integerForKey:key];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [self.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [self.sharedAppGroupDefaults setInteger:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

- (NSDate*)getDate:(NSString*)key {
    return [self.sharedAppGroupDefaults objectForKey:key];
}

- (void)setDate:(NSString*)key value:(NSDate*)value {
    [self.sharedAppGroupDefaults setObject:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

@end
