//
//  DatabasePreferences.m
//  Strongbox
//
//  Created by Strongbox on 04/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabasePreferences.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "BrowseSortConfiguration.h"

@interface DatabasePreferences ()

@property (readonly) SafeMetaData* metadata;
@property (readonly) SafeMetaData* templateDummy;

@end

@implementation DatabasePreferences

+ (instancetype)fromUuid:(NSString *)uuid {
    return [[DatabasePreferences alloc] initWithUuid:uuid];
}

+ (NSArray<DatabasePreferences *> *)forAllDatabasesOfProvider:(StorageProvider)provider {
    return [[SafesList.sharedInstance getSafesOfProvider:provider] map:^id _Nonnull(SafeMetaData * _Nonnull obj, NSUInteger idx) {
        return [DatabasePreferences fromUuid:obj.uuid];
    }];
}

+ (NSArray<DatabasePreferences *> *)filteredDatabases:(BOOL (^)(DatabasePreferences * _Nonnull))block {
    return [DatabasePreferences.allDatabases filter:block];
}

+ (NSArray<DatabasePreferences *> *)allDatabases {
    return [SafesList.sharedInstance.snapshot map:^id _Nonnull(SafeMetaData * _Nonnull obj, NSUInteger idx) {
        return [DatabasePreferences fromUuid:obj.uuid];
    }];
}

+ (NSArray<DatabasePreferences *> *)iCloudDatabases {
    return [DatabasePreferences forAllDatabasesOfProvider:kiCloud];
}

+ (NSArray<DatabasePreferences *> *)localDeviceDatabases {
    return [DatabasePreferences forAllDatabasesOfProvider:kLocalDevice];
}

+ (instancetype)templateDummyWithNickName:(NSString *)nickName
                          storageProvider:(StorageProvider)storageProvider
                                 fileName:(NSString *)fileName
                           fileIdentifier:(NSString *)fileIdentifier {
    return [[DatabasePreferences alloc] initAsTemplateDummyWithNickName:nickName storageProvider:storageProvider fileName:fileName fileIdentifier:fileIdentifier];
}



- (instancetype)initWithUuid:(NSString*)uuid {
    self = [super init];
    if (self) {
        if ( [SafesList.sharedInstance getById:uuid] != nil ) {
            _uuid = uuid;
            _templateDummy = nil;
        }
        else {
            return nil;
        }
    }
    return self;
}

- (instancetype)initAsTemplateDummyWithNickName:(NSString *)nickName
                              storageProvider:(StorageProvider)storageProvider
                                     fileName:(NSString *)fileName
                               fileIdentifier:(NSString *)fileIdentifier  {
    self = [super init];
    if (self) {
        _templateDummy = [[SafeMetaData alloc] initWithNickName:nickName storageProvider:storageProvider fileName:fileName fileIdentifier:fileIdentifier];
        _uuid = self.templateDummy.uuid;
    }
    return self;
}



+ (NSString *)trimDatabaseNickName:(NSString *)string {
    return [SafesList trimDatabaseNickName:string];
}

+ (NSString *)suggestedDatabaseNameUsingDeviceName {
    return [SafesList.sharedInstance getSuggestedDatabaseNameUsingDeviceName];
}

- (void)add:(NSData *)initialCache initialCacheModDate:(NSDate *)initialCacheModDate {
    if ( self.templateDummy ) {
        [SafesList.sharedInstance add:self.templateDummy initialCache:initialCache initialCacheModDate:initialCacheModDate];
    }
    else {
        NSLog(@"🔴 WARNWARN: Attempt to add an existing database to the list");
    }
}

- (void)addWithDuplicateCheck:(NSData *)initialCache initialCacheModDate:(NSDate *)initialCacheModDate {
    if ( self.templateDummy ) {
        NSString* newUuid = [SafesList.sharedInstance addWithDuplicateCheck:self.templateDummy
                                                               initialCache:initialCache
                                                        initialCacheModDate:initialCacheModDate];
        
        if ( newUuid ) {
            NSLog(@"✅ Duplicate found - changing UUID of this database to match...");
            _uuid = newUuid;
        }
    }
    else {
        NSLog(@"🔴 WARNWARN: Attempt to add an existing database to the list");
    }
}



- (void)removeFromDatabasesList {
    [SafesList.sharedInstance remove:self.uuid];
}

- (void)clearKeychainItems {
    [self.metadata clearKeychainItems];
}

+ (void)notifyDatabaseChanged:(NSString *)databaseIdChanged {
    [SafesList.sharedInstance notifyDatabaseChanged:databaseIdChanged];
}

+ (void)notifyDatabasesListChanged {
    [SafesList.sharedInstance notifyDatabasesListChanged];
}

+ (BOOL)isValid:(NSString *)nickName {
    return [SafesList.sharedInstance isValid:nickName];
}

+ (BOOL)isUnique:(NSString *)nickName {
    return [SafesList.sharedInstance isUnique:nickName];
}

+ (void)reloadIfChangedByOtherComponent {
    [SafesList.sharedInstance reloadIfChangedByOtherComponent];
}

+ (BOOL)isEditing:(DatabasePreferences *)database {
    SafeMetaData* meta = database.metadata;
    return [SafesList.sharedInstance isEditing:meta];
}

+ (void)setEditing:(DatabasePreferences *)database editing:(BOOL)editing {
    SafeMetaData* meta = database.metadata;
    [SafesList.sharedInstance setEditing:meta editing:editing];
}

+ (void)deleteAll {
    [SafesList.sharedInstance deleteAll];
}

- (NSDictionary *)getJsonSerializationDictionary {
    return [self.metadata getJsonSerializationDictionary];
}

+ (NSString *)getUniqueNameFromSuggestedName:(NSString *)suggested {
    return [SafesList.sharedInstance getUniqueNameFromSuggestedName:suggested];
}

+ (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    [SafesList.sharedInstance move:sourceIndex to:destinationIndex];
}



- (SafeMetaData *)metadata {
    if ( self.templateDummy ) {
        return self.templateDummy;
    }
    else {
        
        return [SafesList.sharedInstance getById:self.uuid];
    }
}

- (void)update:(void (^)(SafeMetaData * _Nonnull metadata))touch {
    if ( self.templateDummy ) {
        touch(self.templateDummy);
    }
    else {
        [SafesList.sharedInstance atomicUpdate:self.uuid touch:touch];
    }
}



- (NSString *)nickName {
    return self.metadata.nickName;
}

- (void)setNickName:(NSString *)nickName {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.nickName = nickName;
    }];
}



- (NSString *)fileName {
    return self.metadata.fileName;
}

- (void)setFileName:(NSString *)fileName {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.fileName = fileName;
    }];
}



- (NSString *)fileIdentifier {
    return self.metadata.fileIdentifier;
}

- (void)setFileIdentifier:(NSString *)fileIdentifier {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.fileIdentifier = fileIdentifier;
    }];
}



- (StorageProvider)storageProvider {
    return self.metadata.storageProvider;
}

- (void)setStorageProvider:(StorageProvider)storageProvider {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.storageProvider = storageProvider;
    }];
}



- (BOOL)hasBeenPromptedForQuickLaunch {
    return self.metadata.hasBeenPromptedForQuickLaunch;
}

- (void)setHasBeenPromptedForQuickLaunch:(BOOL)hasBeenPromptedForQuickLaunch {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hasBeenPromptedForQuickLaunch = hasBeenPromptedForQuickLaunch;
    }];
}



- (DuressAction)duressAction {
    return self.metadata.duressAction;
}

- (void)setDuressAction:(DuressAction)duressAction {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.duressAction = duressAction;
    }];
}



- (int)failedPinAttempts {
    return self.metadata.failedPinAttempts;
}

- (void)setFailedPinAttempts:(int)failedPinAttempts {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.failedPinAttempts = failedPinAttempts;
    }];
}



- (BOOL)autoFillEnabled {
    return self.metadata.autoFillEnabled;
}

- (void)setAutoFillEnabled:(BOOL)autoFillEnabled {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillEnabled = autoFillEnabled;
    }];
}



- (BOOL)hasUnresolvedConflicts {
    return self.metadata.hasUnresolvedConflicts;
}

- (void)setHasUnresolvedConflicts:(BOOL)hasUnresolvedConflicts {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hasUnresolvedConflicts = hasUnresolvedConflicts;
    }];
}



- (NSString *)keyFileBookmark {
    return self.metadata.keyFileBookmark;
}

- (NSString *)keyFileFileName {
    return self.metadata.keyFileFileName;
}

- (void)setKeyFile:(NSString*)keyFileBookmark keyFileFileName:(NSString*)keyFileFileName {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        [metadata setKeyFile:keyFileBookmark keyFileFileName:keyFileFileName];
    }];
}



- (DatabaseFormat)likelyFormat {
    return self.metadata.likelyFormat;
}

- (void)setLikelyFormat:(DatabaseFormat)likelyFormat {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.likelyFormat = likelyFormat;
    }];
}



- (BOOL)readOnly {
    return self.metadata.readOnly;
}

- (void)setReadOnly:(BOOL)readOnly {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.readOnly = readOnly;
    }];
}



- (BrowseViewType)browseViewType {
    return self.metadata.browseViewType;
}

- (void)setBrowseViewType:(BrowseViewType)browseViewType {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.browseViewType = browseViewType;
    }];
}



- (BrowseTapAction)tapAction {
    return self.metadata.tapAction;
}

- (void)setTapAction:(BrowseTapAction)tapAction {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.tapAction = tapAction;
    }];
}



- (BrowseSortField)browseSortField {
    return self.metadata.browseSortField;
}

- (void)setBrowseSortField:(BrowseSortField)browseSortField {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.browseSortField = browseSortField;
    }];
}



- (BOOL)browseSortOrderDescending {
    return self.metadata.browseSortOrderDescending;
}

- (void)setBrowseSortOrderDescending:(BOOL)browseSortOrderDescending {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.browseSortOrderDescending = browseSortOrderDescending;
    }];
}



- (BOOL)browseSortFoldersSeparately {
    return self.metadata.browseSortFoldersSeparately;
}

- (void)setBrowseSortFoldersSeparately:(BOOL)browseSortFoldersSeparately {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.browseSortFoldersSeparately = browseSortFoldersSeparately;
    }];
}



- (BrowseItemSubtitleField)browseItemSubtitleField {
    return self.metadata.browseItemSubtitleField;
}

- (void)setBrowseItemSubtitleField:(BrowseItemSubtitleField)browseItemSubtitleField {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.browseItemSubtitleField = browseItemSubtitleField;
    }];
}



- (BOOL)immediateSearchOnBrowse {
    return self.metadata.immediateSearchOnBrowse;
}

- (void)setImmediateSearchOnBrowse:(BOOL)immediateSearchOnBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.immediateSearchOnBrowse = immediateSearchOnBrowse;
    }];
}



- (BOOL)hideTotpInBrowse {
    return self.metadata.hideTotpInBrowse;
}

- (void)setHideTotpInBrowse:(BOOL)hideTotpInBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hideTotpInBrowse = hideTotpInBrowse;
    }];
}



- (BOOL)showKeePass1BackupGroup {
    return self.metadata.showKeePass1BackupGroup;
}

- (void)setShowKeePass1BackupGroup:(BOOL)showKeePass1BackupGroup {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showKeePass1BackupGroup = showKeePass1BackupGroup;
    }];
}



- (BOOL)showChildCountOnFolderInBrowse {
    return self.metadata.showChildCountOnFolderInBrowse;
}

- (void)setShowChildCountOnFolderInBrowse:(BOOL)showChildCountOnFolderInBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showChildCountOnFolderInBrowse = showChildCountOnFolderInBrowse;
    }];
}



- (BOOL)showFlagsInBrowse {
    return self.metadata.showFlagsInBrowse;
}

- (void)setShowFlagsInBrowse:(BOOL)showFlagsInBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showFlagsInBrowse = showFlagsInBrowse;
    }];
}



- (BOOL)doNotShowRecycleBinInBrowse {
    return self.metadata.doNotShowRecycleBinInBrowse;
}

- (void)setDoNotShowRecycleBinInBrowse:(BOOL)doNotShowRecycleBinInBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.doNotShowRecycleBinInBrowse = doNotShowRecycleBinInBrowse;
    }];
}



- (BOOL)showRecycleBinInSearchResults {
    return self.metadata.showRecycleBinInSearchResults;
}

- (void)setShowRecycleBinInSearchResults:(BOOL)showRecycleBinInSearchResults {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showRecycleBinInSearchResults = showRecycleBinInSearchResults;
    }];
}



- (BOOL)showExpiredInSearch {
    return self.metadata.showExpiredInSearch;
}

- (void)setShowExpiredInSearch:(BOOL)showExpiredInSearch {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showExpiredInSearch = showExpiredInSearch;
    }];
}



- (BOOL)showExpiredInBrowse {
    return self.metadata.showExpiredInBrowse;
}

- (void)setShowExpiredInBrowse:(BOOL)showExpiredInBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showExpiredInBrowse = showExpiredInBrowse;
    }];
}



- (BOOL)hideIconInBrowse {
    return self.metadata.hideIconInBrowse;
}

- (void)setHideIconInBrowse:(BOOL)hideIconInBrowse {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hideIconInBrowse = hideIconInBrowse;
    }];
}



- (BOOL)showEmptyFieldsInDetailsView {
    return self.metadata.showEmptyFieldsInDetailsView;
}

- (void)setShowEmptyFieldsInDetailsView:(BOOL)showEmptyFieldsInDetailsView {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showEmptyFieldsInDetailsView = showEmptyFieldsInDetailsView;
    }];
}



- (NSArray<NSNumber *> *)detailsViewCollapsedSections {
    return self.metadata.detailsViewCollapsedSections;
}

- (void)setDetailsViewCollapsedSections:(NSArray<NSNumber *> *)detailsViewCollapsedSections {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.detailsViewCollapsedSections = detailsViewCollapsedSections;
    }];
}



- (BOOL)easyReadFontForAll {
    return self.metadata.easyReadFontForAll;
}

- (void)setEasyReadFontForAll:(BOOL)easyReadFontForAll {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.easyReadFontForAll = easyReadFontForAll;
    }];
}



- (BOOL)hideTotp {
    return self.metadata.hideTotp;
}

- (void)setHideTotp:(BOOL)hideTotp {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hideTotp = hideTotp;
    }];
}



- (BOOL)tryDownloadFavIconForNewRecord {
    return self.metadata.tryDownloadFavIconForNewRecord;
}

- (void)setTryDownloadFavIconForNewRecord:(BOOL)tryDownloadFavIconForNewRecord {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.tryDownloadFavIconForNewRecord = tryDownloadFavIconForNewRecord;
    }];
}



- (BOOL)showPasswordByDefaultOnEditScreen {
    return self.metadata.showPasswordByDefaultOnEditScreen;
}

- (void)setShowPasswordByDefaultOnEditScreen:(BOOL)showPasswordByDefaultOnEditScreen {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showPasswordByDefaultOnEditScreen = showPasswordByDefaultOnEditScreen;
    }];
}



- (NSNumber *)autoLockTimeoutSeconds {
    return self.metadata.autoLockTimeoutSeconds;
}

- (void)setAutoLockTimeoutSeconds:(NSNumber *)autoLockTimeoutSeconds {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoLockTimeoutSeconds = autoLockTimeoutSeconds;
    }];
}



- (BOOL)showQuickViewFavourites {
    return self.metadata.showQuickViewFavourites;
}

- (void)setShowQuickViewFavourites:(BOOL)showQuickViewFavourites {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showQuickViewFavourites = showQuickViewFavourites;
    }];
}



- (BOOL)showQuickViewNearlyExpired {
    return self.metadata.showQuickViewNearlyExpired;
}

- (void)setShowQuickViewNearlyExpired:(BOOL)showQuickViewNearlyExpired {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showQuickViewNearlyExpired = showQuickViewNearlyExpired;
    }];
}



- (BOOL)showQuickViewExpired {
    return self.metadata.showQuickViewExpired;
}

- (void)setShowQuickViewExpired:(BOOL)showQuickViewExpired {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showQuickViewExpired = showQuickViewExpired;
    }];
}



- (NSArray<NSString *> *)favourites {
    return self.metadata.favourites;
}

- (void)setFavourites:(NSArray<NSString *> *)favourites {
    self.metadata.favourites = favourites;
}



- (NSArray<NSString *> *)auditExcludedItems {
    return self.metadata.auditExcludedItems;
}

- (void)setAuditExcludedItems:(NSArray<NSString *> *)auditExcludedItems {
    self.metadata.auditExcludedItems = auditExcludedItems;
}



- (NSUInteger)maxBackupKeepCount {
    return self.metadata.maxBackupKeepCount;
}

- (void)setMaxBackupKeepCount:(NSUInteger)maxBackupKeepCount {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.maxBackupKeepCount = maxBackupKeepCount;
    }];
}



- (BOOL)makeBackups {
    return self.metadata.makeBackups;
}

- (void)setMakeBackups:(BOOL)makeBackups {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.makeBackups = makeBackups;
    }];
}



- (BOOL)hideTotpCustomFieldsInViewMode {
    return self.metadata.hideTotpCustomFieldsInViewMode;
}

- (void)setHideTotpCustomFieldsInViewMode:(BOOL)hideTotpCustomFieldsInViewMode {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hideTotpCustomFieldsInViewMode = hideTotpCustomFieldsInViewMode;
    }];
}



- (YubiKeyHardwareConfiguration *)contextAwareYubiKeyConfig {
    return self.metadata.contextAwareYubiKeyConfig;
}

- (void)setContextAwareYubiKeyConfig:(YubiKeyHardwareConfiguration *)contextAwareYubiKeyConfig {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.contextAwareYubiKeyConfig = contextAwareYubiKeyConfig;
    }];
}

- (YubiKeyHardwareConfiguration *)yubiKeyConfig {
    return self.metadata.yubiKeyConfig;
}

- (void)setYubiKeyConfig:(YubiKeyHardwareConfiguration *)yubiKeyConfig {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.yubiKeyConfig = yubiKeyConfig;
    }];
}

- (YubiKeyHardwareConfiguration *)autoFillYubiKeyConfig {
    return self.metadata.autoFillYubiKeyConfig;
}

- (void)setAutoFillYubiKeyConfig:(YubiKeyHardwareConfiguration *)autoFillYubiKeyConfig {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillYubiKeyConfig = autoFillYubiKeyConfig;
    }];
}



- (DatabaseAuditorConfiguration *)auditConfig {
    return self.metadata.auditConfig;
}

- (void)setAuditConfig:(DatabaseAuditorConfiguration *)auditConfig {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.auditConfig = auditConfig;
    }];
}



- (BOOL)colorizePasswords {
    return self.metadata.colorizePasswords;
}

- (void)setColorizePasswords:(BOOL)colorizePasswords {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.colorizePasswords = colorizePasswords;
    }];
}



- (BOOL)colorizeProtectedCustomFields {
    return self.metadata.colorizeProtectedCustomFields;
}

- (void)setColorizeProtectedCustomFields:(BOOL)colorizeProtectedCustomFields {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.colorizeProtectedCustomFields = colorizeProtectedCustomFields;
    }];
}



- (KeePassIconSet)keePassIconSet {
    return self.metadata.keePassIconSet;
}

- (void)setKeePassIconSet:(KeePassIconSet)keePassIconSet {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.keePassIconSet = keePassIconSet;
    }];
}



- (BOOL)promptedForAutoFetchFavIcon {
    return self.metadata.promptedForAutoFetchFavIcon;
}

- (void)setPromptedForAutoFetchFavIcon:(BOOL)promptedForAutoFetchFavIcon {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.promptedForAutoFetchFavIcon = promptedForAutoFetchFavIcon;
    }];
}



- (NSUUID *)outstandingUpdateId {
    return self.metadata.outstandingUpdateId;
}

- (void)setOutstandingUpdateId:(NSUUID *)outstandingUpdateId {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.outstandingUpdateId = outstandingUpdateId;
    }];
}



- (NSDate *)lastSyncRemoteModDate {
    return self.metadata.lastSyncRemoteModDate;
}

- (void)setLastSyncRemoteModDate:(NSDate *)lastSyncRemoteModDate {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lastSyncRemoteModDate = lastSyncRemoteModDate;
    }];
}



- (NSDate *)lastSyncAttempt {
    return self.metadata.lastSyncAttempt;
}

- (void)setLastSyncAttempt:(NSDate *)lastSyncAttempt {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lastSyncAttempt = lastSyncAttempt;
    }];
}



- (ConflictResolutionStrategy)conflictResolutionStrategy {
    return self.metadata.conflictResolutionStrategy;
}

- (void)setConflictResolutionStrategy:(ConflictResolutionStrategy)conflictResolutionStrategy {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.conflictResolutionStrategy = conflictResolutionStrategy;
    }];
}



- (BOOL)quickTypeEnabled {
    return self.metadata.quickTypeEnabled;
}

- (void)setQuickTypeEnabled:(BOOL)quickTypeEnabled {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.quickTypeEnabled = quickTypeEnabled;
    }];
}



- (QuickTypeAutoFillDisplayFormat)quickTypeDisplayFormat {
    return self.metadata.quickTypeDisplayFormat;
}

- (void)setQuickTypeDisplayFormat:(QuickTypeAutoFillDisplayFormat)quickTypeDisplayFormat {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.quickTypeDisplayFormat = quickTypeDisplayFormat;
    }];
}



- (BOOL)emptyOrNilPwPreferNilCheckFirst {
    return self.metadata.emptyOrNilPwPreferNilCheckFirst;
}

- (void)setEmptyOrNilPwPreferNilCheckFirst:(BOOL)emptyOrNilPwPreferNilCheckFirst {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.emptyOrNilPwPreferNilCheckFirst = emptyOrNilPwPreferNilCheckFirst;
    }];
}



- (BOOL)autoLockOnDeviceLock {
    return self.metadata.autoLockOnDeviceLock;
}

- (void)setAutoLockOnDeviceLock:(BOOL)autoLockOnDeviceLock {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoLockOnDeviceLock = autoLockOnDeviceLock;
    }];
}



- (NSInteger)autoFillConvenienceAutoUnlockTimeout {
    return self.metadata.autoFillConvenienceAutoUnlockTimeout;
}

- (void)setAutoFillConvenienceAutoUnlockTimeout:(NSInteger)autoFillConvenienceAutoUnlockTimeout {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillConvenienceAutoUnlockTimeout = autoFillConvenienceAutoUnlockTimeout;
    }];
}



- (NSDate *)autoFillLastUnlockedAt {
    return self.metadata.autoFillLastUnlockedAt;
}

- (void)setAutoFillLastUnlockedAt:(NSDate *)autoFillLastUnlockedAt {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillLastUnlockedAt = autoFillLastUnlockedAt;
    }];
}



- (BOOL)autoFillCopyTotp {
    return self.metadata.autoFillCopyTotp;
}

- (void)setAutoFillCopyTotp:(BOOL)autoFillCopyTotp {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillCopyTotp = autoFillCopyTotp;
    }];
}



- (BOOL)forceOpenOffline {
    return self.metadata.forceOpenOffline;
}

- (void)setForceOpenOffline:(BOOL)forceOpenOffline {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.forceOpenOffline = forceOpenOffline;
    }];
}



- (OfflineDetectedBehaviour)offlineDetectedBehaviour {
    return self.metadata.offlineDetectedBehaviour;
}

- (void)setOfflineDetectedBehaviour:(OfflineDetectedBehaviour)offlineDetectedBehaviour {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.offlineDetectedBehaviour = offlineDetectedBehaviour;
    }];
}



- (CouldNotConnectBehaviour)couldNotConnectBehaviour {
    return self.metadata.couldNotConnectBehaviour;
}

- (void)setCouldNotConnectBehaviour:(CouldNotConnectBehaviour)couldNotConnectBehaviour {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.couldNotConnectBehaviour = couldNotConnectBehaviour;
    }];
}



- (BOOL)showConvenienceExpiryMessage {
    return self.metadata.showConvenienceExpiryMessage;
}

- (void)setShowConvenienceExpiryMessage:(BOOL)showConvenienceExpiryMessage {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showConvenienceExpiryMessage = showConvenienceExpiryMessage;
    }];
}



- (BOOL)hasShownInitialOnboardingScreen {
    return self.metadata.hasShownInitialOnboardingScreen;
}

- (void)setHasShownInitialOnboardingScreen:(BOOL)hasShownInitialOnboardingScreen {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hasShownInitialOnboardingScreen = hasShownInitialOnboardingScreen;
    }];
}



- (BOOL)convenienceExpiryOnboardingDone {
    return self.metadata.convenienceExpiryOnboardingDone;
}

- (void)setConvenienceExpiryOnboardingDone:(BOOL)convenienceExpiryOnboardingDone {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.convenienceExpiryOnboardingDone = convenienceExpiryOnboardingDone;
    }];
}



- (BOOL)autoFillOnboardingDone {
    return self.metadata.autoFillOnboardingDone;
}

- (void)setAutoFillOnboardingDone:(BOOL)autoFillOnboardingDone {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillOnboardingDone = autoFillOnboardingDone;
    }];
}



- (BOOL)hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue {
    return self.metadata.hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue;
}

- (void)setHasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue:(BOOL)hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue = hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue;
    }];
}



- (BOOL)onboardingDoneHasBeenShown {
    return self.metadata.onboardingDoneHasBeenShown;
}

- (void)setOnboardingDoneHasBeenShown:(BOOL)onboardingDoneHasBeenShown {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.onboardingDoneHasBeenShown = onboardingDoneHasBeenShown;
    }];
}



- (BOOL)scheduledExport {
    return self.metadata.scheduledExport;
}

- (void)setScheduledExport:(BOOL)scheduledExport {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.scheduledExport = scheduledExport;
    }];
}



- (BOOL)scheduledExportOnboardingDone {
    return self.metadata.scheduledExportOnboardingDone;
}

- (void)setScheduledExportOnboardingDone:(BOOL)scheduledExportOnboardingDone {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.scheduledExportOnboardingDone = scheduledExportOnboardingDone;
    }];
}



- (NSUInteger)scheduleExportIntervalDays {
    return self.metadata.scheduleExportIntervalDays;
}

- (void)setScheduleExportIntervalDays:(NSUInteger)scheduleExportIntervalDays {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.scheduleExportIntervalDays = scheduleExportIntervalDays;
    }];
}



- (NSDate *)nextScheduledExport {
    return self.metadata.nextScheduledExport;
}

- (void)setNextScheduledExport:(NSDate *)nextScheduledExport {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.nextScheduledExport = nextScheduledExport;
    }];
}



- (NSDate *)lastScheduledExportModDate {
    return self.metadata.lastScheduledExportModDate;
}

- (void)setLastScheduledExportModDate:(NSDate *)lastScheduledExportModDate {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lastScheduledExportModDate = lastScheduledExportModDate;
    }];
}



- (BOOL)lockEvenIfEditing {
    return self.metadata.lockEvenIfEditing;
}

- (void)setLockEvenIfEditing:(BOOL)lockEvenIfEditing {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lockEvenIfEditing = lockEvenIfEditing;
    }];
}



- (NSDate *)databaseCreated {
    return self.metadata.databaseCreated;
}

- (void)setDatabaseCreated:(NSDate *)databaseCreated {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.databaseCreated = databaseCreated;
    }];
}



- (NSUInteger)unlockCount {
    return self.metadata.unlockCount;
}

- (void)setUnlockCount:(NSUInteger)unlockCount {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.unlockCount = unlockCount;
    }];
}



- (BOOL)autoFillScanAltUrls {
    return self.metadata.autoFillScanAltUrls;
}

- (void)setAutoFillScanAltUrls:(BOOL)autoFillScanAltUrls {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillScanAltUrls = autoFillScanAltUrls;
    }];
}



- (BOOL)autoFillScanCustomFields {
    return self.metadata.autoFillScanCustomFields;
}

- (void)setAutoFillScanCustomFields:(BOOL)autoFillScanCustomFields {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillScanCustomFields = autoFillScanCustomFields;
    }];
}



- (BOOL)autoFillScanNotes {
    return self.metadata.autoFillScanNotes;
}

- (void)setAutoFillScanNotes:(BOOL)autoFillScanNotes {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillScanNotes = autoFillScanNotes;
    }];
}



- (BOOL)hasBeenPromptedForConvenience {
    return self.metadata.hasBeenPromptedForConvenience;
}

- (void)setHasBeenPromptedForConvenience:(BOOL)hasBeenPromptedForConvenience {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hasBeenPromptedForConvenience = hasBeenPromptedForConvenience;
    }];
}



- (NSInteger)convenienceExpiryPeriod {
    return self.metadata.convenienceExpiryPeriod;
}

- (void)setConvenienceExpiryPeriod:(NSInteger)convenienceExpiryPeriod {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.convenienceExpiryPeriod = convenienceExpiryPeriod;
    }];
}



- (BOOL)conveniencePasswordHasBeenStored {
    return self.metadata.conveniencePasswordHasBeenStored;
}

- (void)setConveniencePasswordHasBeenStored:(BOOL)conveniencePasswordHasBeenStored {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.conveniencePasswordHasBeenStored = conveniencePasswordHasBeenStored;
    }];
}



- (BOOL)autoFillConcealedFieldsAsCreds {
    return self.metadata.autoFillConcealedFieldsAsCreds;
}

- (void)setAutoFillConcealedFieldsAsCreds:(BOOL)autoFillConcealedFieldsAsCreds {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillConcealedFieldsAsCreds = autoFillConcealedFieldsAsCreds;
    }];
}



- (BOOL)autoFillUnConcealedFieldsAsCreds {
    return self.metadata.autoFillUnConcealedFieldsAsCreds;
}

- (void)setAutoFillUnConcealedFieldsAsCreds:(BOOL)autoFillUnConcealedFieldsAsCreds {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.autoFillUnConcealedFieldsAsCreds = autoFillUnConcealedFieldsAsCreds;
    }];
}



- (BOOL)argon2MemReductionDontAskAgain {
    return self.metadata.argon2MemReductionDontAskAgain;
}

- (void)setArgon2MemReductionDontAskAgain:(BOOL)argon2MemReductionDontAskAgain {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.argon2MemReductionDontAskAgain = argon2MemReductionDontAskAgain;
    }];
}



- (NSDate *)lastAskedAboutArgon2MemReduction {
    return self.metadata.lastAskedAboutArgon2MemReduction;
}

- (void)setLastAskedAboutArgon2MemReduction:(NSDate *)lastAskedAboutArgon2MemReduction {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lastAskedAboutArgon2MemReduction = lastAskedAboutArgon2MemReduction;
    }];
}



- (BOOL)kdbx4UpgradeDontAskAgain {
    return self.metadata.kdbx4UpgradeDontAskAgain;
}

- (void)setKdbx4UpgradeDontAskAgain:(BOOL)kdbx4UpgradeDontAskAgain {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.kdbx4UpgradeDontAskAgain = kdbx4UpgradeDontAskAgain;
    }];
}



- (NSDate *)lastAskedAboutKdbx4Upgrade {
    return self.metadata.lastAskedAboutKdbx4Upgrade;
}

- (void)setLastAskedAboutKdbx4Upgrade:(NSDate *)lastAskedAboutKdbx4Upgrade {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lastAskedAboutKdbx4Upgrade = lastAskedAboutKdbx4Upgrade;
    }];
}



- (BOOL)viewDereferencedFields {
    return self.metadata.viewDereferencedFields;
}



- (BOOL)searchDereferencedFields {
    return self.metadata.searchDereferencedFields;
}



- (NSURL *)backupsDirectory {
    return self.metadata.backupsDirectory;
}



- (BOOL)mainAppAndAutoFillYubiKeyConfigsIncoherent {
    return self.metadata.mainAppAndAutoFillYubiKeyConfigsIncoherent;
}





- (void)triggerPasswordExpiry {
    [self.metadata triggerPasswordExpiry];
}



- (BOOL)isConvenienceUnlockEnabled {
    return self.metadata.isConvenienceUnlockEnabled;
}

- (BOOL)isTouchIdEnabled {
    return self.metadata.isTouchIdEnabled;
}

- (void)setIsTouchIdEnabled:(BOOL)isTouchIdEnabled {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.isTouchIdEnabled = isTouchIdEnabled;
    }];
}



- (BOOL)conveniencePasswordHasExpired {
    return self.metadata.conveniencePasswordHasExpired;
}






- (NSString *)conveniencePin {
    return self.metadata.conveniencePin;
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    self.metadata.conveniencePin = conveniencePin;
}



- (NSString *)duressPin {
    return self.metadata.duressPin;
}

- (void)setDuressPin:(NSString *)duressPin {
    self.metadata.duressPin = duressPin;
}



- (NSString *)autoFillConvenienceAutoUnlockPassword {
    return self.metadata.autoFillConvenienceAutoUnlockPassword;
}

- (void)setAutoFillConvenienceAutoUnlockPassword:(NSString *)autoFillConvenienceAutoUnlockPassword {
    self.metadata.autoFillConvenienceAutoUnlockPassword = autoFillConvenienceAutoUnlockPassword;
}



- (NSString *)convenienceMasterPassword {
    return self.metadata.convenienceMasterPassword;
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    self.metadata.convenienceMasterPassword = convenienceMasterPassword;
}

- (BOOL)customSortOrderForFields {
    return self.metadata.customSortOrderForFields;
}

- (void)setCustomSortOrderForFields:(BOOL)customSortOrderForFields {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.customSortOrderForFields = customSortOrderForFields;
    }];
}

- (BOOL)lazySyncMode {
     return self.metadata.lazySyncMode;
}

- (void)setLazySyncMode:(BOOL)lazySyncMode {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lazySyncMode = lazySyncMode;
    }];
}

- (NSUUID *)asyncUpdateId {
    return self.metadata.asyncUpdateId;
}

- (void)setAsyncUpdateId:(NSUUID *)asyncUpdateId {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.asyncUpdateId = asyncUpdateId;
    }];
}

- (NSUUID *)lastViewedEntry {
    return self.metadata.lastViewedEntry;
}

- (void)setLastViewedEntry:(NSUUID *)lastViewedEntry {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.lastViewedEntry = lastViewedEntry;
    }];
}

- (BOOL)showLastViewedEntryOnUnlock {
    return self.metadata.showLastViewedEntryOnUnlock;
}

- (void)setShowLastViewedEntryOnUnlock:(BOOL)showLastViewedEntryOnUnlock {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.showLastViewedEntryOnUnlock = showLastViewedEntryOnUnlock;
    }];
}

- (BOOL)persistLazyEvenLastSyncErrors {
    return self.metadata.persistLazyEvenLastSyncErrors;
}

- (void)setPersistLazyEvenLastSyncErrors:(BOOL)persistLazyEvenLastSyncErrors {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.persistLazyEvenLastSyncErrors = persistLazyEvenLastSyncErrors;
    }];
}

- (NSArray<NSNumber *> *)visibleTabs {
    return self.metadata.visibleTabs;
}

- (void)setVisibleTabs:(NSArray<NSNumber *> *)visibleTabs {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.visibleTabs = visibleTabs;
    }];
}

- (BOOL)hideTabBarIfOnlySingleTab {
    return self.metadata.hideTabBarIfOnlySingleTab;
}

- (void)setHideTabBarIfOnlySingleTab:(BOOL)hideTabBarIfOnlySingleTab {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.hideTabBarIfOnlySingleTab = hideTabBarIfOnlySingleTab;
    }];
}

- (NSDictionary<NSString *,BrowseSortConfiguration *> *)sortConfigurations {
    return self.metadata.sortConfigurations;
}

- (void)setSortConfigurations:(NSDictionary<NSString *,BrowseSortConfiguration *> *)sortConfigurations {
    [self update:^(SafeMetaData * _Nonnull metadata) {
        metadata.sortConfigurations = sortConfigurations;
    }];
}

@end
