//
//  HashedBlockStream.m
//  Strongbox
//
//  Created by Strongbox on 12/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KP31HashedBlockStream.h"
#import "Utils.h"
#import "KdbxSerialization.h"
#import <CommonCrypto/CommonCrypto.h>
#import "Utils.h"

@interface KP31HashedBlockStream ()

@property NSInputStream* inputStream;
@property NSUInteger workingBlockOffset;
@property uint8_t* workingBlock;
@property size_t workingBlockLength;
@property int workingBlockIndex;
@property size_t readSoFar;
@property NSError* error;

@end

@implementation KP31HashedBlockStream

- (instancetype)initWithStream:(NSInputStream *)stream {
    self = [super init];
    if (self) {
        self.inputStream = stream;
    }
    return self;
}

- (void)open {
    [self.inputStream open];
}

- (void)close {
    [self.inputStream close];
    [self cleanupWorkingBlock];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    NSUInteger bufferWritten = 0;
    NSUInteger bufferOffset = 0;
    
    while (bufferWritten < len) {
        NSUInteger bufferAvailable = len - bufferWritten;
        NSUInteger workingAvailable = self.workingBlockLength - self.workingBlockOffset;

        if (self.workingBlock == nil || workingAvailable == 0)  {
            if (! [self loadNextBlock] ) {
                slog(@"KP31HashedBlockStream: Error Reading next working Block");
                return -1;
            }
            
            if (self.workingBlockLength == 0) { 
                break;
            }
        }
        
        workingAvailable = self.workingBlockLength - self.workingBlockOffset;
        NSUInteger bytesToWriteToBuffer = MIN(bufferAvailable, workingAvailable);
        
        uint8_t *src = &self.workingBlock[self.workingBlockOffset];
        uint8_t *dest = &buffer[bufferOffset];
    
        memcpy(dest, src, bytesToWriteToBuffer);
        
        bufferWritten += bytesToWriteToBuffer;
        bufferOffset += bytesToWriteToBuffer;
        self.workingBlockOffset += bytesToWriteToBuffer;
    }
    
    return bufferWritten;
}

- (BOOL)loadNextBlock {
    BlockHeader block;
    NSInteger read = [self.inputStream read:(uint8_t*)&block maxLength:SIZE_OF_BLOCK_HEADER];
    
    if (read < 0) {
        slog(@"Error reading Block Header... [%zu]", read);
        self.error = [Utils createNSError:@"Error reading Block Header" errorCode:-1];
        [self cleanupWorkingBlock];
        return NO;
    }
    
    if (read == 0) { 
        [self cleanupWorkingBlock];
        return YES;
    }
    
    if (read != SIZE_OF_BLOCK_HEADER) {
        [self cleanupWorkingBlock];
        slog(@"Couldn't read all of Block Header... [%zu]", read);
        self.error = [Utils createNSError:@"Couldn't read all of Block Header..." errorCode:-1];
        return NO;
    }
        
    size_t blockLength = littleEndian4BytesToUInt32(block.size);
    if (blockLength > 0) {
        [self cleanupWorkingBlock];
        self.workingBlock = malloc(blockLength);
        self.workingBlockLength = blockLength;

        read = [self.inputStream read:self.workingBlock maxLength:blockLength];
        if (read != blockLength) {
            [self cleanupWorkingBlock];
            slog(@"Couldn't read all of Block... [%zu] but wanted [%zu]", read, blockLength);
            self.error = [Utils createNSError:@"Couldn't read all of Block..." errorCode:-1];
            return NO;
        }
        
        uint8_t actualHashBytes[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(self.workingBlock, (uint32_t)self.workingBlockLength, actualHashBytes);
        if (memcmp(actualHashBytes, block.hash, CC_SHA256_DIGEST_LENGTH) != 0) {
            slog(@"Block Header Hash does not match content. This safe is possibly corrupt.");
            self.error = [Utils createNSError:@"Block Header Hash does not match content. This safe is possibly corrupt." errorCode:-1];
            [self cleanupWorkingBlock];
            return NO;
        }
    }
    else {
        [self cleanupWorkingBlock]; 
    }
    
    self.readSoFar += blockLength;
    
    self.workingBlockIndex++;
    self.workingBlockOffset = 0;
    
    return YES;
}

- (void)cleanupWorkingBlock {
    if (self.workingBlock) {
        free(self.workingBlock);
    }
    self.workingBlock = nil;
    self.workingBlockLength = 0;
}

- (NSError *)streamError {
    return self.error;
}

@end
