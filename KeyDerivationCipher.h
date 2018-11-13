//
//  KeyDerivationCipher.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VariantObject.h"
#import "KdfParameters.h"

NS_ASSUME_NONNULL_BEGIN

@protocol KeyDerivationCipher <NSObject>

- (instancetype)initWithParametersDictionary:(NSDictionary<NSString*, VariantObject*>*)parameters;
- (NSData*)deriveKey:(NSData*)data;

@property (readonly, nonatomic) KdfParameters* kdfParameters;

@end

NS_ASSUME_NONNULL_END
