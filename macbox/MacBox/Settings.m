//
//  Settings.m
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Settings.h"

static NSString* const kVisibleColumns = @"visibleColumns";

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



NSString *const kPreferenceGlobalShowShortcut = @"GlobalShowStrongboxHotKey-New";


static const NSInteger kDefaultClearClipboardTimeout = 60;

static NSString* const kShowQuickView = @"revealDetailsImmediately";
static NSString* const kFullVersion = @"fullVersion";
static NSString* const kEndFreeTrialDate = @"endFreeTrialDate";
static NSString* const kAutoLockTimeout = @"autoLockTimeout";
static NSString* const kWarnedAboutTouchId = @"warnedAboutTouchId";
static NSString* const kAlwaysShowPassword = @"alwaysShowPassword";
static NSString* const kUiDoNotSortKeePassNodesInBrowseView = @"uiDoNotSortKeePassNodesInBrowseView";
static NSString* const kAutoFillNewRecordSettings = @"autoFillNewRecordSettings";
static NSString* const kAutoSave = @"autoSave";
static NSString* const kClearClipboardEnabled = @"clearClipboardEnabled";
static NSString* const kClearClipboardAfterSeconds = @"clearClipboardAfterSeconds";
static NSString* const kDoNotShowTotp = @"doNotShowTotp";
static NSString* const kShowRecycleBinInSearchResults = @"showRecycleBinInSearchResults";
static NSString* const kDoNotShowRecycleBinInBrowse = @"doNotShowRecycleBinInBrowse";
static NSString* const kFloatOnTop = @"floatOnTop";
static NSString* const kNoAlternatingRows = @"noAlternatingRows";
static NSString* const kShowHorizontalGrid = @"showHorizontalGrid";
static NSString* const kShowVerticalGrid = @"showVerticalGrid";
static NSString* const kDoNotShowAutoCompleteSuggestions = @"doNotShowAutoCompleteSuggestions";
static NSString* const kDoNotShowChangeNotifications = @"doNotShowChangeNotifications";
static NSString* const kOutlineViewTitleIsReadonly = @"outlineViewTitleIsReadonly";
static NSString* const kOutlineViewEditableFieldsAreReadonly = @"outlineViewEditableFieldsAreReadonly";
static NSString* const kConcealEmptyProtectedFields = @"concealEmptyProtectedFields";
static NSString* const kShowCustomFieldsOnQuickView = @"showCustomFieldsOnQuickView";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kAutoPromptForTouchIdOnActivate = @"autoPromptForTouchIdOnActivate";
static NSString* const kShowSystemTrayIcon = @"showSystemTrayIcon";
static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kExpressDownloadFavIconOnNewOrUrlChanged = @"expressDownloadFavIconOnNewOrUrlChanged";
static NSString* const kShowAttachmentsOnQuickViewPanel = @"showAttachmentsOnQuickViewPanel";
static NSString* const kShowAttachmentImagePreviewsOnQuickViewPanel = @"showAttachmentImagePreviewsOnQuickViewPanel";
static NSString* const kShowPasswordImmediatelyInOutline = @"showPasswordImmediatelyInOutline";
static NSString* const kHideKeyFileNameOnLockScreen = @"hideKeyFileNameOnLockScreen";
static NSString* const kDoNotRememberKeyFile = @"doNotRememberKeyFile";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kColorizePasswords = @"colorizePasswords";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";
static NSString* const kClipboardHandoff = @"clipboardHandoff";
static NSString* const kMigratedToNewSettings = @"migratedToNewSettings";
static NSString* const kShowAdvancedUnlockOptions = @"showAdvancedUnlockOptions";
static NSString* const kStartWithSearch = @"startWithSearch";
static NSString* const kShowDatabasesManagerOnCloseAllWindows = @"showDatabasesManagerOnCloseAllWindows";
static NSString* const kShowAutoFillTotpCopiedMessage = @"showAutoFillTotpCopiedMessage";
static NSString* const kAutoLaunchSingleDatabase = @"autoLaunchSingleDatabase";
static NSString* const kLockDatabasesOnScreenLock = @"lockDatabasesOnScreenLock";
static NSString* const kUseLegacyFileProvider = @"useLegacyFileProvider-Release";
static NSString* const kHasMigratedToSyncManager = @"hasMigratedToSyncManager";
static NSString* const kHideDockIconOnAllMinimized = @"hideDockIconOnAllMinimized";



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

- (instancetype)init {
    self = [super init];
    if (self) {
        [self migrateToNewStore];
    }
    return self;
}

- (BOOL)migratedToNewStore {
    NSNumber* obj = [self.sharedAppGroupDefaults objectForKey:kMigratedToNewSettings];
    return obj != nil ? obj.boolValue : NO;
}

- (void)setMigratedToNewStore:(BOOL)migratedToNewStore {
    [self.sharedAppGroupDefaults setBool:migratedToNewStore forKey:kMigratedToNewSettings];
    [self.sharedAppGroupDefaults synchronize];
}

- (void)migrateToNewStore {
#ifndef IS_APP_EXTENSION
    if (self.migratedToNewStore) {

        return;
    }
    
    NSArray *keys = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys];
    for(NSString* key in keys){
        id value = [[NSUserDefaults standardUserDefaults] valueForKey:key];
        NSLog(@"Migrating... value: %@ forKey: %@", [[NSUserDefaults standardUserDefaults] valueForKey:key],key);
        [self.sharedAppGroupDefaults setValue:value forKey:key];
    }

    self.migratedToNewStore = YES;
#endif
}

- (NSString *)appGroupName {
    return kDefaultAppGroupName;
}

- (NSUserDefaults *)sharedAppGroupDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultAppGroupName];
    
    if(defaults == nil) {
        NSLog(@"ERROR: Could not get NSUserDefaults for Suite Name: [%@]", kDefaultAppGroupName);
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



- (BOOL)hideDockIconOnAllMinimized {
    return [self getBool:kHideDockIconOnAllMinimized];
}

- (void)setHideDockIconOnAllMinimized:(BOOL)hideDockIconOnAllMinimized {
    return [self setBool:kHideDockIconOnAllMinimized value:hideDockIconOnAllMinimized];
}

- (BOOL)hasMigratedToSyncManager {
    return [self getBool:kHasMigratedToSyncManager];
}

- (void)setHasMigratedToSyncManager:(BOOL)hasMigratedToSyncManager {
    [self setBool:kHasMigratedToSyncManager value:hasMigratedToSyncManager];
}

- (BOOL)useLegacyFileProvider {
    return [self getBool:kUseLegacyFileProvider];
}

- (void)setUseLegacyFileProvider:(BOOL)useLegacyFileProvider {
    [self setBool:kUseLegacyFileProvider value:useLegacyFileProvider];
}

- (BOOL)lockOnScreenLock {
    return [self getBool:kLockDatabasesOnScreenLock fallback:YES];
}

- (void)setLockOnScreenLock:(BOOL)lockDatabasesOnScreenLock {
    [self setBool:kLockDatabasesOnScreenLock value:lockDatabasesOnScreenLock];
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

- (BOOL)startWithSearch {
    return [self getBool:kStartWithSearch fallback:YES];
}

- (void)setStartWithSearch:(BOOL)startWithSearch {
    [self setBool:kStartWithSearch value:startWithSearch];
}

- (BOOL)showAdvancedUnlockOptions {
    return [self getBool:kShowAdvancedUnlockOptions];
}

- (void)setShowAdvancedUnlockOptions:(BOOL)showAdvancedUnlockOptions {
    [self setBool:kShowAdvancedUnlockOptions value:showAdvancedUnlockOptions];
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

- (BOOL)showPasswordImmediatelyInOutline {
    return NO;

}

- (void)setShowPasswordImmediatelyInOutline:(BOOL)showPasswordImmediatelyInOutline {
    [self setBool:kShowPasswordImmediatelyInOutline value:showPasswordImmediatelyInOutline];
}

- (BOOL)expressDownloadFavIconOnNewOrUrlChanged {
    return [self getBool:kExpressDownloadFavIconOnNewOrUrlChanged fallback:YES];
}

- (void)setExpressDownloadFavIconOnNewOrUrlChanged:(BOOL)expressDownloadFavIconOnNewOrUrlChanged {
    [self setBool:kExpressDownloadFavIconOnNewOrUrlChanged value:expressDownloadFavIconOnNewOrUrlChanged];
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

+ (NSArray<NSString*> *)kDefaultVisibleColumns 
{
    static NSArray *_arr;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _arr = @[kTitleColumn, kUsernameColumn, kPasswordColumn, kURLColumn];
    });
    
    return _arr;
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

- (BOOL)showQuickView {
    return [self getBool:kShowQuickView fallback:YES];
}

- (void)setShowQuickView:(BOOL)value {
    [self setBool:kShowQuickView value:value];
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
    return NO;

}

-(void)setAlwaysShowPassword:(BOOL)alwaysShowPassword {
    [self setBool:kAlwaysShowPassword value:alwaysShowPassword];
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
    
    if(date == nil) {
        return YES;
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

- (void)setEndFreeTrialDate:(NSDate *)endFreeTrialDate {
    
    
    [self.userDefaults setObject:endFreeTrialDate forKey:kEndFreeTrialDate];
    
    [self.userDefaults synchronize];
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

- (BOOL)uiDoNotSortKeePassNodesInBrowseView {
    return [self getBool:kUiDoNotSortKeePassNodesInBrowseView];
}

- (void)setUiDoNotSortKeePassNodesInBrowseView:(BOOL)uiDoNotSortKeePassNodesInBrowseView {
    [self setBool:kUiDoNotSortKeePassNodesInBrowseView value:uiDoNotSortKeePassNodesInBrowseView];
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

- (BOOL)floatOnTop {
    return [self getBool:kFloatOnTop];
}

- (void)setFloatOnTop:(BOOL)floatOnTop {
    [self setBool:kFloatOnTop value:floatOnTop];
}

- (BOOL)noAlternatingRows {
    return [self getBool:kNoAlternatingRows];
}

- (void)setNoAlternatingRows:(BOOL)noAlternatingRows {
    [self setBool:kNoAlternatingRows value:noAlternatingRows];
}

- (BOOL)showHorizontalGrid {
    return [self getBool:kShowHorizontalGrid];
}

- (void)setShowHorizontalGrid:(BOOL)showHorizontalGrid {
    [self setBool:kShowHorizontalGrid value:showHorizontalGrid];
}

- (BOOL)showVerticalGrid {
    return [self getBool:kShowVerticalGrid];
}

- (void)setShowVerticalGrid:(BOOL)showVerticalGrid {
    [self setBool:kShowVerticalGrid value:showVerticalGrid];
}

- (BOOL)doNotShowAutoCompleteSuggestions {
    return [self getBool:kDoNotShowAutoCompleteSuggestions];
}

- (void)setDoNotShowAutoCompleteSuggestions:(BOOL)doNotShowAutoCompleteSuggestions {
    [self setBool:kDoNotShowAutoCompleteSuggestions value:doNotShowAutoCompleteSuggestions];
}

- (BOOL)doNotShowChangeNotifications {
    return [self getBool:kDoNotShowChangeNotifications];
}

- (void)setDoNotShowChangeNotifications:(BOOL)doNotShowChangeNotifications {
    [self setBool:kDoNotShowChangeNotifications value:doNotShowChangeNotifications];
}

- (NSString *)easyReadFontName {
    return @"Menlo";
}

- (NSArray<NSString *> *)visibleColumns {
    NSArray<NSString*>* ret = [self.userDefaults objectForKey:kVisibleColumns];
    
    return ret ? ret : [Settings kDefaultVisibleColumns];
}

- (void)setVisibleColumns:(NSArray<NSString *> *)visibleColumns {
    if(!visibleColumns || !visibleColumns.count) {
        visibleColumns = [Settings kDefaultVisibleColumns];
    }
    
    [self.userDefaults setObject:visibleColumns forKey:kVisibleColumns];
    [self.userDefaults synchronize];
}

- (BOOL)outlineViewTitleIsReadonly {
    return [self getBool:kOutlineViewTitleIsReadonly];
}

- (void)setOutlineViewTitleIsReadonly:(BOOL)outlineViewTitleIsReadonly {
    [self setBool:kOutlineViewTitleIsReadonly value:outlineViewTitleIsReadonly];
}

- (BOOL)outlineViewEditableFieldsAreReadonly {
    return [self getBool:kOutlineViewEditableFieldsAreReadonly];
}

- (void)setOutlineViewEditableFieldsAreReadonly:(BOOL)outlineViewEditableFieldsAreReadonly {
    [self setBool:kOutlineViewEditableFieldsAreReadonly value:outlineViewEditableFieldsAreReadonly];
}

- (BOOL)dereferenceInQuickView {
    return YES;
}

- (BOOL)dereferenceInOutlineView {
    return YES;
}

- (BOOL)dereferenceDuringSearch {
    return YES;
}

- (BOOL)concealEmptyProtectedFields {
    return [self getBool:kConcealEmptyProtectedFields fallback:YES];
}

- (void)setConcealEmptyProtectedFields:(BOOL)concealEmptyProtectedFields {

    [self setBool:kConcealEmptyProtectedFields value:concealEmptyProtectedFields];
}

- (BOOL)showCustomFieldsOnQuickViewPanel {
    return YES;

}

- (void)setShowCustomFieldsOnQuickViewPanel:(BOOL)showCustomFieldsOnQuickViewPanel {
    return [self setBool:kShowCustomFieldsOnQuickView value:showCustomFieldsOnQuickViewPanel];
}

- (BOOL)showAttachmentsOnQuickViewPanel {
    return YES;


}

- (void)setShowAttachmentsOnQuickViewPanel:(BOOL)showAttachmentsOnQuickViewPanel {
    [self setBool:kShowAttachmentsOnQuickViewPanel value:showAttachmentsOnQuickViewPanel];
}

- (BOOL)showAttachmentImagePreviewsOnQuickViewPanel {
    return YES;

}

- (void)setShowAttachmentImagePreviewsOnQuickViewPanel:(BOOL)showAttachmentImagePreviewsOnQuickViewPanel {
    [self setBool:kShowAttachmentImagePreviewsOnQuickViewPanel value:showAttachmentImagePreviewsOnQuickViewPanel];
}

@end
