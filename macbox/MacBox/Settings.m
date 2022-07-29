//
//  Settings.m
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"
#import "NotificationConstants.h"
#import "Utils.h"
#import "Constants.h"
#import "Model.h"

NSString* const kTitleColumn = @"TitleColumn";
NSString* const kUsernameColumn = @"UsernameColumn";
NSString* const kPasswordColumn = @"PasswordColumn";
NSString* const kTOTPColumn = @"TOTPColumn";
NSString* const kURLColumn = @"URLColumn";
NSString* const kEmailColumn = @"EmailColumn";
NSString* const kNotesColumn = @"NotesColumn";
NSString* const kExpiresColumn = @"ExpiresColumn";
NSString* const kAttachmentsColumn = @"AttachmentsColumn";
NSString* const kCustomFieldsColumn = @"CustomFieldsColumn";



static const NSInteger kDefaultClearClipboardTimeout = 60;

static NSString* const kFullVersion = @"fullVersion";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kAutoLockTimeout = @"autoLockTimeout";

static NSString* const kAlwaysShowPassword = @"alwaysShowPassword";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kAutoSave = @"autoSave";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kFloatOnTop = @"floatOnTop";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kTrayPasswordGenerationConfig = @"trayPasswordGenerationConfig";
static NSString* const kAutoPromptForTouchIdOnActivate = @"autoPromptForTouchIdOnActivate";
static NSString* const kShowSystemTrayIcon = @"showSystemTrayIcon";
static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kShowPasswordImmediatelyInOutline = @"showPasswordImmediatelyInOutline";
static NSString* const kHideKeyFileNameOnLockScreen = @"hideKeyFileNameOnLockScreen";
static NSString* const kDoNotRememberKeyFile = @"doNotRememberKeyFile";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kColorizePasswords = @"colorizePasswords";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";
static NSString* const kClipboardHandoff = @"clipboardHandoff";
static NSString* const kShowDatabasesManagerOnCloseAllWindows = @"showDatabasesManagerOnCloseAllWindows";
static NSString* const kShowAutoFillTotpCopiedMessage = @"showAutoFillTotpCopiedMessage";
static NSString* const kAutoLaunchSingleDatabase = @"autoLaunchSingleDatabase";
static NSString* const kHideDockIconOnAllMinimized = @"hideDockIconOnAllMinimized";
static NSString* const kCloseManagerOnLaunch = @"closeManagerOnLaunch";
static NSString* const kMakeLocalRollingBackups = @"makeLocalRollingBackups";
static NSString* const kMiniaturizeOnCopy = @"miniaturizeOnCopy";
static NSString* const kQuickRevealWithOptionKey = @"quickRevealWithOptionKey";
static NSString* const kMarkdownNotes = @"markdownNotes";
static NSString* const kShowPasswordGenInTray = @"showPasswordGenInTray";
static NSString* const kNextGenUI = @"nextGenUI-Production-17-Mar-2022";
static NSString* const kAddOtpAuthUrl = @"addOtpAuthUrl";
static NSString* const kAddLegacySupplementaryTotpCustomFields = @"addLegacySupplementaryTotpCustomFields";
static NSString* const kQuitOnAllWindowsClosed = @"quitOnAllWindowsClosed";
static NSString* const kLastPromptedToUseNextGenUI = @"lastPromptedToUseNextGenUI";
static NSString* const kShowCopyFieldButton = @"showCopyFieldButton";
static NSString* const kLockEvenIfEditing = @"lockEvenIfEditing";
static NSString* const kScreenCaptureBlocked = @"screenCaptureBlocked";



static NSString* const kLastEntitlementCheckAttempt = @"lastEntitlementCheckAttempt";
static NSString* const kNumberOfEntitlementCheckFails = @"numberOfEntitlementCheckFails";
static NSString* const kAppHasBeenDowngradedToFreeEdition = @"appHasBeenDowngradedToFreeEdition";
static NSString* const kHasPromptedThatAppHasBeenDowngradedToFreeEdition = @"hasPromptedThatAppHasBeenDowngradedToFreeEdition";
static NSString* const kHasPromptedThatFreeTrialWillEndSoon = @"hasPromptedThatFreeTrialWillEndSoon";

static NSString* const kHasShownFirstRunWelcome = @"hasShownFirstRunWelcome";
static NSString* const kFreeTrialNudgeCount = @"freeTrialNudgeCount";
static NSString* const kLastFreeTrialNudge = @"lastFreeTrialNudge";
static NSString* const kInstallDate = @"installDate";
static NSString* const kLaunchCountKey = @"launchCountKey";
static NSString* const kUseIsolatedDropbox = @"useIsolatedDropbox";
static NSString* const kUseParentGroupIconOnCreate = @"useParentGroupIconOnCreate";
static NSString* const kStripUnusedIconsOnSave = @"stripUnusedIconsOnSave";



static NSString* const kDefaultAppGroupName = @"group.strongbox.mac.mcguill";



@implementation Settings

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    return sharedInstance;
}

- (NSString *)appGroupName {
    return kDefaultAppGroupName;
}

- (NSUserDefaults *)sharedAppGroupDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultAppGroupName];
    
    if(defaults == nil) {
        NSLog(@"🔴 ERROR: Could not get NSUserDefaults for Suite Name: [%@]", kDefaultAppGroupName);
    }
    
    return defaults;
}

- (NSUserDefaults*)userDefaults {
    return self.sharedAppGroupDefaults;
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [self.userDefaults objectForKey:key];
    
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [self.userDefaults setBool:value forKey:key];
    [self.userDefaults synchronize];
}









- (BOOL)stripUnusedIconsOnSave {
    return YES;
    
    return [self getBool:kStripUnusedIconsOnSave];
}

- (void)setStripUnusedIconsOnSave:(BOOL)stripUnusedIconsOnSave {
    return [self setBool:kStripUnusedIconsOnSave value:stripUnusedIconsOnSave];
}

- (BOOL)useParentGroupIconOnCreate {
    return [self getBool:kUseParentGroupIconOnCreate fallback:YES];
}

- (void)setUseParentGroupIconOnCreate:(BOOL)useParentGroupIconOnCreate {
    [self setBool:kUseParentGroupIconOnCreate value:useParentGroupIconOnCreate];
}

- (BOOL)useIsolatedDropbox {
    return [self getBool:kUseIsolatedDropbox];
}

- (void)setUseIsolatedDropbox:(BOOL)useIsolatedDropbox {
    [self setBool:kUseIsolatedDropbox value:useIsolatedDropbox];
}



- (NSDate *)installDate {
    return [self.userDefaults objectForKey:kInstallDate];
}

- (void)setInstallDate:(NSDate *)installDate {
    [self.userDefaults setObject:installDate forKey:kInstallDate];
}

- (NSInteger)daysInstalled {
    NSDate* installDate = self.installDate;

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

- (NSUInteger)launchCount {
    return [self.userDefaults integerForKey:kLaunchCountKey];
}

- (void)incrementLaunchCount {
    NSUInteger launchCount = self.launchCount;
    
    launchCount++;
    
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    
    [self.userDefaults setInteger:launchCount forKey:kLaunchCountKey];
    [self.userDefaults synchronize];
}



- (NSUInteger)freeTrialOrUpgradeNudgeCount {
    return [self.sharedAppGroupDefaults integerForKey:kFreeTrialNudgeCount];
}

- (void)setFreeTrialOrUpgradeNudgeCount:(NSUInteger)freeTrialOrUpgradeNudgeCount {
    [self.sharedAppGroupDefaults setInteger:freeTrialOrUpgradeNudgeCount forKey:kFreeTrialNudgeCount];
}

- (NSDate *)lastFreeTrialOrUpgradeNudge {
    NSDate* ret = [self.sharedAppGroupDefaults objectForKey:kLastFreeTrialNudge];
    
    return ret ? ret : NSDate.date;
}

- (void)setLastFreeTrialOrUpgradeNudge:(NSDate *)lastFreeTrialOrUpgradeNudge {
    [self.sharedAppGroupDefaults setObject:lastFreeTrialOrUpgradeNudge forKey:kLastFreeTrialNudge];
}

- (NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    
    return [userDefaults objectForKey:kLastEntitlementCheckAttempt];
}

- (void)setLastEntitlementCheckAttempt:(NSDate *)lastEntitlementCheckAttempt {
    NSUserDefaults *userDefaults = self.sharedAppGroupDefaults;
    [userDefaults setObject:lastEntitlementCheckAttempt forKey:kLastEntitlementCheckAttempt];
    [userDefaults synchronize];
}

- (NSUInteger)numberOfEntitlementCheckFails {
    NSInteger ret =  [self.sharedAppGroupDefaults integerForKey:kNumberOfEntitlementCheckFails];
    return ret;
}

- (void)setNumberOfEntitlementCheckFails:(NSUInteger)numberOfEntitlementCheckFails {
    [self.sharedAppGroupDefaults setInteger:numberOfEntitlementCheckFails forKey:kNumberOfEntitlementCheckFails];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)appHasBeenDowngradedToFreeEdition {
    return [self getBool:kAppHasBeenDowngradedToFreeEdition];
}

- (void)setAppHasBeenDowngradedToFreeEdition:(BOOL)appHasBeenDowngradedToFreeEdition {
    [self setBool:kAppHasBeenDowngradedToFreeEdition value:appHasBeenDowngradedToFreeEdition];
}

- (BOOL)hasPromptedThatAppHasBeenDowngradedToFreeEdition {
    return [self getBool:kHasPromptedThatAppHasBeenDowngradedToFreeEdition];
}

- (void)setHasPromptedThatAppHasBeenDowngradedToFreeEdition:(BOOL)hasPromptedThatAppHasBeenDowngradedToFreeEdition {
    [self setBool:kHasPromptedThatAppHasBeenDowngradedToFreeEdition value:hasPromptedThatAppHasBeenDowngradedToFreeEdition];
}























- (void)setPro:(BOOL)value {
    [self setFullVersion:value];
}











- (BOOL)screenCaptureBlocked {
    return [self getBool:kScreenCaptureBlocked fallback:YES];
}

- (void)setScreenCaptureBlocked:(BOOL)screenCaptureBlocked {
    [self setBool:kScreenCaptureBlocked value:screenCaptureBlocked];
}

- (BOOL)lockEvenIfEditing {
    return [self getBool:kLockEvenIfEditing fallback:YES];
}

- (void)setLockEvenIfEditing:(BOOL)lockEvenIfEditing {
    [self setBool:kLockEvenIfEditing value:lockEvenIfEditing];
}

- (BOOL)showCopyFieldButton {
    return [self getBool:kShowCopyFieldButton fallback:YES];
}

- (void)setShowCopyFieldButton:(BOOL)showCopyFieldButton {
    [self setBool:kShowCopyFieldButton value:showCopyFieldButton];
}

- (BOOL)quitStrongboxOnAllWindowsClosed {
    return [self getBool:kQuitOnAllWindowsClosed fallback:NO];
}

- (void)setQuitStrongboxOnAllWindowsClosed:(BOOL)quitStrongboxOnAllWindowsClosed {
    [self setBool:kQuitOnAllWindowsClosed value:quitStrongboxOnAllWindowsClosed];
}

- (BOOL)addOtpAuthUrl {
    return [self getBool:kAddOtpAuthUrl fallback:YES];
}

- (void)setAddOtpAuthUrl:(BOOL)addOtpAuthUrl {
    [self setBool:kAddOtpAuthUrl value:addOtpAuthUrl];
}

- (BOOL)addLegacySupplementaryTotpCustomFields {
    return [self getBool:kAddLegacySupplementaryTotpCustomFields fallback:NO];
}

- (void)setAddLegacySupplementaryTotpCustomFields:(BOOL)addLegacySupplementaryTotpCustomFields {
    [self setBool:kAddLegacySupplementaryTotpCustomFields value:addLegacySupplementaryTotpCustomFields];
}

- (BOOL)checkPinYin {
    return NO;
}

- (void)setCheckPinYin:(BOOL)checkPinYin {
    
}

- (BOOL)runningAsATrayApp {
    return Settings.sharedInstance.showSystemTrayIcon && Settings.sharedInstance.hideDockIconOnAllMinimized;
}

- (BOOL)showPasswordGenInTray {
    return [self getBool:kShowPasswordGenInTray fallback:YES];
}

- (void)setShowPasswordGenInTray:(BOOL)showPasswordGenInTray {
    [self setBool:kShowPasswordGenInTray value:showPasswordGenInTray];
}

- (BOOL)markdownNotes {
    return [self getBool:kMarkdownNotes];
}

- (void)setMarkdownNotes:(BOOL)markdownNotes {
    [self setBool:kMarkdownNotes value:markdownNotes];
}

- (BOOL)quickRevealWithOptionKey {
    return [self getBool:kQuickRevealWithOptionKey fallback:YES]; 
}

- (void)setQuickRevealWithOptionKey:(BOOL)quickRevealWithOptionKey {
    [self setBool:kQuickRevealWithOptionKey value:quickRevealWithOptionKey];
}

- (BOOL)miniaturizeOnCopy {
    return [self getBool:kMiniaturizeOnCopy fallback:NO];
}

- (void)setMiniaturizeOnCopy:(BOOL)miniaturizeOnCopy {
    [self setBool:kMiniaturizeOnCopy value:miniaturizeOnCopy];
}

- (NSDate *)lastPromptedToUseNextGenUI {
    return [self.sharedAppGroupDefaults objectForKey:kLastPromptedToUseNextGenUI];
}

- (void)setLastPromptedToUseNextGenUI:(NSDate *)lastPromptedToUseNextGenUI {
    [self.sharedAppGroupDefaults setObject:lastPromptedToUseNextGenUI forKey:kLastPromptedToUseNextGenUI];
    [self.sharedAppGroupDefaults synchronize];
}

- (BOOL)nextGenUI {
    if (@available(macOS 11.0, *)) {
        return [self getBool:kNextGenUI fallback:YES];
    }
    else {
        return NO;
    }
}

- (void)setNextGenUI:(BOOL)nextGenUI {
    [self setBool:kNextGenUI value:nextGenUI];
}

- (BOOL)makeLocalRollingBackups {
    return [self getBool:kMakeLocalRollingBackups fallback:YES];
}

- (void)setMakeLocalRollingBackups:(BOOL)makeLocalRollingBackups {
    [self setBool:kMakeLocalRollingBackups value:makeLocalRollingBackups];
}

- (BOOL)closeManagerOnLaunch {
    return [self getBool:kCloseManagerOnLaunch fallback:YES];
}

- (void)setCloseManagerOnLaunch:(BOOL)closeManagerOnLaunch {
    [self setBool:kCloseManagerOnLaunch value:closeManagerOnLaunch];
}

- (BOOL)hideDockIconOnAllMinimized {
    return [self getBool:kHideDockIconOnAllMinimized];
}

- (void)setHideDockIconOnAllMinimized:(BOOL)hideDockIconOnAllMinimized {
    return [self setBool:kHideDockIconOnAllMinimized value:hideDockIconOnAllMinimized];
}

- (BOOL)autoFillAutoLaunchSingleDatabase {
    return [self getBool:kAutoLaunchSingleDatabase fallback:YES];
}

- (void)setAutoFillAutoLaunchSingleDatabase:(BOOL)autoFillAutoLaunchSingleDatabase {
    return [self setBool:kAutoLaunchSingleDatabase value:autoFillAutoLaunchSingleDatabase];
}

- (BOOL)showAutoFillTotpCopiedMessage {
    return [self getBool:kShowAutoFillTotpCopiedMessage fallback:YES];
}

- (void)setShowAutoFillTotpCopiedMessage:(BOOL)showAutoFillTotpCopiedMessage {
    [self setBool:kShowAutoFillTotpCopiedMessage value:showAutoFillTotpCopiedMessage];
}

- (BOOL)showDatabasesManagerOnCloseAllWindows {
    return [self getBool:kShowDatabasesManagerOnCloseAllWindows fallback:YES];
}

- (void)setShowDatabasesManagerOnCloseAllWindows:(BOOL)showDatabasesManagerOnCloseAllWindows {
    [self setBool:kShowDatabasesManagerOnCloseAllWindows value:showDatabasesManagerOnCloseAllWindows];
}

- (BOOL)clipboardHandoff {
    return [self getBool:kClipboardHandoff fallback:NO]; 
}

- (void)setClipboardHandoff:(BOOL)clipboardHandoff {
    [self setBool:kClipboardHandoff value:clipboardHandoff];
}

- (BOOL)colorizeUseColorBlindPalette {
    return [self getBool:kColorizeUseColorBlindPalette];
}

- (void)setColorizeUseColorBlindPalette:(BOOL)colorizeUseColorBlindPalette {
    [self setBool:kColorizeUseColorBlindPalette value:colorizeUseColorBlindPalette];
}

- (BOOL)colorizePasswords {
    return [self getBool:kColorizePasswords fallback:YES];
}

- (void)setColorizePasswords:(BOOL)colorizePasswords {
    [self setBool:kColorizePasswords value:colorizePasswords];
}

- (BOOL)allowEmptyOrNoPasswordEntry {
    return [self getBool:kAllowEmptyOrNoPasswordEntry];
}

- (void)setAllowEmptyOrNoPasswordEntry:(BOOL)allowEmptyOrNoPasswordEntry {
    [self setBool:kAllowEmptyOrNoPasswordEntry value:allowEmptyOrNoPasswordEntry];
}

- (BOOL)hideKeyFileNameOnLockScreen {
    return [self getBool:kHideKeyFileNameOnLockScreen];
}

- (void)setHideKeyFileNameOnLockScreen:(BOOL)hideKeyFileNameOnLockScreen {
    [self setBool:kHideKeyFileNameOnLockScreen value:hideKeyFileNameOnLockScreen];
}

- (BOOL)doNotRememberKeyFile {
    return [self getBool:kDoNotRememberKeyFile];
}

- (void)setDoNotRememberKeyFile:(BOOL)doNotRememberKeyFile {
    [self setBool:kDoNotRememberKeyFile value:doNotRememberKeyFile];
}

- (FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [self.userDefaults objectForKey:kFavIconDownloadOptions];

    if(encodedObject == nil) {
        return FavIconDownloadOptions.defaults;
    }

    FavIconDownloadOptions *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setFavIconDownloadOptions:(FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:favIconDownloadOptions];
    [self.userDefaults setObject:encodedObject forKey:kFavIconDownloadOptions];
    [self.userDefaults synchronize];
}

- (BOOL)showSystemTrayIcon {
    return [self getBool:kShowSystemTrayIcon fallback:YES];
}

- (void)setShowSystemTrayIcon:(BOOL)showSystemTrayIcon {
    [self setBool:kShowSystemTrayIcon value:showSystemTrayIcon];
}

- (BOOL)autoPromptForTouchIdOnActivate {
    return [self getBool:kAutoPromptForTouchIdOnActivate fallback:YES];
}

- (PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [self.userDefaults objectForKey:kPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return [PasswordGenerationConfig defaults];
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setPasswordGenerationConfig:(PasswordGenerationConfig *)passwordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:passwordGenerationConfig];
    [self.userDefaults setObject:encodedObject forKey:kPasswordGenerationConfig];
    [self.userDefaults synchronize];
}

- (PasswordGenerationConfig *)trayPasswordGenerationConfig {
    NSData *encodedObject = [self.userDefaults objectForKey:kTrayPasswordGenerationConfig];
    
    if(encodedObject == nil) {
        return self.passwordGenerationConfig; 
    }
    
    PasswordGenerationConfig *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    
    return object;
}

- (void)setTrayPasswordGenerationConfig:(PasswordGenerationConfig *)trayPasswordGenerationConfig {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:trayPasswordGenerationConfig];
    [self.userDefaults setObject:encodedObject forKey:kTrayPasswordGenerationConfig];
    [self.userDefaults synchronize];
}

+ (NSArray<NSString*> *)kAllColumns
{
    static NSArray *_arr;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _arr = @[kTitleColumn, kUsernameColumn, kPasswordColumn, kTOTPColumn, kURLColumn, kEmailColumn, kNotesColumn, kExpiresColumn, kAttachmentsColumn, kCustomFieldsColumn];
    });
    
    return _arr;
}

- (BOOL)fullVersion {
    return [self getBool:kFullVersion];
}

- (void)setFullVersion:(BOOL)value {
    [self setBool:kFullVersion value:value];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotificationKey object:nil];
}

- (BOOL)isProOrFreeTrial {
    return self.isPro || self.freeTrial;
}

- (BOOL)isPro {
    return self.fullVersion;
}

- (BOOL)isFreeTrial {
    return self.freeTrial;
}

- (BOOL)freeTrial {
    NSDate* date = self.endFreeTrialDate;
    
    if ( date == nil ) {
        return NO;
    }
    
    BOOL ret = !([date timeIntervalSinceNow] < 0);

    return ret;
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
    return [self.userDefaults objectForKey:kEndFreeTrialDate];
}

- (NSInteger)autoLockTimeoutSeconds {
    return [self.userDefaults integerForKey:kAutoLockTimeout];
}

- (void)setAutoLockTimeoutSeconds:(NSInteger)autoLockTimeoutSeconds {
    
    
    [self.userDefaults setInteger:autoLockTimeoutSeconds forKey:kAutoLockTimeout];
    
    [self.userDefaults synchronize];
}

- (AutoFillNewRecordSettings*)autoFillNewRecordSettings {
    NSData *data = [self.userDefaults objectForKey:kAutoFillNewRecordSettings];
    
    if(data) {
        return (AutoFillNewRecordSettings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return AutoFillNewRecordSettings.defaults;
}

- (void)setAutoFillNewRecordSettings:(AutoFillNewRecordSettings *)autoFillNewRecordSettings {
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:autoFillNewRecordSettings];
    
    [self.userDefaults setObject:encoded forKey:kAutoFillNewRecordSettings];
    [self.userDefaults synchronize];
}

-(BOOL)autoSave {
    
    
    NSObject* autoSave = [self.userDefaults objectForKey:kAutoSave];

    BOOL ret = TRUE;
    if(!autoSave) {
        
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

- (BOOL)clearClipboardEnabled {
    return [self getBool:kClearClipboardEnabled fallback:YES]; 
}

- (void)setClearClipboardEnabled:(BOOL)clearClipboardEnabled {
    [self setBool:kClearClipboardEnabled value:clearClipboardEnabled];
}

- (NSInteger)clearClipboardAfterSeconds {
    
    NSInteger ret = [self.userDefaults integerForKey:kClearClipboardAfterSeconds];

    return ret == 0 ? kDefaultClearClipboardTimeout : ret;
}


- (void)setClearClipboardAfterSeconds:(NSInteger)clearClipboardAfterSeconds {
    
    
    [self.userDefaults setInteger:clearClipboardAfterSeconds forKey:kClearClipboardAfterSeconds];
    
    [self.userDefaults synchronize];
}

- (BOOL)floatOnTop {
    return [self getBool:kFloatOnTop];
}

- (void)setFloatOnTop:(BOOL)floatOnTop {
    [self setBool:kFloatOnTop value:floatOnTop];
}

- (NSString *)easyReadFontName {
    return @"Menlo";
}



- (BOOL)revealPasswordsImmediately {
    return [self getBool:kShowPasswordImmediatelyInOutline] || [self getBool:kAlwaysShowPassword];
}

- (void)setRevealPasswordsImmediately:(BOOL)revealPasswordsImmediately {
    [self setBool:kShowPasswordImmediatelyInOutline value:revealPasswordsImmediately];
    [self setBool:kAlwaysShowPassword value:revealPasswordsImmediately];
}



- (NSData *)duressDummyData {
    NSLog(@"🔴 NOTIMPL: duressDummyData");
    return nil;
}

- (void)setDuressDummyData:(NSData *)duressDummyData {
    NSLog(@"🔴 NOTIMPL: setDuressDummyData");
}

- (PasswordStrengthConfig *)passwordStrengthConfig {
    return PasswordStrengthConfig.defaults;
}

- (void)setPasswordStrengthConfig:(PasswordStrengthConfig *)passwordStrengthConfig {
    NSLog(@"🔴 NOTIMPL: setPasswordStrengthConfig");
}

- (BOOL)databasesAreAlwaysReadOnly {
    return NO;
}

- (void)setDatabasesAreAlwaysReadOnly:(BOOL)databasesAreAlwaysReadOnly {
    
}

- (BOOL)hasShownFirstRunWelcome {
    return [self getBool:kHasShownFirstRunWelcome];
}

- (void)setHasShownFirstRunWelcome:(BOOL)hasShownFirstRunWelcome {
    [self setBool:kHasShownFirstRunWelcome value:hasShownFirstRunWelcome];
}

@end
