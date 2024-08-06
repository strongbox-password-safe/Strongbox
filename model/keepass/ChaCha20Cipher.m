//
//  ChaCha20Cipher.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ChaCha20Cipher.h"
#import "sodium.h"
#import "ChaCha20ReadStream.h"
#import "ChaCha20OutputStream.h"
#import "SBLog.h"

static const uint32_t kIvSize = 12;
static const uint32_t kKeySize = 32;

static const BOOL kLogVerbose = NO;

@implementation ChaCha20Cipher

- (instancetype)init
{
    self = [super init];
    if (self) {
        int sodium_initialization = sodium_init();
        
        if (sodium_initialization == -1) {
            slog(@"Sodium Initialization Failed.");
            return nil;
        }
    }
    return self;
}

- (NSMutableData *)decrypt:(NSData *)data iv:(NSData *)iv key:(NSData *)key {
    if(kLogVerbose) {
        slog(@"IV12: %@", [iv base64EncodedStringWithOptions:kNilOptions]);
        slog(@"KEY32: %@", [key base64EncodedStringWithOptions:kNilOptions]);
        slog(@"ChaCha Data In: %@", [data base64EncodedStringWithOptions:kNilOptions]);
    }
 
    if(iv.length != kIvSize || key.length != kKeySize) {
        slog(@"IV or Key not of the expected length.");
        return nil;
    }
    
    NSMutableData *foo = [NSMutableData dataWithLength:data.length];
    
    crypto_stream_chacha20_ietf_xor(foo.mutableBytes, data.bytes, data.length, iv.bytes, key.bytes);
    
    return foo;
}

- (NSMutableData *)encrypt:(NSData *)data iv:(NSData *)iv key:(NSData *)key {
    return [self decrypt:data iv:iv key:key];
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
    return [[ChaCha20ReadStream alloc] initWithStream:inputStream key:key iv:iv];
}

- (NSOutputStream *)getEncryptionOutputStreamForStream:(NSOutputStream *)outputStream key:(NSData *)key iv:(NSData *)iv {
    return [[ChaCha20OutputStream alloc] initToOutputStream:outputStream key:key iv:iv];
}

@end
