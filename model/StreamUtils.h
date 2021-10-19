//
//  StreamUtils.h
//  Strongbox
//
//  Created by Strongbox on 29/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StreamUtils : NSObject

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream
                    to:(NSOutputStream*)outputStream;

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream
                    to:(NSOutputStream*)outputStream
   openAndCloseStreams:(BOOL)openAndCloseStreams;

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream
                    to:(NSOutputStream*)outputStream
   openAndCloseStreams:(BOOL)openAndCloseStreams
   randomizeChunkSizes:(BOOL)randomizeChunkSizes;

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream
                    to:(NSOutputStream*)outputStream
   openAndCloseStreams:(BOOL)openAndCloseStreams
             chunkSize:(NSUInteger)chunkSize;

+ (NSData*)readAll:(NSInputStream*)inputStream;

+ (NSData*)readAll:(NSInputStream*)inputStream randomizeChunkSizes:(BOOL)randomizeChunkSizes;

@end

NS_ASSUME_NONNULL_END
