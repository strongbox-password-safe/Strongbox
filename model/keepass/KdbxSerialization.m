//
//  KeePassXmlSerialization.m
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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

typedef struct _HeaderEntryHeader {
    uint8_t id;
    uint8_t lengthBytes[2];
} HeaderEntryHeader;
#define SIZE_OF_HEADER_ENTRY_HEADER      3

typedef struct _BlockHeader {
    uint8_t id[4];
    uint8_t hash[32];
    uint8_t size[4];
} BlockHeader;
#define SIZE_OF_BLOCK_HEADER 40

static const struct _BlockHeader EndOfBlocksHeaderTemplate; // Useful way to zero everything out. Id needs to be set on use.

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

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error {
    return keePass2SignatureAndVersionMatch(candidate, kKdbx3MajorVersionNumber, kKdbx3MinorVersionNumber, error);
}

- (instancetype)init:(SerializationData*)serializationData {
    self = [super init];
    if (self) {
        self.serializationData = serializationData;
        self.headerData = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (void)stage1Serialize:(CompositeKeyFactors *)compositeKeyFactors completion:(SerializeCompletionBlock)completion {
    KeepassFileHeader header = getNewFileHeader(self.serializationData.fileVersion);
    [self.headerData appendBytes:&header length:SIZE_OF_KEEPASS_HEADER];
    
    // 2. Generate Encryption Parameters To Be Serialized in the Headers
    
    NSData* compositeKey = getCompositeKey(compositeKeyFactors);
    NSData* transformSeed = getRandomData(kDefaultTransformSeedLength);
    NSData* transformKey = getAesTransformKey(compositeKey, transformSeed, self.serializationData.transformRounds);
    NSData* masterSeed = getRandomData(kMasterSeedLength);
    
    if(compositeKeyFactors.yubiKeyCR) {
        NSData* challenge = masterSeed;
        compositeKeyFactors.yubiKeyCR(challenge, ^(BOOL userCancelled, NSData * _Nullable response, NSError * _Nullable error) {
            if(userCancelled || !response || error) {
                completion(userCancelled, nil, error);
            }
            else {
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
        NSLog(@"Serialize: compositeKey = [%@]", compositeKey);
        NSLog(@"Serialize: transformSeed = [%@]", transformSeed);
        NSLog(@"Serialize: masterSeed = [%@]", masterSeed);
        NSLog(@"Serialize: encryptionIv = [%@]", self.encryptionIv);
        NSLog(@"Serialize: StartStream = [%@]", self.startStream);
    }
    
    // 3. Headers
    
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
    
    // 4. Xml to Payload Data (optional GZIP compression)
    
    NSData* payload = [xml dataUsingEncoding:NSUTF8StringEncoding];
    payload = self.serializationData.compressionFlags == kGzipCompressionFlag ? [payload gzippedData] : payload;
    
    // 5. Get Encrypted Data Blob
    
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

+ (void)deserialize:(NSData *)safeData
compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
         completion:(DeserializeCompletionBlock)completion {
    size_t offset;
    NSDictionary<NSNumber *,NSObject *> *headerEntries = getHeaderEntries3((uint8_t*)safeData.bytes, safeData.length, &offset);
    if(!headerEntries) {
        NSLog(@"Error getting header entries. Possibly missing header entry.");
        NSError *error = [Utils createNSError:@"Error getting header entries. Possibly missing entry." errorCode:-3];
        completion(NO, nil, error);
        return;
    }
    
    DecryptionParameters * decryptionParameters = getDecryptionParameters(headerEntries);
    if(kLogVerbose) {
        NSLog(@"DecryptionParameters: [%@]", decryptionParameters);
    }
    
    NSData* compositeKey = getCompositeKey(compositeKeyFactors);
    NSData* transformKey = getAesTransformKey(compositeKey, decryptionParameters.transformSeed, decryptionParameters.transformRounds);
    
    if (compositeKeyFactors.yubiKeyCR) {
        NSData* challenge = decryptionParameters.masterSeed;
        compositeKeyFactors.yubiKeyCR(challenge, ^(BOOL userCancelled, NSData * _Nullable response, NSError * _Nullable error) {
            if(userCancelled || error != nil) {
                completion(userCancelled, nil, error);
            }
            else {
                NSData* masterKey = getMaster(decryptionParameters.masterSeed, transformKey, response);
                [KdbxSerialization deserializeStage2:safeData offset:offset headerEntries:headerEntries decryptionParameters:decryptionParameters masterKey:masterKey completion:completion];
            }
        });
    }
    else {
        NSData* masterKey = getMaster(decryptionParameters.masterSeed, transformKey, nil);
        [KdbxSerialization deserializeStage2:safeData offset:offset headerEntries:headerEntries decryptionParameters:decryptionParameters masterKey:masterKey completion:completion];
    }
}

+ (void)deserializeStage2:(NSData *)safeData
                   offset:(size_t)offset
            headerEntries:(NSDictionary<NSNumber *,NSObject *> *)headerEntries
     decryptionParameters:(DecryptionParameters*)decryptionParameters
                masterKey:(NSData*)masterKey
               completion:(DeserializeCompletionBlock)completion {
    // Hash Header for corruption check
    
    NSMutableData* headerHash = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(safeData.bytes, (CC_LONG)offset, headerHash.mutableBytes);
    
    if(kLogVerbose) {
        NSLog(@"HEADERHASH (ACTUAL): %@", [headerHash base64EncodedStringWithOptions:kNilOptions]);
    }
    
    NSData *dataIn = [safeData subdataWithRange:NSMakeRange(offset, safeData.length - offset)];
    
    // Decrypt
    
    id<Cipher> cipher = getCipher(decryptionParameters.cipherId);
    
    if(!cipher) {
        NSString *message=[NSString stringWithFormat:@"Unknown Cipher ID: [%@]. Do not know how to decrypt.", [decryptionParameters.cipherId UUIDString]];
        NSError *error = [Utils createNSError:message errorCode:-5];
        completion(NO, nil, error);
        return;
    }
    
    NSData *decrypted = [cipher decrypt:dataIn iv:decryptionParameters.encryptionIv key:masterKey];
    if(decrypted == nil) {
        NSError *error = [Utils createNSError:@"Could not decrypt using provided parameters" errorCode:-1];
        completion(NO, nil, error);
        return;
    }

    // Verify Start Stream - This checks the correct passphrase/keyfile has been used (or we've done something very wrong in the decryption process :/)
    
    NSData *actualStartStream = [decrypted subdataWithRange:NSMakeRange(0, decryptionParameters.streamStartBytes.length)];
    if(![decryptionParameters.streamStartBytes isEqualToData:actualStartStream]) {
        NSError *error = [Utils createNSError:@"Passphrase or Key File (Composite Key) Incorrect" errorCode:kStrongboxErrorCodeIncorrectCredentials];
        completion(NO, nil, error);
        return;
    }
    
    // Deblockify
    
    NSData* deblockified = deblockify((uint8_t*)&decrypted.bytes[decryptionParameters.streamStartBytes.length]);
    
    if(!deblockified) {
        NSError *error = [Utils createNSError:@"Could not find next block in unordered blocks list. Cannot deblockify" errorCode:-6];
        completion(NO, nil, error);
        return;
    }
    
    BOOL compressed = decryptionParameters.compressionFlags == kGzipCompressionFlag;
    NSError* error;
    RootXmlDomainObject *rootXmlObject = [KdbxSerialization readXml:compressed
                                                             source:deblockified
                                                innerRandomStreamId:decryptionParameters.innerRandomStreamId
                                                 protectedStreamKey:decryptionParameters.protectedStreamKey
                                                              error:&error];

    if(rootXmlObject == nil) {
        NSLog(@"Could not parse XML: [%@]", error);
        completion(NO, nil, error);
        return;
    }
    
    SerializationData* ret = [[SerializationData alloc] init];
    KeepassFileHeader keePassFileHeader = getKeePassFileHeader(safeData);
    
    ret.fileVersion = [NSString stringWithFormat:@"%hu.%hu", keePassFileHeader.major, keePassFileHeader.minor];
    ret.transformRounds = decryptionParameters.transformRounds;
    ret.compressionFlags = decryptionParameters.compressionFlags;
    ret.innerRandomStreamId = decryptionParameters.innerRandomStreamId;
    ret.protectedStreamKey = decryptionParameters.protectedStreamKey;
    ret.extraUnknownHeaders = getUnknownHeaders(headerEntries);
    ret.headerHash = [headerHash base64EncodedStringWithOptions:kNilOptions];
    ret.rootXmlObject = rootXmlObject;
    ret.cipherId = decryptionParameters.cipherId;
    
    completion(NO, ret, nil);
}

+ (RootXmlDomainObject*)readXml:(BOOL)compressed
                         source:(NSData*)source
            innerRandomStreamId:(uint32_t)innerRandomStreamId
             protectedStreamKey:(NSData*)protectedStreamKey
                          error:(NSError**)error {
    
    NSInputStream* stream = compressed ? [[GZipInputStream alloc] initWithData:source] : [NSInputStream inputStreamWithData:source];
    [stream open];
    
    RootXmlDomainObject* rootXmlObject = parseXml(innerRandomStreamId, protectedStreamKey,
                                                XmlProcessingContext.standardV3Context, stream, error);
    
    [stream close];
    
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
            NSLog(@"Writing Block %d [%llu bytes]", blockNumber, blockLength);
        }
        
        [blockified appendBytes:&blockHeader length:SIZE_OF_BLOCK_HEADER];
        [blockified appendData:block];
        
        bytesRemaining -= blockLength;
        blockNumber++;
    }
    
    BlockHeader endBlockHeader = EndOfBlocksHeaderTemplate;
    [Utils integerTolittleEndian4Bytes:blockNumber bytes:endBlockHeader.id];
    
    [blockified appendBytes:&endBlockHeader length:SIZE_OF_BLOCK_HEADER];
    
    // 3. We prefix our blockified data with random Start Stream Bytes (Used to check we've got the right password only I believe)
    
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

NSDictionary<NSNumber *,NSObject *>* getHeaderEntries3(uint8_t * const buffer, size_t bufferLength, size_t* finalOffset) {
    NSMutableDictionary<NSNumber *,NSObject *> *headerEntries = [NSMutableDictionary dictionary];
    
    int offset = SIZE_OF_KEEPASS_HEADER;
    
    while (offset + SIZE_OF_HEADER_ENTRY_HEADER <= bufferLength) {
        HeaderEntryHeader *headerEntry = (HeaderEntryHeader*)&buffer[offset];
        
        int16_t length = littleEndian2BytesToInt16(headerEntry->lengthBytes);
        uint8_t* data = &buffer[offset + SIZE_OF_HEADER_ENTRY_HEADER];
        NSData* headerData = [NSData dataWithBytes:data length:length];
        
        if(kLogVerbose) {
            NSLog(@"Found Header Entry of Type %d and length %d", headerEntry->id, length);
        }
        
        if(offset + SIZE_OF_HEADER_ENTRY_HEADER + length > bufferLength) {
            NSLog(@"This safe appears to be corrupt. Header entry found at [%d] with length of [%d] but only [%lu] data bytes total.", offset, length, bufferLength);
            return nil;
        }
        
        offset += SIZE_OF_HEADER_ENTRY_HEADER + length;
        
        if(END_OF_ENTRIES == headerEntry->id) {
            //NSLog(@"END_OF_ENTRIES: %@", headerData);
            break;
        }
        else {
            NSObject* obj = getHeaderEntryObject(headerEntry->id, headerData);
            if(obj) {
                [headerEntries setObject:obj forKey:@(headerEntry->id)];
            }
        }
    }
    
    if(kLogVerbose) {
        dumpHeaderEntries(headerEntries);
    }
    
    if(![KdbxSerialization verifyRequiredHeadersPresent:headerEntries]) {
        return nil;
    }
    
    *finalOffset = offset;
    return headerEntries;
}

+(BOOL)verifyRequiredHeadersPresent:(NSMutableDictionary<NSNumber *,NSObject *> *)headerEntries {
    if(![headerEntries objectForKey:@(TRANSFORMSEED)]){
        NSLog(@"Missing required TRANSFORMSEED header entry.");
        return NO;
    }
    
    if(![headerEntries objectForKey:@(TRANSFORMROUNDS)]) {
        NSLog(@"Missing required TRANSFORMROUNDS header entry.");
        return NO;
    }
    
    if(![headerEntries objectForKey:@(MASTERSEED)]) {
        NSLog(@"Missing required MASTERSEED header entry.");
        return NO;
    }
    
    if(![headerEntries objectForKey:@(ENCRYPTIONIV)]) {
        NSLog(@"Missing required ENCRYPTIONIV header entry.");
        return NO;
    }
    
    
    if(![headerEntries objectForKey:@(STREAMSTARTBYTES)]) {
        NSLog(@"Missing required STREAMSTARTBYTES header entry.");
        return NO;
    }
    
    if([headerEntries objectForKey:@(INNERRANDOMSTREAMID)] && ![headerEntries objectForKey:@(PROTECTEDSTREAMKEY)]) {
        NSLog(@"Missing required PROTECTEDSTREAMKEY because INNERRANDOMSTREAMID is Present.");
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
        NSLog(@"DECRYPTION PARAMETERS = [%@]", decryptionParameters);
    }
    
    return decryptionParameters;
}

static NSData* deblockify(uint8_t* blockified) {
    BlockHeader* block = (BlockHeader*)blockified;
    
    NSMutableDictionary<NSNumber*, NSData*> *unorderedBlocks = [NSMutableDictionary dictionary];
    while(YES) {
        uint32_t size = littleEndian4BytesToInt32(block->size);
        uint32_t blockId = littleEndian4BytesToInt32(block->id);
        
        if(kLogVerbose) {
            NSLog(@"Found block id [%d] and size=[%d]", blockId, size);
        }
        
        if(size == 0) {
            break;
        }
        
        uint8_t* data = (((uint8_t*)block) + SIZE_OF_BLOCK_HEADER);
        NSData *blockData = [NSData dataWithBytes:data length:size];
        
        uint8_t actualHashBytes[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(blockData.bytes, (uint32_t)blockData.length, actualHashBytes);
        NSData* actualHash = [NSData dataWithBytes:actualHashBytes length:CC_SHA256_DIGEST_LENGTH];
        NSData* expectedHash = [NSData dataWithBytes:block->hash length:CC_SHA256_DIGEST_LENGTH];

        if(![actualHash isEqualToData:expectedHash]) {
            NSLog(@"Block Header Hash does not match content. This safe is possibly corrupt.");
            NSLog(@"%@ != %@", [actualHash base64EncodedDataWithOptions:kNilOptions], [expectedHash base64EncodedDataWithOptions:kNilOptions]);
            return nil;
        }
        
        [unorderedBlocks setObject:blockData forKey:@(blockId)];
        
        block = (BlockHeader*)(((uint8_t*)block) + SIZE_OF_BLOCK_HEADER + size);
    }
    
    NSMutableData* deblockified = [NSMutableData data];
    for(int i=0;i<unorderedBlocks.count;i++) {
        NSData* blockData = [unorderedBlocks objectForKey:@(i)];
        
        if(!blockData) {
            NSLog(@"Could not find block %d in unordered blocks list. Cannot deblockify.", i);
            return nil;
        }
        
        if(kLogVerbose) {
            NSLog(@"Adding Block %d", i);
        }
        
        [deblockified appendData:blockData];
    }
    
    return [deblockified copy];
}

// MMcG: Because of the funky KDBX 3.1 YubiKey Challenge Response Design :(

static NSData *getMaster(NSData* masterSeed, NSData *transformKey, NSData* yubiResponse) {
    NSMutableData *masterKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, masterSeed.bytes, (CC_LONG)masterSeed.length);
    
    if(yubiResponse) {
        NSData* hashed = sha256(yubiResponse);
        CC_SHA256_Update(&context, hashed.bytes, (CC_LONG)hashed.length);
    }
    
    CC_SHA256_Update(&context, transformKey.bytes, (CC_LONG)transformKey.length);
    
    
    CC_SHA256_Final(masterKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        NSLog(@"MASTER KEY: %@", [masterKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return [masterKey copy];
}

static NSData *getCompositeKey(CompositeKeyFactors* compositeKeyFactors) {
    NSData *hashedPassword = compositeKeyFactors.password != nil ? sha256([compositeKeyFactors.password dataUsingEncoding:NSUTF8StringEncoding]) : nil;
    
    // Concatenate together in one big sha256...
    
    NSMutableData *compositeKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    
    if(hashedPassword) {
        CC_SHA256_Update(&context, hashedPassword.bytes, (CC_LONG)hashedPassword.length);
    }
    
    if(compositeKeyFactors.keyFileDigest) {
        CC_SHA256_Update(&context, compositeKeyFactors.keyFileDigest.bytes, (CC_LONG)compositeKeyFactors.keyFileDigest.length);
    }

    // Not done here as in KDBX4.0 - Handled in get Master :(
    
//    if(compositeKeyFactors.yubiKeyResponse) {
//        NSLog(@"YUBI: Adding YubiKey Challenge Response to Composite Key");
//        NSData *hashed = sha256(compositeKeyFactors.yubiKeyResponse);
//        CC_SHA256_Update(&context, hashed.bytes, (CC_LONG)hashed.length);
//    }
    
    CC_SHA256_Final(compositeKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        NSLog(@"COMPOSITE KEY: %@", [compositeKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return compositeKey;
}

@end
