//
//  IOSAlertingUI.m
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "IOSAlertingUI.h"
#import "Alerts.h"

@implementation IOSAlertingUI

+ (instancetype)sharedInstance {
    static IOSAlertingUI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[IOSAlertingUI alloc] init];
    });
    
    return sharedInstance;
}

- (void)error:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title error:(nonnull const NSError *)error completion:(nonnull void (^)(void))completion {
    [Alerts error:parentUiElement title:title error:error completion:completion];
}

- (void)twoOptionsWithCancel:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message defaultButtonText:(nonnull NSString *)defaultButtonText secondButtonText:(nonnull NSString *)secondButtonText action:(nonnull void (^)(int))action {
    [Alerts twoOptionsWithCancel:parentUiElement title:title message:message defaultButtonText:defaultButtonText secondButtonText:secondButtonText action:action];
}

- (void)warn:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message {
    [Alerts warn:parentUiElement title:title message:message];
}

- (void)warn:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message completion:(nonnull void (^)(void))completion {
    [Alerts warn:parentUiElement title:title message:message completion:completion];
}

- (void)areYouSure:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement message:(nonnull NSString *)message action:(nonnull void (^)(BOOL))action {
    [Alerts areYouSure:parentUiElement message:message action:action];
}
    
- (void)error:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement error:(nonnull const NSError *)error completion:(nonnull void (^)(void))completion {
    [Alerts error:parentUiElement error:error completion:completion];
}

- (void)info:(nonnull PARENT_UI_ELEMENT_PTR)parentUiElement title:(nonnull NSString *)title message:(nonnull NSString *)message completion:(void (^)(void))completion {
    [Alerts info:parentUiElement title:title message:message completion:completion];
}

@end
