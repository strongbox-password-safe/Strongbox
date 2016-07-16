//
//  AddGoogleDriveSafeTableViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 04/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

// svn checkout http://google-api-objectivec-client.googlecode.com/svn/trunk/ google-api-objectivec-client-read-only

#import "AddGoogleDriveSafeTableViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDriveConstants.h"
#import "GTLDrive.h"
#import "AddSafeViewController.h"
#import "core-model/SafeTools.h"
#import "SafeMetaData.h"
#import "GTMOAuth2Authentication.h"
#import "GoogleDriveManager.h"
#import "MBProgressHUD.h"
#import "core-model/SafeDatabase.h"

@interface AddGoogleDriveSafeTableViewController ()

@end

@implementation AddGoogleDriveSafeTableViewController
{
    GTLDriveFile* warningLargeFileIdentifier;
    NSMutableArray* _driveFiles;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Get the reference to the current toolbar buttons
    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];
    
    if(self.existing)
    {
        // This is how you remove the button from the toolbar and animate it
        [toolbarButtons removeObject:self.buttonSelectThisFolder];
        [self setToolbarItems:toolbarButtons animated:YES];
    }
    else
    {
        // This is how you add the button to the toolbar and animate it
        if (![toolbarButtons containsObject:self.buttonSelectThisFolder]) {
            // The following line adds the object to the end of the array.
            // If you want to add the button somewhere else, use the `insertObject:atIndex:`
            // method instead of the `addObject` method.
            [toolbarButtons addObject:self.buttonSelectThisFolder];
            [self setToolbarItems:toolbarButtons animated:YES];
        }
    }

    self.navigationItem.title = self.existing ? @"Please Select Safe File" : @"Select Folder For New Safe";
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if(_driveFiles == nil)
    {
        _driveFiles = [[NSMutableArray alloc] init];
    }
    
    [self loadDriveFiles];
}

- (void)loadDriveFiles {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES]; // To do will this work with out a navigation controller
    });
        
    [self.googleDrive getFilesAndFolders:self withParentFolder:(self.rootDriveFile ? self.rootDriveFile.identifier : nil) completionHandler:^(NSArray *folders, NSArray *files, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        });
        
        [_driveFiles removeAllObjects];
        
        if(error == nil)
        {
            NSArray *sorted = [folders sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                GTLDriveFile *f1 = (GTLDriveFile*)obj1;
                GTLDriveFile *f2 = (GTLDriveFile*)obj2;
                
                return [f1.title compare:f2.title options:NSCaseInsensitiveSearch];
            }];
            
            [_driveFiles addObjectsFromArray:sorted];
            
            // This also leaves the files until afer the folders, which I prefer (existing files not shown in new safe situation)
            
            if(self.existing)
            {
                NSArray *sorted = [files sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    GTLDriveFile *f1 = (GTLDriveFile*)obj1;
                    GTLDriveFile *f2 = (GTLDriveFile*)obj2;
                    
                    return [f1.title compare:f2.title options:NSCaseInsensitiveSearch];
                }];
                
                [_driveFiles addObjectsFromArray:sorted];
            }
            
            //NSLog(@"Got %lu results", (unsigned long)[self.driveFiles count]);
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.tableView reloadData];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                NSString* message = [NSString stringWithFormat:@"There was a problem accessing Google Drive. Error: %@", error ];
                
                UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Error accessing Google Drive"
                                                                      message:message
                                                               preferredStyle:UIAlertControllerStyleAlert];
                
                [self presentViewController:alertController animated:YES completion:nil];
                
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [self.tableView reloadData];
                });
            });
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_driveFiles count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GoogleDriveItemCell" forIndexPath:indexPath];
    
    GTLDriveFile *file = [_driveFiles objectAtIndex:indexPath.row];
    cell.textLabel.text = file.title;
    
    if (self.iconsByUrl == nil) {
        self.iconsByUrl = [[NSMutableDictionary alloc] init];
    }
    
    NSString* imageLink = file.iconLink; //file.thumbnailLink == NULL ? file.iconLink : file.thumbnailLink;
    
    if([file.mimeType isEqual:@"application/vnd.google-apps.folder"])
    {
        cell.imageView.image = [UIImage imageNamed:@"folder48"];
    }
    else if([self.iconsByUrl objectForKey:imageLink] == nil)
    {
        //NSLog(@"Caching: %@", imageLink);
        
        [self.googleDrive fetchUrl:self withUrl:imageLink completionHandler:^(NSData *data, NSError *error) {
            if (error == nil && data)
            {
                UIImage* image = [UIImage imageWithData:data];

                if(image)
                {
                    [self.iconsByUrl setObject:image forKey:imageLink];
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void){
                        cell.imageView.image = image;
                        
                        [self.tableView reloadData];
                    });
                }
            }
            else
            {
                NSLog(@"An error occurred downloading icon: %@", error);
            }
        }];
    }
    else
    {
        cell.imageView.image = [self.iconsByUrl objectForKey:imageLink];
    }
    
    cell.accessoryType = [file.mimeType  isEqual: @"application/vnd.google-apps.folder"] ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)readFile:(GTLDriveFile *)file {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES]; // TODO: will this work with out a navigation controller
    });
    
    [self.googleDrive readWithOnlyFileId:self fileIdentifier:file.identifier completionHandler:^(NSData *data, NSError *error)
     {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
        
        if(error == nil)
        {
            if([SafeDatabase isAValidSafe:data])
            {
                [self performSegueWithIdentifier:@"segueSelectedFile" sender:file];
            }
            else
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not a Safe"
                                                                message:@"This is not a valid safe!"
                                                               delegate:self
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        }
        else
        {
            NSLog(@"%@", error);
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Getting Safe"
                                                            message:@"There was a problem accessing the safe file."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            
            [alert show];
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    GTLDriveFile *file = [_driveFiles objectAtIndex:indexPath.row];
    
    if ([file.mimeType isEqual: @"application/vnd.google-apps.folder"])
    {
        [self performSegueWithIdentifier:@"recursiveSegue" sender:nil];
    }
    else
    {
        if(file.fileSize.longValue > MAX_SAFE_SIZE)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Safe is Very Large"
                                                            message:@"Warning: This file may take quite a while to download and open. Are you sure you want to continue?"
                                                           delegate:self
                                                  cancelButtonTitle:@"No"
                                                  otherButtonTitles:@"Yes", nil];
            
            alert.tag = 1;
            warningLargeFileIdentifier = file;
            [alert show];
        }
        else
        {
            [self readFile:file];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 1 && buttonIndex == 1) // Large File Size Warning
    {
        [self readFile:warningLargeFileIdentifier];
        warningLargeFileIdentifier = nil;
    }
}

- (IBAction)onSelectThisFolder:(id)sender
{
     NSString* parentFolder = self.rootDriveFile ? self.rootDriveFile.identifier : @"root";
    
    [self performSegueWithIdentifier:@"segueSelectedFile" sender:parentFolder];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return (sender == self);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"recursiveSegue"])
    {
        NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
        GTLDriveFile *file = [_driveFiles objectAtIndex:ip.row];
        
        AddGoogleDriveSafeTableViewController *vc = [segue destinationViewController];
        vc.safes = self.safes;
        vc.rootDriveFile = file;
        vc.existing = self.existing;
        vc.googleDrive = self.googleDrive;
        vc.safeStorageProvider = self.safeStorageProvider;
    }
    else if([[segue identifier] isEqualToString:@"segueSelectedFile"])
    {
        AddSafeViewController* vc = [segue destinationViewController];
        
        vc.safes = self.safes;
        vc.existing = self.existing;
        vc.fileOrFolderObject = sender;
        vc.safeStorageProvider = self.safeStorageProvider;
    }
}



@end
