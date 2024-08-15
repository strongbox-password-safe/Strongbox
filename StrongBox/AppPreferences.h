//
//  SharedAppAndAutoFillSettings.h
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AutoFillNewRecordSettings.h"
#import "FavIconDownloadOptions.h"
#import "DatabaseCellSubtitleField.h"
#import "AppPrivacyShieldMode.h"
#import "AppLockMode.h"
#import "ApplicationPreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppPreferences : NSObject<ApplicationPreferences>

+ (instancetype)sharedInstance;

@property (nullable, readonly) NSUserDefaults* sharedAppGroupDefaults;
@property (readonly) NSString* appGroupName;
@property BOOL suppressAppBackgroundTriggers; 

@property BOOL colorizeUseColorBlindPalette;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property (nullable) NSString* quickLaunchUuid;
@property BOOL allowEmptyOrNoPasswordEntry;
@property BOOL hideKeyFileOnUnlock;
@property (nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (nonatomic) BOOL hideTips;
@property BOOL clipboardHandoff;
@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;
@property (nullable) NSData* duressDummyData;



@property (readonly) BOOL isPro;
- (void)setPro:(BOOL)value;

@property BOOL showAllFilesInLocalKeyFiles;
@property BOOL monitorInternetConnectivity;

@property FavIconDownloadOptions *favIconDownloadOptions;
@property BOOL showDatabasesSeparator;
@property BOOL showDatabaseStatusIcon;
@property DatabaseCellSubtitleField databaseCellTopSubtitle;
@property DatabaseCellSubtitleField databaseCellSubtitle1;
@property DatabaseCellSubtitleField databaseCellSubtitle2;
@property BOOL showDatabaseIcon;

@property BOOL syncPullEvenIfModifiedDateSame; 
@property BOOL syncForcePushDoNotCheckForConflicts; 

@property BOOL autoFillDidChangeDatabases;
@property BOOL mainAppDidChangeDatabases;

@property BOOL showMetadataOnDetailsScreen;
@property BOOL userHasOptedInToThirdPartyStorageLibraries;



@property BOOL autoFillExitedCleanly;
@property BOOL autoFillWroteCleanly;

@property BOOL haveWarnedAboutAutoFillCrash;
@property BOOL dontNotifyToSwitchToMainAppForSync;

@property BOOL storeAutoFillServiceIdentifiersInNotes;
@property BOOL useFullUrlAsURLSuggestion;
@property BOOL autoProceedOnSingleMatch;
@property BOOL showAutoFillTotpCopiedMessage;

@property BOOL autoFillAutoLaunchSingleDatabase;
@property (nullable) NSString* autoFillQuickLaunchUuid;
@property BOOL migratedQuickLaunchToAutoFill;
@property BOOL autoFillShowFavourites;
@property BOOL coalesceAppLockAndQuickLaunchBiometrics;

@property AppPrivacyShieldMode appPrivacyShieldMode;
@property BOOL migratedOfflineDetectedBehaviour;



@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;

@property (readonly) NSUInteger launchCount;
- (void)resetLaunchCount;
- (void)incrementLaunchCount;

- (NSString*)getFlagsStringForDiagnostics;

@property (nonatomic) NSDate* installDate;
@property (nonatomic, readonly) NSInteger daysInstalled;
- (void)clearInstallDate;

@property (nonatomic) BOOL showKeePassCreateSafeOptions;

@property AppLockMode appLockMode;
@property NSString* appLockPin;
@property NSInteger appLockDelay;
@property BOOL appLockAppliesToPreferences;
@property NSInteger deleteDataAfterFailedUnlockCount;
@property NSUInteger failedUnlockAttempts;

@property BOOL backupFiles;
@property BOOL backupIncludeImportedKeyFiles;
@property BOOL haveAskedAboutBackupSettings;

@property BOOL hideExportFromDatabaseContextMenu;
@property BOOL allowThirdPartyKeyboards;

@property BOOL appLockAllowDevicePasscodeFallbackForBio;

@property BOOL haveAttemptedMigrationToFullFileProtection;

@property PasswordStrengthConfig* passwordStrengthConfig;
@property NSInteger promptedForSale;

@property BOOL addLegacySupplementaryTotpCustomFields;
@property BOOL addOtpAuthUrl;

@property BOOL pinYinSearchEnabled;

@property (nullable) NSData* lastKnownGoodBiometricsDatabaseState;
@property (nullable) NSData* autoFillLastKnownGoodBiometricsDatabaseState;

@property BOOL scheduledTipsCheckDone;
@property BOOL hasShownFirstRunWelcome;
@property BOOL hasShownFirstRunFinalWelcome;
@property (nullable) NSDate* lastAskToEnableAutoFill;
@property BOOL promptToEnableAutoFill;

@property NSDate* lastFreeTrialNudge;
@property NSUInteger freeTrialNudgeCount;

@property BOOL appHasBeenDowngradedToFreeEdition; 
@property BOOL hasPromptedThatAppHasBeenDowngradedToFreeEdition;

@property BOOL hasPromptedThatFreeTrialWillEndSoon;

@property BOOL databasesAreAlwaysReadOnly;
@property BOOL disableExport;
@property BOOL disablePrinting;
@property BOOL disableWiFiSyncClientMode;
@property BOOL disableFavIconFeature;
@property BOOL disableNetworkBasedFeatures; 


@property BOOL useIsolatedDropbox;



@property BOOL instantPinUnlocking;

@property BOOL exportItemsPreserveUUIDs;
@property BOOL exportItemsReplaceExisting;
@property BOOL exportItemsPreserveTimestamps;

@property BOOL duplicateItemReferencePassword;
@property BOOL duplicateItemReferenceUsername;
@property BOOL duplicateItemPreserveTimestamp;
@property BOOL duplicateItemEditAfterwards;

@property BOOL disableThirdPartyStorageOptions; 

@property BOOL markdownNotes;

@property BOOL autoFillLongTapPreview;
@property BOOL hideTipJar;

@property BOOL useParentGroupIconOnCreate;

@property BOOL stripUnusedIconsOnSave;
@property BOOL stripUnusedHistoricalIcons;

@property BOOL pinCodeHapticFeedback;

@property BOOL hasMigratedToLazySync;

@property (nullable) NSString* businessOrganisationName;

@property BOOL appendDateToExportFileName;

@property (nullable) NSDate* lastQuickTypeMultiDbRegularClear;

@property BOOL atomicSftpWrite;

@property NSString* databasesSerializationError;

@property BOOL wiFiSyncHasRequestedNetworkPermissions;

@property BOOL zipExports;

@property BOOL runAsWiFiSyncSourceDevice;
@property (nullable) NSString* wiFiSyncServiceName;
@property (nullable) NSString* wiFiSyncPasscode;

@property BOOL cloudKitZoneCreated;

@property BOOL showDatabasesOnAppShortcutMenu;

@property BOOL hasWarnedAboutCloudKitUnavailability;
@property BOOL hasGotUserNotificationsPermissions;
@property (nullable) NSDate* lastAskToEnableNotifications;
@property BOOL showDatabaseNamesInBrowse;
@property BOOL warnAboutLocalDeviceDatabases;

@property BOOL disableCopyTo;
@property BOOL disableMakeVisibleInFiles;

@property BOOL disableHomeTab;

@property BOOL hardwareKeyCachingBeta;
@property BOOL hasMigratedInconsistentHardwareKeysForCachingFeature;

@end

NS_ASSUME_NONNULL_END
