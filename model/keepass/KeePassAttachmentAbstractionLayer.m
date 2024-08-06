//
//  Attachment.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassAttachmentAbstractionLayer.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import <CommonCrypto/CommonCrypto.h>

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

#import "Utils.h"
#import "Base64DecodeOutputStream.h"
#import "GzipDecompressOutputStream.h"
#import "AesOutputStream.h"
#import "Sha256PassThroughOutputStream.h"
#import "AesInputStream.h"

static const int kBlockSize = 32 * 1024;
static NSString* kEmptyDataDigest;

static const BOOL kEncrypt = YES; 

#if defined(TARGET_OS_IPHONE) && defined(IS_APP_EXTENSION) && defined(MEMORY_PERF_MEASURES)
static const BOOL kMemoryPerfMeasuresEnabled = YES;
#else
static const BOOL kMemoryPerfMeasuresEnabled = NO;
#endif

@interface KeePassAttachmentAbstractionLayer ()

@property NSString* encryptedSessionFilePath;
@property NSData* encryptionKey;
@property NSData* encryptionIV;
@property NSString* sha256Hex;
@property NSUInteger attachmentLength;
@property NSOutputStream* memoryStream;

@property NSOutputStream* incrementalWriteStream;
@property Sha256PassThroughOutputStream* digested;

@end

@implementation KeePassAttachmentAbstractionLayer

+ (void)initialize {
    if(self == [KeePassAttachmentAbstractionLayer class]) {
        kEmptyDataDigest = NSData.data.sha256.upperHexString; 
    }
}

- (instancetype)initNonPerformantWithData:(NSData *)data compressed:(BOOL)compressed protectedInMemory:(BOOL)protectedInMemory {
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
            slog(@"Error reading stream... [%ld]", (long)read);
            return nil;
        }
    }
    
    return self;
}
    
- (instancetype)initWithStream:(NSInputStream *)stream
                        length:(NSUInteger)length
             protectedInMemory:(BOOL)protectedInMemory
                    compressed:(BOOL)compressed {
    if (self = [self initForStreamWriting:protectedInMemory compressed:compressed]) {
        _compressed = compressed;
        _protectedInMemory = protectedInMemory;
        
        [stream open];
        
        uint8_t block[kBlockSize];
        for (size_t readSoFar = 0; readSoFar < length; readSoFar += kBlockSize) {
            size_t remaining = length - readSoFar;
            size_t bytesToReadThisTime = remaining > kBlockSize ? kBlockSize : remaining;
            NSInteger read = [stream read:block maxLength:bytesToReadThisTime];
            if (read <= 0) {
                slog(@"Not enough data to read specified length of attachment. Read = %ld, Requested = %ld", (long)read, bytesToReadThisTime);
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
        
#if defined(TARGET_OS_IPHONE) && defined(IS_APP_EXTENSION) && defined(MEMORY_PERF_MEASURES)
        if ( kMemoryPerfMeasuresEnabled ) {
            self.encryptedSessionFilePath = [self getUniqueFileName];
        }
#endif
        

        
        self.attachmentLength = 0;
        _sha256Hex = kEmptyDataDigest;
    }
    
    return self;
}

- (NSInteger)writeStreamWithPlainDecompressedBytes:(const uint8_t*)buffer maxLength:(NSUInteger)len { 
    if (self.incrementalWriteStream == nil) {
        [self createOutputPipeline:NO gzipDecompress:NO];
        [self.incrementalWriteStream open];
    }
    
    return [self writeStream:buffer maxLength:len];
    
}

- (NSOutputStream*)getOutputStream {
    if ( kMemoryPerfMeasuresEnabled ) {
        return [NSOutputStream outputStreamToFileAtPath:self.encryptedSessionFilePath append:NO];
    }
    else {
        self.memoryStream = [NSOutputStream outputStreamToMemory];
        return self.memoryStream;
    }
}

- (NSInputStream*)getInputStream {
    if ( kMemoryPerfMeasuresEnabled ) {
        NSError* error = nil;
        [NSFileManager.defaultManager attributesOfItemAtPath:self.encryptedSessionFilePath error:&error];
        if ( error ) {
            slog(@"Could not find encrypted session file! Cannot return input stream [%@]", error);
            return nil;
        }
        
        return [NSInputStream inputStreamWithFileAtPath:self.encryptedSessionFilePath];
    }
    else {
        if ( !self.memoryStream ) {
            slog(@"🔴 Could not find memory stream! Cannot return input stream");
            return nil;
        }
        
        NSData* data = [self.memoryStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        return [NSInputStream inputStreamWithData:data];
    }
}

- (void)createOutputPipeline:(BOOL)base64Decode gzipDecompress:(BOOL)gzipDecompress {
    NSOutputStream* outputStream = [self getOutputStream];

    NSOutputStream* ciphered;
    if ( kEncrypt ) {
        ciphered = [[AesOutputStream alloc] initToOutputStream:outputStream encrypt:YES key:self.encryptionKey iv:self.encryptionIV chainOpensAndCloses:YES];
    }
    else {
        ciphered = outputStream;
    }
 
    
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
        ret = (foo[0] == 0x1f) && (foo[1] == 0x8b); 
    }
        
    return ret;
}

- (NSInteger)writeStreamWithB64Text:(NSString *)text {
    if (self.incrementalWriteStream == nil) {
        self.compressed = [self detectKeePassV3Compression:text];
        [self createOutputPipeline:YES gzipDecompress:self.compressed];
        [self.incrementalWriteStream open];
    }

    
    
    size_t len = [text lengthOfBytesUsingEncoding:NSASCIIStringEncoding];
    
    uint8_t* ascii = malloc(len);
    
    BOOL converted = [text getBytes:ascii maxLength:len usedLength:nil encoding:NSASCIIStringEncoding options:kNilOptions range:NSMakeRange(0, len) remainingRange:nil];
    
    if (!converted) {
        slog(@"Could not convert b64 text to ascii!");
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
    
    
    
    
    self.attachmentLength = self.digested ? self.digested.length : 0;
    _sha256Hex = self.digested ? self.digested.digest.upperHexString : kEmptyDataDigest;
}

- (NSInputStream *)getPlainTextInputStream {
    if (self.digested == nil) {
        return [NSInputStream inputStreamWithData:NSData.data]; 
    }
 
    NSInputStream* inStream = [self getInputStream];
    
    NSInputStream* aesDecrypt = kEncrypt ? [[AesInputStream alloc] initWithStream:inStream key:self.encryptionKey iv:self.encryptionIV] : inStream;
    
    return aesDecrypt;
}

- (NSData *)nonPerformantFullData {
    return [NSData dataWithContentsOfStream:[self getPlainTextInputStream]];
}

#if defined(TARGET_OS_IPHONE) && defined(IS_APP_EXTENSION) && defined(MEMORY_PERF_MEASURES)
- (NSString*)getUniqueFileName {
    NSString* ret;
    
    do {
        ret = [StrongboxFilesManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}
#endif

- (NSUInteger)length {
    return self.attachmentLength;
}

- (NSUInteger)estimatedStorageBytes {
    return self.length;
}

- (NSString *)digestHash {
    return self.sha256Hex;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[KeePassAttachmentAbstractionLayer class]]) {
        return NO;
    }
    
    KeePassAttachmentAbstractionLayer* other = (KeePassAttachmentAbstractionLayer*)object;
    







    
    if ( ![self.digestHash isEqualToString:other.digestHash] ) {
        return NO;
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Compressed: %d, Protected: %d, Length = [%lu bytes], SHA256 = [%@]", self.compressed, self.protectedInMemory, (unsigned long)self.length, self.digestHash];
}

@end
