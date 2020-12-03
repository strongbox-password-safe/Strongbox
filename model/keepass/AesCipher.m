//
//  AesCipher.m
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AesCipher.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonCrypto.h>
#import "AesInputStream.h"

static const uint32_t kIvSize = kCCBlockSizeAES128;

@implementation AesCipher



- (NSData*)crypt:(CCOperation)operation data:(NSData *)data iv:(NSData*)iv key:(NSData*)key {
    
    
    size_t bufferSize;
    
    CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes,
                                     data.bytes, data.length, nil, 0, &bufferSize);

    
    
    NSMutableData *ret = [NSMutableData dataWithLength:bufferSize];
    CCCryptorStatus status = CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes,
                     data.bytes, data.length, ret.mutableBytes, ret.length, &bufferSize);

    if(status != kCCSuccess) {
        return nil;
    }
    
    if(bufferSize != ret.length) {
        return [ret subdataWithRange:NSMakeRange(0, bufferSize)];
    }
    
    return ret;
}


- (NSData *)decrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self crypt:kCCDecrypt data:data iv:iv key:key];
}

- (NSData *)encrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self crypt:kCCEncrypt data:data iv:iv key:key];
}

- (NSData *)generateIv {
    NSMutableData *newKey = [NSMutableData dataWithLength:kIvSize];
    
    if(SecRandomCopyBytes(kSecRandomDefault, kIvSize, newKey.mutableBytes))
    {
        NSLog(@"Could not securely copy new bytes");
        return nil;
    }
    
    return newKey;
}

- (NSInputStream *)getDecryptionStreamForStream:(NSInputStream *)inputStream key:(NSData *)key iv:(NSData *)iv {
    return [[AesInputStream alloc] initWithStream:inputStream key:key iv:iv];
}


@end
