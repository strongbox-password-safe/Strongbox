//
//  Salsa20Stream.m
//  StrongboxTests
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Salsa20Stream.h"
#import "sodium.h"
#import <CommonCrypto/CommonDigest.h>
#import "SBLog.h"

//static const uint32_t kIvSize = 8;
static const uint32_t kKeySize = 32;
static const uint32_t kBlockSize = 64;

static const uint8_t iv[] = {0xE8, 0x30, 0x09, 0x4B, 0x97, 0x20, 0x5D, 0x2A};

@interface Salsa20Stream ()

@property (nonatomic) uint64_t bytesProcessed;
@property (nonatomic) NSData* hashedKey;

@end

@implementation Salsa20Stream

+ (void)initialize {
    if(self == [Salsa20Stream class]) {
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
        slog(@"Could not securely copy new Salsa20 Stream Key bytes");
        return nil;
    }
       
    return newKey;
}

- (id)initWithKey:(const NSData *)key {
    if(self = [super init]) {
        if(!key) {
            key = [Salsa20Stream generateNewKey];
        }
        _key = [key copy];
    

        NSMutableData* hashedKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(key.bytes, (CC_LONG)key.length, hashedKey.mutableBytes);
        
        self.bytesProcessed = 0;
        self.hashedKey = hashedKey;
    }
    
    return self;
}

-(NSData*)doTheXor:(NSData *)ct {
    uint32_t currentBlock = (uint32_t)self.bytesProcessed / kBlockSize;
    int offset = self.bytesProcessed % kBlockSize;

    NSMutableData *xorBlock = [NSMutableData dataWithLength:ct.length + kBlockSize];
    NSRange subRange = NSMakeRange(offset, ct.length);
    [xorBlock replaceBytesInRange:subRange withBytes:ct.bytes];

    NSMutableData *outData = [[NSMutableData alloc] initWithLength:ct.length + kBlockSize];

    crypto_stream_salsa20_xor_ic(outData.mutableBytes, xorBlock.bytes, xorBlock.length, iv, currentBlock, self.hashedKey.bytes);

    self.bytesProcessed += ct.length;
    return [outData subdataWithRange:subRange];
}

@end
