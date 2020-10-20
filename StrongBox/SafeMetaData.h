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

typedef NS_ENUM (NSInteger, KeePassIconSet) {
    kKeePassIconSetClassic,
    kKeePassIconSetSfSymbols,
    kKeePassIconSetKeePassXC,
};

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

@property (nonatomic) BOOL hasBeenPromptedForConvenience;
@property (nonatomic) BOOL isEnrolledForConvenience;
@property (nonatomic, strong, nullable) NSString* convenienceMasterPassword;
@property (nonatomic, strong, nullable) NSString* convenenienceYubikeySecret;  // TODO: Kill with fire

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

// Browse View

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
@property BOOL viewDereferencedFields;
@property BOOL searchDereferencedFields;
@property BOOL showExpiredInSearch;
@property BOOL showExpiredInBrowse;
@property BOOL hideIconInBrowse;

// Details View
@property BOOL showEmptyFieldsInDetailsView;
@property NSArray<NSNumber*>* detailsViewCollapsedSections;
@property BOOL easyReadFontForAll;
@property BOOL hideTotp;
@property BOOL tryDownloadFavIconForNewRecord;
@property BOOL showPasswordByDefaultOnEditScreen;

///

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

// The YubiKey configuration can be different in AutoFill mode - to allow users to use Hardware key in Main App and Virtual in Auto Fill
@property (nullable) YubiKeyHardwareConfiguration* contextAwareYubiKeyConfig;
@property (readonly) BOOL mainAppAndAutoFillYubiKeyConfigsIncoherent;
@property (nullable) YubiKeyHardwareConfiguration* autoFillYubiKeyConfig; // TODO: Remove access after migration of emergency workaround field

@property DatabaseAuditorConfiguration* auditConfig;

@property BOOL colorizePasswords;
@property BOOL colorizeProtectedCustomFields;

@property KeePassIconSet keePassIconSet;

@property BOOL promptedForAutoFetchFavIcon;

@property (nullable) NSUUID* outstandingUpdateId;
@property (nullable) NSDate* lastSyncRemoteModDate; // Last time we got a remote sync (pulled from remote)

@end

NS_ASSUME_NONNULL_END
