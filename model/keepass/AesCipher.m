//
//  AesCipher.m
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AesCipher.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonCrypto.h>
#import "AesInputStream.h"
#import "AesOutputStream.h"
#import "SBLog.h"

static const uint32_t kIvSize = kCCBlockSizeAES128;

@implementation AesCipher



- (NSMutableData*)crypt:(CCOperation)operation data:(NSData *)data iv:(NSData*)iv key:(NSData*)key {
    
    
    size_t bufferSize;
    CCCryptorStatus status = CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes,
                                     data.bytes, data.length, nil, 0, &bufferSize);

    if(status != kCCBufferTooSmall) {
        slog(@"Could not get AES buffer size: [%d]", status);
        return nil;
    }
    
    
    
    NSMutableData *ret = [NSMutableData dataWithLength:bufferSize];
    status = CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes,
                     data.bytes, data.length, ret.mutableBytes, ret.length, &bufferSize);

    if(status != kCCSuccess) {
        slog(@"Could not AES crypt: [%d]", status);
        return nil;
    }
    
    if(bufferSize != ret.length) {
        return [ret subdataWithRange:NSMakeRange(0, bufferSize)].mutableCopy;
    }
    
    return ret;
}


- (NSMutableData *)decrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self crypt:kCCDecrypt data:data iv:iv key:key];
}

- (NSMutableData *)encrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self crypt:kCCEncrypt data:data iv:iv key:key];
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
    return [[AesInputStream alloc] initWithStream:inputStream key:key iv:iv];
}

- (NSOutputStream *)getEncryptionOutputStreamForStream:(NSOutputStream *)outputStream key:(NSData *)key iv:(NSData *)iv {
    return [[AesOutputStream alloc] initToOutputStream:outputStream encrypt:YES key:key iv:iv chainOpensAndCloses:NO];
}

@end
