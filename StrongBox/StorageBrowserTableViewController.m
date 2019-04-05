//
//  StorageBrowserTableViewController.m
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "StorageBrowserTableViewController.h"
#import "AddSafeAlertController.h"
#import "Alerts.h"
#import "DatabaseModel.h"
#import "SafesList.h"
#import "Utils.h"

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
    
    _defaultFolderImage = [UIImage imageNamed:@"folder-48x48"];
    _defaultFileImage = [UIImage imageNamed:@"page_white_text-48x48"];
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

    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.tableFooterView = [UIView new];
    
    self.navigationItem.prompt = self.existing ? @"Please Select Database File" : @"Select Folder For New Database";

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 750 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self.safeStorageProvider list:self.parentFolder
                        viewController:self
                            completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error) {
                                [self onList:userCancelled items:items error:error];
        }];
    });
}

- (void)onList:(BOOL)userCancelled items:(NSArray<StorageBrowserItem *> *)items error:(NSError *)error {
    self.listDone = YES;

    if(userCancelled) {
        NSLog(@"User Cancelled Listing... Returning to Root");
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.navigationController popToRootViewControllerAnimated:YES]; 
        });
        return;
    }
    
    if(items == nil || error) {
        [Alerts error:self title:@"Problem Listing Files & Folders" error:error completion:^{
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self.navigationController popToRootViewControllerAnimated:YES];
            });
        }];
    }
    else {
        NSArray *tmp = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (id object, NSDictionary *bindings)
        {
            return self.existing || ((StorageBrowserItem *)object).folder;
        }]];
        
        _items = [[tmp sortedArrayUsingComparator:^NSComparisonResult(StorageBrowserItem*  _Nonnull obj1, StorageBrowserItem*  _Nonnull obj2) {
            if(obj1.folder && !obj2.folder) {
                return NSOrderedAscending;
            }
            else if(!obj1.folder && obj2.folder) {
                return NSOrderedDescending;
            }
            else {
                return [Utils finderStringCompare:obj1.name string2:obj2.name];
            }
        }] mutableCopy];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.tableView reloadEmptyDataSet];
            [self.tableView reloadData];
        });
    }
}

#pragma mark - Table view data source

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text =  self.listDone ? @"No Files or Folders Found" : @"Loading...";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0f] };
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StorageBrowserItemCell" forIndexPath:indexPath];

    StorageBrowserItem *file = _items[indexPath.row];

    cell.textLabel.text = file.name;

    if (_safeStorageProvider.providesIcons) {
        NSValue *myKey = [NSValue valueWithNonretainedObject:file];

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
    }

    cell.accessoryType = file.folder ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    return cell;
}

- (IBAction)onSelectThisFolder:(id)sender {
    AddSafeAlertController *controller = [[AddSafeAlertController alloc] init];

    [controller addNew:self
            validation:^BOOL (NSString *name, NSString *password) {
        return [[SafesList sharedInstance] isValidNickName:name] && password.length;
    }
            completion:^(NSString *name, NSString *password, BOOL response) {
                if (response) {
                    NSString *nickName = [SafesList sanitizeSafeNickName:name];
                    [self addNewSafeAndPopToRoot:nickName password:password];
                }
            }];
}

- (void)validateAndAddExistingSafe:(StorageBrowserItem *)file indexPath:(NSIndexPath *)indexPath  {
    if(self.safeStorageProvider.storageId == kLocalDevice) {
        NSArray<SafeMetaData*> * localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
        NSMutableSet *existing = [NSMutableSet set];
        for (SafeMetaData* safe in localSafes) {
            [existing addObject:safe.fileName];
        }
        
        if([existing containsObject:file.name]) {
            [Alerts warn:self title:@"Database Already Present" message:@"This file is already in your existing set of databases. No need to add it again, it will automatically pick up any updates made via iTunes File Sharing etc."];
            
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            return;
        }
    }
    
    [self.safeStorageProvider readWithProviderData:file.providerData
                                    viewController:self
                                        completion:^(NSData *data, NSError *error) {
                                            [self  readForValidationDone:file
                                            data:data
                                            error:error];
                                        }];
}

- (void)readForValidationDone:(StorageBrowserItem *)file data:(NSData *)data error:(NSError *)error {
    if (error == nil) {
        NSError* err;
        if ([DatabaseModel isAValidSafe:data error:&err]) {
            AddSafeAlertController *controller = [[AddSafeAlertController alloc] init];

            [controller addExisting:self
                         validation:^BOOL (NSString *name) {
                return [[SafesList sharedInstance] isValidNickName:name];
            }
                         completion:^(NSString *name, BOOL response) {
                             if (response) {
                             NSString *nickName = [SafesList sanitizeSafeNickName:name];

                             [self addExistingSafeAndPopToRoot:file
                                                 name:nickName];
                             }
                         }];
        }
        else {
            [Alerts error:self
                    title:@"Invalid Database File"
                    error:err];
        }
    }
    else {
        NSLog(@"%@", error);

        [Alerts error:self title:@"Error Reading Database File" error:error];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    StorageBrowserItem *file = _items[indexPath.row];

    if (file.folder) {
        if(self.safeStorageProvider.rootFolderOnly) {
            [Alerts info:self title:@"Root Folder Only" message:@"You can only have databases in the Root folder for this storage type."];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        else {
            [self performSegueWithIdentifier:@"recursiveSegue" sender:nil];
        }
    }
    else {
        [self validateAndAddExistingSafe:file indexPath:indexPath];
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return (sender == self);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"recursiveSegue"]) {
        NSIndexPath *ip = (self.tableView).indexPathForSelectedRow;
        StorageBrowserItem *file = _items[ip.row];

        StorageBrowserTableViewController *vc = segue.destinationViewController;
    
        vc.parentFolder = file.providerData;
        vc.existing = self.existing;
        vc.format = self.format;
        vc.safeStorageProvider = self.safeStorageProvider;
    }
}

- (void)addExistingSafeAndPopToRoot:(StorageBrowserItem *)item name:(NSString *)name {
    SafeMetaData *safe = [self.safeStorageProvider getSafeMetaData:name providerData:item.providerData];

    [[SafesList sharedInstance] add:safe];

    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)addNewSafeAndPopToRoot:(NSString *)name password:(NSString *)password {
    NSLog(@"Create New Database with Format: %d", self.format);
    
    DatabaseModel *newSafe = [[DatabaseModel alloc] initNewWithPassword:password keyFileDigest:nil format:self.format];
 
    NSError *error;
    NSData *data = [newSafe getAsData:&error];

    if (data == nil) {
        [Alerts error:self
                title:@"Error Saving Database"
                error:error];

        return;
    }

    // The Saving must be done on the main GUI thread!

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self saveNewSafe:name data:data safe:newSafe];
    });
}

- (void)saveNewSafe:(NSString *)nickName data:(NSData *)data safe:(DatabaseModel*)safe {
    [self.safeStorageProvider create:nickName
                           extension:safe.fileExtension
                                data:data
                        parentFolder:self.parentFolder
                      viewController:self
                          completion:^(SafeMetaData *metadata, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                [[SafesList sharedInstance] add:metadata];
            }
            else {
                NSLog(@"An error occurred: %@", error);

                [Alerts error:self
                        title:@"Error Saving Database"
                        error:error];
            }

            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }];
}

@end
