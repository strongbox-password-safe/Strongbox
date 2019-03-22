//
//  Settings.m
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"

#define kRevealDetailsImmediately @"revealDetailsImmediately"
#define kFullVersion @"fullVersion"
#define kEndFreeTrialDate @"endFreeTrialDate"
#define kAutoLockTimeout @"autoLockTimeout"
#define kPasswordGenerationParameters @"passwordGenerationParameters"
#define kWarnedAboutTouchId @"warnedAboutTouchId"
#define kAlwaysShowUsernameInOutlineView @"alwaysShowUsernameInOutlineView"
#define kAlwaysShowPassword @"alwaysShowPassword"
#define kUiDoNotSortKeePassNodesInBrowseView @"uiDoNotSortKeePassNodesInBrowseView"

static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kAutoSave = @"autoSave";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kDoNotShowTotp = @"doNotShowTotp";
static NSString* const kShowRecycleBinInSearchResults = @"showRecycleBinInSearchResults";
static NSString* const kDoNotShowRecycleBinInBrowse = @"doNotShowRecycleBinInBrowse";
            
static const NSInteger kDefaultClearClipboardTimeout = 60;

@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    return sharedInstance;
}

- (BOOL)revealDetailsImmediately {
    return [self getBool:kRevealDetailsImmediately];
}

- (void)setRevealDetailsImmediately:(BOOL)value {
    [self setBool:kRevealDetailsImmediately value:value];
}

- (BOOL)warnedAboutTouchId {
    return [self getBool:kWarnedAboutTouchId];
}

- (void)setWarnedAboutTouchId:(BOOL)warnedAboutTouchId {
    [self setBool:kWarnedAboutTouchId value:warnedAboutTouchId];
}

- (BOOL)fullVersion {
    return [self getBool:kFullVersion];
}

- (void)setFullVersion:(BOOL)value {
    [self setBool:kFullVersion value:value];
}

- (BOOL)alwaysShowPassword {
    return [self getBool:kAlwaysShowPassword];
}

-(void)setAlwaysShowPassword:(BOOL)alwaysShowPassword {
    [self setBool:kAlwaysShowPassword value:alwaysShowPassword];
}

- (BOOL)alwaysShowUsernameInOutlineView {
    return [self getBool:kAlwaysShowUsernameInOutlineView];
}

- (void)setAlwaysShowUsernameInOutlineView:(BOOL)alwaysShowUsernameInOutlineView {
    [self setBool:kAlwaysShowUsernameInOutlineView value:alwaysShowUsernameInOutlineView];
}

- (BOOL)freeTrial {
    NSDate* date = self.endFreeTrialDate;
    
    if(date == nil) {
        return YES;
    }
    
    return !([date timeIntervalSinceNow] < 0);
}

- (NSInteger)freeTrialDaysRemaining {
    NSDate* date = self.endFreeTrialDate;
    
    if(date == nil) {
        return -1;
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                fromDate:[NSDate date]
                                                  toDate:date
                                                 options:0];
    
    NSInteger days = [components day];
    
    return days;
}

- (NSDate*)endFreeTrialDate {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setEndFreeTrialDate:(NSDate *)endFreeTrialDate {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:endFreeTrialDate forKey:kEndFreeTrialDate];
    
    [userDefaults synchronize];
}

- (BOOL)getBool:(NSString*)key {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    return [userDefaults boolForKey:key];
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:key];
    
    [userDefaults synchronize];
}

- (NSInteger)autoLockTimeoutSeconds {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults integerForKey:kAutoLockTimeout];
}

- (void)setAutoLockTimeoutSeconds:(NSInteger)autoLockTimeoutSeconds {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setInteger:autoLockTimeoutSeconds forKey:kAutoLockTimeout];
    
    [userDefaults synchronize];
}

- (PasswordGenerationParameters *)passwordGenerationParameters {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationParameters];
    
    if(encodedObject == nil) {
        return [[PasswordGenerationParameters alloc] initWithDefaults];
    }
    
    PasswordGenerationParameters *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return object;
}

-(void)setPasswordGenerationParameters:(PasswordGenerationParameters *)passwordGenerationParameters {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationParameters];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:encodedObject forKey:kPasswordGenerationParameters];
    [defaults synchronize];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [[NSUserDefaults standardUserDefaults] setObject:encoded forKey:kAutoFillNewRecordSettings];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(BOOL)autoSave {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSObject* autoSave = [userDefaults objectForKey:kAutoSave];

    BOOL ret = TRUE;
    if(!autoSave) {
        NSLog(@"No Autosave settings... defaulting to Yes");
    }
    else {
        NSNumber* num = (NSNumber*)autoSave;
        ret = num.boolValue;
    }

    return ret;
}

-(void)setAutoSave:(BOOL)autoSave {
    [self setBool:kAutoSave value:autoSave];
}

- (BOOL)uiDoNotSortKeePassNodesInBrowseView {
    return [self getBool:kUiDoNotSortKeePassNodesInBrowseView];
}

- (void)setUiDoNotSortKeePassNodesInBrowseView:(BOOL)uiDoNotSortKeePassNodesInBrowseView {
    [self setBool:kUiDoNotSortKeePassNodesInBrowseView value:uiDoNotSortKeePassNodesInBrowseView];
}

- (BOOL)clearClipboardEnabled {
    return [self getBool:kClearClipboardEnabled];
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [self setBool:kClearClipboardEnabled value:clearClipboardEnabled];
}

- (NSInteger)clearClipboardAfterSeconds {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger ret = [userDefaults integerForKey:kClearClipboardAfterSeconds];

    return ret == 0 ? kDefaultClearClipboardTimeout : ret;
}


- (void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setInteger:clearClipboardAfterSeconds forKey:kClearClipboardAfterSeconds];
    
    [userDefaults synchronize];
}

- (BOOL)doNotShowTotp {
    return [self getBool:kDoNotShowTotp];
}

- (void)setDoNotShowTotp:(BOOL)doNotShowTotp {
    [self setBool:kDoNotShowTotp value:doNotShowTotp];
}

- (BOOL)showRecycleBinInSearchResults {
    return [self getBool:kShowRecycleBinInSearchResults];
}

- (void)setShowRecycleBinInSearchResults:(BOOL)showRecycleBinInSearchResults {
    [self setBool:kShowRecycleBinInSearchResults value:showRecycleBinInSearchResults];
}

- (BOOL)doNotShowRecycleBinInBrowse {
    return [self getBool:kDoNotShowRecycleBinInBrowse];
}

- (void)setDoNotShowRecycleBinInBrowse:(BOOL)doNotShowRecycleBinInBrowse {
    [self setBool:kDoNotShowRecycleBinInBrowse value:doNotShowRecycleBinInBrowse];
}

@end
