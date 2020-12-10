//
//  OnboardingConvenienceViewController.m
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OnboardingConvenienceViewController.h"
#import "DatabasesManager.h"

@interface OnboardingConvenienceViewController ()

@property (weak) IBOutlet NSButton *enableTouchId;
@property (weak) IBOutlet NSButton *buttonDone;
@property (weak) IBOutlet NSButton *buttonNext;

@end

@implementation OnboardingConvenienceViewController

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.autoFillIsAvailable) {
        self.buttonDone.hidden = YES;
    }
    else {
        self.buttonNext.hidden = YES;
    }
    
    [self bindUI];
}

- (void)bindUI {
    self.enableTouchId.state = self.database.isTouchIdEnabled ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)onPreferencesChanged:(id)sender {
    self.database.isTouchIdEnabled = self.enableTouchId.state == NSControlStateValueOn;
    
    if(self.database.isTouchIdEnabled) {
        self.database.isTouchIdEnrolled = YES;
        [self.database resetConveniencePasswordWithCurrentConfiguration:self.ckfs.password];
    }
    else {
        self.database.isTouchIdEnrolled = NO;
        [self.database resetConveniencePasswordWithCurrentConfiguration:nil];
    }

    [DatabasesManager.sharedInstance update:self.database];
    
    [self bindUI];
}

- (IBAction)onDone:(id)sender {
    self.database.hasPromptedForTouchIdEnrol = YES;
    [DatabasesManager.sharedInstance update:self.database];

    [self.view.window close];
}

- (IBAction)onNext:(id)sender {
    self.database.hasPromptedForTouchIdEnrol = YES;
    [DatabasesManager.sharedInstance update:self.database];

    self.onNext();
}

@end
