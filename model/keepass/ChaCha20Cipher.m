//
//  ChaCha20Cipher.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "ChaCha20Cipher.h"
#import "sodium.h"

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
    NSMutableData *foo = [NSMutableData dataWithLength:data.length];
    
    NSLog(@"IV12: %@", [iv base64EncodedStringWithOptions:kNilOptions]);
    NSLog(@"KEY32: %@", [key base64EncodedStringWithOptions:kNilOptions]);
    NSLog(@"ChaCha Data In: %@", [data base64EncodedStringWithOptions:kNilOptions]);

    // TODO: Verify iv and key are of correct lenght? This might not actually be necessary if we calculate it correctly
    
    if(iv.length != 12 || key.length != 32) {
        NSLog(@"IV or Key not of the expected length.");
        return nil;
    }
    
    //int status = crypto_stream_chacha20_xor(foo.mutableBytes, data.bytes, data.length, iv.bytes, key.bytes);
    
    int status = crypto_stream_chacha20_ietf_xor(foo.mutableBytes, data.bytes, data.length, iv.bytes, key.bytes);
    
    NSLog(@"Status: %d", status);
    // Check status
    
    NSLog(@"Out (b64): %@", [foo base64EncodedStringWithOptions:kNilOptions]);
    
    return foo;
}

@end
