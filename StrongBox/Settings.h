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

static NSString* kAppGroupName = @"group.strongbox.mcguill";

@interface Settings : NSObject

+ (Settings *)sharedInstance;

- (void) startMonitoringConnectivitity;
- (BOOL) isOffline;

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

@property (nonatomic) BOOL disallowAllBiometricId;
@property (nonatomic, strong) AutoFillNewRecordSettings* autoFillNewRecordSettings;
@property (nonatomic) BOOL useQuickLaunchAsRootView;

@end
