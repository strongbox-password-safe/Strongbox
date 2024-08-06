//
//  TwoFishOutputStream.m
//  Strongbox
//
//  Created by Strongbox on 09/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "TwoFishOutputStream.h"
#import "Utils.h"
#import "Constants.h"
#import "tomcrypt.h"

@interface TwoFishOutputStream ()

@property NSOutputStream* outputStream;
@property NSError* error;

@property uint8_t* ivBlock;
@property symmetric_key *skey;

@property size_t bytesCipheredSoFar;

@property uint8_t* workChunk;
@property size_t workChunkLength;

@property BOOL closed;
@property BOOL opened;

@property NSMutableData* pending;

@end

static const uint32_t kKeySize = 32;
static const uint32_t kBlockSize = 16;

@implementation TwoFishOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream key:(NSData *)key iv:(NSData *)iv {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        self.outputStream = outputStream;
        
        self.skey = malloc(sizeof(symmetric_key));
        if ((twofish_setup(key.bytes, kKeySize, 0, _skey)) != CRYPT_OK) {
            slog(@"Invalid Key");
            return nil;
        }

        self.ivBlock = malloc(kBlockSize);
        memcpy(self.ivBlock, iv.bytes, kBlockSize);
    
        self.workChunkLength = 0;
        self.workChunk = malloc(kStreamingSerializationChunkSize);
                
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
    
    if ( (YES) /* self.pending.length */ ) { 
        [self processChunk:self.pending.bytes length:self.pending.length];
        
        NSInteger wroteThisTime = [self.outputStream write:self.workChunk maxLength:self.workChunkLength];
        if ( wroteThisTime < 0 ) {
            slog(@"TwoFish: Error writing to outputstream");
            return;
        }
    }
    
    self.outputStream = nil;
    free(self.workChunk);
    
    if (self.ivBlock) {
        free(self.ivBlock);
        self.ivBlock = nil;
    }
    if (self.skey) {
        free(self.skey);
        self.skey = nil;
    }
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
            slog(@"TwoFish: Error writing to outputstream");
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
    self.workChunkLength = 0;

    int numBlocks = (int)length / kBlockSize;
    
    uint8_t ct[kBlockSize];
    uint8_t ptBar[kBlockSize];
    
    memcpy(ct, self.ivBlock, kBlockSize); 

    const uint8_t* pt = plainText;
    
    if ( numBlocks == 0 ) {


        

        uint8_t padLen = kBlockSize - (length - (kBlockSize * numBlocks));

        for (size_t j = 0; j < kBlockSize - padLen; j++) {
            ptBar[j] = ct[j] ^ pt[j];
        }
        
        for (size_t i = kBlockSize - padLen; i < kBlockSize; i++) {
            ptBar[i] = ct[i] ^ padLen;
        }

        twofish_ecb_encrypt(ptBar, ct, _skey);
        
        memcpy(self.workChunk, ct, kBlockSize);
        self.workChunkLength = kBlockSize;
    }
    else {
        for (int i = 0; i < numBlocks; i++) {
            for (int j = 0; j < kBlockSize; j++) {
                ptBar[j] = pt[j] ^ ct[j];
            }

            twofish_ecb_encrypt(ptBar, ct, _skey);
            
            memcpy(&self.workChunk[i * kBlockSize], ct, kBlockSize);
            
            pt += kBlockSize;
            self.workChunkLength += kBlockSize;
        }
    
        memcpy(self.ivBlock, ct, kBlockSize); 
    }
    
    self.bytesCipheredSoFar += length;
}

- (NSError *)streamError {
    return self.outputStream.streamError ? self.outputStream.streamError : self.error;
}

@end

