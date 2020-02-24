//
//  CompositeKey.m
//  Strongbox
//
//  Created by Mark on 16/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CompositeKeyFactors.h"

@implementation CompositeKeyFactors

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
        _password = password;
        _keyFileDigest = keyFileDigest;
        _yubiKeyCR = yubiKeyCR;
    }
    return self;
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
