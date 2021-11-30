//
//  MacOSAlertingUI.m
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacOSAlertingUI.h"
#import "MacAlerts.h"

@implementation MacOSAlertingUI

+ (instancetype)sharedInstance {
    static MacOSAlertingUI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MacOSAlertingUI alloc] init];
    });
    
    return sharedInstance;
}

- (void)areYouSure:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement message:(nonnull NSString *)message action:(nonnull void (^)(BOOL))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts areYouSure:message window:parentUiElement.view.window completion:action];
    });
}

- (void)error:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement error:(nonnull const NSError *)error completion:(nonnull void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts error:error window:parentUiElement.view.window completion:completion];
    });
}

- (void)error:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title error:(nonnull const NSError *)error completion:(nonnull void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts error:title error:error window:parentUiElement.view.window];
    });
}

- (void)info:(PARENT_UI_ELEMENT_PTR)parentUiElement title:(NSString *)title message:(NSString *)message completion:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts info:title informativeText:message window:parentUiElement.view.window completion:completion];
    });
}

- (void)twoOptionsWithCancel:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message defaultButtonText:(nonnull NSString *)defaultButtonText secondButtonText:(nonnull NSString *)secondButtonText action:(nonnull void (^)(int))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts twoOptionsWithCancel:title informativeText:message option1AndDefault:defaultButtonText option2:secondButtonText window:parentUiElement.view.window completion:action];
    });
}

- (void)warn:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts info:title informativeText:message window:parentUiElement.view.window completion:nil];
    });
}

- (void)warn:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message completion:(nonnull void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts info:title informativeText:message window:parentUiElement.view.window completion:completion];
    });
}

@end
