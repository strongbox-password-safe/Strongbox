//
//  ChangeMasterPasswordWindowController.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ChangeMasterPasswordWindowController.h"

@interface ChangeMasterPasswordWindowController ()

@end

@implementation ChangeMasterPasswordWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if(self.titleText) {
        self.textFieldTitle.stringValue = self.titleText;
    }
    
    [self updateUi];
}

- (IBAction)onCancel:(id)sender {
    _confirmedPassword = nil;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)onOk:(id)sender {
    if([self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
        _confirmedPassword = self.textFieldNew.stringValue;
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    }
}

- (IBAction)controlTextDidChange:(NSSecureTextField *)obj
{
    [self updateUi];
}

- (void)updateUi {
    if(self.textFieldNew.stringValue.length == 0 && self.textFieldConfirm.stringValue.length == 0){
        self.labelPasswordsMatch.stringValue = @"*Passwords cannot be blank";
        self.buttonOk.enabled = NO;
    }
    else if([self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
        self.labelPasswordsMatch.stringValue = @"";
        self.buttonOk.enabled = YES;
    }
    else {
        self.labelPasswordsMatch.stringValue = @"*Passwords don't match";
        self.buttonOk.enabled = NO;
    }
}

@end
