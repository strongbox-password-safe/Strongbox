//
//  InitialViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "InitialTabViewController.h"
#import "Settings.h"

@implementation InitialTabViewController

- (void)showQuickLaunchView {
    self.selectedIndex = 1;
    self.tabBar.hidden = YES;
}

- (void)showSafesListView {
    self.selectedIndex = 0;
    self.tabBar.hidden = YES;
}

- (BOOL)isInQuickLaunchViewMode {
    return self.selectedIndex == 1;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tabBar.hidden = YES;
    self.selectedIndex = Settings.sharedInstance.useQuickLaunchAsRootView ? 1 : 0;
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
