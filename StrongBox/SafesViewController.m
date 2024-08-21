//
//  SafesViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesViewController.h"
#import "DatabasePreferences.h"
#import "Alerts.h"
#import "SelectStorageProviderController.h"
#import "DatabaseCell.h"
#import "VersionConflictController.h"
#import "SafeStorageProviderFactory.h"
#import "UnlockDatabaseSequenceHelper.h"
#import "SelectDatabaseFormatTableViewController.h"
#import "AddNewSafeHelper.h"
#import "StrongboxUIDocument.h"
#import "SVProgressHUD.h"
#import "AutoFillManager.h"
#import "PinEntryController.h"
#import "CASGTableViewController.h"
#import "PreferencesTableViewController.h"
#import "FontManager.h"
#import "WelcomeAddDatabaseViewController.h"
#import "WelcomeCreateDoneViewController.h"
#import "NSArray+Extensions.h"
#import "StrongboxiOSFilesManager.h"
#import "LocalDeviceStorageProvider.h"
#import "Utils.h"
#import "DatabasesViewPreferencesController.h"
#import "AppLockViewController.h"
#import "iCloudSafesCoordinator.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "BackupsManager.h"
#import "BackupsTableViewController.h"
#import "ProUpgradeIAPManager.h"
#import "BiometricsManager.h"
#import "BookmarksHelper.h"
#import "FreeTrialOnboardingViewController.h"
#import "AppPreferences.h"
#import "SyncManager.h"
#import "SyncStatus.h"
#import "SyncLogViewController.h"
#import "NSDate+Extensions.h"
#import "DebugHelper.h"
#import "UITableView+EmptyDataSet.h"
#import "MergeInitialViewController.h"
#import "Platform.h"
#import "Serializator.h"
#import "DatabaseMerger.h"
#import "DatabasePropertiesVC.h"
#import "SecretStore.h"
#import "WorkingCopyManager.h"
#import <notify.h>
#import "AppDelegate.h"
#import "SaleScheduleManager.h"

#import "StrongboxErrorCodes.h"
#import "RandomizerPopOverViewController.h"
#import "UpgradeViewController.h"

#import "OnboardingManager.h"

#ifndef NO_NETWORKING
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"
#endif

#import "WebDAVConnections.h"
#import "SFTPConnections.h"
#import "WebDAVConnectionsViewController.h"
#import "SFTPConnectionsViewController.h"

#import "StorageBrowserTableViewController.h"
#import "Constants.h"

#import "SFTPProviderData.h"
#import "WebDAVProviderData.h"
#import "ContextMenuHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "Strongbox-Swift.h"
#import "CSVImporter.h"
#import "CSV.h"
#import "NSString+Extensions.h"
#import "SafesList.h"
#import "VirtualYubiKeys.h"
#import "ExportHelper.h"
#import "DatabaseNuker.h"

static NSString* kWifiBrowserResultsUpdatedNotification = @"wifiBrowserResultsUpdated";
static NSString* kDebugLoggerLinesUpdatedNotification = @"debugLoggerLinesUpdated";

@interface SafesViewController () <UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonCustomizeView;

@property (nonatomic, copy) NSArray<DatabasePreferences*> *collection;

@property NSURL* enqueuedImportUrl;
@property BOOL enqueuedImportCanOpenInPlace;

@property BOOL ignoreNextAppActiveNotification;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonDice;
@property BOOL openingDatabaseInProgress;

@property NSString* importFormat;

@property (nullable) NSString* overrideQuickLaunchWithAppShortcutQuickLaunchUuid;

@property NSArray<DebugLine*> *debugLines;

@property (nonatomic, strong) NSDate *unlockedDatabaseWentIntoBackgroundAt;

@property SelectStorageSwiftHelper* selectStorageSwiftHelper;

#ifndef NO_NETWORKING
@property CloudKitSharingUIHelper* cloudKitSharingUIHelper;
#endif

@end

@implementation SafesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.hidden = YES;
    
    [self customizeUI];
    
    [self checkForBrokenVirtualHardwareKeys];
    
    [self migrateAnyInconsistentAFHardwareKeys]; 
    
    
    
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        
        
        
        [self internalRefresh];
        
        self.tableView.hidden = NO;
        
        [self listenToNotifications];
        
        if ( ![self isAppLocked] ) {

            
            [self doAppActivationTasks:NO];
        }
        else {

        }
    });
}

- (void)migrateAnyInconsistentAFHardwareKeys {
    if ( AppPreferences.sharedInstance.hasMigratedInconsistentHardwareKeysForCachingFeature) {
        return;
    }
    
    AppPreferences.sharedInstance.hasMigratedInconsistentHardwareKeysForCachingFeature = YES;

    for ( DatabasePreferences* database in DatabasePreferences.allDatabases ) {
        if ( database.nextGenPrimaryYubiKeyConfig != nil && database.mainAppAndAutoFillYubiKeyConfigsIncoherent ) {
            YubiKeyHardwareConfiguration *conf = database.nextGenPrimaryYubiKeyConfig;
            database.nextGenPrimaryYubiKeyConfig = conf; 
        }
    }
}

- (void)checkForBrokenVirtualHardwareKeys {
    NSMutableSet<NSString*>* broken = NSMutableSet.set;
    
    for ( VirtualYubiKey* key in VirtualYubiKeys.sharedInstance.snapshot ) {
        if ( key.secretIsNoLongerPresent ) {
            slog(@"🔴 Found broken Virtual Hardware Key [%@]", key.identifier);
            [broken addObject:key.identifier];
        }
    }
    
    for ( DatabasePreferences* database in DatabasePreferences.allDatabases ) {
        YubiKeyHardwareConfiguration* yubiConfig = database.nextGenPrimaryYubiKeyConfig;
        
        if ( yubiConfig && yubiConfig.mode == kVirtual && [broken containsObject:yubiConfig.virtualKeyIdentifier] ) {
            slog(@"🔴 Found database using broken Virtual Hardware Key [%@] - fixing", database.nickName);
            database.nextGenPrimaryYubiKeyConfig = nil;
        }
    }
    
    for ( NSString* ident in broken ) {
        slog(@"🔴 Deleting broken Virtual Hardware Key [%@]", ident);
        [VirtualYubiKeys.sharedInstance deleteKey:ident];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    

    
    [self setupTips];
    
    self.navigationController.navigationBar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO];
    
    self.navigationItem.hidesBackButton = YES;
    
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    [self bindToolbar];
    
    [CustomAppIconObjCHelper downgradeProIconIfInUse];
}

- (void)setupTips {
    if( AppPreferences.sharedInstance.hideTips || DatabasePreferences.allDatabases.firstObject == nil ) { 
        self.navigationItem.prompt = nil;
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"hint_tap_and_hold_to_see_options", @"TIP: Tap and hold item to see options");
    }
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self internalRefresh];
    });
}

- (void)internalRefresh {
    
    
    self.debugLines = [DebugLogger.snapshot reverseObjectEnumerator].allObjects;
    
    self.collection = DatabasePreferences.allDatabases;
    
    self.tableView.separatorStyle = AppPreferences.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    
    [self.tableView reloadData];
    
    [self updateDynamicAppIconShortcuts];
    
    [self bindToolbar];
    
    [CustomAppIconObjCHelper downgradeProIconIfInUse];

#ifndef NO_NETWORKING
    [self maybeWarnAboutCloudKitUnavailability];
#endif
}

#ifndef NO_NETWORKING
- (void)maybeWarnAboutCloudKitUnavailability {
    if ( CloudKitDatabasesInteractor.shared.fastIsAvailable ) {
        AppPreferences.sharedInstance.hasWarnedAboutCloudKitUnavailability = NO;
    }
    else {
        BOOL hasCloudKitDbs = [self.collection anyMatch:^BOOL(DatabasePreferences * _Nonnull obj) {
            return obj.storageProvider == kCloudKit;
        }];
        
        if ( hasCloudKitDbs && !AppPreferences.sharedInstance.hasWarnedAboutCloudKitUnavailability && [self isVisibleViewController] ) {
            AppPreferences.sharedInstance.hasWarnedAboutCloudKitUnavailability = YES;
            
            [Alerts info:self
                   title:NSLocalizedString(@"strongbox_sync_unavailable_title", @"Strongbox Sync Unavailable")
                 message:NSLocalizedString(@"strongbox_sync_unavailable_msg", @"Strongbox Sync has become unavailable. Please check you are signed in to your Apple account in System Settings.")
              completion:nil];
        }
    }
}
#endif

- (void)updateDynamicAppIconShortcuts {
    NSMutableArray<UIApplicationShortcutIcon*>* shortcuts = [[NSMutableArray alloc] init];
    
    if ( AppPreferences.sharedInstance.showDatabasesOnAppShortcutMenu ) {
        for ( DatabasePreferences* database in self.collection ) {
            UIMutableApplicationShortcutItem *mutableShortcutItem = [[UIMutableApplicationShortcutItem alloc] initWithType:@"quick-launch"  localizedTitle:database.nickName];
            
            mutableShortcutItem.userInfo = @{ @"uuid" : database.uuid };
            mutableShortcutItem.icon = [UIApplicationShortcutIcon iconWithSystemImageName:@"cylinder.split.1x2"];
            
            [shortcuts addObject:mutableShortcutItem.copy];
        }
    }
    
    
    
    [[UIApplication sharedApplication] setShortcutItems:shortcuts.copy];
}

- (void)performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem {
    slog(@"✅ performActionForShortcutItem: [%@]", shortcutItem.type);
    
    if ( [shortcutItem.type isEqualToString:@"quick-launch"] ) {
        NSString* uuid = (NSString*)shortcutItem.userInfo[@"uuid"];
        
        if ( uuid ) {
            DatabasePreferences* database = [DatabasePreferences fromUuid:uuid];
            if ( database ) {
                slog(@"Quick Launching database from App Shortcut = [%@]", database.nickName);
                self.overrideQuickLaunchWithAppShortcutQuickLaunchUuid = uuid;
            }
        }
    }
    else if ( [shortcutItem.type isEqualToString:@"sync-all"] ) {
        [SyncManager.sharedInstance backgroundSyncAll];
    }
}

- (void)customizeUI {
    [self customizeAddDatabaseButton];
    
    [self.buttonPreferences setAccessibilityLabel:NSLocalizedString(@"generic_settings", @"Settings")];
    [self.buttonCustomizeView setAccessibilityLabel:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View")];
    [self.buttonAddSafe setAccessibilityLabel:NSLocalizedString(@"casg_add_action", @"Add")];

    self.barButtonDice.image = [UIImage systemImageNamed:@"dice"];
    
    self.collection = [NSArray array];
    
    [self setupTableview];
}

- (void)customizeAddDatabaseButton {
    __weak SafesViewController* weakSelf = self;
    
    UIMenuElement* quickStart = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_quick_start", @"Get Started Wizard")
                                               systemImage:@"wand.and.stars"
                                                   handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showFirstDatabaseGetStartedWizard];
    }];
    
    
    
    
    
    
    
    
    UIMenuElement* newAdvancedDatabase = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_new_advanced", @"New Database")
                                                        systemImage:@"plus.circle"
                                                            handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onCreateNewSafe];
    }];
    
    UIMenuElement* addExisting = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_add_existing", @"Add Existing")
                                                systemImage:@"externaldrive.badge.plus"
                                                    handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onAddExistingSafe];

    }];
    
    UIMenuElement* wifiTransfer = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_wifi_transfer", @"Wi-Fi Transfer")
                                                 systemImage:@"network"
                                                     handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToLocalNetworkServer" sender:nil];
    }];

    UIMenuElement* import1P = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_1password_1pif", @"1Password (1Pif)")
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImport1Password];
    }];
    
    UIMenuElement* import1P1Pux = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_1password_1pux", @"1Password (1Pux)")
                                                     handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImport1Password1Pux];
    }];
    
    UIMenuElement* importEnpass = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_enpass_json", @"Enpass (JSON)")
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImportEnpass];
    }];
    UIMenuElement* importBitwarden = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_bitwarden_json", @"Bitwarden (JSON)")
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImportBitwarden];
    }];
    
    UIMenuElement* importLastPass = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_lastpass", @"LastPass (CSV)")
                                                       handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImportLastPass];
    }];
    UIMenuElement* importiCloud = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_icloud", @"Apple/iCloud Keychain (CSV)")
                                                     handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImportiCloud];
    }];
    
    UIMenuElement* importCsv = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_import_csv", @"CSV...")
                                                  handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onImportGenericCsv];
    }];
    
    UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:@[quickStart]];
    
    UIMenu* menu2 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:@[newAdvancedDatabase, addExisting]];
    
    UIMenu* import = [UIMenu menuWithTitle:NSLocalizedString(@"safesvc_import_submenu", @"Import")
                                     image:[UIImage systemImageNamed:@"square.and.arrow.down"]
                                identifier:nil
                                   options:UIMenuOptionsDisplayInline
                                  children:@[import1P1Pux, import1P, importBitwarden, importEnpass, importLastPass, importiCloud, importCsv]];
    
    UIMenu* advanced = [UIMenu menuWithTitle:NSLocalizedString(@"generic_advanced_noun", @"Advanced")
                                     image:[UIImage systemImageNamed:@"gearshape.2.fill"]
                                identifier:nil
                                   options:UIMenuOptionsDisplayInline
                                  children:@[wifiTransfer]];
    
    BOOL showTransferOverLan = !AppPreferences.sharedInstance.disableNetworkBasedFeatures;
    
    UIMenu* more = [UIMenu menuWithTitle:NSLocalizedString(@"safesvc_more_submenu", @"More")
                                   image:[UIImage systemImageNamed:@"ellipsis.circle"]
                              identifier:nil
                                 options:kNilOptions
                                children:!showTransferOverLan ? @[import] : @[import, advanced]];
    
    UIMenu* menu = [UIMenu menuWithTitle:@""
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:@[menu1, menu2, more]];
    
    self.buttonAddSafe.action = nil;
    self.buttonAddSafe.menu = menu;
}

- (void)doAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication {
    [self refreshICloudFolderDatabases];
     
    [SyncManager.sharedInstance backgroundSyncOutstandingUpdates];
    
    
    
    [self startWiFiSyncObservation];

    [self doAppOnboarding:userJustCompletedBiometricAuthentication quickLaunchWhenDone:YES];
}

- (void)refreshICloudFolderDatabases {
    if ( !AppPreferences.sharedInstance.disableNetworkBasedFeatures && iCloudSafesCoordinator.sharedInstance.fastAvailabilityTest ) {

        
        [[iCloudSafesCoordinator sharedInstance] startQuery];
    }
}

- (void)doAppOnboarding:(BOOL)userJustCompletedBiometricAuthentication quickLaunchWhenDone:(BOOL)quickLaunchWhenDone {
    if ( self.enqueuedImportUrl ) {
        if ([self.enqueuedImportUrl.absoluteString.lowercaseString hasPrefix:@"otpauth"]) {
            NSURL* copy = self.enqueuedImportUrl;
            self.enqueuedImportUrl = nil;
            [self handleOtpAuthUrl:copy];
        }
        else {
            if ( ![self isVisibleViewController] ) {
                slog(@"We're not the visible view controller - not doing Onboarding");
                return;
            }

            [self processEnqueuedImport];
        }
    }
    else {
        if ( ![self isVisibleViewController] ) {
            slog(@"We're not the visible view controller - not doing Onboarding");
            return;
        }

        __weak SafesViewController* weakSelf = self;
        [OnboardingManager.sharedInstance startAppOnboarding:self completion:^{
            if ( quickLaunchWhenDone ) {
                [weakSelf openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
            }
        }];
    }
}



- (void)onAppDidEnterBackground { 
    slog(@"SafesViewController::onAppDidEnterBackground");
    
    self.ignoreNextAppActiveNotification = NO;
    self.unlockedDatabaseWentIntoBackgroundAt = [[NSDate alloc] init];
}

- (void)appResignActive {
    slog(@"SafesViewController::appResignActive");
    
    self.ignoreNextAppActiveNotification = NO;
    if( AppPreferences.sharedInstance.suppressAppBackgroundTriggers ) {
        slog(@"SafesViewController::appResignActive... suppressAppBackgroundTriggers so ignoring.");
        self.ignoreNextAppActiveNotification = YES;
        return;
    }

    self.unlockedDatabaseWentIntoBackgroundAt = [[NSDate alloc] init];
}

- (void)appBecameActive {
    slog(@"SafesViewController::appBecameActive");
    
    if( self.ignoreNextAppActiveNotification ) {
        slog(@"SafesViewController::App Active received but ignoring likely due to in progress Biometrics... Nothing to do");
        self.ignoreNextAppActiveNotification = NO;
        return;
    }
    
    
    
    
    BOOL reloadedDueToAutoFillChange = [DatabasePreferences reloadIfChangedByOtherComponent];
    self.collection = DatabasePreferences.allDatabases;
    [self refresh]; 
    
    
    
    if ( [self shouldLockUnlockedDatabase] ) {
        [self lockUnlockedDatabase:^{
            if ( ![self isAppLocked] ) {
                slog(@"SafesViewController::appBecameActive - Just Locked Database - App is not locked - Doing App Activation Tasks.");
                [self doAppActivationTasks:NO];
            }
        }];
    }
    else {
        if ( ![self isAppLocked] ) {
            slog(@"SafesViewController::appBecameActive - App is not locked - Doing App Activation Tasks.");
            [self doAppActivationTasks:NO];
        }
    }
    
    
    
    if ( reloadedDueToAutoFillChange ) {
        [self notifyUnlockedDatabaseAutoFillChangesMade];
    }
}

- (void)startWiFiSyncObservation {
    if ( !StrongboxProductBundle.supportsWiFiSync || AppPreferences.sharedInstance.disableWiFiSyncClientMode ) {
        return;
    }
    
    if ( !AppPreferences.sharedInstance.wiFiSyncHasRequestedNetworkPermissions ) {

        return;
    }
    
    slog(@"SafesViewController::startWiFiSyncObservation...");
    
    [WiFiSyncBrowser.shared startBrowsing:NO
                               completion:^(BOOL success) {
        if ( !success ) {
            slog(@"🔴 Could not start WiFi Browser! error = [%@]", WiFiSyncBrowser.shared.lastError);
        }
        else {
            slog(@"🟢 WiFiBrowser Started");
        }
    }];
}

- (void)notifyUnlockedDatabaseAutoFillChangesMade {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( AppModel.shared.unlockedDatabase ) {
            slog(@"AutoFill Changes were made and unlocked database open, notify to reload");
            [NSNotificationCenter.defaultCenter postNotificationName:kAutoFillChangedConfigNotification object:nil];
        }
        else {
            slog(@"AutoFill Changes were made and no unlocked database open doing a background sync on all");
            [SyncManager.sharedInstance backgroundSyncOutstandingUpdates];
        }
    });
}

- (void)onAppLockScreenWillBeDismissed:(void (^)(void))completion {
    slog(@"SafesViewController::onAppLockWillBeDismissed");

    if ( [self shouldLockUnlockedDatabase] ) {
        [self lockUnlockedDatabase:completion];
    }
    else {
        if ( completion ) {
            completion();
        }
    }
}

- (void)onAppLockScreenWasDismissed:(BOOL)userJustCompletedBiometricAuthentication {
    slog(@"SafesViewController::onAppLockWasDismissed [%hhd]", userJustCompletedBiometricAuthentication);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self doAppActivationTasks:userJustCompletedBiometricAuthentication];
    });
}

- (BOOL)shouldLockUnlockedDatabase {
    Model* model = AppModel.shared.unlockedDatabase;
    
    if ( self.unlockedDatabaseWentIntoBackgroundAt && model ) {
        DatabasePreferences *prefs = model.metadata;
        
        BOOL isEditing = [AppModel.shared isEditing:prefs.uuid];
        BOOL dontLockIfEditing = !prefs.lockEvenIfEditing;
        
        if ( isEditing && dontLockIfEditing ) {
            slog(@"Not locking database because user is currently editing.");
            return NO;
        }
        
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.unlockedDatabaseWentIntoBackgroundAt];
        
        NSNumber *seconds = prefs.autoLockTimeoutSeconds;
        
        slog(@"Autolock Time [%@s] - background Time: [%f].", seconds, secondsBetween);
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) 
        {
            slog(@"Should Lock Database [YES]");
            return YES;
        }
    }
    
    return NO;
}

- (void)protectedDataWillBecomeUnavailable {
    

    [self onDeviceLocked];
}

- (void)onMainSplitViewControllerClosed:(id)param {
    NSNotification* notification = param;
    NSString* databaseId = notification.object;

    slog(@"onMainSplitViewControllerClosed [%@]", databaseId);

    if ( AppModel.shared.unlockedDatabase ) {
        slog(@"onMainSplitViewControllerClosed - Matching unlock db - clearing unlocked state.");

        if ( [AppModel.shared isUnlocked:databaseId] ) {
            [AppModel.shared closeDatabase];
            self.unlockedDatabaseWentIntoBackgroundAt = nil;
        }
        else {
            slog(@"WARNWARN: Received closed but Unlocked Database ID doesn't match!");
        }
    }
    else {
        slog(@"WARNWARN: Received closed but no Unlocked Database state available!");
    }
}

- (void)onDeviceLocked {
    slog(@"onDeviceLocked - Device Lock detected - locking open database if so configured...");
    Model* model = AppModel.shared.unlockedDatabase;

    if ( model && model.metadata.autoLockOnDeviceLock ) {
        DatabasePreferences *prefs = model.metadata;
        
        BOOL isEditing = [AppModel.shared isEditing:prefs.uuid];
        BOOL dontLockIfEditing = !prefs.lockEvenIfEditing;
        
        if ( isEditing && dontLockIfEditing ) {
            slog(@"Not locking database because user is currently editing.");
        }
        else {
            [self lockUnlockedDatabase:nil];
        }
    }
}

- (BOOL)isAppLocked {
    AppDelegate* appDelegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
    
    return appDelegate.isAppLocked;
}

- (void)lockUnlockedDatabase:(void (^ __nullable)(void))completion {
    if ( AppModel.shared.unlockedDatabase ) {
        slog(@"Locking Unlocked Database...");
                
        if ( ![self isAppLocked] ) {
            slog(@"lockUnlockedDatabase: App is not locked... we can lock");
            
            
            
            
            [AppModel.shared markAsEditingWithId:AppModel.shared.unlockedDatabase.databaseUuid editing:NO];

            
            
            UINavigationController* nav = self.navigationController;
            [nav popToRootViewControllerAnimated:NO];
            [self dismissViewControllerAnimated:NO completion:completion];

            [AppModel.shared closeDatabase]; 
            self.unlockedDatabaseWentIntoBackgroundAt = nil;
        }
        else {
            slog(@"lockUnlockedDatabase: Cannot lock unlocked database because App is locked");
            if ( completion ) {
                completion();
            }
        }
    }
    else {
        slog(@"lockUnlockedDatabase: No unlocked database to lock");

        if ( completion ) {
            completion();
        }
    }
}

- (UIViewController*)getVisibleViewController {
    UIViewController* visibleSoFar = self.navigationController;
    int attempts = 10;
    do {
        if ([visibleSoFar isKindOfClass:UINavigationController.class]) {
            UINavigationController* nav = (UINavigationController*)visibleSoFar;
            
             slog(@"VISIBLE: [%@] is Nav Controller, moving to Visisble: [%@]", visibleSoFar, nav.visibleViewController);

            if (nav.visibleViewController) {
                visibleSoFar = nav.visibleViewController;
            }
            else {
                break;
            }
        }
        else {
             slog(@"VISIBLE: [%@] is regular VC checking is it's presenting anything: [%@]", visibleSoFar, visibleSoFar.presentedViewController);

            if (visibleSoFar.presentedViewController) {
                visibleSoFar = visibleSoFar.presentedViewController;
            }
            else {
                break;
            }
        }
    } while (--attempts); 

    slog(@"VISIBLE: [%@]", visibleSoFar);
    
    return visibleSoFar;
}

- (BOOL)isVisibleViewController {
    UIViewController* visible =[self getVisibleViewController];
    BOOL ret = visible == self;


    
    return ret;
}

- (void)listenToNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refresh)
                                               name:kDatabasesListChangedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseUpdated:)
                                               name:kDatabaseUpdatedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appResignActive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onAppDidEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appBecameActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseUpdated:)
                                               name:kSyncManagerDatabaseSyncStatusChangedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(protectedDataWillBecomeUnavailable)
                                               name:UIApplicationProtectedDataWillBecomeUnavailable
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onMainSplitViewControllerClosed:)
                                               name:kMasterDetailViewCloseNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refresh)
                                               name:kWifiBrowserResultsUpdatedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refresh)
                                               name:kDebugLoggerLinesUpdatedNotification
                                             object:nil];
}

- (void)onDatabaseUpdated:(id)param {
    NSNotification* notification = param;
    NSString* databaseId = notification.object;
        
    NSArray<DatabasePreferences*>* newColl = DatabasePreferences.allDatabases;
    
    if (newColl.count != self.collection.count) { 
        [self refresh];
    }
    else {
        self.collection = newColl; 

        NSUInteger index = [self.collection indexOfObjectPassingTest:^BOOL(DatabasePreferences * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.uuid isEqualToString:databaseId];
        }];

        if (index == NSNotFound) {
            slog(@"WARNWARN: Database Update for DB [%@] but DB not found in Collection!", databaseId);
        }
        else {


            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            });
        }
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];

    if(editing) {
        [self removeEditButtonInLeftBar];
        [self insertEditButtonInLeftBar];
    }
    else {
        [self removeEditButtonInLeftBar];
    }
}

- (void)removeEditButtonInLeftBar {
    NSMutableArray* leftBarButtonItems = self.navigationItem.leftBarButtonItems ?  self.navigationItem.leftBarButtonItems.mutableCopy : @[].mutableCopy;
    
    [leftBarButtonItems removeObject:self.editButtonItem];
    
    self.navigationItem.leftBarButtonItems = leftBarButtonItems;
}

- (void)insertEditButtonInLeftBar {
    NSMutableArray* leftBarButtonItems = self.navigationItem.leftBarButtonItems ?  self.navigationItem.leftBarButtonItems.mutableCopy : @[].mutableCopy;

    [leftBarButtonItems insertObject:self.editButtonItem atIndex:0];

    self.navigationItem.leftBarButtonItems = leftBarButtonItems;
}

- (void)setupTableview {
    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
    
    self.tableView.tableFooterView = [UIView new];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    UIRefreshControl* refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(onManualPulldownRefresh) forControlEvents:UIControlEventValueChanged];
    
    self.tableView.refreshControl = refreshControl;
}

- (void)onManualPulldownRefresh {
    [SyncManager.sharedInstance backgroundSyncAll];
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView.refreshControl endRefreshing];
    });
}

- (NSAttributedString*)getEmptyDatasetTitle {
    NSString *text = NSLocalizedString(@"safes_vc_empty_databases_list_tableview_title", @"Title displayed in tableview when there are no databases setup");
    
    NSDictionary *attributes = @{NSFontAttributeName:FontManager.sharedInstance.headlineFont,
                                 NSForegroundColorAttributeName: UIColor.secondaryLabelColor };
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString*)getEmptyDatasetDescription {
    NSString *text = NSLocalizedString(@"safes_vc_empty_databases_list_tableview_subtitle", @"Subtitle displayed in tableview when there are no databases setup");

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{NSFontAttributeName: FontManager.sharedInstance.subheadlineFont,
                                 NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
                                 NSParagraphStyleAttributeName: paragraph};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString*)getEmptyDatasetButtonTitle {
    NSDictionary *attributes = @{
                                    NSFontAttributeName : FontManager.sharedInstance.headlineFont,
                                    NSForegroundColorAttributeName : UIColor.whiteColor,
                                    };
    
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"generic_get_started", @"Get Started") attributes:attributes];
}

#pragma mark - Table view data source

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        slog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        [DatabasePreferences move:sourceIndexPath.row to:destinationIndexPath.row];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
#ifdef DEBUG
    return 2;
#else
    return 1;
#endif
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( section == 0 ) {
        if (self.collection.count == 0) {
            __weak id weakSelf = self;
            [self.tableView setEmptyTitle:[self getEmptyDatasetTitle]
                              description:[self getEmptyDatasetDescription]
                              buttonTitle:[self getEmptyDatasetButtonTitle]
                            bigBlueBounce:YES
                             buttonAction:^{
                [weakSelf showFirstDatabaseGetStartedWizard];
            }];
        }
        else {
            [self.tableView setEmptyTitle:nil];
        }
        
        return self.collection.count;
    }
    else {
        return self.debugLines.count;
    }
}

- (void)showFirstDatabaseGetStartedWizard {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Welcome" bundle:nil];
    UINavigationController* nav = [storyboard instantiateInitialViewController];

    WelcomeAddDatabaseViewController *vc = (WelcomeAddDatabaseViewController*)nav.topViewController;
    
    __weak id weakSelf = self;
    vc.onDone = ^(BOOL addExisting, DatabasePreferences * _Nullable databaseToOpen) {
        [weakSelf dismissViewControllerAnimated:YES completion:^{
            [weakSelf onGetStartedWizardDone:addExisting databaseToOpen:databaseToOpen];
        }];
    };
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)onGetStartedWizardDone:(BOOL)addExisting databaseToOpen:(DatabasePreferences*)databaseToOpen {
    if (addExisting) {
        [self onAddExistingSafe];
    }
    else if(databaseToOpen) {
        [self openDatabase:databaseToOpen];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section == 0 ) {
        DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];
        
        if ( indexPath.row < self.collection.count ) { 
            DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];
            
            [cell populateCell:database];
        }
        
        return cell;
    }
    else {
        DebugLine* line = self.debugLines[indexPath.row];
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"debug-logger-cell-id" forIndexPath:indexPath];
        
        cell.textLabel.text = line.line;
        cell.detailTextLabel.text = line.date.iso8601DateStringWithFractionalSeconds;
        UIImage* image = [UIImage systemImageNamed:@"info.circle"];
        
        cell.imageView.image = image;
        
        if (line.category == DebugLineCategoryError ) {
            cell.imageView.tintColor = UIColor.systemRedColor;
        }
        else if ( line.category == DebugLineCategoryWarn ) {
            cell.imageView.tintColor = UIColor.systemOrangeColor;
        }
        else if ( line.category == DebugLineCategoryInfo ) {
            cell.imageView.tintColor = UIColor.systemGreenColor;
        }
        else if ( line.category == DebugLineCategoryDebug ) {
            cell.imageView.tintColor = UIColor.systemBlueColor;
        }

        return cell;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ( section == 1 ) {
        return @"Debug Log";
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( self.editing || indexPath.section != 0 ) {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    [self openAtIndexPath:indexPath
          explicitOffline:NO
     explicitManualUnlock:NO
           explicitOnline:NO];
}



- (void)explicitRequestManualUnlock:(NSIndexPath*)indexPath {
    [self openAtIndexPath:indexPath
          explicitOffline:NO
     explicitManualUnlock:YES
           explicitOnline:NO];
}

- (void)explicitRequestOpenOffline:(NSIndexPath*)indexPath {
    [self openAtIndexPath:indexPath
          explicitOffline:YES
     explicitManualUnlock:NO
           explicitOnline:NO];
}

- (void)explicitRequestOpenOnline:(NSIndexPath*)indexPath {
    [self openAtIndexPath:indexPath
          explicitOffline:NO
     explicitManualUnlock:NO
           explicitOnline:YES];
}

- (void)openAtIndexPath:(NSIndexPath*)indexPath
        explicitOffline:(BOOL)explicitOffline
   explicitManualUnlock:(BOOL)explicitManualUnlock
         explicitOnline:(BOOL)explicitOnline {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];
    
    [self openDatabase:database
       explicitOffline:explicitOffline
  explicitManualUnlock:explicitManualUnlock
   biometricPreCleared:NO
        explicitOnline:explicitOnline
     explicitEagerSync:NO];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(DatabasePreferences*)database {
    [self openDatabase:database
       explicitOffline:NO
  explicitManualUnlock:NO
   biometricPreCleared:NO
        explicitOnline:NO
     explicitEagerSync:NO];
}

- (void)openDatabase:(DatabasePreferences*)safe
     explicitOffline:(BOOL)explicitOffline
explicitManualUnlock:(BOOL)explicitManualUnlock
 biometricPreCleared:(BOOL)biometricPreCleared
      explicitOnline:(BOOL)explicitOnline
   explicitEagerSync:(BOOL)explicitEagerSync {
    PresentUnlockedDatabaseParams* presentationParams = [[PresentUnlockedDatabaseParams alloc] initWithSuppressInitialLazySync:NO onLoadAdd2FAOtpAuthUrl:nil];

    [self openDatabase:safe 
       explicitOffline:explicitOffline
  explicitManualUnlock:explicitManualUnlock
   biometricPreCleared:biometricPreCleared
        explicitOnline:explicitOnline
     explicitEagerSync:explicitEagerSync
    suppressOnboarding:NO
    presentationParams:presentationParams];
}

- (void)openDatabaseFor2FAAdd:(DatabasePreferences*)safe optAuthUrl:(NSURL*)optAuthUrl {
    PresentUnlockedDatabaseParams* presentationParams = [[PresentUnlockedDatabaseParams alloc] initWithSuppressInitialLazySync:YES onLoadAdd2FAOtpAuthUrl:optAuthUrl];

    [self openDatabase:safe 
       explicitOffline:false
  explicitManualUnlock:false 
   biometricPreCleared:false
        explicitOnline:false
     explicitEagerSync:YES
    suppressOnboarding:YES
    presentationParams:presentationParams];
}

- (void)openDatabase:(DatabasePreferences*)safe
     explicitOffline:(BOOL)explicitOffline
explicitManualUnlock:(BOOL)explicitManualUnlock
 biometricPreCleared:(BOOL)biometricPreCleared
      explicitOnline:(BOOL)explicitOnline
   explicitEagerSync:(BOOL)explicitEagerSync 
  suppressOnboarding:(BOOL)suppressOnboarding
  presentationParams:(PresentUnlockedDatabaseParams*)presentationParams {
    slog(@"======================== OPEN DATABASE: %@ [EON: %hhd, EOFF: %hhd, MAN: %hhd, BPC: %hhd] ============================",
          safe.nickName, explicitOnline, explicitOffline, explicitManualUnlock, biometricPreCleared);
        
    biometricPreCleared = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics && biometricPreCleared;
    
    if(safe.hasUnresolvedConflicts) { 
        [self performSegueWithIdentifier:@"segueToVersionConflictResolution" sender:safe.fileIdentifier];
    }
    else {
        if ( self.openingDatabaseInProgress ) {
            slog(@"Another Database is in the process of being opened. Will not open this one.");
            return;
        }
        self.openingDatabaseInProgress = YES;
        
        UnlockDatabaseSequenceHelper* helper = [UnlockDatabaseSequenceHelper helperWithViewController:self
                                                                                             database:safe
                                                                                       isAutoFillOpen:NO
                                                                                      explicitOffline:explicitOffline
                                                                                       explicitOnline:explicitOnline];

        [helper beginUnlockSequence:NO
                biometricPreCleared:biometricPreCleared
               explicitManualUnlock:explicitManualUnlock
                  explicitEagerSync:explicitEagerSync
                         completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
            self.openingDatabaseInProgress = NO;
            
            if (result == kUnlockDatabaseResultSuccess) {
                [self showUnlockedDatabase:model suppressOnboarding:suppressOnboarding presentationParams:presentationParams];
            }
            else if (result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
                [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
            }
            else if (result == kUnlockDatabaseResultIncorrectCredentials) {
                
                slog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
            }
            else if (result == kUnlockDatabaseResultError) {
                [Alerts error:self
                        title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                        error:error
                   completion:^{
                    if ( error.code == kStorageProviderSFTPorWebDAVSecretMissingErrorCode ) {
                        [self editConnection:safe];
                    }
                }];
            }
        }];
    }
}

- (void)showUnlockedDatabase:(Model*)model suppressOnboarding:(BOOL)suppressOnboarding presentationParams:(PresentUnlockedDatabaseParams*)presentationParams {
    if ( !suppressOnboarding ) {
        [OnboardingManager.sharedInstance startDatabaseOnboarding:self model:model completion:^{
            [self presentUnlockedDatabase:model presentationParams:presentationParams];
        }];
    }
    else {
        [self presentUnlockedDatabase:model presentationParams:presentationParams];
    }
}

- (void)presentUnlockedDatabase:(Model*)model presentationParams:(PresentUnlockedDatabaseParams*)presentationParams {
    [AppModel.shared unlockDatabase:model];
    
    MainSplitViewController *svc = MainSplitViewController.fromStoryboard;
    svc.model = model;
    svc.presentationParams = presentationParams;
    
    svc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:svc animated:YES completion:nil];
}





- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if ( indexPath.section != 0 ) {
        return nil;
    }
    
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        NSMutableArray *array = [NSMutableArray arrayWithArray:@[
            [self getContextualMenuDatabaseNonMutatatingActions:indexPath],
            [self getContextualMenuDatabaseActions:indexPath],
            [self getContextualMenuDatabaseStateActions:indexPath],
        ]];

        DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

        if ( safe.storageProvider == kWebDAV || safe.storageProvider == kSFTP ) {
            UIMenu* m = [UIMenu menuWithTitle:@""
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:@[[self getContextualMenuEditConnectionAction:indexPath],
                                                [self getContextualMenuEditFilePathAction:indexPath]]];

            [array insertObject:m atIndex:2];
        }
        
        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:kNilOptions
                            children:array];
    }];
}

- (UIAction*)getContextualViewBackupsAction:(NSIndexPath*)indexPath   {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_action_backups", @"Button Title to view backup settings of this database")
                                    systemImage:@"clock" 
                                    
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToBackups" sender:safe];
    }];

    return ret;
}

- (UIAction*)getContextualViewSyncLogAction:(NSIndexPath*)indexPath  {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_action_view_sync_status", @"Button Title to view sync log for this database")
                                    systemImage:@"arrow.clockwise.icloud" 
                                    
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
    }];

    return ret;
}

- (UIMenu*)getContextualMenuDatabaseNonMutatatingActions:(NSIndexPath*)indexPath  {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];

    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    BOOL conveniencePossible = safe.isConvenienceUnlockEnabled && safe.conveniencePasswordHasBeenStored && AppPreferences.sharedInstance.isPro;
    if (conveniencePossible) {
        [ma addObject:[self getContextualMenuUnlockManualAction:indexPath]];
    }

    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid];

    
    
    if ( safe.forceOpenOffline ) {
        if (safe.storageProvider != kLocalDevice) {
            [ma addObject:[self getContextualMenuOpenOnlineAction:indexPath]];
        }
    }
    else if ( !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        BOOL localCopyAvailable = safe.storageProvider != kLocalDevice && localCopyUrl != nil && !safe.forceOpenOffline;
     
        if (localCopyAvailable) {
            [ma addObject:[self getContextualMenuOpenOfflineAction:indexPath]];
        }
    }
    
    
    
    BOOL exportAllowed = !AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu && localCopyUrl != nil && !AppPreferences.sharedInstance.disableExport;
    if (exportAllowed) {
        [ma addObject:[self getContextualExportAction:indexPath]];
    }
    
    if (self.collection.count > 1) {
        [ma addObject:[self getContextualReOrderDatabasesAction:indexPath]];
    }
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualReOrderDatabasesAction:(NSIndexPath*)indexPath   {
    UIAction* ret = [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_action_reorder_database", @"Button Title to reorder this database")
                                    systemImage:@"arrow.up.arrow.down"
                                    
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self setEditing:YES];
    }];

    return ret;
}

- (UIMenu*)getContextualMenuDatabaseStateActions:(NSIndexPath*)indexPath  {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    BOOL makeVisible = safe.storageProvider == kLocalDevice;
    
    if (makeVisible) {
        BOOL shared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safe];

        if ( !AppPreferences.sharedInstance.disableMakeVisibleInFiles || !shared ) {
            [ma addObject:[self getContextualMenuMakeVisibleAction:indexPath]];
        }
    }

    [ma addObject:[self getContextualMenuQuickLaunchAction:indexPath]];
    
    if ( safe.autoFillEnabled ) {
        [ma addObject:[self getContextualMenuAutoFillQuickLaunchAction:indexPath]];
    }
    
    if ( !AppPreferences.sharedInstance.databasesAreAlwaysReadOnly ) {
        [ma addObject:[self getContextualMenuReadOnlyAction:indexPath]];
    }
    
    [ma addObject:[self getContextualMenuPropertiesAction:indexPath]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIMenu*)getContextualMenuDatabaseActions:(NSIndexPath*)indexPath {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    DatabasePreferences *safe = self.collection[indexPath.row];
    
    if ( safe.storageProvider == kCloudKit ) {
        [ma addObject:[self getContextualMenuCloudKitShareAction:indexPath]];
    }
    
    [ma addObject:[self getContextualMenuRenameAction:indexPath]];
    
    if ( !AppPreferences.sharedInstance.disableCopyTo ) {
        [ma addObject:[self getContextualMenuCopyToStorageAction:indexPath]];
    }

    if (self.collection.count > 1) {
        [ma addObject:[self getContextualMenuMergeAction:indexPath]];
    }
    
    [ma addObject:[self getContextualMenuRemoveAction:indexPath]];
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualExportAction:(NSIndexPath*)indexPath  {
    UIAction* ret = [ContextMenuHelper getItem:NSLocalizedString(@"generic_export", @"Export")
                                    systemImage:@"square.and.arrow.up"
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self onExport:indexPath];
    }];

    return ret;
}

- (UIAction*)getContextualMenuMakeVisibleAction:(NSIndexPath*)indexPath {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    BOOL shared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safe];
    
    NSString* title = !shared ?
        NSLocalizedString(@"safes_vc_show_in_files", @"Visible in Files app") :
        NSLocalizedString(@"safes_vc_make_autofillable", @"Hidden from Files app");

    UIAction* ret = [ContextMenuHelper getItem:title
                                       checked:!shared
                                   systemImage:@"folder" 
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self promptAboutToggleLocalStorage:indexPath shared:shared];
    }];
   
    return ret;
}

- (UIAction*)getContextualMenuQuickLaunchAction:(NSIndexPath*)indexPath {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL isAlreadyQuickLaunch = [AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid];
    
    NSString* title = NSLocalizedString(@"databases_toggle_quick_launch_context_menu", @"Quick Launch");
    
    UIAction* ret = [ContextMenuHelper getItem:title
                                 image:[UIImage imageNamed:@"rocket"]
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self toggleQuickLaunch:safe];
    }];
   
    ret.state = isAlreadyQuickLaunch ? UIMenuElementStateOn : UIMenuElementStateOff;
   
    return ret;
}

- (UIAction*)getContextualMenuAutoFillQuickLaunchAction:(NSIndexPath*)indexPath {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL isAlreadyQuickLaunch = [AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:safe.uuid];
    
    NSString* title = NSLocalizedString(@"databases_toggle_autofill_quick_launch_context_menu", @"AutoFill Quick Launch");
    
    UIAction* ret = [ContextMenuHelper getItem:title
                                 image:[UIImage imageNamed:@"globe"]
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self toggleAutoFillQuickLaunch:safe];
    }];
   
    ret.state = isAlreadyQuickLaunch ? UIMenuElementStateOn : UIMenuElementStateOff;
   
    return ret;
}

- (UIAction*)getContextualMenuPropertiesAction:(NSIndexPath*)indexPath  {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString* title = NSLocalizedString(@"browse_vc_action_properties", @"Properties");
    
    UIAction* ret = [ContextMenuHelper getItem:title
                                 image:[UIImage systemImageNamed:@"list.bullet"]
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self showDatabaseProperties:safe];
    }];
       
    return ret;
}

- (UIAction*)getContextualMenuReadOnlyAction:(NSIndexPath*)indexPath  {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString* title = NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read Only");
    
    UIAction* ret = [ContextMenuHelper getItem:title
                                 image:[UIImage systemImageNamed:@"eyeglasses"]
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self toggleReadOnly:safe];
    }];
    
    ret.state = safe.readOnly ? UIMenuElementStateOn : UIMenuElementStateOff;
   
    return ret;
}

- (UIAction*)getContextualMenuUnlockManualAction:(NSIndexPath*)indexPath  {
    return [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_unlock_manual_action", @"Open ths database manually bypassing any convenience unlock")
                           systemImage:@"lock.open"
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self explicitRequestManualUnlock:indexPath];
    }];
}

- (UIAction*)getContextualMenuOpenOfflineAction:(NSIndexPath*)indexPath  {
    return [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_slide_left_open_offline_action", @"Open ths database offline table action")
                           systemImage:@"bolt.horizontal.circle"
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self explicitRequestOpenOffline:indexPath];
    }];
}

- (UIAction*)getContextualMenuOpenOnlineAction:(NSIndexPath*)indexPath  {
    return [ContextMenuHelper getItem:NSLocalizedString(@"safes_vc_slide_left_open_online_action", @"Open this database online action")
                           systemImage:@"bolt.horizontal.circle"
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self explicitRequestOpenOnline:indexPath];
    }];
}

- (UIAction*)getContextualMenuRenameAction:(NSIndexPath*)indexPath  {
    return [ContextMenuHelper getItem:NSLocalizedString(@"generic_rename", @"Rename")
                           systemImage:@"pencil"
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self renameSafe:indexPath];
    }];
}
    
- (UIAction*)getContextualMenuMergeAction:(NSIndexPath*)indexPath  {
    UIImage* img = [UIImage systemImageNamed:@"arrow.triangle.merge"];

    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    return [ContextMenuHelper getItem:NSLocalizedString(@"generic_action_compare_and_merge_ellipsis", @"Compare & Merge...")
                                 image:img
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self beginMergeWizard:safe];
    }];
}

- (UIAction*)getContextualMenuEditConnectionAction:(NSIndexPath*)indexPath  {
    UIImage* img = [UIImage systemImageNamed:@"externaldrive.connected.to.line.below"];

    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    NSString* foo = safe.storageProvider == kSFTP ? NSLocalizedString(@"generic_action_edit_sftp_connection_ellipsis", @"SFTP Connection...") : NSLocalizedString(@"generic_action_edit_webdav_connection_ellipsis", @"WebDAV Connection...");
    
    return [ContextMenuHelper getItem:foo
                                 image:img
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self editConnection:safe];
    }];
}

- (UIAction*)getContextualMenuEditFilePathAction:(NSIndexPath*)indexPath  {
    UIImage* img = [UIImage systemImageNamed:@"location"];

    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    NSString* foo = safe.storageProvider == kSFTP ? NSLocalizedString(@"reselect_sftp_file_ellipsis", @"Reselect SFTP File...") : NSLocalizedString(@"reselect_webdav_file_ellipsis", @"Reselect WebDAV File...");
    
    return [ContextMenuHelper getItem:foo
                                 image:img
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self editFilePath:safe];
    }];
}

- (UIAction*)getContextualMenuCopyToStorageAction:(NSIndexPath*)indexPath  {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];

    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];

    return [ContextMenuHelper getItem:NSLocalizedString(@"database_option_copy_to_ellipsis", @"Copy To...")
                          systemImage:@"arrow.triangle.branch" 
                              enabled:url != nil  
                              handler:^(__kindof UIAction * _Nonnull action) {
        [self onCopyToNewStorageLocation:database];
    }];
}

- (UIAction*)getContextualMenuRemoveAction:(NSIndexPath*)indexPath  {
    return [ContextMenuHelper getDestructiveItem:NSLocalizedString(@"generic_remove", @"Remove")
                                     systemImage:@"trash"
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self onRemoveDatabase:indexPath];
    }];
}

- (UIAction*)getContextualMenuCloudKitShareAction:(NSIndexPath*)indexPath {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];

    return [ContextMenuHelper getItem:database.isSharedInCloudKit ?
            NSLocalizedString(@"generic_manage_sharing_action_ellipsis", @"Manage Sharing...") :
            NSLocalizedString(@"generic_share_action_ellipsis", @"Share...")
                          systemImage:@"person.3"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [self onCloudKitShare:indexPath];
    }];
}



- (void)onExport:(NSIndexPath*)indexPath {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];
    
    NSError* error;
    NSURL* url = [ExportHelper getExportFile:database error:&error];
    if ( !url || error ) {
        [Alerts error:self error:error];
        return;
    }

    NSArray *activityItems = @[url];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    

    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
    activityViewController.popoverPresentationController.sourceView = self.tableView;
    activityViewController.popoverPresentationController.sourceRect = rect;
    activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [ExportHelper cleanupExportFiles:url];
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction* removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"safes_vc_slide_left_remove_database_action", @"Remove this database table action") 
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onRemoveDatabase:indexPath];
    }];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[removeAction]];
}

- (void)toggleAutoFillQuickLaunch:(DatabasePreferences*)database {
    if([AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = nil;
        [self refresh];
    }
    else {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = database.uuid;
        [self refresh];
    }
}

- (void)toggleQuickLaunch:(DatabasePreferences*)database {
    if([AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.quickLaunchUuid = nil;
        [self refresh];
    }
    else {
        [Alerts yesNo:self
                title:NSLocalizedString(@"safes_vc_about_quick_launch_title", @"Title of Prompt about setting Quick Launch")
              message:NSLocalizedString(@"safes_vc_about_setting_quick_launch_and_confirm", @"Message about quick launch feature and asking to confirm yes or no")
               action:^(BOOL response) {
            if (response) {
                AppPreferences.sharedInstance.quickLaunchUuid = database.uuid;
                [self refresh];
            }
        }];
    }
}

- (void)toggleReadOnly:(DatabasePreferences*)database {
    database.readOnly = !database.readOnly;
}

- (void)promptAboutToggleLocalStorage:(NSIndexPath*)indexPath shared:(BOOL)shared {
    NSString* message = shared ?
        NSLocalizedString(@"safes_vc_show_database_in_files_info", @"Button title to Show Database in iOS Files App") :
        NSLocalizedString(@"safes_vc_make_database_auto_fill_info", @"Button title to Hide Database from the iOS Files App");
    
    [Alerts okCancel:self
               title:NSLocalizedString(@"safes_vc_change_local_device_storage_mode_title", @"OK/Cancel prompt title for changing local storage mode")
             message:message
              action:^(BOOL response) {
                  if (response) {
                      [self toggleLocalSharedStorage:indexPath];
                  }
              }];
}

- (void)toggleLocalSharedStorage:(NSIndexPath*)indexPath {
    DatabasePreferences* metadata = [self.collection objectAtIndex:indexPath.row];

    NSError* error;
    if (![SyncManager.sharedInstance toggleLocalDatabaseFilesVisibility:metadata error:&error]) {
        [Alerts error:self title:NSLocalizedString(@"safes_vc_could_not_change_storage_location_error", @"error message could not change local storage") error:error];
    }
}

- (void)renameSafe:(NSIndexPath * _Nonnull)indexPath {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"segueToRenameDatabase" sender:database];
}

- (void)onRemoveDatabase:(NSIndexPath * _Nonnull)indexPath {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];
    
    NSString *message;
    
    if ( database.storageProvider == kCloudKit && !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        if ( database.isOwnedByMeCloudKit ) {
            message = NSLocalizedString(@"ays_remove_database_permanent_all_devices_delete_please_take_backup", @"Are you sure you want to remove this database? It will be permanently deleted across all devices.\n\nPlease consider taking a backup local copy first.");
        }
        else {
            [self promptUserToRemoveThemselvesFromCloudKitSharing:database indexPath:indexPath];
            return;
        }
    }
    else {
        if (database.storageProvider == kiCloud ||
            database.storageProvider == kCloudKit ||
            database.storageProvider == kLocalDevice) {
            message = NSLocalizedString(@"ays_remove_database_permanent_delete", @"Are you sure you want to remove this database from Strongbox?\n\n(NB: The underlying database file will be permanently deleted)");
        }
        else {
            message = NSLocalizedString(@"ays_remove_database_underlying_not_deleted", @"Are you sure you want to remove this database from Strongbox? (NB: The underlying database file will not be deleted)");
        }
    }
    
    [Alerts yesNo:self
            title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure? Title")
          message:message
           action:^(BOOL response) {
               if (response) {
                   [self removeAndCleanupSafe:database];
               }
           }];
}

- (void)promptUserToRemoveThemselvesFromCloudKitSharing:(DatabasePreferences*)database indexPath:(NSIndexPath*)indexPath {
    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    [Alerts okCancel:self
               title:NSLocalizedString(@"strongbox_sync_shared_database_title", @"Shared Database")
             message:NSLocalizedString(@"strongbox_sync_shared_database_msg", @"This database is shared with you by someone else who owns it. To remove this database from your list, tap OK to manage sharing and remove yourself.")
              action:^(BOOL response) {
        if ( response ) {
            [self onCloudKitCreateOrManageSharing:database rect:rect];
        }
    }];
}

- (void)removeAndCleanupSafe:(DatabasePreferences *)safe {
    BOOL requiresTripleCheck = safe.storageProvider == kCloudKit;
    
    if ( requiresTripleCheck ) {
        NSString* codeword = NSLocalizedString(@"delete_triple_confirm_code_word", @"delete");
        NSString* locFmt = [NSString stringWithFormat:NSLocalizedString(@"delete_triple_confirm_message_fmt", @"Please enter the word '%@' below to confirm."), codeword];
        
        [Alerts OkCancelWithTextField:self
                        textFieldText:@""
                                title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
                              message:locFmt
                           completion:^(NSString *confirm, BOOL response) {
            if ( response && confirm != nil && [confirm localizedCaseInsensitiveCompare:codeword] == NSOrderedSame ) {
                [self removeAndCleanupSafeConfirmed:safe];
            }
        }];
    }
    else {
        [self removeAndCleanupSafeConfirmed:safe];
    }
}

- (void)removeAndCleanupSafeConfirmed:(DatabasePreferences*)safe {
    [CrossPlatformDependencies.defaults.spinnerUi show:NSLocalizedString(@"generic_deleting_ellipsis", @"Deleting...")
                                        viewController:self];
    
    [DatabaseNuker nuke:safe 
     deleteUnderlyingIfSupported:YES
             completion:^(NSError * _Nullable error) {
        [CrossPlatformDependencies.defaults.spinnerUi dismiss];

        if ( error ) {
            [Alerts error:self error:error];
        }
    }];
}



- (void)renameDatabase:(DatabasePreferences*)database name:(NSString*)name renameFile:(BOOL)renameFile {
    database.nickName = name;
    
    if ( renameFile && database.storageProvider == kLocalDevice ) {
        NSError* error;
        if ( ![LocalDeviceStorageProvider.sharedInstance renameFilename:database filename:name error:&error] ) {
            slog(@"🔴 Error Renaming... [%@]", error);
            
            if ( error ) {
                [Alerts error:self error:error];
            }
        }
    }
    else if ( database.storageProvider == kCloudKit ) {
        NSString* fileName = renameFile ? [name stringByAppendingPathExtension:database.fileName.pathExtension] : nil;

        [self renameCloudKitDatabase:database nick:name fileName:fileName];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ( [segue.identifier isEqualToString:@"segueToStorageType"] ) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SelectStorageProviderController *vc = (SelectStorageProviderController*)nav.topViewController;
        
        NSString *newOrExisting = (NSString *)sender;
        BOOL existing = [newOrExisting isEqualToString:@"Existing"];
        vc.existing = existing;
        
        vc.onDone = ^(SelectedStorageParameters *params) {
            dispatch_async(dispatch_get_main_queue(), ^{
                params.createMode = !existing;
                [self onSelectedStorageLocation:params];
            });
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToVersionConflictResolution"]) {
        VersionConflictController* vc = (VersionConflictController*)segue.destinationViewController;
        vc.url = (NSString*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueFromSafesToPreferences"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        PreferencesTableViewController* vc = (PreferencesTableViewController*)nav.topViewController;
        
        vc.onDone = ^{
            [self dismissViewControllerAnimated:YES completion:^{
                [self doAppOnboarding:NO quickLaunchWhenDone:NO]; 
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToRenameDatabase"]) {
        DatabasePreferences* database = (DatabasePreferences*)sender;
        
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        scVc.mode = kCASGModeRenameDatabase;
        scVc.initialName = database.nickName;
        
        BOOL allowFileRename = database.storageProvider == kLocalDevice || database.storageProvider == kCloudKit;
        scVc.showFileRenameOption = allowFileRename;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [self renameDatabase:database name:creds.name renameFile:creds.renameFileToMatch && allowFileRename];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToCreateDatabase"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        
        SelectedStorageParameters* params = (SelectedStorageParameters*)sender;
        BOOL expressMode = params == nil;
        BOOL createMode = params == nil || params.createMode;
        
        scVc.mode = createMode ? (expressMode ? kCASGModeCreateExpress : kCASGModeCreate) : kCASGModeAddExisting;
        scVc.initialFormat = kDefaultFormat;
        
        if(params) {
            if(params.method == kStorageMethodNativeStorageProvider && params.file.name.length) {
                scVc.initialName = params.file.name.stringByDeletingPathExtension;
            }
        }
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [self onCreateOrAddDialogDismissedSuccessfully:params credentials:creds];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueFromInitialToAddDatabase"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        scVc.mode = kCASGModeAddExisting;
        
        NSDictionary<NSString*, id> *params = (NSDictionary<NSString*, id> *)sender;
        NSURL* url = params[@"url"];
        NSData* data = params[@"data"];
        NSNumber* numEIP = params[@"editInPlace"];
        NSDate* modDate = params[@"modDate"];
        
        BOOL editInPlace = numEIP.boolValue;
        
        if(url && url.lastPathComponent.length) {
            NSString* suggestion = url.lastPathComponent.stringByDeletingPathExtension;
            scVc.initialName = [DatabasePreferences getUniqueNameFromSuggestedName:suggestion];
        }
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    if(editInPlace) {
                        [self addExternalFileReferenceSafe:creds.name data:data url:url dateModified:modDate];
                    }
                    else {
                        [self copyAndAddImportedSafe:creds.name data:data url:url modDate:modDate];
                    }
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToCreateExpressDone"]) {
        WelcomeCreateDoneViewController* wcdvc = (WelcomeCreateDoneViewController*)segue.destinationViewController;
        
        NSDictionary *d = sender; 
        
        wcdvc.database = d[@"database"];
        wcdvc.password = d[@"password"];
        
        wcdvc.onDone = ^(BOOL addExisting, DatabasePreferences * _Nullable databaseToOpen) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(databaseToOpen) {
                     [self openDatabase:databaseToOpen];
                }
            }];
        };
    }
    else if([segue.identifier isEqualToString:@"segueToDatabasesViewPreferences"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        DatabasesViewPreferencesController* vc = (DatabasesViewPreferencesController*)nav.topViewController;
        
        vc.onPreferencesChanged = ^{
            [self internalRefresh];
            
            [self.tableView beginUpdates];
            [self.tableView endUpdates];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToBackups"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        BackupsTableViewController* vc = (BackupsTableViewController*)nav.topViewController;
        vc.metadata = (DatabasePreferences*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToSyncLog"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SyncLogViewController* vc = (SyncLogViewController*)nav.topViewController;
        vc.database = (DatabasePreferences*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToUpgrade"]) {
        UIViewController* vc = segue.destinationViewController;

        if ( AppPreferences.sharedInstance.daysInstalled > 90 )  {
            vc.modalPresentationStyle = UIModalPresentationFullScreen;
            vc.modalInPresentation = YES;
        }
    }
    else if ( [segue.identifier isEqualToString:@"segueToMergeWizard"] ) {
        DatabasePreferences* dest = (DatabasePreferences*)sender;
        UINavigationController* nav = segue.destinationViewController;
        MergeInitialViewController* vc = (MergeInitialViewController*)nav.topViewController;
        vc.firstMetadata = dest;
        vc.onDone = ^(BOOL mergeRequested, Model * _Nullable first, Model * _Nullable second) {
            [self dismissViewControllerAnimated:YES completion:^{
                if ( mergeRequested ) {
                    [self mergeDatabases:first second:second];
                }
            }];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToDatabaseProperties"] ) {
        DatabasePreferences* database = (DatabasePreferences*)sender;
        UINavigationController* nav = segue.destinationViewController;
        DatabasePropertiesVC* vc = (DatabasePropertiesVC*)nav.topViewController;
        vc.databaseUuid = database.uuid;
    }
}

- (void)mergeDatabases:(Model*)first second:(Model*)second {
    NSString* msg = NSLocalizedString(@"merge_view_are_you_sure", @"Are you sure you want to merge the second database into the first?");
    [Alerts areYouSure:self message:msg action:^(BOOL response) {
        if (response) {
            DatabaseMerger* merger = [DatabaseMerger mergerFor:first.database theirs:second.database];
            BOOL success = [merger merge];

            if (success) {
                [first asyncUpdate:^(AsyncJobResult * _Nonnull result) {
                    if (result.error) {
                        [Alerts error:self error:result.error];
                    }
                    else if (result.userCancelled) {
                        [Alerts error:self
                                title:NSLocalizedString(@"merge_view_merge_title_error", @"There was an problem merging this database.")
                                error:nil];
                    }
                    else {
                        [Alerts info:self
                               title:NSLocalizedString(@"merge_view_merge_title_success", @"Merge Successful")
                             message:NSLocalizedString(@"merge_view_merge_message_success", @"The Merge was successful and your database is now up to date.")];
                                                
                        [first asyncSync]; 
                    }
                }];
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"merge_view_merge_title_error", @"There was an problem merging this database.")
                        error:nil];
            }
        }
    }];
}

- (void)onCreateOrAddDialogDismissedSuccessfully:(SelectedStorageParameters*)storageParams
                                     credentials:(CASGParams*)credentials {
    BOOL expressMode = storageParams == nil;
    
    if(expressMode || storageParams.createMode) {
        if(expressMode) {
            [self onCreateNewExpressDatabase:credentials.name
                                        password:credentials.password
                                      forceLocal:NO];
        }
        else {
            [self onCreateNewDatabase:storageParams
                                 name:credentials.name
                             password:credentials.password
                      keyFileBookmark:credentials.keyFileBookmark
                      keyFileFileName:credentials.keyFileFileName
                       onceOffKeyFile:credentials.oneTimeKeyFileData
                        yubiKeyConfig:credentials.yubiKeyConfig
                               format:credentials.format];
        }
    }
    else {
        [self onAddExistingDatabaseUiDone:storageParams name:credentials.name];
    }
}

- (void)onSelectedStorageLocation:(SelectedStorageParameters*)params {
    slog(@"onSelectedStorageLocation: [%@] - [%@]", params.createMode ? @"Create" : @"Add", params);
    
    if(params.method == kStorageMethodUserCancelled) {
        slog(@"onSelectedStorageLocation: User Cancelled");
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else if (params.method == kStorageMethodErrorOccurred) {
        [self dismissViewControllerAnimated:YES completion:^{
            [Alerts error:self title:NSLocalizedString(@"safes_vc_error_selecting_storage_location", @"Error title - error selecting storage location") error:params.error];
        }];
    }
    else if (params.method == kStorageMethodFilesAppUrl) {
        [self dismissViewControllerAnimated:YES completion:^{
            slog(@"Files App: [%@] - Create: %d", params.url, params.createMode);

            if (params.createMode) {
                [self performSegueWithIdentifier:@"segueToCreateDatabase" sender:params];
            }
            else {
                
                [self import:params.url canOpenInPlace:!params.filesAppMakeALocalCopy forceOpenInPlace:!params.filesAppMakeALocalCopy];
            }
        }];
    }
    else if (params.method == kStorageMethodManualUrlDownloadedData || params.method == kStorageMethodNativeStorageProvider) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self performSegueWithIdentifier:@"segueToCreateDatabase" sender:params];
        }];
    }
}

- (void)onAddExistingDatabaseUiDone:(SelectedStorageParameters*)storageParams
                               name:(NSString*)name {
    if(storageParams.method == kStorageMethodManualUrlDownloadedData) {
        
        [self addManuallyDownloadedUrlDatabase:name modDate:NSDate.date data:storageParams.data];
    }
    else { 
        DatabasePreferences* database = [storageParams.provider getDatabasePreferences:name providerData:storageParams.file.providerData];
        database.likelyFormat = storageParams.likelyFormat;
        
        if(database == nil) {
            [Alerts warn:self
                   title:NSLocalizedString(@"safes_vc_error_adding_database", @"Error title: error adding database")
                 message:NSLocalizedString(@"safes_vc_unknown_error_while_adding_database", @"Error Message- unknown error while adding")];
        }
        else {
            NSError* error;
            if ( ![database add:storageParams.data initialCacheModDate:storageParams.initialDateModified error:&error] ) {
                [Alerts error:self error:error];
            }
        }
    }
}

- (void)onCreateNewDatabase:(SelectedStorageParameters*)storageParams
                       name:(NSString*)name
                   password:(NSString*)password
            keyFileBookmark:(NSString*)keyFileBookmark
            keyFileFileName:(NSString*)keyFileFileName
             onceOffKeyFile:(NSData*)onceOffKeyFile
              yubiKeyConfig:(YubiKeyHardwareConfiguration*)yubiKeyConfig
                     format:(DatabaseFormat)format {
    [AddNewSafeHelper createNewDatabase:self
                                   name:name
                               password:password
                        keyFileBookmark:keyFileBookmark
                        keyFileFileName:keyFileFileName
                     onceOffKeyFileData:onceOffKeyFile
                          yubiKeyConfig:yubiKeyConfig
                          storageParams:storageParams
                                 format:format
                             completion:^(BOOL userCancelled, DatabasePreferences * _Nullable metadata, NSData * _Nonnull initialSnapshot, NSError * _Nullable error) {
        if (userCancelled) {
            
        }
        else if (error || !metadata) {
            if ( error && error.code == StrongboxErrorCodes.couldNotCreateICloudFile ) {
                [Alerts oneOptionsWithCancel:self
                                       title:NSLocalizedString(@"icloud_create_issue_title", @"iCloud Create Database Error")
                                     message:NSLocalizedString(@"icloud_create_issue_message", @"Strongbox could not create a new iCloud Database for you, most likely because the Strongbox iCloud folder has been deleted.\n\nYou can find out how to fix this issue below.")
                                  buttonText:NSLocalizedString(@"icloud_create_issue_fix", @"How do I fix this?")
                                      action:^(BOOL response) {
                    if ( response ) {
                        NSURL* url = [NSURL URLWithString:@"https:
                        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
                    }
                }];
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error creating database")
                        error:error];
            }
        }
        else {
            [self addDatabaseWithiCloudRaceCheck:metadata initialCache:initialSnapshot initialCacheModDate:NSDate.date];
        }
    }];
}

- (void)onCreateNewExpressDatabase:(NSString*)name
                          password:(NSString*)password
                        forceLocal:(BOOL)forceLocal {
    [AddNewSafeHelper createNewExpressDatabase:self
                                          name:name
                                      password:password
                                    forceLocal:forceLocal
                                    completion:^(BOOL userCancelled, DatabasePreferences * _Nonnull metadata, NSData * _Nonnull initialSnapshot, NSError * _Nonnull error) {
        if (userCancelled) {
            
        }
        else if(error || !metadata) {
            if ( error && error.code == StrongboxErrorCodes.couldNotCreateICloudFile ) {
                [Alerts twoOptionsWithCancel:self
                                       title:NSLocalizedString(@"icloud_create_issue_title", @"iCloud Create Database Error")
                                     message:NSLocalizedString(@"icloud_create_issue_message", @"Strongbox could not create a new iCloud Database for you, most likely because the Strongbox iCloud folder has been deleted.\n\nYou can find out how to fix this issue below.")
                           defaultButtonText:NSLocalizedString(@"icloud_create_issue_fix", @"How do I fix this?")
                            secondButtonText:NSLocalizedString(@"icloud_create_issue_local_instead", @"Create local database instead")
                                      action:^(int response) {
                    if ( response == 0 ) {
                        NSURL* url = [NSURL URLWithString:@"https:
                        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
                    }
                    else if ( response == 1) {
                        [self onCreateNewExpressDatabase:name password:password forceLocal:YES];
                    }
                }];
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error while creating database")
                        error:error];
            }
        }
        else {
            metadata = [self addDatabaseWithiCloudRaceCheck:metadata initialCache:initialSnapshot initialCacheModDate:NSDate.date];
            [self performSegueWithIdentifier:@"segueToCreateExpressDone"
                                      sender:@{@"database" : metadata, @"password" : password }];
        }
    }];
}

- (DatabasePreferences*)addDatabaseWithiCloudRaceCheck:(DatabasePreferences*)metadata initialCache:(NSData*)initialCache initialCacheModDate:(NSDate*)initialCacheModDate {
    if (metadata.storageProvider == kiCloud) {
        DatabasePreferences* existing = [DatabasePreferences.allDatabases firstOrDefault:^BOOL(DatabasePreferences * _Nonnull obj) {
            return obj.storageProvider == kiCloud && [obj.fileName compare:metadata.fileName] == NSOrderedSame;
        }];
        
        if(existing) { 
            slog(@"Not Adding as this iCloud filename is already present. Probably picked up by Watch Thread.");
            return existing;
        }
    }
    
    NSError* error;
    if ( ![metadata add:initialCache initialCacheModDate:initialCacheModDate error:&error] ) {
        [Alerts error:self error:error];
    }
    
    return metadata;
}

- (void)addManuallyDownloadedUrlDatabase:(NSString *)nickName modDate:(NSDate*)modDate data:(NSData *)data {
    [self addManualDownloadUrl:data modDate:modDate nickName:nickName];
}

- (void)addManualDownloadUrl:(NSData*)data modDate:(NSDate*)modDate nickName:(NSString *)nickName {
    id<SafeStorageProvider> provider = LocalDeviceStorageProvider.sharedInstance;

    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];  
    
    NSString* filename = [NSString stringWithFormat:@"%@.%@", nickName, [Serializator getDefaultFileExtensionForFormat:format]];
    
    [provider create:nickName
            fileName:filename
                data:data
        parentFolder:nil
      viewController:self
          completion:^(DatabasePreferences *metadata, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                NSError* error;
                if ( ![metadata addWithDuplicateCheck:data initialCacheModDate:modDate error:&error] ) {
                    [Alerts error:self error:error];
                }
            }
            else {
                [Alerts error:self title:NSLocalizedString(@"safes_vc_error_importing_database", @"Error Title Error Importing Datavase") error:error];
            }
        });
     }];
}




- (IBAction)onAddSafe:(id)sender {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"safes_vc_what_would_you_like_to_do", @"Options Title - What would like to do? Options are to Add a Database or Create New etc")
                                            message:nil
                                      preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_add_existing_database", @"")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
                                                       [self onAddExistingSafe];
                                                   }];
    [alertController addAction:action];
    
    
    
    UIAlertAction *createNewAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_new_database_advanced", @"")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
                                                       [self onCreateNewSafe];
                                                   }];
    [alertController addAction:createNewAction];
    
    
    
    UIAlertAction *quickAndEasyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_new_database_express", @"")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) {
                                                                [self onNewExpressDatabase];
                                                            }];

    [alertController addAction:quickAndEasyAction];
    
    
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    alertController.popoverPresentationController.barButtonItem = self.buttonAddSafe;
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)onAddExistingSafe {
    [self performSegueWithIdentifier:@"segueToStorageType" sender:@"Existing"];
}

- (void)onCreateNewSafe {
    [self performSegueWithIdentifier:@"segueToStorageType" sender:nil];
}

- (void)onNewExpressDatabase {
    [self performSegueWithIdentifier:@"segueToCreateDatabase" sender:nil];
}



- (IBAction)onUpgrade:(id)sender {
    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
}

- (void)onProStatusChanged:(id)param {
    slog(@"Pro Status Changed!");
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindToolbar];
        
        [CustomAppIconObjCHelper downgradeProIconIfInUse];
    });
}

- (void)showSaleScreen {

    
    BOOL existingSubscriber = ProUpgradeIAPManager.sharedInstance.hasActiveYearlySubscription;
    Sale* sale = SaleScheduleManager.sharedInstance.currentSale;
    
    if ( sale ) {
        __weak SafesViewController* weakSelf = self;
        UIViewController* vc = [SwiftUIViewFactory makeSaleOfferViewControllerWithSale:sale
                                                                    existingSubscriber:existingSubscriber
         redeemHandler:^{
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                SKPaymentQueue* queue = SKPaymentQueue.defaultQueue;
                [queue presentCodeRedemptionSheet];
            }];
        } onLifetimeHandler:^{
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                [weakSelf showLifetimePurchaseScreen];
            }];
        } dismissHandler:^{
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [self presentViewController:vc animated:YES completion:nil];
    }
    else {
        slog(@"🔴 Can't show sale screen - no sale on!");
    }
}

- (void)showLifetimePurchaseScreen {
    SKStoreProductViewController *vc = [[SKStoreProductViewController alloc] init];
    
    [vc loadProductWithParameters:@{ SKStoreProductParameterITunesItemIdentifier : @(1481853033) }
                  completionBlock:^(BOOL result, NSError * _Nullable error) {
        if ( !result ) {
            slog(@"loadProductWithParameters: result = %hhd, error = %@", result, error);
        }
    }];
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)showUpgradeScreen {
    UpgradeViewController* vc = [UpgradeViewController fromStoryboard];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)showToolbar:(NSString*)title
              image:(NSString*)image
      textTintColor:(UIColor*)textTintColor
          tintColor:(UIColor*)tintColor
  showDismissButton:(BOOL)showDismissButton
             action:(SEL)action {

    
    UIBarButtonItem* bbi1 = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:image] menu:nil];
    UIBarButtonItem* bbi2 = [[UIBarButtonItem alloc] initWithTitle:title menu:nil];
    UIBarButtonItem* bbi3 = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:image] menu:nil];
    





    bbi1.tintColor = tintColor;
    bbi2.tintColor = textTintColor;
    bbi3.tintColor = tintColor;

    
    bbi1.action = action;
    bbi1.target = self;
    bbi2.action = action;
    bbi2.target = self;
    bbi3.action = action;
    bbi3.target = self;
    
    NSMutableArray<UIBarButtonItem*>* buttons = @[UIBarButtonItem.flexibleSpaceItem,
                                                  bbi1,
                                                  bbi2,

                                                  UIBarButtonItem.flexibleSpaceItem,
                                                  ].mutableCopy;
    



    
    self.navigationController.toolbar.items = buttons;
    
    self.navigationController.toolbar.hidden = NO;
}

- (void)hideToolbar {

    self.navigationController.toolbar.hidden = YES;
}

- (BOOL)shouldShowUpgradeNotification {
    return !CustomizationManager.isAProBundle && !AppPreferences.sharedInstance.isPro;
}

- (BOOL)shouldShowSaleNotification {
    if ( SaleScheduleManager.sharedInstance.saleNowOn && !CustomizationManager.isAProBundle ) {
        
        if ( !AppPreferences.sharedInstance.isPro ) {
            return YES;
        }
        
        if ( ProUpgradeIAPManager.sharedInstance.hasActiveYearlySubscription && 
            SaleScheduleManager.sharedInstance.currentSale.showToExistingSubscribers ) {
            
            














            
            return YES;
        }
    }
    
    return NO;
}

- (void)bindToolbar {
    if ( [self shouldShowSaleNotification] ) {
        [self showToolbar:NSLocalizedString(@"safesvc_sale_now_on", @"Strongbox Sale Now On")
                    image:@"gift"
            textTintColor:UIColor.systemBlueColor
                tintColor:UIColor.greenColor
        showDismissButton:NO
                   action:@selector(showSaleScreen)];
    }
    else if ( [self shouldShowUpgradeNotification] ) {
        BOOL freeTrialAvailable = ProUpgradeIAPManager.sharedInstance.isFreeTrialAvailable;
        
        NSString *upgradeButtonTitle = freeTrialAvailable ?
        NSLocalizedString(@"safes_vc_upgrade_info_trial_available_button_title", @"Try Pro free for 3 months") :
        NSLocalizedString(@"safes_vc_upgrade_info_button_title_please_upgrade", @"Please Upgrade...");
        
        [self showToolbar:upgradeButtonTitle
                    image:@"star.circle.fill"
            textTintColor:AppPreferences.sharedInstance.daysInstalled > 60 ? UIColor.systemOrangeColor : UIColor.linkColor
                tintColor:AppPreferences.sharedInstance.daysInstalled > 60 ? UIColor.systemOrangeColor : UIColor.systemYellowColor
        showDismissButton:NO
                   action:@selector(showUpgradeScreen)];
    }
    else {
        [self hideToolbar];
    }
}

- (IBAction)onPreferences:(id)sender {
    if (!AppPreferences.sharedInstance.appLockAppliesToPreferences || AppPreferences.sharedInstance.appLockMode == kNoLock) {
        [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
        return;
    }
    
    if((AppPreferences.sharedInstance.appLockMode == kBiometric || AppPreferences.sharedInstance.appLockMode == kBoth) && BiometricsManager.isBiometricIdAvailable) {
        [self requestBiometricBeforeOpeningPreferences];
    }
    else if (AppPreferences.sharedInstance.appLockMode == kPinCode || AppPreferences.sharedInstance.appLockMode == kBoth) {
        [self requestPin];
    }
}

- (void)requestBiometricBeforeOpeningPreferences {
    [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_preferences_message", @"Identify to Open Settings")
                                     completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (AppPreferences.sharedInstance.appLockMode == kPinCode || AppPreferences.sharedInstance.appLockMode == kBoth) {
                    [self requestPin];
                }
                else {
                    [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
                }
            });
        }}];
}

- (void)requestPin {
    PinEntryController* pinEntryVc = PinEntryController.newControllerForAppLock;
    
    pinEntryVc.pinLength = AppPreferences.sharedInstance.appLockPin.length;
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if( response == kPinEntryResponseOk ) {
            if([pin isEqualToString:AppPreferences.sharedInstance.appLockPin]) {
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
                [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
            }
            else {
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeError];
                
                [Alerts info:self
                       title:NSLocalizedString(@"safes_vc_error_pin_incorrect_title", @"")
                     message:NSLocalizedString(@"safes_vc_error_pin_incorrect_message", @"")];
            }
        }
    };
    
    [self presentViewController:pinEntryVc animated:YES completion:nil];
}

- (void)openQuickLaunchDatabase:(BOOL)userJustCompletedBiometricAuthentication {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self internalOpenQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
    });
}

- (void)internalOpenQuickLaunchDatabase:(BOOL)userJustCompletedBiometricAuthentication {
    

    NSString* overrideQuickLaunchUuid = self.overrideQuickLaunchWithAppShortcutQuickLaunchUuid;
    self.overrideQuickLaunchWithAppShortcutQuickLaunchUuid = nil;

    if( !AppPreferences.sharedInstance.quickLaunchUuid && overrideQuickLaunchUuid == nil ) {
        
        return;
    }

    if(![self isVisibleViewController]) {
        slog(@"Not opening Quick Launch database as not at top of the Nav Stack");
        return;
    }
    
    NSString* uuid = overrideQuickLaunchUuid == nil ? AppPreferences.sharedInstance.quickLaunchUuid : overrideQuickLaunchUuid;
    
    DatabasePreferences* safe = [DatabasePreferences fromUuid:uuid];
        
    if(!safe) {
        slog(@"Not opening Quick Launch database as configured database not found");
        return;
    }
    
    [self openDatabase:safe
       explicitOffline:NO
  explicitManualUnlock:NO
   biometricPreCleared:userJustCompletedBiometricAuthentication
        explicitOnline:NO
     explicitEagerSync:NO];
}




- (void)processEnqueuedImport {
    if ( !self.enqueuedImportUrl ) {
        return;
    }

    

    [self.navigationController popToRootViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];

    NSURL* copy = self.enqueuedImportUrl;
    self.enqueuedImportUrl = nil;
    [self import:copy canOpenInPlace:self.enqueuedImportCanOpenInPlace forceOpenInPlace:NO];
}

- (void)import:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    dispatch_async(dispatch_get_main_queue(), ^{ 
        StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];

        if(!document) {
            slog(@"Invalid URL to Import [%@]", url);
            [self onReadImportedFile:NO data:nil url:url canOpenInPlace:NO forceOpenInPlace:NO modDate:nil];
            return;
        }

        [SVProgressHUD showWithStatus:NSLocalizedString(@"set_icon_vc_progress_reading_data", @"Reading Data...")];

        [document openWithCompletionHandler:^(BOOL success) {
            [SVProgressHUD dismiss];
            
            if ( document && [document isKindOfClass:StrongboxUIDocument.class] ) {
                NSData* data = document.data ? document.data.copy : nil; 
                
                NSError* error;
                NSDictionary* att = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
                NSDate* mod = att.fileModificationDate;
                
                [document closeWithCompletionHandler:nil];
                
                
                
                
                [StrongboxFilesManager.sharedInstance deleteAllInboxItems];
                        
                [self onReadImportedFile:success data:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace modDate:mod];
            }
            else {
                [self onReadImportedFile:NO data:nil url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace modDate:nil];
            }
        }];
    });
}

- (void)    onReadImportedFile:(BOOL)success
                      data:(NSData*)data
                       url:(NSURL*)url
            canOpenInPlace:(BOOL)canOpenInPlace
          forceOpenInPlace:(BOOL)forceOpenInPlace
                   modDate:(NSDate*)modDate {
    if(!success || !data) {
        if ([url.absoluteString isEqualToString:@"auth:
            
            slog(@"IGNORE - sent by Launcher app for some reason - just ignore...");
        }
        else {
            [Alerts warn:self
                   title:NSLocalizedString(@"safesvc_error_title_import_file_error_opening", @"Error Opening")
                 message:NSLocalizedString(@"safesvc_error_message_import_file_error_opening", @"Could not access this file.")];
        }
    }
    else {
        if ( [url.pathExtension caseInsensitiveCompare:@"key"] ==  NSOrderedSame || [url.pathExtension caseInsensitiveCompare:@"keyx"] ==  NSOrderedSame ) {
            [self importKey:data url:url];
        }
        
        




















        else {
            [self importDatabase:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace modDate:modDate];
        }
    }
}

- (void)importKey:(NSData*)data url:(NSURL*)url {
    NSString* filename = url.lastPathComponent;
    NSString* path = [StrongboxFilesManager.sharedInstance.keyFilesDirectory.path stringByAppendingPathComponent:filename];
    
    NSError *error;
    [data writeToFile:path options:kNilOptions error:&error];
    
    if(!error) {
        [Alerts info:self
               title:NSLocalizedString(@"safesvc_info_title_key_file_imported", @"Key File Imported")
             message:NSLocalizedString(@"safesvc_info_message_key_file_imported", @"This key file has been imported successfully.")];
    }
    else {
        [Alerts error:self
                title:NSLocalizedString(@"safesvc_error_title_error_importing_key_file", @"Problem Importing Key File") error:error];
    }
}

- (void)importDatabase:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace modDate:(NSDate*)modDate {
    NSError* error;
    
    if (![Serializator isValidDatabaseWithPrefix:data error:&error]) { 
        [Alerts error:self
                title:[NSString stringWithFormat:NSLocalizedString(@"safesvc_error_title_import_database_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                error:error];
        return;
    }
    
    if ( canOpenInPlace ) {
        if ( forceOpenInPlace ) {
            [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:YES modDate:modDate];
        }
        else {
            [Alerts threeOptions:self
                           title:NSLocalizedString(@"safesvc_import_database_prompt_title_edit_copy", @"Edit or Copy?")
                         message:NSLocalizedString(@"safesvc_import_database_prompt_message", @"Strongbox can attempt to edit this document in its current location and keep a reference or, if you'd prefer, Strongbox can just make a copy of this file for itself.\n\nWhich option would you like?")
               defaultButtonText:NSLocalizedString(@"safesvc_option_edit_in_place", @"Edit in Place")
                secondButtonText:NSLocalizedString(@"safesvc_option_make_a_copy", @"Make a Copy")
                 thirdButtonText:NSLocalizedString(@"generic_cancel", @"Cancel Option Button Title")
                          action:^(int response) {
                              if(response != 2) {
                                  [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:response == 0 modDate:modDate];
                              }
                          }];
        }
    }
    else {
        [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:NO modDate:modDate];
    }
}

- (void)checkForLocalFileOverwriteOrGetNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace modDate:(NSDate*)modDate {
    if(editInPlace == NO) {
        NSString* filename = url.lastPathComponent;
        
        BOOL existsInDefault = [LocalDeviceStorageProvider.sharedInstance fileNameExistsInDefaultStorage:filename];
        BOOL existsInDocuments = [LocalDeviceStorageProvider.sharedInstance fileNameExistsInDocumentsFolder:filename];
        
        if ( existsInDefault || existsInDocuments ) {
            [Alerts twoOptionsWithCancel:self
                                   title:NSLocalizedString(@"safesvc_update_existing_database_title", @"Update Existing Database?")
                                 message:NSLocalizedString(@"safesvc_update_existing_question", @"A database using this file name was found in Strongbox. Should Strongbox update that database to use this file, or would you like to create a new database using this file?")
                       defaultButtonText:NSLocalizedString(@"safesvc_update_existing_option_update", @"Update Existing Database")
                        secondButtonText:NSLocalizedString(@"safesvc_update_existing_option_create", @"Create a New Database")
                                  action:^(int response) {
                                      if(response == 0) {
                                          NSString *suggestedFilename = url.lastPathComponent;
                                          
                                          BOOL updated;

                                          if ( existsInDefault ) {
                                              updated = [LocalDeviceStorageProvider.sharedInstance writeToDefaultStorageWithFilename:suggestedFilename overwrite:YES data:data modDate:modDate];
                                          }
                                          else {
                                              updated = [LocalDeviceStorageProvider.sharedInstance writeToDocumentsWithFilename:suggestedFilename overwrite:YES data:data modDate:modDate];
                                          }
                                          
                                          if(!updated) {
                                              [Alerts warn:self
                                                     title:NSLocalizedString(@"safesvc_error_updating_title", @"Error updating file.")
                                                   message:NSLocalizedString(@"safesvc_error_updating_message", @"Could not update local file.")];
                                          }
                                          else {
                                              slog(@"Updated...");
                                              [SyncManager.sharedInstance backgroundSyncLocalDeviceDatabasesOnly];
                                          }
                                      }
                                      else if (response == 1){
                                          [self promptForNickname:data url:url editInPlace:editInPlace modDate:modDate];
                                      }
                                  }];
        }
        else {
            [self promptForNickname:data url:url editInPlace:editInPlace modDate:modDate];
        }
    }
    else {
        [self promptForNickname:data url:url editInPlace:editInPlace modDate:modDate];
    }
}

- (void)promptForNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace modDate:(NSDate*)modDate {
    [self performSegueWithIdentifier:@"segueFromInitialToAddDatabase"
                              sender:@{ @"editInPlace" : @(editInPlace),
                                        @"url" : url,
                                        @"data" : data,
                                        @"modDate" : modDate
                              }];
}



- (void)enqueueImport:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace {
    self.enqueuedImportUrl = url;
    self.enqueuedImportCanOpenInPlace = canOpenInPlace;
}

- (void)copyAndAddImportedSafe:(NSString *)nickName 
                          data:(NSData *)data
                           url:(NSURL*)url
                       modDate:(NSDate*)modDate {
    NSString* extension = [Serializator getLikelyFileExtension:data];
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];
    
    [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data modDate:modDate];
}

- (void)importToLocalDevice:(NSURL*)url 
                     format:(DatabaseFormat)format
                   nickName:(NSString*)nickName
                  extension:(NSString*)extension
                       data:(NSData*)data
                    modDate:(NSDate*)modDate {
    
    
    NSString *suggestedFilename = url.lastPathComponent;
        
    [LocalDeviceStorageProvider.sharedInstance create:nickName 
                                             fileName:suggestedFilename
                                                 data:data
                                              modDate:modDate
                                           completion:^(METADATA_PTR  _Nullable metadata, const NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                
                NSError* error;
                if( ![metadata addWithDuplicateCheck:data initialCacheModDate:modDate error:&error] ) {
                    [Alerts error:self error:error];
                }
                else {
                    [Alerts info:self
                           title:NSLocalizedString(@"import_successful_title",  @"Import Successful")
                         message:NSLocalizedString(@"database_local_copy_done_info_msg", @"Your database was successfully imported. Note that you can now remove the original source file from the device should you wish.")];
                }
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"safesvc_error_importing_title", @"Error Importing Database")
                        error:error];
            }
        });
    }];
}

- (void)addExternalFileReferenceSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url dateModified:(NSDate*)dateModified {
    NSError* error;
    NSData* bookMark = [BookmarksHelper getBookmarkDataFromUrl:url error:&error];
    
    if (error) {
        [Alerts error:self
                title:NSLocalizedString(@"safesvc_error_title_could_not_bookmark", @"Could not bookmark this file")
                error:error];
        return;
    }

    NSString* filename = [url lastPathComponent];
    
    DatabasePreferences* metadata = [FilesAppUrlBookmarkProvider.sharedInstance getDatabasePreferences:nickName fileName:filename providerData:bookMark];
    
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];
    metadata.likelyFormat = format;
    
    if (! [metadata addWithDuplicateCheck:data initialCacheModDate:dateModified error:&error] ) {
        [Alerts error:self error:error];
    }
}

- (void)beginMergeWizard:(DatabasePreferences*)destinationDatabase {
    if (self.collection.count < 2) {
        [Alerts info:self
               title:NSLocalizedString(@"merge_no_other_databases_available_title", @"No Other Databases Available")
             message:NSLocalizedString(@"merge_no_other_databases_available_msg", @"There are no other databases in your databases collection to merge into this database. You must add another database so that you can select it for the merge operation. Tap the '+' button to add.")];
    }
    else {
        [self performSegueWithIdentifier:@"segueToMergeWizard" sender:destinationDatabase];
    }
}



- (void)showDatabaseProperties:(DatabasePreferences*)database {
    [self performSegueWithIdentifier:@"segueToDatabaseProperties" sender:database];
}

- (IBAction)onRollTheDice:(id)sender {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"RandomizerPopOver" bundle:nil];
    
    RandomizerPopOverViewController* vc = (RandomizerPopOverViewController*)[storyboard instantiateInitialViewController];
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.presentationController.delegate = self;
    vc.popoverPresentationController.barButtonItem = self.barButtonDice;

        
    [self presentViewController:vc animated:YES completion:nil];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    
    
    return UIModalPresentationNone;
}

- (void)editConnection:(DatabasePreferences*)database {
#ifndef NO_NETWORKING
    if ( database.storageProvider == kWebDAV ) {
        WebDAVConnectionsViewController* vc = [WebDAVConnectionsViewController instantiateFromStoryboard];
        vc.selectMode = YES;
        
        WebDAVSessionConfiguration* config = [WebDAVStorageProvider.sharedInstance getConnectionFromDatabase:database];
        vc.initialSelected = config.identifier;
        
        vc.onSelected = ^(WebDAVSessionConfiguration * _Nonnull connection) {
            if ( ![connection.identifier isEqualToString:config.identifier] ) {
                [Alerts areYouSure:self
                           message:NSLocalizedString(@"are_you_sure_change_connection", @"Are you sure you want to change the connection for this database?")
                            action:^(BOOL response) {
                    if ( response ) {
                        [self changeWebDAVDatabaseConnection:database connection:connection];
                    }
                }];
            }
        };
        
        [vc presentFromViewController:self];
    }
    else if ( database.storageProvider == kSFTP ) {
        SFTPConnectionsViewController* vc = [SFTPConnectionsViewController instantiateFromStoryboard];
        vc.selectMode = YES;
        
        SFTPSessionConfiguration* config = [SFTPStorageProvider.sharedInstance getConnectionFromDatabase:database];
        vc.initialSelected = config.identifier;
        
        vc.onSelected = ^(SFTPSessionConfiguration * _Nonnull connection) {
            if ( ![connection.identifier isEqualToString:config.identifier] ) {
                [Alerts areYouSure:self
                           message:NSLocalizedString(@"are_you_sure_change_connection", @"Are you sure you want to change the connection for this database?")
                            action:^(BOOL response) {
                    if ( response ) {
                        [self changeSFTPDatabaseConnection:database connection:connection];
                    }
                }];
            }
        };
        
        [vc presentFromViewController:self];
    }
#endif
}

- (void)changeWebDAVDatabaseConnection:(DatabasePreferences*)database connection:(WebDAVSessionConfiguration*)connection {
#ifndef NO_NETWORKING
    WebDAVProviderData* pd = [WebDAVStorageProvider.sharedInstance getProviderDataFromMetaData:database];
    pd.connectionIdentifier = connection.identifier;
    
    DatabasePreferences* newDb = [WebDAVStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:pd];
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}

- (void)changeSFTPDatabaseConnection:(DatabasePreferences*)database connection:(SFTPSessionConfiguration*)connection {
#ifndef NO_NETWORKING
    SFTPProviderData* pd = [SFTPStorageProvider.sharedInstance getProviderDataFromMetaData:database];
    pd.connectionIdentifier = connection.identifier;
    
    DatabasePreferences* newDb = [SFTPStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:pd];
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}

- (void)editFilePath:(DatabasePreferences*)database {
#ifndef NO_NETWORKING
    if ( database.storageProvider != kWebDAV && database.storageProvider != kSFTP ) {
        return;
    }
        
    id<SafeStorageProvider> sp;
    
    if ( database.storageProvider == kWebDAV ) {
        WebDAVStorageProvider *wsp = [[WebDAVStorageProvider alloc] init];
        wsp.explicitConnection = [WebDAVStorageProvider.sharedInstance getConnectionFromDatabase:database];
        wsp.maintainSessionForListing = YES;
        sp = wsp;
    }
    else {
        SFTPStorageProvider *ssp = [[SFTPStorageProvider alloc] init];
        ssp.explicitConnection = [SFTPStorageProvider.sharedInstance getConnectionFromDatabase:database];
        ssp.maintainSessionForListing = YES;
        sp = ssp;
    }
    
    __weak SafesViewController* weakSelf = self;
    
    StorageBrowserTableViewController* vc = [StorageBrowserTableViewController instantiateFromStoryboard];
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];

    vc.existing = YES;
    vc.safeStorageProvider = sp;
    vc.onDone = ^(SelectedStorageParameters *params) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [nav.presentingViewController dismissViewControllerAnimated:YES completion:^{
                [weakSelf onEditSftpOrWebDAVFilePathDone:params database:database];
            }];
        });
    };
    
    [self presentViewController:nav animated:YES completion:nil];
#endif
}

- (void)onEditSftpOrWebDAVFilePathDone:(SelectedStorageParameters *)params
                              database:(DatabasePreferences*)database {
    if ( params.method == kStorageMethodErrorOccurred ) {
        [Alerts error:self error:params.error];
    }
    else if ( params.method == kStorageMethodNativeStorageProvider ) {
        [Alerts areYouSure:self
                   message:NSLocalizedString(@"are_you_sure_use_this_file_this_database", @"Are you want to use this file for this database?")
                    action:^(BOOL response) {
            if ( response ) {
                slog(@"Done [%@]", params.file.providerData);
                if ( database.storageProvider == kWebDAV ) {
                    [self changeWebDAVFilePath:database providerData:(WebDAVProviderData*)params.file.providerData];
                }
                else {
                    [self changeSFTPFilePath:database providerData:(SFTPProviderData*)params.file.providerData];
                }
            }
        }];
    }
}

- (void)changeSFTPFilePath:(DatabasePreferences*)database providerData:(SFTPProviderData*)providerData {
#ifndef NO_NETWORKING
    DatabasePreferences* newDb = [SFTPStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:providerData];
    
    database.fileName = newDb.fileName;
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}

- (void)changeWebDAVFilePath:(DatabasePreferences*)database providerData:(WebDAVProviderData*)providerData {
#ifndef NO_NETWORKING
    DatabasePreferences* newDb = [WebDAVStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:providerData];
    
    database.fileName = newDb.fileName;
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}



- (void)onImportLastPass {
    [self continueImportFileSelection:@"LastPass"];
}

- (void)onImportiCloud {
    [self continueImportFileSelection:@"iCloud"];
}

- (void)onImport1Password1Pux {
    [Alerts info:self
           title:NSLocalizedString(@"safes_vc_import_1password", @"Import 1Password")
         message:NSLocalizedString(@"safes_vc_import_1password_1pux_message", @"Strongbox can import 1Pux files from 1Password. Tap OK to select your exported 1Pux file.")
      completion:^{
        [self continueImportFileSelection:@"1Pux"];
    } ];
}

- (void)onImport1Password {
    [Alerts info:self
           title:NSLocalizedString(@"safes_vc_import_1password", @"Import 1Password")
         message:NSLocalizedString(@"safes_vc_import_1password_message", @"Strongbox can import 1Pif files from 1Password. Tap OK to select your exported 1Pif file.")
      completion:^{
        [self continueImportFileSelection:@"1Password"];
    } ];
}

- (void)onImportEnpass {
    [Alerts info:self
           title:NSLocalizedString(@"safes_vc_import_enpass", @"Import Enpass")
         message:NSLocalizedString(@"safes_vc_import_json_message", @"Strongbox can import JSON files. Tap OK to select your exported JSON file.")
      completion:^{
        [self continueImportFileSelection:@"Enpass"];
    } ];
}

- (void)onImportBitwarden {
    [Alerts info:self
           title:NSLocalizedString(@"safes_vc_import_bitwarden", @"Import Bitwarden")
         message:NSLocalizedString(@"safes_vc_import_json_message", @"Strongbox can import JSON files. Tap OK to select your exported JSON file.")
      completion:^{
        [self continueImportFileSelection:@"Bitwarden"];
    } ];
}

- (void)onImportGenericCsv {
    NSString* loc = NSLocalizedString(@"mac_csv_file_must_contain_header_and_fields", @"The CSV file must contain a header row with at least one of the following fields:\n\n[%@, %@, %@, %@, %@, %@]\n\nThe order of the fields doesn't matter.");

    NSString* message = [NSString stringWithFormat:loc, kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderTotp, kCSVHeaderNotes];
   
    loc = NSLocalizedString(@"mac_csv_format_info_title", @"CSV Format");

    [Alerts info:self title:loc message:message completion:^{
        [self continueImportFileSelection:@"CSV"];
    }];
}

- (void)continueImportFileSelection:(NSString*)importFormat {
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeItem]];
    vc.delegate = self;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    self.importFormat = importFormat;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {

    
    NSURL* url = [urls objectAtIndex:0];

    
    
    if (! [url startAccessingSecurityScopedResource] ) {
        slog(@"🔴 Could not securely access URL!");
    }











    if ( [self.importFormat isEqualToString:@"1Password"] ) {
        [self import1Password:url];
    }
    else if ( [self.importFormat isEqualToString:@"1Pux"] ) {
        [self import1Password1Pux:url];
    }
    else if ( [self.importFormat isEqualToString:@"LastPass"] ) {
        [self importLastPass:url];
    }
    else if ( [self.importFormat isEqualToString:@"iCloud"] ) {
        [self importiCloudCsv:url];
    }
    else if ( [self.importFormat isEqualToString:@"CSV"] ) {
        [self importCsv:url];
    }
    else if ( [self.importFormat isEqualToString:@"Enpass"] ) {
        [self importEnpass:url];
    }
    else if ( [self.importFormat isEqualToString:@"Bitwarden"] ) {
        [self importBitwarden:url];
    }
}

- (void)import1Password1Pux:(NSURL*)url {
    NSString* title = NSLocalizedString(@"1password_import_warning_title", @"1Password Import Warning");
    NSString* msg = NSLocalizedString(@"1password_import_warning_msg", @"The import process isn't perfect and some features of 1Password such as named sections are not available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");
    
    [Alerts info:self
           title:title
         message:msg
      completion:^{
        NSError* error;
        id<Importer> importer = [[OnePassword1PuxImporter alloc] init];
        ImportResult* result = [importer convertExWithUrl:url error:&error];
        [self addImportedDatabase:result.database messages:result.messages error:error];
    }];
}

- (void)importBitwarden:(NSURL*)url {
    NSString* title = NSLocalizedString(@"generic_import_warning_title", @"Import Warning");
    NSString* msg = NSLocalizedString(@"generic_import_warning_msg", @"The import process may not be perfect and some features may not be available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");

    [Alerts info:self
           title:title
         message:msg
      completion:^{
        NSError* error;
        id<Importer> importer = [[BitwardenImporter alloc] init];
        ImportResult* result = [importer convertExWithUrl:url error:&error];
        [self addImportedDatabase:result.database messages:result.messages error:error];
    }];
}

- (void)importEnpass:(NSURL*)url {
    NSString* title = NSLocalizedString(@"generic_import_warning_title", @"Import Warning");
    NSString* msg = NSLocalizedString(@"generic_import_warning_msg", @"The import process may not be perfect and some features may not be available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");
    
    [Alerts info:self
           title:title
         message:msg
      completion:^{
        NSError* error;
        id<Importer> importer = [[EnpassImporter alloc] init];
        ImportResult* result = [importer convertExWithUrl:url error:&error];
        [self addImportedDatabase:result.database messages:result.messages error:error];
    }];
}

- (void)import1Password:(NSURL*)url {
    NSString* title = NSLocalizedString(@"1password_import_warning_title", @"1Password Import Warning");
    NSString* msg = NSLocalizedString(@"1password_import_warning_msg", @"The import process isn't perfect and some features of 1Password such as named sections are not available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");

    [Alerts info:self
           title:title
         message:msg
      completion:^{
        NSError* error;
        id<Importer> importer = [[OnePasswordImporter alloc] init];
        DatabaseModel* database = [importer convertWithUrl:url error:&error];
        [self addImportedDatabase:database error:error];
    }];
}

- (void)importLastPass:(NSURL*)url {
    NSError* error;
    id<Importer> importer = [[LastPassImporter alloc] init];
    DatabaseModel* database = [importer convertWithUrl:url error:&error];
    [self addImportedDatabase:database error:error];
}

- (void)importiCloudCsv:(NSURL*)url {
    NSError* error;
    id<Importer> importer = [[iCloudImporter alloc] init];
    DatabaseModel* database = [importer convertWithUrl:url error:&error];
    [self addImportedDatabase:database error:error];
}

- (void)importCsv:(NSURL*)url {
    NSError* error;
    id<Importer> importer = [[CSVImporter alloc] init];
    DatabaseModel* database = [importer convertWithUrl:url error:&error];
    [self addImportedDatabase:database error:error];
}

- (void)addImportedDatabase:(DatabaseModel*)database error:(NSError*)error {
    [self addImportedDatabase:database messages:nil error:error];
}

- (void)addImportedDatabase:(DatabaseModel*)database
                   messages:(NSArray<ImportMessage*>* _Nullable)messages
                      error:(NSError*)error {
    if ( !database ) {
        [self importFailedNotification:error];
    }
    else {
        messages = messages ? messages : @[];
        
        __weak SafesViewController* weakSelf = self;
        
        UIViewController* vc = [SwiftUIViewFactory makeImportResultViewControllerWithMessages:messages
                                                                               dismissHandler:^(BOOL cancel) {
            [weakSelf.presentedViewController dismissViewControllerAnimated:YES completion:^{
                if ( !cancel ) {
                    [weakSelf setNewMasterPasswordOnImportedDatabase:database];
                }
            }];
        }];
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [self presentViewController:vc animated:YES completion:nil];
        






    }
}

- (void)setNewMasterPasswordOnImportedDatabase:(DatabaseModel*)database {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"CreateDatabaseOrSetCredentials" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    CASGTableViewController *scVc = (CASGTableViewController*)nav.topViewController;
    scVc.mode = kCASGModeCreateExpress;
    
    scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(success) {
                CompositeKeyFactors *ckf = [[CompositeKeyFactors alloc] initWithPassword:creds.password];
                if ( ckf ) {
                    database.ckfs = ckf;
                    [self addImportedDatabase:database 
                                         name:creds.name];
                }
                else {
                    [self importFailedNotification];
                }
            }
        }];
    };

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)importFailedNotification {
    [self importFailedNotification:nil];
}

- (void)importFailedNotification:(NSError*)error {
    if ( error ) {
        [Alerts error:self title:NSLocalizedString(@"import_failed_title", @"🔴 Import Failed") error:error];
    }
    else {
        [Alerts info:self
               title:NSLocalizedString(@"import_failed_title", @"🔴 Import Failed")
             message:NSLocalizedString(@"import_failed_message", @"Strongbox could not import this file. Please check it is in the correct format.")];
    }
}



- (void)onCloudKitShare:(NSIndexPath*)indexPath {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];
    
    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];

    [self onCloudKitCreateOrManageSharing:database rect:rect];
}

- (void)onCloudKitCreateOrManageSharing:(DatabasePreferences*)database rect:(CGRect)rect {
#ifndef NO_NETWORKING
    self.cloudKitSharingUIHelper = [[CloudKitSharingUIHelper alloc] initWithDatabase:database
                                                                parentViewController:self
                                                                          completion:^(NSError * _Nullable error ) {
        if ( error ) {
            slog(@"🔴 Error CloudKitSharingUIHelper [%@]", error);
            [Alerts error:self error:error];
        }
        
        [CloudKitDatabasesInteractor.shared refreshAndMergeWithCompletionHandler:^(NSError * _Nullable error) {
            if ( error ) {
                slog(@"🔴 Error refreshing after sharing. [%@]", error);
            }
        }];
        
        self.cloudKitSharingUIHelper = nil;
    }];
    
    [self.cloudKitSharingUIHelper presentWithRect:rect sourceView:self.tableView];
#endif
}

-(void)renameCloudKitDatabase:(DatabasePreferences*)database 
                         nick:(NSString*)nick
                     fileName:(NSString*_Nullable)fileName {
#ifndef NO_NETWORKING
    [CrossPlatformDependencies.defaults.spinnerUi show:NSLocalizedString(@"generic_renaming_ellipsis", @"Renaming...")
                                        viewController:self];
        
    [CloudKitDatabasesInteractor.shared renameWithDatabase:database
                                                  nickName:nick
                                                  fileName:fileName
                                         completionHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                [CrossPlatformDependencies.defaults.spinnerUi dismiss];
                slog(@"🔴 Error renaming Cloudkit Database [%@]", error);
                [Alerts error:self error:error];
            }
            else {
                [CrossPlatformDependencies.defaults.spinnerUi dismiss];
            }
        });
    }];
#endif
}



- (void)addImportedDatabase:(DatabaseModel*)importModel name:(NSString*)name {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createDatabaseForCreateOrImportOrCopy:name importModel:importModel databaseToCopy:nil];
    });
}

- (void)onCopyToNewStorageLocation:(DatabasePreferences*)databaseToCopy {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createDatabaseForCreateOrImportOrCopy:nil importModel:nil databaseToCopy:databaseToCopy];
    });
}

- (void)createDatabaseForCreateOrImportOrCopy:(NSString*)name importModel:(DatabaseModel*)importModel databaseToCopy:(DatabasePreferences*)databaseToCopy {
    self.selectStorageSwiftHelper = [[SelectStorageSwiftHelper alloc] initWithParentViewController:self
                                                        completion:^(DatabasePreferences * _Nullable maybeNewDatabase, BOOL userCancelled, NSError * _Nullable maybeError) {
        if ( maybeNewDatabase ) {
            [Alerts info:self title:NSLocalizedString(@"database_created_title", @"Database Created")
                 message:NSLocalizedString(@"database_created_msg", @"Your new database is now added and ready to be unlocked.")]; 
        }
        else if (maybeError) {
            if ( maybeError.code == StrongboxErrorCodes.couldNotCreateICloudFile ) {
                [Alerts oneOptionsWithCancel:self
                                       title:NSLocalizedString(@"icloud_create_issue_title", @"iCloud Create Database Error")
                                     message:NSLocalizedString(@"icloud_create_issue_message", @"Strongbox could not create a new iCloud Database for you, most likely because the Strongbox iCloud folder has been deleted.\n\nYou can find out how to fix this issue below.")
                                  buttonText:NSLocalizedString(@"icloud_create_issue_fix", @"How do I fix this?")
                                      action:^(BOOL response) {
                    if ( response ) {
                        NSURL* url = [NSURL URLWithString:@"https:
                        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
                    }
                }];
            }
            else {
                [Alerts error:self error:maybeError];
            }
        }
        
        self.selectStorageSwiftHelper = nil;
    }];
    
    if ( databaseToCopy ) {
        [self.selectStorageSwiftHelper beginCopyToStorageInteractionWithDatabaseToCopy:databaseToCopy];
    }
    else {
        [self.selectStorageSwiftHelper beginCreateOnStorageInteractionWithNickName:name databaseModel:importModel];
    }
}



- (void)handleOtpAuthUrl:(NSURL*)url {
    UIViewController* vc = [self getVisibleViewController];

    if ( AppModel.shared.editInProgress ) {
        [Alerts info:vc 
               title:NSLocalizedString(@"generic_edit_in_progress", @"Edit In Progress")
             message:NSLocalizedString(@"generic_edit_in_progress_2fa_code", @"There is an edit in progress, please complete this before adding a 2FA Code.")
          completion:nil];
        return;
    }
    
    [TwoFactorOtpAuthUrlUIHelper beginOtpAuthURLImportWithUrl:url
                                               viewController:vc
                                            completionHandler:^(DatabasePreferences * _Nullable database, NSError * _Nullable error) {
        if ( error ) {
            slog(@"🔴 Error adding TOTP: [%@]", error);
            [Alerts info:self title:NSLocalizedString(@"generic_error", @"Error") message:error.debugDescription];
        }
        else if ( database != nil ) {
            if ( AppModel.shared.unlockedDatabase ) {
                if ( AppModel.shared.unlockedDatabase.metadata.uuid == database.uuid ) {
                    [NSNotificationCenter.defaultCenter postNotificationName:kBeginImport2FAOtpAuthUrlNotification object:url];
                }
                else {
                    [Alerts yesNo:vc 
                            title:NSLocalizedString(@"close_current_db_question", @"Close Current Database?")
                          message:NSLocalizedString(@"close_current_db_question_for_2fa", @"You currently have a different database unlocked. Can Strongbox close that database to continue adding your 2FA Code?")
                           action:^(BOOL response) {
                        if ( response ) {
                            [self closeUnlockedDatabase:^{
                                [self openDatabaseFor2FAAdd:database optAuthUrl:url];
                            }];
                        }
                    }];
                }
            }
            else {
                [self openDatabaseFor2FAAdd:database optAuthUrl:url];
            }
        }
    }];
}

- (void)closeUnlockedDatabase:(void(^)(void))completion {
    Model* model = AppModel.shared.unlockedDatabase;
    if ( !model ) {
        slog(@"🔴 No database unlocked to close!!");
        return;
    }
    
    UIViewController* presented = self.presentedViewController;
    if ( presented == nil || ![presented isKindOfClass:MainSplitViewController.class] ) {
        
        slog(@"🔴 Unexpected, couldn't find the main splitviewcontroller!");
        return;
    }
    MainSplitViewController* splitView = (MainSplitViewController*)presented;
    if ( splitView.model != model ) {
        slog(@"🔴 Mismatching models!");
        return;
    }
    
    [splitView closeAndCleanupWithCompletion:completion];
}

@end
















































































































