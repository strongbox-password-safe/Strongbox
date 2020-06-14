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

@interface Settings : NSObject

+ (Settings *)sharedInstance;

@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;

- (void)resetLaunchCount;
- (NSInteger)getLaunchCount;
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

@property NSDate* lastFreeTrialNudge;

NS_ASSUME_NONNULL_END

@end
