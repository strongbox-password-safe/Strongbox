//
//  AddGoogleDriveSafeTableViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 04/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GTLDriveFile.h"
#import "GoogleDriveManager.h"
#import "SafeStorageProvider.h"
#import "SafesCollection.h"

@interface AddGoogleDriveSafeTableViewController : UITableViewController
- (IBAction)onSelectThisFolder:(id)sender;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonSelectThisFolder;
@property (nonatomic) BOOL existing;
@property (nonatomic) SafesCollection *safes;
@property (nonatomic) BOOL isAuthorized;
@property (nonatomic) NSMutableDictionary* iconsByUrl;
@property (nonatomic) GTLDriveFile* rootDriveFile;
@property (nonatomic) GoogleDriveManager *googleDrive;

@property (nonatomic) id<SafeStorageProvider> safeStorageProvider;

@end
