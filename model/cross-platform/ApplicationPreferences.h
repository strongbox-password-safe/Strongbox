//
//  ApplicationPreferences.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef ApplicationPreferences_h
#define ApplicationPreferences_h

#import "PasswordGenerationConfig.h"
#import "PasswordStrengthConfig.h"
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    kAppAppearanceSystem,
    kAppAppearanceLight,
    kAppAppearanceDark,
} AppAppearance;

@protocol ApplicationPreferences <NSObject>

@property (nullable) NSData* duressDummyData;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property PasswordStrengthConfig* passwordStrengthConfig;
@property BOOL checkPinYin;
@property BOOL atomicSftpWrite;

@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;
@property BOOL appHasBeenDowngradedToFreeEdition; 
@property BOOL hasPromptedThatAppHasBeenDowngradedToFreeEdition;

@property (readonly) BOOL isPro;
- (void)setPro:(BOOL)value;

@property BOOL stripUnusedIconsOnSave;
@property BOOL stripUnusedHistoricalIcons;
@property BOOL useIsolatedDropbox;

@property BOOL addLegacySupplementaryTotpCustomFields;
@property BOOL addOtpAuthUrl;

@property (nullable) NSDate* lastQuickTypeMultiDbRegularClear;

@property BOOL databasesAreAlwaysReadOnly;
@property BOOL disableExport;
@property BOOL disableCopyTo;
@property BOOL disableMakeVisibleInFiles;
@property BOOL disablePrinting;

@property (nullable) NSString* businessOrganisationName;

@property BOOL autoFillWroteCleanly;

@property BOOL runAsWiFiSyncSourceDevice;
@property (nullable) NSString* wiFiSyncServiceName;

@property (nullable) NSString* lastWiFiSyncPasscodeError;
@property (nullable) NSString* wiFiSyncPasscode;

@property BOOL disableWiFiSyncClientMode;
@property BOOL disableNetworkBasedFeatures;

@property BOOL cloudKitZoneCreated;
@property BOOL changeNotificationsSubscriptionCreated;
@property (nullable) NSDate* lastCloudKitRefresh;

@property AppAppearance appAppearance; 

@property BOOL useOneDriveUSGovCloudInstance;

@property BOOL hardwareKeyCachingBeta;

@end

NS_ASSUME_NONNULL_END

#endif /* ApplicationPreferences_h */
