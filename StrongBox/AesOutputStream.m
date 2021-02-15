//
//  AesOutputStream.m
//  Strongbox
//
//  Created by Strongbox on 26/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AesOutputStream.h"
#import <CommonCrypto/CommonCrypto.h>
#import "Utils.h"

@interface AesOutputStream ()

@property NSOutputStream* outputStream;
@property CCCryptorRef *cryptor;
@property NSError* error;

@end

@implementation AesOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream encrypt:(BOOL)encrypt key:(NSData *)key iv:(NSData *)iv {
    if (self = [super init]) {
        if (outputStream == nil) {
            return nil;
        }
        
        _cryptor = malloc(sizeof(CCCryptorRef));
        
        CCCryptorStatus status = CCCryptorCreate(encrypt ? kCCEncrypt : kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, key.bytes, kCCKeySizeAES256, iv.bytes, _cryptor);
        
        if (status != kCCSuccess) {
            NSLog(@"Crypto Error: %d", status);
            return nil;
        }

        self.outputStream = outputStream;
    }
    
    return self;
}

- (void)open {
    if (self.outputStream) {
        [self.outputStream open];
    }
}

- (void)close {
    if (self.outputStream == nil) {
        return;
    }
    
    size_t encRequired = CCCryptorGetOutputLength(*_cryptor, 0, YES);
    uint8_t* encBlock = malloc(encRequired);
    size_t encWritten;

    CCCryptorStatus status = CCCryptorFinal(*_cryptor, encBlock, encRequired, &encWritten);
    if (status != kCCSuccess) {
        NSLog(@"Crypto Error: %d", status);
        self.error = [Utils createNSError:[NSString stringWithFormat:@"Crypto Error: %d", status] errorCode:status];
        free(encBlock);
        return;
    }

    if (encWritten > 0) {
        [self.outputStream write:encBlock maxLength:encWritten];
    }
    
    free(encBlock);
    
    [self.outputStream close];
    self.outputStream = nil;
    
    if (self.cryptor) {
        free(self.cryptor);
        self.cryptor = nil;
    }
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    size_t encRequired = CCCryptorGetOutputLength(*_cryptor, len, NO);
    uint8_t* encBlock = malloc(encRequired);
    size_t encWritten;

    CCCryptorStatus status = CCCryptorUpdate(*_cryptor, buffer, len, encBlock, encRequired, &encWritten);
    if (status != kCCSuccess) {
        NSLog(@"Crypto Error: %d", status);
        self.error = [Utils createNSError:[NSString stringWithFormat:@"Crypto Error: %d", status] errorCode:status];
        free(encBlock);
        return - 1;
    }

    NSInteger ret = [self.outputStream write:encBlock maxLength:encWritten];

    free(encBlock);
    
    return ret;
}

- (NSError *)streamError {
    return self.outputStream.streamError ? self.outputStream.streamError : self.error;
}

@end
