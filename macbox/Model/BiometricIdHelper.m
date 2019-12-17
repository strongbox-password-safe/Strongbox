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
    if(self.dummyMode) {
        return YES;
    }
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];
        
        NSError *authError;
        return [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError];
    }
    
    return NO;
}

- (NSString*)biometricIdName {
    NSString* loc = NSLocalizedString(@"settings_touch_id_name", @"Touch ID");
    NSString* biometricIdName = loc;
    return biometricIdName;
}

- (void)authorize:(void (^)(BOOL success, NSError *error))completion {
    if(self.dummyMode) {
        completion(YES, nil);
        return;
    }
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];

        NSString* loc = NSLocalizedString(@"mac_biometrics_identify_to_open_database", @"Identify to Open Database");
        
        NSError *authError;
        if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError]) {
            [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                             localizedReason:loc
                                       reply:^(BOOL success, NSError *error) {
                                           completion(success, error);
                                       }];
        }
        else {
            NSLog(@"Biometrics is not available on this device");
            NSString* loc = NSLocalizedString(@"mac_biometrics_not_available", @"Biometrics is not available on this device!");
            completion(NO, [Utils createNSError:loc errorCode:24321]);
        }
    }
    else {
        NSLog(@"Biometrics is not available on this device");
        NSString* loc = NSLocalizedString(@"mac_biometrics_not_available", @"Biometrics is not available on this device!");
        completion(NO, [Utils createNSError:loc errorCode:24321]);
    }
}

@end
