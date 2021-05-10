//
//  SafesViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesViewController.h"
#import "BrowseSafeView.h"
#import "SafesList.h"
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
#import "FileManager.h"
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
#import "YubiManager.h"
#import "WelcomeFreemiumViewController.h"
#import "MasterDetailViewController.h"
#import "AppPreferences.h"
#import "SyncManager.h"
#import "SyncStatus.h"
#import "SyncLogViewController.h"
#import "NSDate+Extensions.h"
#import "DebugHelper.h"
#import "GettingStartedInitialViewController.h"
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

@interface SafesViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpgrade;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonCustomizeView;

@property (nonatomic, copy) NSArray<SafeMetaData*> *collection;

@property NSURL* enqueuedImportUrl;
@property BOOL enqueuedImportCanOpenInPlace;

@property (nonatomic, strong) NSDate *unlockedDatabaseWentIntoBackgroundAt;
@property SafeMetaData* unlockedDatabase; 
@property BOOL appLockSuppressedForBiometricAuth;



@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation SafesViewController

- (void)preHeatSecureEnclave {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        NSLog(@"Pre-Heat Secret Store: [%hhd]", SecretStore.sharedInstance.secureEnclaveAvailable);
    });
}

- (void)customizeUI {
    if (@available(iOS 13.0, *)) { 
        [self.buttonPreferences setImage:[UIImage systemImageNamed:@"gear"]];
    }

    [self.buttonPreferences setAccessibilityLabel:NSLocalizedString(@"audit_drill_down_section_header_preferences", @"Preferences")];
    [self.buttonCustomizeView setAccessibilityLabel:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View")];
    [self.buttonAddSafe setAccessibilityLabel:NSLocalizedString(@"casg_add_action", @"Add")];
    self.collection = [NSArray array];
    [self setupTableview];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self preHeatSecureEnclave]; 
    
    [self customizeUI];
    
    [self checkForPreviousCrash];

    [self internalRefresh];
    
    [self setFreeTrialEndDateBasedOnIapPurchase]; 

    
    
    [self migrateOfflineDetectedBehaviour]; 
    
    [self listenToNotifications];
    
    if([AppPreferences.sharedInstance getLaunchCount] == 1) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self doOnboarding]; 
        });
    }




    else {
        if ( ![self isAppLocked] ) {
            NSLog(@"Initial Activation/Load - App is not Locked...");
            [self doAppActivationTasks:NO];
        }
    }
}

- (void)migrateOfflineDetectedBehaviour {
    if ( !AppPreferences.sharedInstance.migratedOfflineDetectedBehaviour ) {
        NSLog(@"migrateOfflineDetectedBehaviour...");
        AppPreferences.sharedInstance.migratedOfflineDetectedBehaviour = YES;
        
        for (SafeMetaData* database in self.collection) {
            database.offlineDetectedBehaviour = database.immediateOfflineOfferIfOfflineDetected ? kOfflineDetectedBehaviourAsk : kOfflineDetectedBehaviourTryConnectThenAsk;
            [SafesList.sharedInstance update:database];
        }
    }
}

- (NSString*)getCrashMessage {
    NSString* loc = NSLocalizedString(@"safes_vc_please_send_crash_report", @"Please send this crash to support@strongboxsafe.com");
    NSString* message = [NSString stringWithFormat:@"%@\n\n%@", loc, [DebugHelper getCrashEmailDebugString]];
    
    return message;
}

- (void)sharePreviousCrash {
    NSString* message = [self getCrashMessage];
    
    NSArray *activityItems = @[
                               message];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];

    
    activityViewController.popoverPresentationController.barButtonItem = self.buttonAddSafe; 
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) { }];


    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)copyPreviousCrashToClipboard {
    NSString* message = [self getCrashMessage];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setString:message];
 }

- (void)checkForPreviousCrash {
    if ([NSFileManager.defaultManager fileExistsAtPath:FileManager.sharedInstance.crashFile.path]) {
        [NSFileManager.defaultManager removeItemAtURL:FileManager.sharedInstance.archivedCrashFile error:nil];
        [NSFileManager.defaultManager moveItemAtURL:FileManager.sharedInstance.crashFile toURL:FileManager.sharedInstance.archivedCrashFile error:nil];

        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"crash_diagnostics_share_last_title", @"Share Crash Diagnostics?")
                             message:NSLocalizedString(@"crash_diagnostics_share_last_message", @"It looks like Strongbox had a crash last time. Would you be so kind as to share the diagnostics with Strongbox Support?\n\nPlease mail to support@strongboxsafe.com")
                   defaultButtonText:NSLocalizedString(@"crash_diagnostics_share_action", @"Share")
                    secondButtonText:NSLocalizedString(@"crash_diagnostics_copy_action", @"Copy to Clipboard")
                              action:^(int response) {
            if ( response == 0 ) {
                [self sharePreviousCrash];
            }
            else if ( response == 1 ) {
                [self copyPreviousCrashToClipboard];
            }
        }];
    }
}

- (void)doOnboarding {
    if (AppPreferences.sharedInstance.isProOrFreeTrial) {
        NSLog(@"New User is already Pro or in Free Trial... Standard Onboarding");
        [self startOnboarding];
    }
    else { 
        NSLog(@"New User is not pro or in a free trial... Prompt for free trial opt in");

        [self promptToOptInToFreeTrial];
    }
}

- (void)promptToOptInToFreeTrial {
    [self performSegueWithIdentifier:@"segueToFreemiumOnboarding" sender:nil];
}

- (void)onOptInToFreeTrialPromptDone:(BOOL)purchasedOrRestoredFreeTrial {
    if (purchasedOrRestoredFreeTrial) {
        NSLog(@"Successful Restoration or Free Trial Purchase!");
        [self setFreeTrialEndDateBasedOnIapPurchase];
        [self bindProOrFreeTrialUi];
    }
    
    
    
    [self performSegueWithIdentifier:@"segueToWelcome" sender:nil];
}

- (void)setFreeTrialEndDateBasedOnIapPurchase {
    NSDate* freeTrialPurchaseDate = ProUpgradeIAPManager.sharedInstance.freeTrialPurchaseDate;
    if (freeTrialPurchaseDate) {
        NSLog(@"setFreeTrialEndDateBasedOnIapPurchase: [%@]", freeTrialPurchaseDate);
        NSDate* endDate = [AppPreferences.sharedInstance calculateFreeTrialEndDateFromDate:freeTrialPurchaseDate];
        AppPreferences.sharedInstance.freeTrialEnd = endDate;
    }
    else {

    }
}

- (void)startOnboarding {
    [self performSegueWithIdentifier:@"segueToWelcome" sender:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    [self.navigationController setNavigationBarHidden:NO];
    
    [self setupTips];
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    [self bindProOrFreeTrialUi];
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self internalRefresh];
    });
}

- (void)internalRefresh {


    self.collection = SafesList.sharedInstance.snapshot;

    self.tableView.separatorStyle = AppPreferences.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;

    [self.tableView reloadData];
}



- (void)appResignActive {
    NSLog(@"appResignActive");
    
    self.appLockSuppressedForBiometricAuth = NO;
    if( AppPreferences.sharedInstance.suppressAppBackgroundTriggers ) {
        NSLog(@"appResignActive... suppressAppBackgroundTriggers");
        self.appLockSuppressedForBiometricAuth = YES;
        return;
    }

    self.unlockedDatabaseWentIntoBackgroundAt = [[NSDate alloc] init];
}

- (void)appBecameActive {
    NSLog(@"SafesViewController - appBecameActive");
    
    if( self.appLockSuppressedForBiometricAuth ) {
        NSLog(@"App Active but Lock Screen Suppressed... Nothing to do");
        self.appLockSuppressedForBiometricAuth = NO;
        return;
    }

    
    
    
    [SafesList.sharedInstance reloadIfChangedByOtherComponent];
    self.collection = SafesList.sharedInstance.snapshot;
    [SyncManager.sharedInstance backgroundSyncOutstandingUpdates];
    [self refresh]; 

    
    
    if ( [self shouldLockUnlockedDatabase] ) {
        [self lockUnlockedDatabase:nil];
    }
      




        if ( ![self isAppLocked] ) {
            NSLog(@"XXXXXXXXX - appBecameActive - App is not locked - Doing App Activation Tasks.");
            [self doAppActivationTasks:NO];

    }
}

- (void)onAppLockScreenWillBeDismissed:(void (^)(void))completion {
    NSLog(@"XXXXXXXXXXXXXXXXXX - onAppLockWillBeDismissed");

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
    NSLog(@"XXXXXXXXXXXXXXXXXX - onAppLockWasDismissed [%hhd]", userJustCompletedBiometricAuthentication);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self doAppActivationTasks:userJustCompletedBiometricAuthentication];
    });
}

- (BOOL)shouldLockUnlockedDatabase {
    if ( self.unlockedDatabaseWentIntoBackgroundAt && self.unlockedDatabase ) {
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

- (void)onDeviceLocked {
    NSLog(@"onDeviceLocked - Device Lock detected - locking open database if so configured...");
    
    if ( self.unlockedDatabase && self.unlockedDatabase.autoLockOnDeviceLock ) {
        [self lockUnlockedDatabase:nil];
    }
}

- (BOOL)isAppLocked {
    AppDelegate* appDelegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
    return appDelegate.isAppLocked;
}

- (void)lockUnlockedDatabase:(void (^ __nullable)(void))completion {
    if (self.unlockedDatabase) {
        NSLog(@"Locking Unlocked Database...");
                
        if ( ![self isAppLocked] ) {
            NSLog(@"lockUnlockedDatabase: App is not locked... we can lock");
            
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



- (void)doAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication {
    

    if(!self.enqueuedImportUrl) {
        [self checkICloudAvailabilityAndPerformAppActivationTasks:userJustCompletedBiometricAuthentication];
    }
    else {
        [self processEnqueuedImport];
    }
}

- (void)checkICloudAvailabilityAndPerformAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication {
    [self checkICloudAvailability:userJustCompletedBiometricAuthentication isAppActivation:YES];
}

- (void)checkICloudAvailability:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation {
    NSLog(@"checkICloudAvailability... App Activate: [%d]", isAppActivation);
    [[iCloudSafesCoordinator sharedInstance] initializeiCloudAccessWithCompletion:^(BOOL available) {
        AppPreferences.sharedInstance.iCloudAvailable = available;
        
        if (!AppPreferences.sharedInstance.iCloudAvailable) {
            NSLog(@"iCloud Not Available...");
            [self onICloudNotAvailable:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
        }
        else {

            [self onICloudAvailable:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
        }
    }];
}

- (void)onICloudNotAvailable:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation {
    
    AppPreferences.sharedInstance.iCloudPrompted = NO;
    
    if ([AppPreferences.sharedInstance iCloudWasOn] &&  [self getICloudSafes].count) {
        [Alerts warn:self
               title:NSLocalizedString(@"safesvc_icloud_no_longer_available_title", @"iCloud no longer available")
             message:NSLocalizedString(@"safesvc_icloud_no_longer_available_message", @"iCloud has become unavailable. Your iCloud database remain stored in iCloud but they will no longer sync to or from this device though you may still access them here.")];
        
        
        
        
        
    }
    
    
    [AppPreferences sharedInstance].iCloudOn = NO;
    AppPreferences.sharedInstance.iCloudWasOn = NO;
    
    [self onICloudCheckDone:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
}

- (void)onICloudAvailable:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation{
    if (!AppPreferences.sharedInstance.iCloudOn && !AppPreferences.sharedInstance.iCloudPrompted) {
        BOOL existingLocalDeviceSafes = [self getLocalDeviceSafes].count > 0;
        BOOL hasOtherCloudSafes = [self hasSafesOtherThanLocalAndiCloud];
        
        if (!existingLocalDeviceSafes && !hasOtherCloudSafes) { 
                                                                
            [self onICloudAvailableContinuation:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
            return;
        }
        else if (self.presentedViewController == nil) {
            NSString* strA = NSLocalizedString(@"safesvc_migrate_local_existing", @"You can now use iCloud with Strongbox. Should your current local databases be migrated to iCloud and available on all your devices? (NB: Your existing cloud databases will not be affected)");
            NSString* strB = NSLocalizedString(@"safesvc_migrate_local_no_existing", @"You can now use iCloud with Strongbox. Should your current local databases be migrated to iCloud and available on all your devices?");
            NSString* str1 = NSLocalizedString(@"safesvc_use_icloud_question_existing", @"Would you like the option to use iCloud with Strongbox? (NB: Your existing cloud databases will not be affected)");
            NSString* str2 = NSLocalizedString(@"safesvc_use_icloud_question_no_existing", @"You can now use iCloud with Strongbox. Would you like to have your databases available on all your devices?");
            
            NSString *message = existingLocalDeviceSafes ? (hasOtherCloudSafes ? strA : strB) : (hasOtherCloudSafes ? str1 : str2);
            
            [Alerts twoOptions:self
                         title:NSLocalizedString(@"safesvc_icloud_now_available_title", @"iCloud is Now Available")
                       message:message
             defaultButtonText:NSLocalizedString(@"safesvc_option_use_icloud", @"Use iCloud")
              secondButtonText:NSLocalizedString(@"safesvc_option_local_only", @"Local Only")
                        action:^(BOOL response) {
                            if(response) {
                                AppPreferences.sharedInstance.iCloudOn = YES;
                            }
                            AppPreferences.sharedInstance.iCloudPrompted = YES;
                            [self onICloudAvailableContinuation:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
                        }];
        }
    }
    else {
        [self onICloudAvailableContinuation:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
    }
}

- (void)onICloudAvailableContinuation:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation {
    BOOL iCloudOn = AppPreferences.sharedInstance.iCloudOn;
    BOOL iCloudWasOn = AppPreferences.sharedInstance.iCloudWasOn;
    BOOL hasLocalDatabases = [self getLocalDeviceSafes].count != 0;
    
    
    if (iCloudOn && !iCloudWasOn && hasLocalDatabases) {
        [Alerts twoOptions:self
                     title:NSLocalizedString(@"safesvc_icloud_available_title", @"iCloud Available")
                   message:NSLocalizedString(@"safesvc_question_migrate_local_to_icloud", @"Would you like to migrate your current local device databases to iCloud?")
         defaultButtonText:NSLocalizedString(@"safesvc_option_migrate_to_icloud", @"Migrate to iCloud")
          secondButtonText:NSLocalizedString(@"safesvc_option_keep_local", @"Keep Local")
                    action:^(BOOL response) {
                        if(response) {
                            [[iCloudSafesCoordinator sharedInstance] migrateLocalToiCloud:^(BOOL show) {
                                [self showiCloudMigrationUi:show];
                            }];
                        }
                    }];
    }
    
    
    
    BOOL hasICloudDatabases = [self getICloudSafes].count != 0;
    if (!iCloudOn && iCloudWasOn && hasICloudDatabases) {
        [Alerts threeOptions:self
                       title:NSLocalizedString(@"safesvc_icloud_unavailable_title", @"iCloud Unavailable")
                     message:NSLocalizedString(@"safesvc_icloud_unavailable_question", @"What would you like to do with the databases currently on this device?")
           defaultButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_remove", @"Remove them, Keep on iCloud Only")
            secondButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_make_local", @"Make Local Copies")
             thirdButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_icloud_on", @"Switch iCloud Back On")
                      action:^(int response) {
                          if(response == 2) {           
                              [AppPreferences sharedInstance].iCloudOn = YES;
                              AppPreferences.sharedInstance.iCloudWasOn = [AppPreferences sharedInstance].iCloudOn;
                          }
                          else if(response == 1) {      
                              [[iCloudSafesCoordinator sharedInstance] migrateiCloudToLocal:^(BOOL show) {
                                  [self showiCloudMigrationUi:show];
                              }];
                          }
                          else if(response == 0) {
                              [self removeAllICloudSafes];
                          }
                      }];
    }
    
    AppPreferences.sharedInstance.iCloudWasOn = AppPreferences.sharedInstance.iCloudOn;
    [[iCloudSafesCoordinator sharedInstance] startQuery];
    
    [self onICloudCheckDone:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
}

- (void)onICloudCheckDone:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation {
    if(isAppActivation) {
        [self continueAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication];
    }
}

- (void)continueAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication {
    NSLog(@"continueAppActivationTasks...");
    
    if([self isVisibleViewController]) {
        BOOL userHasLocalDatabases = [self getLocalDeviceSafes].firstObject != nil;



        
        if (!AppPreferences.sharedInstance.haveAskedAboutBackupSettings && userHasLocalDatabases) {
            [self promptForBackupSettings];
        }
        



        else if ( AppPreferences.sharedInstance.quickLaunchUuid ) {
            [self openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
        }
    }
}














- (void)promptForBackupSettings {
    NSString* title = NSLocalizedString(@"backup_settings_prompt_title", @"Backup Settings");
    NSString* message = NSLocalizedString(@"backup_settings_prompt_message", @"By Default Strongbox now includes all your local documents and databases in Apple backups, however imported Key Files are explicitly not included for security reasons.\n\nYou can change these settings at any time in Preferences > Advanced Preferences.\n\nDoes this sound ok?");
    NSString* option1 = NSLocalizedString(@"backup_settings_prompt_option_yes_looks_good", @"Yes, the defaults sound good");
    NSString* option2 = NSLocalizedString(@"backup_settings_prompt_yes_but_include_key_files", @"Yes, but also backup Key Files");
    NSString* option3 = NSLocalizedString(@"backup_settings_prompt_no_dont_backup_anything", @"No, do NOT backup anything");
    
    [Alerts threeOptionsWithCancel:self title:title
                           message:message defaultButtonText:option1 secondButtonText:option2 thirdButtonText:option3 action:^(int response) {
        NSLog(@"Selected: %d", response);
        if (response == 0) {
            AppPreferences.sharedInstance.backupFiles = YES;
            AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = NO;
        }
        else if (response == 1) {
            AppPreferences.sharedInstance.backupFiles = YES;
            AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = YES;
        }
        else if (response == 2) {
            AppPreferences.sharedInstance.backupFiles = NO;
            AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = NO;
        }
        
        if (response != 3) {
            [FileManager.sharedInstance setDirectoryInclusionFromBackup:AppPreferences.sharedInstance.backupFiles
                                                       importedKeyFiles:AppPreferences.sharedInstance.backupIncludeImportedKeyFiles];
            
            AppPreferences.sharedInstance.haveAskedAboutBackupSettings = YES;
        }
    }];
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

    NSLog(@"VISIBLE: [%@]", visibleSoFar);
    
    return visibleSoFar;
}

- (BOOL)isVisibleViewController {
    UIViewController* visible =[self getVisibleViewController];
    BOOL ret = visible == self;

    NSLog(@"isVisibleViewController: %d [Actual Visible: [%@]]", ret, visible);
    
    return ret;
}

- (void)processEnqueuedImport {
    if(!self.enqueuedImportUrl) {
        return;
    }
    
    
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSURL* copy = self.enqueuedImportUrl;
    self.enqueuedImportUrl = nil;
    [self import:copy canOpenInPlace:self.enqueuedImportCanOpenInPlace forceOpenInPlace:NO];
}

- (void)listenToNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotificationKey
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
}

- (void)onDatabaseUpdated:(id)param {
    NSNotification* notification = param;
    NSString* databaseId = notification.object;
        
    NSArray<SafeMetaData*>* newColl = SafesList.sharedInstance.snapshot;
    
    if (newColl.count != self.collection.count) { 
        [self refresh];
    }
    else {
        self.collection = newColl; 

        NSUInteger index = [self.collection indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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

    if (@available(iOS 13.0, *)) { 
        
    }
    else {
        self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                    initWithTarget:self
                                    action:@selector(handleLongPress)];
        self.longPressRecognizer.minimumPressDuration = 1;
        self.longPressRecognizer.cancelsTouchesInView = YES;
        [self.tableView addGestureRecognizer:self.longPressRecognizer];
    }
    
    UIRefreshControl* refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(onManualPulldownRefresh) forControlEvents:UIControlEventValueChanged];
    
    if (@available(iOS 10.0, *)) {
        self.tableView.refreshControl = refreshControl;
    }
    else {
        [self.tableView addSubview:refreshControl];
    }
}

- (void)onManualPulldownRefresh {
    [SyncManager.sharedInstance backgroundSyncAll];
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView.refreshControl endRefreshing];
    });
}

- (void)handleLongPress {
    if (!self.tableView.editing) {
        [self setEditing:YES animated:YES];
        
        UIImpactFeedbackGenerator* gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [gen impactOccurred];
    }
}

- (void)setupTips {
    if(AppPreferences.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        if (@available(iOS 13.0, *)) {
            self.navigationItem.prompt = NSLocalizedString(@"hint_tap_and_hold_to_see_options", @"TIP: Tap and hold item to see options");
        }
        else {
            self.navigationItem.prompt = NSLocalizedString(@"safes_vc_tip", @"Tip displayed at top of screen. Slide left on Database for options");
        }
    }
}

- (NSAttributedString*)getEmptyDatasetTitle {
    NSString *text = NSLocalizedString(@"safes_vc_empty_databases_list_tableview_title", @"Title displayed in tableview when there are no databases setup");
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString*)getEmptyDatasetDescription {
    NSString *text = NSLocalizedString(@"safes_vc_empty_databases_list_tableview_subtitle", @"Subtitle displayed in tableview when there are no databases setup");

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{NSFontAttributeName: FontManager.sharedInstance.regularFont,
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString*)getEmptyDatasetButtonTitle {
    NSDictionary *attributes = @{
                                    NSFontAttributeName : FontManager.sharedInstance.regularFont,
                                    NSForegroundColorAttributeName : UIColor.systemBlueColor,
                                    };
    
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"safes_vc_empty_databases_list_get_started_button_title", @"Subtitle displayed in tableview when there are no databases setup") attributes:attributes];
}

#pragma mark - Table view data source

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        [SafesList.sharedInstance move:sourceIndexPath.row to:destinationIndexPath.row];
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
                         buttonAction:^{
            [weakSelf startOnboarding];
        }];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }
    
    return self.collection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];

    SafeMetaData *database = [self.collection objectAtIndex:indexPath.row];

    [cell populateCell:database];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        return;
    }
    
    [self openAtIndexPath:indexPath openOffline:NO];
}



- (void)manualUnlock:(NSIndexPath*)indexPath {
    [self openAtIndexPath:indexPath openOffline:NO manualUnlock:YES ignoreForceOpenOffline:NO];
}

- (void)openOffline:(NSIndexPath*)indexPath {
    [self openAtIndexPath:indexPath openOffline:YES];
}

- (void)forceOpenOnline:(NSIndexPath*)indexPath {
    [self openAtIndexPath:indexPath openOffline:NO manualUnlock:NO ignoreForceOpenOffline:YES];
}

- (void)openAtIndexPath:(NSIndexPath*)indexPath openOffline:(BOOL)openOffline {
    [self openAtIndexPath:indexPath openOffline:openOffline manualUnlock:NO ignoreForceOpenOffline:NO];
}

- (void)openAtIndexPath:(NSIndexPath*)indexPath openOffline:(BOOL)openOffline manualUnlock:(BOOL)manualUnlock ignoreForceOpenOffline:(BOOL)ignoreForceOpenOffline {
    SafeMetaData *database = [self.collection objectAtIndex:indexPath.row];

    if ( !ignoreForceOpenOffline ) {
        openOffline |= database.forceOpenOffline;
    }
    
    [self openDatabase:database openOffline:openOffline noConvenienceUnlock:manualUnlock biometricPreCleared:NO];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(SafeMetaData*)database {
    [self openDatabase:database biometricPreCleared:NO];
}

- (void)openDatabase:(SafeMetaData*)database biometricPreCleared:(BOOL)biometricPreCleared {
    [self openDatabase:database openOffline:database.forceOpenOffline noConvenienceUnlock:NO biometricPreCleared:biometricPreCleared];
}

- (void)openDatabase:(SafeMetaData*)safe
         openOffline:(BOOL)openOffline
 noConvenienceUnlock:(BOOL)noConvenienceUnlock
 biometricPreCleared:(BOOL)biometricPreCleared {
    NSLog(@"======================== OPEN DATABASE: %@ ============================", safe);
    
    biometricPreCleared = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics && biometricPreCleared;
    
    if(safe.hasUnresolvedConflicts) { 
        [self performSegueWithIdentifier:@"segueToVersionConflictResolution" sender:safe.fileIdentifier];
    }
    else {
        UnlockDatabaseSequenceHelper* helper = [UnlockDatabaseSequenceHelper helperWithViewController:self database:safe isAutoFillOpen:NO offlineExplicitlyRequested:openOffline];

        [helper beginUnlockSequence:NO
                biometricPreCleared:biometricPreCleared
                noConvenienceUnlock:noConvenienceUnlock
                         completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
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
                        error:error];
            }
        }];
    }
}



- (void)onboardOrShowUnlockedDatabase:(Model*)model {
    BOOL biometricPossible = BiometricsManager.isBiometricIdAvailable && !AppPreferences.sharedInstance.disallowAllBiometricId;
    BOOL pinPossible = !AppPreferences.sharedInstance.disallowAllPinCodeOpens;

    BOOL conveniencePossible = [AppPreferences.sharedInstance isProOrFreeTrial] && (biometricPossible || pinPossible);
    BOOL convenienceNotYetPrompted = !model.metadata.hasBeenPromptedForConvenience;
    
    BOOL quickLaunchPossible = AppPreferences.sharedInstance.quickLaunchUuid == nil;
    BOOL quickLaunchNotYetPrompted = !model.metadata.hasBeenPromptedForQuickLaunch;
    
    
    
    
    
    
    
    
    
    if (conveniencePossible && convenienceNotYetPrompted) {
        [self promptForConvenienceEnrolAndOpen:biometricPossible pinPossible:pinPossible model:model];
    }
    else if (quickLaunchPossible && quickLaunchNotYetPrompted) {
        [self promptForQuickLaunch:model];
    }
    else {
        [self showUnlockedDatabase:model];
    }
}

- (void)showUnlockedDatabase:(Model*)model {
    if (@available(iOS 11.0, *)) { 
        [self performSegueWithIdentifier:@"segueToMasterDetail" sender:model];
    }
    else {
        [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:model];
    }
}





- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:kNilOptions
                            children:@[
            [self getContextualMenuDatabaseNonMutatatingActions:indexPath],
            [self getContextualMenuDatabaseActions:indexPath],
            [self getContextualMenuDatabaseStateActions:indexPath],
        ]];
    }];
}

- (UIAction*)getContextualViewBackupsAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)) {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"safes_vc_action_backups", @"Button Title to view backup settings of this database")
                                    systemImage:@"clock" 
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToBackups" sender:safe];
    }];

    return ret;
}

- (UIAction*)getContextualViewSyncLogAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"safes_vc_action_view_sync_status", @"Button Title to view sync log for this database")
                                    systemImage:@"arrow.clockwise.icloud" 
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
    }];

    return ret;
}

- (UIMenu*)getContextualMenuDatabaseNonMutatatingActions:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    BOOL conveniencePossible = safe.isEnrolledForConvenience && AppPreferences.sharedInstance.isProOrFreeTrial;
    if (conveniencePossible) [ma addObject:[self getContextualMenuUnlockManualAction:indexPath]];

    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe];

    
    
    if ( safe.forceOpenOffline ) {
        if (safe.storageProvider != kLocalDevice) {
            [ma addObject:[self getContextualMenuOpenOnlineAction:indexPath]];
        }
    }
    else {
        BOOL localCopyAvailable = safe.storageProvider != kLocalDevice && localCopyUrl != nil && !safe.forceOpenOffline;
        if (localCopyAvailable) [ma addObject:[self getContextualMenuOpenOfflineAction:indexPath]];
    }
    
    
    
    BOOL shareAllowed = !AppPreferences.sharedInstance.hideExportFromDatabaseContextMenu && localCopyUrl != nil;
    if (shareAllowed) [ma addObject:[self getContextualShareAction:indexPath]];

    if (self.collection.count > 1) {
        [ma addObject:[self getContextualReOrderDatabasesAction:indexPath]];
    }
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualReOrderDatabasesAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)) {
    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"safes_vc_action_reorder_database", @"Button Title to reorder this database")
                                    systemImage:@"arrow.up.arrow.down"
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self setEditing:YES];
    }];

    return ret;
}

- (UIMenu*)getContextualMenuDatabaseStateActions:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    BOOL makeVisible = safe.storageProvider == kLocalDevice;
    if (makeVisible) [ma addObject:[self getContextualMenuMakeVisibleAction:indexPath]];

    [ma addObject:[self getContextualMenuQuickLaunchAction:indexPath]];
    
    if ( safe.autoFillEnabled ) {
        [ma addObject:[self getContextualMenuAutoFillQuickLaunchAction:indexPath]];
    }
    
    [ma addObject:[self getContextualMenuReadOnlyAction:indexPath]];
    [ma addObject:[self getContextualMenuPropertiesAction:indexPath]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIMenu*)getContextualMenuDatabaseActions:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    SafeMetaData *safe = self.collection[indexPath.row];

    [ma addObject:[self getContextualMenuRenameAction:indexPath]];

    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe];
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

- (UIAction*)getContextualShareAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"generic_export", @"Export")
                                    systemImage:@"square.and.arrow.up"
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self onShare:indexPath];
    }];

    return ret;
}

- (UIAction*)getContextualMenuMakeVisibleAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)){
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    BOOL shared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safe];
    NSString* localDeviceActionTitle = shared ?
        NSLocalizedString(@"safes_vc_show_in_files", @"Button Title to Show in iOS Files Browser") :
        NSLocalizedString(@"safes_vc_make_autofillable", @"Button Title to Hide from iOS Files Browser");

    UIAction* ret = [self getContextualMenuItem:localDeviceActionTitle
                                    systemImage:shared ? @"eye" : @"eye.slash"
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self promptAboutToggleLocalStorage:indexPath shared:shared];
    }];
   
    return ret;
}

- (UIAction*)getContextualMenuQuickLaunchAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)){
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL isAlreadyQuickLaunch = [AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid];
    
    NSString* title = NSLocalizedString(@"databases_toggle_quick_launch_context_menu", @"Quick Launch");
    
    UIAction* ret = [self getContextualMenuItem:title
                                 image:[UIImage imageNamed:@"rocket"]
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self toggleQuickLaunch:safe];
    }];
   
    ret.state = isAlreadyQuickLaunch ? UIMenuElementStateOn : UIMenuElementStateOff;
   
    return ret;
}

- (UIAction*)getContextualMenuAutoFillQuickLaunchAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)){
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL isAlreadyQuickLaunch = [AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:safe.uuid];
    
    NSString* title = NSLocalizedString(@"databases_toggle_autofill_quick_launch_context_menu", @"AutoFill Quick Launch");
    
    UIAction* ret = [self getContextualMenuItem:title
                                 image:[UIImage imageNamed:@"globe"]
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self toggleAutoFillQuickLaunch:safe];
    }];
   
    ret.state = isAlreadyQuickLaunch ? UIMenuElementStateOn : UIMenuElementStateOff;
   
    return ret;
}

- (UIAction*)getContextualMenuPropertiesAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString* title = NSLocalizedString(@"browse_vc_action_properties", @"Properties");
    
    UIAction* ret = [self getContextualMenuItem:title
                                 image:[UIImage systemImageNamed:@"list.bullet"]
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self showDatabaseProperties:safe];
    }];
       
    return ret;
}

- (UIAction*)getContextualMenuReadOnlyAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString* title = NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read Only");
    
    UIAction* ret = [self getContextualMenuItem:title
                                 image:[UIImage systemImageNamed:@"eyeglasses"]
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self toggleReadOnly:safe];
    }];
    
    ret.state = safe.readOnly ? UIMenuElementStateOn : UIMenuElementStateOff;
   
    return ret;
}

- (UIAction*)getContextualMenuUnlockManualAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"safes_vc_unlock_manual_action", @"Open ths database manually bypassing any convenience unlock")
                           systemImage:@"lock.open"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self manualUnlock:indexPath];
    }];
}

- (UIAction*)getContextualMenuOpenOfflineAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"safes_vc_slide_left_open_offline_action", @"Open ths database offline table action")
                           systemImage:@"bolt.horizontal.circle"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self openOffline:indexPath];
    }];
}

- (UIAction*)getContextualMenuOpenOnlineAction:(NSIndexPath*)indexPath API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"safes_vc_slide_left_open_online_action", @"Open this database online action")
                           systemImage:@"bolt.horizontal.circle"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self forceOpenOnline:indexPath];
    }];
}

- (UIAction*)getContextualMenuRenameAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"generic_rename", @"Rename")
                           systemImage:@"pencil"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self renameSafe:indexPath];
    }];
}
    
- (UIAction*)getContextualMenuCreateLocalCopyAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    UIImage* img = Platform.iOS13Available ? [UIImage systemImageNamed:@"doc.on.doc"] : [UIImage imageNamed:@"copy"];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"generic_action_create_local_database", @"Create Local Copy") 
                                 image:img
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self createLocalCopyDatabase:safe];
    }];

    




    
    return ret;
}

- (UIAction*)getContextualMenuMergeAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    UIImage* img = Platform.iOS14Available ? [UIImage systemImageNamed:@"arrow.triangle.merge"] : [UIImage imageNamed:@"paper_plane"];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    return [self getContextualMenuItem:NSLocalizedString(@"generic_action_compare_and_merge_ellipsis", @"Compare & Merge...")
                                 image:img
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self beginMergeWizard:safe];
    }];
}

- (UIAction*)getContextualMenuRemoveAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"generic_remove", @"Remove")
                           systemImage:@"trash"
                           destructive:YES
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self removeSafe:indexPath];
    }];
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*)systemImage destructive:(BOOL)destructive handler:(UIActionHandler)handler
  API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:title
                                 image:[UIImage systemImageNamed:systemImage]
                           destructive:destructive
                               handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title image:(UIImage*)image destructive:(BOOL)destructive handler:(UIActionHandler)handler
  API_AVAILABLE(ios(13.0)){
    UIAction *ret = [UIAction actionWithTitle:title
                                        image:image
                                   identifier:nil
                                      handler:handler];

    if (destructive) {
        ret.attributes = UIMenuElementAttributesDestructive;
    }
    
    return ret;
}



- (void)onShare:(NSIndexPath*)indexPath {
    SafeMetaData *database = [self.collection objectAtIndex:indexPath.row];

    if (!database) {
        return;
    }
    
    NSString* filename = database.fileName;
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database];
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

    

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    UITableViewRowAction *onOrOfflineAction = nil;
    if ( safe.forceOpenOffline ) {
        if (safe.storageProvider != kLocalDevice) {
            onOrOfflineAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                   title:NSLocalizedString(@"safes_vc_slide_left_open_online_action", @"Open this database online action")
                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                [self forceOpenOnline:indexPath];
            }];
            onOrOfflineAction.backgroundColor = [UIColor systemGreenColor];
        }
    }
    else {
        BOOL offlineOption = safe.storageProvider != kLocalDevice && [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safe modified:nil];
        if ( offlineOption ) {
            onOrOfflineAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                   title:NSLocalizedString(@"safes_vc_slide_left_open_offline_action", @"Open this database offline table action")
                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                [self openOffline:indexPath];
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
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

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
    
    
    
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe];
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

- (void)toggleAutoFillQuickLaunch:(SafeMetaData*)database {
    if([AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:database.uuid]) {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = nil;
        [self refresh];
    }
    else {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = database.uuid;
        [self refresh];
    }
}

- (void)toggleQuickLaunch:(SafeMetaData*)database {
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

- (void)toggleReadOnly:(SafeMetaData*)database {
    database.readOnly = !database.readOnly;
    [SafesList.sharedInstance update:database];
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
    SafeMetaData* metadata = [self.collection objectAtIndex:indexPath.row];

    NSError* error;
    if (![SyncManager.sharedInstance toggleLocalDatabaseFilesVisibility:metadata error:&error]) {
        [Alerts error:self title:NSLocalizedString(@"safes_vc_could_not_change_storage_location_error", @"error message could not change local storage") error:error];
    }
}

- (void)renameSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *database = [self.collection objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"segueToRenameDatabase" sender:database];
}

- (void)removeSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString *message;
    
    if(safe.storageProvider == kiCloud && [AppPreferences sharedInstance].iCloudOn) {
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

- (void)removeAndCleanupSafe:(SafeMetaData *)safe {
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

    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    
    
    
    if([AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid]) {
        AppPreferences.sharedInstance.quickLaunchUuid = nil;
    }

    if([AppPreferences.sharedInstance.autoFillQuickLaunchUuid isEqualToString:safe.uuid]) {
        AppPreferences.sharedInstance.autoFillQuickLaunchUuid = nil;
    }

    
    
    [BackupsManager.sharedInstance deleteAllBackups:safe];
    
    [[SafesList sharedInstance] remove:safe.uuid];
}



- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToMasterDetail"] || [segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc;
        if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
            vc = segue.destinationViewController;
        }
        else {
            MasterDetailViewController *svc = segue.destinationViewController;
            svc.viewModel = (Model*)sender;
            
            UINavigationController *nav = [svc.viewControllers firstObject];
            vc = (BrowseSafeView*)nav.topViewController;
        }
        
        vc.viewModel = (Model *)sender;
        vc.currentGroupId = vc.viewModel.database.effectiveRootGroup.uuid;
        self.unlockedDatabase = vc.viewModel.metadata;
    }
    else if ([segue.identifier isEqualToString:@"segueToStorageType"])
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
                [self checkICloudAvailability:NO isAppActivation:NO];
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToRenameDatabase"]) {
        SafeMetaData* database = (SafeMetaData*)sender;
        
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        scVc.mode = kCASGModeRenameDatabase;
        scVc.initialName = database.nickName;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    database.nickName = creds.name;
                    [SafesList.sharedInstance update:database];
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
            scVc.initialName = [SafesList.sharedInstance getUniqueNameFromSuggestedName:suggestion];
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
    else if ([segue.identifier isEqualToString:@"segueToWelcome"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        
        GettingStartedInitialViewController* vc = (GettingStartedInitialViewController*)nav.topViewController;
        vc.onDone = ^(BOOL addExisting, SafeMetaData * _Nonnull databaseToOpen) {
            [self dismissViewControllerAnimated:YES completion:^{
                [self onOnboardingDoneWithAddDatabase:addExisting databaseToOpen:databaseToOpen];
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToFreemiumOnboarding"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        
        WelcomeFreemiumViewController* vc = (WelcomeFreemiumViewController*)nav.topViewController;
        vc.onDone = ^(BOOL purchasedOrRestoredFreeTrial) {
            [self dismissViewControllerAnimated:YES completion:^{
                [self onOptInToFreeTrialPromptDone:purchasedOrRestoredFreeTrial];
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToCreateExpressDone"]) {
        WelcomeCreateDoneViewController* wcdvc = (WelcomeCreateDoneViewController*)segue.destinationViewController;
        
        NSDictionary *d = sender; 
        
        wcdvc.database = d[@"database"];
        wcdvc.password = d[@"password"];
        
        wcdvc.onDone = ^(BOOL addExisting, SafeMetaData * _Nullable databaseToOpen) {
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
        vc.metadata = (SafeMetaData*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToSyncLog"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SyncLogViewController* vc = (SyncLogViewController*)nav.topViewController;
        vc.database = (SafeMetaData*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToUpgrade"]) {
        UIViewController* vc = segue.destinationViewController;
        if (@available(iOS 13.0, *)) {
            if (AppPreferences.sharedInstance.freeTrialHasBeenOptedInAndExpired || AppPreferences.sharedInstance.daysInstalled > 90) {
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.modalInPresentation = YES;
            }
        }
    }
    else if ( [segue.identifier isEqualToString:@"segueToMergeWizard"] ) {
        SafeMetaData* dest = (SafeMetaData*)sender;
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
        SafeMetaData* database = (SafeMetaData*)sender;
        UINavigationController* nav = segue.destinationViewController;
        DatabasePropertiesVC* vc = (DatabasePropertiesVC*)nav.topViewController;
        vc.database = database;
    }
}

- (void)mergeDatabases:(Model*)first second:(Model*)second {
    NSString* msg = NSLocalizedString(@"merge_view_are_you_sure", @"Are you sure you want to merge the second database into the first?");
    [Alerts areYouSure:self message:msg action:^(BOOL response) {
        if (response) {
            DatabaseMerger* syncer= [DatabaseMerger mergerFor:first.database theirs:second.database];
            BOOL success = [syncer merge];

            if (success) {
                [first update:self handler:^(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error) {
                    if (error) {
                        [Alerts error:self error:error];
                    }
                    else if (userCancelled) {
                        [Alerts error:self
                                title:NSLocalizedString(@"merge_view_merge_title_error", @"There was an problem merging this database.")
                                error:nil];
                    }
                    else {
                        [Alerts info:self
                               title:NSLocalizedString(@"merge_view_merge_title_success", @"Merge Successful")
                             message:NSLocalizedString(@"merge_view_merge_message_success", @"The Merge was successful and your database is now up to date.")];
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

- (void)onOnboardingDoneWithAddDatabase:(BOOL)addExisting
                         databaseToOpen:(SafeMetaData*)databaseToOpen {
    if(addExisting) {
        
        

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if([SafesList.sharedInstance getSafesOfProvider:kiCloud].count) {
                    [Alerts twoOptionsWithCancel:self
                                           title:NSLocalizedString(@"safes_vc_found_icloud_database", @"Informational message title - found an iCloud Database")
                                         message:NSLocalizedString(@"safes_vc_use_icloud_or_continue", @"question message, use iCloud database or select a different one")
                               defaultButtonText:NSLocalizedString(@"safes_vc_use_this_icloud_database", @"One of the options in response to prompt - Use this iCloud database")
                                secondButtonText:NSLocalizedString(@"safes_vc_add_another", @"Second option - Select another database")
                                          action:^(int response) {
                                              if(response == 1) {
                                                  [self onAddExistingSafe];
                                              }
                                          }];
                }
                else {
                    [self onAddExistingSafe];
                }
        });
    }
    else if(databaseToOpen) {
        [self openDatabase:databaseToOpen];
    }
}

- (void)onCreateOrAddDialogDismissedSuccessfully:(SelectedStorageParameters*)storageParams
                                     credentials:(CASGParams*)credentials {
    BOOL expressMode = storageParams == nil;
    
    if(expressMode || storageParams.createMode) {
        if(expressMode) {
            [self onCreateNewExpressDatabaseDone:credentials.name
                                        password:credentials.password];
        }
        else {
            [self onCreateNewDatabaseDone:storageParams
                                     name:credentials.name
                                 password:credentials.password
                          keyFileBookmark:credentials.keyFileBookmark
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
        SafeMetaData* database = [storageParams.provider getSafeMetaData:name providerData:storageParams.file.providerData];
        database.likelyFormat = storageParams.likelyFormat;
        
        if(database == nil) {
            [Alerts warn:self
                   title:NSLocalizedString(@"safes_vc_error_adding_database", @"Error title: error adding database")
                 message:NSLocalizedString(@"safes_vc_unknown_error_while_adding_database", @"Error Message- unknown error while adding")];
        }
        else {
            [SafesList.sharedInstance add:database initialCache:storageParams.data initialCacheModDate:storageParams.initialDateModified];
        }
    }
}

- (void)onCreateNewDatabaseDone:(SelectedStorageParameters*)storageParams
                           name:(NSString*)name
                       password:(NSString*)password
                keyFileBookmark:(NSString*)keyFileBookmark
                 onceOffKeyFile:(NSData*)onceOffKeyFile
                  yubiKeyConfig:(YubiKeyHardwareConfiguration*)yubiKeyConfig
                         format:(DatabaseFormat)format {
    [AddNewSafeHelper createNewDatabase:self
                                   name:name
                               password:password
                        keyFileBookmark:keyFileBookmark
                     onceOffKeyFileData:onceOffKeyFile
                          yubiKeyConfig:yubiKeyConfig
                          storageParams:storageParams
                                 format:format
                             completion:^(BOOL userCancelled, SafeMetaData * _Nullable metadata, NSData * _Nonnull initialSnapshot, NSError * _Nullable error) {
        if (userCancelled) {
            
        }
        else if (error || !metadata) {
            [Alerts error:self
                    title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error creating database")
                    error:error];
        }
        else {
            [self addDatabaseWithiCloudRaceCheck:metadata initialCache:initialSnapshot initialCacheModDate:NSDate.date];
        }
    }];
}

- (void)onCreateNewExpressDatabaseDone:(NSString*)name
                              password:(NSString*)password {
    [AddNewSafeHelper createNewExpressDatabase:self
                                          name:name
                                      password:password
                                    completion:^(BOOL userCancelled, SafeMetaData * _Nonnull metadata, NSData * _Nonnull initialSnapshot, NSError * _Nonnull error) {
        if (userCancelled) {
            
        }
        else if(error || !metadata) {
            [Alerts error:self
                    title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error while creating database")
                    error:error];
        }
        else {
            metadata = [self addDatabaseWithiCloudRaceCheck:metadata initialCache:initialSnapshot initialCacheModDate:NSDate.date];
            [self performSegueWithIdentifier:@"segueToCreateExpressDone"
                                      sender:@{@"database" : metadata, @"password" : password }];
        }
    }];
}

- (SafeMetaData*)addDatabaseWithiCloudRaceCheck:(SafeMetaData*)metadata initialCache:(NSData*)initialCache initialCacheModDate:(NSDate*)initialCacheModDate {
    if (metadata.storageProvider == kiCloud) {
        SafeMetaData* existing = [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
            return obj.storageProvider == kiCloud && [obj.fileName compare:metadata.fileName] == NSOrderedSame;
        }];
        
        if(existing) { 
            NSLog(@"Not Adding as this iCloud filename is already present. Probably picked up by Watch Thread.");
            return existing;
        }
    }
    
    [[SafesList sharedInstance] add:metadata initialCache:initialCache initialCacheModDate:initialCacheModDate];
    
    return metadata;
}

- (void)addManuallyDownloadedUrlDatabase:(NSString *)nickName modDate:(NSDate*)modDate data:(NSData *)data {
    if(AppPreferences.sharedInstance.iCloudOn) {
        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"safes_vc_copy_icloud_or_local", @"Question Title: Copy to icloud or to local")
                             message:NSLocalizedString(@"safes_vc_copy_local_to_icloud", @"Question message: copy to iCloud or to Local")
                   defaultButtonText:NSLocalizedString(@"safes_vc_copy_to_local", @"Default button: Copy to Local")
                    secondButtonText:NSLocalizedString(@"safes_vc_copy_to_icloud", @"Second Button: Copy to iCLoud")
                              action:^(int response) {
                                  if(response == 0) {
                                      [self addManualDownloadUrl:NO data:data modDate:modDate nickName:nickName];
                                  }
                                  else if(response == 1) {
                                      [self addManualDownloadUrl:YES data:data modDate:modDate nickName:nickName];
                                  }
                              }];
    }
    else {
        [self addManualDownloadUrl:NO data:data modDate:modDate nickName:nickName];
    }
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
          completion:^(SafeMetaData *metadata, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                [[SafesList sharedInstance] addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:modDate];
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
        [self bindProOrFreeTrialUi];
    });
}

-(void)bindProOrFreeTrialUi {
    self.navigationController.toolbarHidden =  [[AppPreferences sharedInstance] isPro];
    self.navigationController.toolbar.hidden = [[AppPreferences sharedInstance] isPro];
    
    if(![[AppPreferences sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
    
        NSString *upgradeButtonTitle;

        if (AppPreferences.sharedInstance.hasOptedInToFreeTrial) {
            if([[AppPreferences sharedInstance] isFreeTrial]) {
                NSInteger daysLeft = AppPreferences.sharedInstance.freeTrialDaysLeft;
                
                if(daysLeft > 30) {
                    upgradeButtonTitle = [NSString stringWithFormat:NSLocalizedString(@"safes_vc_upgrade_info_button_title", @"Upgrade Button Title - Upgrade Info")];
                }
                else {
                    upgradeButtonTitle = [NSString stringWithFormat:NSLocalizedString(@"safes_vc_upgrade_info_button_title_days_remaining", @"Upgrade Button Title with Days remaining of pro trial version"),
                                      (long)daysLeft];
                }
                
                if(daysLeft < 10) {
                    [self.buttonUpgrade setTintColor:UIColor.systemRedColor];
                }
            }
            else {
                upgradeButtonTitle = NSLocalizedString(@"safes_vc_upgrade_info_button_title_please_upgrade", @"Upgrade Button Title asking to Please Upgrade");
                [self.buttonUpgrade setTintColor:UIColor.systemRedColor];
            }
        }
        else {
            upgradeButtonTitle = NSLocalizedString(@"safes_vc_upgrade_info_trial_available_button_title", @"Upgrade Button Title - Upgrade Info");
            if (AppPreferences.sharedInstance.daysInstalled > 60) {
                [self.buttonUpgrade setTintColor:UIColor.systemRedColor];
            }
        }
        
        if ( SaleScheduleManager.sharedInstance.saleNowOn ) {
            [self.buttonUpgrade setTitle:NSLocalizedString(@"safesvc_upgrade_button_sale_now_on_title", @"🚀 20% Off Now 🚀 Go Pro 🔥")];
            [self.buttonUpgrade setTintColor:UIColor.systemRedColor];
        }
        else {
            [self.buttonUpgrade setTitle:upgradeButtonTitle];
        }
    }
    else {
        [self.buttonUpgrade setEnabled:NO];
        [self.buttonUpgrade setTintColor: [UIColor clearColor]];
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
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* pinEntryVc = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    __weak PinEntryController* weakVc = pinEntryVc;
    
    pinEntryVc.pinLength = AppPreferences.sharedInstance.appLockPin.length;
    pinEntryVc.isDatabasePIN = NO;
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if(response == kOk) {
            if([pin isEqualToString:AppPreferences.sharedInstance.appLockPin]) {
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
                [self dismissViewControllerAnimated:YES completion:^{
                    [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
                }];
            }
            else {
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeError];
                
                [Alerts info:weakVc
                       title:NSLocalizedString(@"safes_vc_error_pin_incorrect_title", @"")
                     message:NSLocalizedString(@"safes_vc_error_pin_incorrect_message", @"")
                  completion:^{
                    [self dismissViewControllerAnimated:YES completion:nil];
                }];
            }
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    };
    
    [self presentViewController:pinEntryVc animated:YES completion:nil];
}

- (void)openQuickLaunchDatabase:(BOOL)userJustCompletedBiometricAuthentication {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self internalOpenQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
    });
}

- (void)internalOpenQuickLaunchDatabase:(BOOL)userJustCompletedBiometricAuthentication {
    

    if(![self isVisibleViewController]) {
        NSLog(@"Not opening Quick Launch database as not at top of the Nav Stack");
        return;
    }
    
    if(!AppPreferences.sharedInstance.quickLaunchUuid) {
        
        return;
    }
    
    SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
        return [obj.uuid isEqualToString:AppPreferences.sharedInstance.quickLaunchUuid];
    }];
    
    if(!safe) {
        NSLog(@"Not opening Quick Launch database as configured database not found");
        return;
    }
    
    [self openDatabase:safe biometricPreCleared:userJustCompletedBiometricAuthentication];
}



- (NSArray<SafeMetaData*>*)getLocalDeviceSafes {
    return [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
}

- (NSArray<SafeMetaData*>*)getICloudSafes {
    return [SafesList.sharedInstance getSafesOfProvider:kiCloud];
}

- (void)removeAllICloudSafes {
    NSArray<SafeMetaData*> *icloudSafesToRemove = [self getICloudSafes];
    
    for (SafeMetaData *item in icloudSafesToRemove) {
        NSLog(@"Removing...");
        [SafesList.sharedInstance remove:item.uuid];
    }
}

- (BOOL)hasSafesOtherThanLocalAndiCloud {
    return SafesList.sharedInstance.snapshot.count - ([self getICloudSafes].count + [self getLocalDeviceSafes].count) > 0;
}

- (void)showiCloudMigrationUi:(BOOL)show {
    if(show) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"safesvc_icloud_migration_progress_title_migrating", @"Migrating...")];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    }
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
            
            NSData* data = document.data ? document.data.copy : nil; 
            
            NSError* error;
            NSDictionary* att = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
            NSDate* mod = att.fileModificationDate;
            
            [document closeWithCompletionHandler:nil];
            
            
            
            
            [FileManager.sharedInstance deleteAllInboxItems];
                    
            [self onReadImportedFile:success data:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace modDate:mod];
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
        if([url.pathExtension caseInsensitiveCompare:@"key"] ==  NSOrderedSame) {
            [self importKey:data url:url];
        }
        else {
            [self importSafe:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace modDate:modDate];
        }
    }
}

- (void)importKey:(NSData*)data url:(NSURL*)url  {
    NSString* filename = url.lastPathComponent;
    NSString* path = [FileManager.sharedInstance.keyFilesDirectory.path stringByAppendingPathComponent:filename];
    
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

- (void)importSafe:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace modDate:(NSDate*)modDate {
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
        if([LocalDeviceStorageProvider.sharedInstance fileNameExistsInDefaultStorage:filename] && AppPreferences.sharedInstance.iCloudOn == NO) {
            [Alerts twoOptionsWithCancel:self
                                   title:NSLocalizedString(@"safesvc_update_existing_database_title", @"Update Existing Database?")
                                 message:NSLocalizedString(@"safesvc_update_existing_question", @"A database using this file name was found in Strongbox. Should Strongbox update that database to use this file, or would you like to create a new database using this file?")
                       defaultButtonText:NSLocalizedString(@"safesvc_update_existing_option_update", @"Update Existing Database")
                        secondButtonText:NSLocalizedString(@"safesvc_update_existing_option_create", @"Create a New Database")
                                  action:^(int response) {
                                      if(response == 0) {
                                          NSString *suggestedFilename = url.lastPathComponent;
                                          BOOL updated = [LocalDeviceStorageProvider.sharedInstance writeToDefaultStorageWithFilename:suggestedFilename overwrite:YES data:data];
                                          
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
    

    
    if(AppPreferences.sharedInstance.iCloudOn) {
        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"safesvc_copy_database_to_location_title", @"Copy to iCloud or Local?")
                             message:NSLocalizedString(@"safesvc_copy_database_to_location_message", @"iCloud is currently enabled. Would you like to copy this database to iCloud now, or would you prefer to keep on your local device only?")
                   defaultButtonText:NSLocalizedString(@"safesvc_copy_database_option_to_local", @"Copy to Local Device Only")
                    secondButtonText:NSLocalizedString(@"safesvc_copy_database_option_to_icloud", @"Copy to iCloud")
                              action:^(int response) {
                                  if(response == 0) {
                                      [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data modDate:modDate];
                                  }
                                  else if(response == 1) {
                                      [self importToICloud:url format:format nickName:nickName extension:extension data:data modDate:modDate];
                                  }
                              }];
    }
    else {
        [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data modDate:modDate];
    }
}

- (void)importToICloud:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data modDate:(NSDate*)modDate {
    NSString *suggestedFilename = url.lastPathComponent;
    
     
    
    [AppleICloudProvider.sharedInstance create:nickName
                                     extension:extension
                                          data:data
                             suggestedFilename:suggestedFilename
                                  parentFolder:nil
                                viewController:self
                                    completion:^(SafeMetaData *metadata, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
             if (error == nil) {
                 metadata.likelyFormat = format;
                 [[SafesList sharedInstance] addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:modDate];
             }
             else {
                 [Alerts error:self
                         title:NSLocalizedString(@"safesvc_error_importing_title", @"Error Importing Database")
                         error:error];
             }
         });
     }];
}

- (void)importToLocalDevice:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data modDate:(NSDate*)modDate {
    
    
    NSString *suggestedFilename = url.lastPathComponent;
        
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                            extension:extension
                                                 data:data
                                              modDate:modDate
                                    suggestedFilename:suggestedFilename
                                           completion:^(SafeMetaData *metadata, NSError *error) {
       dispatch_async(dispatch_get_main_queue(), ^(void) {
           if (error == nil) {
               metadata.likelyFormat = format;
               [[SafesList sharedInstance] addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:modDate];
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
    
    SafeMetaData* metadata = [FilesAppUrlBookmarkProvider.sharedInstance getSafeMetaData:nickName fileName:filename providerData:bookMark];
    
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];
    metadata.likelyFormat = format;
    
    [[SafesList sharedInstance] addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:dateModified];
}



- (void)createLocalCopyDatabase:(SafeMetaData*)database {
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database];
    
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
                                    suggestedFilename:nickName
                                           completion:^(SafeMetaData * _Nonnull metadata, NSError * _Nonnull error) {
        if(error || !metadata) {
            [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
            return;
        }
        
        [SafesList.sharedInstance addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:modDate];

        [Alerts info:self
               title:NSLocalizedString(@"generic_done", @"Done")
             message:NSLocalizedString(@"safes_vc_created_local_copy_done", @"Local Copy Created.")
          completion:^{
            [self.navigationController popToRootViewControllerAnimated:YES];
        }];
    }];
}

- (void)beginMergeWizard:(SafeMetaData*)destinationDatabase {
    if (self.collection.count < 2) {
        [Alerts info:self
               title:NSLocalizedString(@"merge_no_other_databases_available_title", @"No Other Databases Available")
             message:NSLocalizedString(@"merge_no_other_databases_available_msg", @"There are no other databases in your databases collection to merge into this database. You must add another database so that you can select it for the merge operation. Tap the '+' button to add.")];
    }
    else {
        [self performSegueWithIdentifier:@"segueToMergeWizard" sender:destinationDatabase];
    }
}




- (void)promptForConvenienceEnrolAndOpen:(BOOL)biometricPossible
                             pinPossible:(BOOL)pinPossible
                                   model:(Model*)model {
    NSString *title;
    NSString *message;
    
    NSString* biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];
    
    if(biometricPossible && pinPossible) {
        title = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_both_title_fmt", @"Convenience Unlock: Use %@ or PIN Code in Future?"), biometricIdName];
        message = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_both_message_fmt", @"You can use either %@ or a convenience PIN Code to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use one of these methods, please select from below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password"), biometricIdName];
    }
    else if (biometricPossible) {
        title = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_bio_title_fmt", @"Convenience Unlock: Use %@ to Unlock in Future?"), biometricIdName];
        message = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_bio_message_fmt", @"You can use %@ to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password"), biometricIdName];
    }
    else if (pinPossible) {
        title = NSLocalizedString(@"open_sequence_prompt_use_convenience_pin_title", @"Convenience Unlock: Use a PIN Code to Unlock in Future?");
        message = NSLocalizedString(@"open_sequence_prompt_use_convenience_pin_message", @"You can use a convenience PIN Code to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password");
    }
    
    if (!AppPreferences.sharedInstance.isPro) {
        message = [message stringByAppendingFormat:NSLocalizedString(@"open_sequence_append_convenience_pro_warning", @"\n\nNB: Convenience Unlock is a Pro feature")];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    if(biometricPossible) {
        UIAlertAction *biometricAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_bio_fmt", @"Use %@"), biometricIdName]
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *a) {
            [self enrolForBiometrics:model];
            [self showUnlockedDatabase:model];
        }];
        
        [alertController addAction:biometricAction];
    }
    
    if (pinPossible) {
        UIAlertAction *pinCodeAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_pin", @"Use a PIN Code...")]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) {
            [self setupConveniencePinAndOpen:model];
        }];
        [alertController addAction:pinCodeAction];
    }
    
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"open_sequence_prompt_option_no", @"No")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *a) {
        [self unenrolFromConvenience:model];
        [self showUnlockedDatabase:model];
    }];
    

    [alertController addAction:noAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)enrolForBiometrics:(Model*)model {
    model.metadata.isTouchIdEnabled = YES;
    model.metadata.isEnrolledForConvenience = YES;
    model.metadata.convenienceMasterPassword = model.database.ckfs.password;
    model.metadata.hasBeenPromptedForConvenience = YES;
    
    [SafesList.sharedInstance update:model.metadata];
}

- (void)unenrolFromConvenience:(Model*)model {
    model.metadata.isTouchIdEnabled = NO;
    model.metadata.conveniencePin = nil;
    model.metadata.isEnrolledForConvenience = NO;
    model.metadata.convenienceMasterPassword = nil;
    model.metadata.hasBeenPromptedForConvenience = YES;
    [SafesList.sharedInstance update:model.metadata];
}

- (void)setupConveniencePinAndOpen:(Model*)model {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* pinEntryVc = (PinEntryController*)[storyboard instantiateInitialViewController];
    pinEntryVc.isDatabasePIN = YES;
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if(!(model.metadata.duressPin != nil && [pin isEqualToString:model.metadata.duressPin])) {
                    [self enrolForPinCodeUnlock:model pin:pin];
                    [self showUnlockedDatabase:model];
                }
                else {
                    [Alerts warn:self
                           title:NSLocalizedString(@"open_sequence_warn_pin_conflict_title", @"PIN Conflict")
                        message:NSLocalizedString(@"open_sequence_warn_pin_conflict_message", @"Your Convenience PIN conflicts with your Duress PIN. Please configure in Database Settings")
                    completion:^{
                        [self showUnlockedDatabase:model];
                    }];
                }
            }
            else {
                [self showUnlockedDatabase:model];
            }
        }];
    };

    [self presentViewController:pinEntryVc animated:YES completion:nil];
}

- (void)enrolForPinCodeUnlock:(Model*)model pin:(NSString*)pin {
    model.metadata.conveniencePin = pin;
    model.metadata.isEnrolledForConvenience = YES;
    model.metadata.convenienceMasterPassword = model.database.ckfs.password;
    model.metadata.hasBeenPromptedForConvenience = YES;

    [SafesList.sharedInstance update:model.metadata];
}

- (void)promptForQuickLaunch:(Model*)model {
    if(AppPreferences.sharedInstance.quickLaunchUuid == nil && !model.metadata.hasBeenPromptedForQuickLaunch) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"open_sequence_yesno_set_quick_launch_title", @"Set Quick Launch?")
              message:NSLocalizedString(@"open_sequence_yesno_set_quick_launch_message", @"Would you like to use this as your Quick Launch database? Quick Launch means you will get prompted immediately to unlock when you open Strongbox, saving you a precious tap.")
               action:^(BOOL response) {
            if(response) {
                AppPreferences.sharedInstance.quickLaunchUuid = model.metadata.uuid;
                AppPreferences.sharedInstance.autoFillQuickLaunchUuid = model.metadata.uuid;
            }

            model.metadata.hasBeenPromptedForQuickLaunch = YES;
            [SafesList.sharedInstance update:model.metadata];

            [self showUnlockedDatabase:model];
        }];
    }
}



- (void)showDatabaseProperties:(SafeMetaData*)database {
    [self performSegueWithIdentifier:@"segueToDatabaseProperties" sender:database];
}

@end

