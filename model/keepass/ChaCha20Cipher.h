//
//  ChaCha20Cipher.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Cipher.h"
#import "InnerRandomStream.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChaCha20Cipher : NSObject<Cipher>

- (NSData*)decrypt:(NSData*)data iv:(NSData*)iv key:(NSData*)key;
- (NSData*)encrypt:(NSData*)data iv:(NSData*)iv key:(NSData*)key;
- (NSData*)generateIv;

@end

NS_ASSUME_NONNULL_END
