//
//  SharedAppAndAutoFillSettings.h
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationConfig.h"
#import "AutoFillNewRecordSettings.h"
#import "FavIconDownloadOptions.h"
#import "DatabaseCellSubtitleField.h"

NS_ASSUME_NONNULL_BEGIN

@interface SharedAppAndAutoFillSettings : NSObject

+ (instancetype)sharedInstance;

@property (nullable, readonly) NSUserDefaults* sharedAppGroupDefaults;
@property (readonly) NSString* appGroupName;
@property BOOL suppressPrivacyScreen; // Used by Biometric Auth and Google Drive to suppress privacy screen which interferes with their operation - Not actually stored or serialized - belongs elsewhere

#ifndef IS_APP_EXTENSION

@property BOOL colorizeUseColorBlindPalette;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property (nonatomic) BOOL disallowAllPinCodeOpens;
@property (nonatomic) BOOL disallowAllBiometricId;
@property (nullable) NSString* quickLaunchUuid;
@property BOOL allowEmptyOrNoPasswordEntry;
@property BOOL hideKeyFileOnUnlock;
@property BOOL showYubikeySecretWorkaroundField;
@property (nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (nonatomic) BOOL hideTips;
@property BOOL clipboardHandoff;
@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;
@property NSData* duressDummyData;

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

#else

@property (readonly) BOOL colorizeUseColorBlindPalette;
@property (readonly, nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property (readonly, nonatomic) BOOL disallowAllPinCodeOpens;
@property (readonly, nonatomic) BOOL disallowAllBiometricId;
@property (readonly, nullable) NSString* quickLaunchUuid;
@property (readonly) BOOL allowEmptyOrNoPasswordEntry;
@property (readonly) BOOL hideKeyFileOnUnlock;
@property (readonly) BOOL showYubikeySecretWorkaroundField;
@property (readonly, nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (readonly, nonatomic) BOOL hideTips;
@property (readonly) BOOL clipboardHandoff;
@property (readonly) BOOL clearClipboardEnabled;
@property (readonly) NSInteger clearClipboardAfterSeconds;
@property (readonly) NSData* duressDummyData;

@property (readonly) BOOL freeTrialHasBeenOptedInAndExpired;
@property (readonly) NSInteger freeTrialDaysLeft;
@property (readonly) BOOL isProOrFreeTrial;
@property (readonly) BOOL isPro;
@property (readonly) BOOL isFreeTrial;
@property (readonly) BOOL hasOptedInToFreeTrial;
@property (readonly) NSDate *freeTrialEnd;

- (NSDate*)calculateFreeTrialEndDateFromDate:(NSDate*)from;

@property (readonly) BOOL showAllFilesInLocalKeyFiles;
@property (readonly) BOOL monitorInternetConnectivity;
@property (readonly) BOOL instantPinUnlocking;
@property (nonatomic) BOOL iCloudOn;
@property (readonly) FavIconDownloadOptions *favIconDownloadOptions;
@property (readonly) BOOL showDatabasesSeparator;
@property (readonly) BOOL showDatabaseStatusIcon;
@property (readonly) DatabaseCellSubtitleField databaseCellTopSubtitle;
@property (readonly) DatabaseCellSubtitleField databaseCellSubtitle1;
@property (readonly) DatabaseCellSubtitleField databaseCellSubtitle2;
@property (readonly) BOOL showDatabaseIcon;

#endif

@end

NS_ASSUME_NONNULL_END
