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
#import "Alerts.h"

@interface OnboardingAutoFillViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *wormholeEnabled;
@property (weak) IBOutlet NSButton *enableExtension;
@property (weak) IBOutlet NSStackView *stackView;
@property (weak) IBOutlet NSTextField *labelSystemExtensionNaviagtionHelp;

@end

@implementation OnboardingAutoFillViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.stackView setCustomSpacing:8 afterView:self.enableExtension];
    [self.stackView setCustomSpacing:24 afterView:self.labelSystemExtensionNaviagtionHelp];
    
    [self bindUI];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

- (void)bindUI {
    self.enableExtension.state = AutoFillManager.sharedInstance.isOnForStrongbox ? NSControlStateValueOn : NSControlStateValueOff;
    self.labelSystemExtensionNaviagtionHelp.textColor = AutoFillManager.sharedInstance.isOnForStrongbox ? NSColor.secondaryLabelColor : nil;
    
    self.enableAutoFill.state = self.database.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableQuickType.state = self.database.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.wormholeEnabled.state = self.database.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    self.enableExtension.enabled = AutoFillManager.sharedInstance.isPossible && !AutoFillManager.sharedInstance.isOnForStrongbox;
    self.enableAutoFill.enabled = AutoFillManager.sharedInstance.isPossible && AutoFillManager.sharedInstance.isOnForStrongbox;
    self.enableQuickType.enabled = AutoFillManager.sharedInstance.isPossible && AutoFillManager.sharedInstance.isOnForStrongbox && self.database.autoFillEnabled;
    self.wormholeEnabled.enabled = AutoFillManager.sharedInstance.isPossible && AutoFillManager.sharedInstance.isOnForStrongbox && self.database.autoFillEnabled && self.database.quickTypeEnabled;

    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf bindUI];
    });
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
    self.database.hasPromptedForAutoFillEnrol = YES;
    [DatabasesManager.sharedInstance update:self.database];
    
    [self.view.window close];
}

- (IBAction)onEnableStrongboxSystemExtension:(id)sender {
    [Alerts customOptionWithCancel:NSLocalizedString(@"mac_autofill_enable_extension_title", @"Enable Strongbox Extension")
                 informativeText:NSLocalizedString(@"mac_autofill_enable_extension_message", @"To use AutoFill you must enable the Strongbox Extension in System Preferences. To do this click the 'Open System Preferences...' button below and navigate to:\n\n∙ Extensions > Password AutoFill > Check 'Strongbox'\n\n")
               option1AndDefault:NSLocalizedString(@"mac_autofill_action_open_system_preferences", @"Open System Preferences...")
                          window:self.view.window
                        completion:^(BOOL go) {
        if (go) {
            NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/bin/sh";
            task.arguments = @[@"-c" , @"open x-apple.systempreferences:com.apple.preference"];
            [task launch];
        }
    }];
}

@end
