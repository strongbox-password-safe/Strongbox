//
//  Argon2dKdfCipher.h
//  Strongbox
//
//  Created by Strongbox on 13/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Argon2KdfCipher.h"

NS_ASSUME_NONNULL_BEGIN

@interface Argon2dKdfCipher : Argon2KdfCipher <KeyDerivationCipher>

- (instancetype)initWithDefaults;

@end

NS_ASSUME_NONNULL_END
