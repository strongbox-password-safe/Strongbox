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
#import "Utils.h"
#import "KeePassCiphers.h"
#import "KeePassConstants.h"

static NSString* const kParameterSalt = @"S";
static NSString* const kParameterParallelism = @"P";
static NSString* const kParameterMemory = @"M";
static NSString* const kParameterIterations = @"I";
static NSString* const kParameterVersion = @"V";
static NSString* const kParameterSecretKey = @"K";
static NSString* const kParameterAssocData = @"A";

static const uint64_t kDefaultIterations = 2;
static const uint64_t kDefaultMemory = 1024 * 1024;
static const uint32_t kDefaultParallelism = 2;
static const uint32_t kDefaultVersion = 19;
static const uint32_t kDefaultSaltLength = 32;

static const uint32_t kBlockSize = 1024;

static const BOOL kLogVerbose = NO;

@interface Argon2KdfCipher ()

@property (nonatomic, readonly) NSData *salt;
@property (nonatomic, readonly) uint32_t parallelism;
@property (nonatomic, readonly) uint64_t memory;
@property (nonatomic, readonly) uint64_t iterations;
@property (nonatomic, readonly) uint32_t version;
@property (nonatomic, readonly) NSData *secretKey;
@property (nonatomic, readonly) NSData *assocData;

@end

@implementation Argon2KdfCipher

- (instancetype)initWithDefaults
{
    self = [super init];
    if (self) {
        _parallelism = kDefaultParallelism;
        _memory = kDefaultMemory;
        _iterations = kDefaultIterations;
        _version = kDefaultVersion;
        _salt = getRandomData(kDefaultSaltLength);
        _secretKey = nil;
        _assocData = nil;
    }
    return self;
}

- (instancetype)initWithParametersDictionary:(NSDictionary<NSString*, VariantObject*>*)parameters {
    self = [super init];
    if (self) {
        //NSLog(@"ARGON2: %@", parameters);
        VariantObject *salt = [parameters objectForKey:kParameterSalt];
        if( !salt) {
            return nil;
        }
        else {
            _salt = (NSData*)salt.theObject;
        }

        VariantObject *parallelism = [parameters objectForKey:kParameterParallelism];
        if(!parallelism) {
            _parallelism = kDefaultParallelism;
        }
        else {
            _parallelism = ((NSNumber*)parallelism.theObject).unsignedIntValue;
        }
        
        VariantObject *memory = [parameters objectForKey:kParameterMemory];
        if(!memory) {
            _memory = kDefaultMemory;
        }
        else {
            _memory = ((NSNumber*)memory.theObject).longLongValue;
        }
        
        VariantObject *iterations = [parameters objectForKey:kParameterIterations];
        if(!iterations) {
            _iterations = kDefaultIterations;
        }
        else {
            _iterations = ((NSNumber*)iterations.theObject).longLongValue;
        }
        
        VariantObject *version = [parameters objectForKey:kParameterVersion];
        if(!version) {
            _version = kDefaultVersion;
        }
        else {
            _version = ((NSNumber*)version.theObject).unsignedIntValue;
        }
        
        // Optional
        
        VariantObject *secretKey = [parameters objectForKey:kParameterSecretKey];
        VariantObject *assocData = [parameters objectForKey:kParameterAssocData];
        _secretKey = secretKey ? (NSData*)secretKey.theObject : nil;
        _assocData = assocData ? (NSData*)assocData.theObject : nil;
    }
    return self;
}

- (NSData*)deriveKey:(NSData*)data {
    uint8_t buffer[32];
    
    argon2_context ctx = { 0 };
    
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
    ctx.secret = self.secretKey ? (uint8_t*)self.secretKey.bytes : nil;
    ctx.secretlen = self.secretKey ? (uint32_t)self.secretKey.length : 0;
    ctx.ad = self.assocData ? (uint8_t*)self.assocData.bytes : nil;
    ctx.adlen = self.assocData ? (uint32_t) self.assocData.length : 0;
    ctx.threads = self.parallelism; // UNSURE but looks ok: Correct or should it be constant 4?
    ctx.allocate_cbk = nil; // Important - got caught with a bug here due to initialization values. Must be nil
    ctx.free_cbk = nil; // Important - got caught with a bug here due to initialization values. Must be nil
    
    argon2d_ctx(&ctx);
    
    NSData *transformKey = [NSData dataWithBytes:ctx.out length:ctx.outlen];

    if(kLogVerbose) {
        NSLog(@"ARGON2: TRANSFORM KEY: %@", [transformKey base64EncodedStringWithOptions:kNilOptions]);
    }

    return transformKey;
}

- (KdfParameters *)kdfParameters {
    VariantObject *uuid = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:argon2CipherUuidData()];
    VariantObject *voIterations = [[VariantObject alloc] initWithType:kVariantTypeUint64 theObject:@(self.iterations)];
    VariantObject *voParallelism = [[VariantObject alloc] initWithType:kVariantTypeUint32 theObject:@(self.parallelism)];
    VariantObject *voMemory = [[VariantObject alloc] initWithType:kVariantTypeUint64 theObject:@(self.memory)];
    VariantObject *voVersion = [[VariantObject alloc] initWithType:kVariantTypeUint32 theObject:@(self.version)];
    VariantObject *voSalt = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:self.salt];
    
    NSDictionary<NSString*, VariantObject*> *required = @{
         kKdfParametersKeyUuid : uuid,
         kParameterSalt : voSalt,
         kParameterParallelism : voParallelism,
         kParameterMemory : voMemory,
         kParameterIterations : voIterations,
         kParameterVersion : voVersion,
    };
    
    NSMutableDictionary *dict = [required mutableCopy];
    if(self.secretKey) {
        VariantObject *voSecretKey = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:self.secretKey];
        [dict setObject:voSecretKey forKey:kParameterSecretKey];
    }
    if(self.assocData) {
        VariantObject *voAssocData = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:self.assocData];
        [dict setObject:voAssocData forKey:kParameterAssocData];
    }
    
    return [[KdfParameters alloc] initWithParameters:dict];
}

@end
