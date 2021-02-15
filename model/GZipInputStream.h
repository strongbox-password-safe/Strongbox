//
//  ZLibMMcG.h
//  Strongbox
//
//  Created by Mark on 07/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GZipInputStream : NSInputStream

- (instancetype)initWithStream:(NSInputStream *)innerStream;
- (instancetype)initWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
