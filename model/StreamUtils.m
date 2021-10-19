//
//  StreamUtils.m
//  Strongbox
//
//  Created by Strongbox on 29/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StreamUtils.h"

@implementation StreamUtils

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream to:(NSOutputStream*)outputStream {
    return [self pipeFromStream:inputStream to:outputStream openAndCloseStreams:YES randomizeChunkSizes:NO];
}

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream to:(NSOutputStream*)outputStream openAndCloseStreams:(BOOL)openAndCloseStreams {
    return [self pipeFromStream:inputStream to:outputStream openAndCloseStreams:openAndCloseStreams randomizeChunkSizes:NO];
}

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream
                    to:(NSOutputStream*)outputStream
   openAndCloseStreams:(BOOL)openAndCloseStreams
   randomizeChunkSizes:(BOOL)randomizeChunkSizes {
    const NSUInteger kChunkLength = randomizeChunkSizes ? (arc4random_uniform(32 * 1024) + 1)  : 32 * 1024;

    return [self pipeFromStream:inputStream to:outputStream openAndCloseStreams:openAndCloseStreams chunkSize:kChunkLength];
}

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream
                    to:(NSOutputStream*)outputStream
   openAndCloseStreams:(BOOL)openAndCloseStreams
             chunkSize:(NSUInteger)chunkSize {
    if ( openAndCloseStreams ) {
        [inputStream open];
        [outputStream open];
    }
    
    NSInteger read;
    uint8_t chunk[chunkSize];
    
    while ( (read = [inputStream read:chunk maxLength:chunkSize]) > 0 ) {
        [outputStream write:chunk maxLength:read];
    }
    
    if ( openAndCloseStreams ) {
        [outputStream close];
        [inputStream close];
    }

    return (read == 0);
}

+ (NSData*)readAll:(NSInputStream*)inputStream {
    return [StreamUtils readAll:inputStream randomizeChunkSizes:NO];
}

+ (NSData*)readAll:(NSInputStream*)inputStream randomizeChunkSizes:(BOOL)randomizeChunkSizes {
    [inputStream open];
    
    NSInteger read;
    
    const NSUInteger kChunkLength = randomizeChunkSizes ? (arc4random_uniform(32 * 1024) + 1) : 32 * 1024;

    uint8_t chunk[kChunkLength];
    
    NSMutableData* ret = NSMutableData.data;
    
    while ( (read = [inputStream read:chunk maxLength:kChunkLength]) > 0 ) {
        [ret appendBytes:chunk length:read];
    }
    [inputStream close];

    return ret.copy;
}

@end
