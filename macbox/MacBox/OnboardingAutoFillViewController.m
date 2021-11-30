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
#import "MacAlerts.h"

@interface OnboardingAutoFillViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *wormholeEnabled;
@property (weak) IBOutlet NSButton *enableExtension;
@property (weak) IBOutlet NSStackView *stackView;
@property (weak) IBOutlet NSTextField *labelSystemExtensionNaviagtionHelp;
@property BOOL isOnForStrongbox;

@end

@implementation OnboardingAutoFillViewController

- (DatabaseMetadata*)database {
    return [DatabasesManager.sharedInstance getDatabaseById:self.databaseUuid];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.stackView setCustomSpacing:8 afterView:self.enableExtension];
    [self.stackView setCustomSpacing:24 afterView:self.labelSystemExtensionNaviagtionHelp];
    
    self.isOnForStrongbox = AutoFillManager.sharedInstance.isOnForStrongbox; 
    [self bindUI];

    

    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isOnForStrongbox = AutoFillManager.sharedInstance.isOnForStrongbox; 
        [weakSelf bindUI];
    });
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

- (void)bindUI {
    self.enableExtension.enabled = AutoFillManager.sharedInstance.isPossible && !self.isOnForStrongbox;
    self.enableExtension.state = self.isOnForStrongbox ? NSControlStateValueOn : NSControlStateValueOff;
    self.labelSystemExtensionNaviagtionHelp.textColor = self.isOnForStrongbox ? NSColor.secondaryLabelColor : nil;

    self.enableAutoFill.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox;
    self.enableAutoFill.state = self.database.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.wormholeEnabled.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox && self.database.autoFillEnabled;
    self.wormholeEnabled.state = self.database.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.enableQuickType.state = self.database.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableQuickType.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox && self.database.autoFillEnabled;
}

- (IBAction)onPreferencesChanged:(id)sender {
    BOOL oldQuickType = self.database.quickTypeEnabled;
    BOOL oldEnabled = self.database.autoFillEnabled;

    BOOL autoFillEnabled = self.enableAutoFill.state == NSControlStateValueOn;
    BOOL quickTypeEnabled = self.enableQuickType.state == NSControlStateValueOn;
    BOOL quickWormholeFillEnabled = self.wormholeEnabled.state == NSControlStateValueOn;

    
    
    BOOL quickTypeWasTurnOff = (oldQuickType == YES && oldEnabled == YES) &&
        (quickTypeEnabled == NO || autoFillEnabled == NO);
    
    if ( quickTypeWasTurnOff ) { 
        NSLog(@"AutoFill QuickType was turned off - Clearing Database....");
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }

    BOOL quickTypeWasTurnedOn = (oldQuickType == NO || oldEnabled == NO) &&
        (quickTypeEnabled == YES && autoFillEnabled == YES);

    if ( quickTypeWasTurnedOn ) {
        NSLog(@"AutoFill QuickType was turned on - Populating Database....");
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model
                                                           databaseUuid:self.database.uuid
                                                          displayFormat:self.database.quickTypeDisplayFormat
                                                        alternativeUrls:self.database.autoFillScanAltUrls
                                                           customFields:self.database.autoFillScanCustomFields
                                                                  notes:self.database.autoFillScanNotes
                                           concealedCustomFieldsAsCreds:self.database.autoFillConcealedFieldsAsCreds
                                         unConcealedCustomFieldsAsCreds:self.database.autoFillUnConcealedFieldsAsCreds];
    }

    [DatabasesManager.sharedInstance atomicUpdate:self.databaseUuid touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillEnabled = autoFillEnabled;
        metadata.quickTypeEnabled = quickTypeEnabled;
        metadata.quickWormholeFillEnabled = quickWormholeFillEnabled;
    }];
    
    [self bindUI];
}

- (IBAction)onDone:(id)sender {
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseUuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForAutoFillEnrol = YES;
    }];

    [self.view.window close];
}

- (IBAction)onEnableStrongboxSystemExtension:(id)sender {
    [MacAlerts customOptionWithCancel:NSLocalizedString(@"mac_autofill_enable_extension_title", @"Enable Strongbox Extension")
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
