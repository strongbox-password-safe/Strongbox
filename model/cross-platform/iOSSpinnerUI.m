//
//  SpinnerUI.m
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "iOSSpinnerUI.h"
#import "SVProgressHUD.h"

@implementation iOSSpinnerUI

+ (instancetype)sharedInstance {
    static iOSSpinnerUI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[iOSSpinnerUI alloc] init];
    });
    
    return sharedInstance;
}

- (void)dismiss {
    if ( NSThread.isMainThread ) {
        [SVProgressHUD dismiss];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    }
}

- (void)show:(NSString *)message viewController:(VIEW_CONTROLLER_PTR)viewController {
    if ( NSThread.isMainThread ) {
        [SVProgressHUD showWithStatus:message]; 
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:message]; 
        });
    }
}

@end
