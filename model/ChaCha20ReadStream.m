//
//  ChaCha20ReadStream.m
//  Strongbox
//
//  Created by Strongbox on 12/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ChaCha20ReadStream.h"
#import "sodium.h"
#import "Utils.h"
#import "Constants.h"

static const uint32_t kBlockSize = 64;

@interface ChaCha20ReadStream ()

@property NSInputStream* inputStream;

@property uint8_t* workChunk;
@property size_t workChunkLength;
@property size_t workingChunkOffset;

@property size_t bytesDecrypted;
@property size_t readFromStreamTotal;
@property size_t writtenSoFar;
@property size_t writtenToStreamSoFar;

@property NSData* key;
@property NSData* iv;

@property uint8_t* chacha20DecryptBuffer;
@property uint8_t* chacha20EncryptBuffer;

@property NSError* error;

@end

@implementation ChaCha20ReadStream

- (instancetype)initWithStream:(NSInputStream*)inputStream key:(NSData*)key iv:(NSData*)iv {
    self = [super init];
    if (self) {
        self.inputStream = inputStream;
        self.key = key;
        self.iv = iv;
        self.workingChunkOffset = 0;
        self.workChunk = nil;
        self.workChunkLength = 0;
    }
    return self;
}

- (void)open {
    [self.inputStream open];
}

- (void)close {
    [self.inputStream close];
    
    if (self.workChunk) {
        free(self.workChunk);
        self.workChunk = nil;
    }
    
    if (self.chacha20DecryptBuffer) {
        free(self.chacha20DecryptBuffer);
        self.chacha20DecryptBuffer = nil;
        free(self.chacha20EncryptBuffer);
        self.chacha20EncryptBuffer = nil;
    }
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (self.workChunk != nil && self.workChunkLength == 0) { 
        return 0L;
    }
    
    size_t bufferOffset = 0;
    size_t bufferWritten = 0;
        
    while ( bufferWritten < len ) {
        size_t workingAvailable = self.workChunkLength - self.workingChunkOffset;

        if (workingAvailable == 0) {
            [self loadNextWorkingChunk];
        
            if (self.workChunk == nil) {
                return -1L;
            }
        
            workingAvailable = self.workChunkLength - self.workingChunkOffset;
            if (workingAvailable == 0) {
                return bufferWritten; 
            }
        }

        size_t bufferAvailable = len - bufferOffset;
        size_t bytesToWrite = MIN(workingAvailable, bufferAvailable);

        uint8_t* src = &self.workChunk[self.workingChunkOffset];
        uint8_t* dst = &buffer[bufferOffset];

        memcpy(dst, src, bytesToWrite);
    
        self.writtenToStreamSoFar += bytesToWrite;
        

        bufferWritten += bytesToWrite;
        bufferOffset += bytesToWrite;
        self.workingChunkOffset += bytesToWrite;
    }
        
    return bufferWritten;
}

- (void)loadNextWorkingChunk {
    self.workChunkLength = 0;
    self.workingChunkOffset = 0;
    
    uint8_t *block = malloc(kStreamingSerializationChunkSize);
    
    NSInteger bytesRead = [self.inputStream read:block maxLength:kStreamingSerializationChunkSize];
    
    self.readFromStreamTotal += bytesRead;
    
    if (bytesRead < 0) {
        slog(@"ChaCha20ReadStream Could not read input stream");
        self.error = self.inputStream.streamError; 
        self.workChunk = nil;
        self.workChunkLength = 0;
        free(block);
        return;
    }

    if (self.workChunk == nil) {
        self.workChunk = malloc(kStreamingSerializationChunkSize);
    }
    
    if (bytesRead == 0) {
        self.writtenSoFar += self.workChunkLength;
    }
    else {
        [self decryptAnotherChunk:block length:bytesRead];
        
    }
    
    free(block);
}

- (void)decryptAnotherChunk:(uint8_t*)ct length:(size_t)length {
    if (!self.chacha20DecryptBuffer) {
        self.chacha20DecryptBuffer = malloc(kStreamingSerializationChunkSize + kBlockSize);
        self.chacha20EncryptBuffer = malloc(kStreamingSerializationChunkSize + kBlockSize);
    }

    uint32_t currentBlock = (uint32_t)self.bytesDecrypted / kBlockSize;
    uint32_t offset = self.bytesDecrypted % kBlockSize;

    memset(self.chacha20EncryptBuffer, 0, kStreamingSerializationChunkSize + kBlockSize);
    memcpy(&self.chacha20EncryptBuffer[offset], ct, length);

    crypto_stream_chacha20_ietf_xor_ic(self.chacha20DecryptBuffer, self.chacha20EncryptBuffer, length, self.iv.bytes, currentBlock, self.key.bytes);
    
    memcpy(self.workChunk, &self.chacha20DecryptBuffer[offset], length);
    
    self.workChunkLength = length;
    self.writtenSoFar += self.workChunkLength;
    self.bytesDecrypted += length;
}

- (NSError *)streamError {
    return self.error;
}

@end
