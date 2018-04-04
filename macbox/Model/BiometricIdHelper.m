//
//  BiometricIdHelper.m
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BiometricIdHelper.h"
#import <LocalAuthentication/LocalAuthentication.h>

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
    return YES;
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];
        
        NSError *authError;
        return [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError];
    }
    
    return NO;
}

- (NSString*)biometricIdName {
    NSString* biometricIdName = @"Touch ID";
    
    //    if ( @available (macOS 10.12.1, *)) {
    //        LAContext *localAuthContext = [[LAContext alloc] init];
    //
    //        NSError *authError;
    //        if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError]) {
    //            if (@available(macOS 10.13.2, *)) {
    //                if (localAuthContext.biometryType == LABiometryTypeFaceID ) {
    //                    biometricIdName = @"Face ID";
    //                }
    //            } else {
    //                // Fallback on earlier versions
    //            }
    //        }
    //    }
    
    return biometricIdName;
}


//            LAContext *localAuthContext = [[LAContext alloc] init];
//
//            NSError *authError;
//            if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError]) {
//                [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
//                                 localizedReason:@"Identify to login"
//                                           reply:^(BOOL success, NSError *error) {
//                                               if (success) {
//                                                   // User authenticated successfully, take appropriate action
//                                               }
//                                               else {
//                                                   // User did not authenticate successfully, look at error and take appropriate action
//                                               }
//                                               NSLog(@"%hhd - %@", success, error);
//                                           }];

@end
