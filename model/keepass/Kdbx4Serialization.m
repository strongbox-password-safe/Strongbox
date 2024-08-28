//
//  Kdbx4Serialization.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Kdbx4Serialization.h"
#import "Utils.h"
#import "KdbxSerializationCommon.h"
#import "KdfParameters.h"
#import "KeePassCiphers.h"
#import "ChaCha20Cipher.h"
#import "NSData+GZIP.h"
#import <CommonCrypto/CommonCrypto.h>
#import "CryptoParameters.h"
#import "Kdbx4SerializationData.h"
#import "KeePassConstants.h"
#import "KeePassAttachmentAbstractionLayer.h"
#import "PwSafeSerialization.h"
#import "VariantDictionary.h"
#import "Keys.h"
#import "AesKdfCipher.h"
#import "GZipInputStream.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "HmacBlockInputStream.h"
#import "Argon2dKdfCipher.h"
#import "Argon2idKdfCipher.h"
#import "StrongboxErrorCodes.h"
#import "StreamUtils.h"
#import "HmacBlockOutputStream.h"
#import "GzipDecompressOutputStream.h"
#import "GZIPCompressOutputStream.h"
#import "XmlSerializer.h"

static const uint8_t kInnerHeaderTypeEnd = 0;
static const uint8_t kInnerHeaderTypeInnerRandomStreamId = 1;
static const uint8_t kInnerHeaderTypeInnerRandomStreamKey = 2;
static const uint8_t kInnerHeaderTypeBinary = 3;

typedef void (^GetKeysCompletionBlock)(BOOL userCancelled, Keys*_Nullable keys, NSError*_Nullable error);
typedef void (^GetCompositeKeyCompletionBlock)(BOOL userCancelled, NSData*_Nullable compositeKey, NSError*_Nullable error);

static const BOOL kLogVerbose = NO;

@implementation Kdbx4Serialization

+ (NSData *)getYubiKeyChallenge:(KdfParameters *)kdfParameters error:(NSError * _Nullable __autoreleasing *)error {
    id<KeyDerivationCipher> kdf = getKeyDerivationCipher(kdfParameters, error);
    
    if(!kdf) {
        slog(@"Could not create KDF Cipher with KDFPARAMS: [%@]", kdfParameters);
        return nil;
    }
    
    
    
    return kdf.transformSeed;
}

+ (void)serialize:(Kdbx4SerializationData *)serializationData
  rootXmlDocument:(RootXmlDomainObject *)rootXmlDocument
      innerStream:(id<InnerRandomStream>)innerStream
              ckf:(CompositeKeyFactors *)ckf
     outputStream:(NSOutputStream *)outputStream
       completion:(Serialize4CompletionBlock)completion {
    if(kLogVerbose) {
        slog(@"Serializing with [%@] and password [%@]", serializationData, ckf);
    }
    
    
    
    KeepassFileHeader header = getNewFileHeader(serializationData.fileVersion);
    
    NSMutableData* headerData = [NSMutableData data];
    [headerData appendBytes:&header length:SIZE_OF_KEEPASS_HEADER];
    
    
    
    NSData* masterSeed = getRandomData(kMasterSeedLength);
    id<Cipher> cipher = getCipher(serializationData.cipherUuid);
    
    if(!cipher) {
        slog(@"Could not get Cipher %@", serializationData.cipherUuid.UUIDString);
        NSError* error = [Utils createNSError:@"Could not get appropriate Cipher." errorCode:-1];
        completion(NO, error);
        return;
    }
    
    NSError* error;
    NSData* yubiKeyChallenge = [Kdbx4Serialization getYubiKeyChallenge:serializationData.kdfParameters error:&error];
    if(error) {
        completion(NO, error);
        return;
    }
    
    [Kdbx4Serialization getKeys:yubiKeyChallenge
            compositeKeyFactors:ckf
                  kdfParameters:serializationData.kdfParameters
                     masterSeed:masterSeed
                     completion:^(BOOL userCancelled, Keys * _Nullable keys, NSError * _Nullable error) {
        if(userCancelled || error || keys == nil) {
            if(!keys && !userCancelled) {
                slog(@"Could not get Keys. Error = [%@]", error);
                if ( !error ) {
                    error = [Utils createNSError:@"Could not determine appropriate keys." errorCode:-1];
                }
            }
            completion(userCancelled, error);
        }
        else {
            [Kdbx4Serialization stage2Serialize:keys
                                rootXmlDocument:rootXmlDocument
                                    innerStream:innerStream
                                     headerData:headerData
                              serializationData:serializationData
                                         cipher:cipher
                                     masterSeed:masterSeed
                                   outputStream:outputStream
                                     completion:completion];
        }
    }];
}

+ (void)stage2Serialize:(Keys*)keys
        rootXmlDocument:(RootXmlDomainObject *)rootXmlDocument
            innerStream:(id<InnerRandomStream>)innerStream
             headerData:(NSMutableData*)headerData
      serializationData:(Kdbx4SerializationData *)serializationData
                 cipher:(id<Cipher>)cipher
             masterSeed:(NSData*)masterSeed
           outputStream:(NSOutputStream *)outputStream
             completion:(Serialize4CompletionBlock)completion {
    
    
    NSData* encryptionIv = [cipher generateIv];
    
    if(kLogVerbose) {
        slog(@"Serialize: masterSeed = [%@]", masterSeed);
        slog(@"Serialize: cipher: [%@]", cipher.description);
        slog(@"Serialize: encryptionIv = [%@]", encryptionIv);
    }
    
    
    
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
    
    
    
    NSInteger wrote = [outputStream write:headerData.bytes maxLength:headerData.length];
    if ( wrote <= 0 ) {
        slog(@"Could not serialize headers. KDBX4");
        completion(NO, [Utils createNSError:@"Could not serialize headers. KDBX4." errorCode:-1]);
        return;
    }
    
    
    
    wrote = [outputStream write:headerData.sha256.bytes maxLength:headerData.sha256.length];
    if ( wrote <= 0 ) {
        slog(@"Could not serialize Headers Hash (SHA256). KDBX4");
        completion(NO, [Utils createNSError:@"Could not serialize Headers Hash (SHA256). KDBX4." errorCode:-1]);
        return;
    }
    
    
    
    NSData* blockKey = getHmacKeyForBlock(keys.hmacKey, 0xFFFFFFFFFFFFFFFF); 
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, blockKey.bytes, blockKey.length, headerData.bytes, (CC_LONG)headerData.length, hmac.mutableBytes);
    
    wrote = [outputStream write:hmac.bytes maxLength:hmac.length];
    if ( wrote <= 0 ) {
        slog(@"Could not serialize HEADER HMAC. KDBX4");
        completion(NO, [Utils createNSError:@"Could not serialize HEADER HMAC. KDBX4." errorCode:-1]);
        return;
    }
    
    
    
    
    HmacBlockOutputStream* hmacBlockifyStream = [[HmacBlockOutputStream alloc] initWithStream:outputStream hmacKey:keys.hmacKey];
    NSOutputStream* encryptStream = [cipher getEncryptionOutputStreamForStream:hmacBlockifyStream key:keys.masterKey iv:encryptionIv];
    NSOutputStream* compression = serializationData.compressionFlags == kGzipCompressionFlag ? [[GZIPCompressOutputStream alloc] initToOutputStream:encryptStream] : encryptStream;
    
    [hmacBlockifyStream open];
    [encryptStream open];
    [compression open];
    
    
    
    NSOutputStream* thePipeline = compression;
    wrote = createInnerHeaders(serializationData.attachments, serializationData.innerRandomStreamId, serializationData.innerRandomStreamKey, thePipeline);
    if ( wrote < 0 ) {
        slog(@"Could not serialize inner headers (probably could not serialize attachments). KDBX4. = [%@]", thePipeline.streamError );
        completion(NO, thePipeline.streamError );
        return;
    }
    
    
    
    id<IXmlSerializer> xmlSerializer = [[XmlSerializer alloc] initWithProtectedStream:innerStream v4Format:YES prettyPrint:NO outputStream:thePipeline];
    
    [xmlSerializer beginDocument];
    BOOL writeXmlOk = [rootXmlDocument writeXml:xmlSerializer];
    [xmlSerializer endDocument];
    
    if( !writeXmlOk ) {
        slog(@"Could not serialize Xml to Document.:\n");
        NSError* errXmlSerialize = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        completion(NO, thePipeline.streamError ? thePipeline.streamError : errXmlSerialize);
        return;
    }
    
    if( xmlSerializer.streamError != nil ) {
        slog(@"Could not serialize Xml to Document.: [%@]", xmlSerializer.streamError );
        completion(NO, xmlSerializer.streamError);
        return;
    }
    
    [compression close];
    [encryptStream close];
    [hmacBlockifyStream close];
    
    if ( thePipeline.streamError ) {
        slog(@"Error closing streams [%@]", thePipeline.streamError );
    }
    
    completion(NO, thePipeline.streamError);
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

+ (NSData*)getYubiKeyChallenge:(NSInputStream *)stream {
    CryptoParameters *cryptoParams = [Kdbx4Serialization getCryptoParams:stream];
    if (!cryptoParams) {
        return nil;
    }
    
    NSError* error;
    NSData* yubiKeyChallenge = [Kdbx4Serialization getYubiKeyChallenge:cryptoParams.kdfParameters error:&error];
    
    return error == nil ? yubiKeyChallenge : nil;
}

+ (void)deserialize:(NSInputStream *)stream
compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
      xmlDumpStream:(NSOutputStream*)xmlDumpStream
sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
         completion:(Deserialize4CompletionBlock)completion {
    NSMutableData* headerDataForIntegrityCheck = [NSMutableData data];
    
    
    
    KeepassFileHeader fileHeader = {0};
    if (!readFileHeader(stream, &fileHeader)) {
        slog(@"Error reading KDBX 4 file header");
        NSError* error = [Utils createNSError:@"Error reading KDBX 4 file header" errorCode:-1];
        completion(NO, nil, nil, error);
        return;
    }

    [headerDataForIntegrityCheck appendBytes:&fileHeader length:SIZE_OF_KEEPASS_HEADER];
    
    
    
    NSDictionary<NSNumber*, NSObject*> *headerEntries = readHeaderEntries(stream, headerDataForIntegrityCheck);
    
    if(!headerEntries){
        slog(@"Error getting header entries. Possibly missing header entry.");
        NSError* error = [Utils createNSError:@"Error getting header entries. Possibly missing entry." errorCode:-1];
        completion(NO, nil, nil, error);
        return;
    }

    CryptoParameters *cryptoParams = [[CryptoParameters alloc] initFromHeaders:headerEntries];
    if (!cryptoParams) {
        NSError *error = [Utils createNSError:@"Could not get all required Crypto parameters. Cannot open." errorCode:-2];
        completion(NO, nil, nil, error);
        return;
    }
    
    
    
    NSError* error;
    NSData* yubiKeyChallenge = [Kdbx4Serialization getYubiKeyChallenge:cryptoParams.kdfParameters error:&error];
    if(error) {
        completion(NO, nil, nil, error);
        return;
    }
    
    [Kdbx4Serialization getKeys:yubiKeyChallenge
            compositeKeyFactors:compositeKeyFactors
                  kdfParameters:cryptoParams.kdfParameters
                     masterSeed:cryptoParams.masterSeed
                     completion:^(BOOL userCancelled, Keys * _Nullable keys, NSError * _Nullable error) {
        if(userCancelled || error || keys == nil) {
            completion(userCancelled, nil, nil, error);
        }
        else {
            [Kdbx4Serialization stage2Deserialize:stream
                                             keys:keys
                      headerDataForIntegrityCheck:headerDataForIntegrityCheck
                                    headerEntries:headerEntries
                                     cryptoParams:cryptoParams
                                    xmlDumpStream:xmlDumpStream
                           sanityCheckInnerStream:sanityCheckInnerStream
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
   sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
               completion:(Deserialize4CompletionBlock)completion {
    if(!checkHeaderHash(headerDataForIntegrityCheck, inputStream)) {
        NSError* error = [Utils createNSError:@"Actual Header HMAC or Hash does not match expected. Header has been corrupted." errorCode:-3];
        completion(NO, nil, nil, error);
        return;
    }

    if(!checkHeaderHmac(headerDataForIntegrityCheck, keys.hmacKey, inputStream)) {
        NSError* error = [Utils createNSError:@"Incorrect Passphrase/Key File (Composite Key)"
                                    errorCode:StrongboxErrorCodes.incorrectCredentials];
        completion(NO, nil, nil, error);
        return;
    }

    

    HmacBlockInputStream* hmacedBlockStream = [[HmacBlockInputStream alloc] initWithStream:inputStream hmacKey:keys.hmacKey];

    

    id<Cipher> cipher = getCipher(cryptoParams.cipherUuid);
    NSInputStream* plainTextStream = [cipher getDecryptionStreamForStream:hmacedBlockStream key:keys.masterKey iv:cryptoParams.iv];

    

    BOOL compressed = cryptoParams.compressionFlags == 1;
    NSInputStream* decompressedStream = compressed ? [[GZipInputStream alloc] initWithStream:plainTextStream] : plainTextStream;

    [decompressedStream open];
    
    NSError* error;
    NSError* innerStreamError;

    Kdbx4SerializationData* ret = readDecrypted(decompressedStream, xmlDumpStream, sanityCheckInnerStream, &innerStreamError, &error);

    [decompressedStream close];

    if(ret == nil) {
        slog(@"Could not read decrypted! [%@]", error);
        completion(NO, nil, innerStreamError, error);
        return;
    }

    if(kLogVerbose) {
        slog(@"Got Inner Safe Serialization Data: [%@]", ret);
    }

    

    KeepassFileHeader keePassFileHeader = getKeePassFileHeader(headerDataForIntegrityCheck); 

    ret.fileVersion = [NSString stringWithFormat:@"%hu.%hu", keePassFileHeader.major, keePassFileHeader.minor];
    ret.kdfParameters = cryptoParams.kdfParameters;
    ret.compressionFlags = cryptoParams.compressionFlags;
    ret.extraUnknownHeaders = getUnknownHeaders(headerEntries);
    ret.cipherUuid = cryptoParams.cipherUuid;

    completion(NO, ret, innerStreamError, nil);
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

static NSInteger createInnerHeaders(NSArray<KeePassAttachmentAbstractionLayer*> *attachments, uint32_t innerStreamId, NSData *innerStreamKey, NSOutputStream *outputStream) {
    NSInteger wrote = appendInnerHeader(kInnerHeaderTypeInnerRandomStreamId, Uint32ToLittleEndianData(innerStreamId), outputStream);
    if ( wrote < 0 ) {
        return wrote;
    }
    
    wrote = appendInnerHeader(kInnerHeaderTypeInnerRandomStreamKey, innerStreamKey, outputStream);
    if ( wrote < 0 ) {
        return wrote;
    }
    
    for (KeePassAttachmentAbstractionLayer *attachment in attachments) {
        wrote = appendInnerBinaryHeaderFromStream( attachment, outputStream );
        if ( wrote < 0 ) {
            slog(@"Could not get attachment screen, cannot serialize.");
            return wrote;
        }
    }
    
    appendInnerHeader(kInnerHeaderTypeEnd, nil, outputStream);
    if ( wrote < 0 ) {
        return wrote;
    }
    
    return YES;
}

static NSInteger appendInnerBinaryHeaderFromStream(KeePassAttachmentAbstractionLayer *attachment, NSOutputStream *outputStream) {
    uint8_t typeBytes[] = { kInnerHeaderTypeBinary };
    NSInteger wrote = [outputStream write:typeBytes maxLength:1];
    if ( wrote < 0 ) {
        return wrote;
    }
    
    NSData* lengthData = Uint32ToLittleEndianData((uint32_t)attachment.length + 1); 
    wrote = [outputStream write:lengthData.bytes maxLength:lengthData.length];
    if ( wrote < 0 ) {
        return wrote;
    }
    
    uint8_t protected[] = { attachment.protectedInMemory ? 0x01 : 0x00 };
    wrote = [outputStream write:protected maxLength:1];
    if ( wrote < 0 ) {
        return wrote;
    }
    
    
    
    NSInputStream* inputStream = [attachment getPlainTextInputStream];
    if ( !inputStream ) {
        slog(@"Could not get attachment screen, cannot serialize.");
        return NO;
    }

    [inputStream open];
    
    NSInteger read;
    const NSUInteger kChunkLength = 32 * 1024;
    uint8_t chunk[kChunkLength];
        
    while ( (read = [inputStream read:chunk maxLength:kChunkLength]) > 0 ) {
        wrote = [outputStream write:chunk maxLength:read];
        if ( wrote < 0 ) {
            return wrote;
        }
    }
    
    [inputStream close];
    
    return YES;
}

static NSInteger appendInnerHeader(uint8_t type, NSData* data, NSOutputStream *outputStream) {
    uint8_t typeBytes[] = { type };
    NSInteger wrote = [outputStream write:typeBytes maxLength:1];
    if ( wrote < 0 ) {
        return wrote;
    }

    NSData* lengthData = Uint32ToLittleEndianData(data ? (uint32_t)data.length : 0);
    wrote = [outputStream write:lengthData.bytes maxLength:lengthData.length];
    if ( wrote < 0 ) {
        return wrote;
    }

    if(data) {
        wrote = [outputStream write:data.bytes maxLength:data.length];
        if ( wrote < 0 ) {
            return wrote;
        }
    }
    
    return wrote;
}

static Kdbx4SerializationData* readDecrypted(NSInputStream* stream, NSOutputStream* xmlDumpStream, BOOL sanityCheckInnerStream, NSError** innerStreamError, NSError** ppError) {
    Kdbx4SerializationData* ret = readInnerHeaders(stream);
    
    if (!ret) {
        if (ppError) {
            *ppError = stream.streamError ? stream.streamError : [Utils createNSError:@"Error reading inner headers/attachments" errorCode:-3457];
        }
        slog(@"Error reading inner headers/attachments");
        return nil;
    }
    
    ret.rootXmlObject = parseXml(ret.innerRandomStreamId, ret.innerRandomStreamKey,
                                 XmlProcessingContext.standardV4Context, stream, xmlDumpStream, sanityCheckInnerStream, innerStreamError, ppError);

    if(ret.rootXmlObject == nil) {
        slog(@"Error parsing xml: %@", *ppError);
        return nil;
    }
    
    return ret;
}

static Kdbx4SerializationData* readInnerHeaders(NSInputStream *stream) {
    NSMutableArray* attachments = [NSMutableArray array];
    Kdbx4SerializationData* ret = [[Kdbx4SerializationData alloc] init];
    
    while(YES) {
        uint8_t header[SIZE_OF_INNER_HEADER_ENTRY_HEADER];
        NSInteger read = [stream read:header maxLength:SIZE_OF_INNER_HEADER_ENTRY_HEADER];
        if(read < SIZE_OF_INNER_HEADER_ENTRY_HEADER) {
            slog(@"Not enough data to read even initial inner header.");
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
                slog(@"Not enough data to read even inner header data.");
                return nil;
            }
            
            ret.innerRandomStreamId = littleEndian4BytesToUInt32((uint8_t*)headerBuffer.bytes);
        }
        else if (innerHeader->type == kInnerHeaderTypeInnerRandomStreamKey) { 
            NSMutableData *headerBuffer = [NSMutableData dataWithLength:headerLength];
            read = [stream read:headerBuffer.mutableBytes maxLength:headerLength];
            if (read < headerLength) {
                slog(@"Not enough data to read even inner header data.");
                return nil;
            }
            
            ret.innerRandomStreamKey = headerBuffer;
        }
        else if(innerHeader->type == kInnerHeaderTypeBinary) { 
            uint8_t block[1];
            NSInteger bytesRead = [stream read:block maxLength:1];
            if (bytesRead != 1) {
                slog(@"Could not read initial attachment byte!");
                return nil;
            }
            BOOL protectedInMemory = block[0] == 1;
            

            KeePassAttachmentAbstractionLayer *attachment = [[KeePassAttachmentAbstractionLayer alloc] initWithStream:stream length:headerLength - 1 protectedInMemory:protectedInMemory];
            
            if (attachment == nil) {
                return nil;
            }
            
            [attachments addObject:attachment];
        }
        else {
            slog(@"Unknown inner header type! [%d]", innerHeader->type);
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

+ (void)getKeys:(NSData*)yubiKeyChallenge
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
  kdfParameters:(KdfParameters *)kdfParameters
     masterSeed:(NSData*)masterSeed
     completion:(GetKeysCompletionBlock)completion {
    NSError* error;
    id<KeyDerivationCipher> kdf = getKeyDerivationCipher(kdfParameters, &error);

    if(!kdf) {
        slog(@"Could not create KDF Cipher with KDFPARAMS: [%@]", kdfParameters);
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

            
            
            
            ret.hmacKey = getHmacKey(masterSeed, ret.transformKey);

            completion(NO, ret, nil);
        }
    }];
}

static BOOL checkHeaderHash(NSData* headerData, NSInputStream* stream) {
    uint8_t actualHash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(headerData.bytes, (CC_LONG)headerData.length, actualHash);

    if(kLogVerbose) {
        slog(@"HEADERHASH (ACTUAL): %@", [[NSData dataWithBytes:actualHash length:CC_SHA256_DIGEST_LENGTH] base64EncodedStringWithOptions:kNilOptions]);
    }
    
    uint8_t expectedHash[CC_SHA256_DIGEST_LENGTH];
    
    
    
    NSInteger read = [stream read:expectedHash maxLength:CC_SHA256_DIGEST_LENGTH];
    if (read != CC_SHA256_DIGEST_LENGTH) {
        slog(@"Could not read expected Header Hash KDBX4");
        return NO;
    }
    
    if(memcmp(actualHash, expectedHash, CC_SHA256_DIGEST_LENGTH) != 0) {
        slog(@"Actual Header Hash does not match expected. Header has been corrupted.");
        return NO;
    }

    return YES;
}

static BOOL checkHeaderHmac(NSData* headerData, NSData* hmacKey, NSInputStream* stream) {
    NSData *actualHash = getHeaderHmac(headerData, hmacKey);
    
    if(kLogVerbose) {
        slog(@"HEADER HMAC (ACTUAL): %@", [actualHash base64EncodedStringWithOptions:kNilOptions]);
    }
    
    uint8_t expectedHash[CC_SHA256_DIGEST_LENGTH];
    NSInteger read = [stream read:expectedHash maxLength:CC_SHA256_DIGEST_LENGTH];
    if (read != CC_SHA256_DIGEST_LENGTH) {
        slog(@"Could not read expected Header Hash KDBX4");
        return NO;
    }
    
    if(memcmp(actualHash.bytes, expectedHash, CC_SHA256_DIGEST_LENGTH) != 0) {
        slog(@"Actual Header HMAC does not match expected. Header has been corrupted or passphrase incorrect.");
        return NO;
    }

    return YES;
}

id<KeyDerivationCipher> getKeyDerivationCipher(KdfParameters *kdfParameters, NSError** error) {
    if([kdfParameters.uuid isEqual:argon2dCipherUuid()]) {
        id<KeyDerivationCipher> ret = [[Argon2dKdfCipher alloc] initWithParametersDictionary:kdfParameters];
        if(ret == nil) {
            if(error) {
                *error = [Utils createNSError:@"Could not initialize Argon2 with Parameters" errorCode:-1];
            }
        }
        
        return ret;
    }
    else if([kdfParameters.uuid isEqual:argon2idCipherUuid()]) {
        id<KeyDerivationCipher> ret = [[Argon2idKdfCipher alloc] initWithParametersDictionary:kdfParameters];
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
    
    NSUInteger total = 0;
    
    do {
        HeaderEntryHeader headerEntry;
        NSInteger bytesRead = [stream read:(uint8_t*)&headerEntry maxLength:SIZE_OF_HEADER_ENTRY_HEADER];
        if (bytesRead > 0 && headerDataForIntegrityCheck) {
            [headerDataForIntegrityCheck appendBytes:&headerEntry length:bytesRead];
        }
        
        if(bytesRead < SIZE_OF_HEADER_ENTRY_HEADER) {
            break;
        }
        
        total += bytesRead;
        
        uint32_t length = littleEndian4BytesToUInt32(headerEntry.lengthBytes);
        if(kLogVerbose) {
            slog(@"Found Header Entry of Type %d and length %d", headerEntry.id, length);
        }

        if (length > 0) { 
            NSMutableData* headerData = [NSMutableData dataWithLength:length];

            bytesRead = [stream read:headerData.mutableBytes maxLength:length];
            if (bytesRead > 0 && headerDataForIntegrityCheck) {
                [headerDataForIntegrityCheck appendBytes:headerData.bytes length:bytesRead];
            }
            
            if (bytesRead < length) {
                slog(@"This safe appears to be corrupt. Header entry found with length of [%d]", length);
                return nil;
            }
         
            total += bytesRead;

            if(END_OF_ENTRIES == headerEntry.id) { 
                break;
            }
            
            NSObject* obj = getHeaderEntryObject(headerEntry.id, headerData);
            if(obj) {
                [headerEntries setObject:obj forKey:@(headerEntry.id)];
            }
        }
        
        if(END_OF_ENTRIES == headerEntry.id) {
            break;
        }
    } while (YES);
   
    if(kLogVerbose) {
        slog(@"Bytes Read of Headers: %lu", (unsigned long)total);
        dumpHeaderEntries(headerEntries);
    }
    
    if(![Kdbx4Serialization verifyRequiredHeadersPresent:headerEntries]) {
        return nil;
    }

    return headerEntries;
}

+ (BOOL)verifyRequiredHeadersPresent:(NSMutableDictionary<NSNumber *,NSObject *> *)headerEntries {
    if(![headerEntries objectForKey:@(KDFPARAMETERS)]) {
        slog(@"Missing required KDFPARAMETERS header entry.");
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
    
    return YES;
}

+ (void)getCompositeKey:(NSData*)yubiKeyChallenge
    compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
             completion:(GetCompositeKeyCompletionBlock)completion {
    NSData *hashedPassword = compositeKeyFactors.password != nil ? compositeKeyFactors.password.sha256Data : nil;
    
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
        slog(@"COMPOSITE KEY: %@", [compositeKey base64EncodedStringWithOptions:kNilOptions]);
    }

    completion(NO, compositeKey, nil);
}

@end
