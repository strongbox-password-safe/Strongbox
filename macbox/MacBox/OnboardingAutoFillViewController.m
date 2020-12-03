//
//  OnboardingAutoFillViewController.m
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OnboardingAutoFillViewController.h"
#import "DatabasesManager.h"
#import "AutoFillManager.h"

@interface OnboardingAutoFillViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *wormholeEnabled;

@end

@implementation OnboardingAutoFillViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.database.hasPromptedForAutoFillEnrol = YES;
    [DatabasesManager.sharedInstance update:self.database];

    [self bindUI];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

- (void)bindUI {
    self.enableAutoFill.state = self.database.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableQuickType.state = self.database.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.wormholeEnabled.state = self.database.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    self.enableQuickType.enabled = self.database.autoFillEnabled;
    self.wormholeEnabled.enabled = self.database.autoFillEnabled && self.database.quickTypeEnabled;
}

- (IBAction)onPreferencesChanged:(id)sender {
    BOOL oldQuickType = self.database.quickTypeEnabled;
    BOOL oldEnabled = self.database.autoFillEnabled;

    self.database.autoFillEnabled = self.enableAutoFill.state == NSControlStateValueOn;
    self.database.quickTypeEnabled = self.enableQuickType.state == NSControlStateValueOn;
    self.database.quickWormholeFillEnabled = self.wormholeEnabled.state == NSControlStateValueOn;

    [DatabasesManager.sharedInstance update:self.database];

    
    
    BOOL quickTypeWasTurnOff = (oldQuickType == YES && oldEnabled == YES) &&
        (self.database.quickTypeEnabled == NO || self.database.autoFillEnabled == NO);
    
    if ( quickTypeWasTurnOff ) { 
        NSLog(@"AutoFill QuickType was turned off - Clearing Database....");
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }

    BOOL quickTypeWasTurnedOn = (oldQuickType == NO || oldEnabled == NO) &&
        (self.database.quickTypeEnabled == YES && self.database.autoFillEnabled == YES);

    if ( quickTypeWasTurnedOn ) {
        NSLog(@"AutoFill QuickType was turned on - Populating Database....");
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model databaseUuid:self.database.uuid];
    }
    
    [self bindUI];
}

- (IBAction)onDone:(id)sender {
    [self.view.window close];
}

@end
