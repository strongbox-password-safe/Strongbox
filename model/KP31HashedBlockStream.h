//
//  HashedBlockStream.h
//  Strongbox
//
//  Created by Strongbox on 12/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KP31HashedBlockStream : NSInputStream

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStream:(NSInputStream *)stream;

@end

NS_ASSUME_NONNULL_END
