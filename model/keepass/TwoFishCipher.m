//
//  TwoFishCipher.m
//  Strongbox
//
//  Created by Mark on 07/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TwoFishCipher.h"
#import "tomcrypt.h"
#import "TwoFishReadStream.h"
#import "TwoFishOutputStream.h"
#import "SBLog.h"

static const uint32_t kKeySize = 32;
static const uint32_t kBlockSize = 16;
static const uint32_t kIvSize = kBlockSize;

@implementation TwoFishCipher

- (NSMutableData *)decrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    
    symmetric_key skey;
    
    if ((twofish_setup(key.bytes, kKeySize, 0, &skey)) != CRYPT_OK) {
        slog(@"Invalid Key");
        return nil;
    }
    
    NSMutableData *decData = [[NSMutableData alloc] init];
    
    uint8_t blockIv[kBlockSize];
    memcpy(blockIv, iv.bytes, kBlockSize);
    uint64_t numBlocks = data.length / kBlockSize;
    uint8_t *ct = (uint8_t*)data.bytes;

    uint8_t pt[kBlockSize];
    
    for(int block=0;block < numBlocks-1;block++) {
        twofish_ecb_decrypt(ct, pt, &skey);

        for (int i = 0; i < kBlockSize; i++) {
            pt[i] ^= blockIv[i];
        }
        
        [decData appendBytes:pt length:kBlockSize];
        memcpy(blockIv, ct, kBlockSize);
        ct += kBlockSize;
    }
    
    

    twofish_ecb_decrypt(ct, pt, &skey);

    for (int i = 0; i < kBlockSize; i++) {
        pt[i] ^= blockIv[i];
    }

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

    if(padding) {
        [decData appendBytes:pt length:kBlockSize - paddingLength];
    }
    else {
        [decData appendBytes:pt length:kBlockSize];
    }
    
    return decData;
}

- (NSMutableData *)encrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    
    symmetric_key skey;
    
    if ((twofish_setup(key.bytes, kKeySize, 0, &skey)) != CRYPT_OK) {
        slog(@"Invalid Key");
        return nil;
    }
    
    int numBlocks = (int)data.length / kBlockSize;
    
    NSMutableData *ret = [[NSMutableData alloc] init];
    
    uint8_t *pt = (uint8_t*)data.bytes;
    uint8_t ptBar[kBlockSize];
    unsigned char ct[kBlockSize];
    memcpy(ct, iv.bytes, kBlockSize); 
    
    for (int i = 0; i < numBlocks; i++) {
        for (int j = 0; j < kBlockSize; j++) {
            ptBar[j] = pt[j] ^ ct[j];
        }

        twofish_ecb_encrypt(ptBar, ct, &skey);

        [ret appendBytes:ct length:kBlockSize];
        pt += kBlockSize;
    }
    
    
    
    uint8_t padLen = kBlockSize - (data.length - (kBlockSize * numBlocks));
 
    for (size_t j = 0; j < kBlockSize - padLen; j++) {
        ptBar[j] = ct[j] ^ pt[j];
    }
    for (size_t i = kBlockSize - padLen; i < kBlockSize; i++) {
        ptBar[i] = ct[i] ^ padLen;
    }

    twofish_ecb_encrypt(ptBar, ct, &skey);

    [ret appendBytes:ct length:kBlockSize];
    
    return ret;
}

- (NSData *)generateIv {
    NSMutableData *newKey = [NSMutableData dataWithLength:kIvSize];
    
    if(SecRandomCopyBytes(kSecRandomDefault, kIvSize, newKey.mutableBytes))
    {
        slog(@"Could not securely copy new bytes");
        return nil;
    }
    
    return newKey;
}

- (NSInputStream *)getDecryptionStreamForStream:(NSInputStream *)inputStream key:(NSData *)key iv:(NSData *)iv {
    return [[TwoFishReadStream alloc] initWithStream:inputStream key:key iv:iv];
}

- (NSOutputStream *)getEncryptionOutputStreamForStream:(NSOutputStream *)outputStream key:(NSData *)key iv:(NSData *)iv {
    return [[TwoFishOutputStream alloc] initToOutputStream:outputStream key:key iv:iv];
}

@end
