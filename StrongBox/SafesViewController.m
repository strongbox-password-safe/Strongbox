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
#import "AppleICloudProvider.h"
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

#ifndef NO_SFTP_WEBDAV_SP
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
#import "Strongbox-Swift.h"

@interface SafesViewController () <UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonCustomizeView;

@property (nonatomic, copy) NSArray<DatabasePreferences*> *collection;

@property NSURL* enqueuedImportUrl;
@property BOOL enqueuedImportCanOpenInPlace;

@property (nonatomic, strong) NSDate *unlockedDatabaseWentIntoBackgroundAt;
@property DatabasePreferences* unlockedDatabase; 
@property BOOL appLockSuppressedForBiometricAuth;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonDice;
@property BOOL openingDatabaseInProgress;

@property NSString* importFormat;

@property (nullable) NSString* overrideQuickLaunchWithAppShortcutQuickLaunchUuid;

@end

@implementation SafesViewController

- (void)migrateToLazySync {
    
    
    
    
    if ( !AppPreferences.sharedInstance.hasMigratedToLazySync ) {
        AppPreferences.sharedInstance.hasMigratedToLazySync = YES;
        
        for ( DatabasePreferences* database in DatabasePreferences.allDatabases ) {
            if (
                
                
                database.storageProvider == kTwoDrive ) { 
                    NSLog(@"Migrating OneDrive Database [%@] to non lazy sync", database.nickName);
                    database.lazySyncMode = NO;
                }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    AppPreferences.sharedInstance.suppressAppBackgroundTriggers = NO; 
    
    NSLog(@"SafesViewController::viewDidLoad");
    
    self.tableView.hidden = YES;
    
    [self migrateToLazySync];
    
    [self customizeUI];
    
    [self checkForBrokenVirtualHardwareKeys];
    
    
    
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        
        
        
        [self internalRefresh];
        
        self.tableView.hidden = NO;
        
        [self listenToNotifications];
        
        if ( ![self isAppLocked] ) {
            NSLog(@"SafesViewController::viewDidLoad -> Initial Activation/Load - App is not Locked...");
            
            [self doAppActivationTasks:NO];
        }
        else {
            NSLog(@"SafesViewController::viewDidLoad -> App Is Locked");
        }
    });
}

- (void)checkForBrokenVirtualHardwareKeys {
    NSMutableSet<NSString*>* broken = NSMutableSet.set;
    
    for ( VirtualYubiKey* key in VirtualYubiKeys.sharedInstance.snapshot ) {
        if ( key.secretIsNoLongerPresent ) {
            NSLog(@"🔴 Found broken Virtual Hardware Key [%@]", key.identifier);
            [broken addObject:key.identifier];
        }
    }
    
    for ( DatabasePreferences* database in DatabasePreferences.allDatabases ) {
        YubiKeyHardwareConfiguration* yubiConfig = database.yubiKeyConfig;
        
        if ( yubiConfig && yubiConfig.mode == kVirtual && [broken containsObject:yubiConfig.virtualKeyIdentifier] ) {
            NSLog(@"🔴 Found database using broken Virtual Hardware Key [%@] - fixing", database.nickName);
            database.yubiKeyConfig = nil;
        }
        
        yubiConfig = database.autoFillYubiKeyConfig;
        if ( yubiConfig && yubiConfig.mode == kVirtual && [broken containsObject:yubiConfig.virtualKeyIdentifier] ) {
            NSLog(@"🔴 Found database using broken Virtual Hardware Key for AutoFill [%@] - fixing", database.nickName);
            database.autoFillYubiKeyConfig = nil;
        }
    }
    
    for ( NSString* ident in broken ) {
        NSLog(@"🔴 Deleting broken Virtual Hardware Key [%@]", ident);
        [VirtualYubiKeys.sharedInstance deleteKey:ident];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSLog(@"SafesViewController::viewWillAppear");
    
    [self setupTips];
    
    self.navigationController.navigationBar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO];
    
    self.navigationItem.hidesBackButton = YES;
    
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    [self bindToolbar];
    
    [CustomAppIconObjCHelper downgradeProIconIfInUse];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSLog(@"SafesViewController::viewDidAppear");
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
    NSLog(@"SafesViewController::internalRefresh");
    
    self.collection = DatabasePreferences.allDatabases;
    
    self.tableView.separatorStyle = AppPreferences.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    
    [self.tableView reloadData];
    
    [self updateDynamicAppIconShortcuts];
    
    [self bindToolbar];
    
    [CustomAppIconObjCHelper downgradeProIconIfInUse];
}

- (void)updateDynamicAppIconShortcuts {
    NSMutableArray<UIApplicationShortcutIcon*>* shortcuts = [[NSMutableArray alloc] init];
    
    for ( DatabasePreferences* database in self.collection ) {
        UIMutableApplicationShortcutItem *mutableShortcutItem = [[UIMutableApplicationShortcutItem alloc] initWithType:@"quick-launch"  localizedTitle:database.nickName];
        
        mutableShortcutItem.userInfo = @{ @"uuid" : database.uuid };
        mutableShortcutItem.icon = [UIApplicationShortcutIcon iconWithSystemImageName:@"cylinder.split.1x2"];
        
        [shortcuts addObject:mutableShortcutItem.copy];
    }
    
    
    
    [[UIApplication sharedApplication] setShortcutItems:shortcuts.copy];
}

- (void)performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem {
    NSLog(@"✅ performActionForShortcutItem: [%@]", shortcutItem.type);
    
    if ( [shortcutItem.type isEqualToString:@"quick-launch"] ) {
        NSString* uuid = (NSString*)shortcutItem.userInfo[@"uuid"];
        
        if ( uuid ) {
            DatabasePreferences* database = [DatabasePreferences fromUuid:uuid];
            if ( database ) {
                NSLog(@"Quick Launching database from App Shortcut = [%@]", database.nickName);
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
    
    [self.buttonPreferences setAccessibilityLabel:NSLocalizedString(@"generic_preferences", @"Preferences")];
    [self.buttonCustomizeView setAccessibilityLabel:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View")];
    [self.buttonAddSafe setAccessibilityLabel:NSLocalizedString(@"casg_add_action", @"Add")];
    
    if (@available(iOS 15.0, *)) {
        self.barButtonDice.image = [UIImage systemImageNamed:@"dice"];
    }
    
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
                                                 systemImage:@"wifi"
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
    
    UIMenu* menuWifi = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:@[wifiTransfer]];
    
    UIMenu* import = [UIMenu menuWithTitle:NSLocalizedString(@"safesvc_import_submenu", @"Import")
                                     image:[UIImage systemImageNamed:@"square.and.arrow.down"]
                                identifier:nil
                                   options:UIMenuOptionsDisplayInline
                                  children:@[import1P1Pux, import1P, importLastPass, importiCloud, importCsv]];
    
    
    UIMenu* more = [UIMenu menuWithTitle:NSLocalizedString(@"safesvc_more_submenu", @"More")
                                   image:[UIImage systemImageNamed:@"ellipsis.circle"]
                              identifier:nil
                                 options:kNilOptions
                                children:@[import]];
    
    UIMenu* menu = [UIMenu menuWithTitle:@""
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:AppPreferences.sharedInstance.disableNetworkBasedFeatures ? @[menu1, menu2, more] : @[menu1, menu2, menuWifi, more]];
    
    self.buttonAddSafe.action = nil;
    self.buttonAddSafe.menu = menu;
}

- (void)doAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication {
    [self refreshICloudFolderDatabases];
    
    [SyncManager.sharedInstance backgroundSyncOutstandingUpdates];
    
    [self doAppOnboarding:userJustCompletedBiometricAuthentication quickLaunchWhenDone:YES];
}

- (void)refreshICloudFolderDatabases {
    if ( !AppPreferences.sharedInstance.disableNetworkBasedFeatures && iCloudSafesCoordinator.sharedInstance.fastAvailabilityTest ) {
        NSLog(@"✅ refreshICloudFolderDatabases");
        
        [[iCloudSafesCoordinator sharedInstance] startQuery];
    }
}

- (void)doAppOnboarding:(BOOL)userJustCompletedBiometricAuthentication quickLaunchWhenDone:(BOOL)quickLaunchWhenDone {
    if ( ![self isVisibleViewController] ) {
        NSLog(@"We're not the visible view controller - not doing Onboarding");
        return;
    }
    
    __weak SafesViewController* weakSelf = self;
    [OnboardingManager.sharedInstance startAppOnboarding:self completion:^{


        
        if ( weakSelf.enqueuedImportUrl ) {
            [weakSelf processEnqueuedImport];
        }
        else if ( quickLaunchWhenDone ) {
            [weakSelf openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
        }
    }];
}



- (void)appResignActive {
    NSLog(@"SafesViewController::appResignActive");
    
    self.appLockSuppressedForBiometricAuth = NO;
    if( AppPreferences.sharedInstance.suppressAppBackgroundTriggers ) {
        NSLog(@"appResignActive... suppressAppBackgroundTriggers");
        self.appLockSuppressedForBiometricAuth = YES;
        return;
    }

    self.unlockedDatabaseWentIntoBackgroundAt = [[NSDate alloc] init];
}

- (void)appBecameActive {
    NSLog(@"SafesViewController::appBecameActive");
    
    if( self.appLockSuppressedForBiometricAuth ) {
        NSLog(@"App Active but Lock Screen Suppressed... Nothing to do");
        self.appLockSuppressedForBiometricAuth = NO;
        return;
    }

    
    
    
    BOOL reloadedDueToAutoFillChange = [DatabasePreferences reloadIfChangedByOtherComponent];
    self.collection = DatabasePreferences.allDatabases;
    [self refresh]; 

    
    
    if ( [self shouldLockUnlockedDatabase] ) {
        [self lockUnlockedDatabase:^{
            if ( ![self isAppLocked] ) {
                NSLog(@"SafesViewController::appBecameActive - Just Locked Database - App is not locked - Doing App Activation Tasks.");
                [self doAppActivationTasks:NO];
            }
        }];
    }
    else {
        if ( ![self isAppLocked] ) {
            NSLog(@"SafesViewController::appBecameActive - App is not locked - Doing App Activation Tasks.");
            [self doAppActivationTasks:NO];
        }
    }
    
    if ( reloadedDueToAutoFillChange ) {
        [self notifyUnlockedDatabaseAutoFillChangesMade];
    }
}

- (void)notifyUnlockedDatabaseAutoFillChangesMade {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.unlockedDatabase ) {
            NSLog(@"AutoFill Changes were made and unlocked database open, notify to reload");
            [NSNotificationCenter.defaultCenter postNotificationName:kAutoFillChangedConfigNotification object:nil];
        }
        else {
            NSLog(@"AutoFill Changes were made and no unlocked database open doing a background sync on all");
            [SyncManager.sharedInstance backgroundSyncOutstandingUpdates];
        }
    });
}

- (void)onAppLockScreenWillBeDismissed:(void (^)(void))completion {
    NSLog(@"SafesViewController::onAppLockWillBeDismissed");

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
    NSLog(@"SafesViewController::onAppLockWasDismissed [%hhd]", userJustCompletedBiometricAuthentication);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self doAppActivationTasks:userJustCompletedBiometricAuthentication];
    });
}

- (BOOL)shouldLockUnlockedDatabase {
    if ( self.unlockedDatabaseWentIntoBackgroundAt && self.unlockedDatabase ) {
        BOOL isEditing = [DatabasePreferences isEditing:self.unlockedDatabase];
        BOOL dontLockIfEditing = !self.unlockedDatabase.lockEvenIfEditing;
        
        if ( isEditing && dontLockIfEditing ) {
            NSLog(@"Not locking database because user is currently editing.");
            return NO;
        }
        
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.unlockedDatabaseWentIntoBackgroundAt];
        
        NSNumber *seconds = self.unlockedDatabase.autoLockTimeoutSeconds;
        
        NSLog(@"Autolock Time [%@s] - background Time: [%f].", seconds, secondsBetween);
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) 
        {
            NSLog(@"Should Lock Database [YES]");
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

    NSLog(@"onMainSplitViewControllerClosed [%@]", databaseId);

    if ( self.unlockedDatabase ) {
        NSLog(@"onMainSplitViewControllerClosed - Matching unlock db - clearing unlocked state.");

        if ( [self.unlockedDatabase.uuid isEqualToString:databaseId] ) {
            self.unlockedDatabase = nil;
            self.unlockedDatabaseWentIntoBackgroundAt = nil;
        }
        else {
            NSLog(@"WARNWARN: Received closed but Unlocked Database ID doesn't match!");
        }
    }
    else {
        NSLog(@"WARNWARN: Received closed but no Unlocked Database state available!");
    }
}

- (void)onDeviceLocked {
    NSLog(@"onDeviceLocked - Device Lock detected - locking open database if so configured...");
    
    if ( self.unlockedDatabase && self.unlockedDatabase.autoLockOnDeviceLock ) {
        BOOL isEditing = [DatabasePreferences isEditing:self.unlockedDatabase];
        BOOL dontLockIfEditing = !self.unlockedDatabase.lockEvenIfEditing;
        
        if ( isEditing && dontLockIfEditing ) {
            NSLog(@"Not locking database because user is currently editing.");
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
    if ( self.unlockedDatabase ) {
        NSLog(@"Locking Unlocked Database...");
                
        if ( ![self isAppLocked] ) {
            NSLog(@"lockUnlockedDatabase: App is not locked... we can lock");
            
            
            
            
            [DatabasePreferences setEditing:self.unlockedDatabase editing:NO];

            
            
            UINavigationController* nav = self.navigationController;
            [nav popToRootViewControllerAnimated:NO];
            [self dismissViewControllerAnimated:NO completion:completion];
            
            self.unlockedDatabase = nil; 
            self.unlockedDatabaseWentIntoBackgroundAt = nil;
        }
        else {
            NSLog(@"lockUnlockedDatabase: Cannot lock unlocked database because App is locked");
            if ( completion ) {
                completion();
            }
        }
    }
    else {
        NSLog(@"lockUnlockedDatabase: No unlocked database to lock");

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
            
            

            if (nav.visibleViewController) {
                visibleSoFar = nav.visibleViewController;
            }
            else {
                break;
            }
        }
        else {
            

            if (visibleSoFar.presentedViewController) {
                visibleSoFar = visibleSoFar.presentedViewController;
            }
            else {
                break;
            }
        }
    } while (--attempts); 


    
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
                                           selector:@selector(appBecameActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseUpdated:)
                                               name:kSyncManagerDatabaseSyncStatusChanged
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(protectedDataWillBecomeUnavailable)
                                               name:UIApplicationProtectedDataWillBecomeUnavailable
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onMainSplitViewControllerClosed:)
                                               name:kMasterDetailViewCloseNotification
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
            NSLog(@"WARNWARN: Database Update for DB [%@] but DB not found in Collection!", databaseId);
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
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        [DatabasePreferences move:sourceIndexPath.row to:destinationIndexPath.row];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
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
    DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];

    if ( indexPath.row < self.collection.count ) { 
        DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];

        [cell populateCell:database];
    }
    
    return cell;
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
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
        explicitOnline:explicitOnline];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(DatabasePreferences*)database {
    [self openDatabase:database
       explicitOffline:NO
  explicitManualUnlock:NO
   biometricPreCleared:NO
        explicitOnline:NO];
}

- (void)openDatabase:(DatabasePreferences*)safe
     explicitOffline:(BOOL)explicitOffline
explicitManualUnlock:(BOOL)explicitManualUnlock
 biometricPreCleared:(BOOL)biometricPreCleared
      explicitOnline:(BOOL)explicitOnline {
    NSLog(@"======================== OPEN DATABASE: %@ [EON: %hhd, EOFF: %hhd, MAN: %hhd, BPC: %hhd] ============================", safe.nickName, explicitOnline, explicitOffline, explicitManualUnlock, biometricPreCleared);
        
    biometricPreCleared = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics && biometricPreCleared;
    
    if(safe.hasUnresolvedConflicts) { 
        [self performSegueWithIdentifier:@"segueToVersionConflictResolution" sender:safe.fileIdentifier];
    }
    else {
        if ( self.openingDatabaseInProgress ) {
            NSLog(@"Another Database is in the process of being opened. Will not open this one.");
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
                         completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
            self.openingDatabaseInProgress = NO;
            
            if (result == kUnlockDatabaseResultSuccess) {
                [self onboardOrShowUnlockedDatabase:model];
            }
            else if (result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
                [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
            }
            else if (result == kUnlockDatabaseResultIncorrectCredentials) {
                
                NSLog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
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

- (void)onboardOrShowUnlockedDatabase:(Model*)model {
    [OnboardingManager.sharedInstance startDatabaseOnboarding:self model:model completion:^{
        [self showUnlockedDatabase:model];
    }];
}

- (void)showUnlockedDatabase:(Model*)model {
    self.unlockedDatabase = model.metadata;
    
    [self performSegueWithIdentifier:@"segueToMasterDetail" sender:model];
}





- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
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
    if (conveniencePossible) [ma addObject:[self getContextualMenuUnlockManualAction:indexPath]];

    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid];

    
    
    if ( safe.forceOpenOffline ) {
        if (safe.storageProvider != kLocalDevice) {
            [ma addObject:[self getContextualMenuOpenOnlineAction:indexPath]];
        }
    }
    else if ( !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        BOOL localCopyAvailable = safe.storageProvider != kLocalDevice && localCopyUrl != nil && !safe.forceOpenOffline;
        if (localCopyAvailable) [ma addObject:[self getContextualMenuOpenOfflineAction:indexPath]];
    }
    
    
    
    BOOL shareAllowed = !AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu && localCopyUrl != nil && !AppPreferences.sharedInstance.disableExport;
    if (shareAllowed) [ma addObject:[self getContextualShareAction:indexPath]];

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
    if (makeVisible) [ma addObject:[self getContextualMenuMakeVisibleAction:indexPath]];

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

    [ma addObject:[self getContextualMenuRenameAction:indexPath]];

    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid];
    if (url) {
        [ma addObject:[self getContextualMenuCreateLocalCopyAction:indexPath]];
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

- (UIAction*)getContextualShareAction:(NSIndexPath*)indexPath  {
    UIAction* ret = [ContextMenuHelper getItem:NSLocalizedString(@"generic_export", @"Export")
                                    systemImage:@"square.and.arrow.up"
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self onShare:indexPath];
    }];

    return ret;
}

- (UIAction*)getContextualMenuMakeVisibleAction:(NSIndexPath*)indexPath {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    BOOL shared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safe];
    NSString* localDeviceActionTitle = shared ?
        NSLocalizedString(@"safes_vc_show_in_files", @"Button Title to Show in iOS Files Browser") :
        NSLocalizedString(@"safes_vc_make_autofillable", @"Button Title to Hide from iOS Files Browser");

    UIAction* ret = [ContextMenuHelper getItem:localDeviceActionTitle
                                    systemImage:shared ? @"eye" : @"eye.slash"
                                    
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
    
- (UIAction*)getContextualMenuCreateLocalCopyAction:(NSIndexPath*)indexPath {
    UIImage* img = [UIImage systemImageNamed:@"doc.on.doc"];

    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [ContextMenuHelper getItem:NSLocalizedString(@"generic_action_create_local_database", @"Create Local Copy")
                                 image:img
                           
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self createLocalCopyDatabase:safe];
    }];

    




    
    return ret;
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

- (UIAction*)getContextualMenuRemoveAction:(NSIndexPath*)indexPath  {
    return [ContextMenuHelper getDestructiveItem:NSLocalizedString(@"generic_remove", @"Remove")
                                     systemImage:@"trash.fill"
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self removeSafe:indexPath];
    }];
}



- (void)onShare:(NSIndexPath*)indexPath {
    DatabasePreferences *database = [self.collection objectAtIndex:indexPath.row];

    if (!database) {
        return;
    }
    
    NSString* filename = AppPreferences.sharedInstance.appendDateToExportFileName ? database.exportFilename : database.fileName;
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    if (!localCopyUrl) {
        [Alerts error:self error:[Utils createNSError:@"Could not get local copy" errorCode:-2145]];
        return;
    }
    
    NSError* err;
    NSData* data = [NSData dataWithContentsOfURL:localCopyUrl options:kNilOptions error:&err];
    if (err) {
        [Alerts error:self error:err];
        return;
    }

    [data writeToFile:f options:kNilOptions error:&err];
    if (err) {
        [Alerts error:self error:err];
        return;
    }
    
    NSURL* url = [NSURL fileURLWithPath:f];
    NSArray *activityItems = @[url];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    

    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
    activityViewController.popoverPresentationController.sourceView = self.tableView;
    activityViewController.popoverPresentationController.sourceRect = rect;
    activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSError *errorBlock;
        if([[NSFileManager defaultManager] removeItemAtURL:url error:&errorBlock] == NO) {
            NSLog(@"error deleting file %@", errorBlock);
            return;
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:NSLocalizedString(@"safes_vc_slide_left_remove_database_action", @"Remove this database table action")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeSafe:indexPath];
    }];

    

    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    UITableViewRowAction *onOrOfflineAction = nil;
    if ( safe.forceOpenOffline ) {
        if (safe.storageProvider != kLocalDevice) {
            onOrOfflineAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                   title:NSLocalizedString(@"safes_vc_slide_left_open_online_action", @"Open this database online action")
                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                [self explicitRequestOpenOnline:indexPath];
            }];
            onOrOfflineAction.backgroundColor = [UIColor systemGreenColor];
        }
    }
    else {
        BOOL offlineOption = safe.storageProvider != kLocalDevice && [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safe.uuid modified:nil];
        if ( offlineOption ) {
            onOrOfflineAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                   title:NSLocalizedString(@"safes_vc_slide_left_open_offline_action", @"Open this database offline table action")
                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                [self explicitRequestOpenOffline:indexPath];
            }];
            onOrOfflineAction.backgroundColor = [UIColor darkGrayColor];
        }
    }
    
    
    
    UITableViewRowAction *moreActions = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                           title:NSLocalizedString(@"safes_vc_slide_left_more_actions", @"View more actions table action")
                                                                         handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self showDatabaseMoreActions:indexPath];
    }];
    moreActions.backgroundColor = [UIColor systemBlueColor];

    return onOrOfflineAction ? @[removeAction, onOrOfflineAction, moreActions] : @[removeAction, moreActions];
}

- (void)showDatabaseMoreActions:(NSIndexPath*)indexPath {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"safes_vc_database_actions_sheet_title", @"Title of the 'More Actions' alert/action sheet")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    
    
    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_action_rename_database", @"Button to Rename the Database")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *a) {
                                                             [self renameSafe:indexPath];
                                                         } ];
    [alertController addAction:renameAction];
    
    

    BOOL isAlreadyQuickLaunch = [AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid];
    UIAlertAction *quickLaunchAction = [UIAlertAction actionWithTitle:isAlreadyQuickLaunch ?
                                        NSLocalizedString(@"safes_vc_action_unset_as_quick_launch", @"Button Title to Unset Quick Launch") :
                                        NSLocalizedString(@"safes_vc_action_set_as_quick_launch", @"Button Title to Set Quick Launch")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              [self toggleQuickLaunch:safe];
                                                          } ];
    [alertController addAction:quickLaunchAction];

    

    if (self.collection.count > 1) {
        UIAlertAction *mergeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_action_compare_and_merge_ellipsis", @"Compare & Merge...")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) {
            [self beginMergeWizard:safe];
        }];

        [alertController addAction:mergeAction];
    }
    
    
    
    BOOL localDeviceOption = safe.storageProvider == kLocalDevice;
    if(localDeviceOption) {
        BOOL shared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safe];
        NSString* localDeviceActionTitle = shared ? NSLocalizedString(@"safes_vc_show_in_files", @"Button Title to Show in iOS Files Browser") : NSLocalizedString(@"safes_vc_make_autofillable", @"Button Title to Hide from iOS Files Browser");

        UIAlertAction *secondAction = [UIAlertAction actionWithTitle:localDeviceActionTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) {
                                                                 [self promptAboutToggleLocalStorage:indexPath shared:shared];
                                                             }];
        [alertController addAction:secondAction];
    }
    
    
    
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid];
    if (url) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_action_create_local_database", @"Create Local Copy")
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *a) {
            [self createLocalCopyDatabase:safe];
        }];
        [alertController addAction:action];
    }
    
    
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"browse_vc_action_properties", @"Properties")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
        [self showDatabaseProperties:safe];
    }];
    [alertController addAction:action];
        
    
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel Button")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alertController addAction:cancelAction];
    


    
    [self presentViewController:alertController animated:YES completion:nil];
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

- (void)removeSafe:(NSIndexPath * _Nonnull)indexPath {
    DatabasePreferences *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString *message;
    
    if ( safe.storageProvider == kiCloud && !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        message = NSLocalizedString(@"safes_vc_remove_icloud_databases_warning", @"warning message about removing database from icloud");
    }
    else {
        message = [NSString stringWithFormat:NSLocalizedString(@"safes_vc_are_you_sure_remove_database_fmt", @"are you sure you want to remove database prompt with format string on end"),
                         (safe.storageProvider == kiCloud || safe.storageProvider == kLocalDevice)  ? @"" : NSLocalizedString(@"safes_vc_extra_info_underlying_database", @"extra info appended to string about the underlying storage type")];
    }
    
    [Alerts yesNo:self
            title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure? Title")
          message:message
           action:^(BOOL response) {
               if (response) {
                   [self removeAndCleanupSafe:safe];
               }
           }];
}

- (void)removeAndCleanupSafe:(DatabasePreferences *)safe {
    if (safe.storageProvider == kLocalDevice) {
        [[LocalDeviceStorageProvider sharedInstance] delete:safe
                completion:^(NSError *error) {
                    if (error != nil) {
                        NSLog(@"Error removing local file: %@", error);
                    }
                    else {
                        NSLog(@"Removed Local File Successfully.");
                    }
                }];
    }
    else if (safe.storageProvider == kiCloud) {
        [[AppleICloudProvider sharedInstance] delete:safe completion:^(NSError *error) {
            if(error) {
                NSLog(@"%@", error);
                [Alerts error:self title:NSLocalizedString(@"safes_vc_error_delete_icloud_database", @"Error message - could not delete iCloud database") error:error];
                return;
            }
            else {
                NSLog(@"iCloud file removed");
            }
        }];
    }

    [SyncManager.sharedInstance removeDatabaseAndLocalCopies:safe];
    [safe clearKeychainItems];
    
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    
    
    
    if([AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid]) {
        AppPreferences.sharedInstance.quickLaunchUuid = nil;
    }

    if([AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:safe.uuid]) {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = nil;
    }

    
    
    [BackupsManager.sharedInstance deleteAllBackups:safe];
    
    [safe removeFromDatabasesList];
}



- (void)renameDatabase:(DatabasePreferences*)database name:(NSString*)name renameFile:(BOOL)renameFile {
    database.nickName = name;
    
    BOOL allowFileRename = database.storageProvider == kLocalDevice;
    if ( renameFile &&  allowFileRename ) {
        NSError* error;
        if ( ![LocalDeviceStorageProvider.sharedInstance renameFilename:database filename:name error:&error] ) {
            NSLog(@"🔴 Error Renaming... [%@]", error);
            
            if ( error ) {
                [Alerts error:self error:error];
            }
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ( [segue.identifier isEqualToString:@"segueToMasterDetail"] ) {
        MainSplitViewController *svc = segue.destinationViewController;
        svc.model = (Model*)sender;
    }
    else if ( [segue.identifier isEqualToString:@"segueToStorageType"] )
    {
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
        
        BOOL allowFileRename = database.storageProvider == kLocalDevice;
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
    NSLog(@"onSelectedStorageLocation: [%@] - [%@]", params.createMode ? @"Create" : @"Add", params);
    
    if(params.method == kStorageMethodUserCancelled) {
        NSLog(@"onSelectedStorageLocation: User Cancelled");
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else if (params.method == kStorageMethodErrorOccurred) {
        [self dismissViewControllerAnimated:YES completion:^{
            [Alerts error:self title:NSLocalizedString(@"safes_vc_error_selecting_storage_location", @"Error title - error selecting storage location") error:params.error];
        }];
    }
    else if (params.method == kStorageMethodFilesAppUrl) {
        [self dismissViewControllerAnimated:YES completion:^{
            NSLog(@"Files App: [%@] - Create: %d", params.url, params.createMode);

            if (params.createMode) {
                [self performSegueWithIdentifier:@"segueToCreateDatabase" sender:params];
            }
            else {
                [self import:params.url canOpenInPlace:YES forceOpenInPlace:YES];
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
            [database add:storageParams.data initialCacheModDate:storageParams.initialDateModified];
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
            NSLog(@"Not Adding as this iCloud filename is already present. Probably picked up by Watch Thread.");
            return existing;
        }
    }
    
    [metadata add:initialCache initialCacheModDate:initialCacheModDate];
    
    return metadata;
}

- (void)addManuallyDownloadedUrlDatabase:(NSString *)nickName modDate:(NSDate*)modDate data:(NSData *)data {
    [self addManualDownloadUrl:NO data:data modDate:modDate nickName:nickName];
}

- (void)addManualDownloadUrl:(BOOL)iCloud data:(NSData*)data modDate:(NSDate*)modDate nickName:(NSString *)nickName {
    id<SafeStorageProvider> provider;

    if(iCloud) {
        provider = AppleICloudProvider.sharedInstance;
    }
    else {
        provider = LocalDeviceStorageProvider.sharedInstance;
    }

    NSString* extension = [Serializator getLikelyFileExtension:data];
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];  
    
    [provider create:nickName
           extension:extension
                data:data
        parentFolder:nil
      viewController:self
          completion:^(DatabasePreferences *metadata, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                [metadata addWithDuplicateCheck:data initialCacheModDate:modDate];
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
    NSLog(@"Pro Status Changed!");
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindToolbar];
        
        [CustomAppIconObjCHelper downgradeProIconIfInUse];
    });
}

- (void)showSaleScreen {



    
    BOOL existingSubscriber = ProUpgradeIAPManager.sharedInstance.hasActiveYearlySubscription;
    NSDate* saleEndDate = SaleScheduleManager.sharedInstance.currentSaleEndDate;
    
    if ( saleEndDate ) {
        NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
        [dateComponents setDay:-1];
        NSDate *inclusiveEndDate = [[NSCalendar currentCalendar] dateByAddingComponents:dateComponents toDate:saleEndDate options:0];

        __weak SafesViewController* weakSelf = self;
        UIViewController* vc = [SwiftUIViewFactory makeSaleOfferViewControllerWithSaleEndDate:inclusiveEndDate
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
}

- (void)showLifetimePurchaseScreen {
    SKStoreProductViewController *vc = [[SKStoreProductViewController alloc] init];
    
    [vc loadProductWithParameters:@{ SKStoreProductParameterITunesItemIdentifier : @(1481853033) }
                  completionBlock:^(BOOL result, NSError * _Nullable error) {
        if ( !result ) {
            NSLog(@"loadProductWithParameters: result = %hhd, error = %@", result, error);
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

        if ( ProUpgradeIAPManager.sharedInstance.hasActiveYearlySubscription ) {
            NSDate* expiry = ProUpgradeIAPManager.sharedInstance.currentSubscriptionRenewalOrExpiry;
            
            if ( expiry ) {
                NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
                [dateComponents setMonth:1];
                                
                NSDate* startNext = SaleScheduleManager.sharedInstance.saleAfterNextSaleStartDate;
                
                NSDate *expiryDeadline = [[NSCalendar currentCalendar] dateByAddingComponents:dateComponents
                                                                                       toDate:startNext
                                                                                      options:0];
                
                return [expiry isEarlierThan:expiryDeadline];
            }
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
        NSLocalizedString(@"safes_vc_upgrade_info_trial_available_button_title", @"Upgrade (Free 'Pro' Trial)...") :
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
    [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_preferences_message", @"Identify to Open Preferences")
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
        NSLog(@"Not opening Quick Launch database as not at top of the Nav Stack");
        return;
    }
    
    NSString* uuid = overrideQuickLaunchUuid == nil ? AppPreferences.sharedInstance.quickLaunchUuid : overrideQuickLaunchUuid;
    
    DatabasePreferences* safe = [DatabasePreferences fromUuid:uuid];
        
    if(!safe) {
        NSLog(@"Not opening Quick Launch database as configured database not found");
        return;
    }
    
    [self openDatabase:safe
       explicitOffline:NO
  explicitManualUnlock:NO
   biometricPreCleared:userJustCompletedBiometricAuthentication
        explicitOnline:NO];
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
            NSLog(@"Invalid URL to Import [%@]", url);
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

- (void)onReadImportedFile:(BOOL)success
                      data:(NSData*)data
                       url:(NSURL*)url
            canOpenInPlace:(BOOL)canOpenInPlace
          forceOpenInPlace:(BOOL)forceOpenInPlace
                   modDate:(NSDate*)modDate {
    if(!success || !data) {
        if ([url.absoluteString isEqualToString:@"auth:
            
            NSLog(@"IGNORE - sent by Launcher app for some reason - just ignore...");
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
    
    if(canOpenInPlace) {
        if(forceOpenInPlace) {
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
        if ( [LocalDeviceStorageProvider.sharedInstance fileNameExistsInDefaultStorage:filename] ) {
            [Alerts twoOptionsWithCancel:self
                                   title:NSLocalizedString(@"safesvc_update_existing_database_title", @"Update Existing Database?")
                                 message:NSLocalizedString(@"safesvc_update_existing_question", @"A database using this file name was found in Strongbox. Should Strongbox update that database to use this file, or would you like to create a new database using this file?")
                       defaultButtonText:NSLocalizedString(@"safesvc_update_existing_option_update", @"Update Existing Database")
                        secondButtonText:NSLocalizedString(@"safesvc_update_existing_option_create", @"Create a New Database")
                                  action:^(int response) {
                                      if(response == 0) {
                                          NSString *suggestedFilename = url.lastPathComponent;
                                          BOOL updated = [LocalDeviceStorageProvider.sharedInstance writeToDefaultStorageWithFilename:suggestedFilename overwrite:YES data:data modDate:modDate];
                                          
                                          if(!updated) {
                                              [Alerts warn:self
                                                     title:NSLocalizedString(@"safesvc_error_updating_title", @"Error updating file.")
                                                   message:NSLocalizedString(@"safesvc_error_updating_message", @"Could not update local file.")];
                                          }
                                          else {
                                              NSLog(@"Updated...");
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

- (void)copyAndAddImportedSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url modDate:(NSDate*)modDate {
    NSString* extension = [Serializator getLikelyFileExtension:data];
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];
    
    [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data modDate:modDate];
}

- (void)importToLocalDevice:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data modDate:(NSDate*)modDate {
    
    
    NSString *suggestedFilename = url.lastPathComponent;
        
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                            extension:extension
                                                 data:data
                                              modDate:modDate
                                    suggestedFilename:suggestedFilename
                                           completion:^(DatabasePreferences *metadata, NSError *error) {
       dispatch_async(dispatch_get_main_queue(), ^(void) {
           if (error == nil) {
               metadata.likelyFormat = format;
               [metadata addWithDuplicateCheck:data initialCacheModDate:modDate];
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
    
    [metadata addWithDuplicateCheck:data initialCacheModDate:dateModified];
}



- (void)createLocalCopyDatabase:(DatabasePreferences*)database {
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
    if (!data) {
        [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
        return;
    }
    
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    if (!attr || error) {
        [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
        return;
    }
    
    NSDate* modDate = attr.fileModificationDate;
    

    
    NSString* nickName = [NSString stringWithFormat:@"Local Copy of %@", database.nickName];
    NSString* extension = [Serializator getLikelyFileExtension:data];
    
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                            extension:extension
                                                 data:data
                                              modDate:modDate
                                    suggestedFilename:database.fileName
                                           completion:^(DatabasePreferences * _Nonnull metadata, NSError * _Nonnull error) {
        if(error || !metadata) {
            [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
            return;
        } 
        
        [metadata addWithDuplicateCheck:data initialCacheModDate:modDate];

        [Alerts info:self
               title:NSLocalizedString(@"generic_done", @"Done")
             message:NSLocalizedString(@"safes_vc_created_local_copy_done", @"Local Copy Created.")
          completion:^{
            [self.navigationController popToRootViewControllerAnimated:YES];
        }];
    }];
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
#ifndef NO_SFTP_WEBDAV_SP
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
#ifndef NO_SFTP_WEBDAV_SP
    WebDAVProviderData* pd = [WebDAVStorageProvider.sharedInstance getProviderDataFromMetaData:database];
    pd.connectionIdentifier = connection.identifier;
    
    DatabasePreferences* newDb = [WebDAVStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:pd];
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}

- (void)changeSFTPDatabaseConnection:(DatabasePreferences*)database connection:(SFTPSessionConfiguration*)connection {
#ifndef NO_SFTP_WEBDAV_SP
    SFTPProviderData* pd = [SFTPStorageProvider.sharedInstance getProviderDataFromMetaData:database];
    pd.connectionIdentifier = connection.identifier;
    
    DatabasePreferences* newDb = [SFTPStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:pd];
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}

- (void)editFilePath:(DatabasePreferences*)database {
#ifndef NO_SFTP_WEBDAV_SP
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
                NSLog(@"Done [%@]", params.file.providerData);
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
#ifndef NO_SFTP_WEBDAV_SP
    DatabasePreferences* newDb = [SFTPStorageProvider.sharedInstance getDatabasePreferences:database.nickName providerData:providerData];
    
    database.fileName = newDb.fileName;
    database.fileIdentifier = newDb.fileIdentifier;
#endif
}

- (void)changeWebDAVFilePath:(DatabasePreferences*)database providerData:(WebDAVProviderData*)providerData {
#ifndef NO_SFTP_WEBDAV_SP
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

- (void)onImportGenericCsv {
    NSString* loc = NSLocalizedString(@"mac_csv_file_must_contain_header_and_fields", @"The CSV file must contain a header row with at least one of the following fields:\n\n[%@, %@, %@, %@, %@, %@]\n\nThe order of the fields doesn't matter.");

    NSString* message = [NSString stringWithFormat:loc, kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderTotp, kCSVHeaderNotes];
   
    loc = NSLocalizedString(@"mac_csv_format_info_title", @"CSV Format");

    [Alerts info:self title:loc message:message completion:^{
        [self continueImportFileSelection:@"CSV"];
    }];
}

- (void)continueImportFileSelection:(NSString*)importFormat {
    UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];
    vc.delegate = self;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    self.importFormat = importFormat;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    
    
    if (! [url startAccessingSecurityScopedResource] ) {
        NSLog(@"🔴 Could not securely access URL!");
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
                    [self addImportedDatabase:database name:creds.name];
                }
                else {
                    [self importFailedNotification];
                }
            }
        }];
    };

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)addImportedDatabase:(DatabaseModel*)database name:(NSString*)name {
    [AddNewSafeHelper createNewExpressDatabase:self
                                          name:name
                                         model:database
                                    completion:^(BOOL userCancelled, DatabasePreferences * _Nonnull metadata, NSData * _Nonnull initialSnapshot, NSError * _Nonnull error) {
        [metadata addWithDuplicateCheck:initialSnapshot initialCacheModDate:NSDate.date];
    }];
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



- (void)handleUrlSchemeNavigationRequest:(NSURL *)url {
    NSLog(@"Strongbox URL Scheme: [%@]", url);
    
    return;
    
    NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    
    NSLog(@"Host = %@", components.host );

    NSString* databaseId = components.host;
    
    DatabasePreferences* database = nil;
    
    NSUUID* iden = [[NSUUID alloc] initWithUUIDString:databaseId];
    DatabasePreferences* nickNameMatch = [DatabasePreferences.allDatabases firstOrDefault:^BOOL(DatabasePreferences * _Nonnull obj) {
        return [obj.nickName caseInsensitiveCompare:databaseId] == NSOrderedSame;
    }];
    
    if ( databaseId.length == 0 ) {
        database = DatabasePreferences.allDatabases.firstObject;
        NSLog(@"No Database Specified. Will use first.");
    }
    else if ( iden != nil ) {
        NSLog(@"Database UUID Specified... [%@]", iden.UUIDString); 
        database = [DatabasePreferences fromUuid:databaseId];
    }
    else if ( nickNameMatch ) { 
        database = nickNameMatch;
        NSLog(@"Database NickName Specified");
    }
    else if ( databaseId.isAllDigits ) {
        NSLog(@"Database Index Specified: [%ld]", (long)databaseId.integerValue);
        NSArray* databases = DatabasePreferences.allDatabases;
        if ( databaseId.integerValue < databases.count ) {
            database = databases[databaseId.integerValue];
        }
    }
    
    if ( database ) {
        NSString* path = components.path;
        NSString* query = components.query;

        [self handleUrlSchemeNavigationRequestWithDatabase:database path:path query:query];
    }
    else {
        
    }
}

- (void)handleUrlSchemeNavigationRequestWithDatabase:(DatabasePreferences*)database path:(NSString*)path query:(NSString*)query {
    NSLog(@"URL Nav Scheme Requests Database = [%@] be Unlocked... - path = %@, query = %@", database.nickName, path, query);

    if ( self.unlockedDatabase) {
        if ( [self.unlockedDatabase.uuid isEqualToString:database.uuid] ) {
            NSLog(@"Database Already Unlocked and Open...");
            
        }
        else {
            NSLog(@"Different Database Already Open..."); 
        }
    }
    else {
        
        [self openDatabase:database];
    }
}

@end






































































