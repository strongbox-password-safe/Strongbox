//
//  SelectSafeLocationViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 21/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SelectSafeLocationViewController.h"
#import "AddGoogleDriveSafeTableViewController.h"
#import "DropboxSafeTableViewController.h"
#import "AddSafeViewController.h"

@interface SelectSafeLocationViewController ()

@end

@implementation SelectSafeLocationViewController

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(self.existing)
    {
        self.uiLabelHelp.text = @"Select where your safe is stored";
    }
    else
    {
        self.uiLabelHelp.text = @"Select where you would like to store your new safe";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    [self.buttonGoogleDrive.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [self.buttonDropbox.imageView setContentMode:UIViewContentModeScaleAspectFit];
    
    self.buttonLocalDevice.hidden = self.existing;
    [self.buttonLocalDevice.imageView setContentMode:UIViewContentModeScaleAspectFit];
    
    NSString *title = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) ? @"On this iPad" : @"On this iPhone";
    [self.buttonLocalDevice setTitle:title forState:UIControlStateNormal];
    [self.buttonLocalDevice setTitle:title forState:UIControlStateHighlighted];
    
    
    self.buttonLocalDevice.center = CGPointMake(self.view.center.x, self.buttonLocalDevice.center.y);
    self.buttonGoogleDrive.center = CGPointMake(self.view.center.x, self.buttonGoogleDrive.center.y);
    self.buttonDropbox.center = CGPointMake(self.view.center.x, self.buttonDropbox.center.y);
    self.uiLabelHelp.center = CGPointMake(self.view.center.x, self.uiLabelHelp.center.y);
}

// In a storyboard-based application, you will often want to do a litt   le preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"SegueToGoogleDrive"])
    {
        AddGoogleDriveSafeTableViewController *vc = [segue destinationViewController];
        vc.safes = self.safes;
        vc.existing = self.existing;
        vc.googleDrive = self.googleStorageProvider.googleDrive;
        vc.safeStorageProvider = self.googleStorageProvider;
    }
    else if ([[segue identifier] isEqualToString:@"SegueToDropbox"])
    {
        DropboxSafeTableViewController *vc = [segue destinationViewController];
        vc.safes = self.safes;
        vc.existing = self.existing;
        vc.rootDriveFile = @"/";
        vc.safeStorageProvider = self.dropboxStorageProvider;
    }
    else if([[segue identifier] isEqualToString:@"segueLocalDeviceToAddSafe"])
    {
        AddSafeViewController* vc = [segue destinationViewController];
        
        vc.safes = self.safes;
        vc.existing = NO;
        vc.fileOrFolderObject = nil;
        vc.safeStorageProvider = self.localDeviceStorageProvider;
    }
}

- (IBAction)onDropbox:(id)sender
{   
    [self performSegueWithIdentifier:@"SegueToDropbox" sender:nil];
}

- (IBAction)onGoogledrive:(id)sender
{
}

- (IBAction)onLocalDevice:(id)sender
{
}

@end
