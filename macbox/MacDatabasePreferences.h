//
//  MacDatabasePreferences.h
//  MacBox
//
//  Created by Strongbox on 04/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"
#import "YubiKeyConfiguration.h"
#import "QuickTypeAutoFillDisplayFormat.h"
#import "ConflictResolutionStrategy.h"
#import "DatabaseAuditorConfiguration.h"
#import "DatabaseFormat.h"
#import "SecretStore.h"
#import "BrowseSortField.h"
#import "KeePassIconSet.h"
#import "NextNavigationConstants.h"
#import "SearchScope.h"
#import "SideBarChildCountFormat.h"
#import "SBLog.h"
#import "MMcGPair.h"

@class HeaderNodeState;

NS_ASSUME_NONNULL_BEGIN

@interface MacDatabasePreferences : NSObject

@property (readonly) NSString* uuid;

+ (instancetype)fromUuid:(NSString*)uuid;
+ (instancetype)fromUrl:(NSURL*)url;
+ (instancetype _Nullable)getById:(NSString *)databaseId;

+ (NSArray<MacDatabasePreferences*>*)forAllDatabasesOfProvider:(StorageProvider)provider;

+ (NSArray<MacDatabasePreferences*>*)filteredDatabases:(BOOL (^)(MacDatabasePreferences* database))block;

+ (instancetype)templateDummyWithNickName:(NSString *)nickName
                          storageProvider:(StorageProvider)storageProvider
                                  fileUrl:(NSURL*)fileUrl
                              storageInfo:(NSString*)storageInfo;

- (instancetype)init NS_UNAVAILABLE;

@property (class, readonly) NSArray<MacDatabasePreferences*>* allDatabases;



- (SecretExpiryMode)getConveniencePasswordExpiryMode;
- (NSDate*)getConveniencePasswordExpiryDate;
- (void)clearSecureItems;
@property (nonatomic, strong, nullable) YubiKeyConfiguration* yubiKeyConfiguration;
@property NSArray<NSString*>* visibleColumns;
@property (nullable) NSArray<NSString*>* legacyFavouritesStore;
@property DatabaseAuditorConfiguration* auditConfig;
@property (nullable) NSArray<NSString*>* auditExcludedItems;
- (void)triggerPasswordExpiry;

+ (NSString *_Nonnull)trimDatabaseNickName:(NSString *_Nonnull)string;
+ (BOOL)isUnique:(NSString *)nickName;
+ (BOOL)isValid:(NSString *)nickName;

+ (NSString*)getSuggestedNewDatabaseName;
+ (NSString*)getUniqueNameFromSuggestedName:(NSString*)suggested;

+ (MacDatabasePreferences*)addOrGet:(NSURL *)url;

- (void)add;
- (void)remove;
+ (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;

@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSURL *fileUrl; 
@property (nonatomic, strong, nullable) NSString *storageInfo; 
@property (nonatomic, strong, nullable) NSString *autoFillStorageInfo; 
@property (nonatomic) StorageProvider storageProvider;
@property (nonatomic, strong, nullable) NSString* conveniencePassword;
@property (nonatomic, strong, nullable) NSString* keyFileBookmark;
@property (nonatomic, strong, nullable) NSString* autoFillKeyFileBookmark;
@property (nonatomic) BOOL autoFillEnabled;

@property (nonatomic) BOOL quickTypeEnabled;
@property (nonatomic) QuickTypeAutoFillDisplayFormat quickTypeDisplayFormat;

@property (nonatomic) BOOL hasPromptedForAutoFillEnrol;
@property (nullable) NSUUID* outstandingUpdateId;
@property (nullable) NSDate* lastSyncRemoteModDate; 
@property (nullable) NSDate* lastSyncAttempt;
@property BOOL launchAtStartup;
@property BOOL autoPromptForConvenienceUnlockOnActivate;
@property (nonatomic, strong, nullable) NSString* autoFillConvenienceAutoUnlockPassword;
@property NSInteger autoFillConvenienceAutoUnlockTimeout; 
@property (nullable) NSDate* autoFillLastUnlockedAt;
@property ConflictResolutionStrategy conflictResolutionStrategy;
@property BOOL monitorForExternalChanges;
@property NSInteger monitorForExternalChangesInterval;
@property BOOL autoReloadAfterExternalChanges;
@property (readonly) NSURL* backupsDirectory;
@property NSUInteger maxBackupKeepCount;
@property BOOL makeBackups;
@property (readonly) BOOL isLocalDeviceDatabase;
@property BOOL userRequestOfflineOpenEphemeralFlagForDocument; 
@property BOOL alwaysOpenOffline;
@property BOOL readOnly;
@property BOOL showQuickView;

@property BOOL noAlternatingRows;
@property BOOL showHorizontalGrid;
@property BOOL showVerticalGrid;
@property BOOL doNotShowAutoCompleteSuggestions;
@property BOOL doNotShowChangeNotifications;
@property BOOL outlineViewTitleIsReadonly;
@property BOOL concealEmptyProtectedFields;
@property BOOL startWithSearch;
@property BOOL showAdvancedUnlockOptions;
@property BOOL expressDownloadFavIconOnNewOrUrlChanged;
@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;
@property BOOL uiDoNotSortKeePassNodesInBrowseView;

@property BOOL hasSetInitialWindowPosition;
@property BOOL hasSetInitialUnlockedFrame;

@property BOOL autoFillScanCustomFields;
@property BOOL autoFillScanNotes;
@property (nonatomic, strong, nullable) NSString* conveniencePin;
@property NSUInteger unlockCount;
@property DatabaseFormat likelyFormat;
@property NSString* lastKnownEncryptionSettings;
@property NSString* serializationPerf;
@property BOOL emptyOrNilPwPreferNilCheckFirst; 
@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic) BOOL isWatchUnlockEnabled;
@property (nonatomic) BOOL hasPromptedForTouchIdEnrol;
@property (nonatomic) NSInteger touchIdPasswordExpiryPeriodHours;
@property (nonatomic, readonly) BOOL isConvenienceUnlockEnabled; 
@property (readonly) BOOL conveniencePasswordHasExpired; 
@property BOOL hasBeenPromptedForConvenience; 
@property NSInteger convenienceExpiryPeriod; 
@property (nonatomic, strong, nullable) NSString* convenienceMasterPassword; 
@property (nonatomic) BOOL conveniencePasswordHasBeenStored; 
@property BOOL includeAssociatedDomains;
@property BOOL autoFillConcealedFieldsAsCreds;
@property BOOL autoFillUnConcealedFieldsAsCreds;
@property (nullable) NSUUID* asyncUpdateId; 
@property BOOL promptedForAutoFetchFavIcon;

@property (readonly) NSString* exportFileName;
@property (readonly) NSDictionary<NSString*, NSString *>* debugInfoLines;

@property KeePassIconSet keePassIconSet;



@property OGNavigationContext sideBarNavigationContext;
@property (nullable) NSUUID* sideBarSelectedGroup;
@property (nullable) NSString* sideBarSelectedTag;
@property OGNavigationSpecial sideBarSelectedSpecial;
@property OGNavigationAuditCategory sideBarSelectedAuditCategory;
@property (nullable) NSUUID* sideBarSelectedFavouriteId;
@property NSArray<NSUUID*>* browseSelectedItems;
@property NSString* searchText;
@property SearchScope searchScope;

@property NSArray<HeaderNodeState*>* headerNodes;
@property BOOL customSortOrderForFields;
@property BOOL autoFillCopyTotp;

@property BOOL showChildCountOnFolderInSidebar;
@property SideBarChildCountFormat sideBarChildCountFormat;
@property NSString* sideBarChildCountGroupPrefix;
@property NSString* sideBarChildCountSeparator;
@property BOOL sideBarChildCountShowZero;
@property BOOL sideBarShowTotalCountOnHierarchy;

@property BOOL searchIncludeGroups;





@property (nullable) NSArray<NSString*>* autoFillExcludedItems;

@property (readonly) BOOL searchDereferencedFields;
@property (readonly) BOOL showKeePass1BackupGroup;
@property (readonly) BOOL showExpiredInSearch;



@property BOOL isSharedInCloudKit; 
@property BOOL isOwnedByMeCloudKit;

@property BOOL hardwareKeyCRCaching;
@property BOOL doNotRefreshChallengeInAF;
@property BOOL hasOnboardedHardwareKeyCaching;
@property (nullable) NSDate* lastChallengeRefreshAt;
@property NSInteger challengeRefreshIntervalSecs;
@property NSInteger cacheChallengeDurationSecs;

- (void)addCachedChallengeResponse:(MMcGPair<NSData*, NSData*>*)challengeResponse;
- (void)removeCachedChallenge:(NSData*)challenge;
- (void)clearCachedChallengeResponses;
- (NSData*)getCachedChallengeResponse:(NSData*)challenge;

@property BOOL markDirtyOnExpandCollapseGroups;

@end

NS_ASSUME_NONNULL_END
