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
#import "CacheManager.h"
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

@interface SafesViewController () <DZNEmptyDataSetDelegate, DZNEmptyDataSetSource>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpgrade;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;

- (IBAction)onAddSafe:(id)sender;
- (IBAction)onUpgrade:(id)sender;

@property (nonatomic, copy) NSArray<SafeMetaData*> *collection;
@property PrivacyViewController* privacyAndLockVc;
@property (nonatomic, strong) NSDate *enterBackgroundTime;

@property NSURL* enqueuedImportUrl;
@property BOOL enqueuedImportCanOpenInPlace;
@property BOOL privacyScreenSuppressedForBiometricAuth;

@property BOOL hasAppearedOnce; // Used for App Lock initial load
@property SafeMetaData* lastOpenedDatabase; // Used for Auto Lock - Ideally we should also clear this on DB close but we don't have that event setup yet...

@end

@implementation SafesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.collection = [NSArray array];
    
    [self setupTableview];
    
    [self internalRefresh];
    
    [self listenToNotifications];
    
    [self setFreeTrialEndDateBasedOnIapPurchase]; // Update Free Trial Date

    if([Settings.sharedInstance getLaunchCount] == 1) {
        [self doFirstLaunchTasks];
    }
}

- (void)doFirstLaunchTasks {
    if (Settings.sharedInstance.isProOrFreeTrial) {
        NSLog(@"New User is already Pro or in Free Trial... Standard Onboarding");
        [self startOnboarding];
    }
    else { // Only if not pro, free trial and no free trial purchase do we prompt to Opt-In to free trial...
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
    
    // Standard Onboarding...
    
    [self performSegueWithIdentifier:@"segueToWelcome" sender:nil];
}

- (void)setFreeTrialEndDateBasedOnIapPurchase {
    NSDate* freeTrialPurchaseDate = ProUpgradeIAPManager.sharedInstance.freeTrialPurchaseDate;
    if (freeTrialPurchaseDate) {
        NSLog(@"setFreeTrialEndDateBasedOnIapPurchase: [%@]", freeTrialPurchaseDate);
        NSDate* endDate = [Settings.sharedInstance calculateFreeTrialEndDateFromDate:freeTrialPurchaseDate];
        Settings.sharedInstance.freeTrialEnd = endDate;
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.tableView.contentOffset.y < 0 && self.tableView.emptyDataSetVisible) {
        self.tableView.contentOffset = CGPointZero;
    }
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self internalRefresh];
    });
}

- (void)internalRefresh {
    self.collection = SafesList.sharedInstance.snapshot;
    
    self.tableView.separatorStyle = Settings.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;

    [self.tableView reloadData];
}

#pragma mark Startup Lock and Quick Launch Activation

- (void)appResignActive {
    NSLog(@"appResignActive");
    
    self.privacyScreenSuppressedForBiometricAuth = NO;
    if(Settings.sharedInstance.suppressPrivacyScreen) {
        NSLog(@"appResignActive suppressPrivacyScreen... suppressing privacy and lock screen");
        self.privacyScreenSuppressedForBiometricAuth = YES;
        return;
    }
    
    [self showPrivacyScreen:NO];
}

- (void)appBecameActive {
    NSLog(@"appBecameActive");
    
    if(self.privacyScreenSuppressedForBiometricAuth) {
        NSLog(@"App Active but Privacy Screen Suppressed... Nothing to do");
        self.privacyScreenSuppressedForBiometricAuth = NO;
        return;
    }
    
    if(!self.hasAppearedOnce) {
        [self doAppFirstActivationProcess];
    }
    else {
        if(self.privacyAndLockVc) {
            [self.privacyAndLockVc onAppBecameActive];
        }
        else {
            [self doAppActivationTasks:NO];
        }
    }
}

- (void)doAppFirstActivationProcess {
    if(!self.hasAppearedOnce) {
        self.hasAppearedOnce = YES;
        NSLog(@"self.hasAppearedOnce = YES");

        if (Settings.sharedInstance.appLockMode != kNoLock) {
            [self showPrivacyScreen:YES];
        }
        else {
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
    privacyVc.modalPresentationStyle = UIModalPresentationOverFullScreen; // This stops the view controller interfering with UIAlertController if we happen to present on that. Less than Ideal?

    // Visible will be top most - usually the current nav top controller but can be another modal like Custom Fields editor
    

    UIViewController* visible = [self getVisibleViewController];
    NSLog(@"Presenting Privacy Screen on [%@]", [visible class]);
    [visible presentViewController:privacyVc animated:NO completion:^{
        NSLog(@"Presented Privacy Screen Successfully...");
        self.privacyAndLockVc = privacyVc; // Only set this if we succeed in displaying...
    }];
}

- (void)hidePrivacyScreen:(BOOL)userJustCompletedBiometricAuthentication {
    if (self.privacyAndLockVc) {
        if ([self shouldLockOpenDatabase]) {
            NSLog(@"Should Lock Database now...");

            self.lastOpenedDatabase = nil; // Clear
            
            UINavigationController* nav = self.navigationController;
            [nav popToRootViewControllerAnimated:NO];
            
            // This dismisses all modals including the privacy screen which is what we want
            [self dismissViewControllerAnimated:NO completion:^{
                [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        else {
            NSLog(@"Dismissing Privacy Screen");
            [self.privacyAndLockVc.presentingViewController dismissViewControllerAnimated:NO completion:^{
                NSLog(@"Dismissing Privacy Screen Done!");
                [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        
        self.enterBackgroundTime = nil;
    }
    else {
        // I don't think this is possible but would like to know about it if it ever somehow could occur
        NSLog(@"XXXXX - Interesting Situation - hidePrivacyScreen but no Privacy Screen was up? - XXXX");
    }
}

- (BOOL)shouldLockOpenDatabase {
    if (self.enterBackgroundTime && self.lastOpenedDatabase) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.enterBackgroundTime];
        
        NSNumber *seconds = self.lastOpenedDatabase.autoLockTimeoutSeconds;
        
        NSLog(@"Autolock Time [%@s] - background Time: [%f].", seconds, secondsBetween);
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) // -1 = never
        {
            NSLog(@"Locking Database...");
            return YES;
        }
    }
    
    return NO;
}

// App Activation Sequence....

- (void)onPrivacyScreenDismissed:(BOOL)userJustCompletedBiometricAuthentication {
    self.privacyAndLockVc = nil;
    
    NSLog(@"XXXXXXXXXXXXXXXXXX - On Privacy Screen Dismissed");

    dispatch_async(dispatch_get_main_queue(), ^{
        [self doAppActivationTasks:userJustCompletedBiometricAuthentication];
    });
}

- (void)doAppActivationTasks:(BOOL)userJustCompletedBiometricAuthentication {
    //NSLog(@"doAppActivationTasks");

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
    // If iCloud isn't available, set promoted to no (so we can ask them next time it becomes available)
    [Settings sharedInstance].iCloudPrompted = NO;
    
    if ([[Settings sharedInstance] iCloudWasOn] &&  [self getICloudSafes].count) {
        [Alerts warn:self
               title:NSLocalizedString(@"safesvc_icloud_no_longer_available_title", @"iCloud no longer available")
             message:NSLocalizedString(@"safesvc_icloud_no_longer_available_message", @"Some databases were removed from this device because iCloud has become unavailable, but they remain stored in iCloud.")];
        
        [self removeAllICloudSafes];
    }
    
    // No matter what, iCloud isn't available so switch it to off.???
    [Settings sharedInstance].iCloudOn = NO;
    [Settings sharedInstance].iCloudWasOn = NO;
    
    [self onICloudCheckDone:userJustCompletedBiometricAuthentication isAppActivation:isAppActivation];
}

- (void)onICloudAvailable:(BOOL)userJustCompletedBiometricAuthentication isAppActivation:(BOOL)isAppActivation{
    if (!Settings.sharedInstance.iCloudOn && !Settings.sharedInstance.iCloudPrompted) {
        BOOL existingLocalDeviceSafes = [self getLocalDeviceSafes].count > 0;
        BOOL hasOtherCloudSafes = [self hasSafesOtherThanLocalAndiCloud];
        
        if (!existingLocalDeviceSafes && !hasOtherCloudSafes) { // Empty Databases - Possibly first time user - onboarding will ask
                                                                //Settings.sharedInstance.iCloudOn = YES; // Empty
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
                                Settings.sharedInstance.iCloudOn = YES;
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
    // If iCloud newly switched on, move local docs to iCloud
    if (Settings.sharedInstance.iCloudOn && !Settings.sharedInstance.iCloudWasOn && [self getLocalDeviceSafes].count) {
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
    
    // If iCloud newly switched off, move iCloud docs to local
    if (!Settings.sharedInstance.iCloudOn && Settings.sharedInstance.iCloudWasOn && [self getICloudSafes].count) {
        [Alerts threeOptions:self
                       title:NSLocalizedString(@"safesvc_icloud_unavailable_title", @"iCloud Unavailable")
                     message:NSLocalizedString(@"safesvc_icloud_unavailable_question", @"What would you like to do with the databases currently on this device?")
           defaultButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_remove", @"Remove them, Keep on iCloud Only")
            secondButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_make_local", @"Make Local Copies")
             thirdButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_icloud_on", @"Switch iCloud Back On")
                      action:^(int response) {
                          if(response == 2) {           // @"Switch iCloud Back On"
                              [Settings sharedInstance].iCloudOn = YES;
                              [Settings sharedInstance].iCloudWasOn = [Settings sharedInstance].iCloudOn;
                          }
                          else if(response == 1) {      // @"Keep a Local Copy"
                              [[iCloudSafesCoordinator sharedInstance] migrateiCloudToLocal:^(BOOL show) {
                                  [self showiCloudMigrationUi:show];
                              }];
                          }
                          else if(response == 0) {
                              [self removeAllICloudSafes];
                          }
                      }];
    }
    
    Settings.sharedInstance.iCloudWasOn = Settings.sharedInstance.iCloudOn;
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
        [self openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
    }
}

- (UIViewController*)getVisibleViewController {
    UIViewController* navVisible = self.navigationController.visibleViewController;
    return navVisible.presentedViewController ? navVisible.presentedViewController : navVisible;
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
    
    // Clear Nav Stack and any modals...
    
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
                                           selector:@selector(appResignActive)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appBecameActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
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
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)setupTips {
    if(Settings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"safes_vc_tip", @"Tip displayed at top of screen. Slide left on Database for options");
    }
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = NSLocalizedString(@"safes_vc_empty_databases_list_tableview_title", @"Title displayed in tableview when there are no databases setup");
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = NSLocalizedString(@"safes_vc_empty_databases_list_tableview_subtitle", @"Subtitle displayed in tableview when there are no databases setup");

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{NSFontAttributeName: FontManager.sharedInstance.regularFont,
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    NSDictionary *attributes = @{
                                    NSFontAttributeName : FontManager.sharedInstance.regularFont,
                                    NSForegroundColorAttributeName : UIColor.systemBlueColor,
                                    };
    
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"safes_vc_empty_databases_list_get_started_button_title", @"Subtitle displayed in tableview when there are no databases setup") attributes:attributes];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    [self startOnboarding];
}

- (BOOL)isReasonablyNewUser {
    return [[Settings sharedInstance] getLaunchCount] <= 10;
}

#pragma mark - Table view data source

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        [SafesList.sharedInstance move:sourceIndexPath.row to:destinationIndexPath.row];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.collection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    [self populateDatabaseCell:cell database:safe];
    
    return cell;
}

- (UIImage*)getStatusImage:(SafeMetaData*)database {
    if(database.hasUnresolvedConflicts) {
        return [UIImage imageNamed:@"error"];
    }
    else if([Settings.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        return [UIImage imageNamed:@"rocket"];
    }
    else if(database.readOnly) {
        return [UIImage imageNamed:@"glasses"];
    }

    return nil;
}

- (void)populateDatabaseCell:(DatabaseCell*)cell database:(SafeMetaData*)database {
    UIImage* statusImage = Settings.sharedInstance.showDatabaseStatusIcon ? [self getStatusImage:database] : nil;
    
    NSString* topSubtitle = [self getDatabaseCellSubtitleField:database field:Settings.sharedInstance.databaseCellTopSubtitle];
    NSString* subtitle1 = [self getDatabaseCellSubtitleField:database field:Settings.sharedInstance.databaseCellSubtitle1];
    NSString* subtitle2 = [self getDatabaseCellSubtitleField:database field:Settings.sharedInstance.databaseCellSubtitle2];
    
    id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    UIImage* databaseIcon = Settings.sharedInstance.showDatabaseIcon ? [UIImage imageNamed:provider.icon] : nil;
    
    [cell set:database.nickName
  topSubtitle:topSubtitle
    subtitle1:subtitle1
    subtitle2:subtitle2
 providerIcon:databaseIcon
  statusImage:statusImage
     disabled:NO];
}

- (NSString*)getDatabaseCellSubtitleField:(SafeMetaData*)database field:(DatabaseCellSubtitleField)field {
    switch (field) {
        case kDatabaseCellSubtitleFieldNone:
            return nil;
            break;
        case kDatabaseCellSubtitleFieldFileName:
            return database.fileName;
            break;
        case kDatabaseCellSubtitleFieldLastCachedDate:
            return [self getOfflineCacheModDateString:database];
            break;
        case kDatabaseCellSubtitleFieldStorage:
            return [self getStorageString:database];
            break;
        default:
            return @"<Unknown Field>";
            break;
    }
}

- (NSString*)getStorageString:(SafeMetaData*)database {
    id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    
    NSString* providerString = provider.displayName;
    BOOL localDeviceOption = database.storageProvider == kLocalDevice;
    if(localDeviceOption) {
        providerString = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:database] ?
        NSLocalizedString(@"autofill_safes_vc_storage_local_name", @"Local") :
        NSLocalizedString(@"autofill_safes_vc_storage_local_docs_name", @"Local (Documents)");
    }
    return providerString;
}

- (NSString*)getOfflineCacheModDateString:(SafeMetaData*)database {
    NSDate* modDate = database.offlineCacheEnabled ? [CacheManager.sharedInstance getOfflineCacheFileModificationDate:database] : nil;
    return modDate ? [NSString stringWithFormat:NSLocalizedString(@"safes_vc_cached_date_time_fmt", @"Date and Time last cache was taken"), friendlyDateStringVeryShort(modDate)] : @"";
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        return;
    }
    
    [self openSafeAtIndexPath:indexPath offline:NO];
}

- (void)openSafeAtIndexPath:(NSIndexPath*)indexPath offline:(BOOL)offline {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];

    [self openDatabase:safe offline:offline userJustCompletedBiometricAuthentication:NO];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(SafeMetaData*)safe
             offline:(BOOL)offline
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
                                         manualOpenOfflineCache:offline
                                    biometricAuthenticationDone:userJustCompletedBiometricAuthentication
                                                     completion:^(Model * _Nullable model, NSError * _Nullable error) {
            if(model) {
                if (@available(iOS 11.0, *)) { // iOS 11 required as only new Item Details is supported
                    [self performSegueWithIdentifier:@"segueToMasterDetail" sender:model];
                }
                else {
                    [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:model];
                }
            }
                                                         
             [self refresh]; // Duress PIN may have caused a removal
         }];
    }
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
        [self openOffline:indexPath];
    }];
    offlineAction.backgroundColor = [UIColor darkGrayColor];

    // Other Options
    
    UITableViewRowAction *moreActions = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                           title:NSLocalizedString(@"safes_vc_slide_left_more_actions", @"View more actions table action")
                                                                         handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self showDatabaseMoreActions:indexPath];
    }];
    moreActions.backgroundColor = [UIColor systemBlueColor];

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL offlineOption = safe.offlineCacheEnabled && safe.offlineCacheAvailable;

    return offlineOption ? @[removeAction, offlineAction, moreActions] : @[removeAction, moreActions];
}

- (void)showDatabaseMoreActions:(NSIndexPath*)indexPath {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"safes_vc_database_actions_sheet_title", @"Title of the 'More Actions' alert/action sheet")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    // Rename Action...
    
    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_action_rename_database", @"Button to Rename the Database")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *a) {
                                                             [self renameSafe:indexPath];
                                                         } ];
    [alertController addAction:renameAction];
    
    // Quick Launch Option

    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL isAlreadyQuickLaunch = [Settings.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid];
    UIAlertAction *quickLaunchAction = [UIAlertAction actionWithTitle:isAlreadyQuickLaunch ?
                                        NSLocalizedString(@"safes_vc_action_unset_as_quick_launch", @"Button Title to Unset Quick Launch") :
                                        NSLocalizedString(@"safes_vc_action_set_as_quick_launch", @"Button Title to Set Quick Launch")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              [self toggleQuickLaunch:safe];
                                                          } ];
    [alertController addAction:quickLaunchAction];

    // Start Re-ordering...
    
    UIAlertAction *reorderAction = [UIAlertAction actionWithTitle:
            NSLocalizedString(@"safes_vc_action_reorder_database", @"Button Title to reorder this database")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              [self setEditing:YES];
                                                        } ];
    
    [alertController addAction:reorderAction];
    
    // Local Device options
    
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
    
    // Backups
    
    UIAlertAction *viewBackupsOption = [UIAlertAction actionWithTitle:
            NSLocalizedString(@"safes_vc_action_backups", @"Button Title to view backup settings of this database")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
            [self performSegueWithIdentifier:@"segueToBackups" sender:safe];
        }];
    
    [alertController addAction:viewBackupsOption];

    // Cancel
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel Button")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alertController addAction:cancelAction];
    
//    alertController.popoverPresentationController.sourceView = self.view;
//    alertController.popoverPresentationController.sourceRect = sender;
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)toggleQuickLaunch:(SafeMetaData*)database {
    if([Settings.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        Settings.sharedInstance.quickLaunchUuid = nil;
        [self refresh];
    }
    else {
        [Alerts yesNo:self
                title:NSLocalizedString(@"safes_vc_about_quick_launch_title", @"Title of Prompt about setting Quick Launch")
              message:NSLocalizedString(@"safes_vc_about_setting_quick_launch_and_confirm", @"Message about quick launch feature and asking to confirm yes or no")
               action:^(BOOL response) {
            if (response) {
                Settings.sharedInstance.quickLaunchUuid = database.uuid;
                [self refresh];
            }
        }];
    }
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
    if (![LocalDeviceStorageProvider.sharedInstance toggleSharedStorage:metadata error:&error]) {
        [Alerts error:self title:NSLocalizedString(@"safes_vc_could_not_change_storage_location_error", @"error message could not change local storage") error:error];
    }
    else {
        BOOL previouslyShared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:metadata];

        NSString* message = !previouslyShared ?
            NSLocalizedString(@"safes_vc_database_made_visible_in_files", @"informational message - made the file visible in iOS Files") :
            NSLocalizedString(@"safes_vc_database_made_fully_autofillable", @"informational message - made the database fully autofillable");
        [Alerts info:self
               title:NSLocalizedString(@"safes_vc_local_storage_mode_changed", @"information message = title changed storage mode")
             message:message];
    }
}

- (void)openOffline:(NSIndexPath*)indexPath {
    [self openSafeAtIndexPath:indexPath offline:YES];
}

- (void)renameSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *database = [self.collection objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"segueToRenameDatabase" sender:database];
}

- (void)removeSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString *message;
    
    if(safe.storageProvider == kiCloud && [Settings sharedInstance].iCloudOn) {
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
    
    if (safe.offlineCacheEnabled && safe.offlineCacheAvailable) {
        [[CacheManager sharedInstance] deleteOfflineCachedSafe:safe completion:^(NSError *error) {
          NSLog(@"Delete Offline Cache File. Error = %@", error);
      }];
    }
    
    if(safe.autoFillEnabled && safe.autoFillCacheAvailable) {
        [CacheManager.sharedInstance deleteAutoFillCache:safe completion:^(NSError * _Nonnull error) {
            NSLog(@"Delete Auto Fill Cache File. Error = %@", error);
        }];
    }
    
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    
    // Clear Quick Launch if it was set...
    if([Settings.sharedInstance.quickLaunchUuid isEqualToString:safe.uuid]) {
        Settings.sharedInstance.quickLaunchUuid = nil;
    }
    
    // Delete all backups...
    
    [BackupsManager.sharedInstance deleteAllBackups:safe];
    
    [[SafesList sharedInstance] remove:safe.uuid];
}

//////////////////////////////////////////////////////////////////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToMasterDetail"] || [segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc;
        if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
            vc = segue.destinationViewController;
        }
        else {
            UISplitViewController *svc = segue.destinationViewController;
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
        BOOL editInPlace = numEIP.boolValue;
        
        if(url && url.lastPathComponent.length) {
            NSString* suggestion = url.lastPathComponent.stringByDeletingPathExtension;
            scVc.initialName = [SafesList.sharedInstance getUniqueNameFromSuggestedName:suggestion];
        }
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    if(editInPlace) {
                        [self addExternalFileReferenceSafe:creds.name data:data url:url];
                    }
                    else {
                        [self copyAndAddImportedSafe:creds.name data:data url:url];
                    }
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToWelcome"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        
        WelcomeAddDatabaseViewController* vc = (WelcomeAddDatabaseViewController*)nav.topViewController;
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
        
        NSDictionary *d = sender; // @{@"database" : metadata, @"password" : password}
        
        wcdvc.database = d[@"database"];
        wcdvc.password = d[@"password"];
        
        wcdvc.onDone = ^(BOOL addExisting, SafeMetaData * _Nullable databaseToOpen) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(databaseToOpen) {
                     [self openDatabase:databaseToOpen offline:NO userJustCompletedBiometricAuthentication:NO];
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
    else if ([segue.identifier isEqualToString:@"segueToUpgrade"]) {
        UIViewController* vc = segue.destinationViewController;
        if (@available(iOS 13.0, *)) {
            if (!Settings.sharedInstance.isFreeTrial) {
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.modalInPresentation = YES;
            }
        }
    }
}

- (void)onOnboardingDoneWithAddDatabase:(BOOL)addExisting
                         databaseToOpen:(SafeMetaData*)databaseToOpen {
    if(addExisting) {
        // Here we can check if the user enabled iCloud and we've found an existing database and ask if they
        // want to continue adding the database...

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
        [self openDatabase:databaseToOpen offline:NO userJustCompletedBiometricAuthentication:NO];
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
                                      url:credentials.keyFileUrl
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
            NSLog(@"Files App: [%@]", params.url);
            [self import:params.url canOpenInPlace:YES forceOpenInPlace:YES];
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
    if(storageParams.data) { // Manual URL Download and Add
        [self addManuallyDownloadedUrlDatabase:name data:storageParams.data];
    }
    else { // Standard Native Storage add
        SafeMetaData* database = [storageParams.provider getSafeMetaData:name providerData:storageParams.file.providerData];
        database.likelyFormat = storageParams.likelyFormat;
        
        if(database == nil) {
            [Alerts warn:self title:NSLocalizedString(@"safes_vc_error_adding_database", @"Error title: error adding database") message:NSLocalizedString(@"safes_vc_unknown_error_while_adding_database", @"Error Message- unknown error while adding")];
        }
        else {
            [SafesList.sharedInstance add:database];
        }
    }
}

- (void)onCreateNewDatabaseDone:(SelectedStorageParameters*)storageParams
                           name:(NSString*)name
                       password:(NSString*)password
                            url:(NSURL*)url
                 onceOffKeyFile:(NSData*)onceOffKeyFile
                  yubiKeyConfig:(YubiKeyHardwareConfiguration*)yubiKeyConfig
                         format:(DatabaseFormat)format {
    [AddNewSafeHelper createNewDatabase:self
                                   name:name
                               password:password
                             keyFileUrl:url
                     onceOffKeyFileData:onceOffKeyFile
                          yubiKeyConfig:yubiKeyConfig
                          storageParams:storageParams
                                 format:format
                             completion:^(BOOL userCancelled, SafeMetaData * _Nullable metadata, NSError * _Nullable error) {
        if (userCancelled) {
            // NOP?
        }
        else if (error || !metadata) {
            [Alerts error:self
                    title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error creating database")
                    error:error];
        }
        else {
            [self addDatabaseWithiCloudRaceCheck:metadata];
        }
    }];
}

- (void)onCreateNewExpressDatabaseDone:(NSString*)name
                              password:(NSString*)password {
    [AddNewSafeHelper createNewExpressDatabase:self
                                          name:name
                                      password:password
                                    completion:^(BOOL userCancelled, SafeMetaData * _Nonnull metadata, NSError * _Nonnull error) {
        if (userCancelled) {
            // NOP
        }
        else if(error || !metadata) {
            [Alerts error:self
                    title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error while creating database")
                    error:error];
        }
        else {
            metadata = [self addDatabaseWithiCloudRaceCheck:metadata];
            [self performSegueWithIdentifier:@"segueToCreateExpressDone"
                                      sender:@{@"database" : metadata, @"password" : password }];
        }
    }];
}

- (SafeMetaData*)addDatabaseWithiCloudRaceCheck:(SafeMetaData*)metadata {
    if (metadata.storageProvider == kiCloud) {
        SafeMetaData* existing = [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
            return obj.storageProvider == kiCloud && [obj.fileName isEqualToString:metadata.fileName];
        }];
        
        if(existing) { // May have already been added by our iCloud watch thread.
            NSLog(@"Not Adding as this iCloud filename is already present. Probably picked up by Watch Thread.");
            return existing;
        }
    }
    
    [[SafesList sharedInstance] add:metadata];
    return metadata;
}

- (void)addManuallyDownloadedUrlDatabase:(NSString *)nickName data:(NSData *)data {
    if(Settings.sharedInstance.iCloudOn) {
        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"safes_vc_copy_icloud_or_local", @"Question Title: Copy to icloud or to local")
                             message:NSLocalizedString(@"safes_vc_copy_local_to_icloud", @"Question message: copy to iCloud or to Local")
                   defaultButtonText:NSLocalizedString(@"safes_vc_copy_to_local", @"Default button: Copy to Local")
                    secondButtonText:NSLocalizedString(@"safes_vc_copy_to_icloud", @"Second Button: Copy to iCLoud")
                              action:^(int response) {
                                  if(response == 0) {
                                      [self addManualDownloadUrl:NO data:data nickName:nickName];
                                  }
                                  else if(response == 1) {
                                      [self addManualDownloadUrl:YES data:data nickName:nickName];
                                  }
                              }];
    }
    else {
        [self addManualDownloadUrl:NO data:data nickName:nickName];
    }
}

- (void)addManualDownloadUrl:(BOOL)iCloud data:(NSData*)data nickName:(NSString *)nickName {
    id<SafeStorageProvider> provider;

    if(iCloud) {
        provider = AppleICloudProvider.sharedInstance;
    }
    else {
        provider = LocalDeviceStorageProvider.sharedInstance;
    }

    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    
    [provider create:nickName
           extension:extension
                data:data
        parentFolder:nil
      viewController:self
          completion:^(SafeMetaData *metadata, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
            }
            else {
                [Alerts error:self title:NSLocalizedString(@"safes_vc_error_importing_database", @"Error Title Error Importing Datavase") error:error];
            }
        });
     }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Add / Import

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
    
    // Create New
    
    UIAlertAction *createNewAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_new_database_advanced", @"")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
                                                       [self onCreateNewSafe];
                                                   }];
    [alertController addAction:createNewAction];
    
    // Express
    
//    if(Settings.sharedInstance.iCloudAvailable && Settings.sharedInstance.iCloudOn) {
        UIAlertAction *quickAndEasyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_new_database_express", @"")
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *a) {
                                                                    [self onNewExpressDatabase];
                                                                }];
        
        // [quickAndEasyAction setValue:[UIColor greenColor] forKey:@"titleTextColor"];
        // [quickAndEasyAction setValue:[UIImage imageNamed:@"fast-forward-2-32"] forKey:@"image"];
        [alertController addAction:quickAndEasyAction];
  //  }
    
    // Cancel
    
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onUpgrade:(id)sender {
    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
}

-(void)addToolbarButton:(UIBarButtonItem*)button {
    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];

    if (![toolbarButtons containsObject:button]) {
        [toolbarButtons addObject:button];
        [self setToolbarItems:toolbarButtons animated:NO];
    }
}

-(void)removeToolbarButton:(UIBarButtonItem*)button {
    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];
    [toolbarButtons removeObject:button];
    [self setToolbarItems:toolbarButtons animated:NO];
}

- (void)onProStatusChanged:(id)param {
    NSLog(@"Pro Status Changed!");
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindProOrFreeTrialUi];
    });
}

-(void)bindProOrFreeTrialUi {
    self.navigationController.toolbarHidden =  [[Settings sharedInstance] isPro];
    self.navigationController.toolbar.hidden = [[Settings sharedInstance] isPro];
    
    if(![[Settings sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
    
        NSString *upgradeButtonTitle;

        if (Settings.sharedInstance.hasOptedInToFreeTrial) {
            if([[Settings sharedInstance] isFreeTrial]) {
                NSInteger daysLeft = Settings.sharedInstance.freeTrialDaysLeft;
                
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
    // Only do this if we are the currently visible VC

    if(![self isVisibleViewController]) {
        NSLog(@"Not opening Quick Launch database as not at top of the Nav Stack");
        return;
    }
    
    if(!Settings.sharedInstance.quickLaunchUuid) {
        // NSLog(@"Not opening Quick Launch database as not configured");
        return;
    }
    
    SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
        return [obj.uuid isEqualToString:Settings.sharedInstance.quickLaunchUuid];
    }];
    
    if(!safe) {
        NSLog(@"Not opening Quick Launch database as configured database not found");
        return;
    }
    
    [self openDatabase:safe offline:NO userJustCompletedBiometricAuthentication:userJustCompletedBiometricAuthentication];
}

// iCloud Availability and Import / Export

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

// Importation

- (void)import:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"set_icon_vc_progress_reading_data", @"Reading Data...")];
    
    if(!url || url.absoluteString.length == 0) {
        NSLog(@"nil or empty URL in Files App provider");
        [self onReadImportedFile:NO data:nil url:url canOpenInPlace:NO forceOpenInPlace:NO];
        return;
    }

    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    [document openWithCompletionHandler:^(BOOL success) {
        [SVProgressHUD dismiss];
        
        NSData* data = document.data;
        
        [document closeWithCompletionHandler:nil];
        
        // Inbox should be empty whenever possible so that we can detect the
        // re-importation of a certain file and ask if user wants to create a
        // new copy or just update an old one...
        [FileManager.sharedInstance deleteAllInboxItems];
        
        [self onReadImportedFile:success data:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace];
    }];
}

- (void)onReadImportedFile:(BOOL)success data:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    if(!success || !data) {
        [Alerts warn:self
               title:NSLocalizedString(@"safesvc_error_title_import_file_error_opening", @"Error Opening")
             message:NSLocalizedString(@"safesvc_error_message_import_file_error_opening", @"Could not access this file.")];
    }
    else {
        if([url.pathExtension caseInsensitiveCompare:@"key"] ==  NSOrderedSame) {
            [self importKey:data url:url];
        }
        else {
            [self importSafe:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace];
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

-(void)importSafe:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    NSError* error;
    
    if (![DatabaseModel isAValidSafe:data error:&error]) {
        [Alerts error:self
                title:[NSString stringWithFormat:NSLocalizedString(@"safesvc_error_title_import_database_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                error:error];
        return;
    }
    
    if(canOpenInPlace) {
        if(forceOpenInPlace) {
            [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:YES];
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
                                  [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:response == 0];
                              }
                          }];
        }
    }
    else {
        [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:NO];
    }
}

- (void)checkForLocalFileOverwriteOrGetNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace {
    if(editInPlace == NO) {
        NSString* filename = url.lastPathComponent;
        if([LocalDeviceStorageProvider.sharedInstance fileNameExistsInDefaultStorage:filename] && Settings.sharedInstance.iCloudOn == NO) {
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
                                          }
                                      }
                                      else if (response == 1){
                                          [self promptForNickname:data url:url editInPlace:editInPlace];
                                      }
                                  }];
        }
        else {
            [self promptForNickname:data url:url editInPlace:editInPlace];
        }
    }
    else {
        [self promptForNickname:data url:url editInPlace:editInPlace];
    }
}

- (void)promptForNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace {
    [self performSegueWithIdentifier:@"segueFromInitialToAddDatabase"
                              sender:@{ @"editInPlace" : @(editInPlace),
                                        @"url" : url,
                                        @"data" : data }];
}

/////////////

- (void)importFromManualUiUrl:(NSURL *)importURL {
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    
    NSError* error;
    if (![DatabaseModel isAValidSafe:importedData error:&error]) {
        [Alerts error:self
                title:NSLocalizedString(@"safesvc_import_manual_url_invalid", @"Invalid Database")
                error:error];
        
        return;
    }
    
    [self checkForLocalFileOverwriteOrGetNickname:importedData url:importURL editInPlace:NO];
}

- (void)enqueueImport:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace {
    self.enqueuedImportUrl = url;
    self.enqueuedImportCanOpenInPlace = canOpenInPlace;
}

- (void)copyAndAddImportedSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url  {
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    
    if(Settings.sharedInstance.iCloudOn) {
        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"safesvc_copy_database_to_location_title", @"Copy to iCloud or Local?")
                             message:NSLocalizedString(@"safesvc_copy_database_to_location_message", @"iCloud is currently enabled. Would you like to copy this database to iCloud now, or would you prefer to keep on your local device only?")
                   defaultButtonText:NSLocalizedString(@"safesvc_copy_database_option_to_local", @"Copy to Local Device Only")
                    secondButtonText:NSLocalizedString(@"safesvc_copy_database_option_to_icloud", @"Copy to iCloud")
                              action:^(int response) {
                                  if(response == 0) {
                                      [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data];
                                  }
                                  else if(response == 1) {
                                      [self importToICloud:url format:format nickName:nickName extension:extension data:data];
                                  }
                              }];
    }
    else {
        [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data];
    }
}

- (void)importToICloud:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data {
    NSString *suggestedFilename = url.lastPathComponent;
    
    [AppleICloudProvider.sharedInstance create:nickName
                                     extension:extension
                                          data:data
                             suggestedFilename:suggestedFilename
                                  parentFolder:nil
                                viewController:self
                                    completion:^(SafeMetaData *metadata, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
             if (error == nil) {
                 metadata.likelyFormat = format;
                 [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
             }
             else {
                 [Alerts error:self
                         title:NSLocalizedString(@"safesvc_error_importing_title", @"Error Importing Database")
                         error:error];
             }
         });
     }];
}

- (void)importToLocalDevice:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data {
    // Try to keep the filename the same... but don't overwrite any existing, will have asked previously above if the user wanted to
    
    NSString *suggestedFilename = url.lastPathComponent;
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                            extension:extension
                                                 data:data
                                    suggestedFilename:suggestedFilename
                                           completion:^(SafeMetaData *metadata, NSError *error) {
                                               dispatch_async(dispatch_get_main_queue(), ^(void) {
                                                   if (error == nil) {
                                                       metadata.likelyFormat = format;
                                                       [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
                                                   }
                                                   else {
                                                       [Alerts error:self
                                                               title:NSLocalizedString(@"safesvc_error_importing_title", @"Error Importing Database")
                                                               error:error];
                                                   }
                                               });
                                           }];
}

- (void)addExternalFileReferenceSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url {
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
    
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    metadata.likelyFormat = format;
    
    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
}

@end
