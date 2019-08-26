//
//  ChangeMasterPasswordWindowController.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "CreateFormatAndSetCredentialsWizard.h"
#import "Settings.h"
#import "Alerts.h"
#import "Utils.h"
#import "KeyFileParser.h"

@interface CreateFormatAndSetCredentialsWizard () <NSTabViewDelegate>

@property NSString* keyFilePath;

@end

@implementation CreateFormatAndSetCredentialsWizard

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if(self.titleText) {
        self.textFieldTitle.stringValue = self.titleText;
    }

    self.keyFilePath = nil;
    
    self.tabView.delegate = self;
    
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[self.createSafeWizardMode ? 0 : 1]];
    self.window.title = self.createSafeWizardMode ? @"Create New Password Database" : @"Enter Database Master Credentials";
    
    [self setUIFromFormat];
    
    [self enableUiBasedOnSafeType];
    [self updateUi];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    if(tabViewItem == self.tabView.tabViewItems[1]) {
        [self.window makeFirstResponder:self.textFieldNew];
        [self.textFieldNew becomeFirstResponder];
    }
}

- (void)enableUiBasedOnSafeType {
    if(self.databaseFormat == kPasswordSafe) {
        self.checkboxUseAKeyFile.state = NSOffState;
        self.checkboxUseAKeyFile.enabled = NO;
        self.checkboxUseAPassword.state = NSOnState;
        self.checkboxUseAPassword.enabled = NO;
    }
    else {
        self.checkboxUseAPassword.state = NSOnState;
        self.checkboxUseAPassword.enabled = YES;
        self.checkboxUseAKeyFile.state = NSOffState;
        self.checkboxUseAKeyFile.enabled = YES;
    }
}

- (IBAction)onCancel:(id)sender {
    _confirmedCompositeKeyFactors = nil;
    
    if(self.createSafeWizardMode) {
        [NSApp stopModalWithCode:NSModalResponseCancel];
        [NSApp endSheet:self.window returnCode:NSModalResponseCancel];
    }
    else {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    }
}

- (IBAction)onOk:(id)sender {
    CompositeKeyFactors* ret = [CompositeKeyFactors password:nil];

    if(self.checkboxUseAPassword.state == NSOnState) {
        if([self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
            ret.password = self.textFieldNew.stringValue;
        }
    }

    if(self.checkboxUseAKeyFile.state == NSOnState) {
        NSError* error;
        NSData* data = [NSData dataWithContentsOfFile:self.keyFilePath options:kNilOptions error:&error];
        
        if(!data) {
            NSLog(@"Could not read file at %@. Error: %@", self.keyFilePath, error);
            [Alerts error:@"Could not open key file." error:error window:self.window];
            _confirmedCompositeKeyFactors = nil;
            return;
        }

        ret.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:data checkForXml:YES]; // TODO: Wrong for XML KDB Only
    }

    _confirmedCompositeKeyFactors = ret;

    if(self.createSafeWizardMode) {
        [NSApp stopModalWithCode:NSModalResponseOK];
        [NSApp endSheet:self.window returnCode:NSModalResponseOK];
    }
    else {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    }
}

- (IBAction)controlTextDidChange:(NSSecureTextField *)obj
{
    [self updateUi];
}

- (void)updateUi {
    if(self.checkboxUseAPassword.state == NSOnState) {
        self.textFieldNew.enabled = YES;
        self.textFieldConfirm.enabled = YES;
    }
    else {
        self.textFieldNew.enabled = NO;
        self.textFieldConfirm.enabled = NO;
    }
    
    if(self.checkboxUseAKeyFile.state == NSOnState) {
        self.buttonBrowse.enabled = YES;
        self.labelKeyFilePath.stringValue = self.keyFilePath ? self.keyFilePath : @"";
        self.labelKeyFilePath.placeholderString = self.keyFilePath ? @"" : @"Click Browse to Select a Key File";
    }
    else {
        self.buttonBrowse.enabled = NO;
        self.labelKeyFilePath.stringValue = @"";
        self.labelKeyFilePath.placeholderString = @"";
    }
    
    self.buttonOk.enabled = [self validateUi];
}

- (BOOL)validateUi {
    self.labelPasswordsMatch.stringValue = @"";
    self.labelPasswordsMatch.textColor = [NSColor redColor];
    
    if(self.checkboxUseAPassword.state == NSOnState) {
        if(![self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
            if(self.textFieldConfirm.stringValue.length) {
                self.labelPasswordsMatch.stringValue = @"🛑 Passwords don't match";
            }
            
            return NO; // No Further Validation For THe Moment
        }
    }
    
    if(self.checkboxUseAKeyFile.state == NSOnState) {
        if(self.keyFilePath == nil || ![NSFileManager.defaultManager fileExistsAtPath:self.keyFilePath]) {
            self.labelPasswordsMatch.stringValue = self.keyFilePath ? @"🛑 Key File Invalid" : @"🛑 Select a Key File";
            return NO;
        }
    }
    
    if(self.checkboxUseAPassword.state == NSOffState && self.checkboxUseAKeyFile.state == NSOffState) {
        self.labelPasswordsMatch.stringValue = @"🛑 You must use at least a Password or a Key File";
        return NO;
    }
    
    // KeePass 1 and Password Safe don't allow empty
    
    if(self.databaseFormat == kKeePass1 || self.databaseFormat == kPasswordSafe) {
        if(self.checkboxUseAPassword.state == NSOnState) {
            if(self.textFieldNew.stringValue.length == 0) {
                self.labelPasswordsMatch.stringValue = @"🛑 Password cannot be Empty";
                return NO;
            }
        }
    }
    
    // Warn on simple weak password
    
    if(self.textFieldNew.stringValue.length < 8) {
        self.labelPasswordsMatch.stringValue = @"☠️ Weak Credentials";
        self.labelPasswordsMatch.textColor = [NSColor orangeColor];
    }
    else {
        self.labelPasswordsMatch.stringValue = @"✅ Valid Credentials";
        self.labelPasswordsMatch.textColor = [NSColor greenColor];
    }
    
    return YES;
}

- (IBAction)onBrowse:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            self.keyFilePath = openPanel.URL.path;

            [self updateUi];
        }
    }];
}

- (IBAction)onUseAPassword:(id)sender {
    [self updateUi];
}

- (IBAction)onUseAKeyFile:(id)sender {
    [self updateUi];
}

// Select Format...

- (IBAction)onNext:(id)sender {
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[1]];
}

- (IBAction)onBack:(id)sender {
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[0]];
}

- (void)setUIFromFormat {
    switch (self.databaseFormat) {
        case kPasswordSafe:
            self.formatPasswordSafe.state = NSOnState;
            break;
        case kKeePass4:
            self.formatKeePass2Advanced.state = NSOnState;
            break;
        case kKeePass:
            self.formatKeePass2Standard.state = NSOnState;
            break;
        case kKeePass1:
            self.formatKeePass1.state = NSOnState;
            break;
        default:
            break;
    }
}

- (void)setFormatFromUI {
    if(self.formatPasswordSafe.state == NSOnState) {
        self.databaseFormat = kPasswordSafe;
    }
    else if(self.formatKeePass2Advanced.state == NSOnState) {
        self.databaseFormat = kKeePass4;
    }
    else if(self.formatKeePass2Standard.state == NSOnState) {
        self.databaseFormat = kKeePass;
    }
    else if(self.formatKeePass1.state == NSOnState) {
        self.databaseFormat = kKeePass1;
    }
}

- (IBAction)onChangeDatabaseFormat:(id)sender {
    [self setFormatFromUI];
    
    NSLog(@"Format = %ld", (long)self.databaseFormat);
    
    [self enableUiBasedOnSafeType];
    [self updateUi];
}

@end
