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
    return [CompositeKeyFactors password:password keyFileDigest:keyFileDigest yubiKeyResponse:nil];
}

+ (instancetype)password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest yubiKeyResponse:(NSData*)yubiKeyResponse {
    return [[CompositeKeyFactors alloc] initWithPassword:password keyFileDigest:keyFileDigest yubiKeyResponse:yubiKeyResponse];
}

- (instancetype)initWithPassword:(NSString *)password {
    return [self initWithPassword:password keyFileDigest:nil];
}

- (instancetype)initWithPassword:(NSString *)password keyFileDigest:(NSData *)keyFileDigest {
    return [self initWithPassword:password keyFileDigest:keyFileDigest yubiKeyResponse:nil];
}

- (instancetype)initWithPassword:(NSString *)password keyFileDigest:(NSData *)keyFileDigest yubiKeyResponse:(NSData*)yubiKeyResponse {
    self = [super init];
    if (self) {
        _password = password;
        _keyFileDigest = keyFileDigest;
        _yubiKeyResponse = yubiKeyResponse;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@-%@-%@", self.password, self.keyFileDigest, self.yubiKeyResponse];
}
@end
