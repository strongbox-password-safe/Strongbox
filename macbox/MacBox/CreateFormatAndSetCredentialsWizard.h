//
//  ChangeMasterPasswordWindowController.h
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSAdvancedTextField.h"
#import "AbstractDatabaseFormatAdaptor.h"

@interface CreateFormatAndSetCredentialsWizard : NSWindowController

@property (nonatomic, readonly) CompositeKeyFactors* confirmedCompositeKeyFactors;

@property (nonatomic) NSString* titleText;
@property DatabaseFormat databaseFormat;

@property (weak) IBOutlet NSTabView *tabView;
@property BOOL createSafeWizardMode;

//

@property (weak) IBOutlet NSSecureTextField *textFieldNew;
@property (weak) IBOutlet NSSecureTextField *textFieldConfirm;
@property (weak) IBOutlet NSButton *buttonOk;
@property (weak) IBOutlet NSButton *buttonCancel;

@property (weak) IBOutlet NSAdvancedTextField *labelPasswordsMatch;
@property (weak) IBOutlet NSTextField *textFieldTitle;

@property (weak) IBOutlet NSButton *checkboxUseAPassword;
@property (weak) IBOutlet NSButton *checkboxUseAKeyFile;
@property (weak) IBOutlet NSButton *buttonBrowse;
@property (weak) IBOutlet NSTextField *labelKeyFilePath;

@property (weak) IBOutlet NSButton *formatPasswordSafe;
@property (weak) IBOutlet NSButton *formatKeePass2Advanced;
@property (weak) IBOutlet NSButton *formatKeePass2Standard;
@property (weak) IBOutlet NSButton *formatKeePass1;

@end
