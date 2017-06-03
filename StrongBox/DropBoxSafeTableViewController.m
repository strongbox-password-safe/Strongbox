//
//  DropBoxSafeTableViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 01/08/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "DropboxSafeTableViewController.h"
#import "core-model/SafeDatabase.h"
#import "AddSafeViewController.h"
#import "MBProgressHUD.h"

@interface DropboxSafeTableViewController ()  <DBRestClientDelegate>

@end

@implementation DropboxSafeTableViewController {
    NSMutableArray *_driveFiles;
    DBMetadata *_warningLargeFileIdentifier;
    DBRestClient *_restClient;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.title = self.existing ? @"Please Select Safe File" : @"Select Folder For New Safe";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    // Get the reference to the current toolbar buttons
    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];

    if (self.existing) {
        // This is how you remove the button from the toolbar and animate it
        [toolbarButtons removeObject:self.buttonSelectThisFolder];
        [self setToolbarItems:toolbarButtons animated:YES];
    }
    else {
        // This is how you add the button to the toolbar and animate it
        if (![toolbarButtons containsObject:self.buttonSelectThisFolder]) {
            // The following line adds the object to the end of the array.
            // If you want to add the button somewhere else, use the `insertObject:atIndex:`
            // method instead of the `addObject` method.
            [toolbarButtons addObject:self.buttonSelectThisFolder];
            [self setToolbarItems:toolbarButtons animated:YES];
        }
    }

    if (_driveFiles == nil) {
        _driveFiles = [[NSMutableArray alloc] init];
    }

    if (![[DBSession sharedSession] isLinked]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(isDropboxLinkedHandle:) name:@"isDropboxLinked" object:nil];
        [[DBSession sharedSession] linkFromController:self];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        });

        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
        [_restClient loadMetadata:self.rootDriveFile];
    }
}

- (void)isDropboxLinkedHandle:(id)sender {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if ([[DBSession sharedSession] isLinked]) {
        //NSLog(@"DB => Dropbox just linked... refresh");

        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        });

        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
        [_restClient loadMetadata:self.rootDriveFile];
    }
    else {
        NSLog(@"Not Linked");
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata {
    if (metadata.isDirectory) {
        for (DBMetadata *file in metadata.contents) {
            if (self.existing || file.isDirectory) {
                [_driveFiles addObject:file];
            }
        }

        NSArray *sorted = [_driveFiles sortedArrayUsingComparator:^NSComparisonResult (id obj1, id obj2) {
            DBMetadata *f1 = (DBMetadata *)obj1;
            DBMetadata *f2 = (DBMetadata *)obj2;

            if (f1.isDirectory == f2.isDirectory) {
                return [f1.filename compare:f2.filename
                                    options:NSCaseInsensitiveSearch];
            }
            else {
                return f1.isDirectory ? -1 : 1;
            }
        }];

        [_driveFiles removeAllObjects];
        [_driveFiles addObjectsFromArray:sorted];

        [self.tableView reloadData];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });

    NSLog(@"Error loading metadata: %@", error);

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error scanning folder"
                                                    message:@"There was an error scanning this folder. Please retry later."
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _driveFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DropboxItemCell" forIndexPath:indexPath];

    DBMetadata *file = [_driveFiles objectAtIndex:indexPath.row];

    cell.textLabel.text = file.filename;
    //NSLog(@"%@", file.icon);

    UIImage *img = [UIImage imageNamed:[NSString stringWithFormat:@"%@48", file.icon]];

    img = img ? img : [UIImage imageNamed:@"page_white48"];

    cell.imageView.image = img;

    cell.accessoryType = file.isDirectory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    //cell.selectionStyle = file.isDirectory ? YES : self.existing;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DBMetadata *file = [_driveFiles objectAtIndex:indexPath.row];

    if (file.isDirectory) {
        [self performSegueWithIdentifier:@"recursiveSegue" sender:nil];
    }
    else {
        if (file.totalBytes > MAX_SAFE_SIZE) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Safe is Very Large"
                                                            message:@"Warning: This file may take quite a while to download and open. Are you sure you want to continue?"
                                                           delegate:self
                                                  cancelButtonTitle:@"No"
                                                  otherButtonTitles:@"Yes", nil];

            alert.tag = 1;
            _warningLargeFileIdentifier = file;
            [alert show];
        }
        else {
            [self readFile:file];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1 && buttonIndex == 1) { // Large File Size Warning
        [self readFile:_warningLargeFileIdentifier];
        _warningLargeFileIdentifier = nil;
    }
}

- (void)readFile:(DBMetadata *)file {
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"dat"]];

    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    });

    [_restClient loadFile:file.path intoPath:tempFile];
}

- (IBAction)onSelectThisFolder:(id)sender {
    [self performSegueWithIdentifier:@"segueSelectedFile" sender:self.rootDriveFile];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return (sender == self);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"recursiveSegue"]) {
        NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
        DBMetadata *file = [_driveFiles objectAtIndex:ip.row];

        DropboxSafeTableViewController *vc = [segue destinationViewController];
        vc.safes = self.safes;
        vc.rootDriveFile = file.path;
        vc.existing = self.existing;
        vc.safeStorageProvider = self.safeStorageProvider;
    }
    else if ([[segue identifier] isEqualToString:@"segueSelectedFile"])
    {
        AddSafeViewController *vc = [segue destinationViewController];

        vc.safes = self.safes;
        vc.existing = self.existing;
        vc.fileOrFolderObject = sender;
        vc.safeStorageProvider = self.safeStorageProvider;
    }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)localPath
       contentType:(NSString *)contentType metadata:(DBMetadata *)metadata {
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:localPath];

    if ([SafeDatabase isAValidSafe:data]) {
        [self performSegueWithIdentifier:@"segueSelectedFile" sender:metadata];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not a Safe"
                                                        message:@"This is not a valid safe!"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }

    // Delete the temporary file...

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:localPath error:&error];

    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });

    NSLog(@"%@", error);

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Getting Safe"
                                                    message:@"There was a problem accessing the safe file."
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];

    [alert show];
}

@end
