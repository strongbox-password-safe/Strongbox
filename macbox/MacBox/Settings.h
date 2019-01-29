//
//  Settings.h
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationParameters.h"
#import "AutoFillNewRecordSettings.h"

@interface Settings : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic) BOOL revealDetailsImmediately;
@property (nonatomic) BOOL fullVersion;

@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;
@property (nonatomic, strong) NSDate* endFreeTrialDate;
@property (nonatomic) NSInteger autoLockTimeoutSeconds;
@property (nonatomic, strong) PasswordGenerationParameters *passwordGenerationParameters;

@property (nonatomic) BOOL alwaysShowUsernameInOutlineView;
@property (nonatomic) BOOL alwaysShowPassword;
@property (nonatomic) BOOL warnedAboutTouchId;

@property (nonatomic) AutoFillNewRecordSettings *autoFillNewRecordSettings;
@property (nonatomic) BOOL autoSave;

@property BOOL uiDoNotSortKeePassNodesInBrowseView;

@end

//    [[Settings sharedInstance] setPro:NO];
//    [[Settings sharedInstance] setEndFreeTrialDate:nil];
//    [[Settings sharedInstance] setHavePromptedAboutFreeTrial:NO];
//    [[Settings sharedInstance] resetLaunchCount];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:9 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];


//    [[Settings sharedInstance] setFullVersion:NO];
//[[Settings sharedInstance] setEndFreeTrialDate:nil];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:-10 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];
//
