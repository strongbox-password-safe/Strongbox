//
//  HmacBlockStream.m
//  Strongbox
//
//  Created by Strongbox on 08/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "HmacBlockInputStream.h"
#import "Kdbx4Serialization.h"
#import "Utils.h"
#import <CommonCrypto/CommonCrypto.h>
#import "KeePassCiphers.h"
#import "Utils.h"

@interface HmacBlockInputStream ()

@property NSUInteger workingBlockOffset;
@property uint8_t* workingBlock;
@property size_t workingBlockLength;
@property int workingBlockIndex;

@property NSData *hmacKey;
@property size_t readSoFar;

@property NSError* error;

@property NSInputStream* innerStream;
@property BOOL finished;

@end

@implementation HmacBlockInputStream

- (instancetype)initWithStream:(NSInputStream *)stream hmacKey:(NSData *)hmacKey {
    if (self = [super init]) {
        if (!stream) {
            return nil;
        }
        
        self.workingBlock = nil;
        self.workingBlockOffset = 0;
        self.workingBlockIndex = 0;
        self.hmacKey = hmacKey;
        self.innerStream = stream;
        self.finished = NO;
    }
    
    return self;
}

- (void)open {
    if (self.innerStream) {
        [self.innerStream open];
    }
}

- (void)close {
    if (self.innerStream) {
        [self.innerStream close];
        self.innerStream = nil;
    }
    
    if (self.workingBlock) {
        free(self.workingBlock);
    }
    self.workingBlock = nil;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)maxLength {
    NSUInteger bufferWritten = 0;
    NSUInteger bufferOffset = 0;
    
    while (bufferWritten < maxLength) {
        NSUInteger bufferAvailable = maxLength - bufferWritten;
        NSUInteger workingAvailable = self.workingBlockLength - self.workingBlockOffset;

        if (self.workingBlock == nil || workingAvailable == 0)  {
            if (! [self loadNextBlock] ) {
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
    if (self.finished) { 
        if (self.workingBlock) {
            free(self.workingBlock);
        }
        self.workingBlock = nil;
        self.workingBlockLength = 0;
        return YES;
    }

    HmacBlockHeader blockHeader;
    NSInteger bytesRead = [self.innerStream read:(uint8_t*)&blockHeader maxLength:SIZE_OF_HMAC_BLOCK_HEADER];
    if (bytesRead != SIZE_OF_HMAC_BLOCK_HEADER) {
        return NO;
    }
    
    size_t blockLength = littleEndian4BytesToUInt32(blockHeader.lengthBytes);
    
    
    if (blockLength > 0) {
        if (self.workingBlock != nil) {
            free(self.workingBlock);
        }
        self.workingBlock = malloc(blockLength);
                                   
        bytesRead = [self.innerStream read:self.workingBlock maxLength:blockLength];
        if(bytesRead < 0 || bytesRead < blockLength) {
            slog(@"Not enough data to decrypt Block! [%@]", self.innerStream.streamError);
            self.error = self.innerStream.streamError ? self.innerStream.streamError : [Utils createNSError:@"Error: HmacBlocStream - Could not read enough from inner stream to decrypt block." errorCode:-1];
            free(self.workingBlock);
            self.workingBlock = nil;
            self.workingBlockLength = 0;
            self.finished = YES;
            return NO;
        }
        
        self.workingBlockLength = blockLength;
        
        NSData *actualHmac = getBlockHmacBytes(self.workingBlock, self.workingBlockLength, self.hmacKey, self.workingBlockIndex);
        NSData *expectedHmac = [NSData dataWithBytes:blockHeader.hmacSha256 length:CC_SHA256_DIGEST_LENGTH];

        if(![actualHmac isEqualToData:expectedHmac]) {
            slog(@"Actual Block HMAC does not match expected. Block has been corrupted.");
            self.error = [Utils createNSError:@"Actual Block HMAC does not match expected. Block has been corrupted." errorCode:-1];
            self.workingBlock = nil;
            self.finished = YES;
            return NO;
        }
    }
    else {
        if (self.workingBlock) {
            free(self.workingBlock);
        }
        self.workingBlock = nil;
        self.workingBlockLength = 0;
        self.finished = YES;
    }
    
    self.readSoFar += blockLength;
    
    

    self.workingBlockIndex++;
    self.workingBlockOffset = 0;
    
    return YES;
}

NSData* getBlockHmac(NSData *data, NSData* hmacKey, uint64_t blockIndex) {
    return getBlockHmacBytes((uint8_t*)data.bytes, data.length, hmacKey, blockIndex);
}

NSData* getBlockHmacBytes(const uint8_t* data, size_t len, NSData* hmacKey, uint64_t blockIndex) {
    NSData* blockKey = getHmacKeyForBlock(hmacKey, blockIndex);
    NSData* index = Uint64ToLittleEndianData(blockIndex);
    NSData* blockSizeData = Uint32ToLittleEndianData((uint32_t)len);

    CCHmacContext ctx;
    CCHmacInit(&ctx, kCCHmacAlgSHA256, blockKey.bytes, blockKey.length);
    CCHmacUpdate(&ctx, index.bytes, index.length);
    CCHmacUpdate(&ctx, blockSizeData.bytes, blockSizeData.length);

    if(len){
        CCHmacUpdate(&ctx, data, len);
    }

    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmacFinal(&ctx, hmac.mutableBytes);
    
    return hmac;
}

NSData* getHmacKeyForBlock(NSData* key, uint64_t blockIndex) {
    NSData* index = Uint64ToLittleEndianData(blockIndex);
    
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA512_DIGEST_LENGTH];
    
    CC_SHA512_CTX ctx;
    CC_SHA512_Init(&ctx);
    CC_SHA512_Update(&ctx, index.bytes, (CC_LONG)index.length);
    CC_SHA512_Update(&ctx, key.bytes, (CC_LONG)key.length);
    CC_SHA512_Final(hash.mutableBytes, &ctx);
    
    return hash;
}

- (NSError *)streamError {
    return self.error;
}

@end
