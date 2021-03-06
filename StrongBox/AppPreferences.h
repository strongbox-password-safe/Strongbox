//
//  SharedAppAndAutoFillSettings.h
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationConfig.h"
#import "AutoFillNewRecordSettings.h"
#import "FavIconDownloadOptions.h"
#import "DatabaseCellSubtitleField.h"
#import "AppPrivacyShieldMode.h"
#import "AppLockMode.h"
#import "PasswordStrengthConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppPreferences : NSObject

+ (instancetype)sharedInstance;

@property (nullable, readonly) NSUserDefaults* sharedAppGroupDefaults;
@property (readonly) NSString* appGroupName;
@property BOOL suppressAppBackgroundTriggers; 

@property BOOL colorizeUseColorBlindPalette;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property (nonatomic) BOOL disallowAllPinCodeOpens;
@property (nonatomic) BOOL disallowAllBiometricId;
@property (nullable) NSString* quickLaunchUuid;
@property BOOL allowEmptyOrNoPasswordEntry;
@property BOOL hideKeyFileOnUnlock;
@property (nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (nonatomic) BOOL hideTips;
@property BOOL clipboardHandoff;
@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;
@property (nullable) NSData* duressDummyData;

@property (readonly) BOOL freeTrialHasBeenOptedInAndExpired;
@property (readonly) NSInteger freeTrialDaysLeft;
@property (readonly) BOOL isProOrFreeTrial;
@property (readonly) BOOL isPro;
@property (readonly) BOOL isFreeTrial;
@property (readonly) BOOL hasOptedInToFreeTrial;
- (void)setPro:(BOOL)value;
@property NSDate *freeTrialEnd;
- (NSDate*)calculateFreeTrialEndDateFromDate:(NSDate*)from;

@property BOOL showAllFilesInLocalKeyFiles;
@property BOOL monitorInternetConnectivity;
@property BOOL instantPinUnlocking;
@property (nonatomic) BOOL iCloudOn;
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
@property BOOL autoFillShowPinned;
@property BOOL coalesceAppLockAndQuickLaunchBiometrics;

@property AppPrivacyShieldMode appPrivacyShieldMode;
@property BOOL migratedOfflineDetectedBehaviour;
@property BOOL useBackgroundUpdates;



@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;

@property (readonly) NSUInteger launchCount;

- (void)resetLaunchCount;
- (void)incrementLaunchCount;

- (NSString*)getFlagsStringForDiagnostics;

@property (nonatomic) BOOL iCloudWasOn;
@property (nonatomic) BOOL iCloudPrompted;
@property (nonatomic) BOOL iCloudAvailable;

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
@property BOOL fullFileProtection;

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

@end

NS_ASSUME_NONNULL_END
