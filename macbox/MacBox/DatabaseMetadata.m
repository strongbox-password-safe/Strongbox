//
//  SafeMetaData.m
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabaseMetadata.h"
#import "SecretStore.h"
#import "BookmarksHelper.h"
#import "StrongboxMacFilesManager.h"
#import "Settings.h"
#import "NSDate+Extensions.h"

const NSInteger kDefaultPasswordExpiryHours = -1; // Forever 14 * 24; // 2 weeks
static NSString* const kStrongboxICloudContainerIdentifier = @"iCloud.com.strongbox";

const NSInteger kDefaultCacheChallengeDurationSecs = 8 * 60 * 60; 
const NSInteger kDefaultChallengeRefreshIntervalSecs = 0; 

@interface DatabaseMetadata ()


@property (nonatomic) BOOL isTouchIdEnrolled; 

@property BOOL isEnrolledForConvenience; 
@property BOOL isAutoFillMemOnlyConveniencePasswordHasBeenStored; 

@end

@implementation DatabaseMetadata

- (instancetype)init {
    self = [super init];
    if (self) {
        _uuid = [[NSUUID UUID] UUIDString];
        
        self.touchIdPasswordExpiryPeriodHours = kDefaultPasswordExpiryHours;
        self.quickTypeDisplayFormat = kQuickTypeFormatTitleThenUsername;
        self.autoFillConvenienceAutoUnlockTimeout = 180; 
        self.monitorForExternalChanges = YES;
        self.autoReloadAfterExternalChanges = YES;
        self.makeBackups = YES;
        self.maxBackupKeepCount = 10;
        self.conflictResolutionStrategy = kConflictResolutionStrategyAutoMerge;
        self.showQuickView = YES;
        self.outlineViewTitleIsReadonly = NO;
        self.concealEmptyProtectedFields = YES;
        self.startWithSearch = YES; 
        self.visibleColumns = @[kTitleColumn, kUsernameColumn, kPasswordColumn, kURLColumn];
        
        self.autoFillScanCustomFields = NO;
        self.autoFillScanNotes = NO;
        self.autoFillConcealedFieldsAsCreds = YES;
        self.iconSet = kKeePassIconSetSfSymbols;
        self.browseSelectedItems = @[];
        self.auditConfig = DatabaseAuditorConfiguration.defaults;
        self.headerNodes = HeaderNodeState.defaults;
        self.autoFillCopyTotp = YES;
        self.searchScope = kSearchScopeAll;

        self.customSortOrderForFields = YES; 
        
        
        
        self.showChildCountOnFolderInSidebar = YES;
        self.sideBarChildCountFormat = kSideBarChildCountFormatEntries;
        self.sideBarChildCountGroupPrefix = @"📁";
        self.sideBarChildCountSeparator = @"/";
        self.sideBarChildCountShowZero = YES;
        self.sideBarShowTotalCountOnHierarchy = YES;
        
        self.includeAssociatedDomains = YES;
        self.quickTypeEnabled = YES;
        self.cacheChallengeDurationSecs = kDefaultCacheChallengeDurationSecs;
        self.challengeRefreshIntervalSecs = kDefaultChallengeRefreshIntervalSecs;
        self.doNotRefreshChallengeInAF = YES;
    }
    
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo {
    if(self = [self init]) {
        _nickName = nickName ? nickName : @"<Unknown>";
        self.storageProvider = storageProvider;
        self.monitorForExternalChangesInterval = [self getDefaultMonitorExternalChangesInterval]; 
        self.fileUrl = fileUrl;
        self.storageInfo = storageInfo;
    }
    
    return self;
}



- (NSUInteger)getDefaultMonitorExternalChangesInterval {
    return (self.storageProvider == kLocalDevice || self.storageProvider == kWiFiSync) ? 5 : 30;
}


- (NSString*)getConveniencePasswordIdentifier {
#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        return [NSString stringWithFormat:@"convenience-pw-af-mem-only-%@", self.uuid];
    }
#endif
    
    return [NSString stringWithFormat:@"convenience-pw-%@", self.uuid];
}

- (void)triggerPasswordExpiry {
    BOOL expired = NO;
    [SecretStore.sharedInstance getSecureObject:[self getConveniencePasswordIdentifier] expired:&expired];
    
    if ( expired ) { 
        self.conveniencePasswordHasExpired = YES;
    }
}

- (NSString *)conveniencePassword {
    BOOL expired = NO;
    NSString* object = (NSString*)[SecretStore.sharedInstance getSecureObject:[self getConveniencePasswordIdentifier] expired:&expired];
    
    if ( expired ) { 
        self.conveniencePasswordHasExpired = YES;
    }
    
    return object;
}

- (void)setConveniencePassword:(NSString*)password {
    NSInteger expiringAfterHours = self.touchIdPasswordExpiryPeriodHours;
    
    if ( self.conveniencePasswordHasExpired ) {
        self.conveniencePasswordHasExpired = NO;
    }
    
    NSString* identifier = [self getConveniencePasswordIdentifier];
    if(expiringAfterHours == -1) {
        [SecretStore.sharedInstance setSecureString:password forIdentifier:identifier];
    }
    else if(expiringAfterHours == 0) {
        [SecretStore.sharedInstance setSecureEphemeralObject:password forIdentifer:identifier];
    }
    else {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *date = [cal dateByAddingUnit:NSCalendarUnitHour value:expiringAfterHours toDate:[NSDate date] options:0];
        [SecretStore.sharedInstance setSecureObject:password forIdentifier:identifier expiresAt:date];
    }
}

- (SecretExpiryMode)getConveniencePasswordExpiryMode {
    NSString* identifier = [self getConveniencePasswordIdentifier];
    return [SecretStore.sharedInstance getSecureObjectExpiryMode:identifier];
}

- (NSDate *)getConveniencePasswordExpiryDate {
    NSString* identifier = [self getConveniencePasswordIdentifier];
    return [SecretStore.sharedInstance getSecureObjectExpiryDate:identifier];
}

- (NSString *)autoFillConvenienceAutoUnlockPassword {
    NSString *key = [NSString stringWithFormat:@"%@-autoFillConvenienceAutoUnlockPassword", self.uuid];
    
    if( self.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        return [SecretStore.sharedInstance getSecureString:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
        return nil;
    }
}

- (void)setAutoFillConvenienceAutoUnlockPassword:(NSString *)autoFillConvenienceAutoUnlockPassword {
    NSString *key = [NSString stringWithFormat:@"%@-autoFillConvenienceAutoUnlockPassword", self.uuid];
    
    if(self.autoFillConvenienceAutoUnlockTimeout > 0 && autoFillConvenienceAutoUnlockPassword) {
        NSDate* expiry = [NSDate.date dateByAddingTimeInterval:self.autoFillConvenienceAutoUnlockTimeout];
        
        slog(@"Setting AutoFIll convenience auto unlock expiry to: [%@]", expiry);
        
        [SecretStore.sharedInstance setSecureObject:autoFillConvenienceAutoUnlockPassword forIdentifier:key expiresAt:expiry];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}



- (NSString *)autoFillKeyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"autoFill-keyFileBookmark-%@", self.uuid];
    return [SecretStore.sharedInstance getSecureString:account];
}

- (void)setAutoFillKeyFileBookmark:(NSString *)autoFillKeyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"autoFill-keyFileBookmark-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:autoFillKeyFileBookmark forIdentifier:account];
}

- (NSString *)keyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"keyFileBookmark-%@", self.uuid];
    return [SecretStore.sharedInstance getSecureString:account];
}

- (void)setKeyFileBookmark:(NSString *)keyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"keyFileBookmark-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:keyFileBookmark forIdentifier:account];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%lu] - [%@-%@]", self.nickName, (unsigned long)self.storageProvider, self.fileUrl, self.storageInfo];
}



- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.uuid forKey:@"uuid"];
    [encoder encodeObject:self.nickName forKey:@"nickName"];
    [encoder encodeObject:self.fileUrl forKey:@"fileUrl"];
    [encoder encodeObject:self.storageInfo forKey:@"fileIdentifier"];
    [encoder encodeInteger:self.storageProvider forKey:@"storageProvider"];
    [encoder encodeBool:self.isTouchIdEnabled forKey:@"isTouchIdEnabled"];
    [encoder encodeBool:self.hasPromptedForTouchIdEnrol forKey:@"hasPromptedForTouchIdEnrol"];
    [encoder encodeInteger:self.touchIdPasswordExpiryPeriodHours forKey:@"touchIdPasswordExpiryPeriodHours"];
    [encoder encodeBool:self.isTouchIdEnrolled forKey:@"isTouchIdEnrolled"];
    [encoder encodeObject:self.yubiKeyConfiguration forKey:@"yubiKeyConfiguration"];
    [encoder encodeObject:self.autoFillStorageInfo forKey:@"autoFillStorageInfo"];
    [encoder encodeBool:self.autoFillEnabled forKey:@"autoFillEnabled"];
    [encoder encodeBool:self.quickTypeEnabled forKey:@"quickTypeEnabled"];
    [encoder encodeBool:self.hasPromptedForAutoFillEnrol forKey:@"hasPromptedForAutoFillEnrol"];
    [encoder encodeInteger:self.quickTypeDisplayFormat forKey:@"quickTypeDisplayFormat"];
    
    [encoder encodeInteger:self.conflictResolutionStrategy forKey:@"conflictResolutionStrategy2"];
    [encoder encodeObject:self.outstandingUpdateId forKey:@"outstandingUpdateId"];
    [encoder encodeObject:self.lastSyncRemoteModDate forKey:@"lastSyncRemoteModDate"];
    [encoder encodeObject:self.lastSyncAttempt forKey:@"lastSyncAttempt"];
    
    [encoder encodeBool:self.launchAtStartup forKey:@"launchAtStartup"];
    
    [encoder encodeBool:self.isWatchUnlockEnabled forKey:@"isWatchUnlockEnabled"];

    
    [encoder encodeObject:self.autoFillLastUnlockedAt forKey:@"autoFillLastUnlockedAt"];
    [encoder encodeInteger:self.autoFillConvenienceAutoUnlockTimeout forKey:@"autoFillConvenienceAutoUnlockTimeout"];
    
    [encoder encodeBool:self.monitorForExternalChanges forKey:@"monitorForExternalChanges"];
    [encoder encodeInteger:self.monitorForExternalChangesInterval forKey:@"monitorForExternalChangesInterval"];
    [encoder encodeBool:self.autoReloadAfterExternalChanges forKey:@"autoReloadAfterExternalChanges"];
    
    [encoder encodeInteger:self.maxBackupKeepCount forKey:@"maxBackupKeepCount"];
    [encoder encodeBool:self.makeBackups forKey:@"makeBackups"];
    [encoder encodeBool:self.userRequestOfflineOpenEphemeralFlagForDocument forKey:@"offlineMode"];
    [encoder encodeBool:self.readOnly forKey:@"readOnly"];
    [encoder encodeBool:self.alwaysOpenOffline forKey:@"alwaysOpenOffline"];
    
    /* =================================================================================================== */
    /* Migrated to Per Database Settings - Begin 14 Jun 2021 - Give 3 months migration time -> 14-Sep-2021 */
    
    [encoder encodeBool:self.showQuickView forKey:@"showQuickView"];
    [encoder encodeBool:self.doNotShowTotp forKey:@"doNotShowTotp"];
    [encoder encodeBool:self.noAlternatingRows forKey:@"noAlternatingRows"];
    [encoder encodeBool:self.showHorizontalGrid forKey:@"showHorizontalGrid"];
    [encoder encodeBool:self.showVerticalGrid forKey:@"showVerticalGrid"];
    [encoder encodeBool:self.doNotShowAutoCompleteSuggestions forKey:@"doNotShowAutoCompleteSuggestions"];
    [encoder encodeBool:self.doNotShowChangeNotifications forKey:@"doNotShowChangeNotifications"];
    [encoder encodeBool:self.outlineViewTitleIsReadonly forKey:@"outlineViewTitleIsReadonly"];
    [encoder encodeBool:self.concealEmptyProtectedFields forKey:@"concealEmptyProtectedFields"];
    [encoder encodeBool:self.startWithSearch forKey:@"startWithSearch"];
    [encoder encodeBool:self.showAdvancedUnlockOptions forKey:@"showAdvancedUnlockOptions"];
    [encoder encodeBool:self.expressDownloadFavIconOnNewOrUrlChanged forKey:@"expressDownloadFavIconOnNewOrUrlChanged"];
    [encoder encodeBool:self.doNotShowRecycleBinInBrowse forKey:@"doNotShowRecycleBinInBrowse"];
    [encoder encodeBool:self.showRecycleBinInSearchResults forKey:@"showRecycleBinInSearchResults"];
    [encoder encodeBool:self.uiDoNotSortKeePassNodesInBrowseView forKey:@"uiDoNotSortKeePassNodesInBrowseView"];
    [encoder encodeObject:self.visibleColumns forKey:@"visibleColumns"];
    
    /* =================================================================================================== */
    
    [encoder encodeBool:self.hasSetInitialWindowPosition forKey:@"hasSetInitialWindowPosition"];
    [encoder encodeBool:self.hasSetInitialUnlockedFrame forKey:@"hasSetInitialUnlockedFrame"];
    
    [encoder encodeBool:self.autoFillScanCustomFields forKey:@"autoFillScanCustomFields"];
    [encoder encodeBool:self.autoFillScanNotes forKey:@"autoFillScanNotes"];
    
    [encoder encodeInteger:self.unlockCount forKey:@"unlockCount"];
    [encoder encodeInteger:self.likelyFormat forKey:@"likelyFormat"];
    [encoder encodeBool:self.emptyOrNilPwPreferNilCheckFirst forKey:@"emptyOrNilPwPreferNilCheckFirst"];
    
    [encoder encodeBool:self.isAutoFillMemOnlyConveniencePasswordHasBeenStored forKey:@"isAutoFillMemOnlyConveniencePasswordHasBeenStored"];
    
    [encoder encodeBool:self.autoFillConcealedFieldsAsCreds forKey:@"autoFillConcealedFieldsAsCreds"];
    [encoder encodeBool:self.autoFillUnConcealedFieldsAsCreds forKey:@"autoFillUnConcealedFieldsAsCreds"];
    [encoder encodeObject:self.asyncUpdateId forKey:@"asyncUpdateId"];
    
    [encoder encodeBool:self.promptedForAutoFetchFavIcon forKey:@"promptedForAutoFetchFavIcon"];
    [encoder encodeInteger:self.iconSet forKey:@"iconSet"];
    
    
    
    [encoder encodeInteger:self.sideBarNavigationContext forKey:@"sideBarNavigationContext"];
    [encoder encodeObject:self.sideBarSelectedGroup forKey:@"sideBarSelectedGroup"];
    [encoder encodeInteger:self.sideBarSelectedSpecial forKey:@"sideBarSelectedSpecial"];
    [encoder encodeObject:self.browseSelectedItems forKey:@"browseSelectedItems"];
    
    [encoder encodeObject:self.auditConfig forKey:@"auditorConfig"];
    [encoder encodeInteger:self.sideBarSelectedAuditCategory forKey:@"sideBarSelectedAuditCategory"];
    
    [encoder encodeObject:self.sideBarSelectedFavouriteId forKey:@"sideBarSelectedFavouriteId"];
    
    [encoder encodeObject:self.headerNodes forKey:@"headerNodes2"];
    
    [encoder encodeBool:self.customSortOrderForFields forKey:@"customSortOrderForFields"];
    [encoder encodeBool:self.autoFillCopyTotp forKey:@"autoFillCopyTotp"];
    [encoder encodeInteger:self.searchScope forKey:@"searchScope"];
    [encoder encodeBool:self.searchIncludeGroups forKey:@"searchIncludeGroups"];
    
    
    
    [encoder encodeBool:self.showChildCountOnFolderInSidebar forKey:@"showChildCountOnFolderInSidebar"];
    [encoder encodeInteger:self.sideBarChildCountFormat forKey:@"sideBarChildCountFormat"];
    [encoder encodeObject:self.sideBarChildCountGroupPrefix forKey:@"sideBarChildCountGroupPrefix"];
    [encoder encodeObject:self.sideBarChildCountSeparator forKey:@"sideBarChildCountSeparator"];
    [encoder encodeBool:self.sideBarChildCountShowZero forKey:@"sideBarChildCountShowZero"];
    [encoder encodeBool:self.sideBarShowTotalCountOnHierarchy forKey:@"sideBarShowTotalCountOnHierarchy"];
    
    [encoder encodeBool:self.includeAssociatedDomains forKey:@"includeAssociatedDomains"];
    
    if ( self.lastKnownEncryptionSettings ) {
        [encoder encodeObject:self.lastKnownEncryptionSettings forKey:@"lastKnownEncryptionSettings"];
    }
    
    if ( self.serializationPerf ) {
        [encoder encodeObject:self.serializationPerf forKey:@"serializationPerf"];
    }
    
    [encoder encodeBool:self.isSharedInCloudKit forKey:@"isSharedInCloudKit"];
    [encoder encodeBool:self.isOwnedByMeCloudKit forKey:@"isOwnedByMeCloudKit"];

    [encoder encodeBool:self.hardwareKeyCRCaching forKey:@"hardwareKeyCRCaching"];
    
    [encoder encodeObject:self.lastChallengeRefreshAt forKey:@"lastChallengeRefreshAt"];
    [encoder encodeInteger:self.challengeRefreshIntervalSecs forKey:@"challengeRefreshIntervalSecs"];
    [encoder encodeInteger:self.cacheChallengeDurationSecs forKey:@"cacheChallengeDurationSecs"];
    
    [encoder encodeBool:self.doNotRefreshChallengeInAF forKey:@"doNotRefreshChallengeInAF"];
    [encoder encodeBool:self.hasOnboardedHardwareKeyCaching forKey:@"hasOnboardedHardwareKeyCaching"];
    [encoder encodeBool:self.markDirtyOnExpandCollapseGroups forKey:@"markDirtyOnExpandCollapseGroups"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.nickName = self.nickName ? self.nickName : @"<Unknown>";
        
        self.fileUrl = [decoder decodeObjectForKey:@"fileUrl"];
        self.storageInfo = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
        
        if([decoder containsValueForKey:@"hasPromptedForTouchIdEnrol"]) {
            self.hasPromptedForTouchIdEnrol = [decoder decodeBoolForKey:@"hasPromptedForTouchIdEnrol"];
        }
        
        if([decoder containsValueForKey:@"touchIdPasswordExpiryPeriodHours"]) {
            self.touchIdPasswordExpiryPeriodHours = [decoder decodeIntegerForKey:@"touchIdPasswordExpiryPeriodHours"];
        }
        
        if([decoder containsValueForKey:@"isTouchIdEnrolled"]) {
            self.isTouchIdEnrolled = [decoder decodeBoolForKey:@"isTouchIdEnrolled"];
        }
        else {
            self.isTouchIdEnrolled = self.conveniencePassword != nil;
        }
        
        if ([decoder containsValueForKey:@"yubiKeyConfiguration"]) {
            self.yubiKeyConfiguration = [decoder decodeObjectForKey:@"yubiKeyConfiguration"];
        }
        
        if ( [decoder containsValueForKey:@"autoFillStorageInfo"] ) {
            self.autoFillStorageInfo = [decoder decodeObjectForKey:@"autoFillStorageInfo"];
        }
        
        if([decoder containsValueForKey:@"quickTypeEnabled"]) {
            self.quickTypeEnabled = [decoder decodeBoolForKey:@"quickTypeEnabled"];
        }
        else {
            self.quickTypeEnabled = YES;
        }
        
        if([decoder containsValueForKey:@"autoFillEnabled"]) {
            self.autoFillEnabled = [decoder decodeBoolForKey:@"autoFillEnabled"];
        }
        
        if([decoder containsValueForKey:@"hasPromptedForAutoFillEnrol"]) {
            self.hasPromptedForAutoFillEnrol = [decoder decodeBoolForKey:@"hasPromptedForAutoFillEnrol"];
        }
        
        if([decoder containsValueForKey:@"quickTypeDisplayFormat"]) {
            self.quickTypeDisplayFormat = [decoder decodeIntegerForKey:@"quickTypeDisplayFormat"];
        }
        
        if ( [decoder containsValueForKey:@"outstandingUpdateId"] ) {
            self.outstandingUpdateId = [decoder decodeObjectForKey:@"outstandingUpdateId"];
        }
        
        if ( [decoder containsValueForKey:@"lastSyncRemoteModDate"] ) {
            self.lastSyncRemoteModDate = [decoder decodeObjectForKey:@"lastSyncRemoteModDate"];
        }
        
        if ( [decoder containsValueForKey:@"lastSyncAttempt"] ) {
            self.lastSyncAttempt = [decoder decodeObjectForKey:@"lastSyncAttempt"];
        }
        
        if([decoder containsValueForKey:@"launchAtStartup"]) {
            self.launchAtStartup = [decoder decodeBoolForKey:@"launchAtStartup"];
        }
        
        if( [decoder containsValueForKey:@"isWatchUnlockEnabled"] ) {
            self.isWatchUnlockEnabled = [decoder decodeBoolForKey:@"isWatchUnlockEnabled"];
        }
        else {
            self.isWatchUnlockEnabled = self.isTouchIdEnabled; 
        }
        



        
        if( [decoder containsValueForKey:@"autoFillLastUnlockedAt"] ) {
            self.autoFillLastUnlockedAt = [decoder decodeObjectForKey:@"autoFillLastUnlockedAt"];
        }
        
        if( [decoder containsValueForKey:@"autoFillConvenienceAutoUnlockTimeout"] ) {
            self.autoFillConvenienceAutoUnlockTimeout = [decoder decodeIntegerForKey:@"autoFillConvenienceAutoUnlockTimeout"];
        }
        else {
            self.autoFillConvenienceAutoUnlockTimeout = -1; 
        }
        
        if( [decoder containsValueForKey:@"monitorForExternalChanges"] ) {
            self.monitorForExternalChanges = [decoder decodeBoolForKey:@"monitorForExternalChanges"];
        }
        
        if( [decoder containsValueForKey:@"monitorForExternalChangesInterval"] ) {
            self.monitorForExternalChangesInterval = [decoder decodeIntegerForKey:@"monitorForExternalChangesInterval"];
        }
        else {
            self.monitorForExternalChangesInterval = [self getDefaultMonitorExternalChangesInterval]; 
        }
        
        if( [decoder containsValueForKey:@"autoReloadAfterExternalChanges"] ) {
            self.autoReloadAfterExternalChanges = [decoder decodeBoolForKey:@"autoReloadAfterExternalChanges"];
        }
        
        if([decoder containsValueForKey:@"conflictResolutionStrategy2"]) {
            self.conflictResolutionStrategy = [decoder decodeIntegerForKey:@"conflictResolutionStrategy2"];
        }
        else {
            self.conflictResolutionStrategy = kConflictResolutionStrategyAsk;
        }
        
        if ( [decoder containsValueForKey:@"maxBackupKeepCount"] ) {
            self.maxBackupKeepCount = [decoder decodeIntegerForKey:@"maxBackupKeepCount"];
        }
        
        if ( [decoder containsValueForKey:@"makeBackups"] ) {
            self.makeBackups = [decoder decodeBoolForKey:@"makeBackups"];
        }
        if ( [decoder containsValueForKey:@"offlineMode"] ) {
            self.userRequestOfflineOpenEphemeralFlagForDocument = [decoder decodeBoolForKey:@"offlineMode"];
        }
        if ( [decoder containsValueForKey:@"readOnly"] ) {
            self.readOnly = [decoder decodeBoolForKey:@"readOnly"];
        }
        if ( [decoder containsValueForKey:@"alwaysOpenOffline"] ) {
            self.alwaysOpenOffline = [decoder decodeBoolForKey:@"alwaysOpenOffline"];
        }
        
        /* =================================================================================================== */
        /* Migrated to Per Database Settings - Begin 14 Jun 2021 - Give 3 months migration time -> 14-Sep-2021 */
        
        if ( [decoder containsValueForKey:@"showQuickView"] ) {
            self.showQuickView = [decoder decodeBoolForKey:@"showQuickView"];
        }
        
        if ( [decoder containsValueForKey:@"doNotShowTotp"] ) {
            self.doNotShowTotp = [decoder decodeBoolForKey:@"doNotShowTotp"];
        }
        
        if ( [decoder containsValueForKey:@"noAlternatingRows"] ) {
            self.noAlternatingRows = [decoder decodeBoolForKey:@"noAlternatingRows"];
        }
        
        if ( [decoder containsValueForKey:@"showHorizontalGrid"] ) {
            self.showHorizontalGrid = [decoder decodeBoolForKey:@"showHorizontalGrid"];
        }
        
        if ( [decoder containsValueForKey:@"showVerticalGrid"] ) {
            self.showVerticalGrid = [decoder decodeBoolForKey:@"showVerticalGrid"];
        }
        
        if ( [decoder containsValueForKey:@"doNotShowAutoCompleteSuggestions"] ) {
            self.doNotShowAutoCompleteSuggestions = [decoder decodeBoolForKey:@"doNotShowAutoCompleteSuggestions"];
        }
        
        if ( [decoder containsValueForKey:@"doNotShowChangeNotifications"] ) {
            self.doNotShowChangeNotifications = [decoder decodeBoolForKey:@"doNotShowChangeNotifications"];
        }
        
        if ( [decoder containsValueForKey:@"outlineViewTitleIsReadonly"] ) {
            self.outlineViewTitleIsReadonly = [decoder decodeBoolForKey:@"outlineViewTitleIsReadonly"];
        }
        
        if ( [decoder containsValueForKey:@"concealEmptyProtectedFields"] ) {
            self.concealEmptyProtectedFields = [decoder decodeBoolForKey:@"concealEmptyProtectedFields"];
        }
        
        if ( [decoder containsValueForKey:@"startWithSearch"] ) {
            self.startWithSearch = [decoder decodeBoolForKey:@"startWithSearch"];
        }
        
        if ( [decoder containsValueForKey:@"showAdvancedUnlockOptions"] ) {
            self.showAdvancedUnlockOptions = [decoder decodeBoolForKey:@"showAdvancedUnlockOptions"];
        }
        
        if ( [decoder containsValueForKey:@"expressDownloadFavIconOnNewOrUrlChanged"] ) {
            self.expressDownloadFavIconOnNewOrUrlChanged = [decoder decodeBoolForKey:@"expressDownloadFavIconOnNewOrUrlChanged"];
        }
        
        if ( [decoder containsValueForKey:@"doNotShowRecycleBinInBrowse"] ) {
            self.doNotShowRecycleBinInBrowse = [decoder decodeBoolForKey:@"doNotShowRecycleBinInBrowse"];
        }
        
        if ( [decoder containsValueForKey:@"showRecycleBinInSearchResults"] ) {
            self.showRecycleBinInSearchResults = [decoder decodeBoolForKey:@"showRecycleBinInSearchResults"];
        }
        
        if ( [decoder containsValueForKey:@"uiDoNotSortKeePassNodesInBrowseView"] ) {
            self.uiDoNotSortKeePassNodesInBrowseView = [decoder decodeBoolForKey:@"uiDoNotSortKeePassNodesInBrowseView"];
        }
        
        if ( [decoder containsValueForKey:@"visibleColumns"] ) {
            self.visibleColumns = [decoder decodeObjectForKey:@"visibleColumns"];
        }
        
        /* =================================================================================================== */
        
        if ( [decoder containsValueForKey:@"hasSetInitialWindowPosition"] ) {
            self.hasSetInitialWindowPosition = [decoder decodeBoolForKey:@"hasSetInitialWindowPosition"];
        }
        else {
            self.hasSetInitialWindowPosition = YES; 
        }
        
        if ( [decoder containsValueForKey:@"hasSetInitialUnlockedFrame"] ) {
            self.hasSetInitialUnlockedFrame = [decoder decodeBoolForKey:@"hasSetInitialUnlockedFrame"];
        }
        else {
            self.hasSetInitialUnlockedFrame = YES; 
        }
        
        
        
        if ( [decoder containsValueForKey:@"autoFillScanCustomFields"] ) {
            self.autoFillScanCustomFields = [decoder decodeBoolForKey:@"autoFillScanCustomFields"];
        }
        else {
            self.autoFillScanCustomFields = NO;
        }
        
        if ( [decoder containsValueForKey:@"autoFillScanNotes"] ) {
            self.autoFillScanNotes = [decoder decodeBoolForKey:@"autoFillScanNotes"];
        }
        else {
            self.autoFillScanNotes = YES;
        }
        
        
        
        if ( [decoder containsValueForKey:@"unlockCount"] ) {
            self.unlockCount = [decoder decodeIntegerForKey:@"unlockCount"];
        }
        if ( [decoder containsValueForKey:@"likelyFormat"] ) {
            self.likelyFormat = [decoder decodeIntegerForKey:@"likelyFormat"];
        }
        if ( [decoder containsValueForKey:@"emptyOrNilPwPreferNilCheckFirst"] ) {
            self.emptyOrNilPwPreferNilCheckFirst = [decoder decodeBoolForKey:@"emptyOrNilPwPreferNilCheckFirst"];
        }
        
        
        
        if ( [decoder containsValueForKey:@"isAutoFillMemOnlyConveniencePasswordHasBeenStored"] ) {
            self.isAutoFillMemOnlyConveniencePasswordHasBeenStored = [decoder decodeBoolForKey:@"isAutoFillMemOnlyConveniencePasswordHasBeenStored"];
        }
        
        
        
        if ( [decoder containsValueForKey:@"autoFillConcealedFieldsAsCreds"] ) {
            self.autoFillConcealedFieldsAsCreds = [decoder decodeBoolForKey:@"autoFillConcealedFieldsAsCreds"];
        }
        else {
            self.autoFillConcealedFieldsAsCreds = YES;
        }
        
        if ( [decoder containsValueForKey:@"autoFillUnConcealedFieldsAsCreds"] ) {
            self.autoFillUnConcealedFieldsAsCreds = [decoder decodeBoolForKey:@"autoFillUnConcealedFieldsAsCreds"];
        }
        
        if ( [decoder containsValueForKey:@"asyncUpdateId"] ) {
            self.asyncUpdateId = [decoder decodeObjectForKey:@"asyncUpdateId"];
        }
        
        if ( [decoder containsValueForKey:@"promptedForAutoFetchFavIcon"] ) {
            self.promptedForAutoFetchFavIcon = [decoder decodeBoolForKey:@"promptedForAutoFetchFavIcon"];
        }
        else {
            self.promptedForAutoFetchFavIcon = [decoder decodeBoolForKey:@"expressDownloadFavIconOnNewOrUrlChanged"]; 
        }
        
        
        
        if ( [decoder containsValueForKey:@"iconSet"] ) {
            self.iconSet = [decoder decodeIntegerForKey:@"iconSet"];
        }
        else {
            self.iconSet = kKeePassIconSetSfSymbols;
        }
        
        
        
        if ( [decoder containsValueForKey:@"sideBarNavigationContext"] ) {
            self.sideBarNavigationContext = [decoder decodeIntegerForKey:@"sideBarNavigationContext"];
        }
        else {
            self.sideBarNavigationContext = OGNavigationContextNone; 
        }
        
        if ( [decoder containsValueForKey:@"sideBarSelectedGroup"] ) {
            self.sideBarSelectedGroup = [decoder decodeObjectForKey:@"sideBarSelectedGroup"];
        }
        else {
            self.sideBarSelectedGroup = nil;
        }
        
        if ( [decoder containsValueForKey:@"sideBarSelectedSpecial"] ) {
            self.sideBarSelectedSpecial = [decoder decodeIntegerForKey:@"sideBarSelectedSpecial"];
        }
        
        if ( [decoder containsValueForKey:@"sideBarSelectedAuditCategory"] ) {
            self.sideBarSelectedAuditCategory = [decoder decodeIntegerForKey:@"sideBarSelectedAuditCategory"];
        }
        
        if ( [decoder containsValueForKey:@"browseSelectedItems"] ) {
            self.browseSelectedItems = [decoder decodeObjectForKey:@"browseSelectedItems"];
        }
        else {
            self.browseSelectedItems = @[];
        }
        
        if ( [decoder containsValueForKey:@"auditorConfig"]) {
            self.auditConfig = [decoder decodeObjectForKey:@"auditorConfig"];
        }
        else {
            self.auditConfig = DatabaseAuditorConfiguration.defaults;
        }
        
        if ( [decoder containsValueForKey:@"sideBarSelectedFavouriteId"] ) {
            self.sideBarSelectedFavouriteId = [decoder decodeObjectForKey:@"sideBarSelectedFavouriteId"];
        }
        else {
            self.sideBarSelectedFavouriteId = nil;
        }
        
        if ( [decoder containsValueForKey:@"headerNodes2"] ) {
            self.headerNodes = [decoder decodeObjectForKey:@"headerNodes2"];
        }
        else {
            self.headerNodes = HeaderNodeState.defaults;
        }
        
        if ( [decoder containsValueForKey:@"customSortOrderForFields"] ) {
            self.customSortOrderForFields = [decoder decodeBoolForKey:@"customSortOrderForFields"];
        }
        else {
            self.customSortOrderForFields = YES;
        }
        
        if ( [decoder containsValueForKey:@"autoFillCopyTotp"] ) {
            self.autoFillCopyTotp = [decoder decodeBoolForKey:@"autoFillCopyTotp"];
        }
        else {
            self.autoFillCopyTotp = YES;
        }
        
        if ( [decoder containsValueForKey:@"searchScope"] ) {
            self.searchScope = (SearchScope)[decoder decodeIntegerForKey:@"searchScope"];
        }
        else {
            self.searchScope = kSearchScopeTitle;
        }
        
        if ( [decoder containsValueForKey:@"searchIncludeGroups"] ) {
            self.searchIncludeGroups = [decoder decodeBoolForKey:@"searchIncludeGroups"];
        }
        else {
            self.searchIncludeGroups = NO;
        }
        
        
        
        
        if ( [decoder containsValueForKey:@"showChildCountOnFolderInSidebar"] ) {
            self.showChildCountOnFolderInSidebar = [decoder decodeBoolForKey:@"showChildCountOnFolderInSidebar"];
        }
        else {
            self.showChildCountOnFolderInSidebar = YES;
        }
        
        if ( [decoder containsValueForKey:@"sideBarChildCountFormat"] ) {
            self.sideBarChildCountFormat = [decoder decodeIntegerForKey:@"sideBarChildCountFormat"];
        }
        else {
            self.sideBarChildCountFormat = kSideBarChildCountFormatEntries;
        }
        
        if ( [decoder containsValueForKey:@"sideBarChildCountGroupPrefix"] ) {
            self.sideBarChildCountGroupPrefix = [decoder decodeObjectForKey:@"sideBarChildCountGroupPrefix"];
        }
        else {
            self.sideBarChildCountGroupPrefix = @"📁";
        }
        
        if ( [decoder containsValueForKey:@"sideBarChildCountSeparator"] ) {
            self.sideBarChildCountSeparator = [decoder decodeObjectForKey:@"sideBarChildCountSeparator"];
        }
        else {
            self.sideBarChildCountSeparator = @"/";
        }
        
        if ( [decoder containsValueForKey:@"sideBarChildCountShowZero"] ) {
            self.sideBarChildCountShowZero = [decoder decodeBoolForKey:@"sideBarChildCountShowZero"];
        }
        else {
            self.sideBarChildCountShowZero = YES;
        }
        
        if ( [decoder containsValueForKey:@"sideBarShowTotalCountOnHierarchy"] ) {
            self.sideBarShowTotalCountOnHierarchy = [decoder decodeBoolForKey:@"sideBarShowTotalCountOnHierarchy"];
        }
        else {
            self.sideBarShowTotalCountOnHierarchy = YES;
        }
     
        if ( [decoder containsValueForKey:@"includeAssociatedDomains"] ) {
            self.includeAssociatedDomains = [decoder decodeBoolForKey:@"includeAssociatedDomains"];
        }
        else {
            self.includeAssociatedDomains = YES;
        }

        if ( [decoder containsValueForKey:@"lastKnownEncryptionSettings"] ) {
            self.lastKnownEncryptionSettings = [decoder decodeObjectForKey:@"lastKnownEncryptionSettings"];
        }

        if ( [decoder containsValueForKey:@"serializationPerf"] ) {
            self.serializationPerf = [decoder decodeObjectForKey:@"serializationPerf"];
        }
        
        if ( [decoder containsValueForKey:@"isSharedInCloudKit"] ) {
            self.isSharedInCloudKit = [decoder decodeBoolForKey:@"isSharedInCloudKit"];
        }
        if ( [decoder containsValueForKey:@"isOwnedByMeCloudKit"] ) {
            self.isOwnedByMeCloudKit = [decoder decodeBoolForKey:@"isOwnedByMeCloudKit"];
        }
        
        

        if ( [decoder containsValueForKey:@"hardwareKeyCRCaching"] ) {
            self.hardwareKeyCRCaching = [decoder decodeBoolForKey:@"hardwareKeyCRCaching"];
        }
        if ( [decoder containsValueForKey:@"lastChallengeRefreshAt"] ) {
            self.lastChallengeRefreshAt = [decoder decodeObjectForKey:@"lastChallengeRefreshAt"];
        }

        if ( [decoder containsValueForKey:@"challengeRefreshIntervalSecs"] ) {
            self.challengeRefreshIntervalSecs = [decoder decodeIntForKey:@"challengeRefreshIntervalSecs"];
        }
        else {
            self.challengeRefreshIntervalSecs = kDefaultChallengeRefreshIntervalSecs;
        }

        if ( [decoder containsValueForKey:@"cacheChallengeDurationSecs"] ) {
            self.cacheChallengeDurationSecs = [decoder decodeIntForKey:@"cacheChallengeDurationSecs"];
        }
        else {
            self.cacheChallengeDurationSecs = kDefaultCacheChallengeDurationSecs;
        }
        
        if ( [decoder containsValueForKey:@"doNotRefreshChallengeInAF"] ) {
            self.doNotRefreshChallengeInAF = [decoder decodeBoolForKey:@"doNotRefreshChallengeInAF"];
        }
        else {
            self.doNotRefreshChallengeInAF = YES;
        }
        
        if ( [decoder containsValueForKey:@"hasOnboardedHardwareKeyCaching"] ) {
            self.hasOnboardedHardwareKeyCaching = [decoder decodeBoolForKey:@"hasOnboardedHardwareKeyCaching"];
        }        
        
        if ( [decoder containsValueForKey:@"markDirtyOnExpandCollapseGroups"] ) {
            self.markDirtyOnExpandCollapseGroups = [decoder decodeBoolForKey:@"markDirtyOnExpandCollapseGroups"];
        }
    }
    
    return self;
}



- (NSURL *)backupsDirectory {
    NSURL* url = [StrongboxFilesManager.sharedInstance.backupFilesDirectory URLByAppendingPathComponent:self.uuid isDirectory:YES];
    
    [StrongboxFilesManager.sharedInstance createIfNecessary:url];
    
    return url;
}

- (BOOL)isLocalDeviceDatabase {
    return self.storageProvider == kLocalDevice;
}




- (NSString *)conveniencePin {
    return nil;
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    
}

- (BOOL)isEnrolledForConvenience {
    return self.isTouchIdEnrolled;
}

- (void)setIsEnrolledForConvenience:(BOOL)isEnrolledForConvenience {
    self.isTouchIdEnrolled = isEnrolledForConvenience;
}

- (NSString *)convenienceMasterPassword {
    return self.conveniencePassword;
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    self.conveniencePassword = convenienceMasterPassword;
}

- (BOOL)hasBeenPromptedForConvenience {
    return self.hasPromptedForTouchIdEnrol;
}

- (void)setHasBeenPromptedForConvenience:(BOOL)hasBeenPromptedForConvenience {
    self.hasPromptedForTouchIdEnrol = hasBeenPromptedForConvenience;
}

- (NSInteger)convenienceExpiryPeriod {
    return self.touchIdPasswordExpiryPeriodHours;
}

- (void)setConvenienceExpiryPeriod:(NSInteger)convenienceExpiryPeriod {
    self.touchIdPasswordExpiryPeriodHours = convenienceExpiryPeriod;
}

- (NSArray<NSString *> *)legacyFavouritesStore { 
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    NSArray<NSString *>* ret = [SecretStore.sharedInstance getSecureObject:key];
    
    return ret ? ret : @[];
}

- (void)setLegacyFavouritesStore:(NSArray<NSString *> *)favourites {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    if(favourites) {
        [SecretStore.sharedInstance setSecureObject:favourites forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSArray<NSString *> *)auditExcludedItems {
    NSString* key = [NSString stringWithFormat:@"auditExcludedItems-%@", self.uuid];
    NSArray* ret = [SecretStore.sharedInstance getSecureObject:key];
    return ret ? ret : @[];
}

- (void)setAuditExcludedItems:(NSArray<NSString *> *)auditExcludedItems {
    NSString* key = [NSString stringWithFormat:@"auditExcludedItems-%@", self.uuid];
    [SecretStore.sharedInstance setSecureObject:auditExcludedItems forIdentifier:key];
}

- (NSArray<NSString *> *)autoFillExcludedItems {
    NSString* key = [NSString stringWithFormat:@"autoFillExcludedItems-%@", self.uuid];
    NSArray* ret = [SecretStore.sharedInstance getSecureObject:key];
    return ret ? ret : @[];
}

- (void)setAutoFillExcludedItems:(NSArray<NSString *> *)autoFillExcludedItems {
    NSString* key = [NSString stringWithFormat:@"autoFillExcludedItems-%@", self.uuid];
    [SecretStore.sharedInstance setSecureObject:autoFillExcludedItems forIdentifier:key];
}



- (BOOL)isConvenienceUnlockEnabled {
    return self.isTouchIdEnabled || self.isWatchUnlockEnabled;
}

- (BOOL)conveniencePasswordHasBeenStored {
#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        return self.isAutoFillMemOnlyConveniencePasswordHasBeenStored;
    }
#endif
    
    return self.isEnrolledForConvenience;
}

- (void)setConveniencePasswordHasBeenStored:(BOOL)conveniencePasswordHasBeenStored {
#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        self.isAutoFillMemOnlyConveniencePasswordHasBeenStored = conveniencePasswordHasBeenStored;
        return;
    }
#endif
    
    self.isEnrolledForConvenience = conveniencePasswordHasBeenStored;
}

- (BOOL)conveniencePasswordHasExpired {
    NSString *key = [NSString stringWithFormat:@"%@-pw-has-expired", self.uuid];

#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        key = [NSString stringWithFormat:@"%@-pw-has-expired-af-mem-only", self.uuid];
    }
#endif

    return [Settings.sharedInstance.sharedAppGroupDefaults boolForKey:key];
}

- (void)setConveniencePasswordHasExpired:(BOOL)conveniencePasswordHasExpired {
    NSString *key = [NSString stringWithFormat:@"%@-pw-has-expired", self.uuid];

#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        key = [NSString stringWithFormat:@"%@-pw-has-expired-af-mem-only", self.uuid];
    }
#endif

    [Settings.sharedInstance.sharedAppGroupDefaults setBool:conveniencePasswordHasExpired forKey:key];
}



- (NSString *)sideBarSelectedTag {
    NSString* key = [NSString stringWithFormat:@"sidebar-selected-tag-%@", self.uuid];
    return [SecretStore.sharedInstance getSecureString:key];
}

- (void)setSideBarSelectedTag:(NSString *)sideBarSelectedTag {
    NSString* key = [NSString stringWithFormat:@"sidebar-selected-tag-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:sideBarSelectedTag forIdentifier:key];
}

- (NSString *)searchText {
    NSString* key = [NSString stringWithFormat:@"search-text-%@", self.uuid];
    NSString* ret = [SecretStore.sharedInstance getSecureString:key];
    return ret ? ret : @"";
}

- (void)setSearchText:(NSString *)searchText {
    NSString* foo = searchText ? searchText : @"";
    NSString* key = [NSString stringWithFormat:@"search-text-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:foo forIdentifier:key];
}



- (NSDictionary<NSData *,NSData *> *)cachedYubiKeyChallengeResponses {
    NSString *key = [NSString stringWithFormat:@"%@-cached-crs", self.uuid];
    
    NSDictionary<NSData *,NSData *> *ret = [SecretStore.sharedInstance getSecureObject:key];
    
    return ret ? ret : @{};
}

- (void)setCachedYubiKeyChallengeResponses:(NSDictionary<NSData *,NSData *> *)cachedYubiKeyChallengeResponses {
    NSString *key = [NSString stringWithFormat:@"%@-cached-crs", self.uuid];
    
    if ( cachedYubiKeyChallengeResponses ) {
        if ( self.cacheChallengeDurationSecs > 0 ) {
            NSDate* expiry = [NSDate.now dateByAddingTimeInterval:self.cacheChallengeDurationSecs];
            slog(@"setting challenge cache with expiry = [%@]", expiry.friendlyDateTimeStringBothPrecise);
            [SecretStore.sharedInstance setSecureObject:cachedYubiKeyChallengeResponses forIdentifier:key expiresAt:expiry];
        }
        else if ( self.cacheChallengeDurationSecs == 0 ) { 
            [SecretStore.sharedInstance setSecureObject:cachedYubiKeyChallengeResponses forIdentifier:key];
        }
        else {
            [SecretStore.sharedInstance setSecureEphemeralObject:cachedYubiKeyChallengeResponses forIdentifer:key];
        }
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}



- (void)clearSecureItems {
    [self setConveniencePassword:nil];
    self.keyFileBookmark = nil;
    self.autoFillKeyFileBookmark = nil;
    self.autoFillConvenienceAutoUnlockPassword = nil;
    self.sideBarSelectedTag = nil;
    self.cachedYubiKeyChallengeResponses = nil;
}

@end
