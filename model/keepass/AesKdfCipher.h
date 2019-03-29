//
//  AesKdfCipher.h
//  Strongbox
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KeyDerivationCipher.h"

NS_ASSUME_NONNULL_BEGIN

@interface AesKdfCipher : NSObject<KeyDerivationCipher>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDefaults;
- (instancetype)initWithParametersDictionary:(KdfParameters*)parameters;

- (NSData*)deriveKey:(NSData*)data;

@property (readonly, nonatomic) KdfParameters* kdfParameters;

@end

NS_ASSUME_NONNULL_END
