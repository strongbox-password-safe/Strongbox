//
//  Settings.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "SharedAppAndAutoFillSettings.h"

static NSString* const kLaunchCountKey = @"launchCount";

static NSString* const kiCloudWasOn = @"iCloudWasOn";
static NSString* const kiCloudPrompted = @"iCloudPrompted";

static NSString* const kInstallDate = @"installDate";
static NSString* const kShowKeePassCreateSafeOptions = @"showKeePassCreateSafeOptions";

static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails";
static NSString* const kDeleteDataAfterFailedUnlockCount = @"deleteDataAfterFailedUnlockCount";
static NSString* const kFailedUnlockAttempts = @"failedUnlockAttempts";
static NSString* const kAppLockAppliesToPreferences = @"appLockAppliesToPreferences";

static NSString* const kAppLockMode = @"appLockMode2.0";
static NSString* const kAppLockPin = @"appLockPin2.0";
static NSString* const kAppLockDelay = @"appLockDelay2.0";

static NSString* const kLastFreeTrialNudge = @"lastFreeTrialNudge";

// TODO: Don't use shared settings for these...

@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    
    return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString*)getString:(NSString*)key {
    return [self getString:key fallback:nil];
}

- (NSString*)getString:(NSString*)key fallback:(NSString*)fallback {
    NSString* obj = [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setObject:value forKey:key];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setBool:value forKey:key];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSInteger)getInteger:(NSString*)key {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults integerForKey:key];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setInteger:value forKey:key];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDate *)lastFreeTrialNudge {
    NSDate* date = [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults objectForKey:kLastFreeTrialNudge];
    return date ? date : NSDate.date; // App Install will count as first nudge in a technical sense
}

- (void)setLastFreeTrialNudge:(NSDate *)lastFreeTrialNudge {
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    [userDefaults setObject:lastFreeTrialNudge forKey:kLastFreeTrialNudge];
    [userDefaults synchronize];
}

- (NSDate*)installDate {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:installDate forKey:kInstallDate];
    [userDefaults synchronize];
}

- (void)clearInstallDate {
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults removeObjectForKey:kInstallDate];
    [userDefaults synchronize];
}

- (NSInteger)daysInstalled
{
    NSDate* installDate = Settings.sharedInstance.installDate;

    if(!installDate) {
        return 0;
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                fromDate:installDate
                                                  toDate:[NSDate date]
                                                 options:0];

    NSInteger daysInstalled = [components day];
    
    return daysInstalled;
}

- (NSInteger)getLaunchCount
{
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    
    NSInteger launchCount = [userDefaults integerForKey:kLaunchCountKey];
    
    return launchCount;
}

- (void)resetLaunchCount {
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults removeObjectForKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (void)incrementLaunchCount {
    NSInteger launchCount = [self getLaunchCount];
    
    launchCount++;
    
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    [userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (BOOL)iCloudWasOn {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults boolForKey:kiCloudWasOn];
}

-(void)setICloudWasOn:(BOOL)iCloudWasOn {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setBool:iCloudWasOn forKey:kiCloudWasOn];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (BOOL)iCloudPrompted {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults boolForKey:kiCloudPrompted];
}

- (void)setICloudPrompted:(BOOL)iCloudPrompted {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setBool:iCloudPrompted forKey:kiCloudPrompted];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

//

- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d[%ld]%d%d%d[%ld]%d%d%d%d]",
            SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial,
            (long)SharedAppAndAutoFillSettings.sharedInstance.freeTrialDaysLeft,
            SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial,
            SharedAppAndAutoFillSettings.sharedInstance.isPro,
            SharedAppAndAutoFillSettings.sharedInstance.isFreeTrial,
            (long)self.getLaunchCount,
            SharedAppAndAutoFillSettings.sharedInstance.iCloudOn,
            self.iCloudWasOn,
            self.iCloudPrompted,
            self.iCloudAvailable];
}

- (BOOL)showKeePassCreateSafeOptions {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults boolForKey:kShowKeePassCreateSafeOptions];
}

- (void)setShowKeePassCreateSafeOptions:(BOOL)showKeePassCreateSafeOptions {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setBool:showKeePassCreateSafeOptions forKey:kShowKeePassCreateSafeOptions];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kLastEntitlementCheckAttempt];
}

- (void)setLastEntitlementCheckAttempt:(NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults;
    
    [userDefaults setObject:lastEntitlementCheckAttempt forKey:kLastEntitlementCheckAttempt];
    
    [userDefaults synchronize];
}

- (NSUInteger)numberOfEntitlementCheckFails {
    NSInteger ret =  [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults integerForKey:kNumberOfEntitlementCheckFails];
    return ret;
}


- (void)setNumberOfEntitlementCheckFails:(NSUInteger)numberOfEntitlementCheckFails {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setInteger:numberOfEntitlementCheckFails forKey:kNumberOfEntitlementCheckFails];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (AppLockMode)appLockMode {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults integerForKey:kAppLockMode];
}

- (void)setAppLockMode:(AppLockMode)appLockMode {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setInteger:appLockMode forKey:kAppLockMode];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSString *)appLockPin {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults objectForKey:kAppLockPin];
}

-(void)setAppLockPin:(NSString *)appLockPin {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setObject:appLockPin forKey:kAppLockPin];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSInteger)appLockDelay {
    NSInteger ret =  [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults integerForKey:kAppLockDelay];
    return ret;
}

-(void)setAppLockDelay:(NSInteger)appLockDelay {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setInteger:appLockDelay forKey:kAppLockDelay];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSInteger)deleteDataAfterFailedUnlockCount {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults integerForKey:kDeleteDataAfterFailedUnlockCount];
}

- (void)setDeleteDataAfterFailedUnlockCount:(NSInteger)deleteDataAfterFailedUnlockCount {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setInteger:deleteDataAfterFailedUnlockCount forKey:kDeleteDataAfterFailedUnlockCount];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (NSUInteger)failedUnlockAttempts {
    return [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults integerForKey:kFailedUnlockAttempts];
}

- (void)setFailedUnlockAttempts:(NSUInteger)failedUnlockAttempts {
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults setInteger:failedUnlockAttempts forKey:kFailedUnlockAttempts];
    [SharedAppAndAutoFillSettings.sharedInstance.sharedAppGroupDefaults synchronize];
}

- (BOOL)appLockAppliesToPreferences {
    return [self getBool:kAppLockAppliesToPreferences];
}

- (void)setAppLockAppliesToPreferences:(BOOL)appLockAppliesToPreferences {
    [self setBool:kAppLockAppliesToPreferences value:appLockAppliesToPreferences];
}

// Initial Implementation of Provision Profile Extraction (To try automatically determine app group id initially)

+ (NSString*)getAppGroupFromProvisioningProfile {
    NSString* profilePath = [NSBundle.mainBundle pathForResource:@"embedded" ofType:@"mobileprovision"];
    
    if (profilePath == nil) {
        NSLog(@"INFO: getAppGroupFromProvisioningProfile - Could not find embedded.mobileprovision file");
        return nil;
    }
    
    NSData* plistData = [NSData dataWithContentsOfFile:profilePath];
    if(!plistData) {
        NSLog(@"Error: getAppGroupFromProvisioningProfile - dataWithContentsOfFile nil");
        return nil;
    }
    
    NSString* plistDataString = [NSString stringWithFormat:@"%@", plistData];
    if(plistDataString == nil) {
        NSLog(@"Error: getAppGroupFromProvisioningProfile - plistData - stringWithFormat nil");
        return nil;
    }
    
    NSString* plistString = [self extractPlist:plistDataString];
    if(!plistString) {
        NSLog(@"Error: getAppGroupFromProvisioningProfile - extractPlist nil");
        return nil;
    }
    
    NSError* error;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"<key>com.apple.security.application-groups</key>.*?<array>.*?<string>(.*?)</string>.*?</array>" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                             error:&error];
    
    if(error || regex == nil) {
        NSLog(@"Error: getAppGroupFromProvisioningProfile - regularExpressionWithPattern %@", error);
        return nil;
    }
    
    NSTextCheckingResult* res = [regex firstMatchInString:plistString options:kNilOptions range:NSMakeRange(0, plistString.length)];
    
    if(res && [res numberOfRanges] > 1) {
        NSRange rng = [res rangeAtIndex:1];
        NSString* appGroup = [plistString substringWithRange:rng];
        return appGroup;
    }
    else {
        NSLog(@"INFO: getAppGroupFromProvisioningProfile - App Group Not Found - [%@]", res);
        return nil;
    }
}

+ (NSString*)extractPlist:(NSString*)str {
    // Remove brackets at beginning and end
    if(!str || str.length < 10) { // Some kind of sensible minimum
        return nil;
    }
    
    str = [str substringWithRange:NSMakeRange(1, str.length-2)];
    str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // convert hex to ascii
    
    NSString* profileText = [self hexStringtoAscii:str];
    return profileText;
}

+ (NSString*)hexStringtoAscii:(NSString*)hexString {
    NSString* pattern = @"(0x)?([0-9a-f]{2})";
    NSError* error;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    
    if(error) {
        NSLog(@"hexStringToAscii Error: %@", error);
        return nil;
    }
    
    NSArray<NSTextCheckingResult*>* matches = [regex matchesInString:hexString options:kNilOptions range:NSMakeRange(0, hexString.length)];
    if(!matches) {
        NSLog(@"hexStringToAscii Error: Matches nil");
        return nil;
    }
    
    NSArray<NSNumber*> *characters = [matches map:^id _Nonnull(NSTextCheckingResult * _Nonnull obj, NSUInteger idx) {
        if(obj.numberOfRanges > 1) {
            NSRange range = [obj rangeAtIndex:2];
            NSString *sub = [hexString substringWithRange:range];
            //NSLog(@"Match: %@", sub);
            
            NSScanner *scanner = [NSScanner scannerWithString:sub];
            uint32_t u32;
            [scanner scanHexInt:&u32];
            return @(u32);
        }
        else {
            NSLog(@"Do not know how to decode.");
            return @(32); // Space ASCII
        }
    }];
    
    NSMutableString* foo = [NSMutableString string];
    for (NSNumber* ch in characters) {
        [foo appendFormat:@"%c", ch.unsignedCharValue];
    }
    
    return foo.copy;
}

@end
