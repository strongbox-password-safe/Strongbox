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

@end

@implementation Alerts

+ (void)info:(NSString *)info  window:(NSWindow*)window {
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:info];
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert addButtonWithTitle:@"Ok"];
    
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
    [alert addButtonWithTitle:@"Ok"];
    
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(completion) {
            completion();
        }
    }];
}

+ (void)yesNo:(NSString *)info window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion {
    //NSAlert *alert = [NSAlert alertWithMessageText:info defaultButton:@"No" alternateButton:@"Yes" otherButton:nil informativeTextWithFormat:@""];
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:info];
    [alert setAlertStyle:NSAlertStyleInformational];
    
    [alert addButtonWithTitle:@"No"];
    [alert addButtonWithTitle:@"Yes"];
    
    [[[alert buttons] objectAtIndex:0] setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; // ESC
    [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\r"]; // ENTER
    
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        completion(returnCode == NSAlertSecondButtonReturn);
    }];
}

+ (void)error:(NSError*)error window:(NSWindow*)window {
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:error.localizedDescription];
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
    [alert addButtonWithTitle:@"Ok"];

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
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:defaultValue];
    input.delegate=self;
    
    [alert setAccessoryView:input];
    
    [[alert window] setInitialFirstResponder: input];
    
    //[input becomeFirstResponder];
    
    NSInteger button = [alert runModal];
    
    if (button == NSAlertFirstButtonReturn) {
        [input validateEditing];
        return [input stringValue];
    } else if (button == NSAlertSecondButtonReturn) {
        return nil;
    }
    
    return nil;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    //NSLog(@"controlTextDidChange");
    
    NSTextField* textField = (NSTextField*)notification.object;
    
    if(!self.allowEmptyInput && !textField.stringValue.length) {
        textField.placeholderString = @"Field cannot be empty";
    }
    self.okButton.enabled = self.allowEmptyInput || textField.stringValue.length;// ? YES :NO;
}

//- (void)controlTextDidEndEditing:(NSNotification *)notification {
//    NSLog(@"controlTextDidEndEditing");
//}

@end
