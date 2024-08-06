//
//  HmacBlockOutputStream.m
//  Strongbox
//
//  Created by Strongbox on 04/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "HmacBlockOutputStream.h"
#import "HmacBlockInputStream.h"
#import <CommonCrypto/CommonCrypto.h>
#import "KeePassConstants.h"
#import "Utils.h"

@interface HmacBlockOutputStream ()

@property NSOutputStream* outputStream;
@property NSError* error;
@property int blockNumber;
@property NSData *hmacKey;

@property NSMutableData* pendingBuffer;

@property BOOL wasOpened, wasClosed;
@end

const NSUInteger kMmacLength = CC_SHA256_DIGEST_LENGTH;
const NSUInteger kLengthLength = 4;

@implementation HmacBlockOutputStream

- (instancetype)initWithStream:(NSOutputStream *)outputStream hmacKey:(NSData *)hmacKey {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        self.outputStream = outputStream;
        self.hmacKey = hmacKey;
    }
    
    return self;
}

- (NSError *)streamError {
    return self.outputStream.streamError ? self.outputStream.streamError : self.error;
}

- (void)open {
    if ( self.wasOpened ){
        return;
    }
    self.wasOpened = YES;

    self.blockNumber = 0;
    self.pendingBuffer = [NSMutableData data];
}

- (void)close {
    if ( self.wasClosed ){
        return;
    }
    self.wasClosed = YES;

    if ( self.pendingBuffer.length > 0 ) {
        NSInteger wrote = [self writeBlock:self.pendingBuffer.bytes blockLength:self.pendingBuffer.length];
        

        
        if ( wrote < 0 ) {
            slog(@"WARNWARN: Error writing Last Block");
            return;
        }
    }
    
    self.pendingBuffer = nil;
    
    NSData* terminatorBlock = [NSData data];
    
    NSInteger wrote = [self writeBlock:terminatorBlock.bytes blockLength:terminatorBlock.length];
    if ( wrote < 0 ) {
        slog(@"WARNWARN: Error writing Terminator Block");
        return;
    }

    self.outputStream = nil;
}

- (NSInteger)write:(const uint8_t *)indata maxLength:(NSUInteger)inlen {
    if ( !self.wasOpened || self.wasClosed ) {
        slog(@"WARNWARN: Unopen or not closed. HMAC Block Output Stream");
        return -1;
    }
    
    [self.pendingBuffer appendBytes:indata length:inlen];
    
    
    

    
    
    
    size_t numberOfFullBlocksThisTime = self.pendingBuffer.length / kDefaultBlockifySize;
    


    NSInteger writtenThisTime = 0;
    
    for (size_t i=0; i < numberOfFullBlocksThisTime; i++) {


        const uint8_t *block = &self.pendingBuffer.bytes[i * kDefaultBlockifySize];
        NSInteger w = [self writeFullBlock:block];
        if ( w < 0 ) {
            slog(@"Error writing full HMAC block = [%@]", self.streamError);
            return w;
        }
        
        writtenThisTime += w;

    }
    
    if ( numberOfFullBlocksThisTime > 0 ) {
        NSUInteger offset = numberOfFullBlocksThisTime * kDefaultBlockifySize;
        NSUInteger remaining = self.pendingBuffer.length - offset;
        
        memcpy(self.pendingBuffer.mutableBytes, &self.pendingBuffer.bytes[offset], remaining);
        [self.pendingBuffer setLength:remaining];

        
    }
    

    
    return writtenThisTime;
}

- (NSInteger)writeFullBlock:(const uint8_t*)buffer {
    return [self writeBlock:buffer blockLength:kDefaultBlockifySize];
}

- (NSInteger)writeBlock:(const uint8_t*)buffer blockLength:(size_t)blockLength {


    NSData *hmac = getBlockHmacBytes(buffer, blockLength, self.hmacKey, self.blockNumber);
    
    NSData* lengthData = Uint32ToLittleEndianData((uint32_t)blockLength);

    NSInteger wrote = [self.outputStream write:hmac.bytes maxLength:hmac.length];
    if ( wrote < 0 ) {
        slog(@"WARNWARN: Error writing HMAC for Block");
        
        if ( self.outputStream.streamError == nil ) {
            self.error = [Utils createNSError:@"Could not write HMAC Block to output stream and no output stream error" errorCode:wrote];
        }
        return wrote;
    }
    
    wrote = [self.outputStream write:lengthData.bytes maxLength:lengthData.length];
    if ( wrote < 0 ) {
        slog(@"WARNWARN: Error writing Length for Block");
        
        if ( self.outputStream.streamError == nil ) {
            self.error = [Utils createNSError:@"Could not write HMAC Block to output stream and no output stream error" errorCode:wrote];
        }
        return wrote;
    }

    wrote = [self.outputStream write:buffer maxLength:blockLength];
    if ( wrote < 0 ) {
        slog(@"WARNWARN: Error writing Block for Block");
        
        if ( self.outputStream.streamError == nil ) {
            self.error = [Utils createNSError:@"Could not write HMAC Block to output stream and no output stream error" errorCode:wrote];
        }
        return wrote;
    }

    
    




    
    self.blockNumber++;
    
    return blockLength + hmac.length + lengthData.length;
}

@end
