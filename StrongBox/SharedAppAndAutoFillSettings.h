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

@property (readonly) BOOL uberSync; // Readonly shim over below allowing for easy default on/off as configured
@property (nullable) NSNumber* optionalUberSync; // Allowing for a default "Unset" == nil - meaning the user hasn't chosen, opt them into whatever is appropriate - NONE UBER SYNC for now - 20-June-2020

@end

NS_ASSUME_NONNULL_END
