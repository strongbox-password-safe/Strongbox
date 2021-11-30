//
//  MacCompositeKeyDeterminer.m
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "CompositeKeyDeterminer.h"
#import "Settings.h"
#import "BiometricIdHelper.h"
#import "ManualCredentialsEntry.h"
//#import "MacAlerts.h"
#import "DatabasesManager.h"
#import "MacYubiKeyManager.h"
#import "Utils.h"
#import "WorkingCopyManager.h"
#import "Serializator.h"
#import "KeyFileParser.h"

@interface CompositeKeyDeterminer ()

@property (nonnull) VIEW_CONTROLLER_PTR viewController;
@property (nonnull) METADATA_PTR database;
@property BOOL isAutoFillOpen;
@property BOOL isAutoFillQuickTypeOpen;
@property BOOL noConvenienceUnlock;

@property (nonnull) CompositeKeyDeterminedBlock completion;

@end

@implementation CompositeKeyDeterminer

+ (instancetype)determinerWithViewController:(VIEW_CONTROLLER_PTR)viewController
                                    database:(METADATA_PTR)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen
                     isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                         biometricPreCleared:(BOOL)biometricPreCleared
                         noConvenienceUnlock:(BOOL)noConvenienceUnlock {
    return [[CompositeKeyDeterminer alloc] initWithViewController:viewController
                                                         database:database
                                                   isAutoFillOpen:isAutoFillOpen
                                          isAutoFillQuickTypeOpen:isAutoFillQuickTypeOpen
                                              noConvenienceUnlock:noConvenienceUnlock];
}

- (instancetype)initWithViewController:(VIEW_CONTROLLER_PTR)viewController
                              database:(METADATA_PTR)database
                        isAutoFillOpen:(BOOL)isAutoFillOpen
               isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                   noConvenienceUnlock:(BOOL)noConvenienceUnlock {
    self = [super init];
    if (self) {
        self.viewController = viewController;
        self.database = database;
        self.isAutoFillOpen = isAutoFillOpen;
        self.isAutoFillQuickTypeOpen = isAutoFillQuickTypeOpen;
        self.noConvenienceUnlock = noConvenienceUnlock;
    }
    
    return self;
}

- (void)getCredentials:(CompositeKeyDeterminedBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self innerGetCredentials:completion];
    });
}

- (void)innerGetCredentials:(CompositeKeyDeterminedBlock)completion {
    self.completion = completion;

    
}

- (void)manualUnlockDatabase:(DatabaseMetadata*)database {
    ManualCredentialsEntry* mce = [[ManualCredentialsEntry alloc] initWithNibName:@"ManualCredentialsEntry" bundle:nil];
    mce.databaseUuid = database.uuid;
    mce.isAutoFillOpen = self.isAutoFillOpen;
    
    mce.onDone = ^(BOOL userCancelled, NSString * _Nullable password, NSString * _Nullable keyFileBookmark, YubiKeyConfiguration * _Nullable yubiKeyConfiguration) {
        if (userCancelled) {
            self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
        }
        else {
            
        }
    };
    
    [self.viewController presentViewControllerAsSheet:mce];
}





- (void)onGotCredentials:(NSString*)password
         keyFileBookmark:(NSString*)keyFileBookmark
    yubikeyConfiguration:(YubiKeyConfiguration*)yubiKeyConfiguration
         fromConvenience:(BOOL)fromConvenience {
    NSError* error;
    CompositeKeyFactors* ckf = [self getCkfsWithSelectedUiFactors:password
                                                  keyFileBookmark:keyFileBookmark
                                             yubiKeyConfiguration:yubiKeyConfiguration
                                                  fromConvenience:fromConvenience
                                                            error:&error];
    
    if( !ckf || error) {

        self.completion(kGetCompositeKeyResultError, nil, NO, error);

    }
    else {
        self.database.autoFillKeyFileBookmark = keyFileBookmark;
        [DatabasesManager.sharedInstance atomicUpdate:self.database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.autoFillKeyFileBookmark = keyFileBookmark;
        }];
        
        self.completion(kGetCompositeKeyResultSuccess, ckf, fromConvenience, error);
    }
}



- (CompositeKeyFactors*)getCkfsWithSelectedUiFactors:(NSString*)password
                                     keyFileBookmark:(NSString*)keyFileBookmark
                                yubiKeyConfiguration:(YubiKeyConfiguration * _Nullable)yubiKeyConfiguration
                                     fromConvenience:(BOOL)fromConvenience
                                               error:(NSError**)outError {
    NSData* keyFileDigest = nil;

    if( keyFileBookmark ) {
        DatabaseFormat format = [self getKeyFileDatabaseFormat];

        NSError *keyFileParseError;
        keyFileDigest = [KeyFileParser getDigestFromBookmark:keyFileBookmark 
                                                        format:format
                                                        error:&keyFileParseError];
                
        if( keyFileDigest == nil ) {
            NSLog(@"WARNWARN: Could not read Key File [%@]", keyFileParseError);

            return [self handleErrorParsingKeyFile:fromConvenience keyFileParseError:keyFileParseError outError:outError];
        }

            
            
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    }

    if ( yubiKeyConfiguration == nil ) {
        return [CompositeKeyFactors password:password keyFileDigest:keyFileDigest];
    }
    else {
        return [self getCkfsWithHardwareKey:password keyFileDigest:keyFileDigest yubiKeyConfiguration:yubiKeyConfiguration error:outError];
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

- (CompositeKeyFactors*)handleErrorParsingKeyFile:(BOOL)isConvenienceUnlock keyFileParseError:(NSError *)keyFileParseError outError:(NSError *__autoreleasing *)outError {
    if( isConvenienceUnlock ) {
        NSLog(@"Could not read Key File with Convenience Unlock. Clearing Secure Convenience Items");
        
        [self.database clearSecureItems];
        
        self.database.isEnrolledForConvenience = NO;
        self.database.isTouchIdEnabled = NO;
        self.database.hasBeenPromptedForConvenience = NO; 
        
        [DatabasesManager.sharedInstance update:self.database];
    }
    
    if (outError) {
        *outError = keyFileParseError;
        
        
    }
    
    return nil;
}

- (CompositeKeyFactors *)getCkfsWithHardwareKey:(NSString *)password
                                  keyFileDigest:(NSData *)keyFileDigest
                           yubiKeyConfiguration:(YubiKeyConfiguration *)yubiKeyConfiguration
                                          error:(NSError **)error {
    __block YubiKeyData * _Nonnull foundYubiKey;
    
    
    
    
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    [MacYubiKeyManager.sharedInstance getAvailableYubiKey:^(YubiKeyData * _Nonnull yubiKeyData) {
        foundYubiKey = yubiKeyData;
        dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    if ( foundYubiKey == nil || ![foundYubiKey.serial isEqualToString:yubiKeyConfiguration.deviceSerial]) {
        if (error) {
            NSString* errorMessage = NSLocalizedString(@"mac_autofill_no_or_incorrect_yubikey_found", @"Your Database is configured to use a YubiKey, however no YubiKey or an incorrect YubiKey was found connected.");
            *error = [Utils createNSError:errorMessage errorCode:-24123];
        }
        return nil;
    }
    else {
        NSInteger slot = yubiKeyConfiguration.slot;
        BOOL currentYubiKeySlot1IsBlocking = foundYubiKey.slot1CrStatus == YubiKeySlotCrStatusSupportedBlocking;
        BOOL currentYubiKeySlot2IsBlocking = foundYubiKey.slot2CrStatus == YubiKeySlotCrStatusSupportedBlocking;
        BOOL blocking = slot == 1 ? currentYubiKeySlot1IsBlocking : currentYubiKeySlot2IsBlocking;
        
        NSWindow* windowHint = self.viewController.view.window; 
        
        return [CompositeKeyFactors password:password
                               keyFileDigest:keyFileDigest
                                   yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [MacYubiKeyManager.sharedInstance compositeKeyFactorCr:challenge
                                                        windowHint:windowHint
                                                              slot:slot
                                                    slotIsBlocking:blocking
                                                        completion:completion];
        }];
    }
}



- (BOOL)isAutoFillConvenienceAutoLockPossible {
    
    return YES; 
}

@end
