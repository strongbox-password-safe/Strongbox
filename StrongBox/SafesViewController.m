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
#import "InitialViewController.h"
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
#import "WelcomeViewController.h"
#import "WelcomeCreateDoneViewController.h"
#import "NSArray+Extensions.h"
#import "FileManager.h"
#import "CacheManager.h"
#import "LocalDeviceStorageProvider.h"
#import "Utils.h"
#import "DatabasesViewPreferencesController.h"

@interface SafesViewController () <DZNEmptyDataSetDelegate>

@property (nonatomic, copy) NSArray<SafeMetaData*> *collection;

@end

@implementation SafesViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.tableView.contentOffset.y < 0 && self.tableView.emptyDataSetVisible) {
        self.tableView.contentOffset = CGPointZero;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self refresh];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    [self.navigationItem setPrompt:nil];
    
    [self.navigationController setNavigationBarHidden:NO];
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    [self bindProOrFreeTrialUi];
    
    [[self getInitialViewController] checkICloudAvailability];
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self internalRefresh];
    });
}

- (void)internalRefresh {
    self.collection = SafesList.sharedInstance.snapshot;
    
    self.tableView.separatorStyle = Settings.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;

    if (self.collection.count > 0) {
        [self removeEditButtonInLeftBar];
        [self insertEditButtonInLeftBar];
    }
    else {
        [self removeEditButtonInLeftBar];
    }
    
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.collection = [NSArray array];

    [self insertEditButtonInLeftBar];

    [self setupTableview];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refresh)
                                               name:kDatabasesListChangedNotification
                                             object:nil];
        
    [self internalRefresh];
    
    if([Settings.sharedInstance getLaunchCount] == 1) {
        [self startOnboarding];
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
                                    NSForegroundColorAttributeName : UIColor.blueColor
                                    };
    
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"safes_vc_empty_databases_list_get_started_button_title", @"Subtitle displayed in tableview when there are no databases setup") attributes:attributes];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    [self startOnboarding];
}

- (void)startOnboarding {
    [self performSegueWithIdentifier:@"segueToWelcome" sender:nil];
}

- (BOOL)isReasonablyNewUser {
    return [[Settings sharedInstance] getLaunchCount] <= 10;
}

#pragma mark - Table view data source

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
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
        providerString = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:database] ? @"Local" : @"Local (Documents)";
    }
    return providerString;
}

- (NSString*)getOfflineCacheModDateString:(SafeMetaData*)database {
    NSDate* modDate = database.offlineCacheEnabled ? [CacheManager.sharedInstance getOfflineCacheFileModificationDate:database] : nil;
    return modDate ? [NSString stringWithFormat:NSLocalizedString(@"safes_vc_cached_date_time", @"Date and Time last cache was taken"), friendlyDateStringVeryShort(modDate)] : @"";
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
                    if(!Settings.sharedInstance.doNotUseNewSplitViewController) {
                        [self performSegueWithIdentifier:@"segueToMasterDetail" sender:model];
                    }
                    else {
                        [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:model];
                    }
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
    moreActions.backgroundColor = [UIColor blueColor];

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
    
    // Local Device options
    
    BOOL localDeviceOption = safe.storageProvider == kLocalDevice;
    if(localDeviceOption) {
        BOOL shared = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:safe];
        NSString* localDeviceActionTitle = shared ? NSLocalizedString(@"safes_vc_show_in_files", @"Button Title to Show in Files") : NSLocalizedString(@"safes_vc_make_autofillable", @"Button Title to Make AutoFillable");

        UIAlertAction *secondAction = [UIAlertAction actionWithTitle:localDeviceActionTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) {
                                                                 [self promptAboutToggleLocalStorage:indexPath shared:shared];
                                                             }];
        [alertController addAction:secondAction];
    }
    
    // Cancel
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_cancel", @"Cancel Button")
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
        NSLocalizedString(@"safes_vc_make_database_auto_fill_info", @"Button tutle to make database Auto Fill-able");
    
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
        message = [NSString stringWithFormat:NSLocalizedString(@"safes_vc_are_you_sure_remove_database", @"are you sure you want to remove database prompt with format string on end"),
                         (safe.storageProvider == kiCloud || safe.storageProvider == kLocalDevice)  ? @"" : NSLocalizedString(@"safes_vc_extra_info_underlying_database", @"extra info appended to string about the underlying storage type")];
    }
    
    [Alerts yesNo:self
            title:NSLocalizedString(@"safes_vc_question_confirm_are_you_sure", @"Are you sure? Title")
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
    
    [[SafesList sharedInstance] remove:safe.uuid];
}

//////////////////////////////////////////////////////////////////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.database.rootGroup;
    }
    else if ([segue.identifier isEqualToString:@"segueToMasterDetail"]) {
        UISplitViewController *svc = segue.destinationViewController;
        UINavigationController *nav = [svc.viewControllers firstObject];
        
        BrowseSafeView *vc = (BrowseSafeView*)nav.topViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.database.rootGroup;
    }
    else if ([segue.identifier isEqualToString:@"segueToStorageType"])
    {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SelectStorageProviderController *vc = (SelectStorageProviderController*)nav.topViewController;
        
        NSString *newOrExisting = (NSString *)sender;
        BOOL existing = [newOrExisting isEqualToString:@"Existing"];
        vc.existing = existing;
        
        vc.onDone = ^(SelectedStorageParameters *params) {
            params.createMode = !existing;
            [self onSelectedStorageLocation:params];
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
                [[self getInitialViewController] checkICloudAvailability];
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
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [self onCreateOrAddDialogDismissedSuccessfully:params credentials:creds];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToWelcome"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        WelcomeViewController* vc = (WelcomeViewController*)nav.topViewController;
        vc.onDone = ^(BOOL addExisting, SafeMetaData * _Nonnull databaseToOpen) {
            [self dismissViewControllerAnimated:YES completion:^{
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
            [[self getInitialViewController] import:params.url canOpenInPlace:YES forceOpenInPlace:YES];
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
                         format:(DatabaseFormat)format {
    [AddNewSafeHelper createNewDatabase:self
                                   name:name
                               password:password
                             keyFileUrl:url
                     onceOffKeyFileData:onceOffKeyFile
                          storageParams:storageParams
                                 format:format
                             completion:^(SafeMetaData * _Nonnull metadata, NSError * _Nonnull error) {
                                 if(error || !metadata) {
                                     [Alerts error:self title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error creating database") error:error];
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
                                    completion:^(SafeMetaData * _Nonnull metadata, NSError * _Nonnull error) {
                                        if(error || !metadata) {
                                            [Alerts error:self title:NSLocalizedString(@"safes_vc_error_creating_database", @"Error Title: Error while creating database") error:error];
                                        }
                                        else {
                                            metadata = [self addDatabaseWithiCloudRaceCheck:metadata];
                                            [self performSegueWithIdentifier:@"segueToCreateExpressDone" sender:@{@"database" : metadata, @"password" : password} ];
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
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"safes_vc_cancel", @"")
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
        if([[Settings sharedInstance] isFreeTrial]) {
            NSInteger daysLeft = [[Settings sharedInstance] getFreeTrialDaysRemaining];
            
            if(daysLeft > 30) {
                upgradeButtonTitle = [NSString stringWithFormat:NSLocalizedString(@"safes_vc_upgrade_info_button_title", @"Upgrade Button Title - Upgrade Info")];
            }
            else {
                upgradeButtonTitle = [NSString stringWithFormat:NSLocalizedString(@"safes_vc_upgrade_info_button_title_days_remaining", @"Upgrade Button Title with Days remaining of pro trial version"),
                                  (long)daysLeft];
            }
            
            if(daysLeft < 10) {
                [self.buttonUpgrade setTintColor: [UIColor redColor]];
            }
        }
        else {
            upgradeButtonTitle = NSLocalizedString(@"safes_vc_upgrade_info_button_title_please_upgrade", @"Upgrade Button Title asking to Please Upgrade");
            [self.buttonUpgrade setTintColor: [UIColor redColor]];
        }
        
        [self.buttonUpgrade setTitle:upgradeButtonTitle];
    }
    else {
        [self.buttonUpgrade setEnabled:NO];
        [self.buttonUpgrade setTintColor: [UIColor clearColor]];
    }
}

- (InitialViewController *)getInitialViewController {
    InitialViewController *ivc = (InitialViewController*)self.navigationController.parentViewController;
    return ivc;
}

- (IBAction)onPreferences:(id)sender {
    if (!Settings.sharedInstance.appLockAppliesToPreferences || Settings.sharedInstance.appLockMode == kNoLock) {
        [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
        return;
    }
    
    if((Settings.sharedInstance.appLockMode == kBiometric || Settings.sharedInstance.appLockMode == kBoth) && Settings.isBiometricIdAvailable) {
        [self requestBiometricBeforeOpeningPreferences];
    }
    else if (Settings.sharedInstance.appLockMode == kPinCode || Settings.sharedInstance.appLockMode == kBoth) {
        [self requestPin];
    }
}

- (void)requestBiometricBeforeOpeningPreferences {
    [Settings.sharedInstance requestBiometricId:@"Identify to Open Preferences"
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

// Quick Launch

- (void)openQuickLaunchDatabase:(BOOL)userJustCompletedBiometricAuthentication {
    // Only do this if we are top of the nav stack
    
    if(self.navigationController.topViewController != self) {
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

@end
