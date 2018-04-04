//
//  Alerts.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Alerts.h"

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
    [alert setInformativeText:error.localizedDescription];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert addButtonWithTitle:@"Ok"];

    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(completion) {
            completion();
        }
    }];
}

//+ (NSString *)input: (NSString *)prompt defaultValue: (NSString *)placeHolder {
//    NSAlert *alert = [[NSAlert alloc] init];
//    [alert setMessageText:prompt];
//    
//    [alert addButtonWithTitle:@"Ok"];
//    [alert addButtonWithTitle:@"Cancel"];
//    
//    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
//    [input setStringValue:placeHolder];
//    
//    [alert setAccessoryView:input];
//    NSInteger button = [alert runModal];
//    
//    if (button == NSAlertFirstButtonReturn) {
//        return [input stringValue];
//    } else if (button == NSAlertSecondButtonReturn) {
//        return nil;
//    }
//    
//    return nil;
//}

@end
