//
//  MacCompositeKeyDeterminer.m
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacCompositeKeyDeterminer.h"
#import "Settings.h"
#import "BiometricIdHelper.h"
#import "ManualCredentialsEntry.h"
#import "MacHardwareKeyManager.h"
#import "Utils.h"
#import "WorkingCopyManager.h"
#import "Serializator.h"
#import "KeyFileParser.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "StrongboxErrorCodes.h"
#import "AutoFillLoadingVC.h"

@interface MacCompositeKeyDeterminer ()

@property (nonnull) NSViewController* viewController;
@property (nonnull) METADATA_PTR database;
@property BOOL isAutoFillOpen;
@property BOOL isAutoFillQuickTypeOpen;
@property (readonly, nullable) NSString* contextAwareKeyFileBookmark;

@end

@implementation MacCompositeKeyDeterminer

+ (instancetype)determinerWithViewController:(NSViewController*)viewController
                                    database:(METADATA_PTR)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen {
    return [MacCompositeKeyDeterminer determinerWithViewController:viewController database:database isAutoFillOpen:isAutoFillOpen isAutoFillQuickTypeOpen:NO];
}

+ (instancetype)determinerWithViewController:(NSViewController*)viewController
                                    database:(METADATA_PTR)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen
                     isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen {
    return [[MacCompositeKeyDeterminer alloc] initWithViewController:viewController
                                                         database:database
                                                      isAutoFillOpen:isAutoFillOpen
                                             isAutoFillQuickTypeOpen:isAutoFillQuickTypeOpen];

}

- (instancetype)initWithViewController:(NSViewController*)viewController
                              database:(METADATA_PTR)database
                        isAutoFillOpen:(BOOL)isAutoFillOpen
               isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen {
    self = [super init];
    
    if (self) {
        self.viewController = viewController;
        self.database = database;
        self.isAutoFillOpen = isAutoFillOpen;
        self.isAutoFillQuickTypeOpen = isAutoFillQuickTypeOpen;
    }
    
    return self;
}

- (void)getCkfs:(CompositeKeyDeterminedBlock)completion {
    if ( self.bioOrWatchUnlockIsPossible ) {
        NSLog(@"MacCompositeKeyDeterminer::getCkfs. Convenience Possible...");
        [self getCkfsWithBiometrics:self.contextAwareKeyFileBookmark
               yubiKeyConfiguration:self.database.yubiKeyConfiguration
                      allowFallback:YES
                         completion:completion];
    }
    else {
        NSLog(@"MacCompositeKeyDeterminer::getCkfs. Convenience Possible...");
        [self getCkfsManually:completion];
    }
}

- (void)getCkfsManually:(CompositeKeyDeterminedBlock)completion {
    NSLog(@"MacCompositeKeyDeterminer::getCkfsManually...");

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _getCkfsWithManualUnlock:completion];
    });
}

- (void)getCkfsWithBiometrics:(NSString *)keyFileBookmark
         yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                   completion:(CompositeKeyDeterminedBlock)completion {
    [self getCkfsWithBiometrics:keyFileBookmark yubiKeyConfiguration:yubiKeyConfiguration allowFallback:NO completion:completion];
}

- (void)getCkfsWithBiometrics:(NSString *)keyFileBookmark
         yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                allowFallback:(BOOL)allowFallback
                   completion:(CompositeKeyDeterminedBlock)completion {
    NSLog(@"MacCompositeKeyDeterminer::getCkfsWithBiometrics...");

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _getCkfsWithBiometrics:keyFileBookmark yubiKeyConfiguration:yubiKeyConfiguration allowFallback:allowFallback completion:completion];
    });
}

- (void)_getCkfsWithManualUnlock:(CompositeKeyDeterminedBlock)completion {
    ManualCredentialsEntry* mce = [[ManualCredentialsEntry alloc] initWithNibName:@"ManualCredentialsEntry" bundle:nil];
    mce.databaseUuid = self.database.uuid;
    mce.isAutoFillOpen = self.isAutoFillOpen;
    
    mce.onDone = ^(BOOL userCancelled, NSString * _Nullable password, NSString * _Nullable keyFileBookmark, YubiKeyConfiguration * _Nullable yubiKeyConfiguration) {
        if (userCancelled) {
            completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
        }
        else {
            [self getCkfsWithPassword:password
                      keyFileBookmark:keyFileBookmark
                 yubiKeyConfiguration:yubiKeyConfiguration
                      fromConvenience:NO
                           completion:completion];
        }
    };
    
    [self.viewController presentViewControllerAsSheet:mce];
}

- (void)_getCkfsWithBiometrics:(NSString *)keyFileBookmark
          yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                 allowFallback:(BOOL)allowFallback
                    completion:(CompositeKeyDeterminedBlock)completion {
    if ( !self.bioOrWatchUnlockIsPossible ) { 
        NSLog(@"Biometrics/Watch not possible...");
        
        if ( allowFallback ) {
            NSLog(@"Falling back to manual unlock...");
            [self getCkfsManually:completion];
        }
        return;
    }
    
    NSString* localizedFallbackTitle = allowFallback ? NSLocalizedString(@"safes_vc_unlock_manual_action", @"Manual Unlock") : @"";

    
    
    
    
    AutoFillLoadingVC *requiredDummyAutoFillSheet = nil;
    if ( self.isAutoFillOpen ) {
        NSStoryboard* sb = [NSStoryboard storyboardWithName:@"AutoFillLoading" bundle:nil];
        requiredDummyAutoFillSheet = (AutoFillLoadingVC*)[sb instantiateInitialController];
        requiredDummyAutoFillSheet.onCancelButton = ^{
            completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
        };
        [self.viewController presentViewControllerAsSheet:requiredDummyAutoFillSheet];
    }
    
    [BiometricIdHelper.sharedInstance authorize:localizedFallbackTitle
                                       database:self.database
                                     completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ( requiredDummyAutoFillSheet ) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.viewController dismissViewController:requiredDummyAutoFillSheet];
                });
            }
            
            if(success) {
                [self getCkfsWithPassword:self.database.conveniencePassword
                          keyFileBookmark:keyFileBookmark
                     yubiKeyConfiguration:yubiKeyConfiguration
                          fromConvenience:YES
                               completion:completion];
            }
            else {
                if( allowFallback && error && error.code == LAErrorUserFallback ) {
                    NSLog(@"User requested fallback. Falling back to manual unlock...");
                    [self getCkfsManually:completion];
                }
                else {
                    BOOL cancelled = NO;
                    if( error && (error.code == LAErrorUserCancel || error.code == StrongboxErrorCodes.macOSBiometricInProgressOrImpossible)) {
                        cancelled = YES;
                    }
                    completion(cancelled ? kGetCompositeKeyResultUserCancelled : kGetCompositeKeyResultError, nil, NO, error);
                }
            }
        });
    }];
}

- (void)getCkfsWithExplicitPassword:(NSString *)password
                    keyFileBookmark:(NSString *)keyFileBookmark
               yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                         completion:(CompositeKeyDeterminedBlock)completion {
    [self getCkfsWithPassword:password
              keyFileBookmark:keyFileBookmark
         yubiKeyConfiguration:yubiKeyConfiguration
              fromConvenience:NO
                   completion:completion];
}

- (void)getCkfsWithPassword:(NSString *)password
            keyFileBookmark:(NSString *)keyFileBookmark
       yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
            fromConvenience:(BOOL)fromConvenience
                 completion:(CompositeKeyDeterminedBlock)completion {
    NSError* error;
    CompositeKeyFactors* ckf = [self getCkfsWithSelectedUiFactors:password
                                                  keyFileBookmark:keyFileBookmark
                                             yubiKeyConfiguration:yubiKeyConfiguration
                                                  fromConvenience:NO
                                                            error:&error];
    
    if( !ckf || error) {
        completion(kGetCompositeKeyResultError, nil, fromConvenience, error);
    }
    else {
        completion(kGetCompositeKeyResultSuccess, ckf, fromConvenience, error);
    }
}



- (CompositeKeyFactors*)getCkfsWithSelectedUiFactors:(NSString*)password
                                     keyFileBookmark:(NSString *)keyFileBookmark
                                yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                                     fromConvenience:(BOOL)fromConvenience
                                               error:(NSError**)outError {
    NSWindow* windowHint = self.viewController.view.window; 
    
    DatabaseFormat formatKeyFileHint = keyFileBookmark ? [self getKeyFileDatabaseFormat] : kKeePass4;

    CompositeKeyFactors* ret = [MacCompositeKeyDeterminer getCkfsWithConfigs:password
                                                             keyFileBookmark:keyFileBookmark
                                                        yubiKeyConfiguration:yubiKeyConfiguration
                                            hardwareKeyInteractionWindowHint:windowHint
                                                           formatKeyFileHint:formatKeyFileHint
                                                                       error:outError];
    
    
    if ( ret == nil && fromConvenience ) {
        NSLog(@"Could not get CKFs with Convenience Unlock. Clearing Secure Convenience Items");

        self.database.conveniencePassword = nil;
        self.database.autoFillConvenienceAutoUnlockPassword = nil;
        self.database.conveniencePasswordHasBeenStored = NO;
    }
    
    
    
    if ( ret != nil ) {
        BOOL rememberKeyFile = !Settings.sharedInstance.doNotRememberKeyFile;
        
        BOOL keyFileChanged = ( !rememberKeyFile && self.contextAwareKeyFileBookmark != nil ) || ((!(self.contextAwareKeyFileBookmark == nil && keyFileBookmark == nil)) && (![self.contextAwareKeyFileBookmark isEqual:keyFileBookmark]));
        BOOL yubikeyChanged = (!(self.database.yubiKeyConfiguration == nil && yubiKeyConfiguration == nil)) && (![self.database.yubiKeyConfiguration isEqual:yubiKeyConfiguration]);
        
        if( keyFileChanged || yubikeyChanged ) {
            NSString* temp = rememberKeyFile ? keyFileBookmark : nil;
            
            if ( self.isAutoFillOpen ) {
                self.database.autoFillKeyFileBookmark = temp;
            }
            else {
                self.database.keyFileBookmark = temp;
            }
            
            self.database.yubiKeyConfiguration = yubiKeyConfiguration;
        }
    }
    
    return ret;
}



+ (CompositeKeyFactors*)getCkfsWithConfigs:(NSString*)password
                           keyFileBookmark:(NSString*)keyFileBookmark
                      yubiKeyConfiguration:(YubiKeyConfiguration*)yubiKeyConfiguration
          hardwareKeyInteractionWindowHint:(NSWindow*)hardwareKeyInteractionWindowHint
                         formatKeyFileHint:(DatabaseFormat)formatKeyFileHint
                                     error:(NSError**)outError {
    NSData* keyFileDigest = nil;

    if( keyFileBookmark ) {
        NSError *keyFileParseError;
        keyFileDigest = [KeyFileParser getDigestFromBookmark:keyFileBookmark
                                             keyFileFileName:nil
                                                      format:formatKeyFileHint
                                                       error:&keyFileParseError];
                
        if( keyFileDigest == nil ) {
            NSLog(@"WARNWARN: Could not read Key File [%@]", keyFileParseError);
            
            if (outError) {
                *outError = keyFileParseError;
            }
            
            return nil;
        }
    }

    if ( yubiKeyConfiguration == nil ) {
        return [CompositeKeyFactors password:password keyFileDigest:keyFileDigest];
    }
    else {
        return [MacCompositeKeyDeterminer getCkfsWithHardwareKey:password
                                                   keyFileDigest:keyFileDigest
                                            yubiKeyConfiguration:yubiKeyConfiguration
                                                      windowHint:hardwareKeyInteractionWindowHint
                                                           error:outError];
    }
}

- (DatabaseFormat)getKeyFileDatabaseFormat {
    DatabaseFormat format = self.database.likelyFormat;
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.database.uuid];
    if (url) {
        format = [Serializator getDatabaseFormat:url];
    }
    else {
        
        NSLog(@"🔴 WARNWARN: Could not read working copy to check Key File Format");
    }
    return format;
}

+ (CompositeKeyFactors *)getCkfsWithHardwareKey:(NSString *)password
                                  keyFileDigest:(NSData *)keyFileDigest
                           yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                                     windowHint:(NSWindow*)windowHint
                                          error:(NSError **)error {
    NSInteger slot = yubiKeyConfiguration.slot;
    
    return [CompositeKeyFactors password:password
                           keyFileDigest:keyFileDigest
                               yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
        [MacHardwareKeyManager.sharedInstance compositeKeyFactorCr:challenge
                                                    windowHint:windowHint
                                                          slot:slot
                                                    completion:completion];
    }];
}

- (BOOL)bioOrWatchUnlockIsPossible {
    return [MacCompositeKeyDeterminer bioOrWatchUnlockIsPossible:self.database];
}

+ (BOOL)bioOrWatchUnlockIsPossible:(MacDatabasePreferences*)database {
    if ( !database ) {
        return NO;
    }
    
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL touchEnabled = (database.isTouchIdEnabled && touchAvailable);
    BOOL watchEnabled = (database.isWatchUnlockEnabled && watchAvailable);
    BOOL methodEnabled = touchEnabled || watchEnabled;
    BOOL passwordAvailable = database.conveniencePasswordHasBeenStored;
    BOOL featureAvailable = Settings.sharedInstance.isProOrFreeTrial;
    [database triggerPasswordExpiry];
    BOOL expired = database.conveniencePasswordHasExpired;
    BOOL possible = methodEnabled && featureAvailable && passwordAvailable && !expired;
    

    
    return possible;
}

- (NSString*)contextAwareKeyFileBookmark {
    return self.isAutoFillOpen ? self.database.autoFillKeyFileBookmark : self.database.keyFileBookmark;
}

@end
