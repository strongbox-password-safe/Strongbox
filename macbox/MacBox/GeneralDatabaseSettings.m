//
//  GeneralDatabaseSettings.m
//  MacBox
//
//  Created by Strongbox on 24/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "GeneralDatabaseSettings.h"
#import "DatabasesManager.h"

@interface GeneralDatabaseSettings ()

@property (weak) IBOutlet NSButton *checkboxMonitor;
@property (weak) IBOutlet NSTextField *textboxMonitorInterval;
@property (weak) IBOutlet NSStepper *stepperMonitorInterval;
@property (weak) IBOutlet NSButton *checkboxReloadForeignChanges;

@end

@implementation GeneralDatabaseSettings

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
}

- (void)bindUI {
    NSLog(@"bindUI");

    self.checkboxMonitor.state = self.databaseMetadata.monitorForExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;
    self.stepperMonitorInterval.integerValue = self.databaseMetadata.monitorForExternalChangesInterval;
    self.textboxMonitorInterval.stringValue = self.stepperMonitorInterval.stringValue;
    self.checkboxReloadForeignChanges.state = self.databaseMetadata.autoReloadAfterExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;

    self.stepperMonitorInterval.enabled = self.databaseMetadata.monitorForExternalChanges;
    self.textboxMonitorInterval.enabled = self.databaseMetadata.monitorForExternalChanges;
    self.checkboxReloadForeignChanges.enabled = self.databaseMetadata.monitorForExternalChanges;
}

- (IBAction)onSettingChanged:(id)sender {
    NSLog(@"onSettingChanged");
    
    self.databaseMetadata.monitorForExternalChanges = self.checkboxMonitor.state == NSControlStateValueOn;
    self.databaseMetadata.monitorForExternalChangesInterval = self.stepperMonitorInterval.integerValue;
    self.databaseMetadata.autoReloadAfterExternalChanges = self.checkboxReloadForeignChanges.state == NSOnState;
    
    [DatabasesManager.sharedInstance update:self.databaseMetadata];
    
    [self bindUI];
}

- (IBAction)ontextBoxMonitorIntervalChanged:(id)sender {
    NSLog(@"Text changed");

    self.stepperMonitorInterval.integerValue = self.textboxMonitorInterval.integerValue;
        
    [self onSettingChanged:nil];
}

@end
