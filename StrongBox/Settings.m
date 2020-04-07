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

static const NSInteger kDefaultClearClipboardTimeout = 90;

static NSString* const kLaunchCountKey = @"launchCount";

static NSString* const kIsProKey = @"isPro";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";

static NSString* const kiCloudOn = @"iCloudOn";
static NSString* const kiCloudWasOn = @"iCloudWasOn";
static NSString* const kiCloudPrompted = @"iCloudPrompted";

static NSString* const kInstallDate = @"installDate";
static NSString* const kDisallowBiometricId = @"disallowBiometricId";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kShowKeePassCreateSafeOptions = @"showKeePassCreateSafeOptions";
static NSString* const kHasShownAutoFillLaunchWelcome = @"hasShownAutoFillLaunchWelcome";

static NSString* const kHideTips = @"hideTips";
static NSString* const kDisallowAllPinCodeOpens = @"disallowAllPinCodeOpens";

static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";

static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails";
static NSString* const kInstantPinUnlocking = @"instantPinUnlocking";
static NSString* const kHaveWarnedAboutAutoFillCrash = @"haveWarnedAboutAutoFillCrash";
static NSString* const kDeleteDataAfterFailedUnlockCount = @"deleteDataAfterFailedUnlockCount";
static NSString* const kFailedUnlockAttempts = @"failedUnlockAttempts";
static NSString* const kAppLockAppliesToPreferences = @"appLockAppliesToPreferences";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kShowAllFilesInLocalKeyFiles = @"showAllFilesInLocalKeyFiles";
static NSString* const kHideKeyFileOnUnlock = @"hideKeyFileOnUnlock";

static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";

static NSString* const kAppLockMode = @"appLockMode2.0";
static NSString* const kAppLockPin = @"appLockPin2.0";
static NSString* const kAppLockDelay = @"appLockDelay2.0";

NSString* const kProStatusChangedNotificationKey = @"proStatusChangedNotification";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";
NSString* const kDatabaseViewPreferencesChangedNotificationKey = @"kDatabaseViewPreferencesChangedNotificationKey";

static NSString* const kDefaultAppGroupName = @"group.strongbox.mcguill";

static NSString* cachedAppGroupName;

static NSString* const kShowYubikeySecretWorkaroundField = @"showYubikeySecretWorkaroundField";
static NSString* const kQuickLaunchUuid = @"quickLaunchUuid";

static NSString* const kShowDatabaseIcon = @"showDatabaseIcon";
static NSString* const kShowDatabaseStatusIcon = @"showDatabaseStatusIcon";
static NSString* const kDatabaseCellTopSubtitle = @"databaseCellTopSubtitle";
static NSString* const kDatabaseCellSubtitle1 = @"databaseCellSubtitle1";
static NSString* const kDatabaseCellSubtitle2 = @"databaseCellSubtitle2";
static NSString* const kShowDatabasesSeparator = @"showDatabasesSeparator";
static NSString* const kMonitorInternetConnectivity = @"monitorInternetConnectivity";
static NSString* const kHasDoneProFamilyCheck = @"hasDoneProFamilyCheck";
static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kClipboardHandoff = @"clipboardHandoff";

static NSString* const kAutoFillExitedCleanly = @"autoFillExitedCleanly";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";

@implementation Settings

+ (void)initialize {
    if(self == [Settings class]) {
        // NSString* appGroupPP = [Settings getAppGroupFromProvisioningProfile];
        // cachedAppGroupName = appGroupPP ? appGroupPP : kDefaultAppGroupName;
        //NSLog(@"App Group Name: [%@] (Auto Detected : [%@])", cachedAppGroupName, appGroupPP);

        cachedAppGroupName = kDefaultAppGroupName;
    }
}

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    
    return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)appGroupName {
    return cachedAppGroupName;
}

- (NSUserDefaults*)getSharedAppGroupDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
    
    if(defaults == nil) {
        NSLog(@"ERROR: Could not get NSUserDefaults for Suite Name: [%@]", self.appGroupName);
    }
    
    return defaults;
}

- (NSString*)getString:(NSString*)key {
    return [self getString:key fallback:nil];
}

- (NSString*)getString:(NSString*)key fallback:(NSString*)fallback {
    NSString* obj = [[self getSharedAppGroupDefaults] objectForKey:key];
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [[self getSharedAppGroupDefaults] setObject:value forKey:key];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [[self getSharedAppGroupDefaults] objectForKey:key];
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [[self getSharedAppGroupDefaults] setBool:value forKey:key];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (NSInteger)getInteger:(NSString*)key {
    return [[self getSharedAppGroupDefaults] integerForKey:key];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [[self getSharedAppGroupDefaults] objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [[self getSharedAppGroupDefaults] setInteger:value forKey:key];
    [[self getSharedAppGroupDefaults] synchronize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)mfiYubiKeyEnabled {
    return YES;
}

- (BOOL)colorizeUseColorBlindPalette {
    return [self getBool:kColorizeUseColorBlindPalette];
}

- (void)setColorizeUseColorBlindPalette:(BOOL)colorizeUseColorBlindPalette {
    [self setBool:kColorizeUseColorBlindPalette value:colorizeUseColorBlindPalette];
}

- (BOOL)autoFillExitedCleanly {
    return [self getBool:kAutoFillExitedCleanly fallback:YES];
}

- (void)setAutoFillExitedCleanly:(BOOL)autoFillExitedCleanly {
    return [self setBool:kAutoFillExitedCleanly value:autoFillExitedCleanly];
}

- (BOOL)clipboardHandoff {
    return [self getBool:kClipboardHandoff];
}

- (void)setClipboardHandoff:(BOOL)clipboardHandoff {
    return [self setBool:kClipboardHandoff value:clipboardHandoff];
}

- (FavIconDownloadOptions *)favIconDownloadOptions {
    NSUserDefaults *defaults = [self getSharedAppGroupDefaults];
    NSData *encodedObject = [defaults objectForKey:kFavIconDownloadOptions];

    if(encodedObject == nil) {
        return FavIconDownloadOptions.defaults;
    }

    FavIconDownloadOptions *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setFavIconDownloadOptions:(FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:favIconDownloadOptions];
    NSUserDefaults *defaults = [self getSharedAppGroupDefaults];
    [defaults setObject:encodedObject forKey:kFavIconDownloadOptions];
    [defaults synchronize];
}

- (BOOL)hasDoneProFamilyCheck {
    return [self getBool:kHasDoneProFamilyCheck];
}

- (void)setHasDoneProFamilyCheck:(BOOL)hasDoneProFamilyCheck {
    [self setBool:kHasDoneProFamilyCheck value:hasDoneProFamilyCheck];
}

- (BOOL)monitorInternetConnectivity {
    return [self getBool:kMonitorInternetConnectivity fallback:YES];
}

- (void)setMonitorInternetConnectivity:(BOOL)monitorInternetConnectivity {
    [self setBool:kMonitorInternetConnectivity value:monitorInternetConnectivity];
}

- (BOOL)showDatabasesSeparator {
    return [self getBool:kShowDatabasesSeparator];
}

- (void)setShowDatabasesSeparator:(BOOL)showDatabasesSeparator {
    [self setBool:kShowDatabasesSeparator value:showDatabasesSeparator];
}

- (BOOL)showDatabaseIcon {
    return [self getBool:kShowDatabaseIcon fallback:YES];
}

- (void)setShowDatabaseIcon:(BOOL)showDatabaseIcon {
    [self setBool:kShowDatabaseIcon value:showDatabaseIcon];
}

- (BOOL)showDatabaseStatusIcon {
    return [self getBool:kShowDatabaseStatusIcon fallback:YES];
}

- (void)setShowDatabaseStatusIcon:(BOOL)showDatabaseStatusIcon {
    [self setBool:kShowDatabaseStatusIcon value:showDatabaseStatusIcon];
}

- (DatabaseCellSubtitleField)databaseCellTopSubtitle {
    return[self getInteger:kDatabaseCellTopSubtitle fallback:kDatabaseCellSubtitleFieldNone];
}

- (void)setDatabaseCellTopSubtitle:(DatabaseCellSubtitleField)databaseCellTopSubtitle {
    [self setInteger:kDatabaseCellTopSubtitle value:databaseCellTopSubtitle];
}

- (DatabaseCellSubtitleField)databaseCellSubtitle1 {
    return[self getInteger:kDatabaseCellSubtitle1 fallback:kDatabaseCellSubtitleFieldStorage];
}

- (void)setDatabaseCellSubtitle1:(DatabaseCellSubtitleField)databaseCellSubtitle1 {
    [self setInteger:kDatabaseCellSubtitle1 value:databaseCellSubtitle1];
}

- (DatabaseCellSubtitleField)databaseCellSubtitle2 {
    return[self getInteger:kDatabaseCellSubtitle2 fallback:kDatabaseCellSubtitleFieldNone];
}

- (void)setDatabaseCellSubtitle2:(DatabaseCellSubtitleField)databaseCellSubtitle2 {
    [self setInteger:kDatabaseCellSubtitle2 value:databaseCellSubtitle2];
}

- (NSString *)quickLaunchUuid {
    return [self getString:kQuickLaunchUuid];
}

- (void)setQuickLaunchUuid:(NSString *)quickLaunchUuid {
    [self setString:kQuickLaunchUuid value:quickLaunchUuid];
}

- (BOOL)showYubikeySecretWorkaroundField {
    return [self getBool:kShowYubikeySecretWorkaroundField];
}

- (void)setShowYubikeySecretWorkaroundField:(BOOL)showYubikeySecretWorkaroundField {
    [self setBool:kShowYubikeySecretWorkaroundField value:showYubikeySecretWorkaroundField];
}

- (PasswordGenerationConfig *)passwordGenerationConfig {
    NSUserDefaults *defaults = [self getSharedAppGroupDefaults];
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return [PasswordGenerationConfig defaults];
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setPasswordGenerationConfig:(PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationConfig];
    NSUserDefaults *defaults = [self getSharedAppGroupDefaults];
    [defaults setObject:encodedObject forKey:kPasswordGenerationConfig];
    [defaults synchronize];
}

- (BOOL)isProOrFreeTrial
{
    return [self isPro] || [self isFreeTrial];
}

- (void)setPro:(BOOL)value {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    [userDefaults setBool:value forKey:kIsProKey];
    
    [userDefaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotificationKey object:nil];
}

- (BOOL)isPro
{
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    return [userDefaults boolForKey:kIsProKey];
}

- (BOOL)hasOptedInToFreeTrial {
    return self.freeTrialEnd != nil;
}

- (BOOL)isFreeTrial {
    NSDate* date = self.freeTrialEnd;
    
    if(date == nil) {
        NSLog(@"No Free Trial date set yet. Not in free trial. User has not opted in to Free Trial.");
        return NO;
    }
    
    BOOL freeTrial = !([date timeIntervalSinceNow] < 0);
    
    NSLog(@"Free trial: %d Date: %@ - days remaining = [%ld]", freeTrial, date, (long)self.freeTrialDaysLeft);
    
    return freeTrial;
}

- (NSDate*)calculateFreeTrialEndDateFromDate:(NSDate*)from {
    NSCalendar *cal = [NSCalendar currentCalendar];

    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:90 toDate:from options:0];
    
    return date;
}

- (NSInteger)freeTrialDaysLeft {
    NSDate* date = self.freeTrialEnd;
    
    if(date == nil) {
        return -1;
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                fromDate:[NSDate date]
                                                  toDate:date
                                                 options:0];
    
    NSInteger days = [components day];
    
    return days + 1;
}

- (NSDate *)freeTrialEnd {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setFreeTrialEnd:(NSDate *)freeTrialEnd {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    [userDefaults setObject:freeTrialEnd forKey:kEndFreeTrialDate];

    NSLog(@"Set Free trial end date to %@", freeTrialEnd);

    [userDefaults synchronize];
}

- (NSDate*)installDate {
    return [[self getSharedAppGroupDefaults] objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    [userDefaults setObject:installDate forKey:kInstallDate];
    [userDefaults synchronize];
}

- (void)clearInstallDate {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
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
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    NSInteger launchCount = [userDefaults integerForKey:kLaunchCountKey];
    
    return launchCount;
}

- (void)resetLaunchCount {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    [userDefaults removeObjectForKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (void)incrementLaunchCount {
    NSInteger launchCount = [self getLaunchCount];
    
    launchCount++;
    
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    [userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (BOOL)iCloudOn {
    return [[self getSharedAppGroupDefaults] boolForKey:kiCloudOn];
}

- (void)setICloudOn:(BOOL)iCloudOn {
    [[self getSharedAppGroupDefaults] setBool:iCloudOn forKey:kiCloudOn];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)iCloudWasOn {
    return [[self getSharedAppGroupDefaults] boolForKey:kiCloudWasOn];
}

-(void)setICloudWasOn:(BOOL)iCloudWasOn {
    [[self getSharedAppGroupDefaults] setBool:iCloudWasOn forKey:kiCloudWasOn];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)iCloudPrompted {
    return [[self getSharedAppGroupDefaults] boolForKey:kiCloudPrompted];
}

- (void)setICloudPrompted:(BOOL)iCloudPrompted {
    [[self getSharedAppGroupDefaults] setBool:iCloudPrompted forKey:kiCloudPrompted];
    [[self getSharedAppGroupDefaults] synchronize];
}

//

- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d[%ld]%d%d%d[%ld]%d%d%d%d]",
            self.hasOptedInToFreeTrial,
            (long)self.freeTrialDaysLeft,
            self.isProOrFreeTrial,
            self.isPro,
            self.isFreeTrial,
            (long)self.getLaunchCount,
            self.iCloudOn,
            self.iCloudWasOn,
            self.iCloudPrompted,
            self.iCloudAvailable];
}

- (BOOL)disallowAllBiometricId {
    return [[self getSharedAppGroupDefaults] boolForKey:kDisallowBiometricId];
}

- (void)setDisallowAllBiometricId:(BOOL)disallowAllBiometricId {
    [[self getSharedAppGroupDefaults] setBool:disallowAllBiometricId forKey:kDisallowBiometricId];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [[self getSharedAppGroupDefaults] objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [[self getSharedAppGroupDefaults] setObject:encoded forKey:kAutoFillNewRecordSettings];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)showKeePassCreateSafeOptions {
    return [[self getSharedAppGroupDefaults] boolForKey:kShowKeePassCreateSafeOptions];
}

- (void)setShowKeePassCreateSafeOptions:(BOOL)showKeePassCreateSafeOptions {
    [[self getSharedAppGroupDefaults] setBool:showKeePassCreateSafeOptions forKey:kShowKeePassCreateSafeOptions];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)hasShownAutoFillLaunchWelcome {
    return [[self getSharedAppGroupDefaults] boolForKey:kHasShownAutoFillLaunchWelcome];
}

- (void)setHasShownAutoFillLaunchWelcome:(BOOL)hasShownAutoFillLaunchWelcome {
    [[self getSharedAppGroupDefaults] setBool:hasShownAutoFillLaunchWelcome forKey:kHasShownAutoFillLaunchWelcome];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)hideTips {
    return [[self getSharedAppGroupDefaults] boolForKey:kHideTips];
}

- (void)setHideTips:(BOOL)hideTips {
    [[self getSharedAppGroupDefaults] setBool:hideTips forKey:kHideTips];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)disallowAllPinCodeOpens {
    return [[self getSharedAppGroupDefaults] boolForKey:kDisallowAllPinCodeOpens];
}

- (void)setDisallowAllPinCodeOpens:(BOOL)disallowAllPinCodeOpens {
    [[self getSharedAppGroupDefaults] setBool:disallowAllPinCodeOpens forKey:kDisallowAllPinCodeOpens];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)clearClipboardEnabled {
    return [self getBool:kClearClipboardEnabled fallback:YES];
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [self setBool:kClearClipboardEnabled value:clearClipboardEnabled];
}

- (NSInteger)clearClipboardAfterSeconds {
    NSInteger ret = [self getInteger:kClearClipboardAfterSeconds fallback:kDefaultClearClipboardTimeout];

    if(ret <= 0) { // This seems to have occurred somehow on some devices :(
        [self setClearClipboardAfterSeconds:kDefaultClearClipboardTimeout];
        return kDefaultClearClipboardTimeout;
    }
    
    return ret;
}

-(void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    return [self setInteger:kClearClipboardAfterSeconds value:clearClipboardAfterSeconds];
}

- (NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kLastEntitlementCheckAttempt];
}

- (void)setLastEntitlementCheckAttempt:(NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = [self getSharedAppGroupDefaults];
    
    [userDefaults setObject:lastEntitlementCheckAttempt forKey:kLastEntitlementCheckAttempt];
    
    [userDefaults synchronize];
}

- (NSUInteger)numberOfEntitlementCheckFails {
    NSInteger ret =  [[self getSharedAppGroupDefaults] integerForKey:kNumberOfEntitlementCheckFails];
    return ret;
}


- (void)setNumberOfEntitlementCheckFails:(NSUInteger)numberOfEntitlementCheckFails {
    [[self getSharedAppGroupDefaults] setInteger:numberOfEntitlementCheckFails forKey:kNumberOfEntitlementCheckFails];
    [[self getSharedAppGroupDefaults] synchronize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)instantPinUnlocking {
    return [self getBool:kInstantPinUnlocking fallback:YES];
}

- (void)setInstantPinUnlocking:(BOOL)instantPinUnlocking {
    [self setBool:kInstantPinUnlocking value:instantPinUnlocking];
}

- (BOOL)haveWarnedAboutAutoFillCrash {
    return [self getBool:kHaveWarnedAboutAutoFillCrash];
}

- (void)setHaveWarnedAboutAutoFillCrash:(BOOL)haveWarnedAboutAutoFillCrash {
    [self setBool:kHaveWarnedAboutAutoFillCrash value:haveWarnedAboutAutoFillCrash];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (AppLockMode)appLockMode {
    return [[self getSharedAppGroupDefaults] integerForKey:kAppLockMode];
}

- (void)setAppLockMode:(AppLockMode)appLockMode {
    [[self getSharedAppGroupDefaults] setInteger:appLockMode forKey:kAppLockMode];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (NSString *)appLockPin {
    return [[self getSharedAppGroupDefaults] objectForKey:kAppLockPin];
}

-(void)setAppLockPin:(NSString *)appLockPin {
    [[self getSharedAppGroupDefaults] setObject:appLockPin forKey:kAppLockPin];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (NSInteger)appLockDelay {
    NSInteger ret =  [[self getSharedAppGroupDefaults] integerForKey:kAppLockDelay];
    return ret;
}

-(void)setAppLockDelay:(NSInteger)appLockDelay {
    [[self getSharedAppGroupDefaults] setInteger:appLockDelay forKey:kAppLockDelay];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (NSInteger)deleteDataAfterFailedUnlockCount {
    return [[self getSharedAppGroupDefaults] integerForKey:kDeleteDataAfterFailedUnlockCount];
}

- (void)setDeleteDataAfterFailedUnlockCount:(NSInteger)deleteDataAfterFailedUnlockCount {
    [[self getSharedAppGroupDefaults] setInteger:deleteDataAfterFailedUnlockCount forKey:kDeleteDataAfterFailedUnlockCount];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (NSUInteger)failedUnlockAttempts {
    return [[self getSharedAppGroupDefaults] integerForKey:kFailedUnlockAttempts];
}

- (void)setFailedUnlockAttempts:(NSUInteger)failedUnlockAttempts {
    [[self getSharedAppGroupDefaults] setInteger:failedUnlockAttempts forKey:kFailedUnlockAttempts];
    [[self getSharedAppGroupDefaults] synchronize];
}

- (BOOL)appLockAppliesToPreferences {
    return [self getBool:kAppLockAppliesToPreferences];
}

- (void)setAppLockAppliesToPreferences:(BOOL)appLockAppliesToPreferences {
    [self setBool:kAppLockAppliesToPreferences value:appLockAppliesToPreferences];
}

- (BOOL)showAllFilesInLocalKeyFiles {
    return [self getBool:kShowAllFilesInLocalKeyFiles];
}

- (void)setShowAllFilesInLocalKeyFiles:(BOOL)showAllFilesInLocalKeyFiles {
    [self setBool:kShowAllFilesInLocalKeyFiles value:showAllFilesInLocalKeyFiles];
}

- (BOOL)hideKeyFileOnUnlock {
    return [self getBool:kHideKeyFileOnUnlock];
}

- (void)setHideKeyFileOnUnlock:(BOOL)hideKeyFileOnUnlock {
    [self setBool:kHideKeyFileOnUnlock value:hideKeyFileOnUnlock];
}

- (BOOL)allowEmptyOrNoPasswordEntry {
    return [self getBool:kAllowEmptyOrNoPasswordEntry fallback:NO];
}

- (void)setAllowEmptyOrNoPasswordEntry:(BOOL)allowEmptyOrNoPasswordEntry {
    [self setBool:kAllowEmptyOrNoPasswordEntry value:allowEmptyOrNoPasswordEntry];
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
