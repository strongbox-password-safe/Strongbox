//
//  InitialViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "InitialTabViewController.h"
#import "Settings.h"
#import "SafesList.h"
#import "StorageProvider.h"
#import "NSArray+Extensions.h"

@implementation InitialTabViewController

- (void)showQuickLaunchView {
    self.selectedIndex = 1;
    //self.tabBar.hidden = YES;
}

- (void)showSafesListView {
    self.selectedIndex = 0;
    //self.tabBar.hidden = YES;
}

- (BOOL)isUnsupportedAutoFillProvider:(StorageProvider)storageProvider {
    return storageProvider == kOneDrive ||
    storageProvider == kLocalDevice ||
    storageProvider == kDropbox ||
    storageProvider == kGoogleDrive;
}

- (BOOL)isInQuickLaunchViewMode {
    return self.selectedIndex == 1;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.selectedIndex = Settings.sharedInstance.useQuickLaunchAsRootView ? 1 : 0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSLog(@"View Did Appear! ITC");
    
    //[self.tabBar setHidden:YES];
    
    NSLog(@"self: [%f, %f, %f, %f]", self.view.frame.origin.x, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
    NSLog(@"child: [%f, %f, %f, %f]",
          self.childViewControllers[0].view.frame.origin.x,
          self.childViewControllers[0].view.frame.origin.y,
          self.childViewControllers[0].view.frame.size.width,
          self.childViewControllers[0].view.frame.size.height);
}

- (SafeMetaData*)getPrimarySafe {
    return [SafesList.sharedInstance.snapshot firstObject];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
