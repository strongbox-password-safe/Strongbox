//
//  Salsa20Stream.m
//  StrongboxTests
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Salsa20Stream.h"
#import "sodium.h"
#import <CommonCrypto/CommonDigest.h>

static const uint32_t kIvSize = 8;
static const uint32_t kKeySize = 32;

@interface Salsa20Stream ()

@property (nonatomic) uint64_t bytesProcessed;
@property (nonatomic) NSData* iv;

@end

@implementation Salsa20Stream

+ (NSData*)generateNewKey {
    NSMutableData *newKey = [NSMutableData dataWithLength:kKeySize];
    
    if(SecRandomCopyBytes(kSecRandomDefault, kKeySize, newKey.mutableBytes))
    {
        NSLog(@"Could not securely copy new Salsa20 Stream Key bytes");
        return nil;
    }
       
    return newKey;
}

- (id)initWithIv:(const uint8_t*)iv key:(NSData*)key {
    if(self = [super init]) {
        int sodium_initialization = sodium_init();
        
        if (sodium_initialization == -1) {
            NSLog(@"Sodium Initialization Failed.");
            return nil;
        }
        
        self.bytesProcessed = 0;
        self.iv = [NSData dataWithBytes:iv length:kIvSize];
        _key = [NSData dataWithData:key];
    }
    
    return self;
}

static const uint32_t kSalsa20BlockSize = 64;

-(NSData *)xor:(NSData *)ct {
    uint64_t currentBlock = self.bytesProcessed / kSalsa20BlockSize;
    int offset = self.bytesProcessed % kSalsa20BlockSize;
    
    NSMutableData *outData = [[NSMutableData alloc] initWithLength:ct.length + kSalsa20BlockSize];
    uint8_t *foo = (uint8_t*)outData.bytes;
    
    NSMutableData *bar = [NSMutableData dataWithLength:ct.length + kSalsa20BlockSize];
    
    NSRange subRange = NSMakeRange(offset, ct.length);
    [bar replaceBytesInRange:subRange withBytes:ct.bytes];
    
    // NB: KeePass SHA256s the Key...
    
    uint8_t hashedKey[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(self.key.bytes, (CC_LONG)self.key.length, hashedKey);
    
    crypto_stream_salsa20_xor_ic(foo, bar.bytes, bar.length, self.iv.bytes, currentBlock, hashedKey);
    
    self.bytesProcessed += ct.length;
    
    return [outData subdataWithRange:subRange];
}

@end
