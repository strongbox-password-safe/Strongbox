//
//  MasterDetailViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 04/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MasterDetailViewController.h"

@interface MasterDetailViewController () <UISplitViewControllerDelegate>

@end

@implementation MasterDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    return YES;
}

- (void)onClose {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
