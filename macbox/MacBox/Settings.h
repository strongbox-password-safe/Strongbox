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

@interface Settings : NSObject

+ (instancetype)sharedInstance;

@property (readonly) NSString* appGroupName;

@property (readonly) NSUserDefaults* sharedAppGroupDefaults;

+ (NSArray<NSString*> *)kAllColumns;

@property (nonatomic) BOOL revealDetailsImmediately;
@property (nonatomic) BOOL fullVersion;

@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;
@property (nonatomic, strong) NSDate* endFreeTrialDate;
@property (nonatomic) NSInteger autoLockTimeoutSeconds;

@property (nonatomic) BOOL alwaysShowPassword;
@property (nonatomic) BOOL showPasswordImmediatelyInOutline;

@property (nonatomic) BOOL warnedAboutTouchId;

@property (nonatomic) AutoFillNewRecordSettings *autoFillNewRecordSettings;
@property (nonatomic) BOOL autoSave;

@property BOOL uiDoNotSortKeePassNodesInBrowseView;

@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;

@property BOOL doNotShowTotp;

@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;

@property BOOL floatOnTop;
@property BOOL noAlternatingRows;
@property BOOL showHorizontalGrid;
@property BOOL showVerticalGrid;

@property BOOL doNotShowAutoCompleteSuggestions;
@property BOOL doNotShowChangeNotifications;

@property (readonly) NSString* easyReadFontName;

@property NSArray<NSString*>* visibleColumns;

@property BOOL outlineViewTitleIsReadonly;
@property BOOL outlineViewEditableFieldsAreReadonly;

@property BOOL dereferenceInQuickView;
@property BOOL dereferenceInOutlineView;
@property BOOL dereferenceDuringSearch;

@property BOOL detectForeignChanges;
@property BOOL autoReloadAfterForeignChanges;
@property BOOL concealEmptyProtectedFields;
@property BOOL showCustomFieldsOnQuickViewPanel;

@property PasswordGenerationConfig *passwordGenerationConfig;

@property BOOL autoOpenFirstDatabaseOnEmptyLaunch;

@property BOOL autoPromptForTouchIdOnActivate;
@property BOOL showSystemTrayIcon;

@property FavIconDownloadOptions *favIconDownloadOptions;

@property BOOL expressDownloadFavIconOnNewOrUrlChanged;

@property BOOL allowWatchUnlock;

@property BOOL showAttachmentsOnQuickViewPanel;
@property BOOL showAttachmentImagePreviewsOnQuickViewPanel;

@property BOOL hideKeyFileNameOnLockScreen;
@property BOOL doNotRememberKeyFile;
@property BOOL allowEmptyOrNoPasswordEntry;

@property BOOL hasDoneProFamilyCheck;

@property BOOL colorizePasswords;
@property BOOL colorizeUseColorBlindPalette;

@property BOOL clipboardHandoff;

@property BOOL showAdvancedUnlockOptions;

@end
















