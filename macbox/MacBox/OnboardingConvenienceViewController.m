//
//  OnboardingConvenienceViewController.m
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OnboardingConvenienceViewController.h"
#import "BiometricIdHelper.h"
#import "Settings.h"

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

- (MacDatabasePreferences*)database {
    return [MacDatabasePreferences fromUuid:self.databaseUuid];
}

- (void)bindUI {
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL conveniencePossible = touchAvailable && featureAvailable;
    BOOL convenienceEnabled = (self.database.isTouchIdEnabled && touchAvailable);
    
    self.enableTouchId.enabled = conveniencePossible;
    self.enableTouchId.state = (conveniencePossible && convenienceEnabled) ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)onPreferencesChanged:(id)sender {
    BOOL enable = self.enableTouchId.state == NSControlStateValueOn;
    
    self.database.isTouchIdEnabled = enable;
    self.database.isWatchUnlockEnabled = enable;

    if ( enable ) {
        self.database.conveniencePasswordHasBeenStored = YES;
        self.database.conveniencePassword = self.ckfs.password;
    }
    else {
        self.database.conveniencePasswordHasBeenStored = NO;
        self.database.conveniencePassword = nil;
    }
    
    [self bindUI];
}

- (IBAction)onDone:(id)sender {
    self.database.hasPromptedForTouchIdEnrol = YES;

    [self.view.window close];
}

- (IBAction)onNext:(id)sender {
    self.database.hasPromptedForTouchIdEnrol = YES;

    self.onNext();
}

@end
