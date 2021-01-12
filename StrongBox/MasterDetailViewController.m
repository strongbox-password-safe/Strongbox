//
//  MasterDetailViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 04/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MasterDetailViewController.h"
#import <ISMessages/ISMessages.h>
#import "BrowseSafeView.h"

@interface MasterDetailViewController () <UISplitViewControllerDelegate>

@property BOOL cancelOtpTimer;

@end

@implementation MasterDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.delegate = self;
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    self.cancelOtpTimer = NO;
    [self startOtpRefresh];
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController
collapseSecondaryViewController:(UIViewController *)secondaryViewController
  ontoPrimaryViewController:(UIViewController *)primaryViewController {
    return YES;
}

- (void)onClose {
    NSLog(@"MasterDetailViewController: onClose");
    
    [self killOtpTimer];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kMasterDetailViewCloseNotification object:nil];

    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)killOtpTimer {
    self.cancelOtpTimer = YES;
}

- (void)startOtpRefresh {



    [NSNotificationCenter.defaultCenter postNotificationName:kCentralUpdateOtpUiNotification object:nil];

    if (!self.cancelOtpTimer) {
        __weak MasterDetailViewController* weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf startOtpRefresh];
        });
    }
}

@end
