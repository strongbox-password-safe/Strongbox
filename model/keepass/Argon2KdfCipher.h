//
//  Argon2KdfCipher.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KeyDerivationCipher.h"

NS_ASSUME_NONNULL_BEGIN

@interface Argon2KdfCipher : NSObject<KeyDerivationCipher>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDefaults:(BOOL)argon2id;
- (instancetype)initWithArgon2id:(BOOL)argon2id memory:(uint64_t)memory parallelism:(uint32_t)parallelism iterations:(uint64_t)iterations;
- (instancetype)initWithParametersDictionary:(KdfParameters*)parameters;

- (NSData*)deriveKey:(NSData*)data;

@property (readonly, nonatomic) KdfParameters* kdfParameters;

@property (class, readonly) uint64_t defaultMemory;
@property (class, readonly) uint64_t defaultIterations;
@property (class, readonly) uint32_t defaultParallelism;
@property (class, readonly) uint64_t maxRecommendedMemory;

@property (readonly) uint64_t memory;
@property (readonly) uint64_t iterations;
@property (readonly) uint32_t parallelism;


@end

NS_ASSUME_NONNULL_END
