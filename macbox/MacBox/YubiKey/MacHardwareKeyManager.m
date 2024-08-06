//
//  YubiKeyManager.m
//  Strongbox
//
//  Created by Mark on 18/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "MacHardwareKeyManager.h"

#include "ykcore.h"
#include "ykdef.h"
#include "ykpers-version.h"
#include "ykstatus.h"
#include "yubikey.h"

#import "Utils.h"
#import "PressHardwareKeyWindow.h"
#import "PleaseConnectHardwareKey.h"

#import "MacAlerts.h"

@interface MacHardwareKeyManager ()

@property (strong, nonatomic) dispatch_queue_t queue;

@end

@implementation MacHardwareKeyManager

+ (instancetype)sharedInstance {
    static MacHardwareKeyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[MacHardwareKeyManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("HardwareKeySerializationQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)requestPlugIn:(NSData*)challenge
onDemandWindowProvider:(MacHardwareKeyManagerOnDemandUIProviderBlock)onDemandWindowProvider
                 slot:(NSInteger)slot
           completion:(YubiKeyCRResponseBlock)completion   {
    __weak MacHardwareKeyManager* weakSelf = self;
    [PleaseConnectHardwareKey show:onDemandWindowProvider completion:^(BOOL cancelled) {
        if ( cancelled ) {
            completion(YES, nil, nil);
        }
        else {
            [weakSelf compositeKeyFactorCr:challenge slot:slot completion:completion onDemandWindowProvider:onDemandWindowProvider];
        }
    }];
}

- (void)compositeKeyFactorCr:(NSData*)challenge
                  windowHint:(NSWindow*)windowHint
                        slot:(NSInteger)slot
                  completion:(YubiKeyCRResponseBlock)completion {
    [self compositeKeyFactorCr:challenge slot:slot completion:completion onDemandWindowProvider:^NSWindow * _Nonnull{
        return windowHint;
    }];
}

- (void)compositeKeyFactorCr:(NSData *)challenge
                        slot:(NSInteger)slot
                  completion:(YubiKeyCRResponseBlock)completion
      onDemandWindowProvider:(MacHardwareKeyManagerOnDemandUIProviderBlock)onDemandWindowProvider {
    dispatch_async(self.queue, ^{
        HardwareKeySlotCrStatus status = [self fastGetStatus:(int)slot];
        
        if ( status == kHardwareKeySlotCrStatusUnknown || status == kHardwareKeySlotCrStatusNotSupported ) {
            [self requestPlugIn:challenge onDemandWindowProvider:onDemandWindowProvider slot:slot completion:completion];
        }
        else {
            if ( status == kHardwareKeySlotCrStatusSupportedBlocking ) {
                [PressHardwareKeyWindow show:onDemandWindowProvider];
            }
            
            NSError *error;
            NSData* response = [self cr:challenge slot:slot error:&error];
            
            if ( status == kHardwareKeySlotCrStatusSupportedBlocking ) {
                [PressHardwareKeyWindow hide];
            }
            
            completion(NO, response, error);
        }
    });
}

- (void)getAvailableKey:(GetAvailableKeyCompletion)completion {
    dispatch_async(self.queue, ^{
        HardwareKeyData* ret = [self internalGetAvailableYubiKey];
        completion(ret);
    });
}

- (void)challengeResponse:(NSData *)challenge slot:(NSInteger)slot completion:(ChallengeResponseCompletion)completion {
    dispatch_async(self.queue, ^{
        NSError *error;
        NSData* response =[self cr:challenge slot:slot error:&error];
        completion(response, error);
    });
}

- (HardwareKeySlotCrStatus)fastGetStatus:(int)slot {
    if (!yk_init()) {
        slog(@"YubiKey Init Failed");
        return kHardwareKeySlotCrStatusUnknown;
    }

    YK_KEY *firstKey = yk_open_first_key();

    if (!firstKey) {
        
        return kHardwareKeySlotCrStatusUnknown;
    }
        
    HardwareKeySlotCrStatus ret = [self slotSupportsChallengeResponse:firstKey slot:slot];
    
    yk_close_key(firstKey);

    return ret;
}

- (HardwareKeyData*)internalGetAvailableYubiKey {
    if (!yk_init()) {
        slog(@"YubiKey Init Failed");
        return nil;
    }

    YK_KEY *firstKey = yk_open_first_key();

    if (!firstKey) {
        
        return nil;
    }
    
    unsigned int serial;
    if(!yk_get_serial(firstKey, 1, 0, &serial)) {

        return nil;
    }

    
    
    HardwareKeyData* ret = [[HardwareKeyData alloc] init];
    
    ret.serial = @(serial).stringValue;
    ret.slot1CrStatus = [self slotSupportsChallengeResponse:firstKey slot:1];
    ret.slot2CrStatus = [self slotSupportsChallengeResponse:firstKey slot:2];

    yk_close_key(firstKey);

    return ret;
}

- (NSData*)cr:(NSData*)challenge slot:(NSInteger)slot error:(NSError**)error {
    if (!yk_init()) {
        slog(@"YubiKey Init Failed");
        return nil;
    }

    YK_KEY *firstKey = yk_open_first_key();

    if (!firstKey) {
        return nil;
    }
    
    NSData* ret;
    YubiKeyChallengeResponseResult result = [self internalChallengeResponse:firstKey
                                                                       slot:slot
                                                              allowBlocking:YES
                                                                  challenge:challenge
                                                                   response:&ret];

    yk_close_key(firstKey);

    if (result == YubiKeyChallengeResponseResultSuccess) {
        return ret;
    }

    NSString* loc = NSLocalizedString(@"mac_error_getting_challenge_response_yubikey", @"Could not get Challenge Response from Yubikey");
    
    if ( error ) {
        *error = [Utils createNSError:loc errorCode:-1];
    }
    
    return nil;
}

- (HardwareKeySlotCrStatus)slotSupportsChallengeResponse:(YK_KEY*)key slot:(int)slot {
    const int kChallengeSize = 64;
    uint8_t challenge[kChallengeSize] = {0};
    NSData* challengeData = [NSData dataWithBytes:challenge length:kChallengeSize];
    
    NSData* response;
    YubiKeyChallengeResponseResult result = [self internalChallengeResponse:key
                                                                       slot:slot
                                                              allowBlocking:NO
                                                                  challenge:challengeData
                                                                   response:&response];

    if (result == YubiKeyChallengeResponseResultSuccess) {
        return kHardwareKeySlotCrStatusSupportedNonBlocking;
    }
    else if (result == YubiKeyChallengeResponseResultWouldBlock) {
        return kHardwareKeySlotCrStatusSupportedBlocking;
    }
    else {
        return kHardwareKeySlotCrStatusNotSupported;
    }
}

typedef NS_ENUM(NSInteger, YubiKeyChallengeResponseResult) {
    YubiKeyChallengeResponseResultUnknown,
    YubiKeyChallengeResponseResultSuccess,
    YubiKeyChallengeResponseResultWouldBlock,
    YubiKeyChallengeResponseResultError,
};

- (YubiKeyChallengeResponseResult)internalChallengeResponse:(YK_KEY*)key
                                                       slot:(NSInteger)slot
                                              allowBlocking:(BOOL)allowBlocking
                                                  challenge:(NSData*)challenge
                                                   response:(NSData**)response {
    
    
    
    
    

    const NSInteger kChallengeSize = 64;
    const NSInteger padLen = kChallengeSize - challenge.length;

    uint8_t challengeBuffer[kChallengeSize];
    for(int i=0;i<kChallengeSize;i++) {
        challengeBuffer[i] = padLen;
    }
    [challenge getBytes:challengeBuffer length:challenge.length];
    
    const int kResponseSize = 64;
    uint8_t responseBuffer[kResponseSize] = {0};

    int result = yk_challenge_response(key,
                                       (slot == 1) ? SLOT_CHAL_HMAC1 : SLOT_CHAL_HMAC2,
                                       allowBlocking,
                                       kChallengeSize,
                                       challengeBuffer,
                                       kResponseSize,
                                       responseBuffer);
    
    if (result) {
        *response = [[NSData alloc] initWithBytes:responseBuffer length:SHA1_DIGEST_SIZE];
        return YubiKeyChallengeResponseResultSuccess;
    }
    else {
        if (yk_errno == YK_EWOULDBLOCK) {
            return YubiKeyChallengeResponseResultWouldBlock;
        }
        else if (yk_errno == YK_ETIMEOUT) { } 
        else if (yk_errno == YK_EUSBERR) {
            slog(@"CR Error: %s", yk_strerror(yk_errno));
            slog(@"Challenge Response USB Error?");
        }
        else {
            slog(@"Challenge Response Error: %s", yk_strerror(yk_errno));
        }
    }

    return YubiKeyChallengeResponseResultError;
}

@end
