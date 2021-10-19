//
//  Cipher.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Cipher <NSObject>

// Mutable here for Perf reasons, we do some in place insertions in the serializers (see KDBX4 hmacAndBlockify for an example)

- (nullable NSMutableData*)decrypt:(NSData*)data iv:(NSData*)iv key:(NSData*)key;
- (nullable NSMutableData*)encrypt:(NSData*)data iv:(NSData*)iv key:(NSData*)key;
- (nullable NSData*)generateIv;

- (NSInputStream*)getDecryptionStreamForStream:(NSInputStream*)inputStream key:(NSData*)key iv:(NSData*)iv;
- (NSOutputStream*)getEncryptionOutputStreamForStream:(NSOutputStream*)outputStream key:(NSData*)key iv:(NSData*)iv;

@end

NS_ASSUME_NONNULL_END
