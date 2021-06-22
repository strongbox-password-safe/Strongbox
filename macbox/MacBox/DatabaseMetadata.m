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
#import "FileManager.h"
#import "Settings.h"


const NSInteger kDefaultPasswordExpiryHours = -1; // Forever 14 * 24; // 2 weeks
static NSString* const kStrongboxICloudContainerIdentifier = @"iCloud.com.strongbox";

@implementation DatabaseMetadata

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.touchIdPasswordExpiryPeriodHours = kDefaultPasswordExpiryHours;
        self.quickTypeDisplayFormat = kQuickTypeFormatTitleThenUsername;
        self.autoFillConvenienceAutoUnlockTimeout = -1; 
        self.monitorForExternalChanges = YES;
        self.monitorForExternalChangesInterval = self.storageProvider == kMacFile ? 10 : 30; 
        self.autoReloadAfterExternalChanges = YES;
        self.makeBackups = YES;
        self.maxBackupKeepCount = 10;
        


        self.showQuickView = YES;
        self.outlineViewTitleIsReadonly = YES;
        self.outlineViewEditableFieldsAreReadonly = YES;
        self.concealEmptyProtectedFields = YES;
        self.startWithSearch = YES;
        self.lockOnScreenLock = YES;
        self.expressDownloadFavIconOnNewOrUrlChanged = YES; 
        self.visibleColumns = @[kTitleColumn, kUsernameColumn, kPasswordColumn, kURLColumn];
    }
    
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo {
    if(self = [self init]) {
        _nickName = nickName ? nickName : @"<Unknown>";
        _uuid = [[NSUUID UUID] UUIDString];
        self.storageProvider = storageProvider;
        self.fileUrl = fileUrl;
        self.storageInfo = storageInfo;
    }
    
    return self;
}



- (void)clearSecureItems {
    [self setConveniencePassword:nil expiringAfterHours:-1];
    self.keyFileBookmark = nil;
    self.autoFillKeyFileBookmark = nil;
    self.autoFillConvenienceAutoUnlockPassword = nil;
}

- (NSString*)getConveniencePasswordIdentifier {
    return [NSString stringWithFormat:@"convenience-pw-%@", self.uuid];
}

- (NSString *)conveniencePassword {
    return [self getConveniencePassword:nil];
}

- (NSString*)getConveniencePassword:(BOOL*_Nullable)expired {
    return [SecretStore.sharedInstance getSecureObject:[self getConveniencePasswordIdentifier] expired:expired];
}

- (void)setConveniencePassword:(NSString*)password expiringAfterHours:(NSInteger)expiringAfterHours {
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

- (void)resetConveniencePasswordWithCurrentConfiguration:(NSString*)password {
    if( self.isTouchIdEnabled || self.isWatchUnlockEnabled ) {
        [self setConveniencePassword:password expiringAfterHours:self.touchIdPasswordExpiryPeriodHours];
    }
    else {
        [self setConveniencePassword:nil expiringAfterHours:-1];
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
        
        NSLog(@"Setting AutoFIll convenience auto unlock expiry to: [%@]", expiry);
        
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
    [encoder encodeBool:self.quickWormholeFillEnabled forKey:@"quickWormholeFillEnabled"];
    [encoder encodeInteger:self.quickTypeDisplayFormat forKey:@"quickTypeDisplayFormat"];

    [encoder encodeInteger:self.conflictResolutionStrategy forKey:@"conflictResolutionStrategy"];
    [encoder encodeObject:self.outstandingUpdateId forKey:@"outstandingUpdateId"];
    [encoder encodeObject:self.lastSyncRemoteModDate forKey:@"lastSyncRemoteModDate"];
    [encoder encodeObject:self.lastSyncAttempt forKey:@"lastSyncAttempt"];

    [encoder encodeBool:self.launchAtStartup forKey:@"launchAtStartup"];

    [encoder encodeBool:self.isWatchUnlockEnabled forKey:@"isWatchUnlockEnabled"];
    [encoder encodeBool:self.autoPromptForConvenienceUnlockOnActivate forKey:@"autoPromptForConvenienceUnlockOnActivate"];
    
    [encoder encodeObject:self.autoFillLastUnlockedAt forKey:@"autoFillLastUnlockedAt"];
    [encoder encodeInteger:self.autoFillConvenienceAutoUnlockTimeout forKey:@"autoFillConvenienceAutoUnlockTimeout"];
    
    [encoder encodeBool:self.monitorForExternalChanges forKey:@"monitorForExternalChanges"];
    [encoder encodeInteger:self.monitorForExternalChangesInterval forKey:@"monitorForExternalChangesInterval"];
    [encoder encodeBool:self.autoReloadAfterExternalChanges forKey:@"autoReloadAfterExternalChanges"];

    [encoder encodeInteger:self.maxBackupKeepCount forKey:@"maxBackupKeepCount"];
    [encoder encodeBool:self.makeBackups forKey:@"makeBackups"];
    [encoder encodeBool:self.offlineMode forKey:@"offlineMode"];
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
    [encoder encodeBool:self.outlineViewEditableFieldsAreReadonly forKey:@"outlineViewEditableFieldsAreReadonly"];
    [encoder encodeBool:self.concealEmptyProtectedFields forKey:@"concealEmptyProtectedFields"];
    [encoder encodeBool:self.startWithSearch forKey:@"startWithSearch"];
    [encoder encodeBool:self.showAdvancedUnlockOptions forKey:@"showAdvancedUnlockOptions"];
    [encoder encodeBool:self.lockOnScreenLock forKey:@"lockOnScreenLock"];
    [encoder encodeBool:self.expressDownloadFavIconOnNewOrUrlChanged forKey:@"expressDownloadFavIconOnNewOrUrlChanged"];
    [encoder encodeBool:self.doNotShowRecycleBinInBrowse forKey:@"doNotShowRecycleBinInBrowse"];
    [encoder encodeBool:self.showRecycleBinInSearchResults forKey:@"showRecycleBinInSearchResults"];
    [encoder encodeBool:self.uiDoNotSortKeePassNodesInBrowseView forKey:@"uiDoNotSortKeePassNodesInBrowseView"];
    [encoder encodeObject:self.visibleColumns forKey:@"visibleColumns"];
    
    /* =================================================================================================== */
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

        if([decoder containsValueForKey:@"autoFillEnabled"]) {
            self.autoFillEnabled = [decoder decodeBoolForKey:@"autoFillEnabled"];
        }
        
        if([decoder containsValueForKey:@"hasPromptedForAutoFillEnrol"]) {
            self.hasPromptedForAutoFillEnrol = [decoder decodeBoolForKey:@"hasPromptedForAutoFillEnrol"];
        }

        if([decoder containsValueForKey:@"quickWormholeFillEnabled"]) {
            self.quickWormholeFillEnabled = [decoder decodeBoolForKey:@"quickWormholeFillEnabled"];
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
        
        if( [decoder containsValueForKey:@"autoPromptForConvenienceUnlockOnActivate"] ) {
            self.autoPromptForConvenienceUnlockOnActivate = [decoder decodeBoolForKey:@"autoPromptForConvenienceUnlockOnActivate"];
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
            self.monitorForExternalChangesInterval = self.storageProvider == kMacFile ? 10 : 30; 
        }
        
        if( [decoder containsValueForKey:@"autoReloadAfterExternalChanges"] ) {
            self.autoReloadAfterExternalChanges = [decoder decodeBoolForKey:@"autoReloadAfterExternalChanges"];
        }
        
        



        
        if ( [decoder containsValueForKey:@"maxBackupKeepCount"] ) {
            self.maxBackupKeepCount = [decoder decodeIntegerForKey:@"maxBackupKeepCount"];
        }
        
        if ( [decoder containsValueForKey:@"makeBackups"] ) {
            self.makeBackups = [decoder decodeBoolForKey:@"makeBackups"];
        }
        if ( [decoder containsValueForKey:@"offlineMode"] ) {
            self.offlineMode = [decoder decodeBoolForKey:@"offlineMode"];
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
        else {
            self.showQuickView = Settings.sharedInstance.showQuickView;
        }
        
        if ( [decoder containsValueForKey:@"doNotShowTotp"] ) {
            self.doNotShowTotp = [decoder decodeBoolForKey:@"doNotShowTotp"];
        }
        else {
            self.doNotShowTotp = Settings.sharedInstance.doNotShowTotp;
        }

        if ( [decoder containsValueForKey:@"noAlternatingRows"] ) {
            self.noAlternatingRows = [decoder decodeBoolForKey:@"noAlternatingRows"];
        }
        else {
            self.noAlternatingRows = Settings.sharedInstance.noAlternatingRows;
        }

        if ( [decoder containsValueForKey:@"showHorizontalGrid"] ) {
            self.showHorizontalGrid = [decoder decodeBoolForKey:@"showHorizontalGrid"];
        }
        else {
            self.showHorizontalGrid = Settings.sharedInstance.showHorizontalGrid;
        }

        if ( [decoder containsValueForKey:@"showVerticalGrid"] ) {
            self.showVerticalGrid = [decoder decodeBoolForKey:@"showVerticalGrid"];
        }
        else {
            self.showVerticalGrid = Settings.sharedInstance.showVerticalGrid;
        }

        if ( [decoder containsValueForKey:@"doNotShowAutoCompleteSuggestions"] ) {
            self.doNotShowAutoCompleteSuggestions = [decoder decodeBoolForKey:@"doNotShowAutoCompleteSuggestions"];
        }
        else {
            self.doNotShowAutoCompleteSuggestions = Settings.sharedInstance.doNotShowAutoCompleteSuggestions;
        }

        if ( [decoder containsValueForKey:@"doNotShowChangeNotifications"] ) {
            self.doNotShowChangeNotifications = [decoder decodeBoolForKey:@"doNotShowChangeNotifications"];
        }
        else {
            self.doNotShowChangeNotifications = Settings.sharedInstance.doNotShowChangeNotifications;
        }

        if ( [decoder containsValueForKey:@"outlineViewTitleIsReadonly"] ) {
            self.outlineViewTitleIsReadonly = [decoder decodeBoolForKey:@"outlineViewTitleIsReadonly"];
        }
        else {
            self.outlineViewTitleIsReadonly = Settings.sharedInstance.outlineViewTitleIsReadonly;
        }

        if ( [decoder containsValueForKey:@"outlineViewEditableFieldsAreReadonly"] ) {
            self.outlineViewEditableFieldsAreReadonly = [decoder decodeBoolForKey:@"outlineViewEditableFieldsAreReadonly"];
        }
        else {
            self.outlineViewEditableFieldsAreReadonly = Settings.sharedInstance.outlineViewEditableFieldsAreReadonly;
        }

        if ( [decoder containsValueForKey:@"concealEmptyProtectedFields"] ) {
            self.concealEmptyProtectedFields = [decoder decodeBoolForKey:@"concealEmptyProtectedFields"];
        }
        else {
            self.concealEmptyProtectedFields = Settings.sharedInstance.concealEmptyProtectedFields;
        }

        if ( [decoder containsValueForKey:@"startWithSearch"] ) {
            self.startWithSearch = [decoder decodeBoolForKey:@"startWithSearch"];
        }
        else {
            self.startWithSearch = Settings.sharedInstance.startWithSearch;
        }

        if ( [decoder containsValueForKey:@"showAdvancedUnlockOptions"] ) {
            self.showAdvancedUnlockOptions = [decoder decodeBoolForKey:@"showAdvancedUnlockOptions"];
        }
        else {
            self.showAdvancedUnlockOptions = Settings.sharedInstance.showAdvancedUnlockOptions;
        }

        if ( [decoder containsValueForKey:@"lockOnScreenLock"] ) {
            self.lockOnScreenLock = [decoder decodeBoolForKey:@"lockOnScreenLock"];
        }
        else {
            self.lockOnScreenLock = Settings.sharedInstance.lockOnScreenLock;
        }

        if ( [decoder containsValueForKey:@"expressDownloadFavIconOnNewOrUrlChanged"] ) {
            self.expressDownloadFavIconOnNewOrUrlChanged = [decoder decodeBoolForKey:@"expressDownloadFavIconOnNewOrUrlChanged"];
        }
        else {
            self.expressDownloadFavIconOnNewOrUrlChanged = Settings.sharedInstance.expressDownloadFavIconOnNewOrUrlChanged;
        }

        if ( [decoder containsValueForKey:@"doNotShowRecycleBinInBrowse"] ) {
            self.doNotShowRecycleBinInBrowse = [decoder decodeBoolForKey:@"doNotShowRecycleBinInBrowse"];
        }
        else {
            self.doNotShowRecycleBinInBrowse = Settings.sharedInstance.doNotShowRecycleBinInBrowse;
        }

        if ( [decoder containsValueForKey:@"showRecycleBinInSearchResults"] ) {
            self.showRecycleBinInSearchResults = [decoder decodeBoolForKey:@"showRecycleBinInSearchResults"];
        }
        else {
            self.showRecycleBinInSearchResults = Settings.sharedInstance.showRecycleBinInSearchResults;
        }

        if ( [decoder containsValueForKey:@"uiDoNotSortKeePassNodesInBrowseView"] ) {
            self.uiDoNotSortKeePassNodesInBrowseView = [decoder decodeBoolForKey:@"uiDoNotSortKeePassNodesInBrowseView"];
        }
        else {
            self.uiDoNotSortKeePassNodesInBrowseView = Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView;
        }

        if ( [decoder containsValueForKey:@"visibleColumns"] ) {
            self.visibleColumns = [decoder decodeObjectForKey:@"visibleColumns"];
        }
        else {
            self.visibleColumns = Settings.sharedInstance.visibleColumns;
        }
        
        /* =================================================================================================== */
    }
    
    return self;
}


- (ConflictResolutionStrategy)conflictResolutionStrategy {
    return kConflictResolutionStrategyAutoMerge; 
}

- (NSURL *)backupsDirectory {
    NSURL* url = [FileManager.sharedInstance.backupFilesDirectory URLByAppendingPathComponent:self.uuid isDirectory:YES];
    
    [FileManager.sharedInstance createIfNecessary:url];
    
    return url;
}

- (BOOL)isLocalDeviceDatabase {
    return self.storageProvider == kMacFile;
}

@end
