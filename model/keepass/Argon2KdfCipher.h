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
- (instancetype)initWithParametersDictionary:(KdfParameters*)parameters;

- (NSData*)deriveKey:(NSData*)data;

@property (readonly, nonatomic) KdfParameters* kdfParameters;

@end

NS_ASSUME_NONNULL_END
