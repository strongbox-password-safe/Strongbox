//
//  AdvancedAutoFillSettingsViewController.m
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AdvancedAutoFillSettingsViewController.h"
#import "AutoFillManager.h"
#import "Settings.h"

@interface AdvancedAutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *scanCustomFields;
@property (weak) IBOutlet NSButton *scanNotesForUrls;

@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSPopUpButton *popupDisplayFormat;
@property (weak) IBOutlet NSButton *addUnconcealedFields;
@property (weak) IBOutlet NSButton *addConcealedFields;
@property (weak) IBOutlet NSButton *includeAssociated;

@end

@implementation AdvancedAutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupQuickTypePopup];
    
    [self bindUI];
}

- (void)setupQuickTypePopup {
    [self.popupDisplayFormat.menu removeAllItems];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatUsernameOnly) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleOnly) action:nil keyEquivalent:@""];
    
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenTitle) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenUsername) action:nil keyEquivalent:@""];
}

- (void)bindUI {
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    self.scanCustomFields.state = meta.autoFillScanCustomFields ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanNotesForUrls.state = meta.autoFillScanNotes ? NSControlStateValueOn : NSControlStateValueOff;

    BOOL pro = Settings.sharedInstance.isPro;
    BOOL safariEnabled = AutoFillManager.sharedInstance.isOnForStrongbox;

    self.enableQuickType.enabled = pro && meta.autoFillEnabled && safariEnabled;
    self.enableQuickType.state = meta.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    
    BOOL autoFillOn = pro && meta.autoFillEnabled && safariEnabled;
    BOOL quickTypeOn = autoFillOn && meta.quickTypeEnabled;
    
    [self.popupDisplayFormat selectItemAtIndex:meta.quickTypeDisplayFormat];
    
    self.popupDisplayFormat.enabled = quickTypeOn;
    
    self.includeAssociated.state = meta.includeAssociatedDomains ? NSControlStateValueOn : NSControlStateValueOff;
    self.addConcealedFields.state = meta.autoFillConcealedFieldsAsCreds ? NSControlStateValueOn : NSControlStateValueOff;
    self.addUnconcealedFields.state = meta.autoFillUnConcealedFieldsAsCreds ? NSControlStateValueOn : NSControlStateValueOff;

}

- (IBAction)onChanged:(id)sender {
    BOOL autoFillScanCustomFields = self.scanCustomFields.state == NSControlStateValueOn;
    BOOL autoFillScanNotes = self.scanNotesForUrls.state == NSControlStateValueOn;

    self.model.databaseMetadata.autoFillScanCustomFields = autoFillScanCustomFields;
    self.model.databaseMetadata.autoFillScanNotes = autoFillScanNotes;

    BOOL quickTypeEnabled = self.enableQuickType.state == NSControlStateValueOn;
    self.model.databaseMetadata.quickTypeEnabled = quickTypeEnabled;

    BOOL concealedCustomFieldsAsCreds = self.addConcealedFields.state == NSControlStateValueOn;
    BOOL unConcealedCustomFieldsAsCreds = self.addUnconcealedFields.state == NSControlStateValueOn;
    
    self.model.databaseMetadata.includeAssociatedDomains = self.includeAssociated.state == NSControlStateValueOn;
    self.model.databaseMetadata.autoFillConcealedFieldsAsCreds = concealedCustomFieldsAsCreds;
    self.model.databaseMetadata.autoFillUnConcealedFieldsAsCreds = unConcealedCustomFieldsAsCreds;
    
    [self updateAutoFillDatabases];
    
    [self bindUI];
}

- (IBAction)onDisplayFormatChanged:(id)sender {
    NSInteger newIndex = self.popupDisplayFormat.indexOfSelectedItem;
    
    if ( newIndex != self.model.databaseMetadata.quickTypeDisplayFormat ) {
        self.model.databaseMetadata.quickTypeDisplayFormat = newIndex;
        
        slog(@"AutoFill QuickType Format was changed - Populating Database....");
        
        [self updateAutoFillDatabases];
        
        [self bindUI];
    }
}

- (void)updateAutoFillDatabases {
    dispatch_async(dispatch_get_main_queue(), ^{
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [self.model rebuildMapsAndCaches];
    });
}

@end
