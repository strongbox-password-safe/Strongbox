//
//  Argon2KdfCipher.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Argon2KdfCipher : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithParametersDictionary:(NSDictionary<NSString*, NSObject*>*)parameters NS_DESIGNATED_INITIALIZER;

- (NSData*)deriveKey:(NSData*)data;

@property (nonatomic, readonly) NSData *salt;
@property (nonatomic, readonly) uint32_t parallelism;
@property (nonatomic, readonly) uint64_t memory;
@property (nonatomic, readonly) uint64_t iterations;
@property (nonatomic, readonly) uint32_t version;
@property (nonatomic, readonly) NSData *secretKey; // TODO: Used?
@property (nonatomic, readonly) NSData *assocData; // TODO: Used?

@end

NS_ASSUME_NONNULL_END
