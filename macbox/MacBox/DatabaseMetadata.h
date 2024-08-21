//
//  SafeMetaData.h
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"
#import "SecretStore.h"
#import "YubiKeyConfiguration.h"
#import "QuickTypeAutoFillDisplayFormat.h"
#import "ConflictResolutionStrategy.h"
#import "DatabaseAuditorConfiguration.h"
#import "DatabaseFormat.h"
#import "KeePassIconSet.h"
#import "NextNavigationConstants.h"
#import "SearchScope.h"
#import "HeaderNodeState.h"
#import "SideBarChildCountFormat.h"

@class HeaderNodeState;

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger kDefaultPasswordExpiryHours;

@interface DatabaseMetadata : NSObject

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo;

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSURL *fileUrl; 
@property (nonatomic, strong, nullable) NSString *storageInfo; 
@property (nonatomic, strong, nullable) NSString *autoFillStorageInfo; 
@property (nonatomic) StorageProvider storageProvider;

@property (nonatomic, strong, nullable) NSString* conveniencePassword;
@property (nonatomic, strong, nullable) NSString* keyFileBookmark;
@property (nonatomic, strong, nullable) NSString* autoFillKeyFileBookmark;

@property (nonatomic, strong, nullable) YubiKeyConfiguration* yubiKeyConfiguration;



@property (nonatomic) BOOL autoFillEnabled;
@property (nonatomic) BOOL quickTypeEnabled;
@property (nonatomic) QuickTypeAutoFillDisplayFormat quickTypeDisplayFormat;

@property (nonatomic) BOOL hasPromptedForAutoFillEnrol;

- (SecretExpiryMode)getConveniencePasswordExpiryMode;
- (NSDate*)getConveniencePasswordExpiryDate;

- (void)clearSecureItems;

@property (nullable) NSUUID* outstandingUpdateId;
@property (nullable) NSDate* lastSyncRemoteModDate; 
@property (nullable) NSDate* lastSyncAttempt;
@property BOOL launchAtStartup;

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

/* =================================================================================================== */
/* Migrated to Per Database Settings - Begin 14 Jun 2021 - Give 3 months migration time -> 14-Sep-2021 */

@property BOOL showQuickView;
@property BOOL doNotShowTotp;
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
@property NSArray<NSString*>* visibleColumns;

/* =================================================================================================== */

@property BOOL hasSetInitialWindowPosition;
@property BOOL hasSetInitialUnlockedFrame;



@property BOOL autoFillScanCustomFields;
@property BOOL autoFillScanNotes;




@property (nonatomic, strong, nullable) NSString* conveniencePin;
@property (nullable) NSArray<NSString*>* legacyFavouritesStore;
@property DatabaseAuditorConfiguration* auditConfig;
@property (nullable) NSArray<NSString*>* auditExcludedItems;
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
@property BOOL conveniencePasswordHasExpired; 
@property BOOL hasBeenPromptedForConvenience; 
@property NSInteger convenienceExpiryPeriod; 
@property (nonatomic, strong, nullable) NSString* convenienceMasterPassword; 

@property (nonatomic) BOOL conveniencePasswordHasBeenStored; 

- (void)triggerPasswordExpiry;



@property BOOL includeAssociatedDomains;
@property BOOL autoFillConcealedFieldsAsCreds;
@property BOOL autoFillUnConcealedFieldsAsCreds;

@property (nullable) NSUUID* asyncUpdateId; 

@property BOOL promptedForAutoFetchFavIcon;



@property KeePassIconSet iconSet;



@property OGNavigationContext sideBarNavigationContext;
@property (nullable) NSUUID* sideBarSelectedGroup;
@property (nullable) NSUUID* sideBarSelectedFavouriteId;
@property (nullable) NSString* sideBarSelectedTag;
@property OGNavigationSpecial sideBarSelectedSpecial;
@property OGNavigationAuditCategory sideBarSelectedAuditCategory;
@property NSArray<NSUUID*> *browseSelectedItems;
@property NSString* searchText;
@property SearchScope searchScope;
@property BOOL searchIncludeGroups;

@property NSArray<HeaderNodeState*>* headerNodes;

@property BOOL customSortOrderForFields;

@property BOOL autoFillCopyTotp;

@property BOOL showChildCountOnFolderInSidebar;
@property SideBarChildCountFormat sideBarChildCountFormat;
@property NSString* sideBarChildCountGroupPrefix;
@property NSString* sideBarChildCountSeparator;
@property BOOL sideBarChildCountShowZero;
@property BOOL sideBarShowTotalCountOnHierarchy;

@property (nullable) NSArray<NSString*>* autoFillExcludedItems;

@property BOOL isSharedInCloudKit; 
@property BOOL isOwnedByMeCloudKit; 

@property (nullable) NSDictionary<NSData*, NSData*> *cachedYubiKeyChallengeResponses;
@property BOOL hardwareKeyCRCaching;
@property BOOL doNotRefreshChallengeInAF;
@property BOOL hasOnboardedHardwareKeyCaching;

@property (nullable) NSDate* lastChallengeRefreshAt;
@property NSInteger challengeRefreshIntervalSecs;
@property NSInteger cacheChallengeDurationSecs;

@property BOOL markDirtyOnExpandCollapseGroups;

@end

NS_ASSUME_NONNULL_END
