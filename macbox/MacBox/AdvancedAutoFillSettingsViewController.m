//
//  AdvancedAutoFillSettingsViewController.m
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AdvancedAutoFillSettingsViewController.h"
#import "AutoFillManager.h"

@interface AdvancedAutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *includeAlternativeUrls;
@property (weak) IBOutlet NSButton *scanCustomFields;
@property (weak) IBOutlet NSButton *scanNotesForUrls;

@end

@implementation AdvancedAutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
}

- (void)bindUI {
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    self.includeAlternativeUrls.state = meta.autoFillScanAltUrls ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanCustomFields.state = meta.autoFillScanCustomFields ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanNotesForUrls.state = meta.autoFillScanNotes ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)onChanged:(id)sender {
    BOOL autoFillScanAltUrls = self.includeAlternativeUrls.state == NSControlStateValueOn;
    BOOL autoFillScanCustomFields = self.scanCustomFields.state == NSControlStateValueOn;
    BOOL autoFillScanNotes = self.scanNotesForUrls.state == NSControlStateValueOn;

    self.model.databaseMetadata.autoFillScanAltUrls = autoFillScanAltUrls;
    self.model.databaseMetadata.autoFillScanCustomFields = autoFillScanCustomFields;
    self.model.databaseMetadata.autoFillScanNotes = autoFillScanNotes;

    [self updateAutoFillDatabases];
    
    [self bindUI];
}

- (void)updateAutoFillDatabases {
    [self.model rebuildMapsAndCaches];
    
    
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
