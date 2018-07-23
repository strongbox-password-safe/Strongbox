//
//  BiometricIdHelper.m
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BiometricIdHelper.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "Utils.h"

@interface BiometricIdHelper ()

@end

@implementation BiometricIdHelper

+ (instancetype)sharedInstance {
    static BiometricIdHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BiometricIdHelper alloc] init];
    });
    return sharedInstance;
}

- (BOOL)biometricIdAvailable {
    //return YES;
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];
        
        NSError *authError;
        return [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError];
    }
    
    return NO;
}

- (NSString*)biometricIdName {
    NSString* biometricIdName = @"Touch ID";
    
    return biometricIdName;
}

- (void)authorize:(void (^)(BOOL success, NSError *error))completion {
    //completion(YES, nil);
    //return;
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];

        NSError *authError;
        if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError]) {
            [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                             localizedReason:@"Identify to Open Safe"
                                       reply:^(BOOL success, NSError *error) {
                                           completion(success, error);
                                       }];
        }
        else {
            NSLog(@"Biometrics is not available on this device");
            completion(NO, [Utils createNSError:@"Biometrics is not available on this device!" errorCode:24321]);
        }
    }
    else {
        NSLog(@"Biometrics is not available on this device");
        completion(NO, [Utils createNSError:@"Biometrics is not available on this device!" errorCode:24321]);
    }
}

@end
