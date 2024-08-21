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

typedef enum : NSUInteger {
    kSystemMenuClickActionQuickSearch,
    kSystemMenuClickActionShowStrongbox,
    kSystemMenuClickActionPasswordGenerator,
    kSystemMenuClickActionShowMenu,
} SystemMenuClickAction;

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

#ifndef IS_APP_EXTENSION
- (void)factoryReset;
#endif

@property (readonly) NSString* appGroupName;
@property (readonly) NSUserDefaults* sharedAppGroupDefaults;

+ (NSArray<NSString*> *)kAllColumns;

@property (readonly) BOOL isPro;
- (void)setPro:(BOOL)value;

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

@property (nonatomic) BOOL autoSave;

@property BOOL hideDockIconOnAllMinimized;
@property BOOL clearClipboardEnabled;
@property NSInteger clearClipboardAfterSeconds;
@property (nonatomic) BOOL revealPasswordsImmediately;

@property (nonatomic) NSInteger autoLockTimeoutSeconds;
@property (nonatomic) NSInteger autoLockIfInBackgroundTimeoutSeconds;

@property BOOL closeManagerOnLaunch;
@property BOOL makeLocalRollingBackups;

@property BOOL miniaturizeOnCopy;
@property BOOL hideOnCopy;
@property BOOL quickRevealWithOptionKey;
@property BOOL markdownNotes;
@property BOOL showPasswordGenInTray;

@property BOOL hasPromptedForThirdPartyAutoFill;




@property (nullable) NSData* duressDummyData;
@property BOOL databasesAreAlwaysReadOnly;
@property (nonatomic, strong) PasswordGenerationConfig* passwordGenerationConfig;
@property PasswordStrengthConfig* passwordStrengthConfig;



@property (readonly) BOOL configuredAsAMenuBarApp;

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



@property (nonatomic) NSDate* installDate;
@property (nonatomic, readonly) NSInteger daysInstalled;

@property (readonly) NSUInteger launchCount;
- (void)incrementLaunchCount;

@property BOOL useIsolatedDropbox;
@property BOOL useParentGroupIconOnCreate;

@property BOOL stripUnusedIconsOnSave;
@property BOOL stripUnusedHistoricalIcons;

@property BOOL runBrowserAutoFillProxyServer;

@property BOOL quitTerminatesProcessEvenInSystemTrayMode;
@property BOOL lockDatabaseOnWindowClose; 
@property BOOL lockDatabasesOnScreenLock;
@property BOOL showDatabasesManagerOnAppLaunch;

@property BOOL hasAskedAboutDatabaseOpenInBackground;
@property BOOL concealClipboardFromMonitors;

@property BOOL autoCommitScannedTotp;
@property BOOL runSshAgent;


@property (nullable) NSString* businessOrganisationName;

@property (nullable) NSDate* lastQuickTypeMultiDbRegularClear;

@property (nonatomic) NSInteger sshAgentApprovalDefaultExpiryMinutes;

@property BOOL sshAgentRequestDatabaseUnlockAllowed;
@property BOOL sshAgentPreventRapidRepeatedUnlockRequests;

@property BOOL autoFillWroteCleanly;
@property BOOL atomicSftpWrite;

@property BOOL runAsWiFiSyncSourceDevice;
@property (nullable) NSString* wiFiSyncServiceName;

@property (nullable) NSString* lastWiFiSyncPasscodeError;
@property (nullable) NSString* wiFiSyncPasscode; 

@property BOOL disableWiFiSyncClientMode;
@property BOOL disableNetworkBasedFeatures;

@property BOOL cloudKitZoneCreated;
@property BOOL hasWarnedAboutCloudKitUnavailability;
@property BOOL passwordGeneratorFloatOnTop;
@property BOOL largeTextViewFloatOnTop;

@property SystemMenuClickAction systemMenuClickAction;

@property BOOL hardwareKeyCachingBeta;

@property (nullable) NSData* lastKnownGoodBiometricsDatabaseState;
@property (nullable) NSData* autoFillLastKnownGoodBiometricsDatabaseState;

@property BOOL duplicateItemReferencePassword;
@property BOOL duplicateItemReferenceUsername;
@property BOOL duplicateItemPreserveTimestamp;
@property BOOL duplicateItemEditAfterwards;

@end


NS_ASSUME_NONNULL_END
