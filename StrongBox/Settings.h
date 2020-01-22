//
//  Settings.h
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AutoFillNewRecordSettings.h"
#import "SFTPSessionConfiguration.h"
#import "AppLockMode.h"
#import "BrowseItemSubtitleField.h"
#import "BrowseSortField.h"
#import "BrowseViewType.h"
#import "PasswordGenerationConfig.h"
#import "DatabaseCellSubtitleField.h"
#import "FavIconDownloadOptions.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kProStatusChangedNotificationKey;
extern NSString* const kCentralUpdateOtpUiNotification;


@interface Settings : NSObject

+ (Settings *)sharedInstance;

- (NSUserDefaults*_Nullable)getUserDefaults;

- (void)setHavePromptedAboutFreeTrial:(BOOL)value;
- (BOOL)isHavePromptedAboutFreeTrial;
- (BOOL)isProOrFreeTrial;

- (BOOL)isPro;
- (void)setPro:(BOOL)value;

- (BOOL)isFreeTrial;
- (NSInteger)getFreeTrialDaysRemaining;

- (NSDate*)getEndFreeTrialDate;
- (void)setEndFreeTrialDate:(NSDate*)value;

- (void)resetLaunchCount;
- (NSInteger)getLaunchCount;
- (void)incrementLaunchCount;

- (NSString*)getFlagsStringForDiagnostics;

@property (nonatomic) BOOL neverShowForMacAppMessage;

@property (nonatomic) BOOL iCloudOn;
@property (nonatomic) BOOL iCloudWasOn;
@property (nonatomic) BOOL iCloudPrompted;
@property (nonatomic) BOOL iCloudAvailable;
@property (nonatomic) BOOL safesMigratedToNewSystem;

@property (nonatomic) NSDate* installDate;
@property (nonatomic, readonly) NSInteger daysInstalled;

- (void)clearInstallDate;

@property (nonatomic) BOOL disallowAllPinCodeOpens;
@property (nonatomic) BOOL disallowAllBiometricId;
@property (nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (nonatomic) BOOL showKeePassCreateSafeOptions;
@property (nonatomic) BOOL hasShownAutoFillLaunchWelcome;
@property (nonatomic) BOOL hasShownKeePassBetaWarning;

@property (nonatomic) BOOL hideTips;

@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;

@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;

@property BOOL instantPinUnlocking;
@property BOOL haveWarnedAboutAutoFillCrash;
@property AppLockMode appLockMode;
@property NSString* appLockPin;
@property NSInteger appLockDelay;
@property BOOL appLockAppliesToPreferences;
@property NSInteger deleteDataAfterFailedUnlockCount;
@property NSUInteger failedUnlockAttempts;
@property BOOL showAllFilesInLocalKeyFiles;
@property BOOL hideKeyFileOnUnlock;
@property BOOL allowEmptyOrNoPasswordEntry;

@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;

@property (readonly) NSString* appGroupName;

@property BOOL showYubikeySecretWorkaroundField;

@property (nullable) NSString* quickLaunchUuid;

@property BOOL showDatabaseIcon;
@property BOOL showDatabasesSeparator;
@property BOOL showDatabaseStatusIcon;
@property DatabaseCellSubtitleField databaseCellTopSubtitle;
@property DatabaseCellSubtitleField databaseCellSubtitle1;
@property DatabaseCellSubtitleField databaseCellSubtitle2;

@property BOOL monitorInternetConnectivity;

@property BOOL hasDoneProFamilyCheck;

@property BOOL suppressPrivacyScreen; // Used by Biometric Auth and Google Drive to suppress privacy screen which interferes with their operation

@property FavIconDownloadOptions *favIconDownloadOptions;

@property BOOL clipboardHandoff;

@property BOOL migratedToNewSecretStore;

NS_ASSUME_NONNULL_END

@end
