//
//  TwoFishReadStream.m
//  Strongbox
//
//  Created by Strongbox on 12/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TwoFishReadStream.h"
#import "tomcrypt.h"
#import "Utils.h"

static const uint32_t kKeySize = 32;
static const uint32_t kBlockSize = 16;

static const size_t kWorkingChunkSize = kBlockSize * 1024 * 8; // NB: Must be a multiple of the Block Size

@interface TwoFishReadStream ()

@property NSInputStream* inputStream;

@property uint8_t* workChunk;
@property size_t workChunkLength;
@property size_t workingChunkOffset;
@property size_t readFromStreamTotal;
@property size_t writtenSoFar;
@property size_t writtenToStreamSoFar;

@property uint8_t* ivBlock;
@property symmetric_key *skey;

@property NSError* error;

@property BOOL lastReadZeroBytes;

@property NSData* lastBlock;

@end

@implementation TwoFishReadStream

- (instancetype)initWithStream:(NSInputStream*)inputStream key:(NSData*)key iv:(NSData*)iv {
    self = [super init];
    if (self) {
        self.inputStream = inputStream;
        
        self.skey = malloc(sizeof(symmetric_key));
        if ((twofish_setup(key.bytes, kKeySize, 0, _skey)) != CRYPT_OK) {
            slog(@"Invalid Key");
            return nil;
        }

        self.ivBlock = malloc(kBlockSize);
        memcpy(self.ivBlock, iv.bytes, kBlockSize);
        
        self.workingChunkOffset = 0;
        self.workChunk = nil;
        self.workChunkLength = 0;
        
        self.lastBlock = NSData.data;
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
    if (self.ivBlock) {
        free(self.ivBlock);
        self.ivBlock = nil;
    }
    if (self.skey) {
        free(self.skey);
        self.skey = nil;
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
            if ( workingAvailable == 0 && self.lastReadZeroBytes ) {
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
    
    uint8_t blk[kWorkingChunkSize];
    uint8_t *block = blk;
    
    NSInteger bytesRead = [self.inputStream read:block maxLength:kWorkingChunkSize];
    if (bytesRead < 0) {
        slog(@"TwoFishReadStream Could not read input stream");
        self.error = self.inputStream.streamError; 
        self.workChunkLength = 0;
        return;
    }
        
    if ( bytesRead > 0 ) {
        NSMutableData* tmp = [NSMutableData dataWithData:self.lastBlock];
        [tmp appendBytes:block length:bytesRead];
        
        block = (uint8_t*)tmp.bytes;
        NSInteger bytesToProcess = tmp.length;
        
        self.readFromStreamTotal += bytesRead;
        
        if (self.workChunk == nil) {
            self.workChunk = malloc(kWorkingChunkSize);
        }
        
        NSInteger numBlocks = bytesToProcess / kBlockSize;
        NSInteger remainder = bytesToProcess % kBlockSize;
        
        if ( remainder == 0 ) {
            numBlocks--;
            uint8_t *lastBlock = block + (numBlocks * kBlockSize);
            self.lastBlock = [NSData dataWithBytes:lastBlock length:kBlockSize];
        }
        else {
            uint8_t *lastBlock = block + (numBlocks);
            self.lastBlock = [NSData dataWithBytes:lastBlock length:remainder];
        }

        uint8_t *ct = block;
        uint8_t pt[kBlockSize];
        for(int block=0;block < numBlocks;block++) {
            twofish_ecb_decrypt(ct, pt, _skey);

            for (int i = 0; i < kBlockSize; i++) {
                pt[i] ^= self.ivBlock[i];
            }
            
            memcpy(&self.workChunk[block*kBlockSize], pt, kBlockSize);
            memcpy(self.ivBlock, ct, kBlockSize);
            ct += kBlockSize;
            self.workChunkLength += kBlockSize;
        }
    }
    else {
        if ( self.lastReadZeroBytes ) {
            return;
        }
        self.lastReadZeroBytes = YES;
        
        
        
        uint8_t ct[kBlockSize] = {0};
        uint8_t pt[kBlockSize] = {0};
        memcpy(ct, self.lastBlock.bytes, self.lastBlock.length);
        
        twofish_ecb_decrypt(ct, pt, _skey);

        for (int i = 0; i < self.lastBlock.length; i++) {
            pt[i] ^= self.ivBlock[i];
        }
        
        
        if ( self.lastBlock.length != kBlockSize ) {
            

            slog(@"Last Block not equal to Block Size! Assuming UnPADDED! WARNWARN");
            
            memcpy(self.workChunk, pt, self.lastBlock.length);
            self.workChunkLength = self.lastBlock.length;
        }
        else {
            BOOL padding = YES;
            
            int paddingLength = pt[kBlockSize-1];
            if(paddingLength <= 0 || paddingLength > kBlockSize)  {
                slog(@"TWOFISH: Padding Byte Out of Range! Assuming Not Padded...");
                padding = NO;
            }
        
            for(int i = kBlockSize - paddingLength; i < kBlockSize; i++) {
                if(pt[i] != paddingLength) {
                    slog(@"TWOFISH: Padding byte not equal expected! Assuming Not Padded...");
                    padding = NO;
                }
            }
            
            if ( padding ) {
                NSInteger remainingLen = self.lastBlock.length - paddingLength;
                
                if ( remainingLen ) {
                    memcpy(self.workChunk, pt, remainingLen);
                    self.workChunkLength = remainingLen;
                }
            }
            else {
                slog(@"Last Block not padded! WARNWARN");
                memcpy(self.workChunk, pt, self.lastBlock.length);
                self.workChunkLength = self.lastBlock.length;
            }
        }
    }
    
    self.writtenSoFar += self.workChunkLength;
    

}

- (NSError *)streamError {
    return self.error;
}

@end


    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
