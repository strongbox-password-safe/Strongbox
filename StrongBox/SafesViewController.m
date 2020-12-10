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
#import "Settings.h"
#import "SelectStorageProviderController.h"
#import "DatabaseCell.h"
#import "VersionConflictController.h"
#import "AppleICloudProvider.h"
#import "SafeStorageProviderFactory.h"
#import "OpenSafeSequenceHelper.h"
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
#import "PrivacyViewController.h"
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
#import "SharedAppAndAutoFillSettings.h"
#import "SyncManager.h"
#import "SyncStatus.h"
#import "SyncLogViewController.h"
#import "NSDate+Extensions.h"
#import "DebugHelper.h"
#import "GettingStartedInitialViewController.h"
#import "UITableView+EmptyDataSet.h"
#import "MergeInitialViewController.h"

@interface SafesViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpgrade;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonCustomizeView;

- (IBAction)onAddSafe:(id)sender;
- (IBAction)onUpgrade:(id)sender;

@property (nonatomic, copy) NSArray<SafeMetaData*> *collection;
@property PrivacyViewController* privacyAndLockVc;
@property (nonatomic, strong) NSDate *enterBackgroundTime;

@property NSURL* enqueuedImportUrl;
@property BOOL enqueuedImportCanOpenInPlace;
@property BOOL privacyScreenSuppressedForBiometricAuth;

@property BOOL hasAppearedOnce; 
@property SafeMetaData* lastOpenedDatabase; 

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation SafesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if (@available(iOS 13.0, *)) { 
        [self.buttonPreferences setImage:[UIImage systemImageNamed:@"gear"]];
    }

    [self.buttonPreferences setAccessibilityLabel:NSLocalizedString(@"audit_drill_down_section_header_preferences", @"Preferences")];
    [self.buttonCustomizeView setAccessibilityLabel:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View")];
    [self.buttonAddSafe setAccessibilityLabel:NSLocalizedString(@"casg_add_action", @"Add")];
    
    [self checkForPreviousCrash];

    self.collection = [NSArray array];
    [self setupTableview];
    
    [self internalRefresh];
    
    [self listenToNotifications];
    
    
    
    [self setFreeTrialEndDateBasedOnIapPurchase]; 

    if([Settings.sharedInstance getLaunchCount] == 1) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self doFirstLaunchTasks]; 
        });
    }
    else {
        if (@available(iOS 14.0, *)) { 
            
            if (!self.hasAppearedOnce) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self appBecameActive];
                });
            }
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

- (void)doFirstLaunchTasks {
    if (SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial) {
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
        NSDate* endDate = [SharedAppAndAutoFillSettings.sharedInstance calculateFreeTrialEndDateFromDate:freeTrialPurchaseDate];
        SharedAppAndAutoFillSettings.sharedInstance.freeTrialEnd = endDate;
    }
    else {
        NSLog(@"setFreeTrialEndDateBasedOnIapPurchase: No Free Trial purchase found.");
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
    NSLog(@"REFRESH: Refreshing entire table...");

    self.collection = SafesList.sharedInstance.snapshot;

    self.tableView.separatorStyle = SharedAppAndAutoFillSettings.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;

    [self.tableView reloadData];
}

#pragma mark Startup Lock and Quick Launch Activation

- (void)appResignActive {
    NSLog(@"appResignActive");
    
    self.privacyScreenSuppressedForBiometricAuth = NO;
    if(SharedAppAndAutoFillSettings.sharedInstance.suppressPrivacyScreen) {
        NSLog(@"appResignActive suppressPrivacyScreen... suppressing privacy and lock screen");
        self.privacyScreenSuppressedForBiometricAuth = YES;
        return;
    }
    
    [self showPrivacyScreen:NO];
}

- (void)appBecameActive {
    NSLog(@"XXXXXXXXX - appBecameActive");
    
    if(self.privacyScreenSuppressedForBiometricAuth) {
        NSLog(@"App Active but Privacy Screen Suppressed... Nothing to do");
        self.privacyScreenSuppressedForBiometricAuth = NO;
        return;
    }

    
    
    
    [SafesList.sharedInstance reloadIfChangedByOtherComponent];
    self.collection = SafesList.sharedInstance.snapshot;
    [SyncManager.sharedInstance backgroundSyncOutstandingUpdates];
    [self refresh]; 

    if(!self.hasAppearedOnce) {
        NSLog(@"XXXXXXXXX - appBecameActive - First Appearance - Doing First Activation Process");
        [self doAppFirstActivationProcess];
    }
    else {
        if(self.privacyAndLockVc) {
            NSLog(@"XXXXXXXXX - appBecameActive - Privacy Screen is present - telling it that the app has become active.");

            [self.privacyAndLockVc onAppBecameActive];
        }
        else {
            NSLog(@"XXXXXXXXX - appBecameActive - Privacy Screen is NOT present - Doing App Activation Tasks.");

            [self doAppActivationTasks:NO];
        }
    }
}

- (void)doAppFirstActivationProcess {
    if(!self.hasAppearedOnce) {
        self.hasAppearedOnce = YES;

        if (Settings.sharedInstance.appLockMode != kNoLock) {
            NSLog(@"First App Became Active - App Lock in Place - Showing Privacy Screen...");
            [self showPrivacyScreen:YES];
        }
        else {
            NSLog(@"First App Became Active - No App Lock...");
            [self doAppActivationTasks:NO];
        }
    }
}

- (void)showPrivacyScreen:(BOOL)startupLockMode {
    if(self.privacyAndLockVc) {
        NSLog(@"Privacy Screen Already Up... No need to re show");
        return;
    }
    
    self.enterBackgroundTime = [[NSDate alloc] init];
    
    __weak SafesViewController* weakSelf = self;
    PrivacyViewController* privacyVc = [[PrivacyViewController alloc] initWithNibName:@"PrivacyViewController" bundle:nil];
    privacyVc.onUnlockDone = ^(BOOL userJustCompletedBiometricAuthentication) {
        [weakSelf hidePrivacyScreen:userJustCompletedBiometricAuthentication];
    };
    privacyVc.startupLockMode = startupLockMode;
    privacyVc.modalPresentationStyle = UIModalPresentationOverFullScreen; 

    
    

    UIViewController* visible = [self getVisibleViewController];
    NSLog(@"Presenting Privacy Screen on [%@]", [visible class]);
    [visible presentViewController:privacyVc animated:NO completion:^{
        NSLog(@"Presented Privacy Screen Successfully...");
        self.privacyAndLockVc = privacyVc; 
    }];
}

- (void)hidePrivacyScreen:(BOOL)userJustCompletedBiometricAuthentication {
    UIViewController* visible =[self getVisibleViewController];
    BOOL fallbackMethod = [visible isKindOfClass:PrivacyViewController.class];
    
    if (self.privacyAndLockVc || fallbackMethod) {
        if ([self shouldLockOpenDatabase]) {
            NSLog(@"Should Lock Database now...");

            self.lastOpenedDatabase = nil; 
            
            UINavigationController* nav = self.navigationController;
            [nav popToRootViewControllerAnimated:NO];
            
            
            [self dismissViewControllerAnimated:NO completion:^{
                [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        else {
            NSLog(@"Dismissing Privacy Screen");

            if (self.privacyAndLockVc) {
                [self.privacyAndLockVc.presentingViewController dismissViewControllerAnimated:NO completion:^{
                    NSLog(@"Dismissing Privacy Screen Done!");
                    [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
                }];
            }
            else { 
                
                [self dismissViewControllerAnimated:NO completion:^{
                    [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
                }];
            }
        }
        
        self.enterBackgroundTime = nil;
    }
    else {
        
        
        NSLog(@"XXXXX - Interesting Situation - hidePrivacyScreen but no Privacy Screen was up? - XXXX");
    }
}

- (BOOL)shouldLockOpenDatabase {
    if (self.enterBackgroundTime && self.lastOpenedDatabase) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.enterBackgroundTime];
        
        NSNumber *seconds = self.lastOpenedDatabase.autoLockTimeoutSeconds;
        
        NSLog(@"Autolock Time [%@s] - background Time: [%f].", seconds, secondsBetween);
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) 
        {
            NSLog(@"Locking Database...");
            return YES;
        }
    }
    
    return NO;
}



- (void)onPrivacyScreenDismissed:(BOOL)userJustCompletedBiometricAuthentication {
    self.privacyAndLockVc = nil;
    
    NSLog(@"XXXXXXXXXXXXXXXXXX - On Privacy Screen Dismissed");

    dispatch_async(dispatch_get_main_queue(), ^{
        [self doAppActivationTasks:userJustCompletedBiometricAuthentication];
    });
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
        Settings.sharedInstance.iCloudAvailable = available;
        
        if (!Settings.sharedInstance.iCloudAvailable) {
            NSLog(@"iCloud Not Available...");
            [self onICloudNotAvailable:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
        }
        else {
            NSLog(@"iCloud Available...");
            [self onICloudAvailable:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
        }
    }];
}

- (void)onICloudNotAvailable:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation {
    
    [Settings sharedInstance].iCloudPrompted = NO;
    
    if ([[Settings sharedInstance] iCloudWasOn] &&  [self getICloudSafes].count) {
        [Alerts warn:self
               title:NSLocalizedString(@"safesvc_icloud_no_longer_available_title", @"iCloud no longer available")
             message:NSLocalizedString(@"safesvc_icloud_no_longer_available_message", @"Some databases were removed from this device because iCloud has become unavailable, but they remain stored in iCloud.")];
        
        [self removeAllICloudSafes];
    }
    
    
    [SharedAppAndAutoFillSettings sharedInstance].iCloudOn = NO;
    [Settings sharedInstance].iCloudWasOn = NO;
    
    [self onICloudCheckDone:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
}

- (void)onICloudAvailable:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation{
    if (!SharedAppAndAutoFillSettings.sharedInstance.iCloudOn && !Settings.sharedInstance.iCloudPrompted) {
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
                                SharedAppAndAutoFillSettings.sharedInstance.iCloudOn = YES;
                            }
                            [Settings sharedInstance].iCloudPrompted = YES;
                            [self onICloudAvailableContinuation:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
                        }];
        }
    }
    else {
        [self onICloudAvailableContinuation:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
    }
}

- (void)onICloudAvailableContinuation:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation {
    BOOL iCloudOn = SharedAppAndAutoFillSettings.sharedInstance.iCloudOn;
    BOOL iCloudWasOn = Settings.sharedInstance.iCloudWasOn;
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
                              [SharedAppAndAutoFillSettings sharedInstance].iCloudOn = YES;
                              [Settings sharedInstance].iCloudWasOn = [SharedAppAndAutoFillSettings sharedInstance].iCloudOn;
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
    
    Settings.sharedInstance.iCloudWasOn = SharedAppAndAutoFillSettings.sharedInstance.iCloudOn;
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
        if(!SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid) {
            BOOL userHasLocalDatabases = [self getLocalDeviceSafes].firstObject != nil;
            
            if (!Settings.sharedInstance.haveAskedAboutBackupSettings && userHasLocalDatabases) {
                NSString* title = NSLocalizedString(@"backup_settings_prompt_title", @"Backup Settings");
                NSString* message = NSLocalizedString(@"backup_settings_prompt_message", @"By Default Strongbox now includes all your local documents and databases in Apple backups, however imported Key Files are explicitly not included for security reasons.\n\nYou can change these settings at any time in Preferences > Advanced Preferences.\n\nDoes this sound ok?");
                NSString* option1 = NSLocalizedString(@"backup_settings_prompt_option_yes_looks_good", @"Yes, the defaults sound good");
                NSString* option2 = NSLocalizedString(@"backup_settings_prompt_yes_but_include_key_files", @"Yes, but also backup Key Files");
                NSString* option3 = NSLocalizedString(@"backup_settings_prompt_no_dont_backup_anything", @"No, do NOT backup anything");
                
                [Alerts threeOptionsWithCancel:self title:title
                                       message:message defaultButtonText:option1 secondButtonText:option2 thirdButtonText:option3 action:^(int response) {
                    NSLog(@"Selected: %d", response);
                    if (response == 0) {
                        Settings.sharedInstance.backupFiles = YES;
                        Settings.sharedInstance.backupIncludeImportedKeyFiles = NO;
                    }
                    else if (response == 1) {
                        Settings.sharedInstance.backupFiles = YES;
                        Settings.sharedInstance.backupIncludeImportedKeyFiles = YES;
                    }
                    else if (response == 2) {
                        Settings.sharedInstance.backupFiles = NO;
                        Settings.sharedInstance.backupIncludeImportedKeyFiles = NO;
                    }
                    
                    if (response != 3) {
                        [FileManager.sharedInstance setDirectoryInclusionFromBackup:Settings.sharedInstance.backupFiles
                                                                   importedKeyFiles:Settings.sharedInstance.backupIncludeImportedKeyFiles];
                        
                        Settings.sharedInstance.haveAskedAboutBackupSettings = YES;
                    }
                }];
            }
        }
        else {
            [self openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
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
            NSLog(@"[%@] - Database Changed", self.collection[index].nickName);

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
    if(SharedAppAndAutoFillSettings.sharedInstance.hideTips) {
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
    
    [self openSafeAtIndexPath:indexPath openLocalOnly:NO];
}

- (void)openSafeAtIndexPath:(NSIndexPath*)indexPath openLocalOnly:(BOOL)openLocalOnly {
    [self openSafeAtIndexPath:indexPath openLocalOnly:openLocalOnly manualUnlock:NO];
}

- (void)openSafeAtIndexPath:(NSIndexPath*)indexPath openLocalOnly:(BOOL)openLocalOnly manualUnlock:(BOOL)manualUnlock {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    [self openDatabase:safe openLocalOnly:openLocalOnly noConvenienceUnlock:manualUnlock userJustCompletedBiometricAuthentication:NO];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(SafeMetaData*)safe
       openLocalOnly:(BOOL)openLocalOnly
userJustCompletedBiometricAuthentication:(BOOL)userJustCompletedBiometricAuthentication {
    [self openDatabase:safe openLocalOnly:openLocalOnly noConvenienceUnlock:NO userJustCompletedBiometricAuthentication:userJustCompletedBiometricAuthentication];
}

- (void)openDatabase:(SafeMetaData*)safe
       openLocalOnly:(BOOL)openLocalOnly
 noConvenienceUnlock:(BOOL)noConvenienceUnlock
userJustCompletedBiometricAuthentication:(BOOL)userJustCompletedBiometricAuthentication {
    NSLog(@"======================== OPEN DATABASE: %@ ============================", safe);
    
    if(safe.hasUnresolvedConflicts) {
        [self performSegueWithIdentifier:@"segueToVersionConflictResolution" sender:safe.fileIdentifier];
    }
    else {
        [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                           safe:safe
                                            canConvenienceEnrol:YES
                                                 isAutoFillOpen:NO
                                                  openLocalOnly:openLocalOnly
                                    biometricAuthenticationDone:userJustCompletedBiometricAuthentication
                                            noConvenienceUnlock:noConvenienceUnlock
                                                     completion:^(UnlockDatabaseResult result, Model * _Nullable model, const NSError * _Nullable error) {
            if (result == kUnlockDatabaseResultSuccess) {
                if (@available(iOS 11.0, *)) { 
                    [self performSegueWithIdentifier:@"segueToMasterDetail" sender:model];
                }
                else {
                    [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:model];
                }
            }
            else if (result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
                [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
            }
        }];
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
            [self getContextualMenuDatabaseStateActions:indexPath],
            [self getContextualMenuDatabaseActions:indexPath]
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

- (UIAction*)getContextualViewSyncLogAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)) {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"safes_vc_action_view_sync_status", @"Button Title to view sync log for this database")
                                    systemImage:@"arrow.clockwise.icloud" 
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
    }];

    return ret;
}

- (UIMenu*)getContextualMenuDatabaseNonMutatatingActions:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    SyncStatus *syncStatus = [SyncManager.sharedInstance getSyncStatus:safe];
    
    BOOL conveniencePossible = safe.isEnrolledForConvenience && SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial;
    if (conveniencePossible) [ma addObject:[self getContextualMenuUnlockManualAction:indexPath]];

    NSURL* localCopyUrl = [SyncManager.sharedInstance getLocalWorkingCache:safe];

    BOOL localCopyAvailable = safe.storageProvider != kLocalDevice && localCopyUrl != nil;
    if (localCopyAvailable) [ma addObject:[self getContextualMenuOpenLocalAction:indexPath]];

    [ma addObject:[self getContextualViewBackupsAction:indexPath]];
    
    BOOL shareAllowed = !Settings.sharedInstance.hideExportFromDatabaseContextMenu && localCopyUrl != nil;
    if (shareAllowed) [ma addObject:[self getContextualShareAction:indexPath]];

    BOOL syncLogAvailable = syncStatus.changeLog.firstObject != nil;
    if (syncLogAvailable) [ma addObject:[self getContextualViewSyncLogAction:indexPath]];

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

- (UIMenu*)getContextualMenuDatabaseStateActions:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    BOOL makeVisible = safe.storageProvider == kLocalDevice;
    if (makeVisible) [ma addObject:[self getContextualMenuMakeVisibleAction:indexPath]];

    [ma addObject:[self getContextualMenuQuickLaunchAction:indexPath]];
    
    [ma addObject:[self getContextualMenuReadOnlyAction:indexPath]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIMenu*)getContextualMenuDatabaseActions:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];

    [ma addObject:[self getContextualMenuRenameAction:indexPath]];



    [ma addObject:[self getContextualMenuRemoveAction:indexPath]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualShareAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)) {
    UIAction* ret = [self getContextualMenuItem:NSLocalizedString(@"generic_export", @"Export")
                                    systemImage:@"square.and.arrow.up"
                                    destructive:NO
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self onShare:indexPath];
    }];

    return ret;
}

- (UIAction*)getContextualMenuMakeVisibleAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
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

- (UIAction*)getContextualMenuQuickLaunchAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL isAlreadyQuickLaunch = [SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid];
    
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

- (UIAction*)getContextualMenuReadOnlyAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
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

- (UIAction*)getContextualMenuUnlockManualAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"safes_vc_unlock_manual_action", @"Open ths database manually bypassing any convenience unlock")
                           systemImage:@"lock.open"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self manualUnlock:indexPath];
    }];
}

- (UIAction*)getContextualMenuOpenLocalAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"safes_vc_slide_left_open_offline_action", @"Open ths database offline table action")
                           systemImage:@"house"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self openLocalOnly:indexPath];
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

- (UIAction*)getContextualMenuMergeAction:(NSIndexPath*)indexPath  API_AVAILABLE(ios(13.0)){
    BOOL iOS14 = NO;
    if ( @available(iOS 14.0, *) ) { 
        iOS14 = YES;
    }
    
    UIImage* img = iOS14 ? [UIImage systemImageNamed:@"arrow.triangle.merge"] : [UIImage imageNamed:@"paper_plane"];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    return [self getContextualMenuItem:NSLocalizedString(@"generic_action_merge_ellipsis", @"Merge...")
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
    
    NSURL* localCopyUrl = [SyncManager.sharedInstance getLocalWorkingCache:database];
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

    UITableViewRowAction *offlineAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:NSLocalizedString(@"safes_vc_slide_left_open_offline_action", @"Open ths database offline table action")
                                                                           handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self openLocalOnly:indexPath];
    }];
    offlineAction.backgroundColor = [UIColor darkGrayColor];

    
    
    UITableViewRowAction *moreActions = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                           title:NSLocalizedString(@"safes_vc_slide_left_more_actions", @"View more actions table action")
                                                                         handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self showDatabaseMoreActions:indexPath];
    }];
    moreActions.backgroundColor = [UIColor systemBlueColor];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL offlineOption = safe.storageProvider != kLocalDevice && [SyncManager.sharedInstance isLocalWorkingCacheAvailable:safe modified:nil];

    return offlineOption ? @[removeAction, offlineAction, moreActions] : @[removeAction, moreActions];
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
    
    

    BOOL isAlreadyQuickLaunch = [SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid];
    UIAlertAction *quickLaunchAction = [UIAlertAction actionWithTitle:isAlreadyQuickLaunch ?
                                        NSLocalizedString(@"safes_vc_action_unset_as_quick_launch", @"Button Title to Unset Quick Launch") :
                                        NSLocalizedString(@"safes_vc_action_set_as_quick_launch", @"Button Title to Set Quick Launch")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              [self toggleQuickLaunch:safe];
                                                          } ];
    [alertController addAction:quickLaunchAction];

    

    UIAlertAction *mergeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_action_merge_ellipsis", @"Merge...")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
        [self beginMergeWizard:safe];
    }];




    
    
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
    
    
    
    UIAlertAction *viewBackupsOption = [UIAlertAction actionWithTitle:
            NSLocalizedString(@"safes_vc_action_backups", @"Button Title to view backup settings of this database")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
            [self performSegueWithIdentifier:@"segueToBackups" sender:safe];
        }];
    
    [alertController addAction:viewBackupsOption];

    
    UIAlertAction *viewSyncStatus = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_action_view_sync_status", @"Button Title to view sync log for this database")
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *a) {
        [self performSegueWithIdentifier:@"segueToSyncLog" sender:safe];
    }];
    [alertController addAction:viewSyncStatus];
    
    
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel Button")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alertController addAction:cancelAction];
    


    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)toggleQuickLaunch:(SafeMetaData*)database {
    if([SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid = nil;
        [self refresh];
    }
    else {
        [Alerts yesNo:self
                title:NSLocalizedString(@"safes_vc_about_quick_launch_title", @"Title of Prompt about setting Quick Launch")
              message:NSLocalizedString(@"safes_vc_about_setting_quick_launch_and_confirm", @"Message about quick launch feature and asking to confirm yes or no")
               action:^(BOOL response) {
            if (response) {
                SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid = database.uuid;
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

- (void)manualUnlock:(NSIndexPath*)indexPath {
    [self openSafeAtIndexPath:indexPath openLocalOnly:NO manualUnlock:YES];
}

- (void)openLocalOnly:(NSIndexPath*)indexPath {
    [self openSafeAtIndexPath:indexPath openLocalOnly:YES];
}

- (void)renameSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *database = [self.collection objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"segueToRenameDatabase" sender:database];
}

- (void)removeSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString *message;
    
    if(safe.storageProvider == kiCloud && [SharedAppAndAutoFillSettings sharedInstance].iCloudOn) {
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
    
    
    if([SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid]) {
        SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid = nil;
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
        vc.currentGroup = vc.viewModel.database.rootGroup;
        self.lastOpenedDatabase = vc.viewModel.metadata;
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
                     [self openDatabase:databaseToOpen openLocalOnly:NO userJustCompletedBiometricAuthentication:NO];
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
            if (SharedAppAndAutoFillSettings.sharedInstance.freeTrialHasBeenOptedInAndExpired || Settings.sharedInstance.daysInstalled > 90) {
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.modalInPresentation = YES;
            }
        }
    }
    else if ( [segue.identifier isEqualToString:@"segueToMergeWizard"]) {
        SafeMetaData* dest = (SafeMetaData*)sender;
        MergeInitialViewController* vc = (MergeInitialViewController*)segue.destinationViewController;
        vc.destinationDatabase = dest;
    }
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
        [self openDatabase:databaseToOpen openLocalOnly:NO userJustCompletedBiometricAuthentication:NO];
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
    if(SharedAppAndAutoFillSettings.sharedInstance.iCloudOn) {
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

    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    DatabaseFormat format = [DatabaseModel getDatabaseFormatWithPrefix:data];  
    
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
    self.navigationController.toolbarHidden =  [[SharedAppAndAutoFillSettings sharedInstance] isPro];
    self.navigationController.toolbar.hidden = [[SharedAppAndAutoFillSettings sharedInstance] isPro];
    
    if(![[SharedAppAndAutoFillSettings sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
    
        NSString *upgradeButtonTitle;

        if (SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial) {
            if([[SharedAppAndAutoFillSettings sharedInstance] isFreeTrial]) {
                NSInteger daysLeft = SharedAppAndAutoFillSettings.sharedInstance.freeTrialDaysLeft;
                
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
            if (Settings.sharedInstance.daysInstalled > 60) {
                [self.buttonUpgrade setTintColor:UIColor.systemRedColor];
            }
        }
        
        [self.buttonUpgrade setTitle:upgradeButtonTitle];
    }
    else {
        [self.buttonUpgrade setEnabled:NO];
        [self.buttonUpgrade setTintColor: [UIColor clearColor]];
    }
}

- (IBAction)onPreferences:(id)sender {
    if (!Settings.sharedInstance.appLockAppliesToPreferences || Settings.sharedInstance.appLockMode == kNoLock) {
        [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
        return;
    }
    
    if((Settings.sharedInstance.appLockMode == kBiometric || Settings.sharedInstance.appLockMode == kBoth) && BiometricsManager.isBiometricIdAvailable) {
        [self requestBiometricBeforeOpeningPreferences];
    }
    else if (Settings.sharedInstance.appLockMode == kPinCode || Settings.sharedInstance.appLockMode == kBoth) {
        [self requestPin];
    }
}

- (void)requestBiometricBeforeOpeningPreferences {
    [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_preferences_message", @"Identify to Open Preferences")
                                     completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (Settings.sharedInstance.appLockMode == kPinCode || Settings.sharedInstance.appLockMode == kBoth) {
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
    
    pinEntryVc.pinLength = Settings.sharedInstance.appLockPin.length;
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if(response == kOk) {
            if([pin isEqualToString:Settings.sharedInstance.appLockPin]) {
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
    
    if(!SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid) {
        
        return;
    }
    
    SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
        return [obj.uuid isEqualToString:SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid];
    }];
    
    if(!safe) {
        NSLog(@"Not opening Quick Launch database as configured database not found");
        return;
    }
    
    [self openDatabase:safe openLocalOnly:NO userJustCompletedBiometricAuthentication:userJustCompletedBiometricAuthentication];
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
    
    if (![DatabaseModel isValidDatabaseWithPrefix:data error:&error]) { 
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
        if([LocalDeviceStorageProvider.sharedInstance fileNameExistsInDefaultStorage:filename] && SharedAppAndAutoFillSettings.sharedInstance.iCloudOn == NO) {
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
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    DatabaseFormat format = [DatabaseModel getDatabaseFormatWithPrefix:data];
    

    
    if(SharedAppAndAutoFillSettings.sharedInstance.iCloudOn) {
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
    
    DatabaseFormat format = [DatabaseModel getDatabaseFormatWithPrefix:data];
    metadata.likelyFormat = format;
    
    [[SafesList sharedInstance] addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:dateModified];
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

@end

