//
//  ChaCha20Cipher.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChaCha20Cipher : NSObject

- (NSData*)decrypt:(NSData*)data iv:(NSData*)iv key:(NSData*)key;

@end

NS_ASSUME_NONNULL_END
