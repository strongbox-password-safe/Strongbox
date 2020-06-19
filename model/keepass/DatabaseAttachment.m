//
//  Attachment.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabaseAttachment.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import <CommonCrypto/CommonDigest.h>

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonCrypto.h>
#import "FileManager.h"

#import "Utils.h"

static const int kBlockSize = 32 * 1024;

@interface DatabaseAttachment ()

@property NSString* encryptedSessionFilePath;
@property NSData* encryptionKey;
@property NSData* encryptionIV;
@property NSString* streamSha256Hex;
@property NSUInteger streamLength;

@end

@implementation DatabaseAttachment

- (void)dealloc {
    [self cleanup];
}

- (void)cleanup {
    if (self.encryptedSessionFilePath) {
        NSLog(@"DEALLOC - Removing temporary encrypted attachment file [%@]", self.encryptedSessionFilePath);
        NSError* error;
        [NSFileManager.defaultManager removeItemAtPath:self.encryptedSessionFilePath error:&error];
        NSLog(@"DEALLOC - Removed temporary encrypted attachment with error [%@]", error);
    }
    
    self.encryptedSessionFilePath = nil;
    self.encryptionKey = nil;
}

- (instancetype)initWithData:(NSData *)data compressed:(BOOL)compressed protectedInMemory:(BOOL)protectedInMemory {
    NSInputStream* inputStream = [NSInputStream inputStreamWithData:data];
    [inputStream open];
        
    self = [self initWithStream:inputStream length:data.length protectedInMemory:YES compressed:YES];

    [inputStream close];

    return self;
}

- (instancetype)initWithStream:(NSInputStream *)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory {
    return [self initWithStream:stream length:length protectedInMemory:protectedInMemory compressed:YES];
}

- (instancetype)initWithStream:(NSInputStream *)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory compressed:(BOOL)compressed {
    self = [super init];
    if (self) {
        _compressed = compressed;
        _protectedInMemory = protectedInMemory;
        
        self.encryptedSessionFilePath = [self getUniqueFileName];
        self.streamLength = length;
        
        NSOutputStream *outStream = [NSOutputStream outputStreamToFileAtPath:self.encryptedSessionFilePath append:NO];
        [outStream open];

        CC_SHA256_CTX context;
        CC_SHA256_Init(&context);
        CCCryptorRef cryptor;
        self.encryptionKey = getRandomData(kCCKeySizeAES256);
        self.encryptionIV = getRandomData(kCCBlockSizeAES128);
        CCCryptorStatus status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, self.encryptionKey.bytes, kCCKeySizeAES256, self.encryptionIV.bytes, &cryptor);
        if (status != kCCSuccess) {
            NSLog(@"Crypto Error: %d", status);
            return nil;
        }

        uint8_t block[kBlockSize];
        uint8_t encBlock[kBlockSize];
        size_t encWritten;
        
        for (size_t readSoFar = 0; readSoFar < length; readSoFar += kBlockSize) {
            size_t remaining = length - readSoFar;
            size_t bytesToReadThisTime = remaining > kBlockSize ? kBlockSize : remaining;
            NSInteger read = [stream read:block maxLength:bytesToReadThisTime];
            if (read <= 0) {
                NSLog(@"Not enough data to read specified length of attachment. Read = %ld, Requested = %ld", (long)read, bytesToReadThisTime);
                [outStream close];
            }
            
            // Encrypt and write
            
            status = CCCryptorUpdate(cryptor, block, read, encBlock, kBlockSize, &encWritten);
            if (status != kCCSuccess) {
                NSLog(@"Crypto Error: %d", status);
                return nil;
            }

            [outStream write:encBlock maxLength:encWritten];
            
            // Digest
            CC_SHA256_Update(&context, block, (CC_LONG)read);
            if (status != kCCSuccess) {
                NSLog(@"Crypto Error: %d", status);
                return nil;
            }
        }

        status = CCCryptorFinal(cryptor, encBlock, kBlockSize, &encWritten);
        if (status != kCCSuccess) {
            NSLog(@"Crypto Error: %d", status);
            return nil;
        }

        [outStream write:encBlock maxLength:encWritten];
        [outStream close];
        CCCryptorRelease(cryptor);
        
        NSMutableData *sha256 = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(sha256.mutableBytes, &context);
        if (status != kCCSuccess) {
            NSLog(@"Crypto Error: %d", status);
            return nil;
        }
        
        self.streamSha256Hex = sha256.hex;
    }
    
    return self;
}

- (NSData*)getDataFromEncryptedTemporaryFile {
    NSInputStream* inStream = [NSInputStream inputStreamWithFileAtPath:self.encryptedSessionFilePath];
    [inStream open];

    uint8_t block[kBlockSize];
    uint8_t decBlock[kBlockSize];
    size_t decWritten = 0;

    NSInteger bytesRead = 0;
    NSMutableData* ret  = [NSMutableData data];
    
    CCCryptorRef cryptor;
    CCCryptorStatus status = CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, self.encryptionKey.bytes, kCCKeySizeAES256, self.encryptionIV.bytes, &cryptor);
    if (status != kCCSuccess) {
        NSLog(@"Crypto Error: %d", status);
        return nil;
    }

    do {
        bytesRead = [inStream read:block maxLength:kBlockSize];
        if (bytesRead < 0) {
            NSLog(@"Could not read encrypted session file: [%@]", self.encryptedSessionFilePath);
            return nil;
        }
        
        if (bytesRead > 0) {
            status = CCCryptorUpdate(cryptor, block, bytesRead, decBlock, kBlockSize, &decWritten);
            if (status != kCCSuccess) {
                NSLog(@"Crypto Error: %d", status);
                return nil;
            }
            
            [ret appendBytes:decBlock length:decWritten];
        }
    } while (bytesRead > 0);
    [inStream close];
    
    status = CCCryptorFinal(cryptor, decBlock, kBlockSize, &decWritten);
    if (status != kCCSuccess) {
        NSLog(@"Crypto Error: %d", status);
        return nil;
    }
    if (decWritten > 0) {
        [ret appendBytes:decBlock length:decWritten];
    }
    
    CCCryptorRelease(cryptor);
    
    NSLog(@"Read encrypted file at [%@] with error", self.encryptedSessionFilePath);
    
    return ret;
}

- (NSString*)getUniqueFileName {
    NSString* ret;
    
    do {
        ret = [FileManager.sharedInstance.tmpEncryptedAttachmentPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}

- (NSData *)deprecatedData {
    return [self getDataFromEncryptedTemporaryFile];
}

- (NSUInteger)length {
    return self.streamLength;
}

- (NSUInteger)estimatedStorageBytes {
    return self.length;
}

- (NSString *)digestHash {
    return self.streamSha256Hex;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Compressed: %d, Protected: %d, Size: %lu", self.compressed, self.protectedInMemory, (unsigned long)self.estimatedStorageBytes];
}

@end
