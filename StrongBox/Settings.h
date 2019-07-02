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
#import "BrowseItemSubtitleField.h"
#import "BrowseSortField.h"
#import "BrowseViewType.h"
#import "PasswordGenerationConfig.h"

NS_ASSUME_NONNULL_BEGIN

static NSString* const kAppGroupName = @"group.strongbox.mcguill"; // TODO: This could be an issue for custom builds - can we get from config?
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

- (NSString*)getFlagsStringForDiagnostics;
- (NSString*)getBiometricIdName;

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
@property (nonatomic) BOOL useQuickLaunchAsRootView;
@property (nonatomic) BOOL showKeePassCreateSafeOptions;
@property (nonatomic) BOOL hasShownAutoFillLaunchWelcome;
@property (nonatomic) BOOL hasShownKeePassBetaWarning;

@property (nonatomic) BOOL hideTips;

@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;

@property BOOL hideTotpInAutoFill;

@property BOOL doNotAutoDetectKeyFiles;
@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;
@property BOOL doNotCopyOtpCodeOnAutoFillSelect;

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
@property BOOL doNotUseNewSplitViewController;
@property BOOL allowEmptyOrNoPasswordEntry;
@property BOOL migratedLocalDatabasesToNewSystem;
@property BOOL useSharedAppGroupLocalStorage; // TODO: Default this on soon

// TODO: Remove after migration...

@property BOOL migratedToNewPasswordGenerator;
@property (nonatomic, strong) PasswordGenerationParameters *passwordGenerationParameters;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;


NS_ASSUME_NONNULL_END

@end
