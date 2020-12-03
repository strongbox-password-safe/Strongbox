//
//  DatabaseOnboardingTabViewController.m
//  MacBox
//
//  Created by Strongbox on 21/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseOnboardingTabViewController.h"
#import "OnboardingAutoFillViewController.h"
#import "OnboardingConvenienceViewController.h"
#import "OnboardingWelcomeViewController.h"

@interface DatabaseOnboardingTabViewController ()

@end

@implementation DatabaseOnboardingTabViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    NSLog(@"self.autoFill = %d, self.convenienceUnlock = %d", self.autoFill, self.convenienceUnlock);
    
    if (self.autoFill && self.convenienceUnlock) {
        [self setSelectedTabViewItemIndex:0];
    }
    else if (self.convenienceUnlock) {
        [self setSelectedTabViewItemIndex:1];
    }
    else {
        [self setSelectedTabViewItemIndex:2];
    }
    
    NSTabViewItem* tab1 = self.tabViewItems[0];
    OnboardingWelcomeViewController* welcomeVc = (OnboardingWelcomeViewController*)tab1.viewController;
    NSTabViewItem* tab2 = self.tabViewItems[1];
    OnboardingConvenienceViewController* convenienceVc = (OnboardingConvenienceViewController*)tab2.viewController;
    NSTabViewItem* tab3 = self.tabViewItems[2];
    OnboardingAutoFillViewController* autoFillVc = (OnboardingAutoFillViewController*)tab3.viewController;
        
    __weak DatabaseOnboardingTabViewController* weakSelf = self;
    welcomeVc.database = self.database;
    welcomeVc.onNext = ^{
        [weakSelf setSelectedTabViewItemIndex:1];
    };
    
    convenienceVc.database = self.database;
    convenienceVc.autoFillIsAvailable = self.autoFill;
    convenienceVc.ckfs = self.ckfs;
    convenienceVc.onNext = ^{
        [weakSelf setSelectedTabViewItemIndex:2];
    };
    
    autoFillVc.database = self.database;
    autoFillVc.model = self.model;
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

@end
