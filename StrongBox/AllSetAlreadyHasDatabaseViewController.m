//
//  AllSetAlreadyHasDatabaseViewController.m
//  Strongbox
//
//  Created by Strongbox on 19/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AllSetAlreadyHasDatabaseViewController.h"

@interface AllSetAlreadyHasDatabaseViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonGo;

@end

@implementation AllSetAlreadyHasDatabaseViewController

- (BOOL)shouldAutorotate {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
        return YES; /* Device is iPad */
    }
    else {
        return NO;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
        return UIInterfaceOrientationMaskAll; /* Device is iPad */
    }
    else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    
    [self.navigationItem setPrompt:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.buttonGo.layer.cornerRadius = 5.0f;
}

- (IBAction)onGo:(id)sender {
    self.onDone(NO, nil);
}

@end
