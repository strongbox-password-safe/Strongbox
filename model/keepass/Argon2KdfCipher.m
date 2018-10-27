//
//  Argon2KdfCipher.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Argon2KdfCipher.h"
#import "argon2.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* const kParameterSalt = @"S";
static NSString* const kParameterParallelism = @"P";
static NSString* const kParameterMemory = @"M";
static NSString* const kParameterIterations = @"I";
static NSString* const kParameterVersion = @"V";
static NSString* const kParameterSecretKey = @"K";
static NSString* const kParameterAssocData = @"A";

const uint64_t DefaultIterations = 2;
const uint64_t DefaultMemory = 1024 * 1024;
const uint32_t DefaultParallelism = 2;

static const BOOL kLogVerbose = YES;

@implementation Argon2KdfCipher

- (instancetype)initWithParametersDictionary:(NSDictionary<NSString*, NSObject*>*)parameters {
    self = [super init];
    if (self) {
        NSLog(@"%@", parameters);
        
        NSNumber *parallelism = (NSNumber*)[parameters objectForKey:kParameterParallelism];
        NSNumber *memory = (NSNumber*)[parameters objectForKey:kParameterMemory];
        NSNumber *iterations = (NSNumber*)[parameters objectForKey:kParameterIterations];
        NSNumber *version = (NSNumber*)[parameters objectForKey:kParameterVersion];
    
        _parallelism = parallelism.unsignedIntValue;
        _memory = memory.longLongValue;
        _iterations = iterations.longLongValue;
        _version = version.unsignedIntValue;
        _salt = (NSData*)[parameters objectForKey:kParameterSalt];
        _secretKey = (NSData*)[parameters objectForKey:kParameterSecretKey];
        _assocData = (NSData*)[parameters objectForKey:kParameterAssocData];
    }
    return self;
}

static const uint32_t kBlockSize = 1024;

- (NSData*)deriveKey:(NSData*)data {
    // TODO: Verify parameters exist!
    // TODO: Defaults if not present...
    
    uint8_t buffer[32];
    
    argon2_context ctx;
    
    ctx.version = self.version;
    ctx.lanes = self.parallelism;
    ctx.m_cost = (uint32_t)self.memory / kBlockSize;
    ctx.t_cost = (uint32_t)self.iterations;
    ctx.out = buffer;
    ctx.outlen = 32;
    ctx.pwd = (uint8_t*)data.bytes;
    ctx.pwdlen = (uint32_t)data.length;
    ctx.salt = (uint8_t*)self.salt.bytes;
    ctx.saltlen = (uint32_t)self.salt.length;
    ctx.secret = self.secretKey ? (uint8_t*)self.secretKey.bytes : nil;  // TODO: how to test?
    ctx.secretlen = self.secretKey ? (uint32_t)self.secretKey.length : 0;
    ctx.ad = self.assocData ? (uint8_t*)self.assocData.bytes : nil; // TODO: how to test?
    ctx.adlen = self.assocData ? (uint32_t) self.assocData.length : 0;
    ctx.threads = self.parallelism; // TODO: Correct or should it be constant 4? How to test?
    
    argon2d_ctx(&ctx);
    
    // TODO: If Transform Key is not 32 you need to SHA256 it accoring to source CompositeKey.cs
    
//    uint8_t hash[CC_SHA256_DIGEST_LENGTH];
//    CC_SHA256(buffer, ctx.outlen, hash);
//
//    NSData *transformKey = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];

    NSData *transformKey = [NSData dataWithBytes:ctx.out length:ctx.outlen];

    if(kLogVerbose) {
        NSLog(@"TRANSFORM KEY: %@", [transformKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
//Composite Key: v106/7c+/S7Gw2rTES3ZM+/tY8Thy//PqI4nWcFE8tg=
//Transform Before SHA256: e/BHbXFC6VoFRRRTr9ffF/CMP+rkbHI5BWobU/RLXlU=
//MASTER KEY (I believe): CG2XlQCE+Guu6wged2AxB7GfUTqpVtq51OKK0lJz1hE=
    
    // TODO:
    
    // TODO: Resize Key? Checkout code in CompositeKey.cs
    
    return transformKey;
}

@end
