//
//  Argon2dKdfCipher.m
//  Strongbox
//
//  Created by Strongbox on 13/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "Argon2dKdfCipher.h"

@implementation Argon2dKdfCipher

- (instancetype)initWithDefaults {
    return [super initWithDefaults:NO];
}

- (instancetype)initWithMemory:(uint64_t)memory parallelism:(uint32_t)parallelism iterations:(uint64_t)iterations {
    return [super initWithArgon2id:NO memory:memory parallelism:parallelism iterations:iterations];
}

@end
