//
//  BiometricsManager.m
//  Strongbox
//
//  Created by Mark on 24/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BiometricsManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SecretStore.h"
#import "AppPreferences.h"

@interface BiometricsManager ()

@property BOOL requestInProgress;
@property NSData* lastKnownGoodDatabaseState;
@property NSData* autoFillLastKnownGoodDatabaseState;

@end

@implementation BiometricsManager

+ (instancetype)sharedInstance {
    static BiometricsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BiometricsManager alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        
        


        
        self.lastKnownGoodDatabaseState = AppPreferences.sharedInstance.lastKnownGoodBiometricsDatabaseState;
        self.autoFillLastKnownGoodDatabaseState = AppPreferences.sharedInstance.autoFillLastKnownGoodBiometricsDatabaseState;
    }
    return self;
}

+ (BOOL)isBiometricIdAvailable {
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if (localAuthContext == nil) {
        return NO;
    }
    
    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    if (error) {
        slog(@"isBiometricIdAvailable: NO -> ");
        [BiometricsManager logBiometricError:error];
        return NO;
    }
    
    return YES;
}

- (NSData*)getLastKnownGoodDatabaseState:(BOOL)autoFill {
    return autoFill ? self.autoFillLastKnownGoodDatabaseState : self.lastKnownGoodDatabaseState;
}

- (BOOL)isBiometricDatabaseStateRecorded:(BOOL)autoFill {
    return [self getLastKnownGoodDatabaseState:autoFill] != nil;
}

- (void)clearBiometricRecordedDatabaseState {
    AppPreferences.sharedInstance.lastKnownGoodBiometricsDatabaseState = nil;
    AppPreferences.sharedInstance.autoFillLastKnownGoodBiometricsDatabaseState = nil;
    
    self.lastKnownGoodDatabaseState = nil;
    self.autoFillLastKnownGoodDatabaseState = nil;
}

- (void)recordBiometricDatabaseState:(BOOL)autoFill {
    LAContext *localAuthContext = [[LAContext alloc] init];
    if (localAuthContext == nil) {
        return;
    }

    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    if (error) {
        slog(@"isBiometricIdChangedSinceEnrolment: NO -> ");
        [BiometricsManager logBiometricError:error];
        return;
    }
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        if(autoFill) {
            self.autoFillLastKnownGoodDatabaseState = localAuthContext.evaluatedPolicyDomainState;
            AppPreferences.sharedInstance.autoFillLastKnownGoodBiometricsDatabaseState = self.autoFillLastKnownGoodDatabaseState;
        }
        else {
            self.lastKnownGoodDatabaseState = localAuthContext.evaluatedPolicyDomainState;
            AppPreferences.sharedInstance.lastKnownGoodBiometricsDatabaseState = self.lastKnownGoodDatabaseState;
        }
    });
}

- (BOOL)isBiometricDatabaseStateHasChanged:(BOOL)autoFill {
    if([self getLastKnownGoodDatabaseState:autoFill] == nil) {
        return NO;
    }
    
    LAContext *localAuthContext = [[LAContext alloc] init];
    if (localAuthContext == nil) {
        return NO;
    }

    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    if (error) {
        slog(@"isBiometricIdChangedSinceEnrolment: NO -> ");
        [BiometricsManager logBiometricError:error];
        return NO;
    }
    
    slog(@"Biometrics State: [%@] vs Last Good: [%@]",
          [localAuthContext.evaluatedPolicyDomainState base64EncodedStringWithOptions:kNilOptions],
          [self.lastKnownGoodDatabaseState base64EncodedStringWithOptions:kNilOptions]);

    return ![localAuthContext.evaluatedPolicyDomainState isEqualToData:[self getLastKnownGoodDatabaseState:autoFill]];
}

+ (void)logBiometricError:(NSError*)error {
    if (error.code == LAErrorAuthenticationFailed) {
        slog(@"BIOMETRIC: Auth Failed %@", error);
    }
    else if (error.code == LAErrorUserFallback) {
        slog(@"BIOMETRIC: User Choose Fallback %@", error);
    }
    else if (error.code == LAErrorUserCancel) {
        slog(@"BIOMETRIC: User Cancelled %@", error);
    }
    else if (error.code == LAErrorBiometryNotAvailable) {
        slog(@"BIOMETRIC: LAErrorBiometryNotAvailable %@", error);
    }
    else if (error.code == LAErrorSystemCancel) {
        slog(@"BIOMETRIC: LAErrorSystemCancel %@", error);
    }
    else if (error.code == LAErrorBiometryNotEnrolled) {
        slog(@"BIOMETRIC: LAErrorBiometryNotEnrolled %@", error);
    }
    else if (error.code == LAErrorBiometryLockout) {
        slog(@"BIOMETRIC: LAErrorBiometryLockout %@", error);
    }
    else {
        slog(@"BIOMETRIC: Unknown Error: [%@]", error);
    }
}

- (NSString *)biometricIdName {
    return [self getBiometricIdName];
}

- (NSString*)getBiometricIdName {
    NSString* biometricIdName = NSLocalizedString(@"settings_touch_id_name", @"Touch ID");
    
    NSError* error;
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        if (localAuthContext.biometryType == LABiometryTypeFaceID ) {
            biometricIdName = NSLocalizedString(@"settings_face_id_name", @"Face ID");
        }
    }
    
    return biometricIdName;
}

- (BOOL)isFaceId {
    NSError* error;
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if([localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        if (localAuthContext.biometryType == LABiometryTypeFaceID ) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)requestBiometricId:(NSString*)reason
                completion:(void(^)(BOOL success, NSError * __nullable error))completion {
    return [self requestBiometricId:reason fallbackTitle:nil completion:completion];
}

- (BOOL)requestBiometricId:(NSString*)reason
             fallbackTitle:(NSString*)fallbackTitle 
                completion:(void(^)(BOOL success, NSError * __nullable error))completion {
    LAContext *localAuthContext = [[LAContext alloc] init];
    
    if(fallbackTitle) {
        localAuthContext.localizedFallbackTitle = fallbackTitle;
    }
    
    
    
    
    
    
    slog(@"REQUEST-BIOMETRIC: %d", AppPreferences.sharedInstance.suppressAppBackgroundTriggers);
    
    if ( self.requestInProgress ) {
        
        slog(@"WARN: WARN: Biometric Request is already in Progress - Not launching again...");
        return NO;
    }
    
    AppPreferences.sharedInstance.suppressAppBackgroundTriggers = YES;
    self.requestInProgress = YES;
    
    [localAuthContext evaluatePolicy:fallbackTitle ? LAPolicyDeviceOwnerAuthenticationWithBiometrics : LAPolicyDeviceOwnerAuthentication
                     localizedReason:reason
                               reply:^(BOOL success, NSError *error) {
                                   self.requestInProgress = NO;
                                   AppPreferences.sharedInstance.suppressAppBackgroundTriggers = NO;

                                   if(!success) {
                                       slog(@"requestBiometricId: Fail -> [%@]", error);
                                       [BiometricsManager logBiometricError:error];
                                   }
                                   else {
                                       slog(@"REQUEST-BIOMETRIC DONE SUCCESS");
                                   }
                                   completion(success, error);
                               }];

    return YES;
}

@end
