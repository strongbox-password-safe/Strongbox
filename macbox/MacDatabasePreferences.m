//
//  MacDatabasePreferences.m
//  MacBox
//
//  Created by Strongbox on 04/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacDatabasePreferences.h"
#import "DatabasesManager.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"
#import "NSData+Extensions.h"
#import <objc/message.h>

@interface MacDatabasePreferences ()

@property (readonly) DatabaseMetadata* metadata;
@property (readonly) DatabaseMetadata* templateDummy;
@property NSDictionary<NSData*, NSData*> *cachedYubiKeyChallengeResponses;

@end

@implementation MacDatabasePreferences

+ (instancetype)fromUuid:(NSString *)uuid {
    return [[MacDatabasePreferences alloc] initWithUuid:uuid];
}

+ (instancetype)fromUrl:(NSURL *)url {
    return [MacDatabasePreferences.allDatabases firstOrDefault:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return [obj.fileUrl isEqual:url];
    }];
}

+ (instancetype)getById:(NSString *)databaseId {
    return [MacDatabasePreferences.allDatabases firstOrDefault:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return [obj.uuid isEqual:databaseId];
    }];
}

+ (NSArray<MacDatabasePreferences *> *)allDatabases {
    return [DatabasesManager.sharedInstance.snapshot map:^id _Nonnull(DatabaseMetadata * _Nonnull obj, NSUInteger idx) {
        return [MacDatabasePreferences fromUuid:obj.uuid];
    }];
}

+ (NSArray<MacDatabasePreferences *> *)forAllDatabasesOfProvider:(StorageProvider)provider {
    return [DatabasesManager.sharedInstance.snapshot map:^id _Nonnull(DatabaseMetadata * _Nonnull obj, NSUInteger idx) {
        return obj.storageProvider == provider ? [MacDatabasePreferences fromUuid:obj.uuid] : nil; 
    }];
}

+ (NSArray<MacDatabasePreferences *> *)filteredDatabases:(BOOL (^)(MacDatabasePreferences * _Nonnull))block {
    return [MacDatabasePreferences.allDatabases filter:block];
}

+ (instancetype)templateDummyWithNickName:(NSString *)nickName storageProvider:(StorageProvider)storageProvider fileUrl:(NSURL *)fileUrl storageInfo:(NSString *)storageInfo {
    return [[MacDatabasePreferences alloc] initWithNickName:nickName storageProvider:storageProvider fileUrl:fileUrl storageInfo:storageInfo];
}



- (instancetype)initWithUuid:(NSString*)uuid {
    self = [super init];
    if (self) {
        if ( [DatabasesManager.sharedInstance getDatabaseById:uuid] != nil ) {
            _uuid = uuid;
            _templateDummy = nil;
        }
        else {
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo {
    self = [super init];
    if (self) {
        _templateDummy = [[DatabaseMetadata alloc] initWithNickName:nickName storageProvider:storageProvider fileUrl:fileUrl storageInfo:storageInfo];
        _uuid = self.templateDummy.uuid;
    }
    return self;
}



- (DatabaseMetadata *)metadata {
    if ( self.templateDummy ) {
        return self.templateDummy;
    }
    else {
        
        return [DatabasesManager.sharedInstance getDatabaseById:self.uuid];
    }
}

- (void)update:(void (^)(DatabaseMetadata * _Nonnull metadata))touch {
    if ( self.templateDummy ) {
        touch(self.templateDummy);
    }
    else {
        [DatabasesManager.sharedInstance atomicUpdate:self.uuid touch:touch];
    }
}

+ (MacDatabasePreferences *)addOrGet:(NSURL *)url {
    DatabaseMetadata* metadata = [DatabasesManager.sharedInstance addOrGet:url];
    
    return [MacDatabasePreferences fromUuid:metadata.uuid];
}

- (void)add {
    if ( self.templateDummy ) {
        [DatabasesManager.sharedInstance add:self.templateDummy];
    }
    else {
        slog(@"🔴 WARNWARN: Attempt to add an existing database to the list");
    }
}

- (void)remove {
    [DatabasesManager.sharedInstance remove:self.uuid];
}

+ (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex {
    [DatabasesManager.sharedInstance move:sourceIndex to:destinationIndex];
}



+ (NSString *)trimDatabaseNickName:(NSString *)string {
    return [DatabasesManager trimDatabaseNickName:string];
}

+ (BOOL)isUnique:(NSString *)nickName {
    return [DatabasesManager.sharedInstance isUnique:nickName];
}

+ (BOOL)isValid:(NSString *)nickName {
    return [DatabasesManager.sharedInstance isValid:nickName];
}

+ (NSString *)getSuggestedNewDatabaseName {
    return [DatabasesManager.sharedInstance getSuggestedNewDatabaseName];
}

+ (NSString *)getUniqueNameFromSuggestedName:(NSString *)suggested {
    return [DatabasesManager.sharedInstance getUniqueNameFromSuggestedName:suggested];
}



- (BOOL)isSharedInCloudKit {
    return self.metadata.isSharedInCloudKit;
}

- (void)setIsSharedInCloudKit:(BOOL)isSharedInCloudKit {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.isSharedInCloudKit = isSharedInCloudKit;
    }];
}

- (BOOL)isOwnedByMeCloudKit {
    return self.metadata.isOwnedByMeCloudKit;
}

- (void)setIsOwnedByMeCloudKit:(BOOL)isOwnedByMeCloudKit {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.isOwnedByMeCloudKit = isOwnedByMeCloudKit;
    }];
}




- (NSString *)nickName {
    return self.metadata.nickName;
}

- (void)setNickName:(NSString *)nickName {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.nickName = nickName;
    }];
}



- (NSURL *)fileUrl{
    return self.metadata.fileUrl;
}

- (void)setFileUrl:(NSURL *)fileUrl {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.fileUrl = fileUrl;
    }];

}



- (NSString *)storageInfo {
    return self.metadata.storageInfo;
}

- (void)setStorageInfo:(NSString *)storageInfo {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.storageInfo = storageInfo;
    }];

}



- (NSString *)autoFillStorageInfo {
    return self.metadata.autoFillStorageInfo;
}

- (void)setAutoFillStorageInfo:(NSString *)autoFillStorageInfo {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillStorageInfo = autoFillStorageInfo;
    }];

}



- (StorageProvider)storageProvider {
    return self.metadata.storageProvider;
}

- (void)setStorageProvider:(StorageProvider)storageProvider {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.storageProvider = storageProvider;
    }];

}



- (NSString *)conveniencePassword {
    return self.metadata.conveniencePassword;
}

- (void)setConveniencePassword:(NSString *)conveniencePassword {
    self.metadata.conveniencePassword = conveniencePassword;
}



- (NSString *)keyFileBookmark {
    return self.metadata.keyFileBookmark;
}

- (void)setKeyFileBookmark:(NSString *)keyFileBookmark {
    self.metadata.keyFileBookmark = keyFileBookmark;
}



- (NSString *)autoFillKeyFileBookmark {
    return self.metadata.autoFillKeyFileBookmark;
}

- (void)setAutoFillKeyFileBookmark:(NSString *)autoFillKeyFileBookmark {
    self.metadata.autoFillKeyFileBookmark = autoFillKeyFileBookmark;
}



- (BOOL)autoFillEnabled {
    return self.metadata.autoFillEnabled;
}

- (void)setAutoFillEnabled:(BOOL)autoFillEnabled {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillEnabled = autoFillEnabled;
    }];

}



- (BOOL)quickTypeEnabled {
    return self.metadata.quickTypeEnabled;
}

- (void)setQuickTypeEnabled:(BOOL)quickTypeEnabled {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.quickTypeEnabled = quickTypeEnabled;
    }];

}



- (QuickTypeAutoFillDisplayFormat)quickTypeDisplayFormat {
    return self.metadata.quickTypeDisplayFormat;
}

- (void)setQuickTypeDisplayFormat:(QuickTypeAutoFillDisplayFormat)quickTypeDisplayFormat {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.quickTypeDisplayFormat = quickTypeDisplayFormat;
    }];

}



- (BOOL)hasPromptedForAutoFillEnrol {
    return self.metadata.hasPromptedForAutoFillEnrol;
}

- (void)setHasPromptedForAutoFillEnrol:(BOOL)hasPromptedForAutoFillEnrol {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForAutoFillEnrol = hasPromptedForAutoFillEnrol;
    }];

}



- (NSUUID *)outstandingUpdateId {
    return self.metadata.outstandingUpdateId;
}

- (void)setOutstandingUpdateId:(NSUUID *)outstandingUpdateId {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.outstandingUpdateId = outstandingUpdateId;
    }];

}



- (NSDate *)lastSyncRemoteModDate {
    return self.metadata.lastSyncRemoteModDate;
}

- (void)setLastSyncRemoteModDate:(NSDate *)lastSyncRemoteModDate {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.lastSyncRemoteModDate = lastSyncRemoteModDate;
    }];

}



- (NSDate *)lastSyncAttempt {
    return self.metadata.lastSyncAttempt;
}

- (void)setLastSyncAttempt:(NSDate *)lastSyncAttempt {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.lastSyncAttempt = lastSyncAttempt;
    }];

}



- (BOOL)launchAtStartup {
    return self.metadata.launchAtStartup;
}

- (void)setLaunchAtStartup:(BOOL)launchAtStartup {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.launchAtStartup = launchAtStartup;
    }];

}



- (NSString *)autoFillConvenienceAutoUnlockPassword {
    return self.metadata.autoFillConvenienceAutoUnlockPassword;
}

- (void)setAutoFillConvenienceAutoUnlockPassword:(NSString *)autoFillConvenienceAutoUnlockPassword {
    self.metadata.autoFillConvenienceAutoUnlockPassword = autoFillConvenienceAutoUnlockPassword;
}



- (NSInteger)autoFillConvenienceAutoUnlockTimeout {
    return self.metadata.autoFillConvenienceAutoUnlockTimeout;
}

- (void)setAutoFillConvenienceAutoUnlockTimeout:(NSInteger)autoFillConvenienceAutoUnlockTimeout {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillConvenienceAutoUnlockTimeout = autoFillConvenienceAutoUnlockTimeout;
    }];

}



- (NSDate *)autoFillLastUnlockedAt {
    return self.metadata.autoFillLastUnlockedAt;
}

- (void)setAutoFillLastUnlockedAt:(NSDate *)autoFillLastUnlockedAt {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillLastUnlockedAt = autoFillLastUnlockedAt;
    }];

}



- (ConflictResolutionStrategy)conflictResolutionStrategy {
    return self.metadata.conflictResolutionStrategy;
}

- (void)setConflictResolutionStrategy:(ConflictResolutionStrategy)conflictResolutionStrategy {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.conflictResolutionStrategy = conflictResolutionStrategy;
    }];
}



- (BOOL)monitorForExternalChanges {
    return self.metadata.monitorForExternalChanges;
}

- (void)setMonitorForExternalChanges:(BOOL)monitorForExternalChanges {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.monitorForExternalChanges = monitorForExternalChanges;
    }];

}



- (NSInteger)monitorForExternalChangesInterval {
    return self.metadata.monitorForExternalChangesInterval;
}

- (void)setMonitorForExternalChangesInterval:(NSInteger)monitorForExternalChangesInterval {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.monitorForExternalChangesInterval = monitorForExternalChangesInterval;
    }];

}



- (BOOL)autoReloadAfterExternalChanges {
    return self.metadata.autoReloadAfterExternalChanges;
}

- (void)setAutoReloadAfterExternalChanges:(BOOL)autoReloadAfterExternalChanges {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoReloadAfterExternalChanges = autoReloadAfterExternalChanges;
    }];

}



- (NSURL *)backupsDirectory {
    
    return self.metadata.backupsDirectory;
}



- (NSUInteger)maxBackupKeepCount {
    return self.metadata.maxBackupKeepCount;
}

- (void)setMaxBackupKeepCount:(NSUInteger)maxBackupKeepCount {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.maxBackupKeepCount = maxBackupKeepCount;
    }];

}



- (BOOL)makeBackups {
    return self.metadata.makeBackups;
}

- (void)setMakeBackups:(BOOL)makeBackups {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.makeBackups = makeBackups;
    }];

}



- (BOOL)isLocalDeviceDatabase {
    
    return self.metadata.isLocalDeviceDatabase;
}



- (BOOL)userRequestOfflineOpenEphemeralFlagForDocument {
    return self.metadata.userRequestOfflineOpenEphemeralFlagForDocument;
}

- (void)setUserRequestOfflineOpenEphemeralFlagForDocument:(BOOL)userRequestOfflineOpenEphemeralFlagForDocument {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.userRequestOfflineOpenEphemeralFlagForDocument = userRequestOfflineOpenEphemeralFlagForDocument;
    }];

}



- (BOOL)alwaysOpenOffline {
    return self.metadata.alwaysOpenOffline;
}

- (void)setAlwaysOpenOffline:(BOOL)alwaysOpenOffline {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.alwaysOpenOffline = alwaysOpenOffline;
    }];

}



- (BOOL)readOnly {
    return self.metadata.readOnly;
}

- (void)setReadOnly:(BOOL)readOnly {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.readOnly = readOnly;
    }];

}



- (BOOL)showQuickView {
    return self.metadata.showQuickView;
}

- (void)setShowQuickView:(BOOL)showQuickView {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showQuickView = showQuickView;
    }];

}
















- (BOOL)noAlternatingRows {
    return self.metadata.noAlternatingRows;
}

- (void)setNoAlternatingRows:(BOOL)noAlternatingRows {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.noAlternatingRows = noAlternatingRows;
    }];

}



- (BOOL)showHorizontalGrid {
    return self.metadata.showHorizontalGrid;
}

- (void)setShowHorizontalGrid:(BOOL)showHorizontalGrid {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showHorizontalGrid = showHorizontalGrid;
    }];

}



- (BOOL)showVerticalGrid {
    return self.metadata.showVerticalGrid;
}

- (void)setShowVerticalGrid:(BOOL)showVerticalGrid {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showVerticalGrid = showVerticalGrid;
    }];

}



- (BOOL)doNotShowAutoCompleteSuggestions {
    return self.metadata.doNotShowAutoCompleteSuggestions;
}

- (void)setDoNotShowAutoCompleteSuggestions:(BOOL)doNotShowAutoCompleteSuggestions {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowAutoCompleteSuggestions = doNotShowAutoCompleteSuggestions;
    }];

}



- (BOOL)doNotShowChangeNotifications {
    return self.metadata.doNotShowChangeNotifications;
}

- (void)setDoNotShowChangeNotifications:(BOOL)doNotShowChangeNotifications {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowChangeNotifications = doNotShowChangeNotifications;
    }];

}



- (BOOL)outlineViewTitleIsReadonly {
    return self.metadata.outlineViewTitleIsReadonly;
}

- (void)setOutlineViewTitleIsReadonly:(BOOL)outlineViewTitleIsReadonly {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.outlineViewTitleIsReadonly = outlineViewTitleIsReadonly;
    }];

}



- (BOOL)concealEmptyProtectedFields {
    return self.metadata.concealEmptyProtectedFields;
}

- (void)setConcealEmptyProtectedFields:(BOOL)concealEmptyProtectedFields {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.concealEmptyProtectedFields = concealEmptyProtectedFields;
    }];

}



- (BOOL)startWithSearch {
    return self.metadata.startWithSearch;
}

- (void)setStartWithSearch:(BOOL)startWithSearch {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.startWithSearch = startWithSearch;
    }];

}



- (BOOL)showAdvancedUnlockOptions {
    return self.metadata.showAdvancedUnlockOptions;
}

- (void)setShowAdvancedUnlockOptions:(BOOL)showAdvancedUnlockOptions {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showAdvancedUnlockOptions = showAdvancedUnlockOptions;
    }];

}



- (BOOL)expressDownloadFavIconOnNewOrUrlChanged {
    return self.metadata.expressDownloadFavIconOnNewOrUrlChanged;
}

- (void)setExpressDownloadFavIconOnNewOrUrlChanged:(BOOL)expressDownloadFavIconOnNewOrUrlChanged {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.expressDownloadFavIconOnNewOrUrlChanged = expressDownloadFavIconOnNewOrUrlChanged;
    }];

}



- (BOOL)doNotShowRecycleBinInBrowse {
    return self.metadata.doNotShowRecycleBinInBrowse;
}

- (void)setDoNotShowRecycleBinInBrowse:(BOOL)doNotShowRecycleBinInBrowse {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowRecycleBinInBrowse = doNotShowRecycleBinInBrowse;
    }];

}



- (BOOL)showRecycleBinInSearchResults {
    return self.metadata.showRecycleBinInSearchResults;
}

- (void)setShowRecycleBinInSearchResults:(BOOL)showRecycleBinInSearchResults {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showRecycleBinInSearchResults = showRecycleBinInSearchResults;
    }];

}



- (BOOL)uiDoNotSortKeePassNodesInBrowseView {
    return self.metadata.uiDoNotSortKeePassNodesInBrowseView;
}

- (void)setUiDoNotSortKeePassNodesInBrowseView:(BOOL)uiDoNotSortKeePassNodesInBrowseView {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.uiDoNotSortKeePassNodesInBrowseView = uiDoNotSortKeePassNodesInBrowseView;
    }];

}



- (BOOL)hasSetInitialWindowPosition {
    return self.metadata.hasSetInitialWindowPosition;
}

- (void)setHasSetInitialWindowPosition:(BOOL)hasSetInitialWindowPosition {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasSetInitialWindowPosition = hasSetInitialWindowPosition;
    }];
}

- (BOOL)hasSetInitialUnlockedFrame {
    return self.metadata.hasSetInitialUnlockedFrame;
}

- (void)setHasSetInitialUnlockedFrame:(BOOL)hasSetInitialUnlockedFrame {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasSetInitialUnlockedFrame = hasSetInitialUnlockedFrame;
    }];
}



- (BOOL)autoFillScanCustomFields {
    return self.metadata.autoFillScanCustomFields;
}

- (void)setAutoFillScanCustomFields:(BOOL)autoFillScanCustomFields {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillScanCustomFields = autoFillScanCustomFields;
    }];

}



- (BOOL)autoFillScanNotes {
    return self.metadata.autoFillScanNotes;
}

- (void)setAutoFillScanNotes:(BOOL)autoFillScanNotes {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillScanNotes = autoFillScanNotes;
    }];

}



- (NSString *)conveniencePin {
    return self.metadata.conveniencePin;
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    self.metadata.conveniencePin = conveniencePin;
}



- (NSUInteger)unlockCount {
    return self.metadata.unlockCount;
}

- (void)setUnlockCount:(NSUInteger)unlockCount {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.unlockCount = unlockCount;
    }];

}



- (DatabaseFormat)likelyFormat {
    return self.metadata.likelyFormat;
}

- (void)setLikelyFormat:(DatabaseFormat)likelyFormat {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.likelyFormat = likelyFormat;
    }];

}

- (NSString *)serializationPerf {
    return self.metadata.serializationPerf;
}

- (void)setSerializationPerf:(NSString *)serializationPerf {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.serializationPerf = serializationPerf;
    }];
}

- (NSString *)lastKnownEncryptionSettings {
    return self.metadata.lastKnownEncryptionSettings;
}

- (void)setLastKnownEncryptionSettings:(NSString *)lastKnownEncryptionSettings {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.lastKnownEncryptionSettings = lastKnownEncryptionSettings;
    }];
}



- (BOOL)emptyOrNilPwPreferNilCheckFirst {
    return self.metadata.emptyOrNilPwPreferNilCheckFirst;
}

- (void)setEmptyOrNilPwPreferNilCheckFirst:(BOOL)emptyOrNilPwPreferNilCheckFirst {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.emptyOrNilPwPreferNilCheckFirst = emptyOrNilPwPreferNilCheckFirst;
    }];

}



- (BOOL)isTouchIdEnabled {
    return self.metadata.isTouchIdEnabled;
}

- (void)setIsTouchIdEnabled:(BOOL)isTouchIdEnabled {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.isTouchIdEnabled = isTouchIdEnabled;
    }];

}



- (BOOL)isWatchUnlockEnabled {
    return self.metadata.isWatchUnlockEnabled;
}

- (void)setIsWatchUnlockEnabled:(BOOL)isWatchUnlockEnabled {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.isWatchUnlockEnabled = isWatchUnlockEnabled;
    }];

}



- (BOOL)hasPromptedForTouchIdEnrol {
    return self.metadata.hasPromptedForTouchIdEnrol;
}

- (void)setHasPromptedForTouchIdEnrol:(BOOL)hasPromptedForTouchIdEnrol {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForTouchIdEnrol = hasPromptedForTouchIdEnrol;
    }];

}



- (NSInteger)touchIdPasswordExpiryPeriodHours {
    return self.metadata.touchIdPasswordExpiryPeriodHours;
}

- (void)setTouchIdPasswordExpiryPeriodHours:(NSInteger)touchIdPasswordExpiryPeriodHours {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.touchIdPasswordExpiryPeriodHours = touchIdPasswordExpiryPeriodHours;
    }];

}



- (BOOL)isConvenienceUnlockEnabled {
    
    return self.metadata.isConvenienceUnlockEnabled;
}



- (BOOL)conveniencePasswordHasExpired {
    return self.metadata.conveniencePasswordHasExpired;
}



- (BOOL)hasBeenPromptedForConvenience {
    return self.metadata.hasBeenPromptedForConvenience;
}

- (void)setHasBeenPromptedForConvenience:(BOOL)hasBeenPromptedForConvenience {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasBeenPromptedForConvenience = hasBeenPromptedForConvenience;
    }];

}



- (NSInteger)convenienceExpiryPeriod {
    return self.metadata.convenienceExpiryPeriod;
}

- (void)setConvenienceExpiryPeriod:(NSInteger)convenienceExpiryPeriod {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.convenienceExpiryPeriod = convenienceExpiryPeriod;
    }];

}



- (NSString *)convenienceMasterPassword {
    return self.metadata.convenienceMasterPassword;
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.convenienceMasterPassword = convenienceMasterPassword;
    }];

}



- (BOOL)conveniencePasswordHasBeenStored {
    return self.metadata.conveniencePasswordHasBeenStored;
}

- (void)setConveniencePasswordHasBeenStored:(BOOL)conveniencePasswordHasBeenStored {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.conveniencePasswordHasBeenStored = conveniencePasswordHasBeenStored;
    }];

}



- (BOOL)includeAssociatedDomains {
    return self.metadata.includeAssociatedDomains;
}

- (void)setIncludeAssociatedDomains:(BOOL)includeAssociatedDomains {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.includeAssociatedDomains = includeAssociatedDomains;
    }];
}



- (BOOL)autoFillConcealedFieldsAsCreds {
    return self.metadata.autoFillConcealedFieldsAsCreds;
}

- (void)setAutoFillConcealedFieldsAsCreds:(BOOL)autoFillConcealedFieldsAsCreds {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillConcealedFieldsAsCreds = autoFillConcealedFieldsAsCreds;
    }];
}



- (BOOL)autoFillUnConcealedFieldsAsCreds {
    return self.metadata.autoFillUnConcealedFieldsAsCreds;
}

- (void)setAutoFillUnConcealedFieldsAsCreds:(BOOL)autoFillUnConcealedFieldsAsCreds {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillUnConcealedFieldsAsCreds = autoFillUnConcealedFieldsAsCreds;
    }];

}



- (NSUUID *)asyncUpdateId {
    return self.metadata.asyncUpdateId;
}

- (void)setAsyncUpdateId:(NSUUID *)asyncUpdateId {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.asyncUpdateId = asyncUpdateId;
    }];

}



- (BOOL)promptedForAutoFetchFavIcon {
    return self.metadata.promptedForAutoFetchFavIcon;
}

- (void)setPromptedForAutoFetchFavIcon:(BOOL)promptedForAutoFetchFavIcon {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.promptedForAutoFetchFavIcon = promptedForAutoFetchFavIcon;
    }];
}

- (SecretExpiryMode)getConveniencePasswordExpiryMode {
    return [self.metadata getConveniencePasswordExpiryMode];
}

- (NSDate *)getConveniencePasswordExpiryDate {
    return [self.metadata getConveniencePasswordExpiryDate];
}

- (void)clearSecureItems {
    [self.metadata clearSecureItems];
}

- (void)triggerPasswordExpiry {
    [self.metadata triggerPasswordExpiry];
}



- (YubiKeyConfiguration *)yubiKeyConfiguration {
    return self.metadata.yubiKeyConfiguration;
}

- (void)setYubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.yubiKeyConfiguration = yubiKeyConfiguration;
    }];
}

- (NSArray<NSString *> *)visibleColumns {
    return self.metadata.visibleColumns;
}

- (void)setVisibleColumns:(NSArray<NSString *> *)visibleColumns {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.visibleColumns = visibleColumns;
    }];
}

- (DatabaseAuditorConfiguration *)auditConfig {
    return self.metadata.auditConfig;
}

- (void)setAuditConfig:(DatabaseAuditorConfiguration *)auditConfig {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.auditConfig = auditConfig;
    }];
}



- (NSString *)exportFileName {
    NSString* extension = self.fileUrl.path.pathExtension;
    NSString* withoutExtension = [self.fileUrl.path.lastPathComponent stringByDeletingPathExtension];
    NSString* newFileName = [withoutExtension stringByAppendingFormat:@"-%@", NSDate.date.fileNameCompatibleDateTime];
    
    NSString* ret = [newFileName stringByAppendingPathExtension:extension];
    
    slog(@"Export Filename: [%@]", ret);
    
    return  ret;
}



- (NSDictionary<NSString*, NSString *> *)debugInfoLines_old {
    NSMutableDictionary<NSString*, NSString*>* debugLines = NSMutableDictionary.dictionary;
    
    debugLines[@"nickName"] = self.nickName; 
    debugLines[@"fileUrl"] = [NSString stringWithFormat:@"%@", self.fileUrl]; 
    debugLines[@"keyFileBookmark"] = [NSString stringWithFormat:@"%@", self.keyFileBookmark ? @"YES" : @"NO" ];
    debugLines[@"autoFillEnabled"] = [NSString stringWithFormat:@"%hhd", self.autoFillEnabled]; 
    debugLines[@"quickTypeEnabled"] = [NSString stringWithFormat:@"%hhd", self.quickTypeEnabled]; 
    debugLines[@"quickTypeDisplayFormat"] = [NSString stringWithFormat:@"%ld", (long)self.quickTypeDisplayFormat]; 
    debugLines[@"hasPromptedForAutoFillEnrol"] = [NSString stringWithFormat:@"%hhd", self.hasPromptedForAutoFillEnrol]; 
    debugLines[@"outstandingUpdateId"] = [NSString stringWithFormat:@"%@", self.outstandingUpdateId]; 
    debugLines[@"lastSyncRemoteModDate"] = [NSString stringWithFormat:@"%@", self.lastSyncRemoteModDate.iso8601DateString]; 
    debugLines[@"lastSyncAttempt"] = [NSString stringWithFormat:@"%@", self.lastSyncAttempt.iso8601DateString]; 
    debugLines[@"launchAtStartup"] = [NSString stringWithFormat:@"%hhd", self.launchAtStartup]; 
    debugLines[@"autoPromptForConvenienceUnlockOnActivate"] = [NSString stringWithFormat:@"%hhd", self.autoPromptForConvenienceUnlockOnActivate]; 
    debugLines[@"autoFillConvenienceAutoUnlockTimeout"] = [NSString stringWithFormat:@"%ld", self.autoFillConvenienceAutoUnlockTimeout]; 
    debugLines[@"autoFillLastUnlockedAt"] = [NSString stringWithFormat:@"%@", self.autoFillLastUnlockedAt.iso8601DateString]; 
    debugLines[@"conflictResolutionStrategy"] = [NSString stringWithFormat:@"%ld", self.conflictResolutionStrategy]; 
    debugLines[@"monitorForExternalChanges"] = [NSString stringWithFormat:@"%hhd", self.monitorForExternalChanges]; 
    debugLines[@"monitorForExternalChangesInterval"] = [NSString stringWithFormat:@"%ld", self.monitorForExternalChangesInterval]; 
    debugLines[@"autoReloadAfterExternalChanges"] = [NSString stringWithFormat:@"%hhd", self.autoReloadAfterExternalChanges]; 
    debugLines[@"maxBackupKeepCount"] = [NSString stringWithFormat:@"%ld", self.maxBackupKeepCount]; 
    debugLines[@"makeBackups"] = [NSString stringWithFormat:@"%hhd", self.makeBackups]; 
    debugLines[@"userRequestOfflineOpenEphemeralFlagForDocument"] = [NSString stringWithFormat:@"%hhd", self.userRequestOfflineOpenEphemeralFlagForDocument]; 
    debugLines[@"alwaysOpenOffline"] = [NSString stringWithFormat:@"%hhd", self.alwaysOpenOffline]; 
    debugLines[@"readOnly"] = [NSString stringWithFormat:@"%hhd", self.readOnly]; 
    debugLines[@"showQuickView"] = [NSString stringWithFormat:@"%hhd", self.showQuickView]; 

    debugLines[@"noAlternatingRows"] = [NSString stringWithFormat:@"%hhd", self.noAlternatingRows]; 
    debugLines[@"showHorizontalGrid"] = [NSString stringWithFormat:@"%hhd", self.showHorizontalGrid]; 
    debugLines[@"showVerticalGrid"] = [NSString stringWithFormat:@"%hhd", self.showVerticalGrid]; 
    debugLines[@"doNotShowAutoCompleteSuggestions"] = [NSString stringWithFormat:@"%hhd", self.doNotShowAutoCompleteSuggestions]; 
    debugLines[@"doNotShowChangeNotifications"] = [NSString stringWithFormat:@"%hhd", self.doNotShowChangeNotifications]; 
    debugLines[@"outlineViewTitleIsReadonly"] = [NSString stringWithFormat:@"%hhd", self.outlineViewTitleIsReadonly]; 
    debugLines[@"concealEmptyProtectedFields"] = [NSString stringWithFormat:@"%hhd", self.concealEmptyProtectedFields]; 
    debugLines[@"startWithSearch"] = [NSString stringWithFormat:@"%hhd", self.startWithSearch]; 
    debugLines[@"showAdvancedUnlockOptions"] = [NSString stringWithFormat:@"%hhd", self.showAdvancedUnlockOptions]; 
    debugLines[@"expressDownloadFavIconOnNewOrUrlChanged"] = [NSString stringWithFormat:@"%hhd", self.expressDownloadFavIconOnNewOrUrlChanged]; 
    debugLines[@"doNotShowRecycleBinInBrowse"] = [NSString stringWithFormat:@"%hhd", self.doNotShowRecycleBinInBrowse]; 
    debugLines[@"showRecycleBinInSearchResults"] = [NSString stringWithFormat:@"%hhd", self.showRecycleBinInSearchResults]; 
    debugLines[@"uiDoNotSortKeePassNodesInBrowseView"] = [NSString stringWithFormat:@"%hhd", self.uiDoNotSortKeePassNodesInBrowseView]; 
    debugLines[@"hasSetInitialWindowPosition"] = [NSString stringWithFormat:@"%hhd", self.hasSetInitialWindowPosition]; 

    debugLines[@"autoFillScanCustomFields"] = [NSString stringWithFormat:@"%hhd", self.autoFillScanCustomFields]; 
    debugLines[@"autoFillScanNotes"] = [NSString stringWithFormat:@"%hhd", self.autoFillScanNotes]; 
    debugLines[@"unlockCount"] = [NSString stringWithFormat:@"%ld", self.unlockCount]; 
    debugLines[@"likelyFormat"] = [NSString stringWithFormat:@"%ld", self.likelyFormat]; 
    debugLines[@"emptyOrNilPwPreferNilCheckFirst"] = [NSString stringWithFormat:@"%hhd", self.emptyOrNilPwPreferNilCheckFirst]; 
    debugLines[@"isTouchIdEnabled"] = [NSString stringWithFormat:@"%hhd", self.isTouchIdEnabled]; 
    debugLines[@"isWatchUnlockEnabled"] = [NSString stringWithFormat:@"%hhd", self.isWatchUnlockEnabled]; 
    debugLines[@"hasPromptedForTouchIdEnrol"] = [NSString stringWithFormat:@"%hhd", self.hasPromptedForTouchIdEnrol]; 
    debugLines[@"touchIdPasswordExpiryPeriodHours"] = [NSString stringWithFormat:@"%ld", self.touchIdPasswordExpiryPeriodHours]; 
    debugLines[@"isConvenienceUnlockEnabled"] = [NSString stringWithFormat:@"%hhd", self.isConvenienceUnlockEnabled]; 
    debugLines[@"conveniencePasswordHasExpired"] = [NSString stringWithFormat:@"%hhd", self.conveniencePasswordHasExpired]; 
    debugLines[@"hasBeenPromptedForConvenience"] = [NSString stringWithFormat:@"%hhd", self.hasBeenPromptedForConvenience]; 
    debugLines[@"convenienceExpiryPeriod"] = [NSString stringWithFormat:@"%ld", self.convenienceExpiryPeriod]; 
    debugLines[@"conveniencePasswordHasBeenStored"] = [NSString stringWithFormat:@"%hhd", self.conveniencePasswordHasBeenStored]; 
    debugLines[@"autoFillConcealedFieldsAsCreds"] = [NSString stringWithFormat:@"%hhd", self.autoFillConcealedFieldsAsCreds]; 
    debugLines[@"autoFillUnConcealedFieldsAsCreds"] = [NSString stringWithFormat:@"%hhd", self.autoFillUnConcealedFieldsAsCreds]; 
    debugLines[@"asyncUpdateId"] = [NSString stringWithFormat:@"%@", self.asyncUpdateId]; 
    debugLines[@"promptedForAutoFetchFavIcon"] = [NSString stringWithFormat:@"%hhd", self.promptedForAutoFetchFavIcon]; 
    debugLines[@"iconSet"] = [NSString stringWithFormat:@"%ld", self.keePassIconSet]; 
    debugLines[@"sideBarNavigationContext"] = [NSString stringWithFormat:@"%ld", self.sideBarNavigationContext]; 
    debugLines[@"sideBarSelectedSpecial"] = [NSString stringWithFormat:@"%ld", self.sideBarSelectedSpecial]; 
    debugLines[@"sideBarSelectedAuditCategory"] = [NSString stringWithFormat:@"%ld", self.sideBarSelectedAuditCategory]; 
    debugLines[@"searchScope"] = [NSString stringWithFormat:@"%ld", self.searchScope]; 
    debugLines[@"showChildCountOnFolderInSidebar"] = [NSString stringWithFormat:@"%hhd", self.showChildCountOnFolderInSidebar]; 
    debugLines[@"customSortOrderForFields"] = [NSString stringWithFormat:@"%hhd", self.customSortOrderForFields]; 
    debugLines[@"autoFillCopyTotp"] = [NSString stringWithFormat:@"%hhd", self.autoFillCopyTotp]; 
    
    return debugLines;
}

- (NSDictionary<NSString*, NSString *> *)debugInfoLines {
    NSMutableDictionary<NSString*, NSString*>* debugLines = NSMutableDictionary.dictionary;
    
    @autoreleasepool {
        unsigned int count;
        Ivar *ivars = class_copyIvarList([DatabaseMetadata class], &count);
        DatabaseMetadata* safe = self.metadata;
        
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];

            const char *name = ivar_getName(ivar);
            const char *type = ivar_getTypeEncoding(ivar);
            ptrdiff_t offset = ivar_getOffset(ivar);

            NSString* strValue;
            if (strncmp(type, "i", 1) == 0) {
                int intValue = *(int*)((uintptr_t)safe + offset);
                strValue = [NSString stringWithFormat:@"%i", intValue];
            }
            else if (strncmp(type, "f", 1) == 0) {
                float floatValue = *(float*)((uintptr_t)safe + offset);
                strValue = [NSString stringWithFormat:@"%f", floatValue];
            }
            else if (strncmp(type, "c", 1) == 0) {
                char value = *(char*)((uintptr_t)safe + offset);
                strValue = [NSString stringWithFormat:@"%d", value];
            }
            else if (strncmp(type, "q", 1) == 0) {
                long long value = *(long long*)((uintptr_t)safe + offset);
                strValue = [NSString stringWithFormat:@"%lld", value];
            }
            else if (strncmp(type, "Q", 1) == 0) {
                unsigned long long value = *(unsigned long long*)((uintptr_t)safe + offset);
                strValue = [NSString stringWithFormat:@"%lld", value];
            }
            else if (strncmp(type, "B", 1) == 0) {
                BOOL value = *(BOOL*)((uintptr_t)safe + offset);
                strValue = [NSString stringWithFormat:@"%hhd", value];
            }
            else if (strncmp(type, "@", 1) == 0) {
                id value = object_getIvar(safe, ivar);
                strValue = [NSString stringWithFormat:@"%@", value];
            }
            
            
            if ( strValue ) {
                NSString* key = [NSString stringWithFormat:@"%s", name];
                debugLines[key] = strValue;
            }
            else {
                slog(@"WARNWARN Unknown iVar Type: %s - %s", type, name);
            }
        }
        free(ivars);
    }

    return debugLines;
}



- (KeePassIconSet)keePassIconSet {
    return self.metadata.iconSet;
}

- (void)setKeePassIconSet:(KeePassIconSet)keePassIconSet {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.iconSet = keePassIconSet;
    }];
}



- (OGNavigationContext)sideBarNavigationContext {
    return self.metadata.sideBarNavigationContext;
}

- (void)setSideBarNavigationContext:(OGNavigationContext)sideBarNavigationContext {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarNavigationContext = sideBarNavigationContext;
    }];
}

- (NSUUID *)sideBarSelectedFavouriteId {
    return self.metadata.sideBarSelectedFavouriteId;
}

- (void)setSideBarSelectedFavouriteId:(NSUUID *)sideBarSelectedFavouriteId {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarSelectedFavouriteId = sideBarSelectedFavouriteId;
    }];
}

- (NSUUID *)sideBarSelectedGroup {
    return self.metadata.sideBarSelectedGroup;
}

- (void)setSideBarSelectedGroup:(NSUUID *)sideBarSelectedGroup {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarSelectedGroup = sideBarSelectedGroup;
    }];
}

- (NSString *)sideBarSelectedTag {
    return self.metadata.sideBarSelectedTag;
}

- (void)setSideBarSelectedTag:(NSString *)sideBarSelectedTag {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarSelectedTag = sideBarSelectedTag;
    }];
}

- (OGNavigationSpecial)sideBarSelectedSpecial {
    return self.metadata.sideBarSelectedSpecial;
}

- (void)setSideBarSelectedSpecial:(OGNavigationSpecial)sideBarSelectedSpecial {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarSelectedSpecial = sideBarSelectedSpecial;
    }];
}

- (OGNavigationAuditCategory)sideBarSelectedAuditCategory {
    return self.metadata.sideBarSelectedAuditCategory;
}

- (void)setSideBarSelectedAuditCategory:(OGNavigationAuditCategory)sideBarSelectedAuditCategory {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarSelectedAuditCategory = sideBarSelectedAuditCategory;
    }];
}

- (NSArray<NSUUID *> *)browseSelectedItems {
    return self.metadata.browseSelectedItems;
}

- (void)setBrowseSelectedItems:(NSArray<NSUUID *> *)browseSelectedItems {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.browseSelectedItems = browseSelectedItems;
    }];
}

- (NSString *)searchText {
    return self.metadata.searchText;
}

- (void)setSearchText:(NSString *)searchText {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.searchText = searchText;
    }];
}

- (SearchScope)searchScope {
    return self.metadata.searchScope;
}

- (void)setSearchScope:(SearchScope)searchScope {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.searchScope = searchScope;
    }];
}

- (BOOL)searchIncludeGroups {
    return self.metadata.searchIncludeGroups;
}

- (void)setSearchIncludeGroups:(BOOL)searchIncludeGroups {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.searchIncludeGroups = searchIncludeGroups;
    }];
}

- (NSArray *)headerNodes {
    return self.metadata.headerNodes;
}

- (void)setHeaderNodes:(NSArray *)headerNodes {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.headerNodes = headerNodes;
    }];
}

- (BOOL)customSortOrderForFields {
    return self.metadata.customSortOrderForFields;
}

- (void)setCustomSortOrderForFields:(BOOL)customSortOrderForFields {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.customSortOrderForFields = customSortOrderForFields;
    }];
}

- (BOOL)autoFillCopyTotp {
    return self.metadata.autoFillCopyTotp;
}

- (void)setAutoFillCopyTotp:(BOOL)autoFillCopyTotp {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillCopyTotp = autoFillCopyTotp;
    }];
}

- (BOOL)showChildCountOnFolderInSidebar {
    return self.metadata.showChildCountOnFolderInSidebar;
}

- (void)setShowChildCountOnFolderInSidebar:(BOOL)showChildCountOnFolderInSidebar {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showChildCountOnFolderInSidebar = showChildCountOnFolderInSidebar;
    }];
}

- (SideBarChildCountFormat)sideBarChildCountFormat {
    return self.metadata.sideBarChildCountFormat;
}

- (void)setSideBarChildCountFormat:(SideBarChildCountFormat)sideBarChildCountFormat {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarChildCountFormat = sideBarChildCountFormat;
    }];
}

- (NSString *)sideBarChildCountGroupPrefix {
    return self.metadata.sideBarChildCountGroupPrefix;
}

- (void)setSideBarChildCountGroupPrefix:(NSString *)sideBarChildCountGroupPrefix {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarChildCountGroupPrefix = sideBarChildCountGroupPrefix;
    }];
}

- (NSString *)sideBarChildCountSeparator {
    return self.metadata.sideBarChildCountSeparator;
}

- (void)setSideBarChildCountSeparator:(NSString *)sideBarChildCountSeparator {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarChildCountSeparator = sideBarChildCountSeparator;
    }];
}

- (BOOL)sideBarChildCountShowZero {
    return self.metadata.sideBarChildCountShowZero;
}

- (void)setSideBarChildCountShowZero:(BOOL)sideBarChildCountShowZero {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarChildCountShowZero = sideBarChildCountShowZero;
    }];
}

- (BOOL)sideBarShowTotalCountOnHierarchy {
    return self.metadata.sideBarShowTotalCountOnHierarchy;
}

- (void)setSideBarShowTotalCountOnHierarchy:(BOOL)sideBarShowTotalCountOnHierarchy {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.sideBarShowTotalCountOnHierarchy = sideBarShowTotalCountOnHierarchy;
    }];
}



- (NSArray<NSString *> *)legacyFavouritesStore {
    return self.metadata.legacyFavouritesStore;
}

- (void)setLegacyFavouritesStore:(NSArray<NSString *> *)legacyFavouritesStore {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.legacyFavouritesStore = legacyFavouritesStore;
    }];
}

- (NSArray<NSString *> *)autoFillExcludedItems {
    return self.metadata.autoFillExcludedItems;
}

- (void)setAutoFillExcludedItems:(NSArray<NSString *> *)autoFillExcludedItems {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillExcludedItems = autoFillExcludedItems;
    }];
}

- (NSArray<NSString *> *)auditExcludedItems {
    return self.metadata.auditExcludedItems;
}

- (void)setAuditExcludedItems:(NSArray<NSString *> *)auditExcludedItems {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.auditExcludedItems = auditExcludedItems;
    }];
}





- (BOOL)searchDereferencedFields {
    return YES;
}

- (BOOL)showKeePass1BackupGroup {
    return self.showRecycleBinInSearchResults;
}

- (BOOL)showExpiredInSearch {
    return YES;
}

- (BOOL)hardwareKeyCRCaching {
    BOOL ret = self.metadata.hardwareKeyCRCaching;
    return ret;
}

- (void)setHardwareKeyCRCaching:(BOOL)hardwareKeyCRCaching {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hardwareKeyCRCaching = hardwareKeyCRCaching;
    }];
    [self clearCachedChallengeResponses];
}

- (BOOL)doNotRefreshChallengeInAF {
    return self.metadata.doNotRefreshChallengeInAF;
}

- (void)setDoNotRefreshChallengeInAF:(BOOL)doNotRefreshChallengeInAF {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotRefreshChallengeInAF = doNotRefreshChallengeInAF;
    }];
}

- (BOOL)hasOnboardedHardwareKeyCaching {
    return self.metadata.hasOnboardedHardwareKeyCaching;
}

- (void)setHasOnboardedHardwareKeyCaching:(BOOL)hasOnboardedHardwareKeyCaching {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasOnboardedHardwareKeyCaching = hasOnboardedHardwareKeyCaching;
    }];
}

- (NSDate *)lastChallengeRefreshAt {
    return self.metadata.lastChallengeRefreshAt;
}

- (void)setLastChallengeRefreshAt:(NSDate *)lastChallengeRefreshAt {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.lastChallengeRefreshAt = lastChallengeRefreshAt;
    }];
}

- (NSInteger)challengeRefreshIntervalSecs {
    return self.metadata.challengeRefreshIntervalSecs;
}

- (void)setChallengeRefreshIntervalSecs:(NSInteger)challengeRefreshIntervalSecs {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.challengeRefreshIntervalSecs = challengeRefreshIntervalSecs;
    }];
}

- (NSInteger)cacheChallengeDurationSecs {
    return self.metadata.cacheChallengeDurationSecs;
}

- (void)setCacheChallengeDurationSecs:(NSInteger)cacheChallengeDurationSecs {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.cacheChallengeDurationSecs = cacheChallengeDurationSecs;
    }];
    [self clearCachedChallengeResponses];
}

- (NSDictionary<NSData *,NSData *> *)cachedYubiKeyChallengeResponses {
    return self.metadata.cachedYubiKeyChallengeResponses;
}

- (void)setCachedYubiKeyChallengeResponses:(NSDictionary<NSData *,NSData *> *)cachedYubiKeyChallengeResponses {
    self.metadata.cachedYubiKeyChallengeResponses = cachedYubiKeyChallengeResponses; 
}

- (void)addCachedChallengeResponse:(MMcGPair<NSData *,NSData *> *)challengeResponse {
    slog(@"🐞 addCachedChallengeResponse [%@] -> [%@]", challengeResponse.a.base64String, challengeResponse.b.base64String );
    self.cachedYubiKeyChallengeResponses = @{ challengeResponse.a : challengeResponse.b }; 
}

- (void)removeCachedChallenge:(NSData *)challenge {
    slog(@"🐞 removeCachedChallenge [%@]", challenge.base64String );
    [self clearCachedChallengeResponses];
}

- (void)clearCachedChallengeResponses {
    self.cachedYubiKeyChallengeResponses = @{};
}

- (NSData *)getCachedChallengeResponse:(NSData *)challenge {
    NSData* ret = self.cachedYubiKeyChallengeResponses[challenge];
    
    slog(@"🐞 getCachedChallengeResponse [%@] -> [%@]", challenge.base64String, ret.base64String );
    
    return ret;
}

- (BOOL)markDirtyOnExpandCollapseGroups {
    return self.metadata.markDirtyOnExpandCollapseGroups;
}

- (void)setMarkDirtyOnExpandCollapseGroups:(BOOL)markDirtyOnExpandCollapseGroups {
    [self update:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.markDirtyOnExpandCollapseGroups = markDirtyOnExpandCollapseGroups;
    }];
}

@end
