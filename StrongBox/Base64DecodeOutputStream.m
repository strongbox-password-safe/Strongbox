//
//  Base64DecodeOutputStream.m
//  Strongbox
//
//  Created by Strongbox on 26/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Base64DecodeOutputStream.h"
#import "cdecode.h"

@interface Base64DecodeOutputStream ()

@property base64_decodestate* decodeState;
@property NSOutputStream* outputStream;
@property NSError* error;

@end

@implementation Base64DecodeOutputStream

- (instancetype)initToOutputStream:(NSOutputStream*)outputStream {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        self.decodeState = malloc(sizeof(base64_decodestate));
        
        base64_init_decodestate(_decodeState);
        
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
    if (self.outputStream) {
        [self.outputStream close];
        self.outputStream = nil;
    }
    
    if (self.decodeState) {
        free(self.decodeState);
        self.decodeState = nil;
    }
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    uint8_t* plaintext = malloc(len); 
    
    int decoded = base64_decode_block((const char*)buffer, (int)len, (char*)plaintext, self.decodeState);
    
    NSInteger ret = decoded;
    if (decoded > 0) {
        ret = [self.outputStream write:plaintext maxLength:decoded];
    }

    free(plaintext);
    
    return ret;
}

- (NSError *)streamError {
    return self.error ? self.error : self.outputStream.streamError;
}

@end
