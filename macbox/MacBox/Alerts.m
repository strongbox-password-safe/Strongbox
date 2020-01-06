//
//  Alerts.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Alerts.h"

@interface Alerts ()

@property (nonatomic, strong) NSButton* okButton;
@property (nonatomic) BOOL allowEmptyInput;
@property NSTextField* simpleInputTextField;
@property NSTextField* keyTextField;
@property NSTextField* valueTextField;
@property NSButton* checkboxProtected;

@end

@implementation Alerts

+ (void)info:(NSString *)info
      window:(NSWindow*)window {
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:info];
    [alert setAlertStyle:NSAlertStyleInformational];
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    [alert addButtonWithTitle:loc];
    
    [alert beginSheetModalForWindow:window completionHandler:nil];
}

+ (void)info:(NSString *)message
informativeText:(NSString*)informativeText
      window:(NSWindow*)window
  completion:(void (^)(void))completion {
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSAlertStyleInformational];
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    [alert addButtonWithTitle:loc];
    
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(completion) {
            completion();
        }
    }];
}

+ (void)yesNo:(NSString *)messageText informativeText:(NSString*)informativeText window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion {
    NSAlert *alert = [[NSAlert alloc] init];
    
    if (informativeText) [alert setInformativeText:informativeText];
    if (messageText) [alert setMessageText:messageText];
    
    [alert setAlertStyle:NSAlertStyleInformational];
    
    NSString* loc = NSLocalizedString(@"alerts_no", @"No");
    [alert addButtonWithTitle:loc];
    NSString* loc2 = NSLocalizedString(@"alerts_yes", @"Yes");
    [alert addButtonWithTitle:loc2];
    
    [[[alert buttons] objectAtIndex:0] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; // ESC
    [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\r"]; // ENTER
    
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        completion(returnCode == NSAlertSecondButtonReturn);
    }];
}

+ (void)yesNo:(NSString *)info window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion {
    [Alerts yesNo:info informativeText:nil window:window completion:completion];
}

+ (void)error:(NSError*)error window:(NSWindow*)window {
    NSAlert *alert = [[NSAlert alloc] init];

    NSString* loc = NSLocalizedString(@"alerts_unknown_error", @"Unknown Error");
    [alert setMessageText:error ? error.localizedDescription : loc];
    [alert setAlertStyle:NSAlertStyleWarning];
    
    NSString* loc2 = NSLocalizedString(@"alerts_ok", @"OK");
    [alert addButtonWithTitle:loc2];
    
    [alert beginSheetModalForWindow:window completionHandler:nil];
}

+ (void)error:(NSString*)message error:(NSError*)error window:(NSWindow*)window {
    [Alerts error:message error:error window:window completion:nil];
}

+ (void)error:(NSString*)message error:(NSError*)error window:(NSWindow*)window completion:(void (^)(void))completion {
    NSAlert *alert = [[NSAlert alloc] init];

    [alert setMessageText:message];
    
    if(error && error.localizedDescription) {
        [alert setInformativeText:error.localizedDescription];
    }
    
    [alert setAlertStyle:NSAlertStyleWarning];
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    [alert addButtonWithTitle:loc];

    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(completion) {
            completion();
        }
    }];
}

- (NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue allowEmpty:(BOOL)allowEmpty {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:prompt];
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    self.okButton = [alert addButtonWithTitle:loc];
    self.okButton.enabled = self.allowEmptyInput || defaultValue.length;// ? YES :NO;

    NSString* loc2 = NSLocalizedString(@"generic_cancel", @"Cancel");
    [alert addButtonWithTitle:loc2];
    
    self.simpleInputTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [self.simpleInputTextField setStringValue:defaultValue];
    self.simpleInputTextField.delegate=self;
    
    [alert setAccessoryView:self.simpleInputTextField];
    
    [[alert window] setInitialFirstResponder: self.simpleInputTextField];
    
    //[input becomeFirstResponder];
    
    NSInteger button = [alert runModal];
    
    if (button == NSAlertFirstButtonReturn) {
        [self.simpleInputTextField validateEditing];
        return [self.simpleInputTextField stringValue];
    } else if (button == NSAlertSecondButtonReturn) {
        return nil;
    }
    
    return nil;
}

- (void)inputKeyValue:(NSString*)prompt
              initKey:(NSString*)initKey
            initValue:(NSString*)initValue
        initProtected:(BOOL)initProtected
          placeHolder:(BOOL)placeHolder
           completion:(void (^)(BOOL yesNo, NSString* key, NSString* value, BOOL protected))completion {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:prompt];
    //alert.informativeText = @"Informative?";
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    self.okButton = [alert addButtonWithTitle:loc];
    self.okButton.enabled = NO;
    
    NSString* loc2 = NSLocalizedString(@"generic_cancel", @"Cancel");
    [alert addButtonWithTitle:loc2];
    
    // Accessory View

    self.checkboxProtected = [[NSButton alloc] initWithFrame:NSMakeRect(40, 0, 100, 30)];
    
    NSString* loc3 = NSLocalizedString(@"mac_alerts_input_custom_field_protected_checkbox", @"Protected");
    [self.checkboxProtected setTitle:loc3];
    [self.checkboxProtected setButtonType:NSButtonTypeSwitch];
    self.checkboxProtected.target = self;
    self.checkboxProtected.action = @selector(onCheckboxProtected);
    self.checkboxProtected.state = initProtected ? NSOnState : NSOffState;
    
    NSTextField *keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 77, 295, 16)];
    self.keyTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 75, 295, 24)];
    NSTextField *valueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 35, 295, 16)];
    self.valueTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 33, 295, 24)];

    NSString* loc4 = NSLocalizedString(@"mac_alerts_input_custom_field_label_key", @"Key");
    keyLabel.stringValue = loc4;
    [keyLabel setBezeled:NO];
    [keyLabel setDrawsBackground:NO];
    [keyLabel setEditable:NO];
    [keyLabel setSelectable:NO];

    NSString* loc5 = NSLocalizedString(@"mac_alerts_input_custom_field_label_value", @"Value");
    valueLabel.stringValue = loc5;
    [valueLabel setBezeled:NO];
    [valueLabel setDrawsBackground:NO];
    [valueLabel setEditable:NO];
    [valueLabel setSelectable:NO];

    self.keyTextField.delegate = self;
    self.valueTextField.delegate = self;
    self.keyTextField.nextKeyView = self.valueTextField;
    self.valueTextField.nextKeyView = self.keyTextField;

    if(placeHolder) {
        self.keyTextField.placeholderString = initKey;
        self.valueTextField.placeholderString = initValue;
    }
    else {
        self.keyTextField.stringValue = initKey;
        self.valueTextField.stringValue = initValue;
    }
    
    NSStackView *stackViewer = [[NSStackView alloc] initWithFrame:NSMakeRect(0,0, 295, 100)];

    [stackViewer addSubview:keyLabel];
    [stackViewer addSubview:self.keyTextField];

    [stackViewer addSubview:valueLabel];
    [stackViewer addSubview:self.valueTextField];

    [stackViewer addSubview:self.checkboxProtected];
    
    alert.accessoryView = stackViewer;
    
    [[alert window] setInitialFirstResponder:self.keyTextField];
    
    NSInteger button = [alert runModal];
    
    completion((button == NSAlertFirstButtonReturn), self.keyTextField.stringValue, self.valueTextField.stringValue, self.checkboxProtected.state == NSOnState);
}

- (void)controlTextDidChange:(NSNotification *)notification {
    //NSLog(@"controlTextDidChange");
    
    NSTextField* textField = (NSTextField*)notification.object;
    
    if(textField == self.simpleInputTextField) {
        if(!self.allowEmptyInput && !textField.stringValue.length) {
            NSString* loc = NSLocalizedString(@"mac_alerts_field_cannot_be_empty", @"Field cannot be empty");
            textField.placeholderString = loc;
        }
        self.okButton.enabled = self.allowEmptyInput || textField.stringValue.length;
    }
    else {
        self.okButton.enabled = self.keyTextField.stringValue.length;
    }
}

- (void)onCheckboxProtected {
    self.okButton.enabled = self.keyTextField.stringValue.length;
}


+ (void)twoOptionsWithCancel:(NSString *)messageText
             informativeText:(NSString*)informativeText
           option1AndDefault:(NSString*)option1AndDefault
                     option2:(NSString*)option2
                      window:(NSWindow*)window
                  completion:(void (^)(NSUInteger zeroForCancel))completion {
    NSAlert *alert = [[NSAlert alloc] init];
    
    if (informativeText) [alert setInformativeText:informativeText];
    if (messageText) [alert setMessageText:messageText];
    
    [alert setAlertStyle:NSAlertStyleInformational];
    
    NSString* localizedCancel = NSLocalizedString(@"generic_cancel", @"Cancel");
    [alert addButtonWithTitle:localizedCancel];
    [[[alert buttons] objectAtIndex:0] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; // ESC
    
    [alert addButtonWithTitle:option1AndDefault];
    [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\r"]; // ENTER
    
    [alert addButtonWithTitle:option2];
        
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        completion(returnCode - NSAlertFirstButtonReturn);
    }];
}

@end
