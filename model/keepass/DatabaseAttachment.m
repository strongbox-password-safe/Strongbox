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
#import <CommonCrypto/CommonCrypto.h>
#import "FileManager.h"

#import "Utils.h"
#import "Base64DecodeOutputStream.h"
#import "GzipDecompressOutputStream.h"
#import "AesOutputStream.h"
#import "Sha256PassThroughOutputStream.h"
#import "AesInputStream.h"

static const int kBlockSize = 32 * 1024;
static NSString* kEmptyDataDigest;

static const BOOL kEncrypt = YES; // Encrypt output file - debug helper

@interface DatabaseAttachment ()

@property NSString* encryptedSessionFilePath;
@property NSData* encryptionKey;
@property NSData* encryptionIV;
@property NSString* sha256Hex;
@property NSUInteger attachmentLength;

@property NSOutputStream* incrementalWriteStream;
@property Sha256PassThroughOutputStream* digested;

@end

@implementation DatabaseAttachment

+ (void)initialize {
    if(self == [DatabaseAttachment class]) {
        kEmptyDataDigest = NSData.data.sha256.hex; // Empty data
    }
}

- (void)dealloc {
    [self cleanup];
}

- (void)cleanup {
    if (self.encryptedSessionFilePath) {
        NSError* error;
        [NSFileManager.defaultManager removeItemAtPath:self.encryptedSessionFilePath error:&error];
        NSLog(@"DEALLOC - Removed temporary encrypted attachment [%@]-[%@]", self.encryptedSessionFilePath, error);
    }
    
    self.encryptedSessionFilePath = nil;
    self.encryptionKey = nil;
}

- (instancetype)initWithData:(NSData *)data compressed:(BOOL)compressed protectedInMemory:(BOOL)protectedInMemory {
    return [self initWithStream:[NSInputStream inputStreamWithData:data] protectedInMemory:protectedInMemory compressed:compressed];
}

- (instancetype)initWithStream:(NSInputStream *)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory {
    return [self initWithStream:stream length:length protectedInMemory:protectedInMemory compressed:YES];
}

- (instancetype)initWithStream:(NSInputStream *)stream protectedInMemory:(BOOL)protectedInMemory compressed:(BOOL)compressed {
    if (self = [self initForStreamWriting:protectedInMemory compressed:compressed]) {
        _compressed = compressed;
        _protectedInMemory = protectedInMemory;

        uint8_t block[kBlockSize];
        NSInteger read;
        
        [stream open];
        while ((read = [stream read:block maxLength:kBlockSize]) > 0) {
            [self writeStreamWithPlainDecompressedBytes:block maxLength:read];
        }
        [stream close];
        
        [self closeWriteStream];

        if (read < 0) {
            NSLog(@"Error reading stream... [%ld]", (long)read);
            return nil;
        }
    }
    
    return self;
}
    
- (instancetype)initWithStream:(NSInputStream *)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory compressed:(BOOL)compressed {
    if (self = [self initForStreamWriting:protectedInMemory compressed:compressed]) {
        _compressed = compressed;
        _protectedInMemory = protectedInMemory;
        
        uint8_t block[kBlockSize];
        for (size_t readSoFar = 0; readSoFar < length; readSoFar += kBlockSize) {
            size_t remaining = length - readSoFar;
            size_t bytesToReadThisTime = remaining > kBlockSize ? kBlockSize : remaining;
            NSInteger read = [stream read:block maxLength:bytesToReadThisTime];
            if (read <= 0) {
                NSLog(@"Not enough data to read specified length of attachment. Read = %ld, Requested = %ld", (long)read, bytesToReadThisTime);
                return nil;
            }
         
            [self writeStreamWithPlainDecompressedBytes:block maxLength:read];
        }
        
        [self closeWriteStream];
    }
    
    return self;
}

- (instancetype)initForStreamWriting:(BOOL)protectedInMemory compressed:(BOOL)compressed {
    if (self = [super init]) {
        self.protectedInMemory = protectedInMemory;
        self.compressed = compressed;
        self.encryptionKey = getRandomData(kCCKeySizeAES256);
        self.encryptionIV = getRandomData(kCCBlockSizeAES128);
        self.encryptedSessionFilePath = [self getUniqueFileName];
        
        NSLog(@"Initialized with Encrypted Session File Path = [%@]", self.encryptedSessionFilePath);
        
        self.attachmentLength = 0;
        _sha256Hex = kEmptyDataDigest;
    }
    
    return self;
}

- (NSInteger)writeStreamWithPlainDecompressedBytes:(const uint8_t*)buffer maxLength:(NSUInteger)len { // KeePass v4
    if (self.incrementalWriteStream == nil) {
        [self createOutputPipeline:NO gzipDecompress:NO];
        [self.incrementalWriteStream open];
    }
    
    return [self writeStream:buffer maxLength:len];
    
}

- (void)createOutputPipeline:(BOOL)base64Decode gzipDecompress:(BOOL)gzipDecompress {
    NSOutputStream* outputFile = [NSOutputStream outputStreamToFileAtPath:self.encryptedSessionFilePath append:NO];
    
    NSOutputStream* ciphered = kEncrypt ? [[AesOutputStream alloc] initToOutputStream:outputFile encrypt:YES key:self.encryptionKey iv:self.encryptionIV] : outputFile;
    
    self.digested = [[Sha256PassThroughOutputStream alloc] initToOutputStream:ciphered];
    
    NSOutputStream* decompress = gzipDecompress ? [[GzipDecompressOutputStream alloc] initToOutputStream:self.digested] : self.digested;
    
    self.incrementalWriteStream = base64Decode ? [[Base64DecodeOutputStream alloc] initToOutputStream:decompress] : decompress;
}

- (BOOL)detectKeePassV3Compression:(NSString*)text {
    BOOL ret = NO;
    
    if (text.length > 3) {
        NSString* prefixStr = [text substringToIndex:4];
        NSData* prefix = [[NSData alloc] initWithBase64EncodedString:prefixStr options:kNilOptions];
        uint8_t* foo = (uint8_t*)prefix.bytes;
        ret = (foo[0] == 0x1f) && (foo[1] == 0x8b); // GZIP Magic
    }
        
    return ret;
}

- (NSInteger)writeStreamWithB64Text:(NSString *)text {
    if (self.incrementalWriteStream == nil) {
        self.compressed = [self detectKeePassV3Compression:text];
        [self createOutputPipeline:YES gzipDecompress:self.compressed];
        [self.incrementalWriteStream open];
    }

    // Do not do text.UTF8String the pointer is not released!!
    
    size_t len = [text lengthOfBytesUsingEncoding:NSASCIIStringEncoding];
    
    uint8_t* ascii = malloc(len);
    
    BOOL converted = [text getBytes:ascii maxLength:len usedLength:nil encoding:NSASCIIStringEncoding options:kNilOptions range:NSMakeRange(0, len) remainingRange:nil];
    
    if (!converted) {
        NSLog(@"Could not convert b64 text to ascii!");
        free(ascii);
        return -1;
    }

    NSInteger ret = [self writeStream:ascii maxLength:len];
    
    free(ascii);
     
    return ret;
}

- (NSInteger)writeStream:(const uint8_t*)buffer maxLength:(NSUInteger)len {
    return [self.incrementalWriteStream write:buffer maxLength:len];
}

- (void)closeWriteStream {
    [self.incrementalWriteStream close];
    
    // If it's for some reason an empty attachment then self.digested stream won't have been created - cater for this...
    // Handle weird edge case empty attachment
    
    self.attachmentLength = self.digested ? self.digested.length : 0;
    _sha256Hex = self.digested ? self.digested.digest.hex : kEmptyDataDigest;
}

- (NSInputStream *)getPlainTextInputStream {
    if (self.digested == nil) {
        return [NSInputStream inputStreamWithData:NSData.data]; // Handle weird edge case empty attachment
    }
 
    NSInputStream* inStream = [NSInputStream inputStreamWithFileAtPath:self.encryptedSessionFilePath];
    
    NSInputStream* aesDecrypt = kEncrypt ? [[AesInputStream alloc] initWithStream:inStream key:self.encryptionKey iv:self.encryptionIV] : inStream;
    
    return aesDecrypt;
}

- (NSData *)unitTestDataOnly {
    return [NSData dataWithContentsOfStream:[self getPlainTextInputStream]];
}

- (NSString*)getUniqueFileName {
    NSString* ret;
    
    do {
        ret = [FileManager.sharedInstance.tmpEncryptedAttachmentPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}

- (NSUInteger)length {
    return self.attachmentLength;
}

- (NSUInteger)estimatedStorageBytes {
    return self.length;
}

- (NSString *)digestHash {
    return self.sha256Hex;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Compressed: %d, Protected: %d, Size: %lu", self.compressed, self.protectedInMemory, (unsigned long)self.estimatedStorageBytes];
}

@end
