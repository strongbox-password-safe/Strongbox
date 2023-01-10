//
//  AesKdfCipher.m
//  Strongbox
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AesKdfCipher.h"
#import "Utils.h"
#import "KdbxSerializationCommon.h"
#import "KeePassCiphers.h"
#import "KeePassConstants.h"

static NSString* const kParameterRounds = @"R";
static NSString* const kParameterSeed = @"S";

static const uint64_t kDefaultRounds = 60000;
static const uint32_t kDefaultSeedLength = 32;

@interface AesKdfCipher ()

@property (nonatomic, readonly) NSUUID *uuid; 
@property (nonatomic, readonly) NSData *seed;
@property (nonatomic, readonly) uint64_t rounds;

@end

@implementation AesKdfCipher

- (instancetype)initWithDefaults {
    return [self initWithIterations:kDefaultRounds];
}

- (instancetype)initWithIterations:(uint64_t)iterations {
    self = [super init];
    if (self) {
        _uuid = aesKdbx4KdfCipherUuid();
        _rounds = iterations;
        _seed = getRandomData(kDefaultSeedLength);
    }
    return self;
}

- (instancetype)initWithParametersDictionary:(KdfParameters*)parameters {
    self = [super init];
    if (self) {
        







        _uuid = parameters.uuid;
        
        VariantObject *seed = [parameters.parameters objectForKey:kParameterSeed];
        if(!seed) {
            return nil;
        }
        else {
            _seed = (NSData*)seed.theObject;
        }
        
        
        VariantObject *rounds = [parameters.parameters objectForKey:kParameterRounds];
        if(!rounds) {
            _rounds = kDefaultRounds;
        }
        else {
            _rounds = ((NSNumber*)rounds.theObject).unsignedLongValue;
        }
    }
    
    return self;
}

- (NSData*)deriveKey:(NSData*)data {
    return getAesTransformKey(data, self.seed, self.rounds); 
}

- (KdfParameters *)kdfParameters {
    uuid_t uuid;
    [self.uuid getUUIDBytes:uuid];
    NSData* foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];

    VariantObject *voUuid = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:foo];
    VariantObject *voRound = [[VariantObject alloc] initWithType:kVariantTypeUint64 theObject:@(self.rounds)];
    VariantObject *voSeed = [[VariantObject alloc] initWithType:kVariantTypeByteArray theObject:self.seed];
    
    return [[KdfParameters alloc] initWithParameters:@{ kKdfParametersKeyUuid : voUuid,
                                                        kParameterSeed : voSeed,
                                                        kParameterRounds : voRound }];
}

- (void)rotateHardwareKeyChallenge {

    _seed = getRandomData(kDefaultSeedLength);
}

- (NSData *)transformSeed {
    return self.seed;
}

+ (uint64_t)defaultIterations {
    return kDefaultRounds;
}

- (uint64_t)iterations {
    return self.rounds;
}

@end
