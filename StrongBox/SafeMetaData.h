//
//  SafeDetails.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"
#import "DuressAction.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "BrowseViewType.h"
#import "BrowseTapAction.h"
#import "BrowseSortField.h"
#import "BrowseItemSubtitleField.h"
#import "YubiKeyHardwareConfiguration.h"
#import "DatabaseAuditorConfiguration.h"
#import "KeePassIconSet.h"
#import "ConflictResolutionStrategy.h"
#import "QuickTypeAutoFillDisplayFormat.h"
#import "OfflineDetectedBehaviour.h"
#import "CouldNotConnectBehaviour.h"
#import "BrowseSortConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger kDefaultConvenienceExpiryPeriodHours;

@interface SafeMetaData : NSObject

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier;

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary*)jsonDictionary;
- (NSDictionary*)getJsonSerializationDictionary;

- (void)clearKeychainItems;

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileIdentifier;
@property (nonatomic) StorageProvider storageProvider;

@property BOOL hasBeenPromptedForQuickLaunch;














@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic, strong, nullable) NSString* conveniencePin;
@property (nonatomic, strong, nullable) NSString* duressPin;
@property (nonatomic) DuressAction duressAction;
@property (nonatomic) int failedPinAttempts;

@property (nonatomic) BOOL autoFillEnabled;
@property (nonatomic) BOOL hasUnresolvedConflicts;

@property (nullable, readonly) NSString* keyFileBookmark;
@property (nullable, readonly) NSString* keyFileFileName;
- (void)setKeyFile:(NSString*)keyFileBookmark keyFileFileName:(NSString*)keyFileFileName;

@property DatabaseFormat likelyFormat;
@property NSString* lastKnownEncryptionSettings;
@property NSString* serializationPerf;

@property (nonatomic) BOOL readOnly;
@property BrowseViewType browseViewType;

@property BrowseTapAction tapAction;



@property BrowseItemSubtitleField browseItemSubtitleField;
@property BOOL immediateSearchOnBrowse;

@property BOOL showKeePass1BackupGroup;
@property BOOL showChildCountOnFolderInBrowse;

@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;


@property (readonly) BOOL viewDereferencedFields;
@property (readonly) BOOL searchDereferencedFields;

@property BOOL showExpiredInSearch;
@property BOOL showExpiredInBrowse;
@property BOOL hideIconInBrowse;



@property NSArray<NSNumber*>* detailsViewCollapsedSections;
@property BOOL easyReadFontForAll;

@property BOOL tryDownloadFavIconForNewRecord;
@property BOOL showPasswordByDefaultOnEditScreen;



@property NSNumber *autoLockTimeoutSeconds;

@property BOOL showQuickViewFavourites;
@property BOOL showQuickViewNearlyExpired;
@property BOOL showQuickViewExpired;

@property (nullable) NSArray<NSString*>* legacyFavouritesStore;
@property (nullable) NSArray<NSString*>* auditExcludedItems;
@property (nullable) NSArray<NSString*>* autoFillExcludedItems;
 
@property (readonly) NSURL* backupsDirectory;
@property NSUInteger maxBackupKeepCount;
@property BOOL makeBackups;



@property (nullable) YubiKeyHardwareConfiguration* contextAwareYubiKeyConfig; 
@property (nullable) YubiKeyHardwareConfiguration* nextGenPrimaryYubiKeyConfig; 

@property (readonly) BOOL mainAppAndAutoFillYubiKeyConfigsIncoherent;



@property DatabaseAuditorConfiguration* auditConfig;

@property BOOL colorizePasswords;

@property KeePassIconSet keePassIconSet;

@property BOOL promptedForAutoFetchFavIcon;

@property (nullable) NSUUID* outstandingUpdateId;
@property (nullable) NSDate* lastSyncRemoteModDate; 
@property (nullable) NSDate* lastSyncAttempt;

@property ConflictResolutionStrategy conflictResolutionStrategy;

@property BOOL quickTypeEnabled;















@property QuickTypeAutoFillDisplayFormat quickTypeDisplayFormat;
@property BOOL emptyOrNilPwPreferNilCheckFirst; 
@property BOOL autoLockOnDeviceLock;

@property NSInteger autoFillConvenienceAutoUnlockTimeout; 
@property (nullable) NSDate* autoFillLastUnlockedAt;

@property BOOL autoFillCopyTotp;
@property BOOL forceOpenOffline;

@property OfflineDetectedBehaviour offlineDetectedBehaviour;
@property CouldNotConnectBehaviour couldNotConnectBehaviour;

@property BOOL showConvenienceExpiryMessage;
@property BOOL hasShownInitialOnboardingScreen;
@property BOOL convenienceExpiryOnboardingDone;
@property BOOL autoFillOnboardingDone;
@property BOOL hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue;
@property BOOL onboardingDoneHasBeenShown;



@property BOOL scheduledExport;
@property BOOL scheduledExportOnboardingDone;
@property NSUInteger scheduleExportIntervalDays;
@property (nullable) NSDate* nextScheduledExport;
@property (nullable) NSDate* lastScheduledExportModDate;



@property BOOL lockEvenIfEditing;

@property (nullable) NSDate* databaseCreated;
@property NSUInteger unlockCount;

@property BOOL includeAssociatedDomains;
@property BOOL autoFillScanCustomFields;
@property BOOL autoFillScanNotes;

@property (nonatomic, strong, nullable) NSString* autoFillConvenienceAutoUnlockPassword;



@property (nonatomic, readonly) BOOL isConvenienceUnlockEnabled; 
@property BOOL conveniencePasswordHasExpired; 
@property BOOL hasBeenPromptedForConvenience; 
@property NSInteger convenienceExpiryPeriod; 
@property (nonatomic, strong, nullable) NSString* convenienceMasterPassword; 

@property (nonatomic) BOOL conveniencePasswordHasBeenStored; 

- (void)triggerPasswordExpiry;



@property BOOL autoFillConcealedFieldsAsCreds;
@property BOOL autoFillUnConcealedFieldsAsCreds;
@property BOOL argon2MemReductionDontAskAgain;
@property (nullable) NSDate* lastAskedAboutArgon2MemReduction;
@property BOOL kdbx4UpgradeDontAskAgain;
@property (nullable) NSDate* lastAskedAboutKdbx4Upgrade;

@property BOOL customSortOrderForFields;

@property BOOL lazySyncMode; 
@property BOOL persistLazyEvenLastSyncErrors; 

@property (nullable) NSUUID* asyncUpdateId; 

@property (nullable) NSUUID* lastViewedEntry;
@property BOOL showLastViewedEntryOnUnlock;

@property NSDictionary<NSString*, BrowseSortConfiguration*>* sortConfigurations;

@property (readonly) NSString* exportFilename;

@property BOOL allowPulldownRefreshSyncInOfflineMode;

@property BOOL isSharedInCloudKit; 
@property BOOL isOwnedByMeCloudKit; 

@property BOOL hasInitializedHomeTab;

@property NSArray<NSNumber*>* visibleHomeSections;

@property NSArray<NSNumber*>* visibleTabs;
@property BOOL hideTabBarIfOnlySingleTab;

@property (nullable) NSDictionary<NSData*, NSData*> *cachedYubiKeyChallengeResponses;
@property BOOL hardwareKeyCRCaching;
@property BOOL doNotRefreshChallengeInAF;
@property BOOL hasOnboardedHardwareKeyCaching;
@property (nullable) NSDate* lastChallengeRefreshAt;
@property NSInteger challengeRefreshIntervalSecs;
@property NSInteger cacheChallengeDurationSecs;

@end

NS_ASSUME_NONNULL_END
