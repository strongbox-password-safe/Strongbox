//
//  InnerRandomStreamFactory.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "InnerRandomStreamFactory.h"
#import "KeePassConstants.h"
#import <CommonCrypto/CommonDigest.h>
#import "ChaCha20Stream.h"
#import "Salsa20Stream.h"
#import "PlaintextInnerStream.h"

@implementation InnerRandomStreamFactory

+(id<InnerRandomStream>)getStream:(uint32_t)streamId key:(NSData *)key {
    return [InnerRandomStreamFactory getStream:streamId key:key createNewKeyIfAbsent:YES];
}

+ (id<InnerRandomStream>)getStream:(uint32_t)streamId
                               key:(NSData *)key
              createNewKeyIfAbsent:(BOOL)createNewKeyIfAbsent {
    if(streamId == kInnerStreamSalsa20) {
        if (key != nil || createNewKeyIfAbsent) {
            return [[Salsa20Stream alloc] initWithKey:key];
        }
        else {
            return nil;
        }
    }
    else if (streamId == kInnerStreamArc4) {
        slog(@"ARC4 not supported = %d", streamId);
        
        return nil;
    }
    else if (streamId == kInnerStreamChaCha20) {
        if (key != nil || createNewKeyIfAbsent) {
            return [[ChaCha20Stream alloc] initWithKey:key];
        }
        else {
            return nil;
        }
    }
    else if (streamId == kInnerStreamPlainText) {
        return [[PlaintextInnerStream alloc] init];
    }
    else {
        slog(@"Unknown innerRandomStreamId = %d", streamId);
        return nil;
    }
}

@end
