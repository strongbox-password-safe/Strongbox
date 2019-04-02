//
//  ChaCha20Cipher.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "ChaCha20Cipher.h"
#import "sodium.h"

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
            NSLog(@"Sodium Initialization Failed.");
            return nil;
        }
    }
    return self;
}

- (NSData*)decrypt:(NSData*)data iv:(NSData*)iv key:(NSData*)key {
    if(kLogVerbose) {
        NSLog(@"IV12: %@", [iv base64EncodedStringWithOptions:kNilOptions]);
        NSLog(@"KEY32: %@", [key base64EncodedStringWithOptions:kNilOptions]);
        NSLog(@"ChaCha Data In: %@", [data base64EncodedStringWithOptions:kNilOptions]);
    }
 
    if(iv.length != kIvSize || key.length != kKeySize) {
        NSLog(@"IV or Key not of the expected length.");
        return nil;
    }
    
    NSMutableData *foo = [NSMutableData dataWithLength:data.length];
    
    crypto_stream_chacha20_ietf_xor(foo.mutableBytes, data.bytes, data.length, iv.bytes, key.bytes);
    
    return foo;
}

- (NSData *)encrypt:(nonnull NSData *)data iv:(nonnull NSData *)iv key:(nonnull NSData *)key {
    return [self decrypt:data iv:iv key:key];
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


@end
