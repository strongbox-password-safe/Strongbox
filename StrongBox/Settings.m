//
//  Settings.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"
#import "Reachability.h"

static NSString* kLaunchCountKey = @"launchCount";
static NSString* kAutoLockTimeSeconds = @"autoLockTimeSeconds";
static NSString* kPromptedForReview = @"promptedForReview";
static NSString* kIsProKey = @"isPro";
static NSString* kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* kPromptedForCopyPasswordGesture = @"promptedForCopyPasswordGesture";
static NSString* kCopyPasswordOnLongPress = @"copyPasswordOnLongPress";
static NSString* kShowPasswordByDefaultOnEditScreen = @"showPasswordByDefaultOnEditScreen";
static NSString* kIsHavePromptedAboutFreeTrial = @"isHavePromptedAboutFreeTrial";
static NSString* kTouchId911Count = @"kTouchId911Count";
static NSString* kNeverShowForMacAppMessage = @"neverShowForMacAppMessage";
static NSString* kiCloudOn = @"iCloudOn";
static NSString* kiCloudWasOn = @"iCloudWasOn";
static NSString* kiCloudPrompted = @"iCloudPrompted";
            
@interface Settings ()

@property (nonatomic, strong) Reachability *internetReachabilityDetector;
@property (nonatomic) BOOL offline; // Global Online/Offline variable

@end

@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    return sharedInstance;
}

- (void) startMonitoringConnectivitity {
    self.internetReachabilityDetector = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Internet is reachable
    
    __weak typeof(self) weakSelf = self;
    self.internetReachabilityDetector.reachableBlock = ^(Reachability *reach)
    {
        weakSelf.offline = NO;
    };
    
    // Internet is not reachable
    
    self.internetReachabilityDetector.unreachableBlock = ^(Reachability *reach)
    {
        weakSelf.offline = YES;
    };
    
    [self.internetReachabilityDetector startNotifier];
}

- (BOOL) isOffline {
    return self.offline;
}

- (BOOL)isShowPasswordByDefaultOnEditScreen {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
   
    return [userDefaults boolForKey:kShowPasswordByDefaultOnEditScreen];
}

- (void)setShowPasswordByDefaultOnEditScreen:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:kShowPasswordByDefaultOnEditScreen];
    
    [userDefaults synchronize];
}

- (BOOL)isProOrFreeTrial
{
    return [self isPro] || [self isFreeTrial];
}

- (void)setPro:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:kIsProKey];
    
    [userDefaults synchronize];
}

- (BOOL)isPro
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    return [userDefaults boolForKey:kIsProKey];
}

- (void)setHavePromptedAboutFreeTrial:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:kIsHavePromptedAboutFreeTrial];
    
    [userDefaults synchronize];
}

- (BOOL)isHavePromptedAboutFreeTrial {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
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
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setEndFreeTrialDate:(NSDate*)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:value forKey:kEndFreeTrialDate];

    NSLog(@"Set Free trial end date to %@", value);

    [userDefaults synchronize];
}

- (NSInteger)getFreeTrialDaysRemaining {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
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

- (NSInteger)getLaunchCount
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger launchCount = [userDefaults integerForKey:kLaunchCountKey];
    
    return launchCount;
}

- (void)resetLaunchCount {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults removeObjectForKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (void)incrementLaunchCount {
    NSInteger launchCount = [self getLaunchCount];
    
    launchCount++;
    
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (NSInteger)getTouchId911Count {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger count = [userDefaults integerForKey:kTouchId911Count];
    
    return count;
}

- (void)incrementTouchId911Count {
    NSInteger count = [self getTouchId911Count];
    
    count++;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:count forKey:kTouchId911Count];
    
    [userDefaults synchronize];
}

- (void)resetTouchId911Count {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults removeObjectForKey:kTouchId911Count];
    
    [userDefaults synchronize];
}

-(NSNumber*)getAutoLockTimeoutSeconds
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSNumber *seconds = [userDefaults objectForKey:kAutoLockTimeSeconds];

    if (!seconds) {
        seconds = @60;
    }
    
    return seconds;
}

-(void)setAutoLockTimeoutSeconds:(NSNumber*)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:value forKey:kAutoLockTimeSeconds];
    
    [userDefaults synchronize];
}

- (NSInteger)isUserHasBeenPromptedForReview {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
 
    return [userDefaults integerForKey:kPromptedForReview];
}

- (void)setUserHasBeenPromptedForReview:(NSInteger)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setInteger:value forKey:kPromptedForReview];

    [userDefaults synchronize];
}

- (BOOL)isHasPromptedForCopyPasswordGesture {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    return [userDefaults boolForKey:kPromptedForCopyPasswordGesture];
}

- (void)setHasPromptedForCopyPasswordGesture:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:kPromptedForCopyPasswordGesture];

    [userDefaults synchronize];
}

- (BOOL)isCopyPasswordOnLongPress {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    return [userDefaults boolForKey:kCopyPasswordOnLongPress];
}

- (void)setCopyPasswordOnLongPress:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:kCopyPasswordOnLongPress];
    
    [userDefaults synchronize];
}

- (void)setNeverShowForMacAppMessage:(BOOL)neverShowForMacAppMessage {
    [[NSUserDefaults standardUserDefaults] setBool:neverShowForMacAppMessage forKey:kNeverShowForMacAppMessage];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)neverShowForMacAppMessage {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kNeverShowForMacAppMessage];
}


- (BOOL)iCloudOn {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kiCloudOn];
}

- (void)setICloudOn:(BOOL)iCloudOn {
    [[NSUserDefaults standardUserDefaults] setBool:iCloudOn forKey:kiCloudOn];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)iCloudWasOn {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kiCloudWasOn];
}

-(void)setICloudWasOn:(BOOL)iCloudWasOn {
    [[NSUserDefaults standardUserDefaults] setBool:iCloudWasOn forKey:kiCloudWasOn];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)iCloudPrompted {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kiCloudPrompted];
}

- (void)setICloudPrompted:(BOOL)iCloudPrompted {
    [[NSUserDefaults standardUserDefaults] setBool:iCloudPrompted forKey:kiCloudPrompted];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d%d%d%d[%ld]%d%d[%ld][%@]%ld%d%d%d%d%d%d%d]",
    self.isOffline,
    self.isShowPasswordByDefaultOnEditScreen,
    self.isHavePromptedAboutFreeTrial,
    self.isProOrFreeTrial,
    (long)self.getTouchId911Count,
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

@end
