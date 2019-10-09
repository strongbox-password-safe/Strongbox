//
//  SafeDetails.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeMetaData.h"
#import "JNKeychain.h"
#import "Settings.h"
#import "FileManager.h"

static NSString* const kShowPasswordByDefaultOnEditScreen = @"showPasswordByDefaultOnEditScreen";
static NSString* const kHideTotp = @"hideTotp";
static NSString* const kHideTotpInBrowse = @"hideTotpInBrowse";
static NSString* const kDoNotShowRecycleBinInBrowse = @"doNotShowRecycleBinInBrowse";
static NSString* const kShowRecycleBinInSearchResults = @"showRecycleBinInSearchResults";
static NSString* const kTryDownloadFavIconForNewRecord = @"tryDownloadFavIconForNewRecord";
static NSString* const kViewDereferencedFields = @"viewDereferencedFields";
static NSString* const kSearchDereferencedFields = @"searchDereferencedFields";
static NSString* const kHideEmptyFieldsInDetailsView = @"hideEmptyFieldsInDetailsView";
static NSString* const kCollapsedSections = @"collapsedSections";
static NSString* const kEasyReadFontForAll = @"easyReadFontForAll";
static NSString* const kShowChildCountOnFolderInBrowse = @"showChildCountOnFolderInBrowse";
static NSString* const kShowFlagsInBrowse = @"showFlagsInBrowse";
static NSString* const kImmediateSearchOnBrowse = @"immediateSearchOnBrowse";
static NSString* const kBrowseItemSubtitleField = @"browseItemSubtitleField";
static NSString* const kBrowseSortField = @"browseSortField";
static NSString* const kBrowseSortOrderDescending = @"browseSortOrderDescending";
static NSString* const kBrowseSortFoldersSeparately = @"browseSortFoldersSeparately";
static NSString* const kUiDoNotSortKeePassNodesInBrowseView = @"uiDoNotSortKeePassNodesInBrowseView";
static NSString* const kShowUsernameInBrowse = @"showUsernameInBrowse"; // DEAD
static NSString* const kShowKeePass1BackupGroupInSearchResults = @"showKeePass1BackupGroupInSearchResults";

@interface SafeMetaData ()

// Migrated to SafeMetaData - remove after a while (23-Jun-2019)

@property (readonly) BrowseSortField old_browseSortField;
@property (readonly) BOOL old_browseSortOrderDescending;
@property (readonly) BOOL old_browseSortFoldersSeparately;
@property (readonly) BrowseItemSubtitleField old_browseItemSubtitleField;
@property (readonly) BOOL old_immediateSearchOnBrowse;
@property (readonly) BOOL old_hideTotpInBrowse;
@property (readonly) BOOL old_showKeePass1BackupGroup;
@property (readonly) BOOL old_showChildCountOnFolderInBrowse;
@property (readonly) BOOL old_showFlagsInBrowse;
@property (readonly) BOOL old_doNotShowRecycleBinInBrowse;
@property (readonly) BOOL old_showRecycleBinInSearchResults;
@property (readonly) BOOL old_viewDereferencedFields;
@property (readonly) BOOL old_searchDereferencedFields;
@property (readonly) BOOL old_showEmptyFieldsInDetailsView;
@property (readonly) NSArray<NSNumber*>* old_detailsViewCollapsedSections;
@property (readonly) BOOL old_easyReadFontForAll;
@property (readonly) BOOL old_hideTotp;
@property (readonly) BOOL old_tryDownloadFavIconForNewRecord;
@property (readonly) BOOL old_showPasswordByDefaultOnEditScreen;

@end

@implementation SafeMetaData

- (instancetype)init {
    self = [super init];
    if (self) {
        self.uuid = [[NSUUID UUID] UUIDString];
        self.failedPinAttempts = 0;
//        self.offlineCacheEnabled = YES;
        self.autoFillEnabled = YES;
        self.likelyFormat = kFormatUnknown;
        self.browseViewType = kBrowseViewTypeHierarchy;
        
        // Old original defaults for people used to this... Different defaults for newly created databases
        
        self.tapAction = kBrowseTapActionOpenDetails;
        self.doubleTapAction = kBrowseTapActionCopyUsername;
        self.tripleTapAction = kBrowseTapActionCopyTotp;
        self.longPressTapAction = kBrowseTapActionCopyPassword;
        
        // Migration - Remove after a long while and use defaults instead... 23-Jun-2019
        
        self.browseSortField = self.old_browseSortField;
        self.browseSortOrderDescending = self.old_browseSortOrderDescending;
        self.browseSortFoldersSeparately = self.old_browseSortFoldersSeparately;
        self.browseItemSubtitleField = self.old_browseItemSubtitleField;
        self.immediateSearchOnBrowse = self.old_immediateSearchOnBrowse;
        self.hideTotpInBrowse = self.old_hideTotpInBrowse;
        self.showKeePass1BackupGroup = self.old_showKeePass1BackupGroup;
        self.showChildCountOnFolderInBrowse = self.old_showChildCountOnFolderInBrowse;
        self.showFlagsInBrowse = self.old_showFlagsInBrowse;
        self.doNotShowRecycleBinInBrowse = self.old_doNotShowRecycleBinInBrowse;
        self.showRecycleBinInSearchResults = self.old_showRecycleBinInSearchResults;
        self.viewDereferencedFields = self.old_viewDereferencedFields;
        self.searchDereferencedFields = self.old_searchDereferencedFields;
        self.showEmptyFieldsInDetailsView = self.old_showEmptyFieldsInDetailsView;
        self.detailsViewCollapsedSections = self.old_detailsViewCollapsedSections;
        self.easyReadFontForAll = self.old_easyReadFontForAll;
        self.hideTotp = self.old_hideTotp;
        self.tryDownloadFavIconForNewRecord = self.old_tryDownloadFavIconForNewRecord;
        self.showPasswordByDefaultOnEditScreen = self.old_showPasswordByDefaultOnEditScreen;
        
        //
        
        self.showExpiredInBrowse = YES;
        self.showExpiredInSearch = YES;
        
        self.autoLockTimeoutSeconds = self.old_autoLockTimeoutSeconds;
        self.showQuickViewFavourites = YES;
        self.showQuickViewNearlyExpired = YES;
        self.favourites = @[];
        self.makeBackups = YES;
        self.maxBackupKeepCount = 10;
    }
    
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier {
    if(self = [self init]) {
        self.nickName = nickName;
        self.storageProvider = storageProvider;
        self.fileName = fileName;
        self.fileIdentifier = fileIdentifier;

        // Brand New Databases let's use these defaults;
        
        self.tapAction = kBrowseTapActionOpenDetails;
        self.doubleTapAction = kBrowseTapActionCopyPassword;
        self.tripleTapAction = kBrowseTapActionCopyTotp;
        self.longPressTapAction = kBrowseTapActionCopyUsername;
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
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.fileName = [decoder decodeObjectForKey:@"fileName"];
        self.fileIdentifier = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
        self.isEnrolledForConvenience = [decoder decodeBoolForKey:@"isEnrolledForTouchId"];
        
//        self.offlineCacheEnabled = [decoder decodeBoolForKey:@"offlineCacheEnabled"];
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
    }
    
    return self;
}

- (NSArray<NSString *> *)favourites {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    NSArray<NSString *>* ret = [JNKeychain loadValueForKey:key];
    
    return ret ? ret : @[];
}

- (void)setFavourites:(NSArray<NSString *> *)favourites {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    if(favourites) {
        [JNKeychain saveValue:favourites forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (NSString *)convenienceMasterPassword {
    return [JNKeychain loadValueForKey:self.uuid];
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    if(convenienceMasterPassword) {
        [JNKeychain saveValue:convenienceMasterPassword forKey:self.uuid];
    }
    else {
        [JNKeychain deleteValueForKey:self.uuid];
    }
}

- (NSString *)convenenienceYubikeySecret {
    NSString *key = [NSString stringWithFormat:@"%@-yubikey-secret", self.uuid];
    return [JNKeychain loadValueForKey:key];
}

- (void)setConvenenienceYubikeySecret:(NSString *)convenenienceYubikeySecret {
    NSString *key = [NSString stringWithFormat:@"%@-yubikey-secret", self.uuid];
    
    if(convenenienceYubikeySecret) {
        [JNKeychain saveValue:convenenienceYubikeySecret forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];
    return [JNKeychain loadValueForKey:key];
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];

    if(conveniencePin) {
        [JNKeychain saveValue:conveniencePin forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (NSString *)duressPin {
    NSString *key = [NSString stringWithFormat:@"%@-duress-pin", self.uuid];
    return [JNKeychain loadValueForKey:key];
}

-(void)setDuressPin:(NSString *)duressPin {
    NSString *key = [NSString stringWithFormat:@"%@-duress-pin", self.uuid];
    
    if(duressPin) {
        [JNKeychain saveValue:duressPin forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (void)clearKeychainItems {
    self.convenienceMasterPassword = nil;
    self.convenenienceYubikeySecret = nil;
    
    self.favourites = nil;
    self.duressPin = nil;
    self.conveniencePin = nil;
}

///////////////////////////////////////////////////////////
// Delete me after a while...

- (NSUserDefaults*)getUserDefaults {
    return [Settings.sharedInstance getUserDefaults];
}

- (NSInteger)getInteger:(NSString*)key {
    return [self getInteger:key fallback:0];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [[self getUserDefaults] objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    NSNumber* obj = [userDefaults objectForKey:key];
    
    return obj != nil ? obj.boolValue : fallback;
}

//

- (BrowseSortField)old_browseSortField {
    BOOL oldDoNotSort = [self getBool:kUiDoNotSortKeePassNodesInBrowseView]; // TODO: Remove in a while - 24-Jul-2019
    return (BrowseSortField)[self getInteger:kBrowseSortField fallback:oldDoNotSort ? kBrowseSortFieldNone : kBrowseSortFieldTitle];
}

- (BOOL)old_browseSortOrderDescending {
    return [self getBool:kBrowseSortOrderDescending fallback:NO];
}

- (BOOL)old_browseSortFoldersSeparately {
    return [self getBool:kBrowseSortFoldersSeparately fallback:YES];
}

- (BOOL)old_immediateSearchOnBrowse {
    return [self getBool:kImmediateSearchOnBrowse];
}

- (BrowseItemSubtitleField)old_browseItemSubtitleField {
    BOOL showUsernameInBrowse = [self getBool:kShowUsernameInBrowse fallback:YES];

    BrowseItemSubtitleField deflt = showUsernameInBrowse ? kBrowseItemSubtitleUsername : kBrowseItemSubtitleNoField;
    return (BrowseItemSubtitleField)[self getInteger:kBrowseItemSubtitleField fallback:deflt];
}

-(BOOL)old_hideTotp {
    return [self getBool:kHideTotp];
}

- (BOOL)old_showKeePass1BackupGroup {
    return [self getBool:kShowKeePass1BackupGroupInSearchResults];
}

- (BOOL)old_showChildCountOnFolderInBrowse {
    return [self getBool:kShowChildCountOnFolderInBrowse];
}

- (BOOL)old_showFlagsInBrowse {
    return [self getBool:kShowFlagsInBrowse fallback:YES];
}

- (BOOL)old_doNotShowRecycleBinInBrowse {
    return [self getBool:kDoNotShowRecycleBinInBrowse];
}

- (BOOL)old_showRecycleBinInSearchResults {
    return [self getBool:kShowRecycleBinInSearchResults];
}

- (BOOL)old_viewDereferencedFields {
    return [self getBool:kViewDereferencedFields];
}

- (BOOL)old_searchDereferencedFields {
    return [self getBool:kSearchDereferencedFields];
}

-(BOOL)old_showEmptyFieldsInDetailsView {
    return ![self getBool:kHideEmptyFieldsInDetailsView fallback:YES];
}

- (NSArray<NSNumber *> *)old_detailsViewCollapsedSections {
    NSUserDefaults *userDefaults = [self getUserDefaults];
    NSArray* ret = [userDefaults arrayForKey:kCollapsedSections];    
    return ret ? ret : @[@(0), @(0), @(0), @(0), @(1), @(1)]; // Default
}

- (BOOL)old_easyReadFontForAll {
    return [self getBool:kEasyReadFontForAll];
}

-(BOOL)old_hideTotpInBrowse {
    return [self getBool:kHideTotpInBrowse];
}

-(BOOL)old_tryDownloadFavIconForNewRecord {
    return [self getBool:kTryDownloadFavIconForNewRecord fallback:YES];
}

- (BOOL)old_showPasswordByDefaultOnEditScreen {
    return [self getBool:kShowPasswordByDefaultOnEditScreen];
}

-(NSNumber*)old_autoLockTimeoutSeconds
{
    static NSString* const kAutoLockTimeSeconds = @"autoLockTimeSeconds";
    NSUserDefaults *userDefaults = [self getUserDefaults];
    
    NSNumber *seconds = [userDefaults objectForKey:kAutoLockTimeSeconds];
    
    if (seconds == nil) {
        seconds = @60;
    }
    
    return seconds;
}

- (BOOL)offlineCacheEnabled {
    return YES;
}

- (NSURL *)backupsDirectory {
    NSURL* url = [FileManager.sharedInstance.backupFilesDirectory URLByAppendingPathComponent:self.uuid isDirectory:YES];
    
    [FileManager.sharedInstance createIfNecessary:url];
    
    return url;
}

@end
