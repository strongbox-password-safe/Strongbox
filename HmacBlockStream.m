//
//  HmacBlockStream.m
//  Strongbox
//
//  Created by Strongbox on 08/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "HmacBlockStream.h"
#import "Kdbx4Serialization.h"
#import "Utils.h"
#import <CommonCrypto/CommonCrypto.h>
#import "KeePassCiphers.h"
#import "Utils.h"

@interface HmacBlockStream ()

@property uint8_t* source;
@property size_t sourceLength;
@property NSUInteger sourceOffset;

@property NSUInteger workingBlockOffset;
@property uint8_t* workingBlock;
@property size_t workingBlockLength;
@property int workingBlockIndex;

@property NSData *hmacKey;
@property size_t readSoFar;

@property NSError* error;

@end

@implementation HmacBlockStream

- (instancetype)initWithData:(uint8_t *)data length:(size_t)length hmacKey:(NSData*)hmacKey {
    if (self = [super init]) {
        self.source = data;
        self.sourceOffset = 0;
        self.sourceLength = length;
        self.workingBlock = nil;
        self.workingBlockOffset = 0;
        self.workingBlockIndex = 0;
        self.hmacKey = hmacKey;
    }
    
    return self;
}

- (void)open { }

- (void)close { }

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (self.workingBlock != nil && self.workingBlockLength == 0) { // EOF
        return 0L;
    }

    NSUInteger bufferWritten = 0;
    NSUInteger bufferOffset = 0;
    
    while (bufferWritten < len) {
        NSUInteger bufferAvailable = len - bufferWritten;
        NSUInteger workingAvailable = self.workingBlockLength - self.workingBlockOffset;

        if (self.workingBlock == nil || workingAvailable == 0)  {
            if (! [self loadNextBlock] ) {
                return -1;
            }
            
            if (self.workingBlockLength == 0) { // EOF
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
    HmacBlockHeader *blockHeader = (HmacBlockHeader*)((uint8_t*)self.source + self.sourceOffset);
    size_t blockLength = littleEndian4BytesToInt32(blockHeader->lengthBytes);

//    NSLog(@"DEBUG: Decrypting Block %d of length [%zu] - [%zu]", self.workingBlockIndex, blockLength, self.readSoFar);
    // blockLength = blockLength    size_t    1048576
    
    if (blockLength > 0) {
        if(self.sourceOffset + blockLength > self.sourceLength) {
            NSLog(@"Not enough data to decrypt Block!");
            self.error = [Utils createNSError:@"Not enough data to decrypt block." errorCode:-1];
            self.workingBlock = nil;
            return NO;
        }

        self.workingBlock = blockHeader->data;
        self.workingBlockLength = blockLength;
        
        NSData *actualHmac = getBlockHmacBytes(self.workingBlock, self.workingBlockLength, self.hmacKey, self.workingBlockIndex);
        NSData *expectedHmac = [NSData dataWithBytes:blockHeader->hmacSha256 length:CC_SHA256_DIGEST_LENGTH];

        if(![actualHmac isEqual:expectedHmac]) {
            NSLog(@"Actual Block HMAC does not match expected. Block has been corrupted.");
            self.error = [Utils createNSError:@"Actual Block HMAC does not match expected. Block has been corrupted." errorCode:-1];
            self.workingBlock = nil;
            return NO;
        }
    }
    else {
        self.workingBlock = blockHeader->data;
        self.workingBlockLength = 0;
    }
    
    self.readSoFar += blockLength;
//    NSLog(@"DEBUG: Decrypted Block %d of length [%zu] - [%zu]", self.workingBlockIndex, blockLength, self.readSoFar);

    self.workingBlockIndex++;
    self.workingBlockOffset = 0;
    self.sourceOffset += blockLength + SIZE_OF_HMAC_BLOCK_HEADER;
    
    return YES;
}

NSData* getBlockHmac(NSData *data, NSData* hmacKey, uint64_t blockIndex) {
    return getBlockHmacBytes((uint8_t*)data.bytes, data.length, hmacKey, blockIndex);
}

NSData* getBlockHmacBytes(uint8_t* data, size_t len, NSData* hmacKey, uint64_t blockIndex) {
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
