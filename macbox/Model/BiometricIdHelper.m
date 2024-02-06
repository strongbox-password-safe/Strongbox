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
#import "StrongboxErrorCodes.h"

@interface BiometricIdHelper ()

@property LAContext *inProgressLaContext;

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

- (NSString *)biometricIdName {
    return NSLocalizedString(@"settings_touch_id_name", @"Touch ID");
}

- (BOOL)isWatchUnlockAvailable {
    if(self.dummyMode) {
        return YES;
    }
    
    LAContext *localAuthContext = [[LAContext alloc] init];
    NSError *authError;
    BOOL ret = [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithWatch error:&authError];
    
    
    
    return ret;
}

- (BOOL)isTouchIdUnlockAvailable {
    if(self.dummyMode) {
        return YES;
    }
    
    LAContext *localAuthContext = [[LAContext alloc] init];
    NSError *authError;
    return [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError];
}

- (NSUInteger)getLAPolicy:(BOOL)touch watch:(BOOL)watch {
    if ( touch && watch ) {
        return LAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch;
    }
    
    if ( watch ) {
        return LAPolicyDeviceOwnerAuthenticationWithWatch;
    }
    
    return LAPolicyDeviceOwnerAuthenticationWithBiometrics;
}

- (void)authorize:(MacDatabasePreferences *)database completion:(void (^)(BOOL, NSError *))completion {
    [self authorize:nil database:database completion:completion];
}

- (void)authorize:(NSString *)fallbackTitle database:(MacDatabasePreferences *)database completion:(void (^)(BOOL, NSError *))completion {
    return [self authorize:fallbackTitle reason:nil database:database completion:completion];
}

- (void)authorize:(NSString *)fallbackTitle
           reason:(NSString * _Nullable)reason
         database:(MacDatabasePreferences *)database
       completion:(void (^)(BOOL, NSError *))completion {
    if(self.dummyMode) {
        completion(YES, nil);
        return;
    }
    
    if(self.biometricsInProgress) {
        completion(NO, [Utils createNSError:@"Already a biometrics request in progress, cannot instantiate 2" errorCode:StrongboxErrorCodes.macOSBiometricInProgressOrImpossible]);
        return;
    }
    
    if ( !database.isTouchIdEnabled && !database.isWatchUnlockEnabled ) {
        completion(NO, [Utils createNSError:@"Neither touch nor watch enabled for this database." errorCode:StrongboxErrorCodes.macOSBiometricInProgressOrImpossible]);
        return;
    }
    
    LAContext* lac = [[LAContext alloc] init];
    
    if (fallbackTitle.length == 0) { 
        lac.localizedFallbackTitle = @""; 
    }
    else {
        lac.localizedFallbackTitle = fallbackTitle;
    }
    
    NSString* loc = reason.length ? reason : NSLocalizedString(@"mac_biometrics_identify_to_open_database", @"Unlock Database");
    
    NSError *authError;
    NSUInteger policy = [self getLAPolicy:database.isTouchIdEnabled watch:database.isWatchUnlockEnabled];
    
    if([lac canEvaluatePolicy:policy error:&authError]) {
        self.inProgressLaContext = lac;
        __weak BiometricIdHelper *weakSelf = self;
        
        [self.inProgressLaContext evaluatePolicy:policy
                         localizedReason:loc
                                   reply:^(BOOL success, NSError *error) {
            completion(success, error);
            weakSelf.inProgressLaContext = nil;
        }];
    }
    else {
        NSLog(@"Biometrics is not available on this device");
        NSString* loc = NSLocalizedString(@"mac_biometrics_not_available", @"Biometrics is not available on this device!");
        completion(NO, [Utils createNSError:loc errorCode:24321]);
    }
}

- (BOOL)biometricsInProgress {
    return self.inProgressLaContext != nil;
}

- (void)invalidateCurrentRequest {
    if(self.biometricsInProgress) {
        [self.inProgressLaContext invalidate];
    }
}

@end
