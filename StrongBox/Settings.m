//
//  Settings.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SafesList.h"
#import "NSArray+Extensions.h"

static NSString* const kLaunchCountKey = @"launchCount";
static NSString* const kPromptedForReview = @"newPromptedForReview";
static NSString* const kIsProKey = @"isPro";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kPromptedForCopyPasswordGesture = @"promptedForCopyPasswordGesture";

static NSString* const kIsHavePromptedAboutFreeTrial = @"isHavePromptedAboutFreeTrial";
static NSString* const kNeverShowForMacAppMessage = @"neverShowForMacAppMessage";
static NSString* const kiCloudOn = @"iCloudOn";
static NSString* const kiCloudWasOn = @"iCloudWasOn";
static NSString* const kiCloudPrompted = @"iCloudPrompted";
static NSString* const kSafesMigratedToNewSystem = @"safesMigratedToNewSystem";
static NSString* const kInstallDate = @"installDate";
static NSString* const kDisallowBiometricId = @"disallowBiometricId";
//static NSString* const kDoNotAutoAddNewLocalSafes = @"doNotAutoAddNewLocalSafes"; // Dead
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";

static NSString* const kUseQuickLaunchAsRootView = @"useQuickLaunchAsRootView"; // TODO: Retire / Remove - Dead

static NSString* const kShowKeePassCreateSafeOptions = @"showKeePassCreateSafeOptions";
static NSString* const kHasShownAutoFillLaunchWelcome = @"hasShownAutoFillLaunchWelcome";
static NSString* const kHasShownKeePassBetaWarning = @"hasShownKeePassBetaWarning";
static NSString* const kHideTips = @"hideTips";
static NSString* const kDisallowAllPinCodeOpens = @"disallowAllPinCodeOpens";

static const NSInteger kDefaultClearClipboardTimeout = 90;
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";

//static NSString* const kHideTotpInAutoFill = @"hideTotpInAutofill"; // DEAD
//static NSString* const kDoNotAutoDetectKeyFiles = @"doNotAutoDetectKeyFiles"; // DEAD
static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails";
//static NSString* const kCopyOtpCodeOnAutoFillSelect = @"copyOtpCodeOnAutoFillSelect";
//static NSString* const kDoNotUseQuickTypeAutoFill = @"doNotUseQuickTypeAutoFill"; // Dead
static NSString* const kUseOldItemDetailsScene = @"useOldItemDetailsScene"; // DEAD
static NSString* const kInstantPinUnlocking = @"instantPinUnlocking";
static NSString* const kHaveWarnedAboutAutoFillCrash = @"haveWarnedAboutAutoFillCrash";
static NSString* const kDeleteDataAfterFailedUnlockCount = @"deleteDataAfterFailedUnlockCount";
static NSString* const kFailedUnlockAttempts = @"failedUnlockAttempts";
static NSString* const kAppLockAppliesToPreferences = @"appLockAppliesToPreferences";
//static NSString* const kShowAdvancedUnlockOptions = @"showAdvancedUnlockOptions";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
//static NSString* const kTemporaryUseOldUnlock = @"temporaryUseOldUnlock"; // DEAD
static NSString* const kShowAllFilesInLocalKeyFiles = @"showAllFilesInLocalKeyFiles";
static NSString* const kHideKeyFileOnUnlock = @"hideKeyFileOnUnlock";

//static NSString* const kDoNotUseNewSplitViewController = @"doNotUseNewSplitViewController"; DEAD
//static NSString* const kInterpretEmptyPasswordAsNoPassword = @"interpretEmptyPasswordAsNoPassword"; // DEAD
static NSString* const kMigratedLocalDatabasesToNewSystem = @"migratedLocalDatabasesToNewSystem";

static NSString* const kPasswordGenerationParameters = @"passwordGenerationSettings";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kMigratedToNewPasswordGenerator = @"migratedToNewPasswordGenerator";

static NSString* const kAppLockMode = @"appLockMode2.0";
static NSString* const kAppLockPin = @"appLockPin2.0";
static NSString* const kAppLockDelay = @"appLockDelay2.0";

NSString* const kProStatusChangedNotificationKey = @"proStatusChangedNotification";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";

static NSString* const kDefaultAppGroupName = @"group.strongbox.mcguill";
static NSString* cachedAppGroupName;

static NSString* const kShowYubikeySecretWorkaroundField = @"showYubikeySecretWorkaroundField";
//static NSString* const kUseLocalSharedStorage = @"useLocalSharedStorage"; // DEAD
static NSString* const kQuickLaunchUuid = @"quickLaunchUuid";
static NSString* const kMigratedToNewQuickLaunchSystem = @"migratedToNewQuickLaunchSystem";

static NSString* const kShowDatabaseIcon = @"showDatabaseIcon";
static NSString* const kShowDatabaseStatusIcon = @"showDatabaseStatusIcon";
static NSString* const kDatabaseCellTopSubtitle = @"databaseCellTopSubtitle";
static NSString* const kDatabaseCellSubtitle1 = @"databaseCellSubtitle1";
static NSString* const kDatabaseCellSubtitle2 = @"databaseCellSubtitle2";
static NSString* const kShowDatabasesSeparator = @"showDatabasesSeparator";
static NSString* const kMonitorInternetConnectivity = @"monitorInternetConnectivity";
static NSString* const kHasDoneProFamilyCheck = @"hasDoneProFamilyCheck";

@implementation Settings

+ (void)initialize {
    if(self == [Settings class]) {
        // NSString* appGroupPP = [Settings getAppGroupFromProvisioningProfile];
        // cachedAppGroupName = appGroupPP ? appGroupPP : kDefaultAppGroupName;
        //NSLog(@"App Group Name: [%@] (Auto Detected : [%@])", cachedAppGroupName, appGroupPP);

        cachedAppGroupName = kDefaultAppGroupName;
    }
}

- (NSString *)appGroupName {
    return cachedAppGroupName;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

//

- (BOOL)migratedToNewQuickLaunchSystem {
    return [self getBool:kMigratedToNewQuickLaunchSystem];
}

- (void)setMigratedToNewQuickLaunchSystem:(BOOL)migratedToNewQuickLaunchSystem {
    [self setBool:kMigratedToNewQuickLaunchSystem value:migratedToNewQuickLaunchSystem];
}

- (NSString *)quickLaunchUuid {
    return [self getString:kQuickLaunchUuid];
}

- (void)setQuickLaunchUuid:(NSString *)quickLaunchUuid {
    [self setString:kQuickLaunchUuid value:quickLaunchUuid];
}

- (BOOL)useLocalSharedStorage {
    return YES; // [self getBool:kUseLocalSharedStorage fallback:YES];
}

- (BOOL)showYubikeySecretWorkaroundField {
    return [self getBool:kShowYubikeySecretWorkaroundField];
}

- (void)setShowYubikeySecretWorkaroundField:(BOOL)showYubikeySecretWorkaroundField {
    [self setBool:kShowYubikeySecretWorkaroundField value:showYubikeySecretWorkaroundField];
}

- (BOOL)migratedToNewPasswordGenerator {
    return [self getBool:kMigratedToNewPasswordGenerator];
}

- (void)setMigratedToNewPasswordGenerator:(BOOL)migratedToNewPasswordGenerator {
    [self setBool:kMigratedToNewPasswordGenerator value:migratedToNewPasswordGenerator];
}

- (PasswordGenerationParameters *)passwordGenerationParameters {
    NSUserDefaults *defaults = [self getUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationParameters];
    
    if(encodedObject == nil) {
        return [[PasswordGenerationParameters alloc] initWithDefaults];
    }
    
    PasswordGenerationParameters *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    //NSError *error; // This fails because PGP doesn't conform to NSSecureCoding... something to do some day...
    //PasswordGenerationParameters *object = [NSKeyedUnarchiver unarchivedObjectOfClass:PasswordGenerationParameters.class fromData:encodedObject error:&error];
    
    return object;
}

-(void)setPasswordGenerationParameters:(PasswordGenerationParameters *)passwordGenerationParameters {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationParameters];
    NSUserDefaults *defaults = [self getUserDefaults];
    [defaults setObject:encodedObject forKey:kPasswordGenerationParameters];
    [defaults synchronize];
}

//

- (PasswordGenerationConfig *)passwordGenerationConfig {
    NSUserDefaults *defaults = [self getUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return [PasswordGenerationConfig defaults];
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setPasswordGenerationConfig:(PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationConfig];
    NSUserDefaults *defaults = [self getUserDefaults];
    [defaults setObject:encodedObject forKey:kPasswordGenerationConfig];
    [defaults synchronize];
}

- (BOOL)migratedLocalDatabasesToNewSystem {
    return [self getBool:kMigratedLocalDatabasesToNewSystem];
}

- (void)setMigratedLocalDatabasesToNewSystem:(BOOL)migratedLocalDatabasesToNewSystem {
    [self setBool:kMigratedLocalDatabasesToNewSystem value:migratedLocalDatabasesToNewSystem];
}

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    
    return sharedInstance;
}

- (NSUserDefaults*)getUserDefaults {
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
    NSString* obj = [[self getUserDefaults] objectForKey:key];
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [[self getUserDefaults] setObject:value forKey:key];
    [[self getUserDefaults] synchronize];
}

//

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [[self getUserDefaults] objectForKey:key];
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [[self getUserDefaults] setBool:value forKey:key];
    [[self getUserDefaults] synchronize];
}

//

- (NSInteger)getInteger:(NSString*)key {
    return [[self getUserDefaults] integerForKey:key];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [[self getUserDefaults] objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [[self getUserDefaults] setInteger:value forKey:key];
    [[self getUserDefaults] synchronize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasShownKeePassBetaWarning {
    return [[self getUserDefaults] boolForKey:kHasShownKeePassBetaWarning];
}

- (void)setHasShownKeePassBetaWarning:(BOOL)hasShownKeePassBetaWarning {
    [[self getUserDefaults] setBool:hasShownKeePassBetaWarning forKey:kHasShownKeePassBetaWarning];
    [[self getUserDefaults] synchronize];
}

- (BOOL)isProOrFreeTrial
{
    return [self isPro] || [self isFreeTrial];
}

- (void)setPro:(BOOL)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setBool:value forKey:kIsProKey];
    
    [userDefaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotificationKey object:nil];
}

- (BOOL)isPro
{
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    return [userDefaults boolForKey:kIsProKey];
}

- (void)setHavePromptedAboutFreeTrial:(BOOL)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setBool:value forKey:kIsHavePromptedAboutFreeTrial];
    
    [userDefaults synchronize];
}

- (BOOL)isHavePromptedAboutFreeTrial {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
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
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setEndFreeTrialDate:(NSDate*)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setObject:value forKey:kEndFreeTrialDate];

    NSLog(@"Set Free trial end date to %@", value);

    [userDefaults synchronize];
}

- (NSInteger)getFreeTrialDaysRemaining {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
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
    return [[self getUserDefaults] objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setObject:installDate forKey:kInstallDate];
    [userDefaults synchronize];
}

- (void)clearInstallDate {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
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
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    NSInteger launchCount = [userDefaults integerForKey:kLaunchCountKey];
    
    return launchCount;
}

- (void)resetLaunchCount {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults removeObjectForKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (void)incrementLaunchCount {
    NSInteger launchCount = [self getLaunchCount];
    
    launchCount++;
    
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    
    NSUserDefaults *userDefaults = [self getUserDefaults];
    [userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    
    [userDefaults synchronize];
}

- (NSInteger)isUserHasBeenPromptedForReview {
    NSUserDefaults *userDefaults = [self getUserDefaults];
 
    return [userDefaults integerForKey:kPromptedForReview];
}

- (void)setUserHasBeenPromptedForReview:(NSInteger)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setInteger:value forKey:kPromptedForReview];

    [userDefaults synchronize];
}

- (BOOL)isHasPromptedForCopyPasswordGesture {
    NSUserDefaults *userDefaults = [self getUserDefaults];

    return [userDefaults boolForKey:kPromptedForCopyPasswordGesture];
}

- (void)setHasPromptedForCopyPasswordGesture:(BOOL)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setBool:value forKey:kPromptedForCopyPasswordGesture];

    [userDefaults synchronize];
}

- (void)setNeverShowForMacAppMessage:(BOOL)neverShowForMacAppMessage {
    [[self getUserDefaults] setBool:neverShowForMacAppMessage forKey:kNeverShowForMacAppMessage];
    
    [[self getUserDefaults] synchronize];
}

- (BOOL)neverShowForMacAppMessage {
    return [[self getUserDefaults] boolForKey:kNeverShowForMacAppMessage];
}


- (BOOL)iCloudOn {
    return [[self getUserDefaults] boolForKey:kiCloudOn];
}

- (void)setICloudOn:(BOOL)iCloudOn {
    [[self getUserDefaults] setBool:iCloudOn forKey:kiCloudOn];
    [[self getUserDefaults] synchronize];
}

- (BOOL)iCloudWasOn {
    return [[self getUserDefaults] boolForKey:kiCloudWasOn];
}

-(void)setICloudWasOn:(BOOL)iCloudWasOn {
    [[self getUserDefaults] setBool:iCloudWasOn forKey:kiCloudWasOn];
    [[self getUserDefaults] synchronize];
}

- (BOOL)iCloudPrompted {
    return [[self getUserDefaults] boolForKey:kiCloudPrompted];
}

- (void)setICloudPrompted:(BOOL)iCloudPrompted {
    [[self getUserDefaults] setBool:iCloudPrompted forKey:kiCloudPrompted];
    [[self getUserDefaults] synchronize];
}

//

- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d%d%d%d[%ld]%ld%d%d%d%d%d%d]",
    self.isHavePromptedAboutFreeTrial,
    self.isProOrFreeTrial,
    self.isPro,
    self.isFreeTrial,
    (long)self.getLaunchCount,
    (long)self.isUserHasBeenPromptedForReview,
    self.isHasPromptedForCopyPasswordGesture,
    self.neverShowForMacAppMessage,
    self.iCloudOn,
    self.iCloudWasOn,
    self.iCloudPrompted,
    self.iCloudAvailable];
}

+ (BOOL)isBiometricIdAvailable {
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if (localAuthContext == nil) {
        return NO;
    }
    
    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    if (error) {
        NSLog(@"isBiometricIdAvailable: NO -> ");
        [Settings logBiometricError:error];
        return NO;
    }
    
    return YES;
}

- (void)requestBiometricId:(NSString*)reason
                completion:(void(^)(BOOL success, NSError * __nullable error))completion {
    [self requestBiometricId:reason fallbackTitle:nil completion:completion];
}

- (void)requestBiometricId:(NSString*)reason
             fallbackTitle:(NSString*)fallbackTitle // Setting this means you handle the case of error == LAErrorUserFallback
                completion:(void(^)(BOOL success, NSError * __nullable error))completion {
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if(fallbackTitle) {
        localAuthContext.localizedFallbackTitle = fallbackTitle;
    }
    
    NSLog(@"REQUEST-BIOMETRIC: %d", self.suppressPrivacyScreen);
    
    self.suppressPrivacyScreen = YES;
    
    // MMcG: NB
    //
    // LAPolicyDeviceOwnerAuthentication -> This allows user to enter Device Passcode - which is normally what we want
    // LAPolicyDeviceOwnerAuthenticationWithBiometrics -> Does not auto fall back to device passcode but allows for custom fallback mechanism
    
    [localAuthContext evaluatePolicy:fallbackTitle ? LAPolicyDeviceOwnerAuthenticationWithBiometrics : LAPolicyDeviceOwnerAuthentication
                     localizedReason:reason
                               reply:^(BOOL success, NSError *error) {
                                   self.suppressPrivacyScreen = NO;

                                   if(!success) {
                                       NSLog(@"requestBiometricId: NO -> ");
                                       [Settings logBiometricError:error];
                                   }
                                   else {
                                       NSLog(@"REQUEST-BIOMETRIC DONE SUCCESS");
                                   }
                                   completion(success, error);
                               }];
}

+ (void)logBiometricError:(NSError*)error {
    if (error.code == LAErrorAuthenticationFailed) {
        NSLog(@"BIOMETRIC: Auth Failed");
    }
    else if (error.code == LAErrorUserFallback) {
        NSLog(@"BIOMETRIC: User Choose Fallback");
    }
    else if (error.code == LAErrorUserCancel) {
        NSLog(@"BIOMETRIC: User Cancelled");
    }
    else if (@available(iOS 11.0, *)) {
        if (error.code == LAErrorBiometryNotAvailable) {
            NSLog(@"BIOMETRIC: LAErrorBiometryNotAvailable");
        }
        else if (error.code == LAErrorSystemCancel) {
            NSLog(@"BIOMETRIC: LAErrorSystemCancel");
        }
        else if (error.code == LAErrorBiometryNotEnrolled) {
            NSLog(@"BIOMETRIC: LAErrorBiometryNotEnrolled");
        }
        else if (error.code == LAErrorBiometryLockout) {
            NSLog(@"BIOMETRIC: LAErrorBiometryLockout");
        }
    }
    else {
        NSLog(@"BIOMETRIC: Unknown Error: [%@]", error);
    }
}

- (NSString*)getBiometricIdName {
    NSString* biometricIdName = NSLocalizedString(@"settings_touch_id_name", @"Touch ID");
    
    if (@available(iOS 11.0, *)) {
        NSError* error;
        LAContext *localAuthContext = [[LAContext alloc] init];
        
        if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
            if (localAuthContext.biometryType == LABiometryTypeFaceID ) {
                biometricIdName = NSLocalizedString(@"settings_face_id_name", @"Face ID");
            }
        }
    }
    
    return biometricIdName;
}

- (BOOL)safesMigratedToNewSystem {
    return [[self getUserDefaults] boolForKey:kSafesMigratedToNewSystem];
}

- (void)setSafesMigratedToNewSystem:(BOOL)safesMigratedToNewSystem {
    [[self getUserDefaults] setBool:safesMigratedToNewSystem forKey:kSafesMigratedToNewSystem];
    [[self getUserDefaults] synchronize];
}

- (BOOL)disallowAllBiometricId {
    return [[self getUserDefaults] boolForKey:kDisallowBiometricId];
}

- (void)setDisallowAllBiometricId:(BOOL)disallowAllBiometricId {
    [[self getUserDefaults] setBool:disallowAllBiometricId forKey:kDisallowBiometricId];
    [[self getUserDefaults] synchronize];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [[self getUserDefaults] objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [[self getUserDefaults] setObject:encoded forKey:kAutoFillNewRecordSettings];
    [[self getUserDefaults] synchronize];
}

- (BOOL)useQuickLaunchAsRootView {
    return [[self getUserDefaults] boolForKey:kUseQuickLaunchAsRootView];
}

- (void)setUseQuickLaunchAsRootView:(BOOL)useQuickLaunchAsRootView {
    [[self getUserDefaults] setBool:useQuickLaunchAsRootView forKey:kUseQuickLaunchAsRootView];
    [[self getUserDefaults] synchronize];
}

- (BOOL)showKeePassCreateSafeOptions {
    return [[self getUserDefaults] boolForKey:kShowKeePassCreateSafeOptions];
}

- (void)setShowKeePassCreateSafeOptions:(BOOL)showKeePassCreateSafeOptions {
    [[self getUserDefaults] setBool:showKeePassCreateSafeOptions forKey:kShowKeePassCreateSafeOptions];
    [[self getUserDefaults] synchronize];
}

- (BOOL)hasShownAutoFillLaunchWelcome {
    return [[self getUserDefaults] boolForKey:kHasShownAutoFillLaunchWelcome];
}

- (void)setHasShownAutoFillLaunchWelcome:(BOOL)hasShownAutoFillLaunchWelcome {
    [[self getUserDefaults] setBool:hasShownAutoFillLaunchWelcome forKey:kHasShownAutoFillLaunchWelcome];
    [[self getUserDefaults] synchronize];
}

- (BOOL)hideTips {
    return [[self getUserDefaults] boolForKey:kHideTips];
}

- (void)setHideTips:(BOOL)hideTips {
    [[self getUserDefaults] setBool:hideTips forKey:kHideTips];
    [[self getUserDefaults] synchronize];
}

- (BOOL)disallowAllPinCodeOpens {
    return [[self getUserDefaults] boolForKey:kDisallowAllPinCodeOpens];
}

- (void)setDisallowAllPinCodeOpens:(BOOL)disallowAllPinCodeOpens {
    [[self getUserDefaults] setBool:disallowAllPinCodeOpens forKey:kDisallowAllPinCodeOpens];
    [[self getUserDefaults] synchronize];
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

- (BOOL)doNotAutoDetectKeyFiles {
    return NO; //[[self getUserDefaults] boolForKey:kDoNotAutoDetectKeyFiles];
}

- (NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    //[userDefaults removeObjectForKey:kEndFreeTrialDate];
    
    return [userDefaults objectForKey:kLastEntitlementCheckAttempt];
}

- (void)setLastEntitlementCheckAttempt:(NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setObject:lastEntitlementCheckAttempt forKey:kLastEntitlementCheckAttempt];
    
    [userDefaults synchronize];
}

- (NSUInteger)numberOfEntitlementCheckFails {
    NSInteger ret =  [[self getUserDefaults] integerForKey:kNumberOfEntitlementCheckFails];
    return ret;
}


- (void)setNumberOfEntitlementCheckFails:(NSUInteger)numberOfEntitlementCheckFails {
    [[self getUserDefaults] setInteger:numberOfEntitlementCheckFails forKey:kNumberOfEntitlementCheckFails];
    [[self getUserDefaults] synchronize];
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
    return [[self getUserDefaults] integerForKey:kAppLockMode];
}

- (void)setAppLockMode:(AppLockMode)appLockMode {
    [[self getUserDefaults] setInteger:appLockMode forKey:kAppLockMode];
    [[self getUserDefaults] synchronize];
}

- (NSString *)appLockPin {
    return [[self getUserDefaults] objectForKey:kAppLockPin];
}

-(void)setAppLockPin:(NSString *)appLockPin {
    [[self getUserDefaults] setObject:appLockPin forKey:kAppLockPin];
    [[self getUserDefaults] synchronize];
}

- (NSInteger)appLockDelay {
    NSInteger ret =  [[self getUserDefaults] integerForKey:kAppLockDelay];
    return ret;
}

-(void)setAppLockDelay:(NSInteger)appLockDelay {
    [[self getUserDefaults] setInteger:appLockDelay forKey:kAppLockDelay];
    [[self getUserDefaults] synchronize];
}

- (NSInteger)deleteDataAfterFailedUnlockCount {
    return [[self getUserDefaults] integerForKey:kDeleteDataAfterFailedUnlockCount];
}

- (void)setDeleteDataAfterFailedUnlockCount:(NSInteger)deleteDataAfterFailedUnlockCount {
    [[self getUserDefaults] setInteger:deleteDataAfterFailedUnlockCount forKey:kDeleteDataAfterFailedUnlockCount];
    [[self getUserDefaults] synchronize];
}

- (NSUInteger)failedUnlockAttempts {
    return [[self getUserDefaults] integerForKey:kFailedUnlockAttempts];
}

- (void)setFailedUnlockAttempts:(NSUInteger)failedUnlockAttempts {
    [[self getUserDefaults] setInteger:failedUnlockAttempts forKey:kFailedUnlockAttempts];
    [[self getUserDefaults] synchronize];
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
