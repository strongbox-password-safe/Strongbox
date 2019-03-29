//
//  AesKdfCipher.m
//  Strongbox
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
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

@property (nonatomic, readonly) NSUUID *uuid; // Maintain whatever we are initialized with...
@property (nonatomic, readonly) NSData *seed;
@property (nonatomic, readonly) uint64_t rounds;

@end

@implementation AesKdfCipher

- (instancetype)initWithDefaults
{
    self = [super init];
    if (self) {
        _uuid = aesKdbx4KdfCipherUuid();
        _rounds = kDefaultRounds;
        _seed = getRandomData(kDefaultSeedLength);
    }
    return self;
}

- (instancetype)initWithParametersDictionary:(KdfParameters*)parameters {
    self = [super init];
    if (self) {
        //NSLog(@"AES KDF: %@", parameters);

//        2019-03-26 12:17:39.119800+0100 Strongbox[15451:171707] AES KDF: {
//            "$UUID" = "Type-66: <c9d9f39a 628a4460 bf740d08 c18a4fea>";
//            R = "Type-5: 23255814";
//            S = "Type-66: <9814438c 07d99382 8a3971f6 39e534e7 2a5a46a6 244b2972 28177eae 81717638>";
//        }

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
    return getAesTransformKey(data, self.seed, self.rounds); // Standard KDBX 3 KDF Function
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


@end
