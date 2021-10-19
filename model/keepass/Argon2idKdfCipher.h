//
//  Argon2idKdfCipher.h
//  Strongbox
//
//  Created by Strongbox on 13/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Argon2KdfCipher.h"

NS_ASSUME_NONNULL_BEGIN

@interface Argon2idKdfCipher : Argon2KdfCipher <KeyDerivationCipher>

- (instancetype)initWithDefaults;
- (instancetype)initWithMemory:(uint64_t)memory parallelism:(uint32_t)parallelism iterations:(uint64_t)iterations;

@end

NS_ASSUME_NONNULL_END
