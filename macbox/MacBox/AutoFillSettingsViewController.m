//
//  AutoFillSettingsViewController.m
//  Strongbox
//
//  Created by Strongbox on 24/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AutoFillSettingsViewController.h"
#import "DatabasesManager.h"
#import "AutoFillManager.h"
#import "Settings.h"
#import "MacAlerts.h"
#import "QuickTypeAutoFillDisplayFormat.h"

@interface AutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *useWormholeIfUnlocked;
@property (weak) IBOutlet NSTextField *labelProWarning;
@property (weak) IBOutlet NSButton *enableSystemExtension;
@property (weak) IBOutlet NSTextField *labelNavHelp;
@property (weak) IBOutlet NSPopUpButton *popupDisplayFormat;

@end

@implementation AutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.popupDisplayFormat.menu removeAllItems];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatUsernameOnly) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleOnly) action:nil keyEquivalent:@""];
    
    [self bindUI];
}

- (void)bindUI {
    BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;

    self.labelProWarning.hidden = pro;
    
    self.enableSystemExtension.state = AutoFillManager.sharedInstance.isOnForStrongbox ? NSControlStateValueOn : NSControlStateValueOff;
    self.labelNavHelp.textColor = AutoFillManager.sharedInstance.isOnForStrongbox ? NSColor.secondaryLabelColor : nil;
    
    self.enableAutoFill.state = self.databaseMetadata.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableQuickType.state = self.databaseMetadata.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.useWormholeIfUnlocked.state = self.databaseMetadata.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    self.enableSystemExtension.enabled = AutoFillManager.sharedInstance.isPossible && !AutoFillManager.sharedInstance.isOnForStrongbox;
    self.enableAutoFill.enabled = AutoFillManager.sharedInstance.isPossible && AutoFillManager.sharedInstance.isOnForStrongbox;

    self.enableQuickType.enabled = AutoFillManager.sharedInstance.isPossible && AutoFillManager.sharedInstance.isOnForStrongbox && self.databaseMetadata.autoFillEnabled;

    [self.popupDisplayFormat selectItemAtIndex:self.databaseMetadata.quickTypeDisplayFormat];
    self.popupDisplayFormat.enabled = self.enableQuickType.enabled && self.databaseMetadata.quickTypeEnabled;
    
    self.useWormholeIfUnlocked.enabled = self.enableQuickType.enabled && self.databaseMetadata.quickTypeEnabled;

    
    
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf bindUI];
    });
}

- (IBAction)onDisplayFormatChanged:(id)sender {
    NSInteger newIndex = self.popupDisplayFormat.indexOfSelectedItem;
    
    if ( newIndex != self.databaseMetadata.quickTypeDisplayFormat ) {
        self.databaseMetadata.quickTypeDisplayFormat = newIndex;
        [DatabasesManager.sharedInstance update:self.databaseMetadata];
        
        NSLog(@"AutoFill QuickType Format was changed - Populating Database....");
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.databaseModel
                                                           databaseUuid:self.databaseMetadata.uuid
                                                          displayFormat:self.databaseMetadata.quickTypeDisplayFormat];
        
        [self bindUI];
    }
}

- (IBAction)onChanged:(id)sender {
    BOOL oldQuickType = self.databaseMetadata.quickTypeEnabled;
    BOOL oldEnabled = self.databaseMetadata.autoFillEnabled;

    self.databaseMetadata.autoFillEnabled = self.enableAutoFill.state == NSControlStateValueOn;
    self.databaseMetadata.quickTypeEnabled = self.enableQuickType.state == NSControlStateValueOn;
    self.databaseMetadata.quickWormholeFillEnabled = self.useWormholeIfUnlocked.state == NSControlStateValueOn;

    

    [DatabasesManager.sharedInstance update:self.databaseMetadata];

    
    
    BOOL quickTypeWasTurnOff = (oldQuickType == YES && oldEnabled == YES) &&
        (self.databaseMetadata.quickTypeEnabled == NO || self.databaseMetadata.autoFillEnabled == NO);
    
    if ( quickTypeWasTurnOff ) { 
        NSLog(@"AutoFill QuickType was turned off - Clearing Database....");
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }

    BOOL quickTypeWasTurnedOn = (oldQuickType == NO || oldEnabled == NO) &&
        (self.databaseMetadata.quickTypeEnabled == YES && self.databaseMetadata.autoFillEnabled == YES);

    if ( quickTypeWasTurnedOn ) {
        NSLog(@"AutoFill QuickType was turned off - Populating Database....");
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.databaseModel
                                                           databaseUuid:self.databaseMetadata.uuid
                                                          displayFormat:self.databaseMetadata.quickTypeDisplayFormat];
    }
    
    [self bindUI];
}

- (IBAction)onEnableSystemExtension:(id)sender {
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
