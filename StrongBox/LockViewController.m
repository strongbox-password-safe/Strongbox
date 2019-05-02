//
//  LockViewController.m
//  Strongbox
//
//  Created by Mark on 17/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "LockViewController.h"
#import "Settings.h"
#import "InitialViewController.h"
#import "PinEntryController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "IOsUtils.h"
#import "Alerts.h"

@interface LockViewController ()

@end

@implementation LockViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(promptForUnlock)];
    singleTap.numberOfTapsRequired = 1;
    self.logo.userInteractionEnabled = YES;
    [self.logo addGestureRecognizer:singleTap];

    self.buttonTap.hidden = YES;
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.buttonTap.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        self.buttonTap.hidden = NO;
//    });
}

- (IBAction)onUnlock:(id)sender {
    [self promptForUnlock];
}

- (void)promptForUnlock {
    if (Settings.sharedInstance.appLockMode == kBiometric && Settings.isBiometricIdAvailable) {
        [self requestBiometricId];
    }
    else if (Settings.sharedInstance.appLockMode == kPinCode && Settings.sharedInstance.appLockPin != nil) {
        [self requestPinCode];
    }
    else {
        [self unlock]; // Should never happen but lets not get stuck
    }
}

- (void)requestBiometricId {
    [Settings.sharedInstance requestBiometricId:@"Identify to Open Strongbox" completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self unlock];
            });
        }
//        else {
//            if (error.code == LAErrorAuthenticationFailed) {
//                NSLog(@"Failed");
//            }
//            else if (error.code == LAErrorUserFallback)
//            {
//                NSLog(@"Fallback");
//            }
//            else if (error.code != LAErrorUserCancel)
//            {
//                NSLog(@"Cancel");
//            }
//        }
    }];
}
     
- (void)requestPinCode {
    PinEntryController *vc = [[PinEntryController alloc] init];
    vc.info = @"Please enter your PIN to Unlock Strongbox";
    vc.pinLength = Settings.sharedInstance.appLockPin.length;
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if(response == kOk) {
            if([pin isEqualToString:Settings.sharedInstance.appLockPin]) {
                [self unlock];
            }
            else {
                [Alerts warn:self title:@"Incorrect PIN" message:@"The PIN you entered was incorrect."];
            }
        }
        
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)unlock {
    self.onUnlockSuccessful();
}

@end
