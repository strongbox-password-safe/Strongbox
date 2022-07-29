//
//  macOSSpinnerUI.m
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "macOSSpinnerUI.h"
#import "MBProgressHUD.h"

@interface macOSSpinnerUI ()

@property MBProgressHUD *hud;

@end

@implementation macOSSpinnerUI

+ (instancetype)sharedInstance {
    static macOSSpinnerUI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[macOSSpinnerUI alloc] init];
    });
    
    return sharedInstance;
}

- (void)dismiss {
    if ( NSThread.isMainThread ) {
        [self innerDismiss];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self innerDismiss];
        });
    }
}

- (void)show:(NSString *)message viewController:(VIEW_CONTROLLER_PTR)viewController {
    if ( NSThread.isMainThread ) {
        [self show:message view:viewController.view];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self show:message view:viewController.view];
        });
    }
}
- (void)show:(nonnull NSString *)message window:(nonnull NSWindow*)window {
    if ( NSThread.isMainThread ) {
        [self show:message view:window.contentView];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self show:message view:window.contentView];
        });
    }
}

- (void)show:(nonnull NSString *)message view:(NSView*)view {
    if (!message) {
        message = @"";
    }
    if ( NSThread.isMainThread ) {
        [self innerShow:message view:view];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self innerShow:message view:view];
        });
    }
}

- (void)innerDismiss {
    if ( self.hud ) {
        [self.hud hide:YES];
        self.hud = nil;
    }
}

- (void)innerShow:(nonnull NSString *)message view:(NSView*)view {
    if ( view == nil ) {
        view = NSApplication.sharedApplication.keyWindow ? NSApplication.sharedApplication.keyWindow.contentView : NSApplication.sharedApplication.mainWindow.contentView;
        
        if ( view == nil ) {
            view = NSApplication.sharedApplication.windows.firstObject.contentView;
        }
    }
        
    if ( self.hud != nil ) {
        [self innerDismiss];
    }
    
    self.hud = [MBProgressHUD showHUDAddedTo:view animated:YES];

    self.hud.labelText = message;
    self.hud.removeFromSuperViewOnHide = YES;
}

@end
