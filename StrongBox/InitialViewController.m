//
//  InitialViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 06/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "InitialViewController.h"
#import "Alerts.h"
#import "DatabaseModel.h"
#import "SafesList.h"
#import "Settings.h"
#import "SafeStorageProvider.h"
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesViewController.h"

@interface InitialViewController ()

@end

@implementation InitialViewController

- (void)showQuickLaunchView {
    self.selectedIndex = 1;
}

- (void)showSafesListView {
    self.selectedIndex = 0;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tabBar.hidden = YES;
    self.selectedIndex = Settings.sharedInstance.useQuickLaunchAsRootView ? 1 : 0;
}

- (void)importFromUrlOrEmailAttachment:(NSURL *)importURL {
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    
    if (![DatabaseModel isAValidSafe:importedData]) {
        [Alerts warn:self
               title:@"Invalid Safe"
             message:@"This is not a valid Strongbox password safe database file."];
        
        return;
    }
    
    [self promptForImportedSafeNickName:importedData];
}

- (void)promptForImportedSafeNickName:(NSData *)data {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Nickname"
                            title:@"You are about to import a safe. What nickname would you like to use for it?"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSString *nickName = [SafesList sanitizeSafeNickName:text];
                               
                               if (![[SafesList sharedInstance] isValidNickName:nickName]) {
                                   [Alerts   info:self
                                            title:@"Invalid Nickname"
                                          message:@"That nickname may already exist, or is invalid, please try a different nickname."
                                       completion:^{
                                           [self promptForImportedSafeNickName:data];
                                       }];
                               }
                               else {
                                   [self addImportedSafe:nickName data:data];
                               }
                           }
                       }];
}


- (void)addImportedSafe:(NSString *)nickName data:(NSData *)data {
    id<SafeStorageProvider> provider;
    
    if(Settings.sharedInstance.iCloudOn) {
        provider = AppleICloudProvider.sharedInstance;
    }
    else {
        provider = LocalDeviceStorageProvider.sharedInstance;
    }
    
    [provider create:nickName
                data:data
        parentFolder:nil
      viewController:self
          completion:^(SafeMetaData *metadata, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^(void)
                        {
                            if (error == nil) {
                                [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
                                if(self.selectedIndex == 0) {
                                    UINavigationController* navController = self.selectedViewController;
                                    SafesViewController* safesList = (SafesViewController*)navController.viewControllers[0];
                                    [safesList reloadSafes];
                                }
                            }
                            else {
                                [Alerts error:self title:@"Error Importing Safe" error:error];
                            }
                        });
     }];
}

@end
