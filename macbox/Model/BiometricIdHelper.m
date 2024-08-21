//
//  BiometricIdHelper.m
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BiometricIdHelper.h"
#import "Utils.h"
#import "Settings.h"
#import "StrongboxErrorCodes.h"

@interface BiometricIdHelper ()

@property LAContext *inProgressLaContext;

@property NSData* lastKnownGoodDatabaseState;
@property NSData* autoFillLastKnownGoodDatabaseState;

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

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lastKnownGoodDatabaseState = Settings.sharedInstance.lastKnownGoodBiometricsDatabaseState;
        self.autoFillLastKnownGoodDatabaseState = Settings.sharedInstance.autoFillLastKnownGoodBiometricsDatabaseState;
    }
    return self;
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

- (LAPolicy)getPolicyForDatabase:(MacDatabasePreferences*)database {
    return [self getLAPolicy:database.isTouchIdEnabled watch:database.isWatchUnlockEnabled];
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
    NSUInteger policy = [self getPolicyForDatabase:database];
    
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
        slog(@"Biometrics is not available on this device");
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

- (NSData*)getLastKnownGoodDatabaseState:(BOOL)autoFill {
    return autoFill ? self.autoFillLastKnownGoodDatabaseState : self.lastKnownGoodDatabaseState;
}

- (void)clearBiometricRecordedDatabaseState {
    Settings.sharedInstance.lastKnownGoodBiometricsDatabaseState = nil;
    Settings.sharedInstance.autoFillLastKnownGoodBiometricsDatabaseState = nil;
    
    self.lastKnownGoodDatabaseState = nil;
    self.autoFillLastKnownGoodDatabaseState = nil;
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
        [BiometricIdHelper logBiometricError:error];
        return NO;
    }
    
    slog(@"Biometrics State: [%@] vs Last Good: [%@]",
         [localAuthContext.evaluatedPolicyDomainState base64EncodedStringWithOptions:kNilOptions],
         [self.lastKnownGoodDatabaseState base64EncodedStringWithOptions:kNilOptions]);
    
    return ![localAuthContext.evaluatedPolicyDomainState isEqualToData:[self getLastKnownGoodDatabaseState:autoFill]];
}


- (BOOL)isBiometricDatabaseStateRecorded:(BOOL)autoFill {
    return [self getLastKnownGoodDatabaseState:autoFill] != nil;
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
        [BiometricIdHelper logBiometricError:error];
        return;
    }
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        if(autoFill) {
            self.autoFillLastKnownGoodDatabaseState = localAuthContext.evaluatedPolicyDomainState;
            Settings.sharedInstance.autoFillLastKnownGoodBiometricsDatabaseState = self.autoFillLastKnownGoodDatabaseState;
        }
        else {
            self.lastKnownGoodDatabaseState = localAuthContext.evaluatedPolicyDomainState;
            Settings.sharedInstance.lastKnownGoodBiometricsDatabaseState = self.lastKnownGoodDatabaseState;
        }
    });
}

@end
