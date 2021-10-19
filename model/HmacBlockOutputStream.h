//
//  HmacBlockOutputStream.h
//  Strongbox
//
//  Created by Strongbox on 04/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HmacBlockOutputStream : NSOutputStream

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStream:(NSOutputStream*)stream hmacKey:(NSData*)hmacKey;

@end

NS_ASSUME_NONNULL_END
