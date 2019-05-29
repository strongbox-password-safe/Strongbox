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
static NSString* const kAutoLockTimeSeconds = @"autoLockTimeSeconds";
static NSString* const kPromptedForReview = @"newPromptedForReview";
static NSString* const kIsProKey = @"isPro";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kPromptedForCopyPasswordGesture = @"promptedForCopyPasswordGesture";
static NSString* const kCopyPasswordOnLongPress = @"copyPasswordOnLongPress";
static NSString* const kShowPasswordByDefaultOnEditScreen = @"showPasswordByDefaultOnEditScreen";
static NSString* const kIsHavePromptedAboutFreeTrial = @"isHavePromptedAboutFreeTrial";
static NSString* const kNeverShowForMacAppMessage = @"neverShowForMacAppMessage";
static NSString* const kiCloudOn = @"iCloudOn";
static NSString* const kiCloudWasOn = @"iCloudWasOn";
static NSString* const kiCloudPrompted = @"iCloudPrompted";
static NSString* const kSafesMigratedToNewSystem = @"safesMigratedToNewSystem";
static NSString* const kPasswordGenerationParameters = @"passwordGenerationSettings";
static NSString* const kInstallDate = @"installDate";
static NSString* const kDisallowBiometricId = @"disallowBiometricId";
static NSString* const kDoNotAutoAddNewLocalSafes = @"doNotAutoAddNewLocalSafes";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kUseQuickLaunchAsRootView = @"useQuickLaunchAsRootView";
static NSString* const kShowKeePassCreateSafeOptions = @"showKeePassCreateSafeOptions";
static NSString* const kHasShownAutoFillLaunchWelcome = @"hasShownAutoFillLaunchWelcome";
static NSString* const kHasShownKeePassBetaWarning = @"hasShownKeePassBetaWarning";
static NSString* const kShowKeePass1BackupGroupInSearchResults = @"showKeePass1BackupGroupInSearchResults";
static NSString* const kHideTips = @"hideTips";
static NSString* const kDisallowAllPinCodeOpens = @"disallowAllPinCodeOpens";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kHideTotp = @"hideTotp";
static NSString* const kHideTotpInBrowse = @"hideTotpInBrowse";
static NSString* const kHideTotpInAutoFill = @"hideTotpInAutofill";
static NSString* const kUiDoNotSortKeePassNodesInBrowseView = @"uiDoNotSortKeePassNodesInBrowseView";
static NSString* const kTryDownloadFavIconForNewRecord = @"tryDownloadFavIconForNewRecord";
static NSString* const kDoNotAutoDetectKeyFiles = @"doNotAutoDetectKeyFiles";
static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails";
static NSString* const kDoNotShowRecycleBinInBrowse = @"doNotShowRecycleBinInBrowse";
static NSString* const kShowRecycleBinInSearchResults = @"showRecycleBinInSearchResults";
static NSString* const kCopyOtpCodeOnAutoFillSelect = @"copyOtpCodeOnAutoFillSelect";
static NSString* const kDoNotUseQuickTypeAutoFill = @"doNotUseQuickTypeAutoFill";
static NSString* const kViewDereferencedFields = @"viewDereferencedFields";
static NSString* const kSearchDereferencedFields = @"searchDereferencedFields";
static NSString* const kUseOldItemDetailsScene = @"useOldItemDetailsScene";
static NSString* const kHideEmptyFieldsInDetailsView = @"hideEmptyFieldsInDetailsView";
static NSString* const kCollapsedSections = @"collapsedSections";
static NSString* const kEasyReadFontForAll = @"easyReadFontForAll";
static NSString* const kInstantPinUnlocking = @"instantPinUnlocking";
static NSString* const kShowChildCountOnFolderInBrowse = @"showChildCountOnFolderInBrowse";
static NSString* const kShowFlagsInBrowse = @"showFlagsInBrowse";
static NSString* const kShowUsernameInBrowse = @"showUsernameInBrowse";
static NSString* const kHaveWarnedAboutAutoFillCrash = @"haveWarnedAboutAutoFillCrash";
static NSString* const kDeleteDataAfterFailedUnlockCount = @"deleteDataAfterFailedUnlockCount";
static NSString* const kFailedUnlockAttempts = @"failedUnlockAttempts";
static NSString* const kAppLockAppliesToPreferences = @"appLockAppliesToPreferences";
static NSString* const kShowAdvancedUnlockOptions = @"showAdvancedUnlockOptions";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kTemporaryUseOldUnlock = @"temporaryUseOldUnlock";

static NSString* const kAppLockMode = @"appLockMode2.0";
static NSString* const kAppLockPin = @"appLockPin2.0";
static NSString* const kAppLockDelay = @"appLockDelay2.0";

@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    
    return sharedInstance;
}

- (NSUserDefaults*)getUserDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupName];
    
    return defaults;
}

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasShownKeePassBetaWarning {
    return [[self getUserDefaults] boolForKey:kHasShownKeePassBetaWarning];
}

- (void)setHasShownKeePassBetaWarning:(BOOL)hasShownKeePassBetaWarning {
    [[self getUserDefaults] setBool:hasShownKeePassBetaWarning forKey:kHasShownKeePassBetaWarning];
    [[self getUserDefaults] synchronize];
}

- (BOOL)showPasswordByDefaultOnEditScreen {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    return [userDefaults boolForKey:kShowPasswordByDefaultOnEditScreen];
}

- (void)setShowPasswordByDefaultOnEditScreen:(BOOL)showPasswordByDefaultOnEditScreen {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setBool:showPasswordByDefaultOnEditScreen forKey:kShowPasswordByDefaultOnEditScreen];
    
    [userDefaults synchronize];
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

-(NSNumber*)getAutoLockTimeoutSeconds
{
    NSUserDefaults *userDefaults = [self getUserDefaults];

    NSNumber *seconds = [userDefaults objectForKey:kAutoLockTimeSeconds];

    if (seconds == nil) {
        seconds = @60;
    }
    
    return seconds;
}

-(void)setAutoLockTimeoutSeconds:(NSNumber*)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setObject:value forKey:kAutoLockTimeSeconds];
    
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

- (BOOL)isCopyPasswordOnLongPress {
    NSUserDefaults *userDefaults = [self getUserDefaults];

    return [userDefaults boolForKey:kCopyPasswordOnLongPress];
}

- (void)setCopyPasswordOnLongPress:(BOOL)value {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    [userDefaults setBool:value forKey:kCopyPasswordOnLongPress];
    
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

- (NSString*)getFlagsStringForDiagnostics {
    return [NSString stringWithFormat:@"[%d%d%d%d%d[%ld][%@]%ld%d%d%d%d%d%d%d]",
    self.showPasswordByDefaultOnEditScreen,
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

+ (BOOL)isBiometricIdAvailable {
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if (localAuthContext == nil) {
        return NO;
    }
    
    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    if (error) {
        //NSLog(@"Error with biometrics authentication");
        return NO;
    }
    
    return YES;
}

- (void)requestBiometricId:(NSString*)reason
     allowDevicePinInstead:(BOOL)allowDevicePinInstead
                completion:(void(^)(BOOL success, NSError * __nullable error))completion {
    [self requestBiometricId:reason fallbackTitle:nil allowDevicePinInstead:allowDevicePinInstead completion:completion];
}

- (void)requestBiometricId:(NSString*)reason
             fallbackTitle:(NSString*)fallbackTitle
     allowDevicePinInstead:(BOOL)allowDevicePinInstead
                completion:(void(^)(BOOL success, NSError * __nullable error))completion {
    LAContext *localAuthContext = [[LAContext alloc] init];
    if(fallbackTitle) {
        localAuthContext.localizedFallbackTitle = fallbackTitle;
    }
    else {
        localAuthContext.localizedFallbackTitle = @"";
    }
    
    NSLog(@"REQUEST-BIOMETRIC: %d", self.suppressPrivacyScreen);
    
    self.suppressPrivacyScreen = YES;
    [localAuthContext evaluatePolicy:allowDevicePinInstead ? LAPolicyDeviceOwnerAuthentication : LAPolicyDeviceOwnerAuthenticationWithBiometrics
                     localizedReason:reason
                               reply:^(BOOL success, NSError *error) {
                                    completion(success, error);
                                    NSLog(@"REQUEST-BIOMETRIC DONE: %d", success);
                                    self.suppressPrivacyScreen = NO;
                               }];
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

- (BOOL)doNotAutoAddNewLocalSafes {
    return [[self getUserDefaults] boolForKey:kDoNotAutoAddNewLocalSafes];
}

- (void)setDoNotAutoAddNewLocalSafes:(BOOL)doNotAutoAddNewLocalSafes {
    [[self getUserDefaults] setBool:doNotAutoAddNewLocalSafes forKey:kDoNotAutoAddNewLocalSafes];
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

- (BOOL)showKeePass1BackupGroup {
    return [[self getUserDefaults] boolForKey:kShowKeePass1BackupGroupInSearchResults];
}

- (void)setShowKeePass1BackupGroup:(BOOL)showKeePass1BackupGroupInSearchResults {
    [[self getUserDefaults] setBool:showKeePass1BackupGroupInSearchResults forKey:kShowKeePass1BackupGroupInSearchResults];
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
    return [[self getUserDefaults] boolForKey:kClearClipboardEnabled];
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [[self getUserDefaults] setBool:clearClipboardEnabled forKey:kClearClipboardEnabled];
    [[self getUserDefaults] synchronize];
}

static const NSInteger kDefaultClearClipboardTimeout = 60;
- (NSInteger)clearClipboardAfterSeconds {
    NSInteger ret =  [[self getUserDefaults] integerForKey:kClearClipboardAfterSeconds];

    return ret == 0 ? kDefaultClearClipboardTimeout : ret;
}

-(void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    [[self getUserDefaults] setInteger:clearClipboardAfterSeconds forKey:kClearClipboardAfterSeconds];
    [[self getUserDefaults] synchronize];
}

-(BOOL)hideTotp {
    return [[self getUserDefaults] boolForKey:kHideTotp];
}

- (void)setHideTotp:(BOOL)hideTotp {
    [[self getUserDefaults] setBool:hideTotp forKey:kHideTotp];
    [[self getUserDefaults] synchronize];
}

-(BOOL)hideTotpInBrowse {
    return [[self getUserDefaults] boolForKey:kHideTotpInBrowse];
}

-(void)setHideTotpInBrowse:(BOOL)hideTotpInBrowse {
    [[self getUserDefaults] setBool:hideTotpInBrowse forKey:kHideTotpInBrowse];
    [[self getUserDefaults] synchronize];
}

- (BOOL)hideTotpInAutoFill {
    return [[self getUserDefaults] boolForKey:kHideTotpInAutoFill];
}

- (void)setHideTotpInAutoFill:(BOOL)hideTotpInAutoFill {
    [[self getUserDefaults] setBool:hideTotpInAutoFill forKey:kHideTotpInAutoFill];
    [[self getUserDefaults] synchronize];
}

- (BOOL)uiDoNotSortKeePassNodesInBrowseView {
    return [[self getUserDefaults] boolForKey:kUiDoNotSortKeePassNodesInBrowseView];
}

- (void)setUiDoNotSortKeePassNodesInBrowseView:(BOOL)uiDoNotSortKeePassNodesInBrowseView {
    [[self getUserDefaults] setBool:uiDoNotSortKeePassNodesInBrowseView forKey:kUiDoNotSortKeePassNodesInBrowseView];
    [[self getUserDefaults] synchronize];
}

-(BOOL)tryDownloadFavIconForNewRecord {
    return [self getBool:kTryDownloadFavIconForNewRecord fallback:YES];
}

- (void)setTryDownloadFavIconForNewRecord:(BOOL)tryDownloadFavIconForNewRecord {
    [[self getUserDefaults] setBool:tryDownloadFavIconForNewRecord forKey:kTryDownloadFavIconForNewRecord];
    [[self getUserDefaults] synchronize];
}

- (BOOL)doNotAutoDetectKeyFiles {
    return [[self getUserDefaults] boolForKey:kDoNotAutoDetectKeyFiles];
}

- (void)setDoNotAutoDetectKeyFiles:(BOOL)doNotAutoDetectKeyFiles {
    [[self getUserDefaults] setBool:doNotAutoDetectKeyFiles forKey:kDoNotAutoDetectKeyFiles];
    [[self getUserDefaults] synchronize];
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

- (BOOL)doNotShowRecycleBinInBrowse {
    return [[self getUserDefaults] boolForKey:kDoNotShowRecycleBinInBrowse];
}

- (void)setDoNotShowRecycleBinInBrowse:(BOOL)doNotShowRecycleBinInBrowse {
    [[self getUserDefaults] setBool:doNotShowRecycleBinInBrowse forKey:kDoNotShowRecycleBinInBrowse];
    [[self getUserDefaults] synchronize];
}

- (BOOL)showRecycleBinInSearchResults {
    return [[self getUserDefaults] boolForKey:kShowRecycleBinInSearchResults];
}

- (void)setShowRecycleBinInSearchResults:(BOOL)showRecycleBinInSearchResults {
    [[self getUserDefaults] setBool:showRecycleBinInSearchResults forKey:kShowRecycleBinInSearchResults];
    [[self getUserDefaults] synchronize];
}

- (BOOL)doNotCopyOtpCodeOnAutoFillSelect {

    return [[self getUserDefaults] boolForKey:kCopyOtpCodeOnAutoFillSelect];
}

- (void)setDoNotCopyOtpCodeOnAutoFillSelect:(BOOL)copyOtpCodeOnAutoFillSelect {
    [[self getUserDefaults] setBool:copyOtpCodeOnAutoFillSelect forKey:kCopyOtpCodeOnAutoFillSelect];
    [[self getUserDefaults] synchronize];
}

- (BOOL)doNotUseQuickTypeAutoFill {
    return [[self getUserDefaults] boolForKey:kDoNotUseQuickTypeAutoFill];
}

- (void)setDoNotUseQuickTypeAutoFill:(BOOL)doNotUseQuickTypeAutoFill {
    [[self getUserDefaults] setBool:doNotUseQuickTypeAutoFill forKey:kDoNotUseQuickTypeAutoFill];
    [[self getUserDefaults] synchronize];
}

- (BOOL)viewDereferencedFields {
    return [[self getUserDefaults] boolForKey:kViewDereferencedFields];
}

- (void)setViewDereferencedFields:(BOOL)viewDereferencedFields {
    [[self getUserDefaults] setBool:viewDereferencedFields forKey:kViewDereferencedFields];
    [[self getUserDefaults] synchronize];
}

- (BOOL)searchDereferencedFields {
    return [[self getUserDefaults] boolForKey:kSearchDereferencedFields];
}

- (void)setSearchDereferencedFields:(BOOL)searchDereferencedFields {
    [[self getUserDefaults] setBool:searchDereferencedFields forKey:kSearchDereferencedFields];
    [[self getUserDefaults] synchronize];
}

- (BOOL)useOldItemDetailsScene {
    return [[self getUserDefaults] boolForKey:kUseOldItemDetailsScene];
}

- (void)setUseOldItemDetailsScene:(BOOL)useOldItemDetailsScene {
    [[self getUserDefaults] setBool:useOldItemDetailsScene forKey:kUseOldItemDetailsScene];
    [[self getUserDefaults] synchronize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)showEmptyFieldsInDetailsView {
    return [self getBool:kHideEmptyFieldsInDetailsView fallback:YES];
}

- (void)setShowEmptyFieldsInDetailsView:(BOOL)hideEmptyFieldsInDetailsView {
    [self setBool:kHideEmptyFieldsInDetailsView value:hideEmptyFieldsInDetailsView];
}

- (NSArray<NSNumber *> *)detailsViewCollapsedSections {
    NSArray* ret = [[self getUserDefaults] arrayForKey:kCollapsedSections];
    
    return ret ? ret : @[@(0), @(0), @(0), @(0), @(1), @(1)]; // Default
}

- (void)setDetailsViewCollapsedSections:(NSArray<NSNumber *> *)detailsViewCollapsedSections {
    [[self getUserDefaults] setObject:detailsViewCollapsedSections forKey:kCollapsedSections];
    [[self getUserDefaults] synchronize];
}

- (BOOL)easyReadFontForAll {
    return [self getBool:kEasyReadFontForAll];
}

- (void)setEasyReadFontForAll:(BOOL)easyReadFontForAll {
    [self setBool:kEasyReadFontForAll value:easyReadFontForAll];
}

- (BOOL)instantPinUnlocking {
    return [self getBool:kInstantPinUnlocking fallback:YES];
}

- (void)setInstantPinUnlocking:(BOOL)instantPinUnlocking {
    [self setBool:kInstantPinUnlocking value:instantPinUnlocking];
}

- (BOOL)showChildCountOnFolderInBrowse {
    return [self getBool:kShowChildCountOnFolderInBrowse];
}

- (void)setShowChildCountOnFolderInBrowse:(BOOL)showChildCountOnFolderInBrowse {
    [self setBool:kShowChildCountOnFolderInBrowse value:showChildCountOnFolderInBrowse];
}

- (BOOL)showFlagsInBrowse {
    return [self getBool:kShowFlagsInBrowse fallback:YES];
}

- (void)setShowFlagsInBrowse:(BOOL)showFlagsInBrowse {
    [self setBool:kShowFlagsInBrowse value:showFlagsInBrowse];
}

- (BOOL)showUsernameInBrowse {
    return [self getBool:kShowUsernameInBrowse fallback:YES];
}

-(void)setShowUsernameInBrowse:(BOOL)showUsernameInBrowse {
    [self setBool:kShowUsernameInBrowse value:showUsernameInBrowse];
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

- (BOOL)showAdvancedUnlockOptions {
    return [self getBool:kShowAdvancedUnlockOptions fallback:NO];
}

- (void)setShowAdvancedUnlockOptions:(BOOL)showAdvancedUnlockOptions {
    [self setBool:kShowAdvancedUnlockOptions value:showAdvancedUnlockOptions];
}

- (BOOL)allowEmptyOrNoPasswordEntry {
    return [self getBool:kAllowEmptyOrNoPasswordEntry fallback:NO];
}

- (void)setAllowEmptyOrNoPasswordEntry:(BOOL)allowEmptyOrNoPasswordEntry {
    [self setBool:kAllowEmptyOrNoPasswordEntry value:allowEmptyOrNoPasswordEntry];
}

- (BOOL)temporaryUseOldUnlock {
    return [self getBool:kTemporaryUseOldUnlock];
}

- (void)setTemporaryUseOldUnlock:(BOOL)temporaryUseOldUnlock {
    [self setBool:kTemporaryUseOldUnlock value:temporaryUseOldUnlock];
}

@end
