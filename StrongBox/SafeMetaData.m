//
//  SafeDetails.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeMetaData.h"
#import "SecretStore.h"
#import "StrongboxiOSFilesManager.h"
#import "ItemDetailsViewController.h"
#import "NSDate+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "SafeStorageProviderFactory.h"
#endif

#import "AppPreferences.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

const NSInteger kDefaultConvenienceExpiryPeriodHours = 2 * 168; 

const NSInteger kDefaultCacheChallengeDurationSecs = 8 * 60 * 60; 
const NSInteger kDefaultChallengeRefreshIntervalSecs = 0; 

static const NSUInteger kDefaultScheduledExportIntervalDays = 28;  

@interface SafeMetaData ()

@property BOOL isEnrolledForConvenience; 
@property BOOL isAutoFillMemOnlyConveniencePasswordHasBeenStored; 
@property (nullable) NSDate* convenienceExpiresAt;
@property (readonly) BOOL isNowAfterConvenienceExpiresAt;

@property (nullable) YubiKeyHardwareConfiguration* yubiKeyConfig;
@property (nullable) YubiKeyHardwareConfiguration* autoFillYubiKeyConfig;

@end

@implementation SafeMetaData

- (BOOL)viewDereferencedFields {
    return YES;
}

- (BOOL)searchDereferencedFields {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.uuid = [[NSUUID UUID] UUIDString];
        self.failedPinAttempts = 0;
        self.likelyFormat = kFormatUnknown;
        self.browseViewType = kBrowseViewTypeHome;

        self.browseItemSubtitleField = kBrowseItemSubtitleUsername;
        self.showChildCountOnFolderInBrowse = YES;
        
        self.detailsViewCollapsedSections = ItemDetailsViewController.defaultCollapsedSections;
        self.tryDownloadFavIconForNewRecord = NO;
        self.showExpiredInBrowse = YES;
        self.showExpiredInSearch = YES;
        self.autoLockTimeoutSeconds = @180;
        self.showQuickViewFavourites = NO;
        self.showQuickViewNearlyExpired = YES;
        self.showQuickViewExpired = YES;

        
        
        
        
        self.makeBackups = YES;
        self.maxBackupKeepCount = 10;
        
        self.tapAction = kBrowseTapActionOpenDetails;

        self.colorizePasswords = YES;
        self.keePassIconSet = kKeePassIconSetSfSymbols;
        self.auditConfig = DatabaseAuditorConfiguration.defaults;
        
        self.conflictResolutionStrategy = kConflictResolutionStrategyAutoMerge;
        self.quickTypeDisplayFormat = kQuickTypeFormatTitleThenUsername;
        self.autoLockOnDeviceLock = YES;
        self.autoFillConvenienceAutoUnlockTimeout = -1;
        self.quickTypeEnabled = YES;
        self.autoFillCopyTotp = YES;
        self.convenienceExpiryPeriod = kDefaultConvenienceExpiryPeriodHours;
        self.showConvenienceExpiryMessage = YES;
        self.scheduleExportIntervalDays = kDefaultScheduledExportIntervalDays;
        self.databaseCreated = NSDate.date;
        self.unlockCount = 0;
        
        self.includeAssociatedDomains = YES;
        self.autoFillScanCustomFields = NO;
        self.autoFillScanNotes = NO;
        self.lazySyncMode = NO;
        self.showLastViewedEntryOnUnlock = YES;
        
        self.visibleTabs = @[@(kBrowseViewTypeHome),
                             @(kBrowseViewTypeHierarchy),
                             @(kBrowseViewTypeList),
                             @(kBrowseViewTypeTotpList)];

        self.visibleHomeSections = @[@(HomeViewSectionFavourites),
                             @(HomeViewSectionNavigation),
                             @(HomeViewSectionQuickTags),
                             @(HomeViewSectionOtherViews)];
    
        self.sortConfigurations = @{}; 
        self.customSortOrderForFields = YES; 
        self.cacheChallengeDurationSecs = kDefaultCacheChallengeDurationSecs;
        self.challengeRefreshIntervalSecs = kDefaultChallengeRefreshIntervalSecs;
        self.doNotRefreshChallengeInAF = YES;
    }
    
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier {
    if(self = [self init]) {
        if(!nickName.length) {
            slog(@"WARNWARN: No Nick Name set... auto generating.");
            self.nickName = NSUUID.UUID.UUIDString;
        }
        else {
            self.nickName = nickName;
        }
        
        self.storageProvider = storageProvider;
        self.fileName = fileName;
        self.fileIdentifier = fileIdentifier;
        
        
        
        BOOL immediateOfflineOfferIfOfflineDetected = [SafeMetaData defaultImmediatelyOfferOfflineForProvider:storageProvider];
        self.offlineDetectedBehaviour = immediateOfflineOfferIfOfflineDetected ? kOfflineDetectedBehaviourAsk : kOfflineDetectedBehaviourTryConnectThenAsk;
        self.couldNotConnectBehaviour = kCouldNotConnectBehaviourPrompt;
    }
    
    return self;
}

+ (BOOL)defaultImmediatelyOfferOfflineForProvider:(StorageProvider)storageProvider {
#ifndef IS_APP_EXTENSION
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:storageProvider];
    return provider.defaultForImmediatelyOfferOfflineCache;
#else
    return NO;
#endif
}




+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)jsonDictionary {
    SafeMetaData *ret = [[SafeMetaData alloc] init];

    if ( jsonDictionary[@"uuid"] != nil) ret.uuid = jsonDictionary[@"uuid"];
    if ( jsonDictionary[@"nickName"] != nil ) ret.nickName = jsonDictionary[@"nickName"];
    if ( jsonDictionary[@"fileName"] != nil ) ret.fileName = jsonDictionary[@"fileName"];
    if ( jsonDictionary[@"fileIdentifier"] != nil ) ret.fileIdentifier = jsonDictionary[@"fileIdentifier"];
    
    if ( jsonDictionary[@"autoLockTimeoutSeconds"] != nil ) ret.autoLockTimeoutSeconds = jsonDictionary[@"autoLockTimeoutSeconds"];
    if ( jsonDictionary[@"detailsViewCollapsedSections"] != nil ) ret.detailsViewCollapsedSections = jsonDictionary[@"detailsViewCollapsedSections"];
    if ( jsonDictionary[@"failedPinAttempts"] != nil ) ret.failedPinAttempts = ((NSNumber*)jsonDictionary[@"failedPinAttempts"]).intValue;
    
    if ( jsonDictionary[@"autoFillEnabled"] != nil ) ret.autoFillEnabled = ((NSNumber*)jsonDictionary[@"autoFillEnabled"]).boolValue;


    if ( jsonDictionary[@"immediateSearchOnBrowse"] != nil ) ret.immediateSearchOnBrowse = ((NSNumber*)jsonDictionary[@"immediateSearchOnBrowse"]).boolValue;

    if ( jsonDictionary[@"showKeePass1BackupGroup"] != nil ) ret.showKeePass1BackupGroup = ((NSNumber*)jsonDictionary[@"showKeePass1BackupGroup"]).boolValue;
    if ( jsonDictionary[@"showChildCountOnFolderInBrowse"] != nil ) ret.showChildCountOnFolderInBrowse = ((NSNumber*)jsonDictionary[@"showChildCountOnFolderInBrowse"]).boolValue;

    if ( jsonDictionary[@"doNotShowRecycleBinInBrowse"] != nil ) ret.doNotShowRecycleBinInBrowse = ((NSNumber*)jsonDictionary[@"doNotShowRecycleBinInBrowse"]).boolValue;
    if ( jsonDictionary[@"showRecycleBinInSearchResults"] != nil ) ret.showRecycleBinInSearchResults = ((NSNumber*)jsonDictionary[@"showRecycleBinInSearchResults"]).boolValue;



    if ( jsonDictionary[@"easyReadFontForAll"] != nil ) ret.easyReadFontForAll = ((NSNumber*)jsonDictionary[@"easyReadFontForAll"]).boolValue;

    if ( jsonDictionary[@"tryDownloadFavIconForNewRecord"] != nil ) ret.tryDownloadFavIconForNewRecord = ((NSNumber*)jsonDictionary[@"tryDownloadFavIconForNewRecord"]).boolValue;
    if ( jsonDictionary[@"showPasswordByDefaultOnEditScreen"] != nil ) ret.showPasswordByDefaultOnEditScreen = ((NSNumber*)jsonDictionary[@"showPasswordByDefaultOnEditScreen"]).boolValue;
    if ( jsonDictionary[@"showExpiredInBrowse"] != nil ) ret.showExpiredInBrowse = ((NSNumber*)jsonDictionary[@"showExpiredInBrowse"]).boolValue;
    if ( jsonDictionary[@"showExpiredInSearch"] != nil ) ret.showExpiredInSearch = ((NSNumber*)jsonDictionary[@"showExpiredInSearch"]).boolValue;
    if ( jsonDictionary[@"showQuickViewFavourites2"] != nil ) ret.showQuickViewFavourites = ((NSNumber*)jsonDictionary[@"showQuickViewFavourites2"]).boolValue;
    if ( jsonDictionary[@"showQuickViewNearlyExpired"] != nil ) ret.showQuickViewNearlyExpired = ((NSNumber*)jsonDictionary[@"showQuickViewNearlyExpired"]).boolValue;
    if ( jsonDictionary[@"makeBackups"] != nil ) ret.makeBackups = ((NSNumber*)jsonDictionary[@"makeBackups"]).boolValue;

    if ( jsonDictionary[@"hideIconInBrowse"] != nil ) ret.hideIconInBrowse = ((NSNumber*)jsonDictionary[@"hideIconInBrowse"]).boolValue;
    if ( jsonDictionary[@"colorizePasswords"] != nil ) ret.colorizePasswords = ((NSNumber*)jsonDictionary[@"colorizePasswords"]).boolValue;
    if ( jsonDictionary[@"isTouchIdEnabled"] != nil ) ret.isTouchIdEnabled = ((NSNumber*)jsonDictionary[@"isTouchIdEnabled"]).boolValue;

    if ( jsonDictionary[@"isEnrolledForConvenience"] != nil ) ret.isEnrolledForConvenience = ((NSNumber*)jsonDictionary[@"isEnrolledForConvenience"]).boolValue;
    if ( jsonDictionary[@"isAutoFillMemOnlyConveniencePasswordHasBeenStored"] != nil ) ret.isAutoFillMemOnlyConveniencePasswordHasBeenStored = ((NSNumber*)jsonDictionary[@"isAutoFillMemOnlyConveniencePasswordHasBeenStored"]).boolValue;

    if ( jsonDictionary[@"hasUnresolvedConflicts"] != nil ) ret.hasUnresolvedConflicts = ((NSNumber*)jsonDictionary[@"hasUnresolvedConflicts"]).boolValue;
    if ( jsonDictionary[@"readOnly"] != nil ) ret.readOnly = ((NSNumber*)jsonDictionary[@"readOnly"]).boolValue;
    if ( jsonDictionary[@"hasBeenPromptedForConvenience"] != nil ) ret.hasBeenPromptedForConvenience = ((NSNumber*)jsonDictionary[@"hasBeenPromptedForConvenience"]).boolValue;
    if ( jsonDictionary[@"hasBeenPromptedForQuickLaunch"] != nil ) ret.hasBeenPromptedForQuickLaunch = ((NSNumber*)jsonDictionary[@"hasBeenPromptedForQuickLaunch"]).boolValue;
    if ( jsonDictionary[@"showQuickViewExpired"] != nil ) ret.showQuickViewExpired = ((NSNumber*)jsonDictionary[@"showQuickViewExpired"]).boolValue;

    if ( jsonDictionary[@"promptedForAutoFetchFavIcon"] != nil ) ret.promptedForAutoFetchFavIcon = ((NSNumber*)jsonDictionary[@"promptedForAutoFetchFavIcon"]).boolValue;
    if ( jsonDictionary[@"lockEvenIfEditing"] != nil ) ret.lockEvenIfEditing = ((NSNumber*)jsonDictionary[@"lockEvenIfEditing"]).boolValue;
    
    if ( jsonDictionary[@"keePassIconSet"] != nil ) ret.keePassIconSet = ((NSNumber*)jsonDictionary[@"keePassIconSet"]).unsignedIntegerValue;
    if ( jsonDictionary[@"browseItemSubtitleField"] != nil ) ret.browseItemSubtitleField = ((NSNumber*)jsonDictionary[@"browseItemSubtitleField"]).unsignedIntegerValue;
    if ( jsonDictionary[@"likelyFormat"] != nil ) ret.likelyFormat = ((NSNumber*)jsonDictionary[@"likelyFormat"]).unsignedIntegerValue;
    if ( jsonDictionary[@"browseViewType"] != nil ) ret.browseViewType = ((NSNumber*)jsonDictionary[@"browseViewType"]).unsignedIntegerValue;

    if ( jsonDictionary[@"maxBackupKeepCount"] != nil ) ret.maxBackupKeepCount = ((NSNumber*)jsonDictionary[@"maxBackupKeepCount"]).unsignedIntegerValue;

    if ( jsonDictionary[@"tapAction"] != nil ) ret.tapAction = ((NSNumber*)jsonDictionary[@"tapAction"]).unsignedIntegerValue;

    if ( jsonDictionary[@"storageProvider"] != nil ) ret.storageProvider = ((NSNumber*)jsonDictionary[@"storageProvider"]).unsignedIntegerValue;
    if ( jsonDictionary[@"duressAction"] != nil ) ret.duressAction = ((NSNumber*)jsonDictionary[@"duressAction"]).unsignedIntegerValue;
    if ( jsonDictionary[@"failedPinAttempts"] != nil ) ret.failedPinAttempts = ((NSNumber*)jsonDictionary[@"failedPinAttempts"]).intValue;
    
    if ( jsonDictionary[@"yubiKeyConfig"] != nil ) ret.yubiKeyConfig = [YubiKeyHardwareConfiguration fromJsonSerializationDictionary:jsonDictionary[@"yubiKeyConfig"]];
    if ( jsonDictionary[@"autoFillYubiKeyConfig"] != nil ) ret.autoFillYubiKeyConfig = [YubiKeyHardwareConfiguration fromJsonSerializationDictionary:jsonDictionary[@"autoFillYubiKeyConfig"]];

    if ( jsonDictionary[@"auditConfig"] != nil ) ret.auditConfig = [DatabaseAuditorConfiguration fromJsonSerializationDictionary:jsonDictionary[@"auditConfig"]];

    if ( jsonDictionary[@"outstandingUpdateId"] != nil) ret.outstandingUpdateId = [[NSUUID alloc] initWithUUIDString:jsonDictionary[@"outstandingUpdateId"]];
    if ( jsonDictionary[@"lastSyncRemoteModDate"] != nil ) ret.lastSyncRemoteModDate = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastSyncRemoteModDate"])).doubleValue];
    if ( jsonDictionary[@"lastSyncAttempt"] != nil ) ret.lastSyncAttempt = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastSyncAttempt"])).doubleValue];

    if ( jsonDictionary[@"conflictResolutionStrategy"] != nil ) ret.conflictResolutionStrategy = ((NSNumber*)jsonDictionary[@"conflictResolutionStrategy"]).unsignedIntegerValue;
    
    if ( jsonDictionary[@"quickTypeEnabled"] != nil ) {
        ret.quickTypeEnabled = ((NSNumber*)jsonDictionary[@"quickTypeEnabled"]).boolValue;
    }
    else { 
        ret.quickTypeEnabled = YES;
    }
    
    if ( jsonDictionary[@"quickTypeDisplayFormat"] != nil ) {
        ret.quickTypeDisplayFormat = ((NSNumber*)jsonDictionary[@"quickTypeDisplayFormat"]).integerValue;
    }
    else { 
        ret.quickTypeDisplayFormat = kQuickTypeFormatTitleThenUsername;
    }
    
    
    
    if ( jsonDictionary[@"emptyOrNilPwPreferNilCheckFirst"] != nil ) {
        ret.emptyOrNilPwPreferNilCheckFirst = ((NSNumber*)jsonDictionary[@"emptyOrNilPwPreferNilCheckFirst"]).boolValue;
    }
    
    
    
    if ( jsonDictionary[@"autoLockOnDeviceLock"] != nil ) {
        ret.autoLockOnDeviceLock = ((NSNumber*)jsonDictionary[@"autoLockOnDeviceLock"]).boolValue;
    }
    else { 
        ret.autoLockOnDeviceLock = YES;
    }
    
    
    
    if ( jsonDictionary[@"autoFillConvenienceAutoUnlockTimeout"] != nil ) {
        ret.autoFillConvenienceAutoUnlockTimeout = ((NSNumber*)jsonDictionary[@"autoFillConvenienceAutoUnlockTimeout"]).integerValue;
    }
    else { 
        ret.autoFillConvenienceAutoUnlockTimeout = -1;
    }
    
    
    
    if ( jsonDictionary[@"autoFillLastUnlockedAt"] != nil ) {
        ret.autoFillLastUnlockedAt = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"autoFillLastUnlockedAt"])).doubleValue];
    }
    
    
    
    if ( jsonDictionary[@"autoFillCopyTotp"] != nil ) {
        ret.autoFillCopyTotp = ((NSNumber*)jsonDictionary[@"autoFillCopyTotp"]).boolValue;
    }
    else { 
        ret.autoFillCopyTotp = YES;
    }
    
    
    
    if ( jsonDictionary[@"forceOpenOffline"] != nil ) ret.forceOpenOffline = ((NSNumber*)jsonDictionary[@"forceOpenOffline"]).boolValue;

    
    
    if ( jsonDictionary[@"offlineDetectedBehaviour"] != nil ) {
        ret.offlineDetectedBehaviour = ((NSNumber*)jsonDictionary[@"offlineDetectedBehaviour"]).integerValue;
    }
    else { 
        BOOL immediateOfflineOfferIfOfflineDetected = [SafeMetaData defaultImmediatelyOfferOfflineForProvider:ret.storageProvider];
        ret.offlineDetectedBehaviour = immediateOfflineOfferIfOfflineDetected ? kOfflineDetectedBehaviourAsk : kOfflineDetectedBehaviourTryConnectThenAsk;
    }

    
    
    if ( jsonDictionary[@"couldNotConnectBehaviour"] != nil ) {
        ret.couldNotConnectBehaviour = ((NSNumber*)jsonDictionary[@"couldNotConnectBehaviour"]).integerValue;
    }
    
    
    
    if ( jsonDictionary[@"convenienceExpiryPeriod"] != nil ) {
        ret.convenienceExpiryPeriod = ((NSNumber*)jsonDictionary[@"convenienceExpiryPeriod"]).integerValue;
    }
    else { 
        ret.convenienceExpiryPeriod = -1; 
    }
    
    
    
    if ( jsonDictionary[@"showConvenienceExpiryMessage"] != nil ) {
        ret.showConvenienceExpiryMessage = ((NSNumber*)jsonDictionary[@"showConvenienceExpiryMessage"]).boolValue;
    }
    else { 
        ret.showConvenienceExpiryMessage = YES;
    }

    
    
    if ( jsonDictionary[@"hasShownInitialOnboardingScreen"] != nil ) {
        ret.hasShownInitialOnboardingScreen = ((NSNumber*)jsonDictionary[@"hasShownInitialOnboardingScreen"]).boolValue;
    }
    else { 
        ret.hasShownInitialOnboardingScreen = YES;
    }
    
    
    
    
    if ( jsonDictionary[@"convenienceExpiryOnboardingDone"] != nil ) {
        ret.convenienceExpiryOnboardingDone = ((NSNumber*)jsonDictionary[@"convenienceExpiryOnboardingDone"]).boolValue;
    }

    if ( jsonDictionary[@"autoFillOnboardingDone"] != nil ) {
        ret.autoFillOnboardingDone = ((NSNumber*)jsonDictionary[@"autoFillOnboardingDone"]).boolValue;
    }
    else { 
        ret.autoFillOnboardingDone = YES;
    }

    
    
    if ( jsonDictionary[@"hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue"] != nil ) {
        ret.hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue = ((NSNumber*)jsonDictionary[@"hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue"]).boolValue;
    }
    
    
    
    if ( jsonDictionary[@"onboardingDoneHasBeenShown"] != nil ) {
        ret.onboardingDoneHasBeenShown = ((NSNumber*)jsonDictionary[@"onboardingDoneHasBeenShown"]).boolValue;
    }
    else { 
        ret.onboardingDoneHasBeenShown = YES;
    }

    
    
    if ( jsonDictionary[@"scheduledExport"] != nil ) {
        ret.scheduledExport = ((NSNumber*)jsonDictionary[@"scheduledExport"]).boolValue;
    }
    
    if ( jsonDictionary[@"scheduledExportOnboardingDone"] != nil ) {
        ret.scheduledExportOnboardingDone = ((NSNumber*)jsonDictionary[@"scheduledExportOnboardingDone"]).boolValue;
    }

    if ( jsonDictionary[@"scheduleExportIntervalDays"] != nil ) {
        ret.scheduleExportIntervalDays = ((NSNumber*)jsonDictionary[@"scheduleExportIntervalDays"]).unsignedIntegerValue;
    }
    else {
        ret.scheduleExportIntervalDays = kDefaultScheduledExportIntervalDays;
    }
    
    if ( jsonDictionary[@"nextScheduledExport"] != nil ) {
        ret.nextScheduledExport = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"nextScheduledExport"])).doubleValue];
    }

    if ( jsonDictionary[@"lastScheduledExportModDate"] != nil ) {
        ret.lastScheduledExportModDate = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastScheduledExportModDate"])).doubleValue];
    }
    
    if ( jsonDictionary[@"databaseCreated"] != nil ) {
        ret.databaseCreated = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"databaseCreated"])).doubleValue];
    }
    else {
        ret.databaseCreated = NSDate.date;
    }
    
    if ( jsonDictionary[@"unlockCount"] != nil ) {
        ret.unlockCount = ((NSNumber*)jsonDictionary[@"unlockCount"]).unsignedIntegerValue;
    }

    
    
    if ( jsonDictionary[@"autoFillScanCustomFields"] != nil ) {
        ret.autoFillScanCustomFields = ((NSNumber*)jsonDictionary[@"autoFillScanCustomFields"]).boolValue;
    }
    else {
        ret.autoFillScanCustomFields = YES;
    }

    
    
    if ( jsonDictionary[@"includeAssociatedDomains"] != nil ) {
        ret.includeAssociatedDomains = ((NSNumber*)jsonDictionary[@"includeAssociatedDomains"]).boolValue;
    }
    else {
        ret.includeAssociatedDomains = YES;
    }

    
    
    if ( jsonDictionary[@"autoFillScanNotes"] != nil ) {
        ret.autoFillScanNotes = ((NSNumber*)jsonDictionary[@"autoFillScanNotes"]).boolValue;
    }
    else {
        ret.autoFillScanNotes = YES;
    }
    
    

    if ( jsonDictionary[@"autoFillConcealedFieldsAsCreds"] != nil ) {
        ret.autoFillConcealedFieldsAsCreds = ((NSNumber*)jsonDictionary[@"autoFillConcealedFieldsAsCreds"]).boolValue;
    }
    if ( jsonDictionary[@"autoFillUnConcealedFieldsAsCreds"] != nil ) {
        ret.autoFillUnConcealedFieldsAsCreds = ((NSNumber*)jsonDictionary[@"autoFillUnConcealedFieldsAsCreds"]).boolValue;
    }
    if ( jsonDictionary[@"argon2MemReductionDontAskAgain"] != nil ) {
        ret.argon2MemReductionDontAskAgain = ((NSNumber*)jsonDictionary[@"argon2MemReductionDontAskAgain"]).boolValue;
    }
    if ( jsonDictionary[@"kdbx4UpgradeDontAskAgain"] != nil ) {
        ret.kdbx4UpgradeDontAskAgain = ((NSNumber*)jsonDictionary[@"kdbx4UpgradeDontAskAgain"]).boolValue;
    }
    if ( jsonDictionary[@"lastAskedAboutArgon2MemReduction"] != nil ) {
        ret.lastAskedAboutArgon2MemReduction = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastAskedAboutArgon2MemReduction"])).doubleValue];
    }
    if ( jsonDictionary[@"lastAskedAboutKdbx4Upgrade"] != nil ) {
        ret.lastAskedAboutKdbx4Upgrade = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastAskedAboutKdbx4Upgrade"])).doubleValue];
    }
    
    
    
    if ( jsonDictionary[@"customSortOrderForFields"] != nil ) {
        ret.customSortOrderForFields = ((NSNumber*)jsonDictionary[@"customSortOrderForFields"]).boolValue;
    }
    else {
        ret.customSortOrderForFields = YES;
    }
    
    
    
    NSString* kfb = jsonDictionary[@"keyFileBookmark"];
    NSString* kffn = jsonDictionary[@"keyFileFileName"];
    
    [ret setKeyFile:kfb keyFileFileName:kffn];

    
    
    if ( jsonDictionary[@"lazySyncMode"] != nil ) {
        ret.lazySyncMode = ((NSNumber*)jsonDictionary[@"lazySyncMode"]).boolValue;
    }
    else {
        ret.lazySyncMode = NO;
    }

    if ( jsonDictionary[@"persistLazyEvenLastSyncErrors"] != nil ) {
        ret.persistLazyEvenLastSyncErrors = ((NSNumber*)jsonDictionary[@"persistLazyEvenLastSyncErrors"]).boolValue;
    }
    else {
        ret.persistLazyEvenLastSyncErrors = NO;
    }

    
    
    if ( jsonDictionary[@"asyncUpdateId"] != nil) {
        ret.asyncUpdateId = [[NSUUID alloc] initWithUUIDString:jsonDictionary[@"asyncUpdateId"]];
    }
    
    if ( jsonDictionary[@"lastViewedEntry"] != nil) {
        ret.lastViewedEntry = [[NSUUID alloc] initWithUUIDString:jsonDictionary[@"lastViewedEntry"]];
    }
    
    
    
    if ( jsonDictionary[@"showLastViewedEntryOnUnlock"] != nil ) {
        ret.showLastViewedEntryOnUnlock = ((NSNumber*)jsonDictionary[@"showLastViewedEntryOnUnlock"]).boolValue;
    }
    else {
        ret.showLastViewedEntryOnUnlock = YES;
    }

    
    
    if ( jsonDictionary[@"visibleTabs"] != nil ) {
        ret.visibleTabs = jsonDictionary[@"visibleTabs"];
    }
    else {
        ret.visibleTabs = @[@(kBrowseViewTypeHome),
                            @(kBrowseViewTypeHierarchy),
                            @(kBrowseViewTypeList),
                            @(kBrowseViewTypeTotpList)];
    }

    if ( jsonDictionary[@"hideTabBarIfOnlySingleTab"] != nil ) {
        ret.hideTabBarIfOnlySingleTab = ((NSNumber*)jsonDictionary[@"hideTabBarIfOnlySingleTab"]).boolValue;
    }
    else {
        ret.hideTabBarIfOnlySingleTab = NO;
    }
        
    
    
    if ( jsonDictionary[@"sortConfigurations"] != nil ) {
        NSDictionary* dicts = jsonDictionary[@"sortConfigurations"];
        
        NSMutableDictionary<NSString*, BrowseSortConfiguration*>* configs = NSMutableDictionary.dictionary;
        
        for ( NSString* num in dicts.allKeys ) {
            NSDictionary* dict = dicts[num];
            BrowseSortConfiguration* config = [BrowseSortConfiguration fromJsonSerializationDictionary:dict];
            configs[num] = config;
        }
        
        ret.sortConfigurations = configs.copy;
    }
    else {
        ret.sortConfigurations = @{};
    }
    
    
    
    if ( jsonDictionary[@"allowPulldownRefreshSyncInOfflineMode"] != nil ) {
        ret.allowPulldownRefreshSyncInOfflineMode = ((NSNumber*)jsonDictionary[@"allowPulldownRefreshSyncInOfflineMode"]).boolValue;
    }
    else {
        ret.allowPulldownRefreshSyncInOfflineMode = NO;
    }
    
    
    
    if ( jsonDictionary[@"lastKnownEncryptionSettings"] != nil ) {
        ret.lastKnownEncryptionSettings = jsonDictionary[@"lastKnownEncryptionSettings"];
    }
    
    if ( jsonDictionary[@"serializationPerf"] != nil ) {
        ret.serializationPerf = jsonDictionary[@"serializationPerf"];
    }

    

    if ( jsonDictionary[@"isSharedInCloudKit"] != nil ) {
        ret.isSharedInCloudKit = ((NSNumber*)jsonDictionary[@"isSharedInCloudKit"]).boolValue;
    }
    else {
        ret.isSharedInCloudKit = NO;
    }

    if ( jsonDictionary[@"isOwnedByMeCloudKit"] != nil ) {
        ret.isOwnedByMeCloudKit = ((NSNumber*)jsonDictionary[@"isOwnedByMeCloudKit"]).boolValue;
    }
    else {
        ret.isOwnedByMeCloudKit = NO;
    }

    
    
    if ( jsonDictionary[@"hasInitializedHomeTab"] != nil ) {
        ret.hasInitializedHomeTab = ((NSNumber*)jsonDictionary[@"hasInitializedHomeTab"]).boolValue;
    }
    else {
        ret.hasInitializedHomeTab = NO;
    }

    
    
    if ( jsonDictionary[@"visibleHomeSections"] != nil ) {
        ret.visibleHomeSections = jsonDictionary[@"visibleHomeSections"];
    }
    else {
        ret.visibleHomeSections = @[@(HomeViewSectionFavourites),
                                    @(HomeViewSectionNavigation),
                                    @(HomeViewSectionQuickTags),
                                    @(HomeViewSectionOtherViews)];
    }
    
    

    if ( jsonDictionary[@"hardwareKeyCRCaching"] != nil ) { 
        ret.hardwareKeyCRCaching = ((NSNumber*)jsonDictionary[@"hardwareKeyCRCaching"]).boolValue;
    }
    
    if ( jsonDictionary[@"lastChallengeRefreshAt"] != nil ) { 
        ret.lastChallengeRefreshAt = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastChallengeRefreshAt"])).doubleValue];
    }
    
    if ( jsonDictionary[@"challengeRefreshIntervalSecs"] != nil ) { 
        ret.challengeRefreshIntervalSecs = ((NSNumber*)jsonDictionary[@"challengeRefreshIntervalSecs"]).integerValue;
    }
    else {
        ret.challengeRefreshIntervalSecs = kDefaultChallengeRefreshIntervalSecs;
    }

    if ( jsonDictionary[@"cacheChallengeDurationSecs"] != nil ) {
        ret.cacheChallengeDurationSecs = ((NSNumber*)jsonDictionary[@"cacheChallengeDurationSecs"]).integerValue;
    }
    else {
        ret.cacheChallengeDurationSecs = kDefaultCacheChallengeDurationSecs;
    }

    if ( jsonDictionary[@"doNotRefreshChallengeInAF"] != nil ) {
        ret.doNotRefreshChallengeInAF = ((NSNumber*)jsonDictionary[@"doNotRefreshChallengeInAF"]).boolValue;
    }
    else {
        ret.doNotRefreshChallengeInAF = YES;
    }
    
    if ( jsonDictionary[@"doNotRefreshChallengeInAF"] != nil ) {
        ret.hasOnboardedHardwareKeyCaching = ((NSNumber*)jsonDictionary[@"hasOnboardedHardwareKeyCaching"]).boolValue;
    }

    return ret;
}

- (NSDictionary *)getJsonSerializationDictionary {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{
        @"uuid" : self.uuid,
        @"failedPinAttempts" : @(self.failedPinAttempts),
        @"autoFillEnabled" : @(self.autoFillEnabled),
        @"likelyFormat" : @(self.likelyFormat),
        @"browseViewType" : @(self.browseViewType),



        @"browseItemSubtitleField" : @(self.browseItemSubtitleField),
        @"immediateSearchOnBrowse" : @(self.immediateSearchOnBrowse),

        @"showKeePass1BackupGroup" : @(self.showKeePass1BackupGroup),
        @"showChildCountOnFolderInBrowse" : @(self.showChildCountOnFolderInBrowse),

        @"doNotShowRecycleBinInBrowse" : @(self.doNotShowRecycleBinInBrowse),
        @"showRecycleBinInSearchResults" : @(self.showRecycleBinInSearchResults),



        @"easyReadFontForAll" : @(self.easyReadFontForAll),

        @"tryDownloadFavIconForNewRecord" : @(self.tryDownloadFavIconForNewRecord),
        @"showPasswordByDefaultOnEditScreen" : @(self.showPasswordByDefaultOnEditScreen),
        @"showExpiredInBrowse" : @(self.showExpiredInBrowse),
        @"showExpiredInSearch" : @(self.showExpiredInSearch),
        @"showQuickViewFavourites2" : @(self.showQuickViewFavourites),
        @"showQuickViewNearlyExpired" : @(self.showQuickViewNearlyExpired),
        @"makeBackups" : @(self.makeBackups),
        @"maxBackupKeepCount" : @(self.maxBackupKeepCount),

        @"hideIconInBrowse" : @(self.hideIconInBrowse),
        @"tapAction" : @(self.tapAction),
        @"colorizePasswords" : @(self.colorizePasswords),
        @"keePassIconSet" : @(self.keePassIconSet),
        @"isTouchIdEnabled" : @(self.isTouchIdEnabled),
        
        @"isEnrolledForConvenience" : @(self.isEnrolledForConvenience),
        @"isAutoFillMemOnlyConveniencePasswordHasBeenStored" : @(self.isAutoFillMemOnlyConveniencePasswordHasBeenStored),
        
        @"hasUnresolvedConflicts" : @(self.hasUnresolvedConflicts),
        @"readOnly" : @(self.readOnly),
        @"hasBeenPromptedForConvenience" : @(self.hasBeenPromptedForConvenience),
        @"hasBeenPromptedForQuickLaunch" : @(self.hasBeenPromptedForQuickLaunch),
        @"showQuickViewExpired" : @(self.showQuickViewExpired),

        @"promptedForAutoFetchFavIcon" : @(self.promptedForAutoFetchFavIcon),
        @"storageProvider" : @(self.storageProvider),
        @"duressAction" : @(self.duressAction),
        @"conflictResolutionStrategy" : @(self.conflictResolutionStrategy),
        @"quickTypeEnabled" : @(self.quickTypeEnabled),
        @"quickTypeDisplayFormat" : @(self.quickTypeDisplayFormat),
        @"emptyOrNilPwPreferNilCheckFirst" : @(self.emptyOrNilPwPreferNilCheckFirst),
        @"autoLockOnDeviceLock" : @(self.autoLockOnDeviceLock),
        @"autoFillConvenienceAutoUnlockTimeout" : @(self.autoFillConvenienceAutoUnlockTimeout),
        @"autoFillCopyTotp" : @(self.autoFillCopyTotp),
        @"forceOpenOffline" : @(self.forceOpenOffline),
        @"offlineDetectedBehaviour" : @(self.offlineDetectedBehaviour),
        @"couldNotConnectBehaviour" : @(self.couldNotConnectBehaviour),
        @"convenienceExpiryPeriod" : @(self.convenienceExpiryPeriod),
        @"showConvenienceExpiryMessage" : @(self.showConvenienceExpiryMessage),
        @"hasShownInitialOnboardingScreen" : @(self.hasShownInitialOnboardingScreen),
        @"convenienceExpiryOnboardingDone" : @(self.convenienceExpiryOnboardingDone),
        @"autoFillOnboardingDone" : @(self.autoFillOnboardingDone),
        @"hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue" : @(self.hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue),
        @"onboardingDoneHasBeenShown" : @(self.onboardingDoneHasBeenShown),
        @"scheduledExport" : @(self.scheduledExport),
        @"scheduledExportOnboardingDone" : @(self.scheduledExportOnboardingDone),
        @"scheduleExportIntervalDays" : @(self.scheduleExportIntervalDays),
        @"lockEvenIfEditing" : @(self.lockEvenIfEditing),
        @"unlockCount" : @(self.unlockCount),
        @"autoFillScanNotes" : @(self.autoFillScanNotes),
        @"includeAssociatedDomains" : @(self.includeAssociatedDomains),
        @"autoFillScanCustomFields" : @(self.autoFillScanCustomFields),

        @"autoFillConcealedFieldsAsCreds" : @(self.autoFillConcealedFieldsAsCreds),
        @"autoFillUnConcealedFieldsAsCreds" : @(self.autoFillUnConcealedFieldsAsCreds),
        @"argon2MemReductionDontAskAgain" : @(self.argon2MemReductionDontAskAgain),
        @"kdbx4UpgradeDontAskAgain" : @(self.kdbx4UpgradeDontAskAgain),
        @"customSortOrderForFields" : @(self.customSortOrderForFields),
        @"lazySyncMode" : @(self.lazySyncMode),
        @"persistLazyEvenLastSyncErrors" : @(self.persistLazyEvenLastSyncErrors),
        @"showLastViewedEntryOnUnlock" : @(self.showLastViewedEntryOnUnlock),
        @"hideTabBarIfOnlySingleTab" : @(self.hideTabBarIfOnlySingleTab),
        @"allowPulldownRefreshSyncInOfflineMode" : @(self.allowPulldownRefreshSyncInOfflineMode),
        @"isSharedInCloudKit" : @(self.isSharedInCloudKit),
        @"isOwnedByMeCloudKit" : @(self.isOwnedByMeCloudKit),
        @"hasInitializedHomeTab" : @(self.hasInitializedHomeTab),
        @"hardwareKeyCRCaching" : @(self.hardwareKeyCRCaching),
        @"challengeRefreshIntervalSecs" : @(self.challengeRefreshIntervalSecs),
        @"cacheChallengeDurationSecs" : @(self.cacheChallengeDurationSecs),
        @"doNotRefreshChallengeInAF" : @(self.doNotRefreshChallengeInAF),
        @"hasOnboardedHardwareKeyCaching" : @(self.hasOnboardedHardwareKeyCaching),
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
    if (self.keyFileFileName != nil) {
        ret[@"keyFileFileName"] = self.keyFileFileName;
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

    if (self.autoFillYubiKeyConfig != nil) {
        ret[@"autoFillYubiKeyConfig"] = [self.autoFillYubiKeyConfig getJsonSerializationDictionary];
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

    if (self.lastSyncAttempt != nil) {
        ret[@"lastSyncAttempt"] = @(self.lastSyncAttempt.timeIntervalSinceReferenceDate);
    }

    if (self.autoFillLastUnlockedAt != nil) {
        ret[@"autoFillLastUnlockedAt"] = @(self.autoFillLastUnlockedAt.timeIntervalSinceReferenceDate);
    }

    if (self.nextScheduledExport != nil) {
        ret[@"nextScheduledExport"] = @(self.nextScheduledExport.timeIntervalSinceReferenceDate);
    }
    
    if (self.lastScheduledExportModDate != nil) {
        ret[@"lastScheduledExportModDate"] = @(self.lastScheduledExportModDate.timeIntervalSinceReferenceDate);
    }

    if (self.databaseCreated != nil) {
        ret[@"databaseCreated"] = @(self.databaseCreated.timeIntervalSinceReferenceDate);
    }
    
    if ( self.lastAskedAboutArgon2MemReduction != nil ) {
        ret[@"lastAskedAboutArgon2MemReduction"] = @(self.lastAskedAboutArgon2MemReduction.timeIntervalSinceReferenceDate);
    }
    if ( self.lastAskedAboutKdbx4Upgrade != nil ) {
        ret[@"lastAskedAboutKdbx4Upgrade"] = @(self.lastAskedAboutKdbx4Upgrade.timeIntervalSinceReferenceDate);
    }

    if (self.asyncUpdateId != nil) {
        ret[@"asyncUpdateId"] = self.asyncUpdateId.UUIDString;
    }
    
    if ( self.lastViewedEntry != nil ) {
        ret[@"lastViewedEntry"] = self.lastViewedEntry.UUIDString;
    }
    
    if (self.visibleTabs != nil) {
        ret[@"visibleTabs"] = self.visibleTabs;
    }
    
    if ( self.sortConfigurations ) {
        NSMutableDictionary<NSString*, NSDictionary*> *dicts = NSMutableDictionary.dictionary;
        
        for ( NSString* num in self.sortConfigurations.allKeys ) {
            BrowseSortConfiguration* config = self.sortConfigurations[num];
            
            NSDictionary* dict = [config getJsonSerializationDictionary];
            
            dicts[num] = dict;
        }
        
        ret[@"sortConfigurations"] = dicts;
    }

    if ( self.lastKnownEncryptionSettings ) {
        ret[@"lastKnownEncryptionSettings"] = self.lastKnownEncryptionSettings;
    }

    if ( self.serializationPerf ) {
        ret[@"serializationPerf"] = self.serializationPerf;
    }
    
    if (self.visibleHomeSections != nil) {
        ret[@"visibleHomeSections"] = self.visibleHomeSections;
    }
    
    
    
    if ( self.lastChallengeRefreshAt ) {
        ret[@"lastChallengeRefreshAt"] = @(self.lastChallengeRefreshAt.timeIntervalSinceReferenceDate);
    }
    
    return ret;
}



- (void)setKeyFile:(NSString*)keyFileBookmark keyFileFileName:(NSString*)keyFileFileName {
    _keyFileBookmark = keyFileBookmark;
    _keyFileFileName = keyFileFileName;
}

- (NSArray<NSString *> *)autoFillExcludedItems {
    NSString *key = [NSString stringWithFormat:@"%@-autoFillExcludedItems", self.uuid];
    
    NSArray<NSString *>* ret = [SecretStore.sharedInstance getSecureObject:key];
    
    return ret ? ret : @[];
}

- (void)setAutoFillExcludedItems:(NSArray<NSString *> *)autoFillExcludedItems {
    NSString *key = [NSString stringWithFormat:@"%@-autoFillExcludedItems", self.uuid];
    
    if( autoFillExcludedItems ) {
        [SecretStore.sharedInstance setSecureObject:autoFillExcludedItems forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

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

- (NSArray<NSString *> *)legacyFavouritesStore {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    NSArray<NSString *>* ret = [SecretStore.sharedInstance getSecureObject:key];
    
    return ret ? ret : @[];
}

- (void)setLegacyFavouritesStore:(NSArray<NSString *> *)legacyFavouritesStore {
    NSString *key = [NSString stringWithFormat:@"%@-favourites", self.uuid];
    
    if(legacyFavouritesStore) {
        [SecretStore.sharedInstance setSecureObject:legacyFavouritesStore forIdentifier:key];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}

- (NSString*)conveniencePasswordLookupKey {
#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        return [NSString stringWithFormat:@"convenience-pw-af-mem-only-%@", self.uuid];
    }
#endif

    return self.uuid;
}

- (void)triggerPasswordExpiry {
    BOOL expired = NO;
    [SecretStore.sharedInstance getSecureObject:[self conveniencePasswordLookupKey] expired:&expired];
    
    if ( expired ) { 
        self.conveniencePasswordHasExpired = YES;
    }
    else {
        if ( self.isNowAfterConvenienceExpiresAt ) {
            self.conveniencePasswordHasExpired = YES;
        }
    }
}

- (BOOL)isNowAfterConvenienceExpiresAt {
    if ( self.convenienceExpiresAt == nil ) {
        return NO;
    }
    
    return self.convenienceExpiresAt.isInPast;
}

- (NSString *)convenienceMasterPassword {
    BOOL expired = NO;
    NSString* key = [self conveniencePasswordLookupKey];
    NSString* object = (NSString*)[SecretStore.sharedInstance getSecureObject:key expired:&expired];
    
    if ( expired ) { 
        self.conveniencePasswordHasExpired = YES;
    }
    else {
        if ( self.isNowAfterConvenienceExpiresAt ) {
            self.conveniencePasswordHasExpired = YES;
            object = nil;
        }
    }

    return object; 
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    NSInteger expiringAfterHours = self.convenienceExpiryPeriod;
    NSString* key = [self conveniencePasswordLookupKey];
    
    if ( self.conveniencePasswordHasExpired ) {
        self.conveniencePasswordHasExpired = NO;
    }

    if ( expiringAfterHours == -1 || convenienceMasterPassword.length == 0 ) { 
        self.convenienceExpiresAt = nil;
        [SecretStore.sharedInstance setSecureString:convenienceMasterPassword forIdentifier:key];
    }
    else if ( expiringAfterHours == 0 ) {
        self.convenienceExpiresAt = nil;
        [SecretStore.sharedInstance setSecureEphemeralObject:convenienceMasterPassword forIdentifer:key];
    }
    else {
        NSDate *date = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitHour value:expiringAfterHours toDate:[NSDate date] options:0];
        self.convenienceExpiresAt = date;
        [SecretStore.sharedInstance setSecureString:convenienceMasterPassword forIdentifier:key];
    }
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

- (NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];
    return [SecretStore.sharedInstance getSecureString:key];
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];

    if ( conveniencePin ) {
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

- (NSURL *)backupsDirectory {
    NSURL* url = [StrongboxFilesManager.sharedInstance.backupFilesDirectory URLByAppendingPathComponent:self.uuid isDirectory:YES];
    
    [StrongboxFilesManager.sharedInstance createIfNecessary:url];
    
    return url;
}

- (BOOL)mainAppAndAutoFillYubiKeyConfigsIncoherent {
    BOOL mainAppUsesYubiKey = self.yubiKeyConfig != nil && self.yubiKeyConfig.mode != kNoYubiKey;
    BOOL autoFillUsesYubiKey = self.autoFillYubiKeyConfig != nil && self.yubiKeyConfig.mode != kNoYubiKey;

    return !(!mainAppUsesYubiKey && !autoFillUsesYubiKey) && !(mainAppUsesYubiKey && autoFillUsesYubiKey);
}

- (YubiKeyHardwareConfiguration *)contextAwareYubiKeyConfig {
#ifndef IS_APP_EXTENSION
    return self.yubiKeyConfig;
#else
    return self.autoFillYubiKeyConfig;
#endif
}

- (void)setContextAwareYubiKeyConfig:(YubiKeyHardwareConfiguration *)contextAwareYubiKeyConfig {
#ifndef IS_APP_EXTENSION
    self.yubiKeyConfig = contextAwareYubiKeyConfig;
#else
    self.autoFillYubiKeyConfig = contextAwareYubiKeyConfig;
#endif
}



- (YubiKeyHardwareConfiguration *)nextGenPrimaryYubiKeyConfig {
    return self.contextAwareYubiKeyConfig;
}

- (void)setNextGenPrimaryYubiKeyConfig:(YubiKeyHardwareConfiguration *)nextGenPrimaryYubiKeyConfig {
    self.yubiKeyConfig = nextGenPrimaryYubiKeyConfig;
    self.autoFillYubiKeyConfig = nextGenPrimaryYubiKeyConfig;
}



- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%lu] - [%@-%@]", self.nickName, (unsigned long)self.storageProvider, self.fileName, self.fileIdentifier];
}

- (BOOL)isConvenienceUnlockEnabled {
    return self.isTouchIdEnabled || (self.conveniencePin != nil);
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

    BOOL ret = [AppPreferences.sharedInstance.sharedAppGroupDefaults boolForKey:key];
    
    return ret;
}

- (void)setConveniencePasswordHasExpired:(BOOL)conveniencePasswordHasExpired {
    NSString *key = [NSString stringWithFormat:@"%@-pw-has-expired", self.uuid];
    
#ifdef IS_APP_EXTENSION 
    if ( self.convenienceExpiryPeriod == 0 ) {
        key = [NSString stringWithFormat:@"%@-pw-has-expired-af-mem-only", self.uuid];
    }
#endif

    [AppPreferences.sharedInstance.sharedAppGroupDefaults setBool:conveniencePasswordHasExpired forKey:key];
}

- (NSDate *)convenienceExpiresAt {
    NSString *key = [NSString stringWithFormat:@"%@-pw-expires-at", self.uuid];
    
    NSDate* ret = [AppPreferences.sharedInstance.sharedAppGroupDefaults objectForKey:key];
    
    return ret;
}

- (void)setConvenienceExpiresAt:(NSDate *)convenienceExpiresAt {
    NSString *key = [NSString stringWithFormat:@"%@-pw-expires-at", self.uuid];

    [AppPreferences.sharedInstance.sharedAppGroupDefaults setObject:convenienceExpiresAt forKey:key];
}

- (NSString *)exportFilename {
    NSString* baseFilename = self.fileName;
    NSString* extension = baseFilename.pathExtension;
    NSString* withoutExtension = [baseFilename.lastPathComponent stringByDeletingPathExtension];
    NSString* newFileName = [withoutExtension stringByAppendingFormat:@"-%@", NSDate.date.fileNameCompatibleDateTime];
    
    return [newFileName stringByAppendingPathExtension:extension];
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
            slog(@"👾 setting challenge cache with expiry = [%@]", expiry.friendlyDateTimeStringBothPrecise);
            [SecretStore.sharedInstance setSecureObject:cachedYubiKeyChallengeResponses forIdentifier:key expiresAt:expiry];
        }
        else if ( self.cacheChallengeDurationSecs == 0 ) { 
            slog(@"👾 setting challenge cache forever");
            [SecretStore.sharedInstance setSecureObject:cachedYubiKeyChallengeResponses forIdentifier:key];
        }
        else {
            slog(@"👾 setting challenge cache ephemeral");
            [SecretStore.sharedInstance setSecureEphemeralObject:cachedYubiKeyChallengeResponses forIdentifer:key];
        }
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:key];
    }
}



- (void)clearKeychainItems {
    self.convenienceMasterPassword = nil;
    self.autoFillConvenienceAutoUnlockPassword = nil;
    self.legacyFavouritesStore = nil;
    self.duressPin = nil;
    self.conveniencePin = nil;
    self.cachedYubiKeyChallengeResponses = nil;
}

@end
