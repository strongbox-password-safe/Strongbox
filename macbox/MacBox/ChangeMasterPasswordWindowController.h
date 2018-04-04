//
//  ChangeMasterPasswordWindowController.h
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSAdvancedTextField.h"

@interface ChangeMasterPasswordWindowController : NSWindowController

@property (weak) IBOutlet NSSecureTextField *textFieldNew;
@property (weak) IBOutlet NSSecureTextField *textFieldConfirm;
@property (weak) IBOutlet NSButton *buttonOk;

@property (weak) IBOutlet NSAdvancedTextField *labelPasswordsMatch;
@property (weak) IBOutlet NSTextField *textFieldTitle;

@property (nonatomic, readonly) NSString* confirmedPassword;
@property (nonatomic) NSString* titleText;

@end
