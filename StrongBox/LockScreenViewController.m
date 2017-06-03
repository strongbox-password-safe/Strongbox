//
//  LockScreenViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 07/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "LockScreenViewController.h"

@interface LockScreenViewController ()

@end

@implementation LockScreenViewController {
    BOOL _oldNavBarState;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    _oldNavBarState = self.navigationController.navigationBar.hidden;
    self.navigationController.navigationBar.hidden = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    self.navigationController.navigationBar.hidden = _oldNavBarState;

    [super viewDidDisappear:animated];
}

@end
