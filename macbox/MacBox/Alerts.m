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

+ (void)info:(NSString *)info  window:(NSWindow*)window {
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:info];
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert addButtonWithTitle:@"OK"];
    
    [alert beginSheetModalForWindow:window completionHandler:nil];
}

+ (void)info:(NSString *)message
    informativeText:(NSString*)informativeText
            window:(NSWindow*)window
  completion:(void (^)(void))completion; {
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert addButtonWithTitle:@"OK"];
    
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
    
    [alert addButtonWithTitle:@"No"];
    [alert addButtonWithTitle:@"Yes"];
    
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
    
    [alert setMessageText:error ? error.localizedDescription : @"Unknown Error (nil)"];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert addButtonWithTitle:@"OK"];
    
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
    [alert addButtonWithTitle:@"OK"];

    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(completion) {
            completion();
        }
    }];
}

- (NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue allowEmpty:(BOOL)allowEmpty {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:prompt];
    
    self.allowEmptyInput = allowEmpty;
    self.okButton = [alert addButtonWithTitle:@"OK"];
    self.okButton.enabled = self.allowEmptyInput || defaultValue.length;// ? YES :NO;
    
    [alert addButtonWithTitle:@"Cancel"];
    
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
    
    self.okButton = [alert addButtonWithTitle:@"OK"];
    self.okButton.enabled = NO;
    [alert addButtonWithTitle:@"Cancel"];
    
    // Accessory View

    self.checkboxProtected = [[NSButton alloc] initWithFrame:NSMakeRect(40, 0, 100, 30)];
    [self.checkboxProtected setTitle:@"Protected"];
    [self.checkboxProtected setButtonType:NSButtonTypeSwitch];
    self.checkboxProtected.target = self;
    self.checkboxProtected.action = @selector(onCheckboxProtected);
    self.checkboxProtected.state = initProtected ? NSOnState : NSOffState;
    
    NSTextField *keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 77, 295, 16)];
    self.keyTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 75, 295, 24)];
    NSTextField *valueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 35, 295, 16)];
    self.valueTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 33, 295, 24)];
    
    keyLabel.stringValue = @"Key";
    [keyLabel setBezeled:NO];
    [keyLabel setDrawsBackground:NO];
    [keyLabel setEditable:NO];
    [keyLabel setSelectable:NO];
    
    valueLabel.stringValue = @"Value";
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
            textField.placeholderString = @"Field cannot be empty";
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

@end
