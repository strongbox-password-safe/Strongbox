//
//  Settings.h
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationParameters.h"
#import "AutoFillNewRecordSettings.h"
#import "SFTPSessionConfiguration.h"
#import "AppLockMode.h"

NS_ASSUME_NONNULL_BEGIN

static NSString* const kAppGroupName = @"group.strongbox.mcguill";
static NSString* const kProStatusChangedNotificationKey = @"proStatusChangedNotification";

@interface Settings : NSObject

+ (Settings *)sharedInstance;
- (NSUserDefaults*)getUserDefaults;

- (void)requestBiometricId:(NSString*)reason
     allowDevicePinInstead:(BOOL)allowDevicePinInstead
                completion:(void(^)(BOOL success, NSError * __nullable error))completion;

- (void)requestBiometricId:(NSString  *)reason
             fallbackTitle:(NSString*_Nullable)fallbackTitle
     allowDevicePinInstead:(BOOL)allowDevicePinInstead
                completion:(void(^_Nullable)(BOOL success, NSError * __nullable error))completion;

@property BOOL suppressPrivacyScreen;

+ (BOOL)isBiometricIdAvailable;

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

- (NSNumber*)getAutoLockTimeoutSeconds;
- (void)setAutoLockTimeoutSeconds:(NSNumber*)value;

@property (nonatomic) BOOL showPasswordByDefaultOnEditScreen;

@property (nonatomic) BOOL neverShowForMacAppMessage;
@property (nonatomic) BOOL iCloudOn;
@property (nonatomic) BOOL iCloudWasOn;
@property (nonatomic) BOOL iCloudPrompted;
@property (nonatomic) BOOL iCloudAvailable;
@property (nonatomic) BOOL doNotAutoAddNewLocalSafes;
        
- (NSString*)getFlagsStringForDiagnostics;
- (NSString*)getBiometricIdName;

@property (nonatomic, strong) PasswordGenerationParameters *passwordGenerationParameters;
@property (nonatomic) BOOL safesMigratedToNewSystem; 

@property (nonatomic) NSDate* installDate;
@property (nonatomic, readonly) NSInteger daysInstalled;

- (void)clearInstallDate;

@property (nonatomic) BOOL disallowAllPinCodeOpens;
@property (nonatomic) BOOL disallowAllBiometricId;
@property (nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (nonatomic) BOOL useQuickLaunchAsRootView;
@property (nonatomic) BOOL showKeePassCreateSafeOptions;
@property (nonatomic) BOOL hasShownAutoFillLaunchWelcome;
@property (nonatomic) BOOL hasShownKeePassBetaWarning;

@property (nonatomic) BOOL showKeePass1BackupGroup;
@property (nonatomic) BOOL hideTips;

@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;

@property BOOL hideTotp;
@property BOOL hideTotpInBrowse;
@property BOOL hideTotpInAutoFill;
@property BOOL uiDoNotSortKeePassNodesInBrowseView;
@property BOOL tryDownloadFavIconForNewRecord;
@property BOOL doNotAutoDetectKeyFiles;

@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;

@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;
@property BOOL doNotCopyOtpCodeOnAutoFillSelect;

@property BOOL doNotUseQuickTypeAutoFill;

@property BOOL viewDereferencedFields;
@property BOOL searchDereferencedFields;

@property BOOL useOldItemDetailsScene;
@property BOOL showEmptyFieldsInDetailsView;

@property NSArray<NSNumber*>* detailsViewCollapsedSections;
@property BOOL easyReadFontForAll;

@property BOOL instantPinUnlocking;
@property BOOL showChildCountOnFolderInBrowse;

@property BOOL showFlagsInBrowse;
@property BOOL showUsernameInBrowse;

@property BOOL haveWarnedAboutAutoFillCrash;

@property AppLockMode appLockMode;
@property NSString* appLockPin;
@property NSInteger appLockDelay;
@property BOOL appLockAppliesToPreferences;

@property NSInteger deleteDataAfterFailedUnlockCount;
@property NSUInteger failedUnlockAttempts;

@property BOOL showAdvancedUnlockOptions;
@property BOOL temporaryUseOldUnlock;
@property BOOL allowEmptyOrNoPasswordEntry; 

NS_ASSUME_NONNULL_END

@end
