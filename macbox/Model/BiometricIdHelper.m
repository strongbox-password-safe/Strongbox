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

- (NSString *)biometricIdName {
    return NSLocalizedString(@"settings_touch_id_name", @"Touch ID");
}

- (BOOL)isWatchUnlockAvailable {
    if(self.dummyMode) {
        return YES;
    }
    
    if ( @available(macOS 10.15, *) ) {
        LAContext *localAuthContext = [[LAContext alloc] init];
        NSError *authError;
        BOOL ret = [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithWatch error:&authError];
        
        
        
        return ret;
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

- (BOOL)convenienceAvailable:(DatabaseMetadata *)database {
    if(self.dummyMode) {
        return YES;
    }

    if ( !database.isTouchIdEnabled && !database.isWatchUnlockEnabled ) {
        return NO;
    }
    
    NSUInteger policy = [self getLAPolicy:database.isTouchIdEnabled watch:database.isWatchUnlockEnabled];
 
    LAContext *localAuthContext = [[LAContext alloc] init];
    NSError *authError;
    return [localAuthContext canEvaluatePolicy:policy error:&authError];
}

- (NSUInteger)getLAPolicy:(BOOL)touch watch:(BOOL)watch {
    if ( @available(macOS 10.15, *) ) {
        if ( touch && watch ) {
            return LAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch;
        }
        
        if ( watch ) {
            return LAPolicyDeviceOwnerAuthenticationWithWatch;
        }
        
        return LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    }
    else { 
        return LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    }
}

- (void)authorize:(DatabaseMetadata *)database completion:(void (^)(BOOL, NSError *))completion {
    [self authorize:nil database:database completion:completion];
}

- (void)authorize:(NSString *)fallbackTitle database:(DatabaseMetadata *)database completion:(void (^)(BOOL, NSError *))completion {
    if(self.dummyMode) {
        completion(YES, nil);
        return;
    }
    
    if(self.biometricsInProgress) {
        completion(NO, [Utils createNSError:@"Already a biometrics request in progress, cannot instantiate 2" errorCode:-2412]);
        return;
    }
    
    if ( !database.isTouchIdEnabled && !database.isWatchUnlockEnabled ) {
        completion(NO, [Utils createNSError:@"Neither touch nor watch enabled for this database." errorCode:-2412]);
        return;
    }
    
    if ( @available (macOS 10.12.1, *)) {
        LAContext *localAuthContext = [[LAContext alloc] init];

        if (fallbackTitle.length) {
            localAuthContext.localizedFallbackTitle = fallbackTitle;
        }
            
        NSString* loc = NSLocalizedString(@"mac_biometrics_identify_to_open_database", @"Identify to Unlock Database");
        
        NSError *authError;
        NSUInteger policy = [self getLAPolicy:database.isTouchIdEnabled watch:database.isWatchUnlockEnabled];
        
        if([localAuthContext canEvaluatePolicy:policy error:&authError]) {
            self.biometricsInProgress = YES;
            
            [localAuthContext evaluatePolicy:policy
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
