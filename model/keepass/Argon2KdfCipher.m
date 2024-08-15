//
//  Argon2KdfCipher.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Argon2KdfCipher.h"
#import "argon2.h"
#import <CommonCrypto/CommonDigest.h>
#import "Utils.h"
#import "KeePassCiphers.h"
#import "KeePassConstants.h"

static NSString* const kParameterSalt = @"S";
static NSString* const kParameterParallelism = @"P";
static NSString* const kParameterIterations = @"I";
static NSString* const kParameterVersion = @"V";
static NSString* const kParameterSecretKey = @"K";
static NSString* const kParameterAssocData = @"A";
static NSString* const kParameterMemory = @"M";

#ifdef DEBUG
static const uint64_t kDefaultIterations = 2;  
#else
static const uint64_t kDefaultIterations = 12; 
#endif

static const uint64_t kDefaultMemory = 16 * 1024 * 1024;
static const uint32_t kDefaultParallelism = 2;
static const uint32_t kDefaultVersion = 19;
static const uint32_t kDefaultSaltLength = 32;
    
static const uint64_t kMaxRecommendedMemory = 64 * 1024 * 1024;

static const uint32_t kBlockSize = 1024;

static const BOOL kLogVerbose = NO;

@interface Argon2KdfCipher ()

@property (nonatomic, readonly) NSData *salt;
@property (nonatomic, readonly) uint32_t innerParallelism;
@property (nonatomic, readonly) uint64_t innerMemory;
@property (nonatomic, readonly) uint64_t innerIterations;
@property (nonatomic, readonly) uint32_t version;
@property (nonatomic, readonly) NSData *secretKey;
@property (nonatomic, readonly) NSData *assocData;

@property BOOL argon2id;

@end

@implementation Argon2KdfCipher

- (instancetype)initWithDefaults:(BOOL)argon2id {
    return [self initWithArgon2id:argon2id memory:kDefaultMemory parallelism:kDefaultParallelism iterations:kDefaultIterations];
}

- (instancetype)initWithArgon2id:(BOOL)argon2id memory:(uint64_t)memory parallelism:(uint32_t)parallelism iterations:(uint64_t)iterations {
    self = [super init];
    if (self) {
        _innerParallelism = parallelism;
        _innerMemory = memory;
        _innerIterations = iterations;
        _version = kDefaultVersion;
        _salt = getRandomData(kDefaultSaltLength);
        _secretKey = nil;
        _assocData = nil;
        self.argon2id = argon2id;
    }
    return self;
}

- (instancetype)initWithParametersDictionary:(KdfParameters*)parameters {
    self = [super init];
    if (self) {
        
        VariantObject *salt = [parameters.parameters objectForKey:kParameterSalt];
        if(!salt) {
            return nil;
        }
        else {
            _salt = (NSData*)salt.theObject;
        }

        VariantObject *parallelism = [parameters.parameters objectForKey:kParameterParallelism];
        if(!parallelism) {
            _innerParallelism = kDefaultParallelism;
        }
        else {
            _innerParallelism = ((NSNumber*)parallelism.theObject).unsignedIntValue;
        }
        
        VariantObject *memory = [parameters.parameters objectForKey:kParameterMemory];
        if(!memory) {
            _innerMemory = kDefaultMemory;
        }
        else {
            _innerMemory = ((NSNumber*)memory.theObject).longLongValue;
        }
        
        VariantObject *iterations = [parameters.parameters objectForKey:kParameterIterations];
        if(!iterations) {
            _innerIterations = kDefaultIterations;
        }
        else {
            _innerIterations = ((NSNumber*)iterations.theObject).longLongValue;
        }
        
        VariantObject *version = [parameters.parameters objectForKey:kParameterVersion];
        if(!version) {
            _version = kDefaultVersion;
        }
        else {
            _version = ((NSNumber*)version.theObject).unsignedIntValue;
        }
        
        self.argon2id = parameters.uuid && [parameters.uuid isEqual:argon2idCipherUuid()];
        
        
        
        VariantObject *secretKey = [parameters.parameters objectForKey:kParameterSecretKey];
        VariantObject *assocData = [parameters.parameters objectForKey:kParameterAssocData];
        _secretKey = secretKey ? (NSData*)secretKey.theObject : nil;
        _assocData = assocData ? (NSData*)assocData.theObject : nil;
    }
    
    return self;
}

- (NSData*)deriveKey:(NSData*)data {
    uint8_t buffer[32];
    
    argon2_context ctx = { 0 };
    
    ctx.version = self.version;
    ctx.lanes = self.innerParallelism;
    ctx.m_cost = (uint32_t)self.innerMemory / kBlockSize;
    ctx.t_cost = (uint32_t)self.innerIterations;
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
    ctx.threads = self.innerParallelism; 
    ctx.allocate_cbk = nil; 
    ctx.free_cbk = nil; 
        
    if ( self.argon2id ) {
        argon2id_ctx(&ctx);
    }
    else {
        argon2d_ctx(&ctx);
    }
    
    NSData *transformKey = [NSData dataWithBytes:ctx.out length:ctx.outlen];

    if(kLogVerbose) {
        slog(@"ARGON2: TRANSFORM KEY: %@", [transformKey base64EncodedStringWithOptions:kNilOptions]);
    }

    return transformKey;
}

- (void)rotateHardwareKeyChallenge {
    slog(@"✅ Rotating Argon2 Yubi Challenge");
    
    _salt = getRandomData(kDefaultSaltLength);
}

- (KdfParameters *)kdfParameters {
    NSData* uuidData = self.argon2id ? argon2idCipherUuidData() : argon2dCipherUuidData();
    VariantObject *uuid = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:uuidData];
    
    VariantObject *voIterations = [[VariantObject alloc] initWithType:kVariantTypeUint64 theObject:@(self.innerIterations)];
    VariantObject *voParallelism = [[VariantObject alloc] initWithType:kVariantTypeUint32 theObject:@(self.innerParallelism)];
    VariantObject *voMemory = [[VariantObject alloc] initWithType:kVariantTypeUint64 theObject:@(self.innerMemory)];
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

- (NSData *)transformSeed {
    return self.salt;
}

+ (uint64_t)defaultMemory {
    return kDefaultMemory;
}

+ (uint64_t)defaultIterations {
    return kDefaultIterations;
}

+ (uint32_t)defaultParallelism {
    return kDefaultParallelism;
}

+ (uint64_t)maxRecommendedMemory {
    return kMaxRecommendedMemory;
}

- (uint64_t)iterations {
    return self.innerIterations;
}

- (uint64_t)memory {
    return self.innerMemory;
}

- (uint32_t)parallelism {
    return self.innerParallelism;
}

@end
