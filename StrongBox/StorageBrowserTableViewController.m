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

@interface StorageBrowserTableViewController ()

@property BOOL listDone;

@end

@implementation StorageBrowserTableViewController {
    NSMutableArray *_items;
    UIImage *_defaultFolderImage;
    UIImage *_defaultFileImage;

    NSMutableDictionary<NSValue *, UIImage *> *_iconsCache;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationItem setPrompt:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = self.existing;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _defaultFolderImage = [UIImage imageNamed:@"folder"];
    _defaultFileImage = [UIImage imageNamed:@"document"];
    _iconsCache = [[NSMutableDictionary alloc] init];

    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];

    if (self.existing) {
        [toolbarButtons removeObject:self.buttonSelectThis];
        [self setToolbarItems:toolbarButtons animated:YES];
    }
    else if(![toolbarButtons containsObject:self.buttonSelectThis]) {
        [toolbarButtons addObject:self.buttonSelectThis];
        [self setToolbarItems:toolbarButtons animated:YES];
    }

    self.tableView.tableFooterView = [UIView new];
    
    self.navigationItem.prompt = self.existing ?
    NSLocalizedString(@"sbtvc_select_database_file", @"Please Select Database File") :
    NSLocalizedString(@"sbtvc_select_new_database_location", @"Select Folder For New Database");

    

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
        NSLog(@"User Cancelled Listing... Returning to Root");
        self.onDone([SelectedStorageParameters userCancelled]);
        return;
    }
    
    if(items == nil || error) {
        self.onDone([SelectedStorageParameters error:error withProvider:self.safeStorageProvider]); 
    }
    else {
        _items = [[items sortedArrayUsingComparator:^NSComparisonResult(StorageBrowserItem*  _Nonnull obj1, StorageBrowserItem*  _Nonnull obj2) {
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
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.tableView reloadData];
        });
    }
}

- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text =  self.listDone ?
    NSLocalizedString(@"sbtvc_empty_table_no_files_found", @"No Files or Folders Found") :
        NSLocalizedString(@"generic_loading", @"Loading...");
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0f] };
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self.tableView setEmptyTitle:(_items.count == 0) ? [self getTitleForEmptyDataSet] : nil];
    
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StorageBrowserItemCell" forIndexPath:indexPath];

    StorageBrowserItem *file = _items[indexPath.row];

    cell.textLabel.text = file.name;
    cell.userInteractionEnabled = self.existing || file.folder;
    cell.textLabel.enabled = self.existing || file.folder;
    
    if (_safeStorageProvider.providesIcons) {
        NSValue *myKey = [NSValue valueWithNonretainedObject:file];
        cell.imageView.tintColor = nil;

        if (!_iconsCache[myKey]) {
            [_safeStorageProvider loadIcon:file.providerData
                            viewController:self
                                completion:^(UIImage *image) {
                                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                                        self->_iconsCache[myKey] = image;

                                        cell.imageView.image = image;
                                        NSArray *rowsToReload = @[indexPath];
                                        [self.tableView reloadRowsAtIndexPaths:rowsToReload
                                              withRowAnimation:UITableViewRowAnimationNone];
                                        });
                                }];
        }
        else {
            cell.imageView.image = _iconsCache[myKey];
        }
    }
    else {
        cell.imageView.image = file.folder ? _defaultFolderImage : _defaultFileImage;
        cell.imageView.tintColor = nil;
    }

    cell.accessoryType = file.folder ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    StorageBrowserItem *file = _items[indexPath.row];
    
    if (file.folder) {
        if(self.safeStorageProvider.rootFolderOnly) {
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
        [self validateSelectedDatabase:file indexPath:indexPath];
    }
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
        vc.safeStorageProvider = self.safeStorageProvider;
        vc.onDone = self.onDone;
    }
}



- (void)validateSelectedDatabase:(StorageBrowserItem *)file indexPath:(NSIndexPath *)indexPath  {
    StorageProviderReadOptions *options = [[StorageProviderReadOptions alloc] init];

    [self.safeStorageProvider readWithProviderData:file.providerData
                                    viewController:self
                                           options:options
                                        completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        [self  readForValidationDone:result file:file data:data initialDateModified:dateModified error:error];
    }];
}

- (void)readForValidationDone:(StorageProviderReadResult)result file:(StorageBrowserItem *)file data:(NSData *)data
          initialDateModified:(NSDate*)initialDateModified error:(const NSError *)error {
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
        NSLog(@"%@", error);
        [Alerts error:self
                title:NSLocalizedString(@"sbtvc_error_reading_database", @"Error Reading Database File")
                error:error];
    }
}

- (IBAction)onSelectThisFolder:(id)sender {
    self.onDone([SelectedStorageParameters parametersForNativeProviderCreate:self.safeStorageProvider folder:self.parentFolder]);
}

@end
