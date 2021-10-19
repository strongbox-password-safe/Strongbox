//
//  HmacBlockStream.h
//  Strongbox
//
//  Created by Strongbox on 08/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Keys.h"

NS_ASSUME_NONNULL_BEGIN

@interface HmacBlockInputStream : NSInputStream

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStream:(NSInputStream*)stream hmacKey:(NSData*)hmacKey;

NSData* getBlockHmac(NSData *data, NSData* hmacKey, uint64_t blockIndex);
NSData* getHmacKeyForBlock(NSData* key, uint64_t blockIndex);
NSData* getBlockHmacBytes(const uint8_t* data, size_t len, NSData* hmacKey, uint64_t blockIndex);

@end

NS_ASSUME_NONNULL_END
