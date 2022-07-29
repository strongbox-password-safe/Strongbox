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
#import "ApplicationPreferences.h"
#import "NotificationConstants.h"

NS_ASSUME_NONNULL_BEGIN

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

@interface Settings : NSObject<ApplicationPreferences>

+ (instancetype)sharedInstance;

@property (readonly) NSString* appGroupName;
@property (readonly) NSUserDefaults* sharedAppGroupDefaults;

+ (NSArray<NSString*> *)kAllColumns;

@property (nonatomic) BOOL fullVersion;


@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;
@property (nonatomic, nullable, readonly) NSDate* endFreeTrialDate;
@property (readonly) BOOL isFreeTrial;



@property (readonly) BOOL isPro;



@property (nonatomic) AutoFillNewRecordSettings *autoFillNewRecordSettings;

@property BOOL floatOnTop;
@property (readonly) NSString* easyReadFontName;
@property PasswordGenerationConfig *trayPasswordGenerationConfig;

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

@property (nonatomic) BOOL autoSave;

@property BOOL hideDockIconOnAllMinimized;
@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;
@property (nonatomic) BOOL revealPasswordsImmediately;

@property (nonatomic) NSInteger autoLockTimeoutSeconds; 

@property BOOL closeManagerOnLaunch;
@property BOOL makeLocalRollingBackups;

@property (nullable) NSDate* lastPromptedToUseNextGenUI;

@property BOOL nextGenUI;
@property BOOL miniaturizeOnCopy;
@property BOOL quickRevealWithOptionKey;
@property BOOL markdownNotes;
@property BOOL showPasswordGenInTray;




@property (nullable) NSData* duressDummyData;
@property BOOL databasesAreAlwaysReadOnly;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property (readonly) BOOL isProOrFreeTrial;
@property PasswordStrengthConfig* passwordStrengthConfig;



@property (readonly) BOOL runningAsATrayApp;

@property BOOL checkPinYin;

@property BOOL addLegacySupplementaryTotpCustomFields;
@property BOOL addOtpAuthUrl;

@property BOOL quitStrongboxOnAllWindowsClosed;

@property BOOL showCopyFieldButton;
@property BOOL lockEvenIfEditing;

@property BOOL screenCaptureBlocked;

@property BOOL hasShownFirstRunWelcome;

@property NSUInteger freeTrialOrUpgradeNudgeCount;
@property NSDate* lastFreeTrialOrUpgradeNudge;




@property (nullable) NSDate* lastEntitlementCheckAttempt;
@property NSUInteger numberOfEntitlementCheckFails;
@property BOOL appHasBeenDowngradedToFreeEdition; 
@property BOOL hasPromptedThatAppHasBeenDowngradedToFreeEdition;
- (void)setPro:(BOOL)value;



@property (nonatomic) NSDate* installDate;
@property (nonatomic, readonly) NSInteger daysInstalled;
@property (readonly) NSUInteger launchCount;
- (void)incrementLaunchCount;



@property BOOL useIsolatedDropbox;
@property BOOL useParentGroupIconOnCreate;

@property BOOL stripUnusedIconsOnSave;

@end


NS_ASSUME_NONNULL_END
