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

@property (nonatomic, strong, readonly) NSString* conveniencePassword;
@property (nonatomic, strong, nullable) NSString* keyFileBookmark;
@property (nonatomic, strong, nullable) NSString* autoFillKeyFileBookmark;

@property (nonatomic, strong) YubiKeyConfiguration* yubiKeyConfiguration;

@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic) BOOL isWatchUnlockEnabled;

@property (nonatomic) BOOL isTouchIdEnrolled; 
@property (nonatomic) BOOL hasPromptedForTouchIdEnrol;
@property (nonatomic) NSInteger touchIdPasswordExpiryPeriodHours;

@property (nonatomic) BOOL autoFillEnabled;
@property (nonatomic) BOOL quickTypeEnabled;
@property (nonatomic) QuickTypeAutoFillDisplayFormat quickTypeDisplayFormat;

@property (nonatomic) BOOL quickWormholeFillEnabled;
@property (nonatomic) BOOL hasPromptedForAutoFillEnrol;

- (SecretExpiryMode)getConveniencePasswordExpiryMode;
- (NSDate*)getConveniencePasswordExpiryDate;
    
- (NSString*)getConveniencePassword:(BOOL*_Nullable)expired;

- (void)clearSecureItems;
- (void)resetConveniencePasswordWithCurrentConfiguration:(NSString*_Nullable)password; 

@property (nullable) NSUUID* outstandingUpdateId;
@property (nullable) NSDate* lastSyncRemoteModDate; 
@property (nullable) NSDate* lastSyncAttempt;
@property BOOL launchAtStartup;
@property BOOL autoPromptForConvenienceUnlockOnActivate;

@property (nonatomic, strong, nullable) NSString* autoFillConvenienceAutoUnlockPassword;
@property NSInteger autoFillConvenienceAutoUnlockTimeout; 
@property (nullable) NSDate* autoFillLastUnlockedAt;

@property (readonly) ConflictResolutionStrategy conflictResolutionStrategy;

@property BOOL monitorForExternalChanges;
@property NSInteger monitorForExternalChangesInterval;

@property BOOL autoReloadAfterExternalChanges;

@property (readonly) NSURL* backupsDirectory;
@property NSUInteger maxBackupKeepCount;
@property BOOL makeBackups;  

@property (readonly) BOOL isLocalDeviceDatabase;

@property BOOL offlineMode; 
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
@property BOOL outlineViewEditableFieldsAreReadonly;
@property BOOL concealEmptyProtectedFields;
@property BOOL startWithSearch;
@property BOOL showAdvancedUnlockOptions;
@property BOOL lockOnScreenLock;
@property BOOL expressDownloadFavIconOnNewOrUrlChanged; 
@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;
@property BOOL uiDoNotSortKeePassNodesInBrowseView; 
@property NSArray<NSString*>* visibleColumns;

/* =================================================================================================== */

@property BOOL hasSetInitialWindowPosition;



@property BOOL autoFillScanAltUrls;
@property BOOL autoFillScanCustomFields;
@property BOOL autoFillScanNotes;

@end

NS_ASSUME_NONNULL_END
