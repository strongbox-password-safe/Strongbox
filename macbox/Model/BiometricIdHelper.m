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
#import "Settings.h"

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
        
        
        BOOL ret = [localAuthContext canEvaluatePolicy:[self getLAPolicy] error:&authError];
        
        NSLog(@"DEBUG: Biometric available: [%d][%@]", ret, authError);
        
        return ret;
    }
    
    return NO;
}

- (BOOL)isWatchUnlockAvailable {
    if(self.dummyMode) {
        return YES;
    }
    
    if ( @available(macOS 10.15, *) ) {
        LAContext *localAuthContext = [[LAContext alloc] init];
        NSError *authError;
        return [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithWatch error:&authError];
    }
    
    return NO;
}

- (BOOL)isTouchIdUnlockAvailable {
    if(self.dummyMode) {
        return YES;
    }
    
    if ( @available (macOS 10.12.2, *) ) {
        LAContext *localAuthContext = [[LAContext alloc] init];
        NSError *authError;
        return [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError];
    }
    
    return NO;
}

- (NSUInteger)getLAPolicy {
    if ( @available(macOS 10.15, *) ) {
        return Settings.sharedInstance.allowWatchUnlock ? LAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch : LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    }
    else {
        return LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    }
}

- (NSString*)biometricIdName {
    NSString* loc = NSLocalizedString(@"settings_touch_id_name", @"Touch ID");
    NSString* biometricIdName = loc;
    return biometricIdName;
}

- (void)authorize:(void (^)(BOOL success, NSError *error))completion {
    [self authorize:nil completion:completion];
}

- (void)authorize:(NSString *)fallbackTitle completion:(void (^)(BOOL, NSError *))completion {
    if(self.dummyMode) {
        completion(YES, nil);
        return;
    }
    
    if(self.biometricsInProgress) {
        completion(NO, [Utils createNSError:@"Already a biometrics request in progress, cannot instantiate 2" errorCode:-2412]);
        return;
    }
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];

        if (fallbackTitle.length) {
            localAuthContext.localizedFallbackTitle = fallbackTitle;
        }
            
        NSString* loc = NSLocalizedString(@"mac_biometrics_identify_to_open_database", @"Identify to Unlock Database");
        
        NSError *authError;
        if([localAuthContext canEvaluatePolicy:[self getLAPolicy] error:&authError]) {
            self.biometricsInProgress = YES;
            
            [localAuthContext evaluatePolicy:[self getLAPolicy]
                             localizedReason:loc
                                       reply:^(BOOL success, NSError *error) {
                                           completion(success, error);
                                           self.biometricsInProgress = NO;
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
