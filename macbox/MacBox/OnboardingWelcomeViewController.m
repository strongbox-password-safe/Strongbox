//
//  OnboardingWelcomeViewController.m
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OnboardingWelcomeViewController.h"

@interface OnboardingWelcomeViewController ()

@end

@implementation OnboardingWelcomeViewController

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

- (IBAction)onNext:(id)sender {
    self.onNext();
}

- (IBAction)onLater:(id)sender {
    [self.view.window close];
}

@end
