//
//  GeneralDatabaseSettings.m
//  MacBox
//
//  Created by Strongbox on 24/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "GeneralDatabaseSettings.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "KeePassIconSet.h"
#import "Constants.h"

@interface GeneralDatabaseSettings ()

@property (weak) IBOutlet NSButton *checkboxMonitor;
@property (weak) IBOutlet NSTextField *textboxMonitorInterval;
@property (weak) IBOutlet NSButton *checkboxReloadForeignChanges;
@property (weak) IBOutlet NSButton *checkboxAutoDownloadFavIcon;
@property (weak) IBOutlet NSButton *closeButton;
@property (weak) IBOutlet NSPopUpButton *popupIconSet;
@property (weak) IBOutlet NSButton *helpButton;


@property (weak) IBOutlet NSButton *checkboxShowRecycleBin;
@property (weak) IBOutlet NSButton *checkboxManualItemOrdering;
@property (weak) IBOutlet NSStepper *stepperMonitorInterval;

@end

@implementation GeneralDatabaseSettings
 
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.popupIconSet.menu removeAllItems];
    
    [self.popupIconSet.menu addItemWithTitle:getIconSetName(kKeePassIconSetClassic) action:nil keyEquivalent:@""];
    [self.popupIconSet.menu addItemWithTitle:getIconSetName(kKeePassIconSetSfSymbols) action:nil keyEquivalent:@""];
    [self.popupIconSet.menu addItemWithTitle:getIconSetName(kKeePassIconSetKeePassXC) action:nil keyEquivalent:@""];

    if ( self.model.format == kPasswordSafe ) {
        self.popupIconSet.enabled = NO;
        self.helpButton.hidden = YES;
        self.checkboxShowRecycleBin.hidden = YES;
        self.checkboxAutoDownloadFavIcon.hidden = YES;
        self.checkboxManualItemOrdering.hidden = YES;
    }
    else if ( self.model.format == kKeePass1 ) {
        self.helpButton.hidden = YES;
        self.checkboxShowRecycleBin.hidden = YES;
        self.checkboxAutoDownloadFavIcon.hidden = YES;
        self.checkboxManualItemOrdering.hidden = YES;
    }
        
    [self bindUI];
    
    [self.textboxMonitorInterval resignFirstResponder];
    [self.closeButton becomeFirstResponder];
}

- (IBAction)onSetIconSet:(id)sender {
    NSInteger idx = self.popupIconSet.indexOfSelectedItem;
    
    self.model.keePassIconSet = idx;
    
    [self bindUI];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsChangedNotification object:nil];
}

- (void)bindUI {
    self.checkboxMonitor.state = self.model.monitorForExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;
    self.stepperMonitorInterval.integerValue = self.model.monitorForExternalChangesInterval;
    self.textboxMonitorInterval.stringValue = self.stepperMonitorInterval.stringValue;
    self.checkboxReloadForeignChanges.state = self.model.autoReloadAfterExternalChanges ? NSControlStateValueOn : NSControlStateValueOff;

    self.stepperMonitorInterval.enabled = self.model.monitorForExternalChanges;
    self.textboxMonitorInterval.enabled = self.model.monitorForExternalChanges;
    self.checkboxReloadForeignChanges.enabled = self.model.monitorForExternalChanges;
    
    self.checkboxAutoDownloadFavIcon.state = self.model.downloadFavIconOnChange ? NSControlStateValueOn : NSControlStateValueOff;

    if ( !Settings.sharedInstance.isPro ) {
        self.checkboxAutoDownloadFavIcon.title = NSLocalizedString(@"mac_auto_download_favicon_pro_only", @"Automatically download FavIcon on URL Change (PRO Only)");
    }
    
    [self.popupIconSet selectItemAtIndex:self.model.keePassIconSet];
    
    self.checkboxManualItemOrdering.state = !self.model.sortKeePassNodes ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkboxShowRecycleBin.state = !self.model.showRecycleBinInBrowse ? NSControlStateValueOff : NSControlStateValueOn;
}

- (IBAction)onSettingChanged:(id)sender {
    self.model.monitorForExternalChanges = self.checkboxMonitor.state == NSControlStateValueOn;
    self.model.monitorForExternalChangesInterval = self.stepperMonitorInterval.integerValue;
    self.model.autoReloadAfterExternalChanges = self.checkboxReloadForeignChanges.state == NSControlStateValueOn;
    self.model.downloadFavIconOnChange = self.checkboxAutoDownloadFavIcon.state == NSControlStateValueOn;
    self.model.sortKeePassNodes = self.checkboxManualItemOrdering.state == NSControlStateValueOff;
    self.model.showRecycleBinInBrowse = self.checkboxShowRecycleBin.state == NSControlStateValueOn;

    [self bindUI];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsChangedNotification object:nil];
    });
}

- (IBAction)onTextBoxMonitorIntervalChanged:(id)sender {
    self.stepperMonitorInterval.integerValue = self.textboxMonitorInterval.integerValue;
        
    [self onSettingChanged:nil];
}

- (IBAction)onClose:(id)sender {
    [self.view.window cancelOperation:nil];
}

@end
