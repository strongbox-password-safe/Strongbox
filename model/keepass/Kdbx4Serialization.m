//
//  Kdbx4Serialization.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Kdbx4Serialization.h"
#import "Utils.h"
#import "KdbxSerializationCommon.h"
#import "KdfParameters.h"
#import "KeePassCiphers.h"
#import "Argon2KdfCipher.h"
#import "ChaCha20Cipher.h"
#import "NSData+GZIP.h"
#import <CommonCrypto/CommonCrypto.h>
#import "CryptoParameters.h"
#import "Kdbx4SerializationData.h"
#import "KeePassConstants.h"
#import "DatabaseAttachment.h"
#import "PwSafeSerialization.h"
#import "VariantDictionary.h"
#import "Keys.h"
#import "AesKdfCipher.h"
#import "GZipInputStream.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "HmacBlockStream.h"

static const uint8_t kInnerHeaderTypeEnd = 0;
static const uint8_t kInnerHeaderTypeInnerRandomStreamId = 1;
static const uint8_t kInnerHeaderTypeInnerRandomStreamKey = 2;
static const uint8_t kInnerHeaderTypeBinary = 3;

static const BOOL kLogVerbose = NO;


@implementation Kdbx4Serialization

+ (NSData *)getYubikeyChallenge:(KdfParameters *)kdfParameters error:(NSError * _Nullable __autoreleasing *)error {
//    CryptoParameters* cp = [Kdbx4Serialization getCryptoParams:candidate];
//
    id<KeyDerivationCipher> kdf = getKeyDerivationCipher(kdfParameters, error);
    
    if(!kdf) {
        NSLog(@"Could not create KDF Cipher with KDFPARAMS: [%@]", kdfParameters);
        return nil;
    }
    
    return kdf.transformSeed;
}

+ (void)serialize:(Kdbx4SerializationData *)serializationData
              xml:(NSString *)xml
              ckf:(CompositeKeyFactors *)ckf
       completion:(Serialize4CompletionBlock)completion {
    if(kLogVerbose) {
        NSLog(@"Serializing with [%@] and password [%@]", serializationData, ckf);
    }
    
    // 1. File Header
    
    KeepassFileHeader header = getNewFileHeader(serializationData.fileVersion);
    
    NSMutableData* headerData = [NSMutableData data];
    [headerData appendBytes:&header length:SIZE_OF_KEEPASS_HEADER];
    
    // 2. Generate Encryption Parameters To Be Serialized in the Headers
    
    NSData* masterSeed = getRandomData(kMasterSeedLength);
    id<Cipher> cipher = getCipher(serializationData.cipherUuid);
    
    if(!cipher) {
        NSLog(@"Could not get Cipher %@", serializationData.cipherUuid.UUIDString);
        NSError* error = [Utils createNSError:@"Could not get appropriate Cipher." errorCode:-1];
        completion(NO, nil, error);
        return;
    }
    
    NSError* error;
    NSData* yubiKeyChallenge = [Kdbx4Serialization getYubikeyChallenge:serializationData.kdfParameters error:&error];
    if(error) {
        completion(NO, nil, error);
        return;
    }
    
    [Kdbx4Serialization getKeys:yubiKeyChallenge
            compositeKeyFactors:ckf
                  kdfParameters:serializationData.kdfParameters
                     masterSeed:masterSeed
                     completion:^(BOOL userCancelled, Keys * _Nullable keys, NSError * _Nullable error) {
        if(userCancelled || error || keys == nil) {
            if(!keys && !userCancelled) {
                NSLog(@"Could not get Keys.");
                error = [Utils createNSError:@"Could not determine appropriate keys." errorCode:-1];
            }
            completion(userCancelled, nil, error);
        }
        else {
            [Kdbx4Serialization stage2Serialize:keys
                                            xml:xml
                                     headerData:headerData
                              serializationData:serializationData
                                         cipher:cipher
                                     masterSeed:masterSeed
                                     completion:completion];
        }
    }];
}

+ (void)stage2Serialize:(Keys*)keys
                    xml:(NSString *)xml
             headerData:(NSMutableData*)headerData
      serializationData:(Kdbx4SerializationData *)serializationData
                 cipher:(id<Cipher>)cipher
             masterSeed:(NSData*)masterSeed
             completion:(Serialize4CompletionBlock)completion {
    //NSLog(@"SERIALIZE KEYS: [%@]", keys);
    NSData* encryptionIv = [cipher generateIv];
    
    if(kLogVerbose) {
        NSLog(@"Serialize: masterSeed = [%@]", masterSeed);
        NSLog(@"Serialize: cipher: [%@]", cipher.description);
        NSLog(@"Serialize: encryptionIv = [%@]", encryptionIv);
    }
    
    // 3. Headers
    
    NSMutableDictionary<NSNumber *,NSData *>* headers = [[NSMutableDictionary alloc] initWithDictionary:serializationData.extraUnknownHeaders];
    
    [headers setObject:masterSeed forKey:@(MASTERSEED)];
    [headers setObject:encryptionIv forKey:@(ENCRYPTIONIV)];
    [headers setObject:Uint32ToLittleEndianData(serializationData.compressionFlags) forKey:@(COMPRESSIONFLAGS)];
    uuid_t uuid;
    [serializationData.cipherUuid getUUIDBytes:uuid];
    [headers setObject:[NSData dataWithBytes:uuid length:sizeof(uuid_t)] forKey:@(CIPHERID)];
    NSDictionary<NSString*, VariantObject*> *kdfDictionary = serializationData.kdfParameters.parameters;
    NSData* kdfData = [VariantDictionary toData:kdfDictionary];
    [headers setObject:kdfData forKey:@(KDFPARAMETERS)];
    
    NSData* headerEntriesData = getHeadersData(headers);
    [headerData appendData:headerEntriesData];

    // Header Hash (SHA256)
  
    NSMutableData *ret = [[NSMutableData alloc] initWithData:headerData];
    [ret appendData:headerData.sha256];
    
    // HEADER SHA256 HMAC
    
    NSData* blockKey = getHmacKeyForBlock(keys.hmacKey, 0xFFFFFFFFFFFFFFFF); // Header HMAC Magic Block Number... Constantify?!
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, blockKey.bytes, blockKey.length, headerData.bytes, (CC_LONG)headerData.length, hmac.mutableBytes);

    [ret appendData:hmac];
    
    // 4. Main Payload
    
    // 4.1 Create Inner Headers (Inner Stream Id, and Inner Stream Key, and Attachments/Binaries)
    
    NSMutableData* inner = createInnerHeaders(serializationData.attachments, serializationData.innerRandomStreamId, serializationData.innerRandomStreamKey);
    
    // 4.2 Append XML after the inner headers
    
    [inner appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 4.3 Optional Compression
    
    NSData* encryptionPayload = serializationData.compressionFlags == kGzipCompressionFlag ? [inner gzippedData] : inner;
    
    // 4.3 HMAC Blockify
    
    NSData* encrypted = hmacBlockifyAndEncrypt(encryptionPayload, encryptionIv, keys, cipher);
    
    [ret appendData:encrypted];
    
    completion(NO, ret, nil);
}

static BOOL readFileHeader(NSInputStream* stream, KeepassFileHeader *pFileHeader) {
    NSInteger bytesRead = [stream read:(uint8_t*)pFileHeader maxLength:SIZE_OF_KEEPASS_HEADER];
    
    return (bytesRead == SIZE_OF_KEEPASS_HEADER);
}

+ (CryptoParameters*)getCryptoParams:(NSInputStream*)stream {
    [stream open];
    KeepassFileHeader fileHeader = {0};
    if (!readFileHeader(stream, &fileHeader)) {
        return nil;
    }
    
    NSDictionary<NSNumber*, NSObject*> *headerEntries = readHeaderEntries(stream, nil);
    if(!headerEntries){
        return nil;
    }
    
    return [[CryptoParameters alloc] initFromHeaders:headerEntries];
}

//

+ (void)deserialize:(NSInputStream *)stream
compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
      xmlDumpStream:(NSOutputStream*)xmlDumpStream
         completion:(Deserialize4CompletionBlock)completion {
    NSMutableData* headerDataForIntegrityCheck = [NSMutableData data];
    
    // File Header
    
    KeepassFileHeader fileHeader = {0};
    if (!readFileHeader(stream, &fileHeader)) {
        NSLog(@"Error reading KDBX 4 file header");
        NSError* error = [Utils createNSError:@"Error reading KDBX 4 file header" errorCode:-1];
        completion(NO, nil, error);
        return;
    }

    [headerDataForIntegrityCheck appendBytes:&fileHeader length:SIZE_OF_KEEPASS_HEADER];
    
    // Header Entries
    
    NSDictionary<NSNumber*, NSObject*> *headerEntries = readHeaderEntries(stream, headerDataForIntegrityCheck);
    
    if(!headerEntries){
        NSLog(@"Error getting header entries. Possibly missing header entry.");
        NSError* error = [Utils createNSError:@"Error getting header entries. Possibly missing entry." errorCode:-1];
        completion(NO, nil, error);
        return;
    }

    CryptoParameters *cryptoParams = [[CryptoParameters alloc] initFromHeaders:headerEntries];
    if (!cryptoParams) {
        NSError *error = [Utils createNSError:@"Could not get all required Crypto parameters. Cannot open." errorCode:-2];
        completion(NO, nil, error);
        return;
    }
    
    // Check Yubikey
    
    NSError* error;
    NSData* yubiKeyChallenge = [Kdbx4Serialization getYubikeyChallenge:cryptoParams.kdfParameters error:&error];
    if(error) {
        completion(NO, nil, error);
        return;
    }
    
    [Kdbx4Serialization getKeys:yubiKeyChallenge
            compositeKeyFactors:compositeKeyFactors
                  kdfParameters:cryptoParams.kdfParameters
                     masterSeed:cryptoParams.masterSeed
                     completion:^(BOOL userCancelled, Keys * _Nullable keys, NSError * _Nullable error) {
        if(userCancelled || error || keys == nil) {
            completion(userCancelled, nil, error);
        }
        else {
            [Kdbx4Serialization stage2Deserialize:stream
                                             keys:keys
                      headerDataForIntegrityCheck:headerDataForIntegrityCheck
                                    headerEntries:headerEntries
                                     cryptoParams:cryptoParams
                                    xmlDumpStream:xmlDumpStream
                                       completion:completion];
        }
    }];
}

+ (void)stage2Deserialize:(NSInputStream*)inputStream
                     keys:(Keys*)keys
headerDataForIntegrityCheck:(NSData*)headerDataForIntegrityCheck
            headerEntries:(NSDictionary<NSNumber*, NSObject*> *)headerEntries
             cryptoParams:(CryptoParameters*)cryptoParams
            xmlDumpStream:(NSOutputStream*)xmlDumpStream
               completion:(Deserialize4CompletionBlock)completion {
    if(!checkHeaderHash(headerDataForIntegrityCheck, inputStream)) {
        NSError* error = [Utils createNSError:@"Actual Header HMAC or Hash does not match expected. Header has been corrupted." errorCode:-3];
        completion(NO, nil, error);
        return;
    }

    if(!checkHeaderHmac(headerDataForIntegrityCheck, keys.hmacKey, inputStream)) {
        NSError* error = [Utils createNSError:@"Incorrect Passphrase/Key File (Composite Key)"
                                    errorCode:kStrongboxErrorCodeIncorrectCredentials];
        completion(NO, nil, error);
        return;
    }

    // Deblockify

    HmacBlockStream* hmacedBlockStream = [[HmacBlockStream alloc] initWithStream:inputStream hmacKey:keys.hmacKey];

    // Decrypt

    id<Cipher> cipher = getCipher(cryptoParams.cipherUuid);
    NSInputStream* plainTextStream = [cipher getDecryptionStreamForStream:hmacedBlockStream key:keys.masterKey iv:cryptoParams.iv];

    // Decompress

    BOOL compressed = cryptoParams.compressionFlags == 1;
    NSInputStream* decompressedStream = compressed ? [[GZipInputStream alloc] initWithStream:plainTextStream] : plainTextStream;

    [decompressedStream open];
    
    NSError* error;
    Kdbx4SerializationData* ret = readDecrypted(decompressedStream, xmlDumpStream, &error);

    [decompressedStream close];

    if(ret == nil) {
        NSLog(@"Could not read decrypted! [%@]", error);
        completion(NO, nil, error);
        return;
    }

    if(kLogVerbose) {
        NSLog(@"Got Inner Safe Serialization Data: [%@]", ret);
    }

    // Misc Extra  Serialization Info

    KeepassFileHeader keePassFileHeader = getKeePassFileHeader(headerDataForIntegrityCheck); // This is a little dirty - maintain versioning using tengrity check data :(

    ret.fileVersion = [NSString stringWithFormat:@"%hu.%hu", keePassFileHeader.major, keePassFileHeader.minor];
    ret.kdfParameters = cryptoParams.kdfParameters;
    ret.compressionFlags = cryptoParams.compressionFlags;
    ret.extraUnknownHeaders = getUnknownHeaders(headerEntries);
    ret.cipherUuid = cryptoParams.cipherUuid;

    completion(NO, ret, nil);
}

NSData* getHeadersData(NSDictionary<NSNumber*, NSData*>* headers) {
    NSMutableData* ret = [[NSMutableData alloc] init];
    
    for (NSNumber* num in headers.allKeys) {
        NSData* data = [headers objectForKey:num];
        
        HeaderEntryHeader heh;
        heh.id = num.unsignedCharValue;
        
        NSData* lengthData = Uint32ToLittleEndianData((uint32_t)data.length);
        heh.lengthBytes[0] = ((uint8_t*)lengthData.bytes)[0];
        heh.lengthBytes[1] = ((uint8_t*)lengthData.bytes)[1];
        heh.lengthBytes[2] = ((uint8_t*)lengthData.bytes)[2];
        heh.lengthBytes[3] = ((uint8_t*)lengthData.bytes)[3];
        
        [ret appendBytes:&heh length:SIZE_OF_HEADER_ENTRY_HEADER];
        [ret appendData:data];
    }
    
    HeaderEntryHeader heh;
    heh.id = END_OF_ENTRIES;
    NSData *endOfEntriesWeirdString = [kEndOfHeaderEntriesMagicString dataUsingEncoding:NSUTF8StringEncoding];

    NSData* lengthData = Uint32ToLittleEndianData((uint32_t)endOfEntriesWeirdString.length);
    heh.lengthBytes[0] = ((uint8_t*)lengthData.bytes)[0];
    heh.lengthBytes[1] = ((uint8_t*)lengthData.bytes)[1];
    heh.lengthBytes[2] = ((uint8_t*)lengthData.bytes)[2];
    heh.lengthBytes[3] = ((uint8_t*)lengthData.bytes)[3];
    
    [ret appendBytes:&heh length:SIZE_OF_HEADER_ENTRY_HEADER];
    [ret appendData:endOfEntriesWeirdString];

    return ret;
}

static NSMutableData* createInnerHeaders(NSArray<DatabaseAttachment*> *attachments, uint32_t innerStreamId, NSData *innerStreamKey) {
    NSMutableData *ret = [NSMutableData data];
    
    appendInnerHeader(ret, kInnerHeaderTypeInnerRandomStreamId, Uint32ToLittleEndianData(innerStreamId));
    
    appendInnerHeader(ret, kInnerHeaderTypeInnerRandomStreamKey, innerStreamKey);
    
    for (DatabaseAttachment *attachment in attachments) {
        uint8_t protected[] = { attachment.protectedInMemory ? 0x01 : 0x00 };
        NSMutableData *binary = [NSMutableData dataWithBytes:&protected length:1];
        
        NSInputStream* inputStream = [attachment getPlainTextInputStream];

        // FUTURE: Stream this write
        NSData* data = [NSData dataWithContentsOfStream:inputStream];

        if (!data) {
            return nil;
        }
        
        [binary appendData:data];
        
        appendInnerHeader(ret, kInnerHeaderTypeBinary, binary);
    }
    
    appendInnerHeader(ret, kInnerHeaderTypeEnd, nil);
    
    return ret;
}

static void appendInnerHeader(NSMutableData* base, uint8_t type, NSData* data) {
    uint8_t typeBytes[] = { type };
    [base appendBytes:typeBytes length:1];
    
    NSData* lengthData = Uint32ToLittleEndianData(data ? (uint32_t)data.length : 0);
    [base appendData:lengthData];

    if(data) {
        [base appendData:data];
    }
}

static Kdbx4SerializationData* readDecrypted(NSInputStream* stream, NSOutputStream* xmlDumpStream, NSError** ppError) {
    Kdbx4SerializationData* ret = readInnerHeaders(stream);
    
    if (!ret) {
        if (ppError) {
            *ppError = stream.streamError ? stream.streamError : [Utils createNSError:@"Error reading inner headers/attachments" errorCode:-3457];
        }
        NSLog(@"Error reading inner headers/attachments");
        return nil;
    }
    
    ret.rootXmlObject = parseXml(ret.innerRandomStreamId, ret.innerRandomStreamKey,
                                 XmlProcessingContext.standardV4Context, stream, xmlDumpStream, ppError);
    
    if(ret.rootXmlObject == nil) {
        NSLog(@"Error parsing xml: %@", *ppError);
        return nil;
    }
    
    return ret;
}

static Kdbx4SerializationData* readInnerHeaders(NSInputStream *stream) {
    NSMutableArray* attachments = [NSMutableArray array];
    Kdbx4SerializationData* ret = [[Kdbx4SerializationData alloc] init];
    int attachmentCount = 0;
    
    while(YES) {
        uint8_t header[SIZE_OF_INNER_HEADER_ENTRY_HEADER];
        NSInteger read = [stream read:header maxLength:SIZE_OF_INNER_HEADER_ENTRY_HEADER];
        if(read < SIZE_OF_INNER_HEADER_ENTRY_HEADER) {
            NSLog(@"Not enough data to read even initial inner header.");
            return nil;
        }
        
        InnerHeaderEntryHeader *innerHeader = (InnerHeaderEntryHeader*)header;
        if(innerHeader->type == kInnerHeaderTypeEnd) {
            break;
        }
        
        size_t headerLength = littleEndian4BytesToUInt32(innerHeader->lengthBytes);
        
        if (innerHeader->type == kInnerHeaderTypeInnerRandomStreamId) {
            NSMutableData *headerBuffer = [NSMutableData dataWithLength:headerLength];
            read = [stream read:headerBuffer.mutableBytes maxLength:headerLength];
            if (read < headerLength) {
                NSLog(@"Not enough data to read even inner header data.");
                return nil;
            }
            
            ret.innerRandomStreamId = littleEndian4BytesToUInt32((uint8_t*)headerBuffer.bytes);
        }
        else if (innerHeader->type == kInnerHeaderTypeInnerRandomStreamKey) { // Inner Random Stream Key
            NSMutableData *headerBuffer = [NSMutableData dataWithLength:headerLength];
            read = [stream read:headerBuffer.mutableBytes maxLength:headerLength];
            if (read < headerLength) {
                NSLog(@"Not enough data to read even inner header data.");
                return nil;
            }
            
            ret.innerRandomStreamKey = headerBuffer;
        }
        else if(innerHeader->type == kInnerHeaderTypeBinary) { // Binary
            uint8_t block[1];
            NSInteger bytesRead = [stream read:block maxLength:1];
            if (bytesRead != 1) {
                NSLog(@"Could not read initial attachment byte!");
                return nil;
            }
            BOOL protectedInMemory = block[0] == 1;
            
            NSLog(@"Reading Attachment %d [%ld]", attachmentCount++, headerLength - 1);
            DatabaseAttachment *attachment = [[DatabaseAttachment alloc] initWithStream:stream length:headerLength - 1 protectedInMemory:protectedInMemory];
            
            if (attachment == nil) {
                return nil;
            }
            
            [attachments addObject:attachment];
        }
        else {
            NSLog(@"Unknown inner header type! [%d]", innerHeader->type);
        }
    }
    
    ret.attachments = attachments;

    return ret;
}

static NSDictionary<NSNumber *,NSObject *>* getUnknownHeaders(NSDictionary<NSNumber *,NSObject *>* headers) {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:headers];
    
    [ret removeObjectForKey:@(MASTERSEED)];
    [ret removeObjectForKey:@(ENCRYPTIONIV)];
    [ret removeObjectForKey:@(COMPRESSIONFLAGS)];
    [ret removeObjectForKey:@(CIPHERID)];
    [ret removeObjectForKey:@(KDFPARAMETERS)];
    
    return ret;
}

static NSData* hmacBlockifyAndEncrypt(NSData *payload, NSData* iv, Keys *keys, id<Cipher> cipher) {
    NSData* encrypted = [cipher encrypt:payload iv:iv key:keys.masterKey];
    
    NSMutableData *ret = [NSMutableData data];
    size_t bytesRemaining = encrypted.length;
    int blockNumber = 0;
    while(bytesRemaining > 0) {
        size_t blockLength = (size_t)MIN(kDefaultBlockifySize, bytesRemaining);
        NSData* block = [encrypted subdataWithRange:NSMakeRange(kDefaultBlockifySize * blockNumber, blockLength)];
        
        NSData *hmac = getBlockHmac(block, keys.hmacKey, blockNumber);
        [ret appendData:hmac];
        
        NSData* lengthData = Uint32ToLittleEndianData((uint32_t)blockLength);
        [ret appendData:lengthData];
        
        [ret appendData:block];
        bytesRemaining -= blockLength;
        blockNumber++;
    }
    
    NSData* terminatorBlock = [NSData data];
    NSData *hmac = getBlockHmac(terminatorBlock, keys.hmacKey, blockNumber);
    [ret appendData:hmac];
    
    NSData* lengthData = Uint32ToLittleEndianData((uint32_t)terminatorBlock.length);
    [ret appendData:lengthData];
    
    return ret;
}

typedef void (^GetKeysCompletionBlock)(BOOL userCancelled, Keys*_Nullable keys, NSError*_Nullable error);

+ (void)getKeys:(NSData*)yubiKeyChallenge
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
  kdfParameters:(KdfParameters *)kdfParameters
     masterSeed:(NSData*)masterSeed
     completion:(GetKeysCompletionBlock)completion {
    NSError* error;
    id<KeyDerivationCipher> kdf = getKeyDerivationCipher(kdfParameters, &error);

    if(!kdf) {
        NSLog(@"Could not create KDF Cipher with KDFPARAMS: [%@]", kdfParameters);
        completion(NO, nil, error);
        return;
    }

    [Kdbx4Serialization getCompositeKey:yubiKeyChallenge
                    compositeKeyFactors:compositeKeyFactors
                             completion:^(BOOL userCancelled, NSData * _Nullable compositeKey, NSError * _Nullable error) {
        if (userCancelled || error) {
            completion(userCancelled, nil, error);
        }
        else {
            Keys *ret = [[Keys alloc] init];

            ret.compositeKey = compositeKey;
            ret.transformKey = [kdf deriveKey:ret.compositeKey];
            ret.masterKey = getMasterKey(masterSeed, ret.transformKey);

            // FUTURE: Need to handle different size master keys for different ciphers...
            // Code in KdbxFile.cs ComputeKeys provides example.
            
            ret.hmacKey = getHmacKey(masterSeed, ret.transformKey);

            completion(NO, ret, nil);
        }
    }];
}

static BOOL checkHeaderHash(NSData* headerData, NSInputStream* stream) {
    uint8_t actualHash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(headerData.bytes, (CC_LONG)headerData.length, actualHash);

    if(kLogVerbose) {
        NSLog(@"HEADERHASH (ACTUAL): %@", [[NSData dataWithBytes:actualHash length:CC_SHA256_DIGEST_LENGTH] base64EncodedStringWithOptions:kNilOptions]);
    }
    
    uint8_t expectedHash[CC_SHA256_DIGEST_LENGTH];
    NSInteger read = [stream read:expectedHash maxLength:CC_SHA256_DIGEST_LENGTH];
    if (read != CC_SHA256_DIGEST_LENGTH) {
        NSLog(@"Could not read expected Header Hash KDBX4");
        return NO;
    }
    
    if(memcmp(actualHash, expectedHash, CC_SHA256_DIGEST_LENGTH) != 0) {
        NSLog(@"Actual Header Hash does not match expected. Header has been corrupted.");
        return NO;
    }

    return YES;
}

static BOOL checkHeaderHmac(NSData* headerData, NSData* hmacKey, NSInputStream* stream) {
    NSData *actualHash = getHeaderHmac(headerData, hmacKey);
    
    if(kLogVerbose) {
        NSLog(@"HEADER HMAC (ACTUAL): %@", [actualHash base64EncodedStringWithOptions:kNilOptions]);
    }
    
    uint8_t expectedHash[CC_SHA256_DIGEST_LENGTH];
    NSInteger read = [stream read:expectedHash maxLength:CC_SHA256_DIGEST_LENGTH];
    if (read != CC_SHA256_DIGEST_LENGTH) {
        NSLog(@"Could not read expected Header Hash KDBX4");
        return NO;
    }
    
    if(memcmp(actualHash.bytes, expectedHash, CC_SHA256_DIGEST_LENGTH) != 0) {
        NSLog(@"Actual Header HMAC does not match expected. Header has been corrupted or passphrase incorrect.");
        return NO;
    }

    return YES;
}

static id<KeyDerivationCipher> getKeyDerivationCipher(KdfParameters *kdfParameters, NSError** error) {
    if([kdfParameters.uuid isEqual:argon2CipherUuid()]) {
        id<KeyDerivationCipher> ret = [[Argon2KdfCipher alloc] initWithParametersDictionary:kdfParameters];
        if(ret == nil) {
            if(error) {
                *error = [Utils createNSError:@"Could not initialize Argon2 with Parameters" errorCode:-1];
            }
        }
        
        return ret;
    }
    else if([kdfParameters.uuid isEqual:aesKdbx3KdfCipherUuid()] || [kdfParameters.uuid isEqual:aesKdbx4KdfCipherUuid()]) {
        id<KeyDerivationCipher> ret = [[AesKdfCipher alloc] initWithParametersDictionary:kdfParameters];

        if(ret == nil) {
            if(error) {
                *error = [Utils createNSError:@"Could not initialize AES KDF with Parameters" errorCode:-1];
            }
        }
        
        return ret;
    }
    else {
        if(error) {
            *error = [Utils createNSError:[NSString stringWithFormat:@"Unknown Key Derivation Cipher: [%@]", kdfParameters.uuid.UUIDString] errorCode:-1];
        }
        return nil;
    }
}

static NSData* getHmacKey(NSData* masterSeed, NSData* transformKey) {
    NSMutableData* foo = [masterSeed mutableCopy];
    [foo appendData:transformKey];
    
    uint8_t bar = {0x01};
    [foo appendBytes:&bar length:1];
    
    NSMutableData *headerHmacKey = [NSMutableData dataWithLength:CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(foo.bytes, (CC_LONG)foo.length, headerHmacKey.mutableBytes);

    return headerHmacKey;
}

static NSData* getHeaderHmac(NSData *header, NSData* hmacKey) {
    NSData* blockKey = getHmacKeyForBlock(hmacKey, 0xFFFFFFFFFFFFFFFF);
   
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, blockKey.bytes, blockKey.length, header.bytes, (CC_LONG)header.length, hmac.mutableBytes);

    return hmac;
}

static NSDictionary<NSNumber *,NSObject *>* readHeaderEntries(NSInputStream* stream, NSMutableData* headerDataForIntegrityCheck) {
    NSMutableDictionary<NSNumber *,NSObject *> *headerEntries = [NSMutableDictionary dictionary];
    
    do {
        HeaderEntryHeader headerEntry;
        NSInteger bytesRead = [stream read:(uint8_t*)&headerEntry maxLength:SIZE_OF_HEADER_ENTRY_HEADER];
        if (bytesRead > 0 && headerDataForIntegrityCheck) {
            [headerDataForIntegrityCheck appendBytes:&headerEntry length:bytesRead];
        }
        
        if(bytesRead < SIZE_OF_HEADER_ENTRY_HEADER) {
            break;
        }
                
        int32_t length = littleEndian4BytesToInt32(headerEntry.lengthBytes);
        if(kLogVerbose) {
            NSLog(@"Found Header Entry of Type %d and length %d", headerEntry.id, length);
        }
        
        NSMutableData* headerData = [NSMutableData dataWithLength:length];
        bytesRead = [stream read:headerData.mutableBytes maxLength:length];
        if (bytesRead > 0 && headerDataForIntegrityCheck) {
            [headerDataForIntegrityCheck appendBytes:headerData.bytes length:bytesRead];
        }
        
        if (bytesRead < length) {
            NSLog(@"This safe appears to be corrupt. Header entry found with length of [%d]", length);
            return nil;
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
   
    if(kLogVerbose) {
        dumpHeaderEntries(headerEntries);
    }
    
    if(![Kdbx4Serialization verifyRequiredHeadersPresent:headerEntries]) {
        return nil;
    }

    return headerEntries;
}

+(BOOL)verifyRequiredHeadersPresent:(NSMutableDictionary<NSNumber *,NSObject *> *)headerEntries {
    if(![headerEntries objectForKey:@(KDFPARAMETERS)]) {
        NSLog(@"Missing required KDFPARAMETERS header entry.");
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
    
    return YES;
}

typedef void (^GetCompositeKeyCompletionBlock)(BOOL userCancelled, NSData*_Nullable compositeKey, NSError*_Nullable error);

+ (void)getCompositeKey:(NSData*)yubiKeyChallenge
    compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
             completion:(GetCompositeKeyCompletionBlock)completion {
    NSData *hashedPassword = compositeKeyFactors.password != nil ? compositeKeyFactors.password.sha256 : nil;
    
    if(compositeKeyFactors.yubiKeyCR) {
        compositeKeyFactors.yubiKeyCR(yubiKeyChallenge, ^(BOOL userCancelled, NSData * _Nullable response, NSError * _Nullable error) {
            if(userCancelled || error) {
                completion(userCancelled, nil, error);
            }
            else {
                if (response == nil) {
                    error = [Utils createNSError:@"Nil response received from YubiKey" errorCode:-1];
                    completion(NO, nil, error);
                    return;
                }

                NSMutableArray* factors = @[].mutableCopy;

                if (hashedPassword) [factors addObject:hashedPassword];
                if (compositeKeyFactors.keyFileDigest) [factors addObject:compositeKeyFactors.keyFileDigest];
                
                [factors addObject:response.sha256];

                [Kdbx4Serialization completeWithCKFs:factors completion:completion];
            }
        });
    }
    else {
        NSMutableArray* factors = @[].mutableCopy;

        if (hashedPassword) [factors addObject:hashedPassword];
        if (compositeKeyFactors.keyFileDigest) [factors addObject:compositeKeyFactors.keyFileDigest];
           
        [Kdbx4Serialization completeWithCKFs:factors completion:completion];
    }
}

+ (void)completeWithCKFs:(NSArray<NSData*>*)factors completion:(GetCompositeKeyCompletionBlock)completion {
    NSMutableData *compositeKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    
    for (NSData* factor in factors) {
        CC_SHA256_Update(&context, factor.bytes, (CC_LONG)factor.length);
    }

    CC_SHA256_Final(compositeKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        NSLog(@"COMPOSITE KEY: %@", [compositeKey base64EncodedStringWithOptions:kNilOptions]);
    }

    completion(NO, compositeKey, nil);
}

@end
