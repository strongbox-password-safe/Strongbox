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

@interface AutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *useWormholeIfUnlocked;
@property (weak) IBOutlet NSTextField *labelProWarning;

@end

@implementation AutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
}

- (void)bindUI {
    BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;

    self.labelProWarning.hidden = pro;
    
    self.enableAutoFill.state = self.model.databaseMetadata.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enableQuickType.state = self.model.databaseMetadata.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.useWormholeIfUnlocked.state = self.model.databaseMetadata.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    self.enableQuickType.enabled = self.model.databaseMetadata.autoFillEnabled;
    self.useWormholeIfUnlocked.enabled = self.model.databaseMetadata.autoFillEnabled && self.model.databaseMetadata.quickTypeEnabled;
}

- (IBAction)onChanged:(id)sender {
    BOOL oldQuickType = self.model.databaseMetadata.quickTypeEnabled;
    BOOL oldEnabled = self.model.databaseMetadata.autoFillEnabled;

    self.model.databaseMetadata.autoFillEnabled = self.enableAutoFill.state == NSControlStateValueOn;
    self.model.databaseMetadata.quickTypeEnabled = self.enableQuickType.state == NSControlStateValueOn;
    self.model.databaseMetadata.quickWormholeFillEnabled = self.useWormholeIfUnlocked.state == NSControlStateValueOn;

    

    [DatabasesManager.sharedInstance update:self.model.databaseMetadata];

    
    
    BOOL quickTypeWasTurnOff = (oldQuickType == YES && oldEnabled == YES) &&
        (self.model.databaseMetadata.quickTypeEnabled == NO || self.model.databaseMetadata.autoFillEnabled == NO);
    
    if ( quickTypeWasTurnOff ) { 
        NSLog(@"AutoFill QuickType was turned off - Clearing Database....");
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }

    BOOL quickTypeWasTurnedOn = (oldQuickType == NO || oldEnabled == NO) &&
        (self.model.databaseMetadata.quickTypeEnabled == YES && self.model.databaseMetadata.autoFillEnabled == YES);

    if ( quickTypeWasTurnedOn ) {
        NSLog(@"AutoFill QuickType was turned off - Populating Database....");
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.database databaseUuid:self.model.databaseMetadata.uuid];
    }
    
    [self bindUI];
}

@end
