//
//  InnerRandomStreamFactory.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "InnerRandomStreamFactory.h"
#import "KeePassConstants.h"
#import <CommonCrypto/CommonDigest.h>
#import "ChaCha20Stream.h"
#import "Salsa20Stream.h"

@implementation InnerRandomStreamFactory

+(id<InnerRandomStream>)getStream:(uint32_t)streamId key:(NSData *)key {
    if(streamId == kInnerStreamSalsa20) {
        return [[Salsa20Stream alloc] initWithKey:key];
    }
    else if (streamId == kInnerStreamArc4) {
        NSLog(@"ARC4 not supported = %d", streamId);
        // FUTURE: Support this for older DBs? Hard to find any samples... Low Priority
        return nil;
    }
    else if (streamId == kInnerStreamChaCha20) {
        return [[ChaCha20Stream alloc] initWithKey:key];
    }
    else if (streamId == kInnerStreamPlainText) {
        return nil;
    }
    else {
        NSLog(@"Unknown innerRandomStreamId = %d", streamId);
        return nil;
    }
}

@end
