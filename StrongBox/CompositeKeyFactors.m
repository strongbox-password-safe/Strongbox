//
//  CompositeKey.m
//  Strongbox
//
//  Created by Mark on 16/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CompositeKeyFactors.h"
#import "sblog.h"
#import "NSData+Extensions.h"

@interface CompositeKeyFactors ()

@property (nullable) MMcGPair<NSData*, NSData*>* lastCRResponse;

@end

@implementation CompositeKeyFactors

+ (instancetype)unitTestDefaults {
    return [CompositeKeyFactors password:@"a"];
}

+ (instancetype)password:(NSString *)password {
    return [CompositeKeyFactors password:password keyFileDigest:nil];
}

+ (instancetype)password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest {
    return [CompositeKeyFactors password:password keyFileDigest:keyFileDigest yubiKeyCR:nil];
}

+ (instancetype)password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest yubiKeyCR:(YubiKeyCRHandlerBlock)yubiKeyCR {
    return [[CompositeKeyFactors alloc] initWithPassword:password keyFileDigest:keyFileDigest yubiKeyCR:yubiKeyCR];
}

- (instancetype)initWithPassword:(NSString *)password {
    return [self initWithPassword:password keyFileDigest:nil];
}

- (instancetype)initWithPassword:(NSString *)password keyFileDigest:(NSData *)keyFileDigest {
    return [self initWithPassword:password keyFileDigest:keyFileDigest yubiKeyCR:nil];
}

- (instancetype)initWithPassword:(NSString *)password keyFileDigest:(NSData *)keyFileDigest yubiKeyCR:(YubiKeyCRHandlerBlock)yubiKeyCR {
    self = [super init];
    if (self) {
        __weak CompositeKeyFactors* weakSelf = self;
        
        _password = password;
        _keyFileDigest = keyFileDigest;
        
        if ( yubiKeyCR ) {
            _yubiKeyCR = ^( NSData* challenge, YubiKeyCRResponseBlock responseFn ) {
                yubiKeyCR(challenge, ^(BOOL userCancelled, NSData*_Nullable response, NSError*_Nullable error) {
                    
                    weakSelf.lastCRResponse = [MMcGPair pairOfA:challenge andB:response]; 
                    responseFn(userCancelled, response, error);
                });
            };
        }
        else {
            _yubiKeyCR = nil;
        }
    }
    
    return self;
}

- (MMcGPair<NSData *,NSData *> *)lastChallengeResponse {
    return self.lastCRResponse;
}

- (BOOL)isAmbiguousEmptyOrNullPassword {
    return self.password.length == 0 && (self.keyFileDigest || self.yubiKeyCR);
}

- (instancetype)clone {
    CompositeKeyFactors *ret = [[CompositeKeyFactors alloc] initWithPassword:self.password
                                                              keyFileDigest:self.keyFileDigest
                                                                  yubiKeyCR:self.yubiKeyCR];

    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@-%@-%@", self.password, self.keyFileDigest, self.yubiKeyCR];
}

@end
