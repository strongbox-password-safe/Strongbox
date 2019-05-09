//
//  Settings.h
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationParameters.h"
#import "AutoFillNewRecordSettings.h"

extern NSString* const kTitleColumn;
extern NSString* const kUsernameColumn;
extern NSString* const kPasswordColumn;
extern NSString* const kTOTPColumn;
extern NSString* const kURLColumn;
extern NSString* const kEmailColumn;
extern NSString* const kNotesColumn;
extern NSString* const kAttachmentsColumn;
extern NSString* const kCustomFieldsColumn;

@interface Settings : NSObject

+ (instancetype)sharedInstance;

+ (NSArray<NSString*> *)kAllColumns;

@property (nonatomic) BOOL revealDetailsImmediately;
@property (nonatomic) BOOL fullVersion;

@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;
@property (nonatomic, strong) NSDate* endFreeTrialDate;
@property (nonatomic) NSInteger autoLockTimeoutSeconds;
@property (nonatomic, strong) PasswordGenerationParameters *passwordGenerationParameters;

@property (nonatomic) BOOL alwaysShowPassword;
@property (nonatomic) BOOL warnedAboutTouchId;

@property (nonatomic) AutoFillNewRecordSettings *autoFillNewRecordSettings;
@property (nonatomic) BOOL autoSave;

@property BOOL uiDoNotSortKeePassNodesInBrowseView;

@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;

@property BOOL doNotShowTotp;

@property BOOL doNotShowRecycleBinInBrowse;
@property BOOL showRecycleBinInSearchResults;

@property BOOL doNotFloatDetailsWindowOnTop;
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

@end

//    [[Settings sharedInstance] setPro:NO];
//    [[Settings sharedInstance] setEndFreeTrialDate:nil];
//    [[Settings sharedInstance] setHavePromptedAboutFreeTrial:NO];
//    [[Settings sharedInstance] resetLaunchCount];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:9 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];


//    [[Settings sharedInstance] setFullVersion:NO];
//[[Settings sharedInstance] setEndFreeTrialDate:nil];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:-10 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];
//
