//
//  StorageBrowserTableViewController.m
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StorageBrowserTableViewController.h"
#import "Alerts.h"
#import "DatabaseModel.h"
#import "Utils.h"
#import "NodeIconHelper.h"
#import "UITableView+EmptyDataSet.h"
#import "Serializator.h"
#import "DatabaseCell.h"
#import "SVProgressHUD.h"
#import "NSArray+Extensions.h"

@interface StorageBrowserTableViewController ()

@property BOOL listDone;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSelectThis;
@property NSArray<StorageBrowserItem*> *likelyDatabases;
@property NSArray<StorageBrowserItem*> *items;

@end

@implementation StorageBrowserTableViewController {
    
    UIImage *_defaultFolderImage;
    UIImage *_defaultFileImage;

    NSMutableDictionary<NSValue *, UIImage *> *_iconsCache;
}

+ (instancetype)instantiateFromStoryboard {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectStorage" bundle:nil];
    StorageBrowserTableViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"StorageBrowser"];
    return vc;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationItem setPrompt:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _defaultFolderImage = [UIImage systemImageNamed:@"folder"];
    _defaultFileImage = [UIImage systemImageNamed:@"doc"];
    
    _iconsCache = [[NSMutableDictionary alloc] init];

    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];

    if ( self.existing || self.canNotCreateInThisFolder ) {
        [self.buttonSelectThis setTitle:NSLocalizedString(@"generic_dismiss", @"generic_dismiss")];
    }
    else if(![toolbarButtons containsObject:self.buttonSelectThis]) {
        [toolbarButtons addObject:self.buttonSelectThis];
        [self setToolbarItems:toolbarButtons animated:YES];
    }

    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
        
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.bounds.size.width, 0.01f)];
    
    self.tableView.sectionHeaderTopPadding = CGFLOAT_MIN;

    self.navigationItem.prompt = self.existing ?
        NSLocalizedString(@"sbtvc_select_database_file", @"Please Select Database File") :
        NSLocalizedString(@"sbtvc_select_new_database_location", @"Select Folder For New Database");

    self.navigationItem.title = NSLocalizedString(@"storage_browser", @"Storage Browser");
    
    [self loadListing];
}

- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text =  self.listDone ?
    NSLocalizedString(@"sbtvc_empty_table_no_files_found", @"No Files or Folders Found") :
    NSLocalizedString(@"generic_loading", @"Loading...");
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0f] };
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (void)loadListing {
    

    BOOL dropboxDelayHack = NO;
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    dropboxDelayHack = (self.safeStorageProvider.storageId == kDropbox && self.parentFolder == nil);
#endif
    
    if ( dropboxDelayHack ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 750 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [self.safeStorageProvider list:self.parentFolder
                            viewController:self
                                completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error) {
                                    [self onList:userCancelled items:items error:error];
                                }];
        });
    }
    else {
        [self.safeStorageProvider list:self.parentFolder
                        viewController:self
                            completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error) {
                                [self onList:userCancelled items:items error:error];
                            }];
    }
}

- (void)onList:(BOOL)userCancelled items:(NSArray<StorageBrowserItem *> *)items error:(NSError *)error {
    self.listDone = YES;

    if(userCancelled) {

        self.onDone([SelectedStorageParameters userCancelled]);
        return;
    }
    
    if ( items == nil || error ) {
        self.onDone([SelectedStorageParameters error:error withProvider:self.safeStorageProvider]); 
    }
    else {
        self.items = [[items sortedArrayUsingComparator:^NSComparisonResult(StorageBrowserItem*  _Nonnull obj1, StorageBrowserItem*  _Nonnull obj2) {
            if(obj1.folder && !obj2.folder) {
                return NSOrderedAscending;
            }
            else if(!obj1.folder && obj2.folder) {
                return NSOrderedDescending;
            }
            else {
                return finderStringCompare(obj1.name, obj2.name);
            }
        }] mutableCopy];
        
        self.likelyDatabases = self.existing ? [self filterLikelyDatabases] : @[];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.tableView reloadData];
        });
    }
}

- (NSArray<StorageBrowserItem *> *)filterLikelyDatabases {
    NSSet<NSString*>* likelyDatabases = [NSSet setWithArray:@[
        @"kdbx",
        @"kdb",
        @"psafe3",
    ]];
    
    return [self.items filter:^BOOL(StorageBrowserItem * _Nonnull obj) {
        return !obj.folder && [likelyDatabases containsObject:obj.name.pathExtension.lowercaseString];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( section == 0 ) {
        return self.likelyDatabases.count;
    }
    else {
        [self.tableView setEmptyTitle:(_items.count == 0) ? [self getTitleForEmptyDataSet] : nil];
        
        return _items.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StorageBrowserItem *file;
    
    if ( indexPath.section == 0 ) {
        file = self.likelyDatabases[indexPath.row];
    }
    else {
        file = _items[indexPath.row];
    }
    
    UIImage* img;
    UIColor* tintColor;
    
    if (_safeStorageProvider.providesIcons) {
        NSValue *myKey = [NSValue valueWithNonretainedObject:file];
        
        tintColor = nil;
        img = _defaultFileImage;
        
        if (!_iconsCache[myKey]) {
            [_safeStorageProvider loadIcon:file.providerData
                            viewController:self
                                completion:^(UIImage *image) {
                                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                                        self->_iconsCache[myKey] = image;
                                        [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                              withRowAnimation:UITableViewRowAnimationNone];
                                        });
                                }];
        }
        else {
            img = _iconsCache[myKey];
        }
    }
    else {
        img = file.folder ? _defaultFolderImage : _defaultFileImage;
        tintColor = nil;
    }


        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StorageBrowserItemCell" forIndexPath:indexPath];
        cell.textLabel.text = file.name;
        cell.imageView.image = img;
        
    BOOL enabled = (self.existing || file.folder) && !file.disabled;
    
        cell.userInteractionEnabled = enabled;
        cell.textLabel.enabled = enabled;
        cell.imageView.tintColor = tintColor;
        
        cell.accessoryType = file.folder ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

        return cell;













}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    StorageBrowserItem *file;
    if ( indexPath.section == 0 ) {
        file = self.likelyDatabases[indexPath.row];
    }
    else {
        file = self.items[indexPath.row];
    }
    
    if (file.folder) {
        if ( self.safeStorageProvider.rootFolderOnly ) {
            [Alerts info:self
                   title:NSLocalizedString(@"sbtvc_root_folder_only_title", @"Root Folder Only")
                 message:NSLocalizedString(@"sbtvc_root_folder_only_message", @"You can only have databases in the Root folder for this storage type.")];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        else {
            [self performSegueWithIdentifier:@"recursiveSegue" sender:nil];
        }
    }
    else {
        [self validateSelectedDatabase:file];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ( section == 0 ) {
        return self.likelyDatabases.count > 0 ? NSLocalizedString(@"generic_databases_plural", @"Databases") : nil;
    }
    else {
        return self.items.count > 0 ? NSLocalizedString(@"generic_all_items", @"All Items") : nil;
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ( section == 0 ) {
        return self.likelyDatabases.count > 0 ? NSLocalizedString(@"storage_browser_strongbox_found_likely_databases", @"Strongbox has found these items in this folder that are likely to be databases.") : nil;
    }

    return [super tableView:tableView titleForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ( section == 0 && self.likelyDatabases.count == 0 ) {
        return CGFLOAT_MIN;
    }
    
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if ( section == 0 && self.likelyDatabases.count == 0 ) {
        return CGFLOAT_MIN;
    }
    
    return UITableViewAutomaticDimension;
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    
    
    return (sender == self);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"recursiveSegue"]) {
        NSIndexPath *ip = (self.tableView).indexPathForSelectedRow;
        StorageBrowserItem *file = _items[ip.row];
        
        StorageBrowserTableViewController *vc = segue.destinationViewController;
        
        vc.parentFolder = file.providerData;
        vc.existing = self.existing;
        vc.canNotCreateInThisFolder = file.canNotCreateDatabaseInThisFolder;
        vc.safeStorageProvider = self.safeStorageProvider;
        vc.onDone = self.onDone;
    }
}

- (void)validateSelectedDatabase:(StorageBrowserItem *)file  {
    StorageProviderReadOptions *options = [[StorageProviderReadOptions alloc] init];

    [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"Reading...")];
    
    [self.safeStorageProvider readWithProviderData:file.providerData
                                    viewController:self
                                           options:options
                                        completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
        
        [self  readForValidationDone:result file:file data:data initialDateModified:dateModified error:error];
    }];
}

- (void)readForValidationDone:(StorageProviderReadResult)result
                         file:(StorageBrowserItem *)file
                         data:(NSData *)data
          initialDateModified:(NSDate*)initialDateModified
                        error:(const NSError *)error {
    if (result == kReadResultSuccess) {
        NSError* err;
        if ([Serializator isValidDatabaseWithPrefix:data error:&err]) {  
            DatabaseFormat likelyFormat = [Serializator getDatabaseFormatWithPrefix:data];
            self.onDone([SelectedStorageParameters parametersForNativeProviderExisting:self.safeStorageProvider
                                                                                  file:file
                                                                          likelyFormat:likelyFormat
                                                                                  data:data
                                                                   initialDateModified:initialDateModified]);
        }
        else {
            [Alerts error:self
                    title:NSLocalizedString(@"sbtvc_invalid_database_file", @"Invalid Database File")
                    error:err];
        }
    }
    else {
        slog(@"%@", error);
        [Alerts error:self
                title:NSLocalizedString(@"sbtvc_error_reading_database", @"Error Reading Database File")
                error:error];
    }
}

- (IBAction)onSelectThisFolder:(id)sender {
    if ( self.existing || self.canNotCreateInThisFolder ) {
        self.onDone([SelectedStorageParameters userCancelled]);
    }
    else {
        self.onDone([SelectedStorageParameters parametersForNativeProviderCreate:self.safeStorageProvider folder:self.parentFolder]);
    }
}

@end
