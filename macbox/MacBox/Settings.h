//
//  Settings.h
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationConfig.h"
#import "AutoFillNewRecordSettings.h"
#import "FavIconDownloadOptions.h"

extern NSString* const kTitleColumn;
extern NSString* const kUsernameColumn;
extern NSString* const kPasswordColumn;
extern NSString* const kTOTPColumn;
extern NSString* const kURLColumn;
extern NSString* const kEmailColumn;
extern NSString* const kExpiresColumn;
extern NSString* const kNotesColumn;
extern NSString* const kAttachmentsColumn;
extern NSString* const kCustomFieldsColumn;

extern NSString *const kPreferenceGlobalShowShortcut;

@interface Settings : NSObject

+ (instancetype)sharedInstance;

@property (readonly) NSString* appGroupName;
@property (readonly) NSUserDefaults* sharedAppGroupDefaults;

+ (NSArray<NSString*> *)kAllColumns;

@property (nonatomic) BOOL fullVersion;
@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;
@property (nonatomic, strong) NSDate* endFreeTrialDate;
@property (readonly) BOOL isProOrFreeTrial;
@property (readonly) BOOL isPro;
@property (readonly) BOOL isFreeTrial;

@property (nonatomic) BOOL warnedAboutTouchId;

@property (nonatomic) AutoFillNewRecordSettings *autoFillNewRecordSettings;
@property (readonly) BOOL dereferenceInQuickView;
@property (readonly) BOOL dereferenceInOutlineView;
@property (readonly) BOOL dereferenceDuringSearch;
@property BOOL floatOnTop;
@property (readonly) NSString* easyReadFontName;
@property PasswordGenerationConfig *passwordGenerationConfig;
@property BOOL showSystemTrayIcon;
@property FavIconDownloadOptions *favIconDownloadOptions;
@property BOOL hideKeyFileNameOnLockScreen;
@property BOOL doNotRememberKeyFile;
@property BOOL allowEmptyOrNoPasswordEntry;
@property BOOL colorizePasswords;
@property BOOL colorizeUseColorBlindPalette;
@property BOOL clipboardHandoff;
@property BOOL showDatabasesManagerOnCloseAllWindows;
@property BOOL showAutoFillTotpCopiedMessage;
@property BOOL autoFillAutoLaunchSingleDatabase;
@property BOOL useLegacyFileProvider;
@property (nonatomic) BOOL autoSave;
@property BOOL hasMigratedToSyncManager; 
@property BOOL hideDockIconOnAllMinimized;
@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;
@property (nonatomic) BOOL revealPasswordsImmediately;

@property (nonatomic) NSInteger autoLockTimeoutSeconds; 

/* =================================================================================================== */


@property BOOL showCustomFieldsOnQuickViewPanel;
@property BOOL showAttachmentsOnQuickViewPanel;
@property BOOL showAttachmentImagePreviewsOnQuickViewPanel;

/* =================================================================================================== */
/* Migrated to Per Database Settings - Begin 14 Jun 2021 - Give 3 months migration time -> 14-Sep-2021 */

@property (nonatomic) BOOL showQuickView;
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

@property BOOL migratedConnections;

@property BOOL closeManagerOnLaunch;
@property BOOL makeLocalRollingBackups;

@end
