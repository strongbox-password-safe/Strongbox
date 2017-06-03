//
//  SelectSafeLocationViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 21/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SelectSafeLocationViewController.h"
#import "StorageBrowserTableViewController.h"
#import "SafeStorageProvider.h"
#import "AddSafeAlertController.h"
#import "Alerts.h"

@implementation SelectSafeLocationViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.existing) {
        self.uiLabelHelp.text = @"Select where your safe is stored";
    }
    else {
        self.uiLabelHelp.text = @"Select where you would like to store your new safe";
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    (self.buttonGoogleDrive.imageView).contentMode = UIViewContentModeScaleAspectFit;
    (self.buttonDropbox.imageView).contentMode = UIViewContentModeScaleAspectFit;

    self.buttonLocalDevice.hidden = self.existing;
    (self.buttonLocalDevice.imageView).contentMode = UIViewContentModeScaleAspectFit;

    NSString *title = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"On this iPad" : @"On this iPhone";
    [self.buttonLocalDevice setTitle:title forState:UIControlStateNormal];
    [self.buttonLocalDevice setTitle:title forState:UIControlStateHighlighted];


//    self.buttonLocalDevice.center = CGPointMake(self.view.center.x, self.buttonLocalDevice.center.y);
//    self.buttonGoogleDrive.center = CGPointMake(self.view.center.x, self.buttonGoogleDrive.center.y);
//    self.buttonDropbox.center = CGPointMake(self.view.center.x, self.buttonDropbox.center.y);
//    self.uiLabelHelp.center = CGPointMake(self.view.center.x, self.uiLabelHelp.center.y);
}

- (void)segueToBrowserOrAdd:(id<SafeStorageProvider>)provider {
    if (provider.browsable) {
        [self performSegueWithIdentifier:@"SegueToBrowser" sender:provider];
    }
    else {
        AddSafeAlertController *controller = [[AddSafeAlertController alloc] init];

        [controller addNew:self
                validation:^BOOL (NSString *name, NSString *password) {
            return [self.safes isValidNickName:name] && password.length;
        }
                completion:^(NSString *name, NSString *password, BOOL response) {
                    if (response) {
                    NSString *nickName = [self.safes sanitizeSafeNickName:name];

                    [self addNewSafeAndPopToRoot:nickName
                                    password:password
                                    provider:provider];
                    }
                }];
    }
}

- (void)addNewSafeAndPopToRoot:(NSString *)name password:(NSString *)password provider:(id<SafeStorageProvider>)provider {
    SafeDatabase *newSafe = [[SafeDatabase alloc] initNewWithPassword:password];
    NSData *data = [newSafe getAsData];

    if (data == nil) {
        [Alerts warn:self
               title:@"Error Saving Safe"
             message:@"There was a problem saving the safe."];

        return;
    }

    [provider create:name
                data:data
        parentFolder:nil
      viewController:self
          completion:^(SafeMetaData *metadata, NSError *error)
    {
        if (error == nil) {
            [self.safes add:metadata];
        }
        else {
            NSLog(@"An error occurred: %@", error);

            [Alerts error:self
                    title:@"Error Saving Safe"
                    error:error];
        }

        [self.navigationController popToRootViewControllerAnimated:YES];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"SegueToBrowser"]) {
        StorageBrowserTableViewController *vc = segue.destinationViewController;

        vc.safes = self.safes;
        vc.existing = self.existing;
        vc.safeStorageProvider = sender;
        vc.parentFolder = nil;
    }
}

- (IBAction)onDropbox:(id)sender {
    [self segueToBrowserOrAdd:self.dropboxStorageProvider];
}

- (IBAction)onGoogledrive:(id)sender {
    [self segueToBrowserOrAdd:self.googleStorageProvider];
}

- (IBAction)onLocalDevice:(id)sender {
    [Alerts yesNo:self
            title:@"Local Device Safe Caveat"
          message:@"Since a local safe is only stored on this device, any loss of this device will lead to the loss of "
                    "all passwords stored within this safe. You may want to consider using a cloud storage provider, such as the ones "
                    "supported by StrongBox to avoid catastrophic data loss.\n\nWould you still like to proceed with creating "
                    "a local device safe?"
           action:^(BOOL response) {
               if (response) {
                   [self segueToBrowserOrAdd:self.localDeviceStorageProvider];
               }
            }];
}

@end
