//
//  Settings.m
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"
#import "Utils.h"
#import "Constants.h"
#import "Model.h"

#ifndef IS_APP_EXTENSION

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
#import "GoogleDriveManager.h"
#endif

#endif

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kTitleColumn = @"TitleColumn";
NSString* const kUsernameColumn = @"UsernameColumn";
NSString* const kPasswordColumn = @"PasswordColumn";
NSString* const kTOTPColumn = @"TOTPColumn";
NSString* const kURLColumn = @"URLColumn";
NSString* const kEmailColumn = @"EmailColumn";
NSString* const kNotesColumn = @"NotesColumn";
NSString* const kExpiresColumn = @"ExpiresColumn";
NSString* const kAttachmentsColumn = @"AttachmentsColumn";
NSString* const kCustomFieldsColumn = @"CustomFieldsColumn";



static const NSInteger kDefaultClearClipboardTimeout = 60;

static NSString* const kPro = @"fullVersion";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kAutoLockTimeout = @"autoLockTimeout";
static NSString* const kAutoLockIfInBackgroundTimeoutSeconds = @"autoLockIfInBackgroundTimeoutSeconds";

static NSString* const kAlwaysShowPassword = @"alwaysShowPassword";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kAutoSave = @"autoSave";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kFloatOnTop = @"floatOnTop";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kTrayPasswordGenerationConfig = @"trayPasswordGenerationConfig";
static NSString* const kAutoPromptForTouchIdOnActivate = @"autoPromptForTouchIdOnActivate";
static NSString* const kShowSystemTrayIcon = @"showSystemTrayIcon";
static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kShowPasswordImmediatelyInOutline = @"showPasswordImmediatelyInOutline";
static NSString* const kHideKeyFileNameOnLockScreen = @"hideKeyFileNameOnLockScreen";
static NSString* const kDoNotRememberKeyFile = @"doNotRememberKeyFile";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kColorizePasswords = @"colorizePasswords";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";
static NSString* const kClipboardHandoff = @"clipboardHandoff";
static NSString* const kShowDatabasesManagerOnCloseAllWindows = @"showDatabasesManagerOnCloseAllWindows";
static NSString* const kShowAutoFillTotpCopiedMessage = @"showAutoFillTotpCopiedMessage";
static NSString* const kAutoLaunchSingleDatabase = @"autoLaunchSingleDatabase";
static NSString* const kHideDockIconOnAllMinimized = @"hideDockIconOnAllMinimized";
static NSString* const kCloseManagerOnLaunch = @"closeManagerOnLaunch";
static NSString* const kMakeLocalRollingBackups = @"makeLocalRollingBackups";
static NSString* const kMiniaturizeOnCopy = @"miniaturizeOnCopy";
static NSString* const kQuickRevealWithOptionKey = @"quickRevealWithOptionKey";
static NSString* const kMarkdownNotes = @"markdownNotes";
static NSString* const kShowPasswordGenInTray = @"showPasswordGenInTray";
static NSString* const kAddOtpAuthUrl = @"addOtpAuthUrl";
static NSString* const kAddLegacySupplementaryTotpCustomFields = @"addLegacySupplementaryTotpCustomFields";
static NSString* const kQuitOnAllWindowsClosed = @"quitOnAllWindowsClosed";
static NSString* const kShowCopyFieldButton = @"showCopyFieldButton";
static NSString* const kLockEvenIfEditing = @"lockEvenIfEditing";
static NSString* const kScreenCaptureBlocked = @"screenCaptureBlocked";



static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails-reset-all-27-dec-2022";
static NSString* const kAppHasBeenDowngradedToFreeEdition = @"appHasBeenDowngradedToFreeEdition";
static NSString* const kHasPromptedThatAppHasBeenDowngradedToFreeEdition = @"hasPromptedThatAppHasBeenDowngradedToFreeEdition";
static NSString* const kHasPromptedThatFreeTrialWillEndSoon = @"hasPromptedThatFreeTrialWillEndSoon";

static NSString* const kHasShownFirstRunWelcome = @"hasShownFirstRunWelcome";
static NSString* const kFreeTrialNudgeCount = @"freeTrialNudgeCount";
static NSString* const kLastFreeTrialNudge = @"lastFreeTrialNudge";
static NSString* const kInstallDate = @"installDate";
static NSString* const kLaunchCountKey = @"launchCountKey";
static NSString* const kUseIsolatedDropbox = @"useIsolatedDropbox";
static NSString* const kUseParentGroupIconOnCreate = @"useParentGroupIconOnCreate";
static NSString* const kStripUnusedIconsOnSave = @"stripUnusedIconsOnSave";
static NSString* const kRunBrowserAutoFillProxyServer = @"runBrowserAutoFillProxyServer-Prod-22-Oct-2022";
static NSString* const kQuitTerminatesProcessEvenInSystemTrayMode = @"quitTerminatesProcessEvenInSystemTrayMode";
static NSString* const kLockDatabaseOnWindowClose = @"lockDatabaseOnWindowClose";
static NSString* const kLockDatabasesOnScreenLock = @"lockDatabasesOnScreenLock";
static NSString* const KShowDatabasesManagerOnAppLaunch = @"showDatabasesManagerOnAppLaunch";
static NSString* const kHasAskedAboutDatabaseOpenInBackground = @"hasAskedAboutDatabaseOpenInBackground";
static NSString* const kConcealClipboardFromMonitors = @"concealClipboardFromMonitors-DefaultON-27-Dec-2022";
static NSString* const kAutoCommitScannedTotp = @"autoCommitScannedTotp";
static NSString* const kHideOnCopy = @"hideOnCopy";
static NSString* const kHasPromptedForThirdPartyAutoFill = @"hasPromptedForThirdPartyAutoFill";
static NSString* const kRunSshAgent = @"runSshAgent";

static NSString* const kBusinessOrganisationName = @"businessOrganisationName";
static NSString* const kLastQuickTypeMultiDbRegularClear = @"lastQuickTypeMultiDbRegularClear";
static NSString* const kSshAgentApprovalDefaultExpiryMinutes = @"sshAgentApprovalDefaultExpiryMinutes";



static NSString* const kDatabasesAreAlwaysReadOnly = @"databasesAreAlwaysReadOnly";
static NSString* const kDisableExport = @"disableExport";
static NSString* const kDisablePrinting = @"disablePrinting";
static NSString* const kSshAgentRequestDatabaseUnlockAllowed = @"sshAgentRequestDatabaseUnlockAllowed";
static NSString* const kSshAgentPreventRapidRepeatedUnlockRequests = @"sshAgentPreventRapidRepeatedUnlockRequests";
static NSString* const kAutoFillWroteCleanly = @"autoFillWroteCleanly";
static NSString* const kAtomicSftpWrite = @"atomicSftpWrite";
static NSString* const kStripUnusedHistoricalIcons = @"stripUnusedHistoricalIcons";

static NSString* const kWiFiSyncOn = @"wiFiSyncOn";
static NSString* const kWiFiSyncServiceName = @"wiFiSyncServiceName";
static NSString* const kWiFiSyncPasscodeSSKey = @"wiFiSyncPasscodeSSKey";
static NSString* const kWiFiSyncPasscodeSSKeyHasBeenInitialized = @"wiFiSyncPasscodeSSKeyHasBeenInitialized";

static NSString* const kDisableWiFiSyncClientMode = @"disableWiFiSyncClientMode";
static NSString* const kCloudKitZoneCreated = @"cloudKitZoneCreated";
static NSString* const kChangeNotificationsSubscriptionCreated = @"changeNotificationsSubscriptionCreated";
static NSString* const kDisableNativeNetworkStorageOptions = @"disableNativeNetworkStorageOptions";
static NSString* const kHasWarnedAboutCloudKitUnavailability = @"hasWarnedAboutCloudKitUnavailability";
static NSString* const kPasswordGeneratorFloatOnTop = @"passwordGeneratorFloatOnTop";
static NSString* const kLargeTextViewFloatOnTop = @"largeTextViewFloatOnTop";
static NSString* const kLastWiFiSyncPasscodeError = @"lastWiFiSyncPasscodeError";
static NSString* const kUseUSGovAuthority = @"useUSGovAuthority";
static NSString* const kAppAppearance = @"appAppearance2";
static NSString* const kDisableCopyTo = @"disableCopyTo";
static NSString* const kDisableMakeVisibleInFiles = @"disableMakeVisibleInFiles";
static NSString* const kSystemMenuClickAction = @"systemMenuClickAction";
static NSString* const kLastCloudKitRefresh = @"lastCloudKitRefresh";
static NSString* const kHardwareKeyCachingBeta = @"hardwareKeyCachingBeta2"; 

static NSString* const kLastKnownGoodDatabaseState = @"lastKnownGoodDatabaseState";
static NSString* const kAutoFillLastKnownGoodDatabaseState = @"autoFillLastKnownGoodDatabaseState";

static NSString* const kDuplicateItemPreserveTimestamp = @"duplicateItemPreserveTimestamp";
static NSString* const kDuplicateItemReferencePassword = @"duplicateItemReferencePassword";
static NSString* const kDuplicateItemReferenceUsername = @"duplicateItemReferenceUsername";
static NSString* const kDuplicateItemEditAfterwards = @"duplicateItemEditAfterwards";



static NSString* const kDefaultAppGroupName = @"group.strongbox.mac.mcguill";



@interface Settings ()

@property BOOL wiFiSyncPasscodeSSKeyHasBeenInitialized;

@end

@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    return sharedInstance;
}

- (NSString *)appGroupName {
    return kDefaultAppGroupName;
}

- (NSUserDefaults *)sharedAppGroupDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultAppGroupName];
    
    if(defaults == nil) {
        slog(@"🔴 ERROR: Could not get NSUserDefaults for Suite Name: [%@]", kDefaultAppGroupName);
    }
    
    return defaults;
}

- (NSUserDefaults*)userDefaults {
    return self.sharedAppGroupDefaults;
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [self.userDefaults objectForKey:key];
    
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [self.userDefaults setBool:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSInteger)getInteger:(NSString*)key {
    return [self.userDefaults integerForKey:key];
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [self.userDefaults setInteger:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSString*)getString:(NSString*)key fallback:(NSString*)fallback {
    NSString* obj = [self.userDefaults objectForKey:key];
    
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [self.userDefaults setObject:value forKey:key];
    [self.userDefaults synchronize];
}

#ifndef IS_APP_EXTENSION

- (void)clearAllDefaults {
    for (NSString* key in self.sharedAppGroupDefaults.dictionaryRepresentation.allKeys) {
        slog(@"✅ Deleting from Shared App Group: [%@]", key);
        [self.sharedAppGroupDefaults removeObjectForKey:key];
    }
    
    [self.sharedAppGroupDefaults synchronize];
    
    for ( NSString* key in NSUserDefaults.standardUserDefaults.dictionaryRepresentation.allKeys ) {
        slog(@"✅ Deleting from Standard: [%@]", key);
        [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
        [self.sharedAppGroupDefaults removeObjectForKey:key];
    }
    
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)factoryReset {
    [self clearAllDefaults];
    
    
    
    NSURL* fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:@"sftp-connections.json"];
    
    NSError *error;
    [NSFileManager.defaultManager removeItemAtURL:fileUrl error:&error];
    if ( error ) {
        slog(@"🔴 Error Deleting SFTP Connections File [%@]", error);
    }
    
    fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:@"webdav-connections.json"];
    [NSFileManager.defaultManager removeItemAtURL:fileUrl error:&error];
    if ( error ) {
        slog(@"🔴 Error Deleting WebDAV Connections File [%@]", error);
    }

    
    
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    [GoogleDriveManager.sharedInstance signout];
    [OneDriveStorageProvider.sharedInstance signOutAll];
    [DropboxV2StorageProvider.sharedInstance signOut];
#endif
    
    
    
    [StrongboxFilesManager.sharedInstance deleteAllNukeFromOrbit];
    
    
    
    [NativeMessagingManifestInstallHelper removeNativeMessagingHostsFiles];
    
    
    
    [SecretStore.sharedInstance deleteSecureItem:kWiFiSyncPasscodeSSKey];

    
    
    [self clearAllDefaults];
}

#endif



- (BOOL)duplicateItemEditAfterwards {
    return [self getBool:kDuplicateItemEditAfterwards];
}

- (void)setDuplicateItemEditAfterwards:(BOOL)duplicateItemEditAfterwards {
    [self setBool:kDuplicateItemEditAfterwards value:duplicateItemEditAfterwards];
}

- (BOOL)duplicateItemPreserveTimestamp {
    return [self getBool:kDuplicateItemPreserveTimestamp fallback:YES];
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



- (BOOL)hardwareKeyCachingBeta {
    return [self getBool:kHardwareKeyCachingBeta fallback:YES];
}

- (void)setHardwareKeyCachingBeta:(BOOL)hardwareKeyCachingBeta {
    [self setBool:kHardwareKeyCachingBeta value:hardwareKeyCachingBeta];
}



- (NSDate *)lastCloudKitRefresh {
    NSUserDefaults *userDefaults = Settings.sharedInstance.sharedAppGroupDefaults;
    return [userDefaults objectForKey:kLastCloudKitRefresh];

}

- (void)setLastCloudKitRefresh:(NSDate *)lastCloudKitRefresh {
    NSUserDefaults *userDefaults = Settings.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:lastCloudKitRefresh forKey:kLastCloudKitRefresh];
    
    [userDefaults synchronize];
}

- (SystemMenuClickAction)systemMenuClickAction {
    return [self getInteger:kSystemMenuClickAction];
}

- (void)setSystemMenuClickAction:(SystemMenuClickAction)systemMenuClickAction {
    [self setInteger:kSystemMenuClickAction value:systemMenuClickAction];
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

- (BOOL)largeTextViewFloatOnTop {
    return [self getBool:kLargeTextViewFloatOnTop];
}

- (void)setLargeTextViewFloatOnTop:(BOOL)largeTextViewFloatOnTop {
    [self setBool:kLargeTextViewFloatOnTop value:largeTextViewFloatOnTop];
}

- (BOOL)passwordGeneratorFloatOnTop {
    return [self getBool:kPasswordGeneratorFloatOnTop];
}

- (void)setPasswordGeneratorFloatOnTop:(BOOL)passwordGeneratorFloatOnTop {
    [self setBool:kPasswordGeneratorFloatOnTop value:passwordGeneratorFloatOnTop];
}

- (BOOL)hasWarnedAboutCloudKitUnavailability {
    return [self getBool:kHasWarnedAboutCloudKitUnavailability];
}

- (void)setHasWarnedAboutCloudKitUnavailability:(BOOL)hasWarnedAboutCloudKitUnavailability {
    [self setBool:kHasWarnedAboutCloudKitUnavailability value:hasWarnedAboutCloudKitUnavailability];
}

- (BOOL)disableNetworkBasedFeatures {
    return [self getBool:kDisableNativeNetworkStorageOptions];
}

- (void)setDisableNetworkBasedFeatures:(BOOL)disableNativeNetworkStorageOptions {
    [self setBool:kDisableNativeNetworkStorageOptions value:disableNativeNetworkStorageOptions];
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
    return [self getBool:kDisableWiFiSyncClientMode];
}

- (void)setDisableWiFiSyncClientMode:(BOOL)disableWiFiSyncClientMode {
    [self setBool:kDisableWiFiSyncClientMode value:disableWiFiSyncClientMode];
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
        if ( thePasscode != nil ) {
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
    NSString* current = [self getString:kWiFiSyncServiceName fallback:nil];
    
    if ( !current ) {
        current = [NSString stringWithFormat:@"%@ (%@)", NSHost.currentHost.localizedName, NSUserName()];
        [self setWiFiSyncServiceName:current];
    }
    
    return current;
}

- (void)setWiFiSyncServiceName:(NSString *)wiFiSyncServiceName {
    [self setString:kWiFiSyncServiceName value:wiFiSyncServiceName];
}

- (BOOL)stripUnusedHistoricalIcons {
    return [self getBool:kStripUnusedHistoricalIcons fallback:Settings.sharedInstance.stripUnusedIconsOnSave];
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
- (BOOL)autoFillWroteCleanly {
    return [self getBool:kAutoFillWroteCleanly fallback:YES]; 
}

- (void)setAutoFillWroteCleanly:(BOOL)autoFillWroteCleanly {
    [self setBool:kAutoFillWroteCleanly value:autoFillWroteCleanly];
}

- (BOOL)sshAgentPreventRapidRepeatedUnlockRequests {
    return [self getBool:kSshAgentPreventRapidRepeatedUnlockRequests fallback:YES];
}

- (void)setSshAgentPreventRapidRepeatedUnlockRequests:(BOOL)sshAgentPreventRapidRepeatedUnlockRequests {
    [self setBool:kSshAgentPreventRapidRepeatedUnlockRequests value:sshAgentPreventRapidRepeatedUnlockRequests];
}

- (BOOL)sshAgentRequestDatabaseUnlockAllowed {
    return [self getBool:kSshAgentRequestDatabaseUnlockAllowed fallback:YES];
}

- (void)setSshAgentRequestDatabaseUnlockAllowed:(BOOL)sshAgentRequestDatabaseUnlockAllowed {
    [self setBool:kSshAgentRequestDatabaseUnlockAllowed value:sshAgentRequestDatabaseUnlockAllowed];
}

- (BOOL)databasesAreAlwaysReadOnly {
    return [self getBool:kDatabasesAreAlwaysReadOnly];
}

- (void)setDatabasesAreAlwaysReadOnly:(BOOL)databasesAreAlwaysReadOnly {
    [self setBool:kDatabasesAreAlwaysReadOnly value:databasesAreAlwaysReadOnly];
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

- (NSInteger)sshAgentApprovalDefaultExpiryMinutes {
    NSInteger ret = [self.sharedAppGroupDefaults integerForKey:kSshAgentApprovalDefaultExpiryMinutes];
    
    return ret == 0 ? -1 : ret;
}

- (void)setSshAgentApprovalDefaultExpiryMinutes:(NSInteger)sshAgentApprovalDefaultExpiryMinutes {
    [self.sharedAppGroupDefaults setInteger:sshAgentApprovalDefaultExpiryMinutes forKey:kSshAgentApprovalDefaultExpiryMinutes];
    [self.sharedAppGroupDefaults synchronize];

}

- (NSDate *)lastQuickTypeMultiDbRegularClear {
    NSUserDefaults *userDefaults = Settings.sharedInstance.sharedAppGroupDefaults;
    return [userDefaults objectForKey:kLastQuickTypeMultiDbRegularClear];
}

- (void)setLastQuickTypeMultiDbRegularClear:(NSDate *)lastQuickTypeMultiDbRegularClear {
    NSUserDefaults *userDefaults = Settings.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:lastQuickTypeMultiDbRegularClear forKey:kLastQuickTypeMultiDbRegularClear];
    
    [userDefaults synchronize];
}

- (NSString *)businessOrganisationName {
    return [Settings.sharedInstance.sharedAppGroupDefaults objectForKey:kBusinessOrganisationName];
}

- (void)setBusinessOrganisationName:(NSString *)businessOrganisationName {
    [Settings.sharedInstance.sharedAppGroupDefaults setObject:businessOrganisationName forKey:kBusinessOrganisationName];
    [Settings.sharedInstance.sharedAppGroupDefaults synchronize];
}









- (BOOL)runSshAgent {
    return [self getBool:kRunSshAgent];
}

- (void)setRunSshAgent:(BOOL)runSshAgent {
    [self setBool:kRunSshAgent value:runSshAgent];
}

- (BOOL)hasPromptedForThirdPartyAutoFill {
    return [self getBool:kHasPromptedForThirdPartyAutoFill fallback:NO];
}

- (void)setHasPromptedForThirdPartyAutoFill:(BOOL)hasPromptedForThirdPartyAutoFill {
    [self setBool:kHasPromptedForThirdPartyAutoFill value:hasPromptedForThirdPartyAutoFill];
}

- (BOOL)hideOnCopy {
    return [self getBool:kHideOnCopy fallback:NO];
}

- (void)setHideOnCopy:(BOOL)hideOnCopy {
    [self setBool:kHideOnCopy value:hideOnCopy];
}

- (BOOL)autoCommitScannedTotp {
    return [self getBool:kAutoCommitScannedTotp fallback:YES];
}

- (void)setAutoCommitScannedTotp:(BOOL)autoCommitScannedTotp {
    [self setBool:kAutoCommitScannedTotp value:autoCommitScannedTotp];
}

- (BOOL)concealClipboardFromMonitors {
    return [self getBool:kConcealClipboardFromMonitors fallback:YES];
}

- (void)setConcealClipboardFromMonitors:(BOOL)concealClipboardFromMonitors {
    [self setBool:kConcealClipboardFromMonitors value:concealClipboardFromMonitors];
}

- (BOOL)hasAskedAboutDatabaseOpenInBackground {
    return [self getBool:kHasAskedAboutDatabaseOpenInBackground];
}

- (void)setHasAskedAboutDatabaseOpenInBackground:(BOOL)hasAskedAboutDatabaseOpenInBackground {
    [self setBool:kHasAskedAboutDatabaseOpenInBackground value:hasAskedAboutDatabaseOpenInBackground];
}

- (BOOL)showDatabasesManagerOnAppLaunch {
    return [self getBool:KShowDatabasesManagerOnAppLaunch fallback:YES];
}

- (void)setShowDatabasesManagerOnAppLaunch:(BOOL)showDatabasesManagerOnAppLaunch {
    [self setBool:KShowDatabasesManagerOnAppLaunch value:showDatabasesManagerOnAppLaunch];
}

- (BOOL)lockDatabasesOnScreenLock {
    return [self getBool:kLockDatabasesOnScreenLock fallback:YES];
}

- (void)setLockDatabasesOnScreenLock:(BOOL)lockDatabasesOnScreenLock {
    [self setBool:kLockDatabasesOnScreenLock value:lockDatabasesOnScreenLock];
}

- (BOOL)lockDatabaseOnWindowClose {
    return [self getBool:kLockDatabaseOnWindowClose fallback:YES];
}

- (void)setLockDatabaseOnWindowClose:(BOOL)lockDatabaseOnWindowClose {
    [self setBool:kLockDatabaseOnWindowClose value:lockDatabaseOnWindowClose];
}

- (BOOL)quitTerminatesProcessEvenInSystemTrayMode {
    return [self getBool:kQuitTerminatesProcessEvenInSystemTrayMode fallback:NO];
}

- (void)setQuitTerminatesProcessEvenInSystemTrayMode:(BOOL)quitTerminatesProcessEvenInSystemTrayMode {
    [self setBool:kQuitTerminatesProcessEvenInSystemTrayMode value:quitTerminatesProcessEvenInSystemTrayMode];
}

- (BOOL)runBrowserAutoFillProxyServer {
    return [self getBool:kRunBrowserAutoFillProxyServer fallback:YES];
}

- (void)setRunBrowserAutoFillProxyServer:(BOOL)runBrowserAutoFillProxyServer {
    [self setBool:kRunBrowserAutoFillProxyServer value:runBrowserAutoFillProxyServer];
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

- (BOOL)useIsolatedDropbox {
    return [self getBool:kUseIsolatedDropbox];
}

- (void)setUseIsolatedDropbox:(BOOL)useIsolatedDropbox {
    [self setBool:kUseIsolatedDropbox value:useIsolatedDropbox];
}



- (NSDate *)installDate {
    return [self.userDefaults objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    [self.userDefaults setObject:installDate forKey:kInstallDate];
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
    return [self.userDefaults integerForKey:kLaunchCountKey];
}

- (void)incrementLaunchCount {
    NSUInteger launchCount = self.launchCount;
    
    launchCount++;
    

    
    [self.userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    [self.userDefaults synchronize];
}



- (NSUInteger)freeTrialOrUpgradeNudgeCount {
    return [self.sharedAppGroupDefaults integerForKey:kFreeTrialNudgeCount];
}

- (void)setFreeTrialOrUpgradeNudgeCount:(NSUInteger)freeTrialOrUpgradeNudgeCount {
    [self.sharedAppGroupDefaults setInteger:freeTrialOrUpgradeNudgeCount forKey:kFreeTrialNudgeCount];
}

- (NSDate *)lastFreeTrialOrUpgradeNudge {
    NSDate* ret = [self.sharedAppGroupDefaults objectForKey:kLastFreeTrialNudge];
    
    return ret ? ret : NSDate.date;
}

- (void)setLastFreeTrialOrUpgradeNudge:(NSDate *)lastFreeTrialOrUpgradeNudge {
    [self.sharedAppGroupDefaults setObject:lastFreeTrialOrUpgradeNudge forKey:kLastFreeTrialNudge];
}

- (NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    
    return [userDefaults objectForKey:kLastEntitlementCheckAttempt];
}

- (void)setLastEntitlementCheckAttempt:(NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    [userDefaults setObject:lastEntitlementCheckAttempt forKey:kLastEntitlementCheckAttempt];
    [userDefaults synchronize];
}

- (NSUInteger)numberOfEntitlementCheckFails {
    NSInteger ret =  [self.sharedAppGroupDefaults integerForKey:kNumberOfEntitlementCheckFails];
    return ret;
}

- (void)setNumberOfEntitlementCheckFails:(NSUInteger)numberOfEntitlementCheckFails {
    [self.sharedAppGroupDefaults setInteger:numberOfEntitlementCheckFails forKey:kNumberOfEntitlementCheckFails];
    [self.sharedAppGroupDefaults synchronize];
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



- (BOOL)screenCaptureBlocked {
    return [self getBool:kScreenCaptureBlocked];
}

- (void)setScreenCaptureBlocked:(BOOL)screenCaptureBlocked {
    [self setBool:kScreenCaptureBlocked value:screenCaptureBlocked];
}

- (BOOL)lockEvenIfEditing {
    return [self getBool:kLockEvenIfEditing fallback:YES];
}

- (void)setLockEvenIfEditing:(BOOL)lockEvenIfEditing {
    [self setBool:kLockEvenIfEditing value:lockEvenIfEditing];
}

- (BOOL)showCopyFieldButton {
    return [self getBool:kShowCopyFieldButton fallback:YES];
}

- (void)setShowCopyFieldButton:(BOOL)showCopyFieldButton {
    [self setBool:kShowCopyFieldButton value:showCopyFieldButton];
}

- (BOOL)quitStrongboxOnAllWindowsClosed {
    return [self getBool:kQuitOnAllWindowsClosed fallback:NO];
}

- (void)setQuitStrongboxOnAllWindowsClosed:(BOOL)quitStrongboxOnAllWindowsClosed {
    [self setBool:kQuitOnAllWindowsClosed value:quitStrongboxOnAllWindowsClosed];
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

- (BOOL)checkPinYin {
    return NO;
}

- (void)setCheckPinYin:(BOOL)checkPinYin {
    
}

- (BOOL)configuredAsAMenuBarApp {
    return Settings.sharedInstance.showSystemTrayIcon && Settings.sharedInstance.hideDockIconOnAllMinimized;
}

- (BOOL)showPasswordGenInTray {
    return [self getBool:kShowPasswordGenInTray fallback:YES];
}

- (void)setShowPasswordGenInTray:(BOOL)showPasswordGenInTray {
    [self setBool:kShowPasswordGenInTray value:showPasswordGenInTray];
}

- (BOOL)markdownNotes {
    return [self getBool:kMarkdownNotes fallback:YES];
}

- (void)setMarkdownNotes:(BOOL)markdownNotes {
    [self setBool:kMarkdownNotes value:markdownNotes];
}

- (BOOL)quickRevealWithOptionKey {
    return [self getBool:kQuickRevealWithOptionKey fallback:YES]; 
}

- (void)setQuickRevealWithOptionKey:(BOOL)quickRevealWithOptionKey {
    [self setBool:kQuickRevealWithOptionKey value:quickRevealWithOptionKey];
}

- (BOOL)miniaturizeOnCopy {
    return [self getBool:kMiniaturizeOnCopy fallback:NO];
}

- (void)setMiniaturizeOnCopy:(BOOL)miniaturizeOnCopy {
    [self setBool:kMiniaturizeOnCopy value:miniaturizeOnCopy];
}

- (BOOL)makeLocalRollingBackups {
    return [self getBool:kMakeLocalRollingBackups fallback:YES];
}

- (void)setMakeLocalRollingBackups:(BOOL)makeLocalRollingBackups {
    [self setBool:kMakeLocalRollingBackups value:makeLocalRollingBackups];
}

- (BOOL)closeManagerOnLaunch {
    return [self getBool:kCloseManagerOnLaunch fallback:YES];
}

- (void)setCloseManagerOnLaunch:(BOOL)closeManagerOnLaunch {
    [self setBool:kCloseManagerOnLaunch value:closeManagerOnLaunch];
}

- (BOOL)hideDockIconOnAllMinimized {
    return [self getBool:kHideDockIconOnAllMinimized];
}

- (void)setHideDockIconOnAllMinimized:(BOOL)hideDockIconOnAllMinimized {
    return [self setBool:kHideDockIconOnAllMinimized value:hideDockIconOnAllMinimized];
}

- (BOOL)showAutoFillTotpCopiedMessage {
    return [self getBool:kShowAutoFillTotpCopiedMessage fallback:YES];
}

- (void)setShowAutoFillTotpCopiedMessage:(BOOL)showAutoFillTotpCopiedMessage {
    [self setBool:kShowAutoFillTotpCopiedMessage value:showAutoFillTotpCopiedMessage];
}

- (BOOL)showDatabasesManagerOnCloseAllWindows {
    return [self getBool:kShowDatabasesManagerOnCloseAllWindows fallback:YES];
}

- (void)setShowDatabasesManagerOnCloseAllWindows:(BOOL)showDatabasesManagerOnCloseAllWindows {
    [self setBool:kShowDatabasesManagerOnCloseAllWindows value:showDatabasesManagerOnCloseAllWindows];
}

- (BOOL)clipboardHandoff {
    return [self getBool:kClipboardHandoff fallback:NO]; 
}

- (void)setClipboardHandoff:(BOOL)clipboardHandoff {
    [self setBool:kClipboardHandoff value:clipboardHandoff];
}

- (BOOL)colorizeUseColorBlindPalette {
    return [self getBool:kColorizeUseColorBlindPalette];
}

- (void)setColorizeUseColorBlindPalette:(BOOL)colorizeUseColorBlindPalette {
    [self setBool:kColorizeUseColorBlindPalette value:colorizeUseColorBlindPalette];
}

- (BOOL)colorizePasswords {
    return [self getBool:kColorizePasswords fallback:YES];
}

- (void)setColorizePasswords:(BOOL)colorizePasswords {
    [self setBool:kColorizePasswords value:colorizePasswords];
}

- (BOOL)allowEmptyOrNoPasswordEntry {
    return [self getBool:kAllowEmptyOrNoPasswordEntry];
}

- (void)setAllowEmptyOrNoPasswordEntry:(BOOL)allowEmptyOrNoPasswordEntry {
    [self setBool:kAllowEmptyOrNoPasswordEntry value:allowEmptyOrNoPasswordEntry];
}

- (BOOL)hideKeyFileNameOnLockScreen {
    return [self getBool:kHideKeyFileNameOnLockScreen];
}

- (void)setHideKeyFileNameOnLockScreen:(BOOL)hideKeyFileNameOnLockScreen {
    [self setBool:kHideKeyFileNameOnLockScreen value:hideKeyFileNameOnLockScreen];
}

- (BOOL)doNotRememberKeyFile {
    return [self getBool:kDoNotRememberKeyFile];
}

- (void)setDoNotRememberKeyFile:(BOOL)doNotRememberKeyFile {
    [self setBool:kDoNotRememberKeyFile value:doNotRememberKeyFile];
}

- (FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [self.userDefaults objectForKey:kFavIconDownloadOptions];

    if(encodedObject == nil) {
        return FavIconDownloadOptions.defaults;
    }

    FavIconDownloadOptions *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setFavIconDownloadOptions:(FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:favIconDownloadOptions];
    [self.userDefaults setObject:encodedObject forKey:kFavIconDownloadOptions];
    [self.userDefaults synchronize];
}

- (BOOL)showSystemTrayIcon {
    return [self getBool:kShowSystemTrayIcon fallback:YES];
}

- (void)setShowSystemTrayIcon:(BOOL)showSystemTrayIcon {
    [self setBool:kShowSystemTrayIcon value:showSystemTrayIcon];
}

- (BOOL)autoPromptForTouchIdOnActivate {
    return [self getBool:kAutoPromptForTouchIdOnActivate fallback:YES];
}

- (PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [self.userDefaults objectForKey:kPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return [PasswordGenerationConfig defaults];
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setPasswordGenerationConfig:(PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationConfig];
    [self.userDefaults setObject:encodedObject forKey:kPasswordGenerationConfig];
    [self.userDefaults synchronize];
}

- (PasswordGenerationConfig *)trayPasswordGenerationConfig {
    NSData *encodedObject = [self.userDefaults objectForKey:kTrayPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return self.passwordGenerationConfig; 
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setTrayPasswordGenerationConfig:(PasswordGenerationConfig *)trayPasswordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:trayPasswordGenerationConfig];
    [self.userDefaults setObject:encodedObject forKey:kTrayPasswordGenerationConfig];
    [self.userDefaults synchronize];
}

+ (NSArray<NSString*> *)kAllColumns
{
    static NSArray *_arr;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _arr = @[kTitleColumn, kUsernameColumn, kPasswordColumn, kTOTPColumn, kURLColumn, kEmailColumn, kNotesColumn, kExpiresColumn, kAttachmentsColumn, kCustomFieldsColumn];
    });
    
    return _arr;
}

- (BOOL)isPro {
    return [self getBool:kPro];
}

- (void)setPro:(BOOL)value {
    [self setBool:kPro value:value];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotification object:nil];
}

- (NSInteger)autoLockIfInBackgroundTimeoutSeconds {
    return [self.userDefaults integerForKey:kAutoLockIfInBackgroundTimeoutSeconds];
}

- (void)setAutoLockIfInBackgroundTimeoutSeconds:(NSInteger)autoLockIfInBackgroundTimeoutSeconds {
    [self.userDefaults setInteger:autoLockIfInBackgroundTimeoutSeconds forKey:kAutoLockIfInBackgroundTimeoutSeconds];
    
    [self.userDefaults synchronize];
}

- (NSInteger)autoLockTimeoutSeconds {
    return [self.userDefaults integerForKey:kAutoLockTimeout];
}

- (void)setAutoLockTimeoutSeconds:(NSInteger)autoLockTimeoutSeconds {
    [self.userDefaults setInteger:autoLockTimeoutSeconds forKey:kAutoLockTimeout];
    
    [self.userDefaults synchronize];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [self.userDefaults objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [self.userDefaults setObject:encoded forKey:kAutoFillNewRecordSettings];
    [self.userDefaults synchronize];
}

-(BOOL)autoSave {
    
    
    NSObject* autoSave = [self.userDefaults objectForKey:kAutoSave];

    BOOL ret = TRUE;
    if(!autoSave) {
        
    }
    else {
        NSNumber* num = (NSNumber*)autoSave;
        ret = num.boolValue;
    }

    return ret;
}

-(void)setAutoSave:(BOOL)autoSave {
    [self setBool:kAutoSave value:autoSave];
}

- (BOOL)clearClipboardEnabled {
    return [self getBool:kClearClipboardEnabled fallback:YES]; 
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [self setBool:kClearClipboardEnabled value:clearClipboardEnabled];
}

- (NSInteger)clearClipboardAfterSeconds {
    
    NSInteger ret = [self.userDefaults integerForKey:kClearClipboardAfterSeconds];

    return ret == 0 ? kDefaultClearClipboardTimeout : ret;
}


- (void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    
    
    [self.userDefaults setInteger:clearClipboardAfterSeconds forKey:kClearClipboardAfterSeconds];
    
    [self.userDefaults synchronize];
}

- (BOOL)floatOnTop {
    return [self getBool:kFloatOnTop];
}

- (void)setFloatOnTop:(BOOL)floatOnTop {
    [self setBool:kFloatOnTop value:floatOnTop];
}

- (NSString *)easyReadFontName {
    return @"Menlo";
}



- (BOOL)revealPasswordsImmediately {
    return [self getBool:kShowPasswordImmediatelyInOutline] || [self getBool:kAlwaysShowPassword];
}

- (void)setRevealPasswordsImmediately:(BOOL)revealPasswordsImmediately {
    [self setBool:kShowPasswordImmediatelyInOutline value:revealPasswordsImmediately];
    [self setBool:kAlwaysShowPassword value:revealPasswordsImmediately];
}



- (NSData *)duressDummyData {
    slog(@"🔴 NOTIMPL: duressDummyData");
    return nil;
}

- (void)setDuressDummyData:(NSData *)duressDummyData {
    slog(@"🔴 NOTIMPL: setDuressDummyData");
}

- (PasswordStrengthConfig *)passwordStrengthConfig {
    return PasswordStrengthConfig.defaults;
}

- (void)setPasswordStrengthConfig:(PasswordStrengthConfig *)passwordStrengthConfig {
    slog(@"🔴 NOTIMPL: setPasswordStrengthConfig");
}

- (BOOL)hasShownFirstRunWelcome {
    return [self getBool:kHasShownFirstRunWelcome];
}

- (void)setHasShownFirstRunWelcome:(BOOL)hasShownFirstRunWelcome {
    [self setBool:kHasShownFirstRunWelcome value:hasShownFirstRunWelcome];
}

@end
































































