//
//  StreamUtils.m
//  Strongbox
//
//  Created by Strongbox on 29/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "StreamUtils.h"

@implementation StreamUtils

+ (BOOL)pipeFromStream:(NSInputStream*)inputStream to:(NSOutputStream*)outputStream {
    [inputStream open];
    [outputStream open];
    
    NSInteger read;
    const NSUInteger kChunkLength = 32 * 1024;
    uint8_t chunk[kChunkLength];
    
    while ( (read = [inputStream read:chunk maxLength:kChunkLength]) > 0 ) {
        [outputStream write:chunk maxLength:read];
    }
    
    [outputStream close];
    [inputStream close];

    return (read == 0);
}

@end
