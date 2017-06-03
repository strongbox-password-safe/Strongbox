//
//  DropBoxSafeTableViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 01/08/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DropboxSDK/DropboxSDK.h>
#import "SafeStorageProvider.h"
#import "SafesCollection.h"

@interface DropboxSafeTableViewController : UITableViewController

@property (nonatomic) SafesCollection *safes;
@property (nonatomic) BOOL existing;
@property (nonatomic) NSString *rootDriveFile;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSelectThisFolder;
- (IBAction)onSelectThisFolder:(id)sender;

@property (nonatomic) id<SafeStorageProvider> safeStorageProvider;

@end
