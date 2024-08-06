//
//  LoggingInputStream.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface LoggingInputStream : NSInputStream

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStream:(NSInputStream*)stream;

- (void)open;
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL)hasBytesAvailable;
- (void)close;

@end

NS_ASSUME_NONNULL_END
