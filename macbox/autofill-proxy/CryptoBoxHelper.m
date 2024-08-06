//
//  SealedBoxHelper.m
//  MacBox
//
//  Created by Strongbox on 25/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "CryptoBoxHelper.h"
#import "sodium.h"
#import "NSString+Extensions.h"
#import "NSData+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@implementation CryptoBoxHelper

+ (BoxKeyPair*)createKeyPair {
    uint8_t public[crypto_box_PUBLICKEYBYTES];
    uint8_t secret[crypto_box_SECRETKEYBYTES];
    
    crypto_box_keypair(public, secret);
    
    NSString* publicKey = [NSData dataWithBytes:public length:crypto_box_PUBLICKEYBYTES].base64String;
    NSString* secretKey = [NSData dataWithBytes:secret length:crypto_box_SECRETKEYBYTES].base64String;
    
    return [[BoxKeyPair alloc] initWithPublicKey:publicKey privateKey:secretKey];
}

+ (NSString *)createNonce {
    unsigned char nonce[crypto_box_NONCEBYTES];
    randombytes_buf(nonce, sizeof nonce);
    
    return [NSData dataWithBytes:nonce length:crypto_box_NONCEBYTES].base64String;
}

+ (NSString*)seal:(NSString*)message nonce:(NSString*)nonce theirPublicKey:(NSString*)theirPublicKey myPrivateKey:(NSString*)myPrivateKey {
    NSData* messageData = message.utf8Data;

    const uint8_t *publickey = theirPublicKey.dataFromBase64.bytes;
    const uint8_t *secretkey = myPrivateKey.dataFromBase64.bytes;
    const uint8_t *nonceBytes = nonce.dataFromBase64.bytes;

    NSUInteger cipherTextLength = crypto_box_MACBYTES + messageData.length;
    NSMutableData* ct = [NSMutableData dataWithLength:cipherTextLength];
    
    if (crypto_box_easy(ct.mutableBytes, messageData.bytes, messageData.length, nonceBytes, publickey, secretkey) != 0) {
        slog(@"🔴 crypto_box_easy failed");
        return nil;
    }
    
    return ct.base64String;
}


+ (NSString*)unSeal:(NSString*)message nonce:(NSString*)nonce theirPublicKey:(NSString*)theirPublicKey myPrivateKey:(NSString*)myPrivateKey {
    NSData* cipherTextData = message.dataFromBase64;
    
    const uint8_t *publickey = theirPublicKey.dataFromBase64.bytes;
    const uint8_t *secretkey = myPrivateKey.dataFromBase64.bytes;
    const uint8_t *nonceBytes = nonce.dataFromBase64.bytes;

    NSMutableData* plaintext = [NSMutableData dataWithLength:cipherTextData.length];

    if (crypto_box_open_easy(plaintext.mutableBytes, cipherTextData.bytes, cipherTextData.length, nonceBytes,
                             publickey, secretkey) != 0) {
        slog(@"🔴 crypto_box_open_easy failed");
        return nil;
    }

    NSData* pt = [plaintext subdataWithRange:NSMakeRange(0, cipherTextData.length - crypto_box_MACBYTES)];
    
    NSString* ret = [[NSString alloc] initWithData:pt encoding:NSUTF8StringEncoding];
    
    

    return ret;
}

@end
