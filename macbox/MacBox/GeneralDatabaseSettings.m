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
@property (weak) IBOutlet NSButton *checkboxShowAutoCompleteSuggestions;
@property (weak) IBOutlet NSButton *checkboxLockOnLockScreen;
@property (weak) IBOutlet NSButton *checkboxAutoDownloadFavIcon;
@property (weak) IBOutlet NSButton *checkboxConcealEmptyProtected;
@property (weak) IBOutlet NSButton *checkboxTitleIsEditable;
@property (weak) IBOutlet NSButton *checkboxOtherFieldsAreEditable;
@property (weak) IBOutlet NSButton *checkboxShowRecycleBinInBrowse;
@property (weak) IBOutlet NSButton *checkboxShowRecycleBinInSearch;
@property (weak) IBOutlet NSButton *checkboxKeePassNoSort;

@end

@implementation GeneralDatabaseSettings

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
}

- (void)bindUI {
    NSLog(@"bindUI");

    self.checkboxMonitor.state = self.model.monitorForExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;
    self.stepperMonitorInterval.integerValue = self.model.monitorForExternalChangesInterval;
    self.textboxMonitorInterval.stringValue = self.stepperMonitorInterval.stringValue;
    self.checkboxReloadForeignChanges.state = self.model.autoReloadAfterExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;

    self.stepperMonitorInterval.enabled = self.model.monitorForExternalChanges;
    self.textboxMonitorInterval.enabled = self.model.monitorForExternalChanges;
    self.checkboxReloadForeignChanges.enabled = self.model.monitorForExternalChanges;
    
    self.checkboxLockOnLockScreen.state = self.model.lockOnScreenLock ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkboxKeePassNoSort.state = !self.model.sortKeePassNodes ? NSOnState : NSOffState;
    self.checkboxShowRecycleBinInBrowse.state = !self.model.showRecycleBinInBrowse ? NSOffState : NSOnState;
    self.checkboxShowRecycleBinInSearch.state = self.model.showRecycleBinInSearchResults ? NSOnState : NSOffState;
    self.checkboxShowAutoCompleteSuggestions.state = !self.model.showAutoCompleteSuggestions ? NSOffState : NSOnState;
    self.checkboxTitleIsEditable.state = !self.model.outlineViewTitleIsReadonly ? NSOnState : NSOffState;
    self.checkboxOtherFieldsAreEditable.state = self.model.outlineViewEditableFieldsAreReadonly ? NSOffState : NSOnState;
    self.checkboxAutoDownloadFavIcon.state = self.model.downloadFavIconOnChange ? NSOnState : NSOffState;

    self.checkboxConcealEmptyProtected.state = self.model.concealEmptyProtectedFields ? NSOnState : NSOffState;

    if ( !Settings.sharedInstance.fullVersion ) {
        self.checkboxAutoDownloadFavIcon.title = NSLocalizedString(@"mac_auto_download_favicon_pro_only", @"Automatically download FavIcon on URL Change (PRO Only)");
    }
}

- (IBAction)onSettingChanged:(id)sender {
    NSLog(@"onSettingChanged");
    
    self.model.monitorForExternalChanges = self.checkboxMonitor.state == NSControlStateValueOn;
    self.model.monitorForExternalChangesInterval = self.stepperMonitorInterval.integerValue;
    self.model.autoReloadAfterExternalChanges = self.checkboxReloadForeignChanges.state == NSOnState;
    
    self.model.lockOnScreenLock = self.checkboxLockOnLockScreen.state == NSControlStateValueOn;
    self.model.sortKeePassNodes = self.checkboxKeePassNoSort.state != NSOnState;
    self.model.showRecycleBinInBrowse = self.checkboxShowRecycleBinInBrowse.state == NSOnState;
    self.model.showRecycleBinInSearchResults = self.checkboxShowRecycleBinInSearch.state == NSOnState;
    self.model.showAutoCompleteSuggestions = self.checkboxShowAutoCompleteSuggestions.state == NSOnState;
    self.model.outlineViewTitleIsReadonly = self.checkboxTitleIsEditable.state == NSOffState;
    self.model.outlineViewEditableFieldsAreReadonly = self.checkboxOtherFieldsAreEditable.state == NSOffState;
    self.model.downloadFavIconOnChange = self.checkboxAutoDownloadFavIcon.state == NSOnState;
    self.model.concealEmptyProtectedFields = self.checkboxConcealEmptyProtected.state == NSOnState;
    
    [self bindUI];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)ontextBoxMonitorIntervalChanged:(id)sender {
    NSLog(@"Text changed");

    self.stepperMonitorInterval.integerValue = self.textboxMonitorInterval.integerValue;
        
    [self onSettingChanged:nil];
}

@end
