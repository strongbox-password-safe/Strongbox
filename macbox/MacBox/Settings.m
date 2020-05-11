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

static const NSInteger kDefaultClearClipboardTimeout = 60;

static NSString* const kRevealDetailsImmediately = @"revealDetailsImmediately";
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
static NSString* const kDereferenceInQuickView = @"dereferenceInQuickView";
static NSString* const kDereferenceInOutlineView = @"dereferenceInOutlineView";
static NSString* const kDereferenceDuringSearch = @"dereferenceDuringSearch";
static NSString* const kAutoReloadAfterForeignChanges = @"autoReloadAfterForeignChanges";
static NSString* const kDetectForeignChanges = @"detectForeignChanges";
static NSString* const kConcealEmptyProtectedFields = @"concealEmptyProtectedFields";
static NSString* const kShowCustomFieldsOnQuickView = @"showCustomFieldsOnQuickView";
static NSString* const kPasswordGenerationConfig = @"passwordGenerationConfig";
static NSString* const kAutoOpenFirstDatabaseOnEmptyLaunch = @"autoOpenFirstDatabaseOnEmptyLaunch";
static NSString* const kAutoPromptForTouchIdOnActivate = @"autoPromptForTouchIdOnActivate";
static NSString* const kShowSystemTrayIcon = @"showSystemTrayIcon";
static NSString* const kFavIconDownloadOptions = @"favIconDownloadOptions";
static NSString* const kExpressDownloadFavIconOnNewOrUrlChanged = @"expressDownloadFavIconOnNewOrUrlChanged";
static NSString* const kAllowWatchUnlock = @"allowWatchUnlock";
static NSString* const kShowAttachmentsOnQuickViewPanel = @"showAttachmentsOnQuickViewPanel";
static NSString* const kShowAttachmentImagePreviewsOnQuickViewPanel = @"showAttachmentImagePreviewsOnQuickViewPanel";
static NSString* const kShowPasswordImmediatelyInOutline = @"showPasswordImmediatelyInOutline";

static NSString* const kHideKeyFileNameOnLockScreen = @"hideKeyFileNameOnLockScreen";
static NSString* const kDoNotRememberKeyFile = @"doNotRememberKeyFile";
static NSString* const kAllowEmptyOrNoPasswordEntry = @"allowEmptyOrNoPasswordEntry";
static NSString* const kHasDoneProFamilyCheck = @"hasDoneProFamilyCheck";
static NSString* const kColorizePasswords = @"colorizePasswords";
static NSString* const kColorizeUseColorBlindPalette = @"colorizeUseColorBlindPalette";

@implementation Settings

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

- (BOOL)hasDoneProFamilyCheck {
    return [self getBool:kHasDoneProFamilyCheck];
}

- (void)setHasDoneProFamilyCheck:(BOOL)hasDoneProFamilyCheck {
    return [self setBool:kHasDoneProFamilyCheck value:hasDoneProFamilyCheck];
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
    return [self getBool:kShowPasswordImmediatelyInOutline];
}

- (void)setShowPasswordImmediatelyInOutline:(BOOL)showPasswordImmediatelyInOutline {
    [self setBool:kShowPasswordImmediatelyInOutline value:showPasswordImmediatelyInOutline];
}

- (BOOL)allowWatchUnlock {
    return [self getBool:kAllowWatchUnlock fallback:YES];
}

- (void)setAllowWatchUnlock:(BOOL)allowWatchUnlock {
    [self setBool:kAllowWatchUnlock value:allowWatchUnlock];
}

- (BOOL)expressDownloadFavIconOnNewOrUrlChanged {
    return [self getBool:kExpressDownloadFavIconOnNewOrUrlChanged fallback:YES];
}

- (void)setExpressDownloadFavIconOnNewOrUrlChanged:(BOOL)expressDownloadFavIconOnNewOrUrlChanged {
    [self setBool:kExpressDownloadFavIconOnNewOrUrlChanged value:expressDownloadFavIconOnNewOrUrlChanged];
}

- (FavIconDownloadOptions *)favIconDownloadOptions {
    NSUserDefaults *defaults = [self getUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kFavIconDownloadOptions];

    if(encodedObject == nil) {
        return FavIconDownloadOptions.defaults;
    }

    FavIconDownloadOptions *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];

    return object;
}

- (void)setFavIconDownloadOptions:(FavIconDownloadOptions *)favIconDownloadOptions {
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:favIconDownloadOptions];
    NSUserDefaults *defaults = [self getUserDefaults];
    [defaults setObject:encodedObject forKey:kFavIconDownloadOptions];
    [defaults synchronize];
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

- (void)setAutoPromptForTouchIdOnActivate:(BOOL)autoPromptForTouchIdOnActivate {
    [self setBool:kAutoPromptForTouchIdOnActivate value:autoPromptForTouchIdOnActivate];
}

- (BOOL)autoOpenFirstDatabaseOnEmptyLaunch {
    return [self getBool:kAutoOpenFirstDatabaseOnEmptyLaunch];
}

- (void)setAutoOpenFirstDatabaseOnEmptyLaunch:(BOOL)autoOpenFirstDatabaseOnEmptyLaunch {
    [self setBool:kAutoOpenFirstDatabaseOnEmptyLaunch value:autoOpenFirstDatabaseOnEmptyLaunch];
}

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

- (NSUserDefaults*)getUserDefaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (instancetype)sharedInstance {
    static Settings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Settings alloc] init];
    });
    return sharedInstance;
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

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSNumber* obj = [userDefaults objectForKey:key];
    
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:value forKey:key];
    
    [userDefaults synchronize];
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
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    return [userDefaults objectForKey:kEndFreeTrialDate];
}

- (void)setEndFreeTrialDate:(NSDate *)endFreeTrialDate {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:endFreeTrialDate forKey:kEndFreeTrialDate];
    
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
        //        NSLog(@"No Autosave settings... defaulting to Yes");
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
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSArray<NSString*>* ret = [userDefaults objectForKey:kVisibleColumns];
    
    return ret ? ret : [Settings kDefaultVisibleColumns];
}

- (void)setVisibleColumns:(NSArray<NSString *> *)visibleColumns {
    if(!visibleColumns || !visibleColumns.count) {
        visibleColumns = [Settings kDefaultVisibleColumns];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:visibleColumns forKey:kVisibleColumns];
    [userDefaults synchronize];
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
    return [self getBool:kDereferenceInQuickView fallback:YES];
}

- (void)setDereferenceInQuickView:(BOOL)dereferenceInQuickView {
    [self setBool:kDereferenceInQuickView value:dereferenceInQuickView];
}

- (BOOL)dereferenceInOutlineView {
    return [self getBool:kDereferenceInOutlineView fallback:YES];
}

- (void)setDereferenceInOutlineView:(BOOL)dereferenceInOutlineView {
    [self setBool:kDereferenceInOutlineView value:dereferenceInOutlineView];
}

- (BOOL)dereferenceDuringSearch {
    return [self getBool:kDereferenceDuringSearch fallback:NO];
}

- (void)setDereferenceDuringSearch:(BOOL)dereferenceDuringSearch {
    [self setBool:kDereferenceDuringSearch value:dereferenceDuringSearch];
}

- (BOOL)autoReloadAfterForeignChanges {
    return [self getBool:kAutoReloadAfterForeignChanges fallback:NO];
}

- (void)setAutoReloadAfterForeignChanges:(BOOL)autoReloadAfterForeignChanges {
    [self setBool:kAutoReloadAfterForeignChanges value:autoReloadAfterForeignChanges];
}

- (BOOL)detectForeignChanges {
    return [self getBool:kDetectForeignChanges fallback:YES];
}

-(void)setDetectForeignChanges:(BOOL)detectForeignChanges {
    [self setBool:kDetectForeignChanges value:detectForeignChanges];
}

- (BOOL)concealEmptyProtectedFields {
    return [self getBool:kConcealEmptyProtectedFields fallback:YES];
}

- (void)setConcealEmptyProtectedFields:(BOOL)concealEmptyProtectedFields {
//    NSLog(@"Setting: %d", concealEmptyProtectedFields);
    [self setBool:kConcealEmptyProtectedFields value:concealEmptyProtectedFields];
}

- (BOOL)showCustomFieldsOnQuickViewPanel {
    return [self getBool:kShowCustomFieldsOnQuickView fallback:YES];
}

- (void)setShowCustomFieldsOnQuickViewPanel:(BOOL)showCustomFieldsOnQuickViewPanel {
    return [self setBool:kShowCustomFieldsOnQuickView value:showCustomFieldsOnQuickViewPanel];
}

- (BOOL)showAttachmentsOnQuickViewPanel {
    return [self getBool:kShowAttachmentsOnQuickViewPanel fallback:YES];
}

- (void)setShowAttachmentsOnQuickViewPanel:(BOOL)showAttachmentsOnQuickViewPanel {
    [self setBool:kShowAttachmentsOnQuickViewPanel value:showAttachmentsOnQuickViewPanel];
}

- (BOOL)showAttachmentImagePreviewsOnQuickViewPanel {
    return [self getBool:kShowAttachmentImagePreviewsOnQuickViewPanel fallback:YES];
}

- (void)setShowAttachmentImagePreviewsOnQuickViewPanel:(BOOL)showAttachmentImagePreviewsOnQuickViewPanel {
    [self setBool:kShowAttachmentImagePreviewsOnQuickViewPanel value:showAttachmentImagePreviewsOnQuickViewPanel];
}

@end
