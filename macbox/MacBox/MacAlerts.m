//
//  Alerts.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "MacAlerts.h"

@interface MacAlerts ()

@property (nonatomic, strong) NSButton* okButton;
@property (nonatomic) BOOL allowEmptyInput;
@property NSTextField* simpleInputTextField;
@property NSTextField* keyTextField;
@property NSTextField* valueTextField;
@property NSButton* checkboxProtected;

@end

@implementation MacAlerts

+ (void)info:(NSString *)info
      window:(NSWindow*)window {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:info];
        [alert setAlertStyle:NSAlertStyleInformational];
        
        NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
        [alert addButtonWithTitle:loc];
        
        [alert beginSheetModalForWindow:window completionHandler:nil];
    });
}

+ (void)info:(NSString *)message
informativeText:(NSString*)informativeText
      window:(NSWindow*)window
  completion:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
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
    });
}

+ (void)areYouSure:(NSString *)message window:(NSWindow *)window completion:(void (^)(BOOL))completion {
    [MacAlerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
     informativeText:message
              window:window
          completion:completion];
    
}

+ (void)yesNo:(NSString *)messageText informativeText:(NSString*)informativeText
       window:(NSWindow*)window
   completion:(void (^)(BOOL yesNo))completion {
    [self yesNo:messageText informativeText:informativeText window:window disableEscapeKey:NO completion:completion];
}

+ (void)yesNo:(NSString *)messageText
informativeText:(NSString*)informativeText
       window:(NSWindow*)window
disableEscapeKey:(BOOL)disableEscapeKey
   completion:(void (^)(BOOL yesNo))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        if (informativeText) [alert setInformativeText:informativeText];
        if (messageText) [alert setMessageText:messageText];
        
        [alert setAlertStyle:NSAlertStyleInformational];
        
        NSString* yes = NSLocalizedString(@"alerts_yes", @"Yes");
        [alert addButtonWithTitle:yes];
        
        NSString* no = NSLocalizedString(@"alerts_no", @"No");
        [alert addButtonWithTitle:no];
        
        if (!disableEscapeKey) {
            [[[alert buttons] objectAtIndex:1] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; 
        }
        
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"]; 
        
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            completion(returnCode == NSAlertFirstButtonReturn);
        }];
    });
}

+ (void)yesNo:(NSString *)info window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion {
    [self yesNo:info informativeText:nil window:window completion:completion];
}

+ (void)error:(NSError*)error window:(NSWindow*)window {
    [self error:error window:window completion:nil];
}

+ (void)error:(const NSError*)error window:(NSWindow*)window completion:(void (^)(void))completion {
    NSString* loc2 = NSLocalizedString(@"alerts_unknown_error", @"Unknown Error");
    NSString* loc = error.domain.description.length ? error.domain.description : loc2;
    
    [self error:loc error:error window:window completion:completion];
}

+ (void)error:(NSString*)message error:(NSError*)error window:(NSWindow*)window {
    [self error:message error:error window:window completion:nil];
}

+ (void)error:(NSString*)message error:(NSError*)error window:(NSWindow*)window completion:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:message];
        
        if(error && error.localizedDescription) {
            [alert setInformativeText: [NSString stringWithFormat:@"[%ld] %@", error.code, error.localizedDescription]];
        }
        
        [alert setAlertStyle:NSAlertStyleWarning];
        
        NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
        [alert addButtonWithTitle:loc];
        
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            if(completion) {
                completion();
            }
        }];
    });
}

- (NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue allowEmpty:(BOOL)allowEmpty {
    return [self input:prompt defaultValue:defaultValue allowEmpty:allowEmpty secure:NO];
}

- (NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue allowEmpty:(BOOL)allowEmpty secure:(BOOL)secure {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:prompt];
    
    self.allowEmptyInput = allowEmpty;
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    self.okButton = [alert addButtonWithTitle:loc];
    self.okButton.enabled = self.allowEmptyInput || defaultValue.length;

    NSString* loc2 = NSLocalizedString(@"generic_cancel", @"Cancel");
    [alert addButtonWithTitle:loc2];
    
    self.simpleInputTextField = secure ? [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] : [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [self.simpleInputTextField setStringValue:defaultValue];
    
    self.simpleInputTextField.delegate=self;
    
    [alert setAccessoryView:self.simpleInputTextField];
    
    [[alert window] setInitialFirstResponder: self.simpleInputTextField];
    
    
    
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
    
    
    NSString* loc = NSLocalizedString(@"alerts_ok", @"OK");
    self.okButton = [alert addButtonWithTitle:loc];
    self.okButton.enabled = NO;
    
    NSString* loc2 = NSLocalizedString(@"generic_cancel", @"Cancel");
    [alert addButtonWithTitle:loc2];
    
    

    self.checkboxProtected = [[NSButton alloc] initWithFrame:NSMakeRect(40, 0, 100, 30)];
    
    NSString* loc3 = NSLocalizedString(@"mac_alerts_input_custom_field_protected_checkbox", @"Protected");
    [self.checkboxProtected setTitle:loc3];
    [self.checkboxProtected setButtonType:NSButtonTypeSwitch];
    self.checkboxProtected.target = self;
    self.checkboxProtected.action = @selector(onCheckboxProtected);
    self.checkboxProtected.state = initProtected ? NSControlStateValueOn : NSControlStateValueOff;
    
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger button = [alert runModal];
        
        completion((button == NSAlertFirstButtonReturn), self.keyTextField.stringValue, self.valueTextField.stringValue, self.checkboxProtected.state == NSControlStateValueOn);
    });
}

- (void)controlTextDidChange:(NSNotification *)notification {
    
    
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

+ (void)twoOptions:(NSString *)messageText
   informativeText:(NSString*)informativeText
 option1AndDefault:(NSString*)option1AndDefault
           option2:(NSString*)option2
            window:(NSWindow*)window
        completion:(void (^)(NSUInteger option))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        if (informativeText) [alert setInformativeText:informativeText];
        if (messageText) [alert setMessageText:messageText];
        
        [alert setAlertStyle:NSAlertStyleInformational];
        
        [alert addButtonWithTitle:option1AndDefault];
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"]; 
        
        [alert addButtonWithTitle:option2];
        
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSAlertFirstButtonReturn) {
                completion(1);
            }
            else {
                completion(2);
            }
        }];
    });
}

+ (void)threeOptions:(NSString *)messageText
     informativeText:(NSString *)informativeText
   option1AndDefault:(NSString *)option1AndDefault
             option2:(NSString *)option2
             option3:(NSString *)option3
              window:(NSWindow *)window
          completion:(void (^)(NSUInteger))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        if (informativeText) [alert setInformativeText:informativeText];
        if (messageText) [alert setMessageText:messageText];
        
        [alert setAlertStyle:NSAlertStyleInformational];
        
        [alert addButtonWithTitle:option1AndDefault];
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"]; 
        
        [alert addButtonWithTitle:option2];
        [alert addButtonWithTitle:option3];

        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSAlertFirstButtonReturn) {
                completion(1);
            }
            else if ( returnCode == NSAlertSecondButtonReturn ) {
                completion(2);
            }
            else {
                completion(3);
            }
        }];
    });
}

+ (void)threeOptionsWithCancel:(NSString *)messageText
               informativeText:(NSString *)informativeText
             option1AndDefault:(NSString *)option1AndDefault
                       option2:(NSString *)option2
                       option3:(NSString *)option3
                        window:(NSWindow *)window
                    completion:(void (^)(NSUInteger))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        if (informativeText) [alert setInformativeText:informativeText];
        if (messageText) [alert setMessageText:messageText];
        
        [alert setAlertStyle:NSAlertStyleInformational];
        
        [alert addButtonWithTitle:option1AndDefault];
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"]; 
        
        [alert addButtonWithTitle:option2];
        [alert addButtonWithTitle:option3];

        NSString* localizedCancel = NSLocalizedString(@"generic_cancel", @"Cancel");
        [alert addButtonWithTitle:localizedCancel];
        [[[alert buttons] objectAtIndex:3] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; 

        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSAlertFirstButtonReturn) {
                completion(1);
            }
            else if ( returnCode == NSAlertSecondButtonReturn ) {
                completion(2);
            }
            else if ( returnCode == NSAlertThirdButtonReturn ) {
                completion(3);
            }
            else {
                completion(0);
            }
        }];
    });
}

+ (void)twoOptionsWithCancel:(NSString *)messageText
             informativeText:(NSString*)informativeText
           option1AndDefault:(NSString*)option1AndDefault
                     option2:(NSString*)option2
                      window:(NSWindow*)window
                  completion:(void (^)(int response))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        if (informativeText) [alert setInformativeText:informativeText];
        if (messageText) [alert setMessageText:messageText];
        
        [alert setAlertStyle:NSAlertStyleInformational];
        
        [alert addButtonWithTitle:option1AndDefault];
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"]; 
        
        [alert addButtonWithTitle:option2];
        
        NSString* localizedCancel = NSLocalizedString(@"generic_cancel", @"Cancel");
        [alert addButtonWithTitle:localizedCancel];
        [[[alert buttons] objectAtIndex:2] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; 
        
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSAlertThirdButtonReturn) {
                completion(3); 
            }
            else if(returnCode == NSAlertFirstButtonReturn) {
                completion(0); 
            }
            else {
                completion(1); 
            }
        }];
    });
}

+ (void)customOptionWithCancel:(NSString *)messageText
               informativeText:(NSString*)informativeText
             option1AndDefault:(NSString*)option1AndDefault
                        window:(NSWindow*)window
                    completion:(void (^)(BOOL go))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        if (informativeText) [alert setInformativeText:informativeText];
        if (messageText) [alert setMessageText:messageText];
        
        [alert setAlertStyle:NSAlertStyleInformational];
        
        [alert addButtonWithTitle:option1AndDefault];
        [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"]; 
            
        NSString* localizedCancel = NSLocalizedString(@"generic_cancel", @"Cancel");
        [alert addButtonWithTitle:localizedCancel];
        [[[alert buttons] objectAtIndex:1] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; 
        
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSAlertFirstButtonReturn) {
                completion(YES);
            }
            else {
                completion(NO);
            }
        }];
    });
}

@end
