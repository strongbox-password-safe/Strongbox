//
//  AdvancedQuickTypeSettingsViewController.m
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AdvancedQuickTypeSettingsViewController.h"
#import "AutoFillManager.h"
#import "Settings.h"

@interface AdvancedQuickTypeSettingsViewController ()

@property (weak) IBOutlet NSPopUpButton *popupDisplayFormat;
@property (weak) IBOutlet NSButton *addUnconcealedFields;
@property (weak) IBOutlet NSButton *addConcealedFields;

@end

@implementation AdvancedQuickTypeSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.popupDisplayFormat.menu removeAllItems];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatUsernameOnly) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleOnly) action:nil keyEquivalent:@""];
    
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenTitle) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenUsername) action:nil keyEquivalent:@""];
    
    [self bindUI];
}

- (void)bindUI {
    BOOL pro = Settings.sharedInstance.isPro;
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    BOOL safariEnabled = AutoFillManager.sharedInstance.isOnForStrongbox;
    
    BOOL autoFillOn = pro && meta.autoFillEnabled && safariEnabled;
    BOOL quickTypeOn = autoFillOn && meta.quickTypeEnabled;
    
    [self.popupDisplayFormat selectItemAtIndex:meta.quickTypeDisplayFormat];
    
    self.popupDisplayFormat.enabled = quickTypeOn;
    
    self.addConcealedFields.state = meta.autoFillConcealedFieldsAsCreds ? NSControlStateValueOn : NSControlStateValueOff;
    self.addUnconcealedFields.state = meta.autoFillUnConcealedFieldsAsCreds ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)onChanged:(id)sender {
    BOOL concealedCustomFieldsAsCreds = self.addConcealedFields.state == NSControlStateValueOn;
    BOOL unConcealedCustomFieldsAsCreds = self.addUnconcealedFields.state == NSControlStateValueOn;
    
    self.model.databaseMetadata.autoFillConcealedFieldsAsCreds = concealedCustomFieldsAsCreds;
    self.model.databaseMetadata.autoFillUnConcealedFieldsAsCreds = unConcealedCustomFieldsAsCreds;
    
    [self refreshQuickType];
    
    [self bindUI];
}

- (IBAction)onDisplayFormatChanged:(id)sender {
    NSInteger newIndex = self.popupDisplayFormat.indexOfSelectedItem;
    
    if ( newIndex != self.model.databaseMetadata.quickTypeDisplayFormat ) {
        self.model.databaseMetadata.quickTypeDisplayFormat = newIndex;
        
        NSLog(@"AutoFill QuickType Format was changed - Populating Database....");
        
        [self refreshQuickType];
        
        [self bindUI];
    }
}

- (void)refreshQuickType {
    
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.commonModel
                                                       databaseUuid:meta.uuid
                                                      displayFormat:meta.quickTypeDisplayFormat
                                                    alternativeUrls:meta.autoFillScanAltUrls
                                                       customFields:meta.autoFillScanCustomFields
                                                              notes:meta.autoFillScanNotes
                                       concealedCustomFieldsAsCreds:meta.autoFillConcealedFieldsAsCreds
                                     unConcealedCustomFieldsAsCreds:meta.autoFillUnConcealedFieldsAsCreds
                                                           nickName:meta.nickName];
    
}

@end
