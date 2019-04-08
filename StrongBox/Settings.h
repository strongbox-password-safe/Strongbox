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

- (void)requestBiometricId:(NSString*)reason completion:(void(^)(BOOL success, NSError * __nullable error))completion;
- (void)requestBiometricId:(NSString  *)reason fallbackTitle:(NSString*_Nullable)fallbackTitle completion:(void(^_Nullable)(BOOL success, NSError * __nullable error))completion;
@property BOOL biometricAuthInProgress;
+ (BOOL)isBiometricIdAvailable;


- (BOOL)isShowPasswordByDefaultOnEditScreen;
- (void)setShowPasswordByDefaultOnEditScreen:(BOOL)value;

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

- (NSInteger)isUserHasBeenPromptedForReview;
- (void)setUserHasBeenPromptedForReview:(NSInteger)value;

- (BOOL)isHasPromptedForCopyPasswordGesture;
- (void)setHasPromptedForCopyPasswordGesture:(BOOL)value;

- (BOOL)isCopyPasswordOnLongPress;
- (void)setCopyPasswordOnLongPress:(BOOL)value;

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

@property AppLockMode appLockMode;
@property NSString* appLockPin;
@property NSInteger appLockDelay;

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

NS_ASSUME_NONNULL_END

@end
