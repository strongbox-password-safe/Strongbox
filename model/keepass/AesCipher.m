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

@implementation AesCipher

// This class does standard AES CBC with PKCS7 padding using the Common Crypto library

+ (NSData*)decrypt:(NSData *)data iv:(NSData*)iv key:(NSData*)key {
    return [self crypt:kCCDecrypt data:data iv:iv key:key];
}

+ (NSData*)encrypt:(NSData *)data iv:(NSData*)iv key:(NSData*)key {
 
    return [self crypt:kCCEncrypt data:data iv:iv key:key];
}

+ (NSData*)crypt:(CCOperation)operation data:(NSData *)data iv:(NSData*)iv key:(NSData*)key {
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
    
    return ret;
}


@end
