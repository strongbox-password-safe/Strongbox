//
//  SafeDetails.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeMetaData.h"
#import "SecretStore.h"
#import "Settings.h"
#import "FileManager.h"
#import "ItemDetailsViewController.h"

@implementation SafeMetaData

- (instancetype)init {
    self = [super init];
    if (self) {
        self.uuid = [[NSUUID UUID] UUIDString];
        self.failedPinAttempts = 0;
        self.autoFillEnabled = YES;
        self.likelyFormat = kFormatUnknown;
        self.browseViewType = kBrowseViewTypeHierarchy;
        self.browseSortField = kBrowseSortFieldTitle;
        self.browseSortOrderDescending = NO;
        self.browseSortFoldersSeparately = YES;
        self.browseItemSubtitleField = kBrowseItemSubtitleUsername;
        self.immediateSearchOnBrowse = NO;
        self.hideTotpInBrowse = NO;
        self.showKeePass1BackupGroup = NO;
        self.showChildCountOnFolderInBrowse = YES;
        self.showFlagsInBrowse = YES;
        self.doNotShowRecycleBinInBrowse = NO;
        self.showRecycleBinInSearchResults = NO;
        self.viewDereferencedFields = YES;
        self.searchDereferencedFields = YES;
        self.showEmptyFieldsInDetailsView = NO;
        self.detailsViewCollapsedSections = ItemDetailsViewController.defaultCollapsedSections;
        self.easyReadFontForAll = NO;
        self.hideTotp = NO;
        self.tryDownloadFavIconForNewRecord = YES;
        self.showPasswordByDefaultOnEditScreen = NO;
        self.showExpiredInBrowse = YES;
        self.showExpiredInSearch = YES;
        self.autoLockTimeoutSeconds = @60;
        self.showQuickViewFavourites = YES;
        self.showQuickViewNearlyExpired = YES;

        // PERF: Do Not set these - as this massively slows down item creation - They are ok to be created on demand
        //        self.favourites = nil; //@[];
        //        self.auditExcludedItems = nil; // @[];
        
        self.makeBackups = YES;
        self.maxBackupKeepCount = 10;
        self.hideTotpCustomFieldsInViewMode = YES;
        self.hideIconInBrowse = NO;
        
        self.tapAction = kBrowseTapActionOpenDetails;
        self.doubleTapAction = kBrowseTapActionCopyPassword;
        self.tripleTapAction = kBrowseTapActionCopyTotp;
        self.longPressTapAction = kBrowseTapActionCopyUsername;

        self.colorizePasswords = YES;
        self.keePassIconSet = kKeePassIconSetSfSymbols;
        self.auditConfig = DatabaseAuditorConfiguration.defaults;
    }
    
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier {
    if(self = [self init]) {
        if(!nickName.length) {
            NSLog(@"WARNWARN: No Nick Name set... auto generating.");
            self.nickName = NSUUID.UUID.UUIDString;
        }
        else {
            self.nickName = nickName;
        }
        
        self.storageProvider = storageProvider;
        self.fileName = fileName;
        self.fileIdentifier = fileIdentifier;
    }
    
    return self;
}

////////////////////////
// Serialization

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)jsonDictionary {
    SafeMetaData *ret = [[SafeMetaData alloc] init];

    if ( jsonDictionary[@"uuid"] != nil) ret.uuid = jsonDictionary[@"uuid"];
    if ( jsonDictionary[@"nickName"] != nil ) ret.nickName = jsonDictionary[@"nickName"];
    if ( jsonDictionary[@"fileName"] != nil ) ret.fileName = jsonDictionary[@"fileName"];
    if ( jsonDictionary[@"fileIdentifier"] != nil ) ret.fileIdentifier = jsonDictionary[@"fileIdentifier"];
    if ( jsonDictionary[@"keyFileBookmark"] != nil ) ret.keyFileBookmark = jsonDictionary[@"keyFileBookmark"];
    if ( jsonDictionary[@"autoLockTimeoutSeconds"] != nil ) ret.autoLockTimeoutSeconds = jsonDictionary[@"autoLockTimeoutSeconds"];
    if ( jsonDictionary[@"detailsViewCollapsedSections"] != nil ) ret.detailsViewCollapsedSections = jsonDictionary[@"detailsViewCollapsedSections"];
    if ( jsonDictionary[@"failedPinAttempts"] != nil ) ret.failedPinAttempts = ((NSNumber*)jsonDictionary[@"failedPinAttempts"]).intValue;
    
    if ( jsonDictionary[@"autoFillEnabled"] != nil ) ret.autoFillEnabled = ((NSNumber*)jsonDictionary[@"autoFillEnabled"]).boolValue;
    if ( jsonDictionary[@"browseSortOrderDescending"] != nil ) ret.browseSortOrderDescending = ((NSNumber*)jsonDictionary[@"browseSortOrderDescending"]).boolValue;
    if ( jsonDictionary[@"browseSortFoldersSeparately"] != nil ) ret.browseSortFoldersSeparately = ((NSNumber*)jsonDictionary[@"browseSortFoldersSeparately"]).boolValue;
    if ( jsonDictionary[@"immediateSearchOnBrowse"] != nil ) ret.immediateSearchOnBrowse = ((NSNumber*)jsonDictionary[@"immediateSearchOnBrowse"]).boolValue;
    if ( jsonDictionary[@"hideTotpInBrowse"] != nil ) ret.hideTotpInBrowse = ((NSNumber*)jsonDictionary[@"hideTotpInBrowse"]).boolValue;
    if ( jsonDictionary[@"showKeePass1BackupGroup"] != nil ) ret.showKeePass1BackupGroup = ((NSNumber*)jsonDictionary[@"showKeePass1BackupGroup"]).boolValue;
    if ( jsonDictionary[@"showChildCountOnFolderInBrowse"] != nil ) ret.showChildCountOnFolderInBrowse = ((NSNumber*)jsonDictionary[@"showChildCountOnFolderInBrowse"]).boolValue;
    if ( jsonDictionary[@"showFlagsInBrowse"] != nil ) ret.showFlagsInBrowse = ((NSNumber*)jsonDictionary[@"showFlagsInBrowse"]).boolValue;
    if ( jsonDictionary[@"doNotShowRecycleBinInBrowse"] != nil ) ret.doNotShowRecycleBinInBrowse = ((NSNumber*)jsonDictionary[@"doNotShowRecycleBinInBrowse"]).boolValue;
    if ( jsonDictionary[@"showRecycleBinInSearchResults"] != nil ) ret.showRecycleBinInSearchResults = ((NSNumber*)jsonDictionary[@"showRecycleBinInSearchResults"]).boolValue;
    if ( jsonDictionary[@"viewDereferencedFields"] != nil ) ret.viewDereferencedFields = ((NSNumber*)jsonDictionary[@"viewDereferencedFields"]).boolValue;
    if ( jsonDictionary[@"searchDereferencedFields"] != nil ) ret.searchDereferencedFields = ((NSNumber*)jsonDictionary[@"searchDereferencedFields"]).boolValue;
    if ( jsonDictionary[@"showEmptyFieldsInDetailsView"] != nil ) ret.showEmptyFieldsInDetailsView = ((NSNumber*)jsonDictionary[@"showEmptyFieldsInDetailsView"]).boolValue;
    if ( jsonDictionary[@"easyReadFontForAll"] != nil ) ret.easyReadFontForAll = ((NSNumber*)jsonDictionary[@"easyReadFontForAll"]).boolValue;
    if ( jsonDictionary[@"hideTotp"] != nil ) ret.hideTotp = ((NSNumber*)jsonDictionary[@"hideTotp"]).boolValue;
    if ( jsonDictionary[@"tryDownloadFavIconForNewRecord"] != nil ) ret.tryDownloadFavIconForNewRecord = ((NSNumber*)jsonDictionary[@"tryDownloadFavIconForNewRecord"]).boolValue;
    if ( jsonDictionary[@"showPasswordByDefaultOnEditScreen"] != nil ) ret.showPasswordByDefaultOnEditScreen = ((NSNumber*)jsonDictionary[@"showPasswordByDefaultOnEditScreen"]).boolValue;
    if ( jsonDictionary[@"showExpiredInBrowse"] != nil ) ret.showExpiredInBrowse = ((NSNumber*)jsonDictionary[@"showExpiredInBrowse"]).boolValue;
    if ( jsonDictionary[@"showExpiredInSearch"] != nil ) ret.showExpiredInSearch = ((NSNumber*)jsonDictionary[@"showExpiredInSearch"]).boolValue;
    if ( jsonDictionary[@"showQuickViewFavourites"] != nil ) ret.showQuickViewFavourites = ((NSNumber*)jsonDictionary[@"showQuickViewFavourites"]).boolValue;
    if ( jsonDictionary[@"showQuickViewNearlyExpired"] != nil ) ret.showQuickViewNearlyExpired = ((NSNumber*)jsonDictionary[@"showQuickViewNearlyExpired"]).boolValue;
    if ( jsonDictionary[@"makeBackups"] != nil ) ret.makeBackups = ((NSNumber*)jsonDictionary[@"makeBackups"]).boolValue;
    if ( jsonDictionary[@"hideTotpCustomFieldsInViewMode"] != nil ) ret.hideTotpCustomFieldsInViewMode = ((NSNumber*)jsonDictionary[@"hideTotpCustomFieldsInViewMode"]).boolValue;
    if ( jsonDictionary[@"hideIconInBrowse"] != nil ) ret.hideIconInBrowse = ((NSNumber*)jsonDictionary[@"hideIconInBrowse"]).boolValue;
    if ( jsonDictionary[@"colorizePasswords"] != nil ) ret.colorizePasswords = ((NSNumber*)jsonDictionary[@"colorizePasswords"]).boolValue;
    if ( jsonDictionary[@"isTouchIdEnabled"] != nil ) ret.isTouchIdEnabled = ((NSNumber*)jsonDictionary[@"isTouchIdEnabled"]).boolValue;
    if ( jsonDictionary[@"isEnrolledForConvenience"] != nil ) ret.isEnrolledForConvenience = ((NSNumber*)jsonDictionary[@"isEnrolledForConvenience"]).boolValue;
    if ( jsonDictionary[@"hasUnresolvedConflicts"] != nil ) ret.hasUnresolvedConflicts = ((NSNumber*)jsonDictionary[@"hasUnresolvedConflicts"]).boolValue;
    if ( jsonDictionary[@"readOnly"] != nil ) ret.readOnly = ((NSNumber*)jsonDictionary[@"readOnly"]).boolValue;
    if ( jsonDictionary[@"hasBeenPromptedForConvenience"] != nil ) ret.hasBeenPromptedForConvenience = ((NSNumber*)jsonDictionary[@"hasBeenPromptedForConvenience"]).boolValue;
    if ( jsonDictionary[@"hasBeenPromptedForQuickLaunch"] != nil ) ret.hasBeenPromptedForQuickLaunch = ((NSNumber*)jsonDictionary[@"hasBeenPromptedForQuickLaunch"]).boolValue;
    if ( jsonDictionary[@"showQuickViewExpired"] != nil ) ret.showQuickViewExpired = ((NSNumber*)jsonDictionary[@"showQuickViewExpired"]).boolValue;
    if ( jsonDictionary[@"colorizeProtectedCustomFields"] != nil ) ret.colorizeProtectedCustomFields = ((NSNumber*)jsonDictionary[@"colorizeProtectedCustomFields"]).boolValue;
    if ( jsonDictionary[@"promptedForAutoFetchFavIcon"] != nil ) ret.promptedForAutoFetchFavIcon = ((NSNumber*)jsonDictionary[@"promptedForAutoFetchFavIcon"]).boolValue;
    
    if ( jsonDictionary[@"keePassIconSet"] != nil ) ret.keePassIconSet = ((NSNumber*)jsonDictionary[@"keePassIconSet"]).unsignedIntegerValue;
    if ( jsonDictionary[@"browseItemSubtitleField"] != nil ) ret.browseItemSubtitleField = ((NSNumber*)jsonDictionary[@"browseItemSubtitleField"]).unsignedIntegerValue;
    if ( jsonDictionary[@"likelyFormat"] != nil ) ret.likelyFormat = ((NSNumber*)jsonDictionary[@"likelyFormat"]).unsignedIntegerValue;
    if ( jsonDictionary[@"browseViewType"] != nil ) ret.browseViewType = ((NSNumber*)jsonDictionary[@"browseViewType"]).unsignedIntegerValue;
    if ( jsonDictionary[@"browseSortField"] != nil ) ret.browseSortField = ((NSNumber*)jsonDictionary[@"browseSortField"]).unsignedIntegerValue;
    if ( jsonDictionary[@"maxBackupKeepCount"] != nil ) ret.maxBackupKeepCount = ((NSNumber*)jsonDictionary[@"maxBackupKeepCount"]).unsignedIntegerValue;
    if ( jsonDictionary[@"tapAction"] != nil ) ret.tapAction = ((NSNumber*)jsonDictionary[@"tapAction"]).unsignedIntegerValue;
    if ( jsonDictionary[@"doubleTapAction"] != nil ) ret.doubleTapAction = ((NSNumber*)jsonDictionary[@"doubleTapAction"]).unsignedIntegerValue;
    if ( jsonDictionary[@"tripleTapAction"] != nil ) ret.tripleTapAction = ((NSNumber*)jsonDictionary[@"tripleTapAction"]).unsignedIntegerValue;
    if ( jsonDictionary[@"longPressTapAction"] != nil ) ret.longPressTapAction = ((NSNumber*)jsonDictionary[@"longPressTapAction"]).unsignedIntegerValue;
    if ( jsonDictionary[@"storageProvider"] != nil ) ret.storageProvider = ((NSNumber*)jsonDictionary[@"storageProvider"]).unsignedIntegerValue;
    if ( jsonDictionary[@"duressAction"] != nil ) ret.duressAction = ((NSNumber*)jsonDictionary[@"duressAction"]).unsignedIntegerValue;
    if ( jsonDictionary[@"failedPinAttempts"] != nil ) ret.failedPinAttempts = ((NSNumber*)jsonDictionary[@"failedPinAttempts"]).intValue;
    if ( jsonDictionary[@"yubiKeyConfig"] != nil ) ret.yubiKeyConfig = [YubiKeyHardwareConfiguration fromJsonSerializationDictionary:jsonDictionary[@"yubiKeyConfig"]];
    if ( jsonDictionary[@"auditConfig"] != nil ) ret.auditConfig = [DatabaseAuditorConfiguration fromJsonSerializationDictionary:jsonDictionary[@"auditConfig"]];

    if ( jsonDictionary[@"outstandingUpdateId"] != nil) ret.outstandingUpdateId = [[NSUUID alloc] initWithUUIDString:jsonDictionary[@"outstandingUpdateId"]];
    if ( jsonDictionary[@"lastSyncRemoteModDate"] != nil ) ret.lastSyncRemoteModDate = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastSyncRemoteModDate"])).doubleValue];

    return ret;
}

- (NSDictionary *)getJsonSerializationDictionary {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{
        @"uuid" : self.uuid,
        @"failedPinAttempts" : @(self.failedPinAttempts),
        @"autoFillEnabled" : @(self.autoFillEnabled),
        @"likelyFormat" : @(self.likelyFormat),
        @"browseViewType" : @(self.browseViewType),
        @"browseSortField" : @(self.browseSortField),
        @"browseSortOrderDescending" : @(self.browseSortOrderDescending),
        @"browseSortFoldersSeparately" : @(self.browseSortFoldersSeparately),
        @"browseItemSubtitleField" : @(self.browseItemSubtitleField),
        @"immediateSearchOnBrowse" : @(self.immediateSearchOnBrowse),
        @"hideTotpInBrowse" : @(self.hideTotpInBrowse),
        @"showKeePass1BackupGroup" : @(self.showKeePass1BackupGroup),
        @"showChildCountOnFolderInBrowse" : @(self.showChildCountOnFolderInBrowse),
        @"showFlagsInBrowse" : @(self.showFlagsInBrowse),
        @"doNotShowRecycleBinInBrowse" : @(self.doNotShowRecycleBinInBrowse),
        @"showRecycleBinInSearchResults" : @(self.showRecycleBinInSearchResults),
        @"viewDereferencedFields" : @(self.viewDereferencedFields),
        @"searchDereferencedFields" : @(self.searchDereferencedFields),
        @"showEmptyFieldsInDetailsView" : @(self.showEmptyFieldsInDetailsView),
        @"easyReadFontForAll" : @(self.easyReadFontForAll),
        @"hideTotp" : @(self.hideTotp),
        @"tryDownloadFavIconForNewRecord" : @(self.tryDownloadFavIconForNewRecord),
        @"showPasswordByDefaultOnEditScreen" : @(self.showPasswordByDefaultOnEditScreen),
        @"showExpiredInBrowse" : @(self.showExpiredInBrowse),
        @"showExpiredInSearch" : @(self.showExpiredInSearch),
        @"showQuickViewFavourites" : @(self.showQuickViewFavourites),
        @"showQuickViewNearlyExpired" : @(self.showQuickViewNearlyExpired),
        @"makeBackups" : @(self.makeBackups),
        @"maxBackupKeepCount" : @(self.maxBackupKeepCount),
        @"hideTotpCustomFieldsInViewMode" : @(self.hideTotpCustomFieldsInViewMode),
        @"hideIconInBrowse" : @(self.hideIconInBrowse),
        @"tapAction" : @(self.tapAction),
        @"doubleTapAction" : @(self.doubleTapAction),
        @"tripleTapAction" : @(self.tripleTapAction),
        @"longPressTapAction" : @(self.longPressTapAction),
        @"colorizePasswords" : @(self.colorizePasswords),
        @"keePassIconSet" : @(self.keePassIconSet),
        @"isTouchIdEnabled" : @(self.isTouchIdEnabled),
        @"isEnrolledForConvenience" : @(self.isEnrolledForConvenience),
        @"hasUnresolvedConflicts" : @(self.hasUnresolvedConflicts),
        @"readOnly" : @(self.readOnly),
        @"hasBeenPromptedForConvenience" : @(self.hasBeenPromptedForConvenience),
        @"hasBeenPromptedForQuickLaunch" : @(self.hasBeenPromptedForQuickLaunch),
        @"showQuickViewExpired" : @(self.showQuickViewExpired),
        @"colorizeProtectedCustomFields" : @(self.colorizeProtectedCustomFields),
        @"promptedForAutoFetchFavIcon" : @(self.promptedForAutoFetchFavIcon),
        @"storageProvider" : @(self.storageProvider),
        @"duressAction" : @(self.duressAction),
        @"failedPinAttempts" : @(self.failedPinAttempts),
    }];
    
    if (self.nickName != nil) {
        ret[@"nickName"] = self.nickName;
    }
    if (self.fileName != nil) {
        ret[@"fileName"] = self.fileName;
    }
    if (self.fileIdentifier != nil) {
        ret[@"fileIdentifier"] = self.fileIdentifier;
    }
    if (self.keyFileBookmark != nil) {
        ret[@"keyFileBookmark"] = self.keyFileBookmark;
    }
    if (self.autoLockTimeoutSeconds != nil) {
        ret[@"autoLockTimeoutSeconds"] = self.autoLockTimeoutSeconds;
    }
    if (self.detailsViewCollapsedSections != nil) {
        ret[@"detailsViewCollapsedSections"] = self.detailsViewCollapsedSections;
    }
    
    if (self.yubiKeyConfig != nil) {
        ret[@"yubiKeyConfig"] = [self.yubiKeyConfig getJsonSerializationDictionary];
    }
    if (self.auditConfig != nil) {
        ret[@"auditConfig"] = [self.auditConfig getJsonSerializationDictionary];
    }

    if (self.outstandingUpdateId != nil) {
        ret[@"outstandingUpdateId"] = self.outstandingUpdateId.UUIDString;
    }
    
    if (self.lastSyncRemoteModDate != nil) {
        ret[@"lastSyncRemoteModDate"] = @(self.lastSyncRemoteModDate.timeIntervalSinceReferenceDate);
    }

    return ret;
}

////////////////////////
// TODO: Eventually delete these - 14-Jun-2020 +12 months - 14-Jun-2021

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.uuid forKey:@"uuid"];
    [encoder encodeObject:self.nickName forKey:@"nickName"];
    [encoder encodeObject:self.fileName forKey:@"fileName"];
    [encoder encodeObject:self.fileIdentifier forKey:@"fileIdentifier"];
    [encoder encodeInteger:self.storageProvider forKey:@"storageProvider"];

    [encoder encodeBool:self.isTouchIdEnabled forKey:@"isTouchIdEnabled"];
    
    [encoder encodeBool:self.isEnrolledForConvenience forKey:@"isEnrolledForTouchId"];

    [encoder encodeBool:self.hasUnresolvedConflicts forKey:@"hasUnresolvedConflicts"];
    [encoder encodeBool:self.autoFillEnabled forKey:@"autoFillCacheEnabled"];
    [encoder encodeBool:self.readOnly forKey:@"readOnly"];
    
    [encoder encodeInteger:self.duressAction forKey:@"duressAction"];
    [encoder encodeBool:self.hasBeenPromptedForConvenience forKey:@"hasBeenPromptedForConvenience"];
    [encoder encodeInteger:self.failedPinAttempts forKey:@"failedPinAttempts"];

    [encoder encodeObject:self.keyFileBookmark forKey:@"keyFileBookmark"];
    
    [encoder encodeInteger:self.likelyFormat forKey:@"likelyFormat"];
    [encoder encodeInteger:self.browseViewType forKey:@"browseViewType"];
    
    [encoder encodeInteger:self.tapAction forKey:@"tapAction"];
    [encoder encodeInteger:self.doubleTapAction forKey:@"doubleTapAction"];
    [encoder encodeInteger:self.tripleTapAction forKey:@"tripleTapAction"];
    [encoder encodeInteger:self.longPressTapAction forKey:@"longPressTapAction"];
        
    // Browse View

    [encoder encodeInteger:self.browseSortField forKey:@"browseSortField"];
    [encoder encodeBool:self.browseSortOrderDescending forKey:@"browseSortOrderDescending"];
    [encoder encodeBool:self.browseSortFoldersSeparately forKey:@"browseSortFoldersSeparately"];
    [encoder encodeInteger:self.browseItemSubtitleField forKey:@"browseItemSubtitleField"];
    [encoder encodeBool:self.immediateSearchOnBrowse forKey:@"immediateSearchOnBrowse"];
    [encoder encodeBool:self.hideTotpInBrowse forKey:@"hideTotpInBrowse"];
    [encoder encodeBool:self.showKeePass1BackupGroup forKey:@"showKeePass1BackupGroup"];
    [encoder encodeBool:self.showChildCountOnFolderInBrowse forKey:@"showChildCountOnFolderInBrowse"];
    [encoder encodeBool:self.showFlagsInBrowse forKey:@"showFlagsInBrowse"];
    [encoder encodeBool:self.doNotShowRecycleBinInBrowse forKey:@"doNotShowRecycleBinInBrowse"];
    [encoder encodeBool:self.showRecycleBinInSearchResults forKey:@"showRecycleBinInSearchResults"];
    [encoder encodeBool:self.viewDereferencedFields forKey:@"viewDereferencedFields"];
    [encoder encodeBool:self.searchDereferencedFields forKey:@"searchDereferencedFields"];

    // Details View
    
    [encoder encodeBool:self.showEmptyFieldsInDetailsView forKey:@"showEmptyFieldsInDetailsView"];
    [encoder encodeObject:self.detailsViewCollapsedSections forKey:@"detailsViewCollapsedSections"];    
    [encoder encodeBool:self.easyReadFontForAll forKey:@"easyReadFontForAll"];
    [encoder encodeBool:self.hideTotp forKey:@"hideTotp"];
    [encoder encodeBool:self.tryDownloadFavIconForNewRecord forKey:@"tryDownloadFavIconForNewRecord"];
    [encoder encodeBool:self.showPasswordByDefaultOnEditScreen forKey:@"showPasswordByDefaultOnEditScreen"];
    
    //
    
    [encoder encodeBool:self.hasBeenPromptedForQuickLaunch forKey:@"hasBeenPromptedForQuickLaunch"];
    
    [encoder encodeBool:self.showExpiredInSearch forKey:@"showExpiredInSearch"];
    [encoder encodeBool:self.showExpiredInBrowse forKey:@"showExpiredInBrowse"];
    
    [encoder encodeObject:self.autoLockTimeoutSeconds forKey:@"autoLockTimeoutSeconds"];
    
    [encoder encodeBool:self.showQuickViewNearlyExpired forKey:@"showQuickViewNearlyExpired"];
    [encoder encodeBool:self.showQuickViewFavourites forKey:@"showQuickViewFavourites"];
    [encoder encodeBool:self.showQuickViewExpired forKey:@"showQuickViewExpired"];
    
    [encoder encodeBool:self.makeBackups forKey:@"makeBackups"];
    [encoder encodeInteger:self.maxBackupKeepCount forKey:@"maxBackupKeepCount"];
    
    [encoder encodeBool:self.hideTotpCustomFieldsInViewMode forKey:@"hideTotpCustomFieldsInViewMode"];
    [encoder encodeBool:self.hideIconInBrowse forKey:@"hideIconInBrowse"];
    [encoder encodeObject:self.yubiKeyConfig forKey:@"yubiKeyConfig"];
    [encoder encodeBool:self.colorizePasswords forKey:@"colorizePasswords"];
    [encoder encodeInteger:self.keePassIconSet forKey:@"keePassIconSet"];
    [encoder encodeBool:self.colorizeProtectedCustomFields forKey:@"colorizeProtectedCustomFields"];

    [encoder encodeObject:self.auditConfig forKey:@"auditConfig"];
    
    [encoder encodeBool:self.promptedForAutoFetchFavIcon forKey:@"promptedForAutoFetchFavIcon"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        if(!self.nickName.length) {
            NSLog(@"WARNWARN: No Nick Name set... auto generating.");
            self.nickName = NSUUID.UUID.UUIDString;
        }
        
        self.fileName = [decoder decodeObjectForKey:@"fileName"];
        self.fileIdentifier = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
        self.isEnrolledForConvenience = [decoder decodeBoolForKey:@"isEnrolledForTouchId"];
        
        self.hasUnresolvedConflicts = [decoder decodeBoolForKey:@"hasUnresolvedConflicts"];
        
        if([decoder containsValueForKey:@"autoFillCacheEnabled"]) {
            self.autoFillEnabled = [decoder decodeBoolForKey:@"autoFillCacheEnabled"];
        }
        else {
            self.autoFillEnabled = YES;
        }

        if([decoder containsValueForKey:@"readOnly"]) {
            self.readOnly = [decoder decodeBoolForKey:@"readOnly"];
        }

        if([decoder containsValueForKey:@"duressAction"]) {
            self.duressAction = (int)[decoder decodeIntegerForKey:@"duressAction"];
        }

        if([decoder containsValueForKey:@"hasBeenPromptedForConvenience"]) {
            self.hasBeenPromptedForConvenience = [decoder decodeBoolForKey:@"hasBeenPromptedForConvenience"];
        }
        
        if([decoder containsValueForKey:@"failedPinAttempts"]) {
            self.failedPinAttempts = (int)[decoder decodeIntegerForKey:@"failedPinAttempts"];
        }
        
        if([decoder containsValueForKey:@"keyFileBookmark"]) {
            self.keyFileBookmark = [decoder decodeObjectForKey:@"keyFileBookmark"];
        }
        
        if([decoder containsValueForKey:@"likelyFormat"]) {
            self.likelyFormat = (DatabaseFormat)[decoder decodeIntegerForKey:@"likelyFormat"];
        }
        else {
            self.likelyFormat = kFormatUnknown;
        }
        
        if([decoder containsValueForKey:@"browseViewType"]) {
            self.browseViewType = (BrowseViewType)[decoder decodeIntegerForKey:@"browseViewType"];
        }

        if([decoder containsValueForKey:@"tapAction"]) {
            self.tapAction = (BrowseTapAction)[decoder decodeIntegerForKey:@"tapAction"];
        }
        if([decoder containsValueForKey:@"doubleTapAction"]) {
            self.doubleTapAction = (BrowseTapAction)[decoder decodeIntegerForKey:@"doubleTapAction"];
        }
        if([decoder containsValueForKey:@"tripleTapAction"]) {
            self.tripleTapAction = (BrowseTapAction)[decoder decodeIntegerForKey:@"tripleTapAction"];
        }
        if([decoder containsValueForKey:@"longPressTapAction"]) {
            self.longPressTapAction = (BrowseTapAction)[decoder decodeIntegerForKey:@"longPressTapAction"];
        }
        
        // Migrate from Global Settings - 23-Jun-2019
        
        if([decoder containsValueForKey:@"browseSortField"]) {
            self.browseSortField = (BrowseSortField)[decoder decodeIntegerForKey:@"browseSortField"];
        }
        if([decoder containsValueForKey:@"browseSortOrderDescending"]) {
            self.browseSortOrderDescending = [decoder decodeBoolForKey:@"browseSortOrderDescending"];
        }
        if([decoder containsValueForKey:@"browseSortFoldersSeparately"]) {
            self.browseSortFoldersSeparately = [decoder decodeBoolForKey:@"browseSortFoldersSeparately"];
        }
        if([decoder containsValueForKey:@"browseItemSubtitleField"]) {
            self.browseItemSubtitleField = (BrowseItemSubtitleField)[decoder decodeIntegerForKey:@"browseItemSubtitleField"];
        }
        if([decoder containsValueForKey:@"immediateSearchOnBrowse"]) {
            self.immediateSearchOnBrowse = [decoder decodeBoolForKey:@"immediateSearchOnBrowse"];
        }
        if([decoder containsValueForKey:@"hideTotpInBrowse"]) {
            self.hideTotpInBrowse = [decoder decodeBoolForKey:@"hideTotpInBrowse"];
        }
        if([decoder containsValueForKey:@"showKeePass1BackupGroup"]) {
            self.showKeePass1BackupGroup = [decoder decodeBoolForKey:@"showKeePass1BackupGroup"];
        }
        if([decoder containsValueForKey:@"showChildCountOnFolderInBrowse"]) {
            self.showChildCountOnFolderInBrowse = [decoder decodeBoolForKey:@"showChildCountOnFolderInBrowse"];
        }
        if([decoder containsValueForKey:@"showFlagsInBrowse"]) {
            self.showFlagsInBrowse = [decoder decodeBoolForKey:@"showFlagsInBrowse"];
        }
        if([decoder containsValueForKey:@"doNotShowRecycleBinInBrowse"]) {
            self.doNotShowRecycleBinInBrowse = [decoder decodeBoolForKey:@"doNotShowRecycleBinInBrowse"];
        }
        if([decoder containsValueForKey:@"showRecycleBinInSearchResults"]) {
            self.showRecycleBinInSearchResults = [decoder decodeBoolForKey:@"showRecycleBinInSearchResults"];
        }
        if([decoder containsValueForKey:@"viewDereferencedFields"]) {
            self.viewDereferencedFields = [decoder decodeBoolForKey:@"viewDereferencedFields"];
        }
        if([decoder containsValueForKey:@"searchDereferencedFields"]) {
            self.searchDereferencedFields = [decoder decodeBoolForKey:@"searchDereferencedFields"];
        }
        if([decoder containsValueForKey:@"showEmptyFieldsInDetailsView"]) {
            self.showEmptyFieldsInDetailsView = [decoder decodeBoolForKey:@"showEmptyFieldsInDetailsView"];
        }
        if([decoder containsValueForKey:@"detailsViewCollapsedSections"]) {
            self.detailsViewCollapsedSections = [decoder decodeObjectForKey:@"detailsViewCollapsedSections"];
        }
        if([decoder containsValueForKey:@"easyReadFontForAll"]) {
            self.easyReadFontForAll = [decoder decodeBoolForKey:@"easyReadFontForAll"];
        }
        if([decoder containsValueForKey:@"hideTotp"]) {
            self.hideTotp = [decoder decodeBoolForKey:@"hideTotp"];
        }
        if([decoder containsValueForKey:@"tryDownloadFavIconForNewRecord"]) {
            self.tryDownloadFavIconForNewRecord = [decoder decodeBoolForKey:@"tryDownloadFavIconForNewRecord"];
        }
        if([decoder containsValueForKey:@"showPasswordByDefaultOnEditScreen"]) {
            self.showPasswordByDefaultOnEditScreen = [decoder decodeBoolForKey:@"showPasswordByDefaultOnEditScreen"];
        }
        
        if([decoder containsValueForKey:@"hasBeenPromptedForQuickLaunch"]) {
            self.hasBeenPromptedForQuickLaunch = [decoder decodeBoolForKey:@"hasBeenPromptedForQuickLaunch"];
        }
        
        if([decoder containsValueForKey:@"showExpiredInSearch"]) {
            self.showExpiredInSearch = [decoder decodeBoolForKey:@"showExpiredInSearch"];
        }
        if([decoder containsValueForKey:@"showExpiredInBrowse"]) {
            self.showExpiredInBrowse = [decoder decodeBoolForKey:@"showExpiredInBrowse"];
        }
        
        if([decoder containsValueForKey:@"autoLockTimeoutSeconds"]) {
            self.autoLockTimeoutSeconds = [decoder decodeObjectForKey:@"autoLockTimeoutSeconds"];
        }

        if([decoder containsValueForKey:@"showQuickViewNearlyExpired"]) {
            self.showQuickViewNearlyExpired = [decoder decodeBoolForKey:@"showQuickViewNearlyExpired"];
        }
        
        if([decoder containsValueForKey:@"showQuickViewFavourites"]) {
            self.showQuickViewFavourites = [decoder decodeBoolForKey:@"showQuickViewFavourites"];
        }
        
        if([decoder containsValueForKey:@"showQuickViewExpired"]) {
            self.showQuickViewExpired = [decoder decodeBoolForKey:@"showQuickViewExpired"];
        }

        if([decoder containsValueForKey:@"makeBackups"]) {
            self.makeBackups = [decoder decodeBoolForKey:@"makeBackups"];
        }
        if([decoder containsValueForKey:@"maxBackupKeepCount"]) {
            self.maxBackupKeepCount = [decoder decodeIntegerForKey:@"maxBackupKeepCount"];
        }

        if([decoder containsValueForKey:@"hideTotpCustomFieldsInViewMode"]) {
            self.hideTotpCustomFieldsInViewMode = [decoder decodeBoolForKey:@"hideTotpCustomFieldsInViewMode"];
        }
        
        if([decoder containsValueForKey:@"hideIconInBrowse"]) {
            self.hideIconInBrowse = [decoder decodeBoolForKey:@"hideIconInBrowse"];
        }
        
        if([decoder containsValueForKey:@"yubiKeyConfig"]) {
            self.yubiKeyConfig = [decoder decodeObjectForKey:@"yubiKeyConfig"];
        }
        
        if([decoder containsValueForKey:@"colorizePasswords"]) {
            self.colorizePasswords = [decoder decodeBoolForKey:@"colorizePasswords"];
        }
        
        if([decoder containsValueForKey:@"keePassIconSet"]) {
            self.keePassIconSet = [decoder decodeIntegerForKey:@"keePassIconSet"];
        }
        
        if([decoder containsValueForKey:@"colorizeProtectedCustomFields"]) {
            self.colorizeProtectedCustomFields = [decoder decodeBoolForKey:@"colorizeProtectedCustomFields"];
        }
        
        if ([decoder containsValueForKey:@"auditConfig"]) {
            self.auditConfig = [decoder decodeObjectForKey:@"auditConfig"];
        }
        
        if ([decoder containsValueForKey:@"promptedForAutoFetchFavIcon"]) {
            self.promptedForAutoFetchFavIcon = [decoder decodeBoolForKey:@"promptedForAutoFetchFavIcon"];
        }
    }
    
    return self;
}

////////////////////////

- (NSArray<NSString *> *)auditExcludedItems {
    NSString *key = [NSString stringWithFormat:@"%@-auditExcludedItems", self.uuid];
    
    NSArray<NSString *>* ret = [SecretStore.sharedInstance getSecureObject:key];
    
    return ret ? ret : @[];
}

- (void)setAuditExcludedItems:(NSArray<NSString *> *)auditExcludedItems {
    NSString *key = [NSString stringWithFormat:@"%@-auditExcludedItems", self.uuid];
    
    if(auditExcludedItems) {
        [SecretStore.sharedInstance setSecureObject:auditExcludedItems forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSArray<NSString *> *)favourites {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    NSArray<NSString *>* ret = [SecretStore.sharedInstance getSecureObject:key];
    
    return ret ? ret : @[];
}

- (void)setFavourites:(NSArray<NSString *> *)favourites {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    if(favourites) {
        [SecretStore.sharedInstance setSecureObject:favourites forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSString *)convenienceMasterPassword {
    return [SecretStore.sharedInstance getSecureString:self.uuid];
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    if(convenienceMasterPassword) {
        [SecretStore.sharedInstance setSecureString:convenienceMasterPassword forIdentifier:self.uuid];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:self.uuid];
    }
}

- (NSString *)convenenienceYubikeySecret {
    NSString *key = [NSString stringWithFormat:@"%@-yubikey-secret", self.uuid];
    return [SecretStore.sharedInstance getSecureString:key];
}

- (void)setConvenenienceYubikeySecret:(NSString *)convenenienceYubikeySecret {
    NSString *key = [NSString stringWithFormat:@"%@-yubikey-secret", self.uuid];
    
    if(convenenienceYubikeySecret) {
        [SecretStore.sharedInstance setSecureString:convenenienceYubikeySecret forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];
    return [SecretStore.sharedInstance getSecureString:key];
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];

    if(conveniencePin) {
        [SecretStore.sharedInstance setSecureString:conveniencePin forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSString *)duressPin {
    NSString *key = [NSString stringWithFormat:@"%@-duress-pin", self.uuid];
    return [SecretStore.sharedInstance getSecureString:key];
}

-(void)setDuressPin:(NSString *)duressPin {
    NSString *key = [NSString stringWithFormat:@"%@-duress-pin", self.uuid];
    
    if(duressPin) {
        [SecretStore.sharedInstance setSecureString:duressPin forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (void)clearKeychainItems {
    self.convenienceMasterPassword = nil;
    self.convenenienceYubikeySecret = nil;
    self.favourites = nil;
    self.duressPin = nil;
    self.conveniencePin = nil;
}

- (NSURL *)backupsDirectory {
    NSURL* url = [FileManager.sharedInstance.backupFilesDirectory URLByAppendingPathComponent:self.uuid isDirectory:YES];
    
    [FileManager.sharedInstance createIfNecessary:url];
    
    return url;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%lu] - [%@-%@]", self.nickName, (unsigned long)self.storageProvider, self.fileName, self.fileIdentifier];
}

@end
