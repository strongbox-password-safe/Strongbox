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

NS_ASSUME_NONNULL_BEGIN

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

@property (nullable) NSString* keyFileBookmark;

@property DatabaseFormat likelyFormat;

@property (nonatomic) BOOL readOnly;
@property BrowseViewType browseViewType;

@property BrowseTapAction tapAction;
@property BrowseTapAction doubleTapAction;
@property BrowseTapAction tripleTapAction;
@property BrowseTapAction longPressTapAction;



@property BrowseSortField browseSortField;
@property BOOL browseSortOrderDescending;
@property BOOL browseSortFoldersSeparately;
@property BrowseItemSubtitleField browseItemSubtitleField;
@property BOOL immediateSearchOnBrowse;
@property BOOL hideTotpInBrowse;
@property BOOL showKeePass1BackupGroup;
@property BOOL showChildCountOnFolderInBrowse;
@property BOOL showFlagsInBrowse;
@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;


@property (readonly) BOOL viewDereferencedFields;
@property (readonly) BOOL searchDereferencedFields;

@property BOOL showExpiredInSearch;
@property BOOL showExpiredInBrowse;
@property BOOL hideIconInBrowse;


@property BOOL showEmptyFieldsInDetailsView;
@property NSArray<NSNumber*>* detailsViewCollapsedSections;
@property BOOL easyReadFontForAll;
@property BOOL hideTotp;
@property BOOL tryDownloadFavIconForNewRecord;
@property BOOL showPasswordByDefaultOnEditScreen;



@property NSNumber *autoLockTimeoutSeconds;

@property BOOL showQuickViewFavourites;
@property BOOL showQuickViewNearlyExpired;
@property BOOL showQuickViewExpired;

@property (nullable) NSArray<NSString*>* favourites;
@property (nullable) NSArray<NSString*>* auditExcludedItems;

@property (readonly) NSURL* backupsDirectory;
@property NSUInteger maxBackupKeepCount;
@property BOOL makeBackups;

@property BOOL hideTotpCustomFieldsInViewMode;


@property (nullable) YubiKeyHardwareConfiguration* contextAwareYubiKeyConfig;
@property (readonly) BOOL mainAppAndAutoFillYubiKeyConfigsIncoherent;

@property DatabaseAuditorConfiguration* auditConfig;

@property BOOL colorizePasswords;
@property BOOL colorizeProtectedCustomFields;

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


@property BOOL autoFillScanAltUrls;
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

@end

NS_ASSUME_NONNULL_END
