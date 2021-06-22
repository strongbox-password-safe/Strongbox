//
//  OnboardingConvenienceViewController.m
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OnboardingConvenienceViewController.h"
#import "DatabasesManager.h"
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

- (DatabaseMetadata*)database {
    return [DatabasesManager.sharedInstance getDatabaseById:self.databaseUuid];
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
    
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseUuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.isTouchIdEnabled = enable;
        metadata.isWatchUnlockEnabled = enable;

        if ( enable ) {
            metadata.isTouchIdEnrolled = YES;
            [metadata resetConveniencePasswordWithCurrentConfiguration:self.ckfs.password];
        }
        else {
            metadata.isTouchIdEnrolled = NO;
            [metadata resetConveniencePasswordWithCurrentConfiguration:nil];
        }
    }];
    
    [self bindUI];
}

- (IBAction)onDone:(id)sender {
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseUuid touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForTouchIdEnrol = YES;
    }];

    [self.view.window close];
}

- (IBAction)onNext:(id)sender {
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseUuid touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForTouchIdEnrol = YES;
    }];

    self.onNext();
}

@end
