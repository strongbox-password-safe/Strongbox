//
//  SafesViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesViewController.h"
#import "BrowseSafeView.h"
#import "Utils.h"
#import "SafesList.h"
#import "Alerts.h"
#import "ISMessages/ISMessages.h"
#import "UpgradeViewController.h"
#import "Settings.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "SelectStorageProviderController.h"
#import <PopupDialog/PopupDialog-Swift.h>
#import "Strongbox.h"
#import "SafeItemTableCell.h"
#import "VersionConflictController.h"
#import "InitialViewController.h"

#import "iCloudSafesCoordinator.h"
#import "AppleICloudProvider.h"

@interface SafesViewController ()

@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSArray<SKProduct *> *validProducts;
@property (nonatomic, copy) NSArray<SafeMetaData*> *collection;

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
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self refreshView];
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self checkICloudAvailability];
    
    [self refreshView];
    
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
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if(!Settings.sharedInstance.doNotAutoAddNewLocalSafes) {
        [LocalDeviceStorageProvider.sharedInstance stopMonitoringDocumentsDirectory];
    }
}

- (void)didBecomeActive:(NSNotification *)notification {
    [self checkICloudAvailability];
}

- (void)reloadSafes {
    self.collection = SafesList.sharedInstance.snapshot;

    [self.tableView reloadData];
}

- (void)refreshView {
    self.collection = SafesList.sharedInstance.snapshot;

    [self.tableView reloadData];
    
    self.buttonToggleEdit.enabled = self.collection.count > 0;
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
    [self.navigationItem setPrompt:nil];
    
    [self bindProOrFreeTrialUi];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.collection = [NSArray array];

    [self customizeUi];
    
    [iCloudSafesCoordinator sharedInstance].onSafesCollectionUpdated = ^{
        [self onSafesListUpdated];
    };
    
    if(![[Settings sharedInstance] isPro]) {
        [self getValidIapProducts];
        
        if([[Settings sharedInstance] getEndFreeTrialDate] == nil) {
            NSCalendar *cal = [NSCalendar currentCalendar];
            NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:2 toDate:[NSDate date] options:0];
            [[Settings sharedInstance] setEndFreeTrialDate:date];
        }
        
        if([Settings.sharedInstance getLaunchCount] == 1) {
            [Alerts info:self title:@"Welcome!"
                 message:@"Hi, Welcome to Strongbox Pro!\n\nI hope you will enjoy the app!\n-Mark" completion:^{
                     [self checkICloudAvailability];
                 }];
        }
        else if([Settings.sharedInstance getLaunchCount] > 5 || Settings.sharedInstance.daysInstalled > 6) {
            if(![[Settings sharedInstance] isHavePromptedAboutFreeTrial]) {
                [Alerts info:self title:@"Strongbox Pro"
                     message:@"Hi there!\nYou are currently using Strongbox Pro. You can evaluate this version over the next two months. I hope you like it.\n\nAfter this I would ask you to contribute to its development. If you choose not to support the app, you will then be transitioned to a little bit more limited version. You won't lose any of your safes or passwords.\n\nTo find out more you can tap the Upgrade button at anytime below. I hope you enjoy the app, and will choose to support it!\n-Mark" completion:^{
                         [self checkICloudAvailability];
                     }];
                
                [[Settings sharedInstance] setHavePromptedAboutFreeTrial:YES];
            }
            else {
                [self showStartupMessaging];
            }
        }
    }
    else {
        [self showStartupMessaging];
    }
    
    // User may have just switched to our app after updating iCloud settings...
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)onSafesListUpdated {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self refreshView];
    });
}

- (BOOL)hasSafesOtherThanLocalAndiCloud {
    return SafesList.sharedInstance.snapshot.count - ([self getICloudSafes].count + [self getLocalDeviceSafes].count) > 0;
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
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self refreshView];
    });
}

- (void)checkICloudAvailability {
    [[iCloudSafesCoordinator sharedInstance] initializeiCloudAccessWithCompletion:^(BOOL available) {
        Settings.sharedInstance.iCloudAvailable = available;
        
        if (!Settings.sharedInstance.iCloudAvailable) {
            // If iCloud isn't available, set promoted to no (so we can ask them next time it becomes available)
            [Settings sharedInstance].iCloudPrompted = NO;
            
            if ([[Settings sharedInstance] iCloudWasOn] &&  [self getICloudSafes].count) {
                [Alerts warn:self
                       title:@"iCloud no longer available"
                     message:@"Some safes were removed from this device because iCloud has become unavailable, but they remain stored in iCloud."];
                
                [self removeAllICloudSafes];
            }
            
            // No matter what, iCloud isn't available so switch it to off.???
            [Settings sharedInstance].iCloudOn = NO;
            [Settings sharedInstance].iCloudWasOn = NO;
        }
        else {
            // Ask user if want to turn on iCloud if it's available and we haven't asked already and we're not already presenting a view controller
            if (![Settings sharedInstance].iCloudOn && ![Settings sharedInstance].iCloudPrompted && self.presentedViewController == nil) {
                [Settings sharedInstance].iCloudPrompted = YES;
                
                BOOL existingLocalDeviceSafes = [self getLocalDeviceSafes].count > 0;
                BOOL hasOtherCloudSafes = [self hasSafesOtherThanLocalAndiCloud];
                
                NSString *message = existingLocalDeviceSafes ?
                    (hasOtherCloudSafes ? @"You can now use iCloud with Strongbox. Should your current local safes be migrated to iCloud and available on all your devices? (NB: Your existing cloud safes will not be affected)" :
                                          @"You can now use iCloud with Strongbox. Should your current local safes be migrated to iCloud and available on all your devices?") :
                    (hasOtherCloudSafes ? @"Would you like the option to use iCloud with Strongbox? (NB: Your existing cloud safes will not be affected)" : @"You can now use iCloud with Strongbox. Would you like to have your safes available on all your devices?");
                
                [Alerts twoOptions:self
                             title:@"iCloud is Now Available"
                           message:message
                 defaultButtonText:@"Use iCloud"
                  secondButtonText:@"Local Only" action:^(BOOL response) {
                     if(response) {
                         [Settings sharedInstance].iCloudOn = YES;
                     }
                     [self continueICloudAvailableProcedure];
                 }];
            }
            else {
                [self continueICloudAvailableProcedure];
            }
        }
    }];
}

- (void)showiCloudMigrationUi:(BOOL)show {
    if(show) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:@"Migrating..."];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    }
}

- (void)continueICloudAvailableProcedure {
    // If iCloud newly switched on, move local docs to iCloud
    if ([Settings sharedInstance].iCloudOn && ![Settings sharedInstance].iCloudWasOn && [self getLocalDeviceSafes].count) {
        [Alerts twoOptions:self title:@"iCloud Available" message:@"Would you like to migrate your current local device safes to iCloud?"
         defaultButtonText:@"Migrate to iCloud"
          secondButtonText:@"Keep Local" action:^(BOOL response) {
            if(response) {
                [[iCloudSafesCoordinator sharedInstance] migrateLocalToiCloud:^(BOOL show) {
                    [self showiCloudMigrationUi:show];
                }];
            }
        }];
    }

    // If iCloud newly switched off, move iCloud docs to local
    if (![Settings sharedInstance].iCloudOn && [Settings sharedInstance].iCloudWasOn && [self getICloudSafes].count) {
        [Alerts threeOptions:self
                       title:@"iCloud Unavailable"
                     message:@"What would you like to do with the safes currently on this device?"
           defaultButtonText:@"Remove them, Keep on iCloud Only"
            secondButtonText:@"Make Local Copies"
             thirdButtonText:@"Switch iCloud Back On"
                      action:^(int response) {
                        if(response == 2) {           // @"Switch iCloud Back On"
                            [Settings sharedInstance].iCloudOn = YES;
                            [Settings sharedInstance].iCloudWasOn = [Settings sharedInstance].iCloudOn;
                            
                            dispatch_async(dispatch_get_main_queue(), ^(void) {
                                [self refreshView];
                            });
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

    [Settings sharedInstance].iCloudWasOn = [Settings sharedInstance].iCloudOn;
    [[iCloudSafesCoordinator sharedInstance] startQuery];
}

- (void)customizeUi {
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"No Safes Here Yet";
    
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
        [self refreshView];
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
    
    id<SafeStorageProvider> provider = [[self getInitialViewController] getStorageProviderFromProviderId:safe.storageProvider];
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
    
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    if(safe.hasUnresolvedConflicts) {
        [self performSegueWithIdentifier:@"segueToVersionConflictResolution" sender:safe.fileIdentifier];
    }
    else {
        [[self getInitialViewController] beginOpenSafeSequence:safe completion:^(Model * model) {
            [self performSegueWithIdentifier:@"segueToOpenSafeView" sender:model];
        }];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Remove" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeSafe:indexPath];
    }];

    UITableViewRowAction *renameAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Rename" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self renameSafe:indexPath];
    }];

    return @[removeAction, renameAction];
}

- (void)renameSafe:(NSIndexPath * _Nonnull)indexPath {
    SafeMetaData *safe = [self.collection objectAtIndex:indexPath.row];
    
    [Alerts OkCancelWithTextField:self
                    textFieldText:safe.nickName
                            title:@"Rename Safe"
                          message:@"Please enter a new name for this safe"
                       completion:^(NSString *text, BOOL response) {
        if(response) {
            if([SafesList.sharedInstance isValidNickName:text]) {
                safe.nickName = text;
                [SafesList.sharedInstance update:safe];
                [self refreshView];
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
        message = @"This will remove the safe from all your iCloud enabled devices.\n\n"
                    @"Are you sure you want to remove this safe from Strongbox and iCloud?";
    }
    else {
        message = [NSString stringWithFormat:@"Are you sure you want to remove this safe from Strongbox?%@",
                         (safe.storageProvider == kiCloud || safe.storageProvider == kLocalDevice)  ? @"" : @" (NB: The underlying safe data file will not be deleted)"];
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
                [Alerts error:self title:@"Error Deleting iCloud Safe" error:error];
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
         
    [[SafesList sharedInstance] remove:safe.uuid];

    [self refreshView];
}

//////////////////////////////////////////////////////////////////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToOpenSafeView"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.rootGroup;
    }
    else if ([segue.identifier isEqualToString:@"segueToStorageType"])
    {
        SelectStorageProviderController *vc = segue.destinationViewController;
        
        NSString *newOrExisting = (NSString *)sender;
        vc.existing = [newOrExisting isEqualToString:@"Existing"];
    }
    else if ([segue.identifier isEqualToString:@"segueToUpgrade"]) {
        UpgradeViewController* vc = segue.destinationViewController;
       
        if(self.validProducts.count > 0) {
            vc.product = [self.validProducts objectAtIndex:0];
        }
    }
    else if ([segue.identifier isEqualToString:@"segueToVersionConflictResolution"]) {
        VersionConflictController* vc = (VersionConflictController*)segue.destinationViewController;
        vc.url = (NSString*)sender;
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Add / Import

- (void)initiateManualImportFromUrl {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"URL"
                            title:@"Enter URL"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSURL *url = [NSURL URLWithString:text];
                               NSLog(@"URL: %@", url);
                               
                               InitialViewController * ivc = [self getInitialViewController];
                               [ivc importFromUrlOrEmailAttachment:url];
                           }
                       }];
}

- (IBAction)onAddSafe:(id)sender {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"How Would You Like To Add Your Safe?"
                                            message:nil
                                      preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSString*>* buttonTitles =
        @[  @"Create New Safe",
            @"Add Existing Safe",
            @"Import Safe from URL",
            @"Import Email Attachment"];
    
    int index = 1;
    for (NSString *title in buttonTitles) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
                                                            [self onAddSafeActionSheetResponse:index];
                                                       }];
        [alertController addAction:action];
        index++;
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             [self onAddSafeActionSheetResponse:0];
                                                         }];
    [alertController addAction:cancelAction];
    
    alertController.popoverPresentationController.barButtonItem = self.buttonAddSafe;
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)onAddSafeActionSheetResponse:(int)response {
    if (response == 1) {
        [self performSegueWithIdentifier:@"segueToStorageType" sender:@"New"];
    }
    else if (response == 2) {
        [self performSegueWithIdentifier:@"segueToStorageType" sender:@"Existing"];
    }
    else if (response == 3) {
        [self initiateManualImportFromUrl];
    }
    else if (response == 4) {
        [Alerts info:self
               title:@"Importing Via Email"
             message:  @
         "1) Send an email to yourself with your safe file attached\n"
         "2) Ensure this file has a 'dat' or 'psafe3' extension\n"
         "3) Once the mail has arrived in the Mail app, Tap on the attachment\n"
         "4) You will be given an option to 'Copy to Strongbox'\n"
         "\n"
         "Tapping on this will start the import process."];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)getValidIapProducts {
    NSSet *productIdentifiers = [NSSet setWithObjects:kIapProId, nil];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

-(void)productsRequest:(SKProductsRequest *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    NSUInteger count = [response.products count];
    if (count > 0) {
        self.validProducts = response.products;
//        for (SKProduct *validProduct in self.validProducts) {
//            NSLog(@"%@", validProduct.productIdentifier);
//            NSLog(@"%@", validProduct.localizedTitle);
//            NSLog(@"%@", validProduct.localizedDescription);
//            NSLog(@"%@", validProduct.price);
//        }
        
        [self refreshView];
    }
}

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

-(void)bindProOrFreeTrialUi {
    if(self.navigationController.visibleViewController == self) {
        self.navigationController.toolbar.hidden = [[Settings sharedInstance] isPro];
    }
    
    //[self.buttonTogglePro setTitle:(![[Settings sharedInstance] isProOrFreeTrial] ? @"Go Pro" : @"Go Free")];
    //[self.buttonTogglePro setEnabled:NO];
    //[self.buttonTogglePro setTintColor: [UIColor clearColor]];
    //[self.buttonTogglePro setEnabled:YES];
    //[self.buttonTogglePro setTintColor:nil];
    [self removeToolbarButton:self.buttonTogglePro];
    
    if([[Settings sharedInstance] isProOrFreeTrial]) {
        [self.navItemHeader setTitle:@"Safes"];
    }
    else {
        [self.navItemHeader setTitle:@"Safes [Lite Version]"];
    }
    
    if(![[Settings sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
    
        NSString *upgradeButtonTitle;
        if([[Settings sharedInstance] isFreeTrial]) {
            NSInteger daysLeft = [[Settings sharedInstance] getFreeTrialDaysRemaining];
            
            upgradeButtonTitle = [NSString stringWithFormat:@"Upgrade Info - (%ld Pro days Left)",
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

- (void)openAppStoreForOldReview {
    int appId = 897283731;
    
    static NSString *const iOS7AppStoreURLFormat = @"itms-apps://itunes.apple.com/app/id%d?action=write-review";
    static NSString *const iOSAppStoreURLFormat = @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%d&action=write-review";

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:([[UIDevice currentDevice].systemVersion floatValue] >= 7.0f)? iOS7AppStoreURLFormat: iOSAppStoreURLFormat, appId]];
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
        else {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
    else {
        [Alerts info:self title:@"Cannot open App Store" message:@"Please find Strongbox in the App Store and you can write a review there. Much appreciated! -Mark"];
    }
}

- (void)showStartupMessaging {
    NSUInteger random = arc4random_uniform(2);

    if(random == 0) {
        [self maybeMessageAboutMacApp];
    }
    else {
        [self maybeAskForReview];
    }
}

- (void)maybeAskForReview {
    NSInteger promptedForReview = [[Settings sharedInstance] isUserHasBeenPromptedForReview];
    NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];
    
    if (launchCount > 20) {
        if (@available( iOS 10.3,*)) {
            [SKStoreReviewController requestReview];
        }
        else if(launchCount % 10 == 0 && promptedForReview == 0) {
            [self oldAskForReview];
        }
    }
}

- (void)maybeMessageAboutMacApp {
    NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];
    BOOL neverShow = [Settings sharedInstance].neverShowForMacAppMessage;

    if (launchCount > 20 && (launchCount % 5 == 0) && !neverShow) {
        [self showMacAppMessage];
    }
}

- (void)oldAskForReview {
    [Alerts  threeOptions:self
                    title:@"Review Strongbox?"
                  message:@"Hi, I'm Mark, the developer of Strongbox.\nI would really appreciate it if you could rate this app in the App Store for me.\n\nWould you be so kind?"
        defaultButtonText:@"Sure, take me there!"
         secondButtonText:@"Naah"
          thirdButtonText:@"Like, maybe later!"
                   action:^(int response) {
                       if (response == 0) {
                           [self openAppStoreForOldReview];
                           [[Settings sharedInstance] setUserHasBeenPromptedForReview:1];
                       }
                       else if (response == 1) {
                           [[Settings sharedInstance] setUserHasBeenPromptedForReview:1];
                       }
                   }];
}

- (void) showMacAppMessage {
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Available Now"
                                                    message:@"Strongbox is now available in the Mac App Store. I hope you'll find it just as useful there!\n\nSearch 'Strongbox Password Safe' on the Mac App Store."
                                                      image:[UIImage imageNamed:@"strongbox-for-mac-promo"]
                                            buttonAlignment:UILayoutConstraintAxisVertical
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:340
                                        tapGestureDismissal:YES
                                        panGestureDismissal:YES
                                              hideStatusBar:NO
                                                 completion:nil];

    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Cool!" height:50 dismissOnTap:YES action:nil];

    CancelButton *later = [[CancelButton alloc] initWithTitle:@"Got It! Never Remind Me Again!" height:50 dismissOnTap:YES action:^{
        [[Settings sharedInstance] setNeverShowForMacAppMessage:YES];
    }];

    [popup addButtons: @[ok, later]];

    [self presentViewController:popup animated:YES completion:nil];
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

@end
