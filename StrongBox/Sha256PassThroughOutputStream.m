//
//  Sha256OutputStream.m
//  Strongbox
//
//  Created by Strongbox on 26/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Sha256PassThroughOutputStream.h"

#import <CommonCrypto/CommonCrypto.h>
@interface Sha256PassThroughOutputStream ()

@property NSOutputStream* outputStream;
@property NSError* error;
@property CC_SHA256_CTX *sha256context;
@property NSData* digest;

@end

@implementation Sha256PassThroughOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        self.sha256context = malloc(sizeof(CC_SHA256_CTX));
        
        CC_SHA256_Init(_sha256context);

        _length = 0;
        _digest = nil;
        
        self.outputStream = outputStream;
    }
    
    return self;
}

- (void)open {
    if (self.outputStream) {
        [self.outputStream open];
    }
}

- (void)close {
    if (self.outputStream == nil) {
        return;
    }
        
    NSMutableData* foo = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(foo.mutableBytes, _sha256context);

    [self.outputStream close];
    self.outputStream = nil;
    
    free(self.sha256context);
    self.sha256context = nil;
    
    _digest = foo;
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    CC_SHA256_Update(_sha256context, buffer, (CC_LONG)len);

    _length += len;
    
    return [self.outputStream write:buffer maxLength:len];
}

- (NSError *)streamError {
    return self.outputStream.streamError ? self.outputStream.streamError : self.error;
}

@end
