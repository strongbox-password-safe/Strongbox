//
//  ChaCha20Stream.m
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ChaCha20Stream.h"
#import "sodium.h"
#import <CommonCrypto/CommonCrypto.h>
#import "SBLog.h"

static const uint32_t kBlockSize = 64;
static const uint32_t kIvSize = 12;
static const uint32_t kKeySize = 32;

@interface ChaCha20Stream ()

@property (nonatomic) uint64_t bytesProcessed;
@property (nonatomic) NSData* generatedIv;
@property (nonatomic) NSData* generatedKey;

@end

@implementation ChaCha20Stream

+ (void)initialize {
    if(self == [ChaCha20Stream class]) {
        int sodium_initialization = sodium_init();
        
        if (sodium_initialization == -1) {
            slog(@"Sodium Initialization Failed.");
        }
    }
}

+ (NSData*)generateNewKey {
    NSMutableData *newKey = [NSMutableData dataWithLength:kKeySize];
    
    if(SecRandomCopyBytes(kSecRandomDefault, kKeySize, newKey.mutableBytes))
    {
        slog(@"Could not securely copy new Key bytes");
        return nil;
    }
    
    return newKey;
}

- (id)initWithKey:(const NSData *)key {
    if(self = [super init]) {
        if(!key) {
            key = [ChaCha20Stream generateNewKey];
        }
        _key = [key copy];
        
        uint8_t buf[CC_SHA512_DIGEST_LENGTH];
        CC_SHA512(key.bytes, (CC_LONG)key.length, buf);

        self.generatedKey = [NSData dataWithBytes:buf length:kKeySize];
        self.generatedIv = [NSData dataWithBytes:&buf[kKeySize] length:kIvSize];
        
        self.bytesProcessed = 0;
        
        
        
    }
    
    return self;
}

-(NSData *)doTheXor:(NSData *)ct {
    uint32_t currentBlock = (uint32_t)self.bytesProcessed / kBlockSize;
    int offset = self.bytesProcessed % kBlockSize;

    NSMutableData *xorBlock = [NSMutableData dataWithLength:ct.length + kBlockSize];
    NSRange subRange = NSMakeRange(offset, ct.length);
    [xorBlock replaceBytesInRange:subRange withBytes:ct.bytes];

    NSMutableData *outData = [[NSMutableData alloc] initWithLength:ct.length + kBlockSize];

    crypto_stream_chacha20_ietf_xor_ic(outData.mutableBytes, xorBlock.bytes, xorBlock.length, self.generatedIv.bytes, currentBlock, self.generatedKey.bytes);
    
    self.bytesProcessed += ct.length;
    return [outData subdataWithRange:subRange]; 
}

@end
