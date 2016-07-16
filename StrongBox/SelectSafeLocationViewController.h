//
//  SelectSafeLocationViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 21/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleDriveManager.h"
#import "LocalDeviceStorageProvider.h"
#import "DropboxStorageProvider.h"
#import "GoogleDriveStorageProvider.h"
#import "SafesCollection.h"

@interface SelectSafeLocationViewController : UIViewController

@property (nonatomic) BOOL existing;
@property (weak, nonatomic) IBOutlet UILabel *uiLabelHelp;

- (IBAction)onLocalDevice:(id)sender;
- (IBAction)onDropbox:(id)sender;
- (IBAction)onGoogledrive:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *buttonGoogleDrive;
@property (weak, nonatomic) IBOutlet UIButton *buttonDropbox;
@property (weak, nonatomic) IBOutlet UIButton *buttonLocalDevice;

@property GoogleDriveStorageProvider *googleStorageProvider;
@property DropboxStorageProvider *dropboxStorageProvider;
@property LocalDeviceStorageProvider *localDeviceStorageProvider;

@property (nonatomic) SafesCollection *safes;

@end
