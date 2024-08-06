//
//  ChaCha20OutputStream.m
//  Strongbox
//
//  Created by Strongbox on 08/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ChaCha20OutputStream.h"
#import "Utils.h"
#import "sodium.h"
#import "Constants.h"

static const uint32_t kBlockSize = 64;

@interface ChaCha20OutputStream ()

@property NSOutputStream* outputStream;
@property NSError* error;

@property NSData* key;
@property NSData* iv;
@property size_t bytesCipheredSoFar;

@property uint8_t* outBuffer;
@property uint8_t* inBuffer;
@property uint8_t* workChunk;
@property size_t workChunkLength;

@property BOOL closed;
@property BOOL opened;

@property NSMutableData* pending;

@end

@implementation ChaCha20OutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream key:(NSData *)key iv:(NSData *)iv {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        self.outputStream = outputStream;
        self.key = key;
        self.iv = iv;
    
        self.workChunkLength = 0;
        self.workChunk = malloc(kStreamingSerializationChunkSize);
        self.outBuffer = malloc(kStreamingSerializationChunkSize + kBlockSize);
        self.inBuffer = malloc(kStreamingSerializationChunkSize + kBlockSize);
        self.pending = NSMutableData.data;
    }
    
    return self;
}

- (void)open {
    if ( self.opened ){
        return;
    }
    self.opened = YES;
}

- (void)close {
    if ( self.closed ){
        return;
    }
    self.closed = YES;
    
    if ( self.pending.length ) {
        [self processChunk:self.pending.bytes length:self.pending.length];
        
        NSInteger wroteThisTime = [self.outputStream write:self.workChunk maxLength:self.workChunkLength]; 
        if ( wroteThisTime < 0 ) {
            slog(@"ChaCha20: Error writing to outputstream");
            return;
        }

    }
    
    self.outputStream = nil;
    free(self.workChunk);
    free(self.outBuffer);
    free(self.inBuffer);
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if ( !self.opened || self.closed ) {
        slog(@"WARNWARN: Unopen or not closed. AES Output Stream");
        return -1;
    }



    [self.pending appendBytes:buffer length:len];
    
    NSUInteger fullBlocks = self.pending.length / kBlockSize;
    NSUInteger lenToProcessThisTime = fullBlocks * kBlockSize;
    
    NSInteger wrote = 0;

    const uint8_t *currentChunk = self.pending.bytes;
    
    while ( lenToProcessThisTime > 0 ) {
        size_t currentLen = MIN ( lenToProcessThisTime, kStreamingSerializationChunkSize );
        
        [self processChunk:currentChunk length:currentLen];
        
        NSInteger wroteThisTime = [self.outputStream write:self.workChunk maxLength:self.workChunkLength];
        if ( wroteThisTime < 0 ) {
            slog(@"ChaCha20: Error writing to outputstream");
            return wroteThisTime;
        }
        
        wrote += wroteThisTime;
        lenToProcessThisTime -= currentLen;
        currentChunk += currentLen;
        

    }
    
    
    
    if ( fullBlocks ) {
        NSUInteger remainderOffset = fullBlocks * kBlockSize;
        NSUInteger remainderLength = self.pending.length - remainderOffset;
        
        self.pending = [NSMutableData dataWithBytes:&self.pending.bytes[remainderOffset] length:remainderLength];
    }
    
    return wrote;
}

- (void)processChunk:(const uint8_t*)plainText length:(size_t)length {
    uint32_t currentBlock = (uint32_t)self.bytesCipheredSoFar / kBlockSize;
    uint32_t offset = self.bytesCipheredSoFar % kBlockSize;

    memset(self.inBuffer, 0, kStreamingSerializationChunkSize + kBlockSize);
    memcpy(&self.inBuffer[offset], plainText, length);

    crypto_stream_chacha20_ietf_xor_ic(self.outBuffer, self.inBuffer, length, self.iv.bytes, currentBlock, self.key.bytes);
    
    memcpy(self.workChunk, &self.outBuffer[offset], length);
    
    self.workChunkLength = length;
    self.bytesCipheredSoFar += length;
}

- (NSError *)streamError {
    return self.outputStream.streamError ? self.outputStream.streamError : self.error;
}

@end
