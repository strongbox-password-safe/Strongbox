//
//  TwoFishReadStream.m
//  Strongbox
//
//  Created by Strongbox on 12/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
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

@end

@implementation TwoFishReadStream

- (instancetype)initWithStream:(NSInputStream*)inputStream key:(NSData*)key iv:(NSData*)iv {
    self = [super init];
    if (self) {
        self.inputStream = inputStream;
        
        self.skey = malloc(sizeof(symmetric_key));
        if ((twofish_setup(key.bytes, kKeySize, 0, _skey)) != CRYPT_OK) {
            NSLog(@"Invalid Key");
            return nil;
        }

        self.ivBlock = malloc(kBlockSize);
        memcpy(self.ivBlock, iv.bytes, kBlockSize);
        
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
    
    uint8_t block[kWorkingChunkSize];
    NSInteger bytesRead = [self.inputStream read:block maxLength:kWorkingChunkSize];
    if (bytesRead < 0) {
        NSLog(@"TwoFishReadStream Could not read input stream");
        self.error = self.inputStream.streamError; 
        self.workChunkLength = 0;
        return;
    }
    
    self.readFromStreamTotal += bytesRead;
    
    if (self.workChunk == nil) {
        self.workChunk = malloc(kWorkingChunkSize);
    }
    
    uint64_t numBlocks = bytesRead / kBlockSize;
    size_t remainder = bytesRead % kBlockSize;
    
    if (bytesRead == 0 || remainder != 0)  {
        if (bytesRead != 0 && bytesRead != remainder ) {
            self.error = [Utils createNSError:@"TwoFishReadStream: bytesRead != 0 && bytesRead != remainder" errorCode:-1];
            self.workChunkLength = 0;
            return;
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
        }
        
        self.writtenSoFar += self.workChunkLength;
        NSLog(@"DECRYPT FINAL: bytesRead = %zu, decWritten = %zu, totalRead = [%zu], writtenSoFar = %zu", bytesRead, self.workChunkLength, self.readFromStreamTotal, self.writtenSoFar);
    }
    else {
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
        }
            
        self.workChunkLength = bytesRead;
        self.writtenSoFar += self.workChunkLength;
        
    }
}

- (NSError *)streamError {
    return self.error;
}

@end
