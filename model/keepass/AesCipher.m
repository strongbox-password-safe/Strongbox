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

static const uint32_t kIvSize = kCCBlockSizeAES128;

@implementation AesCipher

// This class does standard AES CBC with PKCS7 padding using the Common Crypto library

- (NSData*)crypt:(CCOperation)operation data:(NSData *)data iv:(NSData*)iv key:(NSData*)key {
    // 1. Get Required Buffer Size by Calling with 0 length out buffer
    
    size_t bufferSize;
    CCCryptorStatus status = CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes,
                                     data.bytes, data.length, nil, 0, &bufferSize);

    // 2. Perform actually with right sized buffer.
    
    NSMutableData *ret = [NSMutableData dataWithLength:bufferSize];
    status = CCCrypt(operation, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, key.length, iv.bytes,
                     data.bytes, data.length, ret.mutableBytes, ret.length, &bufferSize);

    if(status != kCCSuccess) {
        return nil;
    }
    
    if(bufferSize != ret.length) {
        return [ret subdataWithRange:NSMakeRange(0, bufferSize)];
    }
    
    return ret;
}


- (nonnull NSData *)decrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self crypt:kCCDecrypt data:data iv:iv key:key];
}

- (nonnull NSData *)encrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self crypt:kCCEncrypt data:data iv:iv key:key];
}

- (nonnull NSData *)generateIv {
    NSMutableData *newKey = [NSMutableData dataWithLength:kIvSize];
    
    if(SecRandomCopyBytes(kSecRandomDefault, kIvSize, newKey.mutableBytes))
    {
        NSLog(@"Could not securely copy new bytes");
        return nil;
    }
    
    return newKey;
}

@end
