//
//  Settings.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"
#import <LocalAuthentication/LocalAuthentication.h>

static NSString* kLaunchCountKey = @"launchCount";
static NSString* kAutoLockTimeSeconds = @"autoLockTimeSeconds";
static NSString* kPromptedForReview = @"newPromptedForReview";
static NSString* kIsProKey = @"isPro";
static NSString* kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* kPromptedForCopyPasswordGesture = @"promptedForCopyPasswordGesture";
static NSString* kCopyPasswordOnLongPress = @"copyPasswordOnLongPress";
static NSString* kShowPasswordByDefaultOnEditScreen = @"showPasswordByDefaultOnEditScreen";
static NSString* kIsHavePromptedAboutFreeTrial = @"isHavePromptedAboutFreeTrial";
static NSString* kNeverShowForMacAppMessage = @"neverShowForMacAppMessage";
static NSString* kiCloudOn = @"iCloudOn";
static NSString* kiCloudWasOn = @"iCloudWasOn";
static NSString* kiCloudPrompted = @"iCloudPrompted";
static NSString* kSafesMigratedToNewSystem = @"safesMigratedToNewSystem";
static NSString* kPasswordGenerationParameters = @"passwordGenerationSettings";
static NSString* kInstallDate = @"installDate";
static NSString* kDisallowBiometricId = @"disallowBiometricId";
static NSString* kDoNotAutoAddNewLocalSafes = @"doNotAutoAddNewLocalSafes";
static NSString* kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* kUseQuickLaunchAsRootView = @"useQuickLaunchAsRootView";

@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    
    return sharedInstance;
}

static NSUserDefaults *getUserDefaults() {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupName];
    
    return defaults;
}

- (BOOL)isShowPasswordByDefaultOnEditScreen {
    NSUserDefaults *userDefaults = getUserDefaults();
   
    return [userDefaults boolForKey:kShowPasswordByDefaultOnEditScreen];
}

- (void)setShowPasswordByDefaultOnEditScreen:(BOOL)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setBool:value forKey:kShowPasswordByDefaultOnEditScreen];
    
    [userDefaults synchronize];
}

- (BOOL)isProOrFreeTrial
{
    return [self isPro] || [self isFreeTrial];
}

- (void)setPro:(BOOL)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setBool:value forKey:kIsProKey];
    
    [userDefaults synchronize];
}

- (BOOL)isPro
{
    NSUserDefaults *userDefaults = getUserDefaults();
    
    return [userDefaults boolForKey:kIsProKey];
}

- (void)setHavePromptedAboutFreeTrial:(BOOL)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setBool:value forKey:kIsHavePromptedAboutFreeTrial];
    
    [userDefaults synchronize];
}

- (BOOL)isHavePromptedAboutFreeTrial {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    return [userDefaults boolForKey:kIsHavePromptedAboutFreeTrial];
}

- (BOOL)isFreeTrial
{
    NSDate* date = [self getEndFreeTrialDate];
    
    if(date == nil) {
        //NSLog(@"No Free Trial date set yet. Not in free trial.");
        return NO;
    }
    
    BOOL freeTrial = !([date timeIntervalSinceNow] < 0);
    
    //NSLog(@"Free trial: %d Date: %@", freeTrial, date);
    
    return freeTrial;
}

- (NSDate*)getEndFreeTrialDate {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setEndFreeTrialDate:(NSDate*)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setObject:value forKey:kEndFreeTrialDate];

    NSLog(@"Set Free trial end date to %@", value);

    [userDefaults synchronize];
}

- (NSInteger)getFreeTrialDaysRemaining {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    NSDate* date = [userDefaults objectForKey:kEndFreeTrialDate];
    
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

- (NSDate*)installDate {
    return [getUserDefaults() objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setObject:installDate forKey:kInstallDate];
    [userDefaults synchronize];
}

- (void)clearInstallDate {
    NSUserDefaults *userDefaults = getUserDefaults();
    
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
    NSUserDefaults *userDefaults = getUserDefaults();
    
    NSInteger launchCount = [userDefaults integerForKey:kLaunchCountKey];
    
    return launchCount;
}

- (void)resetLaunchCount {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults removeObjectForKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (void)incrementLaunchCount {
    NSInteger launchCount = [self getLaunchCount];
    
    launchCount++;
    
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    
    NSUserDefaults *userDefaults = getUserDefaults();
    [userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

-(NSNumber*)getAutoLockTimeoutSeconds
{
    NSUserDefaults *userDefaults = getUserDefaults();

    NSNumber *seconds = [userDefaults objectForKey:kAutoLockTimeSeconds];

    if (seconds == nil) {
        seconds = @60;
    }
    
    return seconds;
}

-(void)setAutoLockTimeoutSeconds:(NSNumber*)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setObject:value forKey:kAutoLockTimeSeconds];
    
    [userDefaults synchronize];
}

- (NSInteger)isUserHasBeenPromptedForReview {
    NSUserDefaults *userDefaults = getUserDefaults();
 
    return [userDefaults integerForKey:kPromptedForReview];
}

- (void)setUserHasBeenPromptedForReview:(NSInteger)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setInteger:value forKey:kPromptedForReview];

    [userDefaults synchronize];
}

- (BOOL)isHasPromptedForCopyPasswordGesture {
    NSUserDefaults *userDefaults = getUserDefaults();

    return [userDefaults boolForKey:kPromptedForCopyPasswordGesture];
}

- (void)setHasPromptedForCopyPasswordGesture:(BOOL)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setBool:value forKey:kPromptedForCopyPasswordGesture];

    [userDefaults synchronize];
}

- (BOOL)isCopyPasswordOnLongPress {
    NSUserDefaults *userDefaults = getUserDefaults();

    return [userDefaults boolForKey:kCopyPasswordOnLongPress];
}

- (void)setCopyPasswordOnLongPress:(BOOL)value {
    NSUserDefaults *userDefaults = getUserDefaults();
    
    [userDefaults setBool:value forKey:kCopyPasswordOnLongPress];
    
    [userDefaults synchronize];
}

- (void)setNeverShowForMacAppMessage:(BOOL)neverShowForMacAppMessage {
    [getUserDefaults() setBool:neverShowForMacAppMessage forKey:kNeverShowForMacAppMessage];
    
    [getUserDefaults() synchronize];
}

- (BOOL)neverShowForMacAppMessage {
    return [getUserDefaults() boolForKey:kNeverShowForMacAppMessage];
}


- (BOOL)iCloudOn {
    return [getUserDefaults() boolForKey:kiCloudOn];
}

- (void)setICloudOn:(BOOL)iCloudOn {
    [getUserDefaults() setBool:iCloudOn forKey:kiCloudOn];
    [getUserDefaults() synchronize];
}

- (BOOL)iCloudWasOn {
    return [getUserDefaults() boolForKey:kiCloudWasOn];
}

-(void)setICloudWasOn:(BOOL)iCloudWasOn {
    [getUserDefaults() setBool:iCloudWasOn forKey:kiCloudWasOn];
    [getUserDefaults() synchronize];
}

- (BOOL)iCloudPrompted {
    return [getUserDefaults() boolForKey:kiCloudPrompted];
}

- (void)setICloudPrompted:(BOOL)iCloudPrompted {
    [getUserDefaults() setBool:iCloudPrompted forKey:kiCloudPrompted];
    [getUserDefaults() synchronize];
}

- (PasswordGenerationParameters *)passwordGenerationParameters {
    NSUserDefaults *defaults = getUserDefaults();
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationParameters];
    
    if(encodedObject == nil) {
        return [[PasswordGenerationParameters alloc] initWithDefaults];
    }
    
    PasswordGenerationParameters *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return object;
}

-(void)setPasswordGenerationParameters:(PasswordGenerationParameters *)passwordGenerationParameters {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationParameters];
    NSUserDefaults *defaults = getUserDefaults();
    [defaults setObject:encodedObject forKey:kPasswordGenerationParameters];
    [defaults synchronize];
}

- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d%d%d%d%d[%ld][%@]%ld%d%d%d%d%d%d%d]",
    self.isShowPasswordByDefaultOnEditScreen,
    self.isHavePromptedAboutFreeTrial,
    self.isProOrFreeTrial,
    self.isPro,
    self.isFreeTrial,
    (long)self.getLaunchCount,
    self.getAutoLockTimeoutSeconds,
    (long)self.isUserHasBeenPromptedForReview,
    self.isHasPromptedForCopyPasswordGesture,
    self.isCopyPasswordOnLongPress,
    self.neverShowForMacAppMessage,
    self.iCloudOn,
    self.iCloudWasOn,
    self.iCloudPrompted,
    self.iCloudAvailable];
}

- (NSString*)getBiometricIdName {
    NSString* biometricIdName = @"Touch ID";
    
    if (@available(iOS 11.0, *)) {
        NSError* error;
        LAContext *localAuthContext = [[LAContext alloc] init];
        
        if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
            if (localAuthContext.biometryType == LABiometryTypeFaceID ) {
                biometricIdName = @"Face ID";
            }
        }
    }
    
    return biometricIdName;
}

- (BOOL)safesMigratedToNewSystem {
    return [getUserDefaults() boolForKey:kSafesMigratedToNewSystem];
}

- (void)setSafesMigratedToNewSystem:(BOOL)safesMigratedToNewSystem {
    [getUserDefaults() setBool:safesMigratedToNewSystem forKey:kSafesMigratedToNewSystem];
    [getUserDefaults() synchronize];
}

- (BOOL)disallowAllBiometricId {
    return [getUserDefaults() boolForKey:kDisallowBiometricId];
}

- (void)setDisallowAllBiometricId:(BOOL)disallowAllBiometricId {
    [getUserDefaults() setBool:disallowAllBiometricId forKey:kDisallowBiometricId];
    [getUserDefaults() synchronize];
}

- (BOOL)doNotAutoAddNewLocalSafes {
    return [getUserDefaults() boolForKey:kDoNotAutoAddNewLocalSafes];
}

- (void)setDoNotAutoAddNewLocalSafes:(BOOL)doNotAutoAddNewLocalSafes {
    [getUserDefaults() setBool:doNotAutoAddNewLocalSafes forKey:kDoNotAutoAddNewLocalSafes];
    [getUserDefaults() synchronize];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [getUserDefaults() objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [getUserDefaults() setObject:encoded forKey:kAutoFillNewRecordSettings];
    [getUserDefaults() synchronize];
}

- (BOOL)useQuickLaunchAsRootView {
    return [getUserDefaults() boolForKey:kUseQuickLaunchAsRootView];
}

- (void)setUseQuickLaunchAsRootView:(BOOL)useQuickLaunchAsRootView {
    [getUserDefaults() setBool:useQuickLaunchAsRootView forKey:kUseQuickLaunchAsRootView];
    [getUserDefaults() synchronize];
}

@end
