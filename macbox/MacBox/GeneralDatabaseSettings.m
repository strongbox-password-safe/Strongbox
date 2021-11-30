//
//  GeneralDatabaseSettings.m
//  MacBox
//
//  Created by Strongbox on 24/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "GeneralDatabaseSettings.h"
#import "DatabasesManager.h"
#import "Settings.h"
#import "AppDelegate.h"

@interface GeneralDatabaseSettings ()

@property (weak) IBOutlet NSButton *checkboxMonitor;
@property (weak) IBOutlet NSTextField *textboxMonitorInterval;
@property (weak) IBOutlet NSStepper *stepperMonitorInterval;
@property (weak) IBOutlet NSButton *checkboxReloadForeignChanges;
@property (weak) IBOutlet NSButton *checkboxLockOnLockScreen;
@property (weak) IBOutlet NSButton *checkboxAutoDownloadFavIcon;
@property (weak) IBOutlet NSButton *closeButton;

@end

@implementation GeneralDatabaseSettings

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
    
    [self.textboxMonitorInterval resignFirstResponder];
    [self.closeButton becomeFirstResponder];
}

- (void)bindUI {
    self.checkboxMonitor.state = self.model.monitorForExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;
    self.stepperMonitorInterval.integerValue = self.model.monitorForExternalChangesInterval;
    self.textboxMonitorInterval.stringValue = self.stepperMonitorInterval.stringValue;
    self.checkboxReloadForeignChanges.state = self.model.autoReloadAfterExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;

    self.stepperMonitorInterval.enabled = self.model.monitorForExternalChanges;
    self.textboxMonitorInterval.enabled = self.model.monitorForExternalChanges;
    self.checkboxReloadForeignChanges.enabled = self.model.monitorForExternalChanges;
    
    self.checkboxLockOnLockScreen.state = self.model.lockOnScreenLock ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkboxAutoDownloadFavIcon.state = self.model.downloadFavIconOnChange ? NSOnState : NSOffState;

    if ( !Settings.sharedInstance.fullVersion ) {
        self.checkboxAutoDownloadFavIcon.title = NSLocalizedString(@"mac_auto_download_favicon_pro_only", @"Automatically download FavIcon on URL Change (PRO Only)");
    }
}

- (IBAction)onSettingChanged:(id)sender {
    self.model.monitorForExternalChanges = self.checkboxMonitor.state == NSControlStateValueOn;
    self.model.monitorForExternalChangesInterval = self.stepperMonitorInterval.integerValue;
    self.model.autoReloadAfterExternalChanges = self.checkboxReloadForeignChanges.state == NSOnState;
    
    self.model.lockOnScreenLock = self.checkboxLockOnLockScreen.state == NSControlStateValueOn;
    self.model.downloadFavIconOnChange = self.checkboxAutoDownloadFavIcon.state == NSOnState;

    [self bindUI];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onTextBoxMonitorIntervalChanged:(id)sender {
    NSLog(@"Text changed");

    self.stepperMonitorInterval.integerValue = self.textboxMonitorInterval.integerValue;
        
    [self onSettingChanged:nil];
}

- (IBAction)onClose:(id)sender {
    [self.view.window cancelOperation:nil];
}

@end
