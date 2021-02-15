//
//  SharedAppAndAutoFillSettings.m
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SharedAppAndAutoFillSettings.h"
#import "Model.h"

static NSString* const kDefaultAppGroupName = @"group.strongbox.mcguill";
static NSString* cachedAppGroupName;

static const NSInteger kDefaultClearClipboardTimeout = 90;

static NSString* const kIsProKey = @"isPro";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kClipboardHandoff = @"clipboardHandoff";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kHideTips = @"hideTips";
static NSString* const kDisallowAllPinCodeOpens = @"disallowAllPinCodeOpens";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kDisallowBiometricId = @"disallowBiometricId";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kQuickLaunchUuid = @"quickLaunchUuid";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kHideKeyFileOnUnlock = @"hideKeyFileOnUnlock";
static NSString* const kShowAllFilesInLocalKeyFiles = @"showAllFilesInLocalKeyFiles";
static NSString* const kMonitorInternetConnectivity = @"monitorInternetConnectivity";
static NSString* const kInstantPinUnlocking = @"instantPinUnlocking";
static NSString* const kiCloudOn = @"iCloudOn";
static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kShowDatabaseIcon = @"showDatabaseIcon";
static NSString* const kShowDatabaseStatusIcon = @"showDatabaseStatusIcon";
static NSString* const kDatabaseCellTopSubtitle = @"databaseCellTopSubtitle";
static NSString* const kDatabaseCellSubtitle1 = @"databaseCellSubtitle1";
static NSString* const kDatabaseCellSubtitle2 = @"databaseCellSubtitle2";
static NSString* const kShowDatabasesSeparator = @"showDatabasesSeparator";

static NSString* const kSyncPullEvenIfModifiedDateSame = @"syncPullEvenIfModifiedDateSame";
static NSString* const kSyncForcePushDoNotCheckForConflicts = @"syncForcePushDoNotCheckForConflicts";

static NSString* const kMainAppDidChangeDatabases = @"mainAppDidChangeDatabases";
static NSString* const kAutoFillDidChangeDatabases = @"autoFillDidChangeDatabases";
static NSString* const kShowMetadataOnDetailsScreen  = @"legacyShowMetadataOnDetailsScreen";
static NSString* const kQuickTypeTitleThenUsername = @"quickTypeTitleThenUsername";
static NSString* const kUserHasOptedInToThirdPartyStorageLibraries = @"userHasOptedInToThirdPartyStorageLibraries";

@implementation SharedAppAndAutoFillSettings

+ (void)initialize {
    if(self == [SharedAppAndAutoFillSettings class]) {
        
        
        

        cachedAppGroupName = kDefaultAppGroupName;
    }
}

+ (instancetype)sharedInstance {
    static SharedAppAndAutoFillSettings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SharedAppAndAutoFillSettings alloc] init];
    });
    
    return sharedInstance;
}



- (NSString *)appGroupName {
    return cachedAppGroupName;
}

- (NSUserDefaults *)sharedAppGroupDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
    
    if(defaults == nil) {
        NSLog(@"ERROR: Could not get NSUserDefaults for Suite Name: [%@]", self.appGroupName);
    }
    
    return defaults;
}



- (BOOL)userHasOptedInToThirdPartyStorageLibraries {
    return [self getBool:kUserHasOptedInToThirdPartyStorageLibraries];
}

- (void)setUserHasOptedInToThirdPartyStorageLibraries:(BOOL)userHasOptedInToThirdPartyStorageLibraries {
    [self setBool:kUserHasOptedInToThirdPartyStorageLibraries value:userHasOptedInToThirdPartyStorageLibraries];
}

- (BOOL)quickTypeTitleThenUsername {
    return [self getBool:kQuickTypeTitleThenUsername fallback:YES];
}

- (void)setQuickTypeTitleThenUsername:(BOOL)quickTypeTitleThenUsername {
    [self setBool:kQuickTypeTitleThenUsername value:quickTypeTitleThenUsername];
}

- (BOOL)showMetadataOnDetailsScreen {
    return [self getBool:kShowMetadataOnDetailsScreen fallback:YES];
}

- (void)setShowMetadataOnDetailsScreen:(BOOL)legacyShowMetadataOnDetailsScreen {
    [self setBool:kShowMetadataOnDetailsScreen value:legacyShowMetadataOnDetailsScreen];
}

- (BOOL)mainAppDidChangeDatabases {
    return [self getBool:kMainAppDidChangeDatabases];
}

- (void)setMainAppDidChangeDatabases:(BOOL)mainAppDidChangeDatabases {
    return [self setBool:kMainAppDidChangeDatabases value:mainAppDidChangeDatabases];
}

- (BOOL)autoFillDidChangeDatabases {
    return [self getBool:kAutoFillDidChangeDatabases];
    
}

- (void)setAutoFillDidChangeDatabases:(BOOL)autoFillDidChangeDatabases {
    [self setBool:kAutoFillDidChangeDatabases value:autoFillDidChangeDatabases];
}

- (BOOL)syncForcePushDoNotCheckForConflicts {
    return [self getBool:kSyncForcePushDoNotCheckForConflicts];
}

- (void)setSyncForcePushDoNotCheckForConflicts:(BOOL)syncForcePushDoNotCheckForConflicts {
    [self setBool:kSyncForcePushDoNotCheckForConflicts value:syncForcePushDoNotCheckForConflicts];
}

- (BOOL)syncPullEvenIfModifiedDateSame {
    return [self getBool:kSyncPullEvenIfModifiedDateSame];
}

- (void)setSyncPullEvenIfModifiedDateSame:(BOOL)syncPullEvenIfModifiedDateSame {
    [self setBool:kSyncPullEvenIfModifiedDateSame value:syncPullEvenIfModifiedDateSame];
}



- (NSData *)duressDummyData {
    return [self.sharedAppGroupDefaults objectForKey:@"dd-safe"];
}

- (void)setDuressDummyData:(NSData *)duressDummyData {
    NSUserDefaults* defaults = self.sharedAppGroupDefaults;
    [defaults setObject:duressDummyData forKey:@"dd-safe"];
    [defaults synchronize];
}



- (void)setPro:(BOOL)value {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    
    [userDefaults setBool:value forKey:kIsProKey];
    
    [userDefaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotificationKey object:nil];
}

- (BOOL)isProOrFreeTrial {
    return self.isPro || self.isFreeTrial;
}

- (BOOL)isPro {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    return [userDefaults boolForKey:kIsProKey];
}

- (BOOL)hasOptedInToFreeTrial {
    return self.freeTrialEnd != nil;
}

- (BOOL)isFreeTrial {
    NSDate* date = self.freeTrialEnd;
    
    if(date == nil) {
        
        return NO;
    }
    
    BOOL freeTrial = !([date timeIntervalSinceNow] < 0);
    
    NSLog(@"Free trial: %d Date: %@ - days remaining = [%ld]", freeTrial, date, (long)self.freeTrialDaysLeft);
    
    return freeTrial;
}

- (BOOL)freeTrialHasBeenOptedInAndExpired {
    return !self.isFreeTrial && self.freeTrialEnd;
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
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    
    
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setFreeTrialEnd:(NSDate *)freeTrialEnd {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    
    [userDefaults setObject:freeTrialEnd forKey:kEndFreeTrialDate];

    NSLog(@"Set Free trial end date to %@", freeTrialEnd);

    [userDefaults synchronize];
}



- (BOOL)colorizeUseColorBlindPalette {
    return [self getBool:kColorizeUseColorBlindPalette];
}

- (void)setColorizeUseColorBlindPalette:(BOOL)colorizeUseColorBlindPalette {
    [self setBool:kColorizeUseColorBlindPalette value:colorizeUseColorBlindPalette];
}

- (BOOL)clipboardHandoff {
    return [self getBool:kClipboardHandoff];
}

- (void)setClipboardHandoff:(BOOL)clipboardHandoff {
    return [self setBool:kClipboardHandoff value:clipboardHandoff];
}

- (PasswordGenerationConfig *)passwordGenerationConfig {
    NSUserDefaults *defaults = self.sharedAppGroupDefaults;
    NSData *encodedObject = [defaults objectForKey:kPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return [PasswordGenerationConfig defaults];
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setPasswordGenerationConfig:(PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationConfig];
    NSUserDefaults *defaults = self.sharedAppGroupDefaults;
    [defaults setObject:encodedObject forKey:kPasswordGenerationConfig];
    [defaults synchronize];
}

- (BOOL)hideTips {
    return [self getBool:kHideTips];
}

- (void)setHideTips:(BOOL)hideTips {
    [self setBool:kHideTips value:hideTips];
}

- (BOOL)disallowAllPinCodeOpens {
    return [self getBool:kDisallowAllPinCodeOpens];
}

- (void)setDisallowAllPinCodeOpens:(BOOL)disallowAllPinCodeOpens {
    [self setBool:kDisallowAllPinCodeOpens value:disallowAllPinCodeOpens];
}

- (BOOL)clearClipboardEnabled {
    return [self getBool:kClearClipboardEnabled fallback:YES];
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [self setBool:kClearClipboardEnabled value:clearClipboardEnabled];
}

- (NSInteger)clearClipboardAfterSeconds {
    NSInteger ret = [self getInteger:kClearClipboardAfterSeconds fallback:kDefaultClearClipboardTimeout];

    if(ret <= 0) { 
        [self setClearClipboardAfterSeconds:kDefaultClearClipboardTimeout];
        return kDefaultClearClipboardTimeout;
    }
    
    return ret;
}

-(void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    return [self setInteger:kClearClipboardAfterSeconds value:clearClipboardAfterSeconds];
}

- (BOOL)disallowAllBiometricId {
    return [self getBool:kDisallowBiometricId];
}

- (void)setDisallowAllBiometricId:(BOOL)disallowAllBiometricId {
    [self setBool:kDisallowBiometricId value:disallowAllBiometricId];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [self.sharedAppGroupDefaults objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [self.sharedAppGroupDefaults setObject:encoded forKey:kAutoFillNewRecordSettings];
    [self.sharedAppGroupDefaults synchronize];
}

- (NSString *)quickLaunchUuid {
    return [self getString:kQuickLaunchUuid];
}

- (void)setQuickLaunchUuid:(NSString *)quickLaunchUuid {
    [self setString:kQuickLaunchUuid value:quickLaunchUuid];
}

- (BOOL)allowEmptyOrNoPasswordEntry {
    return [self getBool:kAllowEmptyOrNoPasswordEntry fallback:NO];
}

- (void)setAllowEmptyOrNoPasswordEntry:(BOOL)allowEmptyOrNoPasswordEntry {
    [self setBool:kAllowEmptyOrNoPasswordEntry value:allowEmptyOrNoPasswordEntry];
}

- (BOOL)hideKeyFileOnUnlock {
    return [self getBool:kHideKeyFileOnUnlock];
}

- (void)setHideKeyFileOnUnlock:(BOOL)hideKeyFileOnUnlock {
    [self setBool:kHideKeyFileOnUnlock value:hideKeyFileOnUnlock];
}

- (BOOL)showAllFilesInLocalKeyFiles {
    return [self getBool:kShowAllFilesInLocalKeyFiles];
}

- (void)setShowAllFilesInLocalKeyFiles:(BOOL)showAllFilesInLocalKeyFiles {
    [self setBool:kShowAllFilesInLocalKeyFiles value:showAllFilesInLocalKeyFiles];
}

- (BOOL)monitorInternetConnectivity {
    return [self getBool:kMonitorInternetConnectivity fallback:YES];
}

- (void)setMonitorInternetConnectivity:(BOOL)monitorInternetConnectivity {
    [self setBool:kMonitorInternetConnectivity value:monitorInternetConnectivity];
}

- (BOOL)instantPinUnlocking {
    return [self getBool:kInstantPinUnlocking fallback:YES];
}

- (void)setInstantPinUnlocking:(BOOL)instantPinUnlocking {
    [self setBool:kInstantPinUnlocking value:instantPinUnlocking];
}

- (BOOL)iCloudOn {
    return [self getBool:kiCloudOn];
}

- (void)setICloudOn:(BOOL)iCloudOn {
    [self setBool:kiCloudOn value:iCloudOn];
}

- (FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [self.sharedAppGroupDefaults objectForKey:kFavIconDownloadOptions];

    if(encodedObject == nil) {
        return FavIconDownloadOptions.defaults;
    }

    FavIconDownloadOptions *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setFavIconDownloadOptions:(FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:favIconDownloadOptions];
    [self.sharedAppGroupDefaults setObject:encodedObject forKey:kFavIconDownloadOptions];
    [self.sharedAppGroupDefaults synchronize];
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
    return[self getInteger:kDatabaseCellTopSubtitle fallback:kDatabaseCellSubtitleFieldFileSize];
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
    return[self getInteger:kDatabaseCellSubtitle2 fallback:kDatabaseCellSubtitleFieldLastModifiedDate];
}

- (void)setDatabaseCellSubtitle2:(DatabaseCellSubtitleField)databaseCellSubtitle2 {
    [self setInteger:kDatabaseCellSubtitle2 value:databaseCellSubtitle2];
}



- (NSString*)getString:(NSString*)key {
    return [self getString:key fallback:nil];
}

- (NSString*)getString:(NSString*)key fallback:(NSString*)fallback {
    NSString* obj = [self.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [self.sharedAppGroupDefaults setObject:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [self.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [self.sharedAppGroupDefaults setBool:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

- (NSInteger)getInteger:(NSString*)key {
    return [self.sharedAppGroupDefaults integerForKey:key];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [self.sharedAppGroupDefaults objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [self.sharedAppGroupDefaults setInteger:value forKey:key];
    [self.sharedAppGroupDefaults synchronize];
}

@end
