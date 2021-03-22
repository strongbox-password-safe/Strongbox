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

@end

NS_ASSUME_NONNULL_END
