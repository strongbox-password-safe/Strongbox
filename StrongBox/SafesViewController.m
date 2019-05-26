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
#import "SafeItemTableCell.h"
#import "VersionConflictController.h"
#import "InitialViewController.h"
#import "AppleICloudProvider.h"
#import "SafeStorageProviderFactory.h"
#import "OpenSafeSequenceHelper.h"
#import "NewSafeFormatController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "AddNewSafeHelper.h"
#import "AddSafeAlertController.h"
#import "StrongboxUIDocument.h"
#import "SVProgressHUD.h"
#import "AutoFillManager.h"
#import "PinEntryController.h"

@interface SafesViewController () <UIDocumentPickerDelegate>

@property (nonatomic, copy) NSArray<SafeMetaData*> *collection;
@property NSURL* temporaryExportUrl;

@end

@implementation SafesViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.tableView.contentOffset.y < 0 && self.tableView.emptyDataSetVisible) {
        self.tableView.contentOffset = CGPointZero;
    }
}

- (void)syncLocalSafesWithFileSystem {
    BOOL changedSomething = NO;
    
    // Add any new
    
    NSArray<StorageBrowserItem*> *items = [LocalDeviceStorageProvider.sharedInstance scanForNewSafes];
    
    if(items.count) {
        for(StorageBrowserItem* item in items) {
            NSString* name = [SafesList sanitizeSafeNickName:[item.name stringByDeletingPathExtension]];
            SafeMetaData *safe = [LocalDeviceStorageProvider.sharedInstance getSafeMetaData:name
                                                                               providerData:item.providerData];
            [[SafesList sharedInstance] add:safe];
        }
        
        changedSomething = YES;
    }
    
    // Remove deleted
    
    NSArray<SafeMetaData*> *localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    
    for (SafeMetaData* localSafe in localSafes) {
        if(![LocalDeviceStorageProvider.sharedInstance fileExists:localSafe]) {
            NSLog(@"Removing Safe [%@] because underlying file [%@] no longer exists in Documents Directory.", localSafe.nickName, localSafe.fileName);
            [SafesList.sharedInstance remove:localSafe.uuid];
            changedSomething = YES;
        }
    }
    
    if(changedSomething) {
        [self reloadSafes];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self reloadSafes];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    [self.navigationItem setPrompt:nil];
    
    [self.navigationController setNavigationBarHidden:NO];
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    [self bindProOrFreeTrialUi];
    
    if(!Settings.sharedInstance.doNotAutoAddNewLocalSafes) {
        [LocalDeviceStorageProvider.sharedInstance startMonitoringDocumentsDirectory:^{
            NSLog(@"File Change Detected! Scanning for New Safes");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self syncLocalSafesWithFileSystem];
            });
        }];
        
        [self syncLocalSafesWithFileSystem];
    }
    
    [self segueToNagScreenIfAppropriate];
    
    [[self getInitialViewController] checkICloudAvailability];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if(!Settings.sharedInstance.doNotAutoAddNewLocalSafes) {
        [LocalDeviceStorageProvider.sharedInstance stopMonitoringDocumentsDirectory];
    }
}

- (void)reloadSafes {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.collection = SafesList.sharedInstance.snapshot;
        
        [self.tableView reloadData];
        
        self.buttonToggleEdit.enabled = (self.collection.count > 0);
        [self.buttonToggleEdit setTintColor:(self.collection.count > 0) ? nil : [UIColor clearColor]];

        if([[self getInitialViewController] getPrimarySafe]) {
            [self.barButtonQuickLaunchView setEnabled:YES];
            [self.barButtonQuickLaunchView setTintColor:nil];
        }
        else {
            [self.barButtonQuickLaunchView setEnabled:NO];
            [self.barButtonQuickLaunchView setTintColor: [UIColor clearColor]];
        }
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.collection = [NSArray array];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
    
    self.tableView.rowHeight = 65.0f;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotificationKey
                                             object:nil];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIImage imageNamed:@"Strongbox-215x215"];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"No Password Databases Here Yet";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"Tap the + button in the top right corner to get started!";
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (BOOL)isReasonablyNewUser {
    return [[Settings sharedInstance] getLaunchCount] <= 10;
}

#pragma mark - Table view data source

-(void)onToggleEdit:(id)sender {
    [self.tableView setEditing:!self.tableView.editing animated:YES];
    
    if (self.tableView.editing)
    {
        [self.buttonToggleEdit setTitle:@"Done"];
        [self.buttonToggleEdit setStyle:UIBarButtonItemStyleDone];
    }
    else
    {
        [self.buttonToggleEdit setTitle:@"Edit"];
        [self.buttonToggleEdit setStyle:UIBarButtonItemStylePlain];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        [SafesList.sharedInstance move:sourceIndexPath.row to:destinationIndexPath.row];
        [self reloadSafes];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.collection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SafeItemTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier" forIndexPath:indexPath];
    
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    cell.textLabel.text = safe.nickName;
    cell.detailTextLabel.text = safe.fileName;
    
    id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:safe.storageProvider];

    NSString *icon = provider.icon;
    cell.imageView.image = [UIImage imageNamed:icon];
    cell.imageViewWarningIndicator.hidden = !safe.hasUnresolvedConflicts;
    
    return cell;
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
    
    if(safe.hasUnresolvedConflicts) {
        [self performSegueWithIdentifier:@"segueToVersionConflictResolution" sender:safe.fileIdentifier];
    }
    else {
        [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                           safe:safe
                                            canConvenienceEnrol:YES
                                                 isAutoFillOpen:NO
                                         manualOpenOfflineCache:offline
                                                     completion:^(Model * _Nullable model, NSError * _Nullable error) {
            if(model) {
                [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:model];
            }
                                                         
            [self reloadSafes]; // Duress might have remove a safe
         }];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Remove" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeSafe:indexPath];
    }];

    UITableViewRowAction *renameAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Rename" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self renameSafe:indexPath];
    }];

    renameAction.backgroundColor = [UIColor blueColor];
    
    UITableViewRowAction *exportAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Export" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onExportSafe:indexPath];
    }];
    
    exportAction.backgroundColor = [UIColor orangeColor]; // TODO: Move export into Details Screen... too many actions here
 
    NSMutableArray* actions = [NSMutableArray arrayWithArray:@[removeAction, renameAction, exportAction]];
    
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    BOOL hasKeyFile = [OpenSafeSequenceHelper findAssociatedLocalKeyFile:safe.fileName] != nil;
    if(hasKeyFile) {
        UITableViewRowAction *removeKeyFileAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Remove Local Key File" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
            [self removeLocalKeyFile:indexPath];
        }];
        removeKeyFileAction.backgroundColor = [UIColor magentaColor];

        [actions addObject:removeKeyFileAction];
    }
    
    if(safe.offlineCacheEnabled && safe.offlineCacheAvailable) {
        UITableViewRowAction *openOffline = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"Open Offline" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
            [self openOffline:indexPath];
        }];
        openOffline.backgroundColor = [UIColor darkGrayColor];

        [actions addObject:openOffline];
    }
    
    return actions;
}

- (void)openOffline:(NSIndexPath*)indexPath {
    [self openSafeAtIndexPath:indexPath offline:YES];
}

- (void)removeLocalKeyFile:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    NSString* fileName = [OpenSafeSequenceHelper getExpectedAssociatedLocalKeyFileName:safe.fileName];
    
    if([LocalDeviceStorageProvider.sharedInstance deleteWithCaseInsensitiveFilename:fileName]) {
        [Alerts info:self title:@"Key File Removed" message:@"The associated local key file was removed."];
    }
    else {
        [Alerts info:self title:@"Key File Not Removed" message:@"The associated local key file could not be removed. Either it was not found or there was an issue deleting. Try using iTunes File Sharing to remove or check if present."];
    }
}

- (void)renameSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    [Alerts OkCancelWithTextField:self
                    textFieldText:safe.nickName
                            title:@"Rename Database"
                          message:@"Please enter a new name for this database"
                       completion:^(NSString *text, BOOL response) {
        if(response) {
            if([SafesList.sharedInstance isValidNickName:text]) {
                safe.nickName = text;
                [SafesList.sharedInstance update:safe];
                [self reloadSafes];
            }
            else {
                [Alerts warn:self title:@"Invalid Name" message:@"That is an invalid name, possibly because one with that name already exists, or because it contains invalid characters. Please try again."];
            }
        }
    }];
}

- (void)removeSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    NSString *message;
    
    if(safe.storageProvider == kiCloud && [Settings sharedInstance].iCloudOn) {
        message = @"This will remove the database from all your iCloud enabled devices.\n\n"
                    @"Are you sure you want to remove this database from Strongbox and iCloud?";
    }
    else {
        message = [NSString stringWithFormat:@"Are you sure you want to remove this database from Strongbox?%@",
                         (safe.storageProvider == kiCloud || safe.storageProvider == kLocalDevice)  ? @"" : @" (NB: The underlying database file will not be deleted)"];
    }
    
    [Alerts yesNo:self
            title:@"Are you sure?"
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
                [Alerts error:self title:@"Error Deleting iCloud Database" error:error];
                return;
            }
            else {
                NSLog(@"iCloud file removed");
            }
        }];
    }
         
    if (safe.offlineCacheEnabled && safe.offlineCacheAvailable)
    {
        [[LocalDeviceStorageProvider sharedInstance] deleteOfflineCachedSafe:safe
                                                                  completion:^(NSError *error) {
                                                                      NSLog(@"Delete Offline Cache File. Error = %@", error);
                                                                  }];
    }
    
    if(safe.useQuickTypeAutoFill) {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }
         
    [[SafesList sharedInstance] remove:safe.uuid];

    [self reloadSafes];
}

//////////////////////////////////////////////////////////////////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
        
        vc.currentGroup = vc.viewModel.database.rootGroup;
    }
    else if ([segue.identifier isEqualToString:@"segueToStorageType"])
    {
        SelectStorageProviderController *vc = segue.destinationViewController;
        
        NSString *newOrExisting = (NSString *)sender;
        vc.existing = [newOrExisting isEqualToString:@"Existing"];
    }
    else if ([segue.identifier isEqualToString:@"segueToVersionConflictResolution"]) {
        VersionConflictController* vc = (VersionConflictController*)segue.destinationViewController;
        vc.url = (NSString*)sender;
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Add / Import

- (IBAction)onAddSafe:(id)sender {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"What would you like to do?"
                                            message:nil
                                      preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *action = [UIAlertAction actionWithTitle:@"Add Existing Database..."
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
                                                       [self onAddExistingSafe];
                                                   }];
    [alertController addAction:action];
    
    // Create New
    
    UIAlertAction *createNewAction = [UIAlertAction actionWithTitle:@"New Database (Advanced)..."
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *a) {
                                                       [self onCreateNewSafe];
                                                   }];
    [alertController addAction:createNewAction];
    
    // Express
    
    if(Settings.sharedInstance.iCloudAvailable && Settings.sharedInstance.iCloudOn) {
        UIAlertAction *quickAndEasyAction = [UIAlertAction actionWithTitle:@"New Database (Express)"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *a) {
                                                                    [self onNewExpressSafe];
                                                                }];
        
        // [quickAndEasyAction setValue:[UIColor greenColor] forKey:@"titleTextColor"];
        //[quickAndEasyAction setValue:[UIImage imageNamed:@"fast-forward-2-32"] forKey:@"image"];
        [alertController addAction:quickAndEasyAction];
    }
    
    // Cancel
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
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
    [self performSegueWithIdentifier:@"segueToSelectNewSafeFormat" sender:self];
}

- (void)onNewExpressSafe {
    AddSafeAlertController* prompt = [[AddSafeAlertController alloc] init];

    [prompt addNew:self
        validation:^BOOL(NSString *name, NSString *password) {
            return [[SafesList sharedInstance] isValidNickName:name] && password.length;
        }
        completion:^(NSString *name, NSString *password, BOOL response) {
            if(response) {
                [AddNewSafeHelper addNewSafeAndPopToRoot:self
                                                    name:name
                                                password:password
                                                provider:AppleICloudProvider.sharedInstance
                                                  format:kKeePass];
                
                [Alerts info:self title:@"New Database Ready!" message:@"Your new database is now ready to use! Just tap on it to get started...\n\nNB: It is VITALLY important that you remember your master password, as without it there is no hope of opening the database.\n\nYou could consider writing this password down and storing offline in a physically secure location."];
            }
    }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    //NSLog(@"didPickDocumentsAtURLs: %@", urls);
    NSURL* url = [urls objectAtIndex:0];
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:self.temporaryExportUrl options:kNilOptions error:&error];
    
    if(!data || error) {
        [Alerts error:self title:@"Error Exporting" error:error];
        NSLog(@"%@", error);
        return;
    }
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithData:data fileUrl:url];
    
    [document saveToURL:url forSaveOperation:UIDocumentSaveForCreating | UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
        if(!success) {
            [Alerts warn:self title:@"Error Exporting" message:@""];
        }
        else {
            [Alerts info:self title:@"Export Successful" message:@"Your Database was successfully exported."];
        }
    }];
    
    [document closeWithCompletionHandler:nil];
}

- (void)onExportSafe:(NSIndexPath*)indexPath {
    SafeMetaData* safe = self.collection[indexPath.row];
    
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:safe.storageProvider];
    [provider read:safe viewController:self completion:^(NSData *data, NSError *error) {
        if(!data || error) {
            [Alerts error:self title:@"Error Reading Database" error:error];
        }
        else {
            self.temporaryExportUrl = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:safe.fileName];
            
            NSError* error;
            [data writeToURL:self.temporaryExportUrl options:kNilOptions error:&error];
            if(error) {
                [Alerts error:self title:@"Error Writing Database" error:error];
                NSLog(@"error: %@", error);
                return;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithURL:self.temporaryExportUrl inMode:UIDocumentPickerModeExportToService];
                vc.delegate = self;
                
                [self presentViewController:vc animated:YES completion:nil];
            });
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)segueToNagScreenIfAppropriate {
    if(Settings.sharedInstance.isProOrFreeTrial) {
        return;
    }
    
    NSInteger random = arc4random_uniform(100);
    
    //NSLog(@"Random: %ld", (long)random);
    
    if(random < 15) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
        });
    }
}

- (IBAction)onUpgrade:(id)sender {
    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
}

- (IBAction)onTogglePro:(id)sender {
    BOOL isPro = [[Settings sharedInstance] isPro];
    
    [[Settings sharedInstance] setPro:!isPro];

    [self bindProOrFreeTrialUi];
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
    
    //[self.buttonTogglePro setTitle:(![[Settings sharedInstance] isProOrFreeTrial] ? @"Go Pro" : @"Go Free")];
    //[self.buttonTogglePro setEnabled:NO];
    //[self.buttonTogglePro setTintColor: [UIColor clearColor]];
    //[self.buttonTogglePro setEnabled:YES];
    //[self.buttonTogglePro setTintColor:nil];
    [self removeToolbarButton:self.buttonTogglePro];
    
    if([[Settings sharedInstance] isProOrFreeTrial]) {
        [self.navItemHeader setTitle:@"Databases"];
    }
    else {
        [self.navItemHeader setTitle:@"Databases [Lite Version]"];
    }
    
    if(![[Settings sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
    
        NSString *upgradeButtonTitle;
        if([[Settings sharedInstance] isFreeTrial]) {
            NSInteger daysLeft = [[Settings sharedInstance] getFreeTrialDaysRemaining];
            
            upgradeButtonTitle = [NSString stringWithFormat:@"Upgrade Info - (%ld Pro days left)",
                                  (long)daysLeft];
            
            if(daysLeft < 10) {
                [self.buttonUpgrade setTintColor: [UIColor redColor]];
            }
        }
        else {
            upgradeButtonTitle = [NSString stringWithFormat:@"Please Upgrade..."];
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

- (IBAction)onSwitchToQuickLaunchView:(id)sender {
    Settings.sharedInstance.useQuickLaunchAsRootView = YES;
    
    InitialViewController * ivc = [self getInitialViewController];
    
    [ivc showQuickLaunchView];
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
                          allowDevicePinInstead:NO 
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
    PinEntryController *vc = [[PinEntryController alloc] init];
    
    __weak PinEntryController* weakVc = vc;
    
    vc.pinLength = Settings.sharedInstance.appLockPin.length;
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if(response == kOk) {
            if([pin isEqualToString:Settings.sharedInstance.appLockPin]) {
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
            
                [self performSegueWithIdentifier:@"segueFromSafesToPreferences" sender:nil];
                [self dismissViewControllerAnimated:YES completion:nil];
            }
            else {
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeError];
                
                [Alerts info:weakVc title:@"PIN Incorrect" message:@"That is not the correct PIN code." completion:^{
                    [self dismissViewControllerAnimated:YES completion:nil];
                }];
            }
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    };
    
    vc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    [self presentViewController:vc animated:YES completion:nil];
}

@end
