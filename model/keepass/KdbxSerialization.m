//
//  KeePassXmlSerialization.m
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KdbxSerialization.h"
#import "DecryptionParameters.h"
#import "Utils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "DecryptionParameters.h"
#import "PwSafeSerialization.h"
#import "Utils.h"
#import "NSData+GZIP.h"
#import "KeePassConstants.h"
#import "AesCipher.h"
#import "KdbxSerializationCommon.h"
#import "KeePassCiphers.h"
#import "GZipInputStream.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "KP31HashedBlockStream.h"
#import "StrongboxErrorCodes.h"

typedef struct _HeaderEntryHeader {
    uint8_t id;
    uint8_t lengthBytes[2];
} HeaderEntryHeader;
#define SIZE_OF_HEADER_ENTRY_HEADER      3

static const struct _BlockHeader EndOfBlocksHeaderTemplate; 

static const uint32_t kDefaultStartStreamBytesLength = 32;

static const uint32_t kKdbx3MajorVersionNumber = 3;
static const uint32_t kKdbx3MinorVersionNumber = 1;

@interface KdbxSerialization ()

@property (nonatomic) SerializationData* serializationData;
@property (nonatomic) NSMutableData* headerData;
@property (nonatomic) NSData* startStream;
@property (nonatomic) NSData* encryptionIv;
@property (nonatomic) NSData* masterKey;

@end

static BOOL kLogVerbose = NO;

@implementation KdbxSerialization

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return keePass2SignatureAndVersionMatch(prefix, kKdbx3MajorVersionNumber, kKdbx3MinorVersionNumber, error);
}

- (instancetype)init:(SerializationData*)serializationData {
    self = [super init];
    if (self) {
        self.serializationData = serializationData;
        self.headerData = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (void)stage1Serialize:(CompositeKeyFactors *)compositeKeyFactors
             completion:(SerializeCompletionBlock)completion {
    KeepassFileHeader header = getNewFileHeader(self.serializationData.fileVersion);
    [self.headerData appendBytes:&header length:SIZE_OF_KEEPASS_HEADER];
    
    
    
    NSData* compositeKey = getCompositeKey(compositeKeyFactors);
    NSData* transformSeed = getRandomData(kDefaultTransformSeedLength);
    NSData* transformKey = getAesTransformKey(compositeKey, transformSeed, self.serializationData.transformRounds);
    NSData* masterSeed = getRandomData(kMasterSeedLength); 
    
    if(compositeKeyFactors.yubiKeyCR) {
        NSData* challenge = masterSeed;
        

        
        compositeKeyFactors.yubiKeyCR(challenge, ^(BOOL userCancelled, NSData * _Nullable response, NSError * _Nullable error) {
            if(userCancelled || error) {
                completion(userCancelled, nil, error);
            }
            else {
                if (response == nil) {
                    error = [Utils createNSError:@"Nil response received from hardware key" errorCode:-1];
                    completion(NO, nil, error);
                    return;
                }

                self.masterKey = getMaster(masterSeed, transformKey, response);
                [self stage1point5Serialize:compositeKey transformSeed:transformSeed masterSeed:masterSeed completion:completion];
            }
        });
    }
    else {
        self.masterKey = getMaster(masterSeed, transformKey, nil);
        [self stage1point5Serialize:compositeKey transformSeed:transformSeed masterSeed:masterSeed completion:completion];
    }
}

- (void)stage1point5Serialize:(NSData*)compositeKey
                transformSeed:(NSData*)transformSeed
                   masterSeed:(NSData*)masterSeed
                   completion:(SerializeCompletionBlock)completion {
    id<Cipher> cipher = getCipher(self.serializationData.cipherId);
    if(!cipher) {
        NSString *message=[NSString stringWithFormat:@"Unknown Cipher ID: [%@]. Do not know how to decrypt.", [self.serializationData.cipherId UUIDString]];
        
        NSError *error = [Utils createNSError:message errorCode:-5];
        completion(NO, nil, error);
        return;
    }

    self.encryptionIv = [cipher generateIv];
    self.startStream = getRandomData(kDefaultStartStreamBytesLength);
    
    if(kLogVerbose) {
        slog(@"Serialize: compositeKey = [%@]", compositeKey);
        slog(@"Serialize: transformSeed = [%@]", transformSeed);
        slog(@"Serialize: masterSeed = [%@]", masterSeed);
        slog(@"Serialize: encryptionIv = [%@]", self.encryptionIv);
        slog(@"Serialize: StartStream = [%@]", self.startStream);
    }
    
    
    
    NSMutableDictionary<NSNumber *,NSData *>* headers = [[NSMutableDictionary alloc] initWithDictionary:self.serializationData.extraUnknownHeaders];
    
    [headers setObject:transformSeed forKey:@(TRANSFORMSEED)];
    [headers setObject:Uint64ToLittleEndianData(self.serializationData.transformRounds) forKey:@(TRANSFORMROUNDS)];
    [headers setObject:masterSeed forKey:@(MASTERSEED)];
    [headers setObject:self.encryptionIv forKey:@(ENCRYPTIONIV)];
    [headers setObject:self.startStream forKey:@(STREAMSTARTBYTES)];
    [headers setObject:Uint32ToLittleEndianData(self.serializationData.innerRandomStreamId) forKey:@(INNERRANDOMSTREAMID)];
    [headers setObject:self.serializationData.protectedStreamKey forKey:@(PROTECTEDSTREAMKEY)];
    [headers setObject:Uint32ToLittleEndianData(self.serializationData.compressionFlags) forKey:@(COMPRESSIONFLAGS)];
    uuid_t uuid;
    [self.serializationData.cipherId getUUIDBytes:uuid];
    [headers setObject:[NSData dataWithBytes:uuid length:sizeof(uuid_t)] forKey:@(CIPHERID)];
    
    NSData* headerEntriesData = [KdbxSerialization getHeadersData:headers];
    [self.headerData appendData:headerEntriesData];
    
    NSMutableData* hashData = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(self.headerData.bytes, (int)self.headerData.length, hashData.mutableBytes);
    
    NSString* ret = [hashData base64EncodedStringWithOptions:kNilOptions];
    
    completion(NO, ret, nil);
}

- (NSData *)stage2Serialize:(NSString *)xml error:(NSError **)error {
    NSMutableData *ret = [[NSMutableData alloc] initWithData:self.headerData];
    
    
    
    NSData* payload = [xml dataUsingEncoding:NSUTF8StringEncoding];
    payload = self.serializationData.compressionFlags == kGzipCompressionFlag ? [payload gzippedData] : payload;
    
    
    
    NSData * toBeEncrypted = getEncryptionBlob(payload, self.startStream);
    
    id<Cipher> cipher = getCipher(self.serializationData.cipherId);
    if(!cipher) {
        NSString *message=[NSString stringWithFormat:@"Unknown Cipher ID: [%@]. Do not know how to decrypt.", [self.serializationData.cipherId UUIDString]];
        
        if (error) {
            *error = [Utils createNSError:message errorCode:-5];
        }
        
        return nil;
    }

    NSData *encrypted = [cipher encrypt:toBeEncrypted iv:self.encryptionIv key:self.masterKey];
    
    if(!encrypted) {
        return nil;
    }
    
    [ret appendData:encrypted];
    
    return ret;
}

static BOOL readFileHeader(NSInputStream* stream, KeepassFileHeader *pFileHeader) {
    NSInteger bytesRead = [stream read:(uint8_t*)pFileHeader maxLength:SIZE_OF_KEEPASS_HEADER];
    
    return (bytesRead == SIZE_OF_KEEPASS_HEADER);
}

+ (void)deserialize:(NSInputStream *)stream
compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
      xmlDumpStream:(NSOutputStream*)xmlDumpStream
sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
         completion:(Kdbx31DeserializeCompletionBlock)completion {
    NSMutableData* headerDataForIntegrityCheck = [NSMutableData data];
    
    
    
    KeepassFileHeader fileHeader = {0};
    if (!readFileHeader(stream, &fileHeader)) {
        slog(@"Error reading KDBX 3.1 file header");
        NSError* error = [Utils createNSError:@"Error reading KDBX 3.1 file header" errorCode:-1];
        completion(NO, nil, nil, error);
        return;
    }
    [headerDataForIntegrityCheck appendBytes:&fileHeader length:SIZE_OF_KEEPASS_HEADER];
    
    
    
    NSDictionary<NSNumber *,NSObject *> *headerEntries = getHeaderEntries3(stream, headerDataForIntegrityCheck);
    
    if(!headerEntries) {
        slog(@"Error getting header entries. Possibly missing header entry.");
        NSError *error = [Utils createNSError:@"Error getting header entries. Possibly missing entry." errorCode:-3];
        completion(NO, nil, nil, error);
        return;
    }
    
    
    
    DecryptionParameters * decryptionParameters = getDecryptionParameters(headerEntries);
    if(kLogVerbose) {
        slog(@"DecryptionParameters: [%@]", decryptionParameters);
    }
    
    NSData* compositeKey = getCompositeKey(compositeKeyFactors);
    NSData* transformKey = getAesTransformKey(compositeKey, decryptionParameters.transformSeed, decryptionParameters.transformRounds);
    
    if (compositeKeyFactors.yubiKeyCR) {
        NSData* challenge = decryptionParameters.masterSeed;
        compositeKeyFactors.yubiKeyCR(challenge, ^(BOOL userCancelled, NSData * _Nullable response, NSError * _Nullable error) {
            if(userCancelled || error != nil) {
                completion(userCancelled, nil, nil, error);
            }
            else {
                if (response == nil) {
                    error = [Utils createNSError:@"Nil response received from hardware key" errorCode:-1];
                    completion(NO, nil, nil, error);
                    return;
                }
                
                NSData* masterKey = getMaster(decryptionParameters.masterSeed, transformKey, response);
                [KdbxSerialization deserializeStage2:stream
                                       headerEntries:headerEntries
                         headerDataForIntegrityCheck:headerDataForIntegrityCheck
                                decryptionParameters:decryptionParameters
                                           masterKey:masterKey
                                       xmlDumpStream:xmlDumpStream
                              sanityCheckInnerStream:sanityCheckInnerStream
                                          completion:completion];
            }
        });
    }
    else {
        NSData* masterKey = getMaster(decryptionParameters.masterSeed, transformKey, nil);
        [KdbxSerialization deserializeStage2:stream
                               headerEntries:headerEntries
                 headerDataForIntegrityCheck:headerDataForIntegrityCheck
                        decryptionParameters:decryptionParameters
                                   masterKey:masterKey
                               xmlDumpStream:xmlDumpStream
                      sanityCheckInnerStream:sanityCheckInnerStream
                                  completion:completion];
    }
}

+ (void)deserializeStage2:(NSInputStream *)inputStream
            headerEntries:(NSDictionary<NSNumber *,NSObject *> *)headerEntries
headerDataForIntegrityCheck:(NSData*)headerDataForIntegrityCheck
     decryptionParameters:(DecryptionParameters*)decryptionParameters
                masterKey:(NSData*)masterKey
            xmlDumpStream:(NSOutputStream*)xmlDumpStream
   sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
               completion:(Kdbx31DeserializeCompletionBlock)completion {
    NSMutableData* headerHash = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(headerDataForIntegrityCheck.bytes, (CC_LONG)headerDataForIntegrityCheck.length, headerHash.mutableBytes);
    
    if(kLogVerbose) {
        slog(@"HEADERHASH (ACTUAL): %@", [headerHash base64EncodedStringWithOptions:kNilOptions]);
    }
        
    
    
    id<Cipher> cipher = getCipher(decryptionParameters.cipherId);
    
    if(!cipher) {
        NSString *message=[NSString stringWithFormat:@"Unknown Cipher ID: [%@]. Do not know how to decrypt.", [decryptionParameters.cipherId UUIDString]];
        NSError *error = [Utils createNSError:message errorCode:-5];
        completion(NO, nil, nil, error);
        return;
    }
    
    NSInputStream *plaintextStream = [cipher getDecryptionStreamForStream:inputStream key:masterKey iv:decryptionParameters.encryptionIv];
    
    uint8_t *start = malloc(decryptionParameters.streamStartBytes.length);
    
    [plaintextStream open];
    NSInteger bytesReadFromStartStream = [plaintextStream read:start maxLength:decryptionParameters.streamStartBytes.length];

    if(bytesReadFromStartStream != decryptionParameters.streamStartBytes.length ||
       memcmp(start, decryptionParameters.streamStartBytes.bytes, decryptionParameters.streamStartBytes.length) != 0) {
      





        free(start);
        NSError *error = [Utils createNSError:@"Passphrase or Key File (Composite Key) Incorrect" errorCode:StrongboxErrorCodes.incorrectCredentials];
        completion(NO, nil, nil, error);
        return;
    }
    free(start);
    
    NSInputStream* deblockifiedStream = [[KP31HashedBlockStream alloc] initWithStream:plaintextStream];
    
    BOOL compressed = decryptionParameters.compressionFlags == kGzipCompressionFlag;
    NSInputStream* decompressedStream = compressed ? [[GZipInputStream alloc] initWithStream:deblockifiedStream] : deblockifiedStream;
        
    [decompressedStream open];
    
    NSError* error;
    NSError* innerStreamError;
    RootXmlDomainObject *rootXmlObject = [KdbxSerialization readXml:compressed
                                                             stream:decompressedStream
                                                innerRandomStreamId:decryptionParameters.innerRandomStreamId
                                                 protectedStreamKey:decryptionParameters.protectedStreamKey
                                                      xmlDumpStream:xmlDumpStream
                                             sanityCheckInnerStream:sanityCheckInnerStream
                                                   innerStreamError:&innerStreamError
                                                              error:&error];

    [decompressedStream close];
    
    if(rootXmlObject == nil) {
        slog(@"Could not parse XML: [%@]", error);
        completion(NO, nil, innerStreamError, error);
        return;
    }
    
    SerializationData* ret = [[SerializationData alloc] init];
    KeepassFileHeader keePassFileHeader = getKeePassFileHeader(headerDataForIntegrityCheck); 
    
    ret.fileVersion = [NSString stringWithFormat:@"%hu.%hu", keePassFileHeader.major, keePassFileHeader.minor];
    ret.transformRounds = decryptionParameters.transformRounds;
    ret.compressionFlags = decryptionParameters.compressionFlags;
    ret.innerRandomStreamId = decryptionParameters.innerRandomStreamId;
    ret.protectedStreamKey = decryptionParameters.protectedStreamKey;
    ret.extraUnknownHeaders = getUnknownHeaders(headerEntries);
    ret.headerHash = [headerHash base64EncodedStringWithOptions:kNilOptions];
    ret.rootXmlObject = rootXmlObject;
    ret.cipherId = decryptionParameters.cipherId;
    
    completion(NO, ret, innerStreamError, nil);
}

+ (RootXmlDomainObject*)readXml:(BOOL)compressed
                         stream:(NSInputStream*)stream
            innerRandomStreamId:(uint32_t)innerRandomStreamId
             protectedStreamKey:(NSData*)protectedStreamKey
                  xmlDumpStream:(NSOutputStream*)xmlDumpStream
         sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
               innerStreamError:(NSError**)innerStreamError
                          error:(NSError**)error {
    RootXmlDomainObject* rootXmlObject = parseXml(innerRandomStreamId, protectedStreamKey,
                                                XmlProcessingContext.standardV3Context, stream, xmlDumpStream, sanityCheckInnerStream, innerStreamError, error);
    return rootXmlObject;
}

+(NSData*)getHeadersData:(NSDictionary<NSNumber*, NSData*>*)headers {
    NSMutableData* ret = [[NSMutableData alloc] init];
    
    for (NSNumber* num in headers.allKeys) {
        NSData* data = [headers objectForKey:num];
        
        HeaderEntryHeader heh;
        heh.id = num.unsignedCharValue;
        
        NSData* lengthData = Uint16ToLittleEndianData(data.length);
        heh.lengthBytes[0] = ((uint8_t*)lengthData.bytes)[0];
        heh.lengthBytes[1] = ((uint8_t*)lengthData.bytes)[1];
        
        [ret appendBytes:&heh length:SIZE_OF_HEADER_ENTRY_HEADER];
        [ret appendData:data];
    }
    
    HeaderEntryHeader heh;
    heh.id = END_OF_ENTRIES;
    
    NSData *endOfEntriesWeirdString = [kEndOfHeaderEntriesMagicString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData* lengthData = Uint16ToLittleEndianData(endOfEntriesWeirdString.length);
    heh.lengthBytes[0] = ((uint8_t*)lengthData.bytes)[0];
    heh.lengthBytes[1] = ((uint8_t*)lengthData.bytes)[1];
    
    [ret appendBytes:&heh length:SIZE_OF_HEADER_ENTRY_HEADER];
    [ret appendData:endOfEntriesWeirdString];
    
    return ret;
}

static NSData * _Nonnull getEncryptionBlob(NSData *payload, NSData* startStream) {
    NSMutableData *blockified = [[NSMutableData alloc] init];
    
    uint64_t bytesRemaining = payload.length;
    int blockNumber = 0;
    while (bytesRemaining) {
        BlockHeader blockHeader;
        [Utils integerTolittleEndian4Bytes:blockNumber bytes:blockHeader.id];
        
        uint64_t blockLength = MIN(kDefaultBlockifySize, bytesRemaining);
        [Utils integerTolittleEndian4Bytes:(uint32_t)blockLength bytes:blockHeader.size];
        
        NSData* block = [payload subdataWithRange:NSMakeRange(blockNumber * kDefaultBlockifySize, (uint32_t)blockLength)];
        
        CC_SHA256(block.bytes, (CC_LONG)blockLength, blockHeader.hash);
   
        if(kLogVerbose) {
            slog(@"Writing Block %d [%llu bytes]", blockNumber, blockLength);
        }
        
        [blockified appendBytes:&blockHeader length:SIZE_OF_BLOCK_HEADER];
        [blockified appendData:block];
        
        bytesRemaining -= blockLength;
        blockNumber++;
    }
    
    BlockHeader endBlockHeader = EndOfBlocksHeaderTemplate;
    [Utils integerTolittleEndian4Bytes:blockNumber bytes:endBlockHeader.id];
    
    [blockified appendBytes:&endBlockHeader length:SIZE_OF_BLOCK_HEADER];
    
    
    
    NSMutableData* ret = [NSMutableData dataWithData:startStream];
    [ret appendData:blockified];
    
    return ret;
}

static NSDictionary<NSNumber *,NSObject *>* getUnknownHeaders(NSDictionary<NSNumber *,NSObject *>* headers) {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:headers];
    
    [ret removeObjectForKey:@(TRANSFORMSEED)];
    [ret removeObjectForKey:@(TRANSFORMROUNDS)];
    [ret removeObjectForKey:@(MASTERSEED)];
    [ret removeObjectForKey:@(ENCRYPTIONIV)];
    [ret removeObjectForKey:@(STREAMSTARTBYTES)];
    [ret removeObjectForKey:@(INNERRANDOMSTREAMID)];
    [ret removeObjectForKey:@(PROTECTEDSTREAMKEY)];
    [ret removeObjectForKey:@(COMPRESSIONFLAGS)];
    [ret removeObjectForKey:@(CIPHERID)];
















    
    return ret;
}

NSDictionary<NSNumber *,NSObject *>* getHeaderEntries3(NSInputStream* stream, NSMutableData* headerDataForIntegrityCheck) {
    NSMutableDictionary<NSNumber *,NSObject *> *headerEntries = [NSMutableDictionary dictionary];
    
    do {
        HeaderEntryHeader headerEntry;
        NSInteger bytesRead = [stream read:(uint8_t*)&headerEntry maxLength:SIZE_OF_HEADER_ENTRY_HEADER];
        
        if (bytesRead < 0 || bytesRead < SIZE_OF_HEADER_ENTRY_HEADER) {
            slog(@"Couldn't read Header Entry Header");
            return nil;
        }
        if ( headerDataForIntegrityCheck ) {
            [headerDataForIntegrityCheck appendBytes:&headerEntry length:bytesRead];
        }
        
        uint16_t length = littleEndian2BytesToUInt16(headerEntry.lengthBytes);
        NSMutableData* headerData = [NSMutableData dataWithLength:length];
        bytesRead = [stream read:headerData.mutableBytes maxLength:length];
        
        if (bytesRead < 0 || bytesRead < length) {
            slog(@"Couldn't read Header: [%ld]", (long)bytesRead);
            return nil;
        }
        if ( headerDataForIntegrityCheck ) {
            [headerDataForIntegrityCheck appendBytes:headerData.bytes length:bytesRead];
        }
        
        if(kLogVerbose) {
            slog(@"Found Header Entry of Type %d and length %d", headerEntry.id, length);
        }
        
        if(END_OF_ENTRIES == headerEntry.id) {
            
            break;
        }
        else {
            NSObject* obj = getHeaderEntryObject(headerEntry.id, headerData);
            if(obj) {
                [headerEntries setObject:obj forKey:@(headerEntry.id)];
            }
        }
    } while (YES);
    
    if (kLogVerbose) {
        dumpHeaderEntries(headerEntries);
    }
    
    if (![KdbxSerialization verifyRequiredHeadersPresent:headerEntries]) {
        return nil;
    }
    
    return headerEntries;
}

+(BOOL)verifyRequiredHeadersPresent:(NSMutableDictionary<NSNumber *,NSObject *> *)headerEntries {
    if(![headerEntries objectForKey:@(TRANSFORMSEED)]){
        slog(@"Missing required TRANSFORMSEED header entry.");
        return NO;
    }
    
    if(![headerEntries objectForKey:@(TRANSFORMROUNDS)]) {
        slog(@"Missing required TRANSFORMROUNDS header entry.");
        return NO;
    }
    
    if(![headerEntries objectForKey:@(MASTERSEED)]) {
        slog(@"Missing required MASTERSEED header entry.");
        return NO;
    }
    
    if(![headerEntries objectForKey:@(ENCRYPTIONIV)]) {
        slog(@"Missing required ENCRYPTIONIV header entry.");
        return NO;
    }
    
    
    if(![headerEntries objectForKey:@(STREAMSTARTBYTES)]) {
        slog(@"Missing required STREAMSTARTBYTES header entry.");
        return NO;
    }
    
    if([headerEntries objectForKey:@(INNERRANDOMSTREAMID)] && ![headerEntries objectForKey:@(PROTECTEDSTREAMKEY)]) {
        slog(@"Missing required PROTECTEDSTREAMKEY because INNERRANDOMSTREAMID is Present.");
        return NO;
    }
    
    return YES;
}

static DecryptionParameters *getDecryptionParameters(NSDictionary *headerEntries) {
    DecryptionParameters *decryptionParameters = [[DecryptionParameters alloc] init];
    decryptionParameters.transformSeed = [headerEntries objectForKey:@(TRANSFORMSEED)];
    
    NSNumber* num = [headerEntries objectForKey:@(TRANSFORMROUNDS)];
    decryptionParameters.transformRounds = num.longLongValue;
    
    decryptionParameters.masterSeed = [headerEntries objectForKey:@(MASTERSEED)];
    decryptionParameters.encryptionIv = [headerEntries objectForKey:@(ENCRYPTIONIV)];
    decryptionParameters.streamStartBytes = [headerEntries objectForKey:@(STREAMSTARTBYTES)];
    
    num = [headerEntries objectForKey:@(COMPRESSIONFLAGS)];
    decryptionParameters.compressionFlags = (uint32_t)num.integerValue;
    
    num = [headerEntries objectForKey:@(INNERRANDOMSTREAMID)];
    decryptionParameters.innerRandomStreamId = num != nil ? num.intValue : 0;
    decryptionParameters.protectedStreamKey = [headerEntries objectForKey:@(PROTECTEDSTREAMKEY)];
    
    NSData* cipherData = [headerEntries objectForKey:@(CIPHERID)];
    decryptionParameters.cipherId = cipherData ? [[NSUUID alloc] initWithUUIDBytes:cipherData.bytes] : aesCipherUuid();
    
    if(kLogVerbose) {
        slog(@"DECRYPTION PARAMETERS = [%@]", decryptionParameters);
    }
    
    return decryptionParameters;
}



static NSData *getMaster(NSData* masterSeed, NSData *transformKey, NSData* yubiResponse) {
    NSMutableData *masterKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, masterSeed.bytes, (CC_LONG)masterSeed.length);
    
    if(yubiResponse) {
        NSData* hashed = yubiResponse.sha256;
        CC_SHA256_Update(&context, hashed.bytes, (CC_LONG)hashed.length);
    }
    
    CC_SHA256_Update(&context, transformKey.bytes, (CC_LONG)transformKey.length);
    
    
    CC_SHA256_Final(masterKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        slog(@"MASTER KEY: %@", [masterKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return [masterKey copy];
}

static NSData *getCompositeKey(CompositeKeyFactors* compositeKeyFactors) {
    NSData *hashedPassword = compositeKeyFactors.password != nil ? compositeKeyFactors.password.sha256Data : nil;
        
    
    
    NSMutableData *compositeKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    
    if(hashedPassword) {
        CC_SHA256_Update(&context, hashedPassword.bytes, (CC_LONG)hashedPassword.length);
    }
    
    if(compositeKeyFactors.keyFileDigest) {
        CC_SHA256_Update(&context, compositeKeyFactors.keyFileDigest.bytes, (CC_LONG)compositeKeyFactors.keyFileDigest.length);
    }

    
    





    
    CC_SHA256_Final(compositeKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        slog(@"COMPOSITE KEY: %@", [compositeKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return compositeKey;
}

@end
