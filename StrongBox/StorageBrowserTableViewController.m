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
#import "PasswordDatabase.h"

@interface StorageBrowserTableViewController ()

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
    [self.navigationController.toolbar setHidden:self.existing];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.toolbar.hidden = NO;
    
    _defaultFolderImage = [UIImage imageNamed:@"folder48"];
    _defaultFileImage = [UIImage imageNamed:@"page_white48"];
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

    self.navigationItem.prompt = self.existing ? @"Please Select Safe File" : @"Select Folder For New Safe";

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 750 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self.safeStorageProvider list:self.parentFolder
                        viewController:self
                            completion:^(NSArray<StorageBrowserItem *> *items, NSError *error)
        {
            [self onList:items
                   error:error];
        }];
    });
}

- (void)onList:(NSArray<StorageBrowserItem *> *)items error:(NSError *)error {
    if (error) {
        [Alerts error:self title:@"Problem Listing Files & Folders" error:error];
    }
    else {
        NSArray *tmp = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (id object, NSDictionary *bindings)
        {
            return self.existing || ((StorageBrowserItem *)object).folder;
        }]];

        _items = [[NSMutableArray alloc] initWithArray:tmp];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.tableView reloadData];
        });
    }
}

#pragma mark - Table view data source

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
                                    _iconsCache[myKey] = image;

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
        return [[SafesCollection sharedInstance] isValidNickName:name] && password.length;
    }
            completion:^(NSString *name, NSString *password, BOOL response) {
                if (response) {
                NSString *nickName = [SafesCollection sanitizeSafeNickName:name];

                [self addNewSafeAndPopToRoot:nickName
                                password:password];
                }
            }];
}

- (void)validateAndAddExistingSafe:(StorageBrowserItem *)file {
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
        if ([PasswordDatabase isAValidSafe:data]) {
            AddSafeAlertController *controller = [[AddSafeAlertController alloc] init];

            [controller addExisting:self
                         validation:^BOOL (NSString *name) {
                return [[SafesCollection sharedInstance] isValidNickName:name];
            }
                         completion:^(NSString *name, BOOL response) {
                             if (response) {
                             NSString *nickName = [SafesCollection sanitizeSafeNickName:name];

                             [self addExistingSafeAndPopToRoot:file
                                                 name:nickName];
                             }
                         }];
        }
        else {
            [Alerts warn:self
                   title:@"Invalid Safe File"
                 message:@"This is not a valid safe!"];
        }
    }
    else {
        NSLog(@"%@", error);

        [Alerts error:self title:@"Error Reading Safe File" error:error];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    StorageBrowserItem *file = _items[indexPath.row];

    if (file.folder) {
        [self performSegueWithIdentifier:@"recursiveSegue" sender:nil];
    }
    else {
        [self validateAndAddExistingSafe:file];
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
        vc.safeStorageProvider = self.safeStorageProvider;
    }
}

- (void)addExistingSafeAndPopToRoot:(StorageBrowserItem *)item name:(NSString *)name {
    SafeMetaData *safe = [self.safeStorageProvider getSafeMetaData:name providerData:item.providerData];

    [[SafesCollection sharedInstance] add:safe];

    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)addNewSafeAndPopToRoot:(NSString *)name password:(NSString *)password {
    PasswordDatabase *newSafe = [[PasswordDatabase alloc] initNewWithPassword:password];
    [newSafe defaultLastUpdateFieldsToNow];
    
    NSError *error;
    NSData *data = [newSafe getAsData:&error];

    if (data == nil) {
        [Alerts error:self
                title:@"Error Saving Safe"
                error:error];

        return;
    }

    // The Saving must be done on the main GUI thread!

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self saveNewSafe:name data:data];
    });
}

- (void)saveNewSafe:(NSString *)nickName data:(NSData *)data {
    [self.safeStorageProvider create:nickName
                                data:data
                        parentFolder:self.parentFolder
                      viewController:self
                          completion:^(SafeMetaData *metadata, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                [[SafesCollection sharedInstance] add:metadata];
            }
            else {
                NSLog(@"An error occurred: %@", error);

                [Alerts error:self
                        title:@"Error Saving Safe"
                        error:error];
            }

            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }];
}

@end
