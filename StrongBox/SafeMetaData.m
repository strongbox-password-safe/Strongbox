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
        self.showChildCountOnFolderInBrowse = NO;
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
        self.favourites = @[];
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

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%u] - [%@-%@]", self.nickName, self.storageProvider, self.fileName, self.fileIdentifier];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.uuid forKey:@"uuid"];
    [encoder encodeObject:self.nickName forKey:@"nickName"];
    [encoder encodeObject:self.fileName forKey:@"fileName"];
    [encoder encodeObject:self.fileIdentifier forKey:@"fileIdentifier"];
    [encoder encodeInteger:self.storageProvider forKey:@"storageProvider"];

    [encoder encodeBool:self.isTouchIdEnabled forKey:@"isTouchIdEnabled"];
    
    [encoder encodeBool:self.isEnrolledForConvenience forKey:@"isEnrolledForTouchId"];

    //[encoder encodeBool:self.offlineCacheEnabled forKey:@"offlineCacheEnabled"];
    [encoder encodeBool:self.offlineCacheAvailable forKey:@"offlineCacheAvailable"];
    [encoder encodeBool:self.hasUnresolvedConflicts forKey:@"hasUnresolvedConflicts"];
    [encoder encodeBool:self.autoFillEnabled forKey:@"autoFillCacheEnabled"];
    [encoder encodeBool:self.autoFillCacheAvailable forKey:@"autoFillCacheAvailable"];
    [encoder encodeBool:self.readOnly forKey:@"readOnly"];
    
    [encoder encodeInteger:self.duressAction forKey:@"duressAction"];
    [encoder encodeBool:self.hasBeenPromptedForConvenience forKey:@"hasBeenPromptedForConvenience"];
    [encoder encodeInteger:self.failedPinAttempts forKey:@"failedPinAttempts"];

//    [encoder encodeBool:self.useQuickTypeAutoFill forKey:@"useQuickTypeAutoFill"];
    [encoder encodeObject:self.keyFileUrl forKey:@"keyFileUrl"];
    
    [encoder encodeInteger:self.likelyFormat forKey:@"likelyFormat"];
    [encoder encodeInteger:self.browseViewType forKey:@"browseViewType"];
    
    [encoder encodeInteger:self.tapAction forKey:@"tapAction"];
    [encoder encodeInteger:self.doubleTapAction forKey:@"doubleTapAction"];
    [encoder encodeInteger:self.tripleTapAction forKey:@"tripleTapAction"];
    [encoder encodeInteger:self.longPressTapAction forKey:@"longPressTapAction"];
    
    // Migrate from Global Settings - 23-Jun-2019
    
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
    [encoder encodeBool:self.alwaysUseCacheForAutoFill forKey:@"alwaysUseCacheForAutoFill"];
    
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
        
        self.offlineCacheAvailable = [decoder decodeBoolForKey:@"offlineCacheAvailable"];
        self.hasUnresolvedConflicts = [decoder decodeBoolForKey:@"hasUnresolvedConflicts"];
        
        if([decoder containsValueForKey:@"autoFillCacheEnabled"]) {
            self.autoFillEnabled = [decoder decodeBoolForKey:@"autoFillCacheEnabled"];
        }
        else {
            self.autoFillEnabled = YES;
        }

        if([decoder containsValueForKey:@"autoFillCacheAvailable"]) {
            self.autoFillCacheAvailable = [decoder decodeBoolForKey:@"autoFillCacheAvailable"];
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
        
        if([decoder containsValueForKey:@"keyFileUrl"]) {
            self.keyFileUrl = [decoder decodeObjectForKey:@"keyFileUrl"];
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

        if([decoder containsValueForKey:@"alwaysUseCacheForAutoFill"]) {
            self.alwaysUseCacheForAutoFill = [decoder decodeBoolForKey:@"alwaysUseCacheForAutoFill"];
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
    }
    
    return self;
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

//

- (BOOL)offlineCacheEnabled {
    return YES;
}

- (NSURL *)backupsDirectory {
    NSURL* url = [FileManager.sharedInstance.backupFilesDirectory URLByAppendingPathComponent:self.uuid isDirectory:YES];
    
    [FileManager.sharedInstance createIfNecessary:url];
    
    return url;
}

@end
