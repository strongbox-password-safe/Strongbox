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
#import "Utils.h"
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

typedef struct _HeaderEntryHeader {
    uint8_t id;
    uint8_t lengthBytes[4];
} HeaderEntryHeader;
#define SIZE_OF_HEADER_ENTRY_HEADER      5

typedef struct _HmacBlockHeader {
    uint8_t hmacSha256[32];
    uint8_t lengthBytes[4];
    uint8_t data[];
} HmacBlockHeader;
#define SIZE_OF_HMAC_BLOCK_HEADER 36

typedef struct _InnerHeaderEntryHeader {
    uint8_t type;
    uint8_t lengthBytes[4];
    uint8_t data[];
} InnerHeaderEntryHeader;
#define SIZE_OF_INNER_HEADER_ENTRY_HEADER      5

static const uint8_t kInnerHeaderTypeEnd = 0;
static const uint8_t kInnerHeaderTypeInnerRandomStreamId = 1;
static const uint8_t kInnerHeaderTypeInnerRandomStreamKey = 2;
static const uint8_t kInnerHeaderTypeBinary = 3;

static const BOOL kLogVerbose = NO;

@implementation Kdbx4Serialization

+ (NSData *)serialize:(Kdbx4SerializationData *)serializationData
             password:(NSString *)password
        keyFileDigest:(NSData*)keyFileDigest
              ppError:(NSError **)ppError {
    if(kLogVerbose) {
        NSLog(@"Serializing with [%@] and password [%@]", serializationData, password);
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
        if(ppError) {
            *ppError = [Utils createNSError:@"Could not get appropriate Cipher." errorCode:-1];
        }
        return nil;
    }
    
    Keys *keys = getKeys(password, keyFileDigest, serializationData.kdfParameters, masterSeed, ppError);
    
    //NSLog(@"SERIALIZE KEYS: [%@]", keys);
    
    if(!keys) {
        NSLog(@"Could not get Keys.");
        if(ppError) {
            *ppError = [Utils createNSError:@"Could not determine appropriate keys." errorCode:-1];
        }
        return nil;
    }

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
    [ret appendData:sha256(headerData)];
    
    // HEADER SHA256 HMAC
    
    NSData* blockKey = getHmacKeyForBlock(keys.hmacKey, 0xFFFFFFFFFFFFFFFF); // Header HMAC Magic Block Number... Constantify?!
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, blockKey.bytes, blockKey.length, headerData.bytes, (CC_LONG)headerData.length, hmac.mutableBytes);

    [ret appendData:hmac];
    
    // 4. Main Payload
    
    // 4.1 Create Inner Headers (Inner Stream Id, and Inner Stream Key, and Attachments/Binaries)
    
    NSMutableData* inner = createInnerHeaders(serializationData.attachments, serializationData.innerRandomStreamId, serializationData.innerRandomStreamKey);
    
    // 4.2 Append XML after the inner headers
    
    [inner appendData:[serializationData.xml dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 4.3 Optional Compression
    
    NSData* encryptionPayload = serializationData.compressionFlags == kGzipCompressionFlag ? [inner gzippedData] : inner;
    
    // 4.3 HMAC Blockify
    
    NSData* encrypted = hmacBlockifyAndEncrypt(encryptionPayload, encryptionIv, keys, cipher);
    
    [ret appendData:encrypted];
    
    return ret;
}

+ (Kdbx4SerializationData*)deserialize:(NSData*)safeData password:(NSString*)password keyFileDigest:(NSData*)keyFileDigest ppError:(NSError**)ppError {
    size_t endOfHeadersOffset;
    NSDictionary<NSNumber*, NSObject*> *headerEntries = getHeaderEntries((uint8_t*)safeData.bytes, safeData.length, &endOfHeadersOffset);
    
    if(!headerEntries){
        NSLog(@"Error getting header entries. Possibly missing header entry.");
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Error getting header entries. Possibly missing entry." errorCode:-1];
        }
        return nil;
    }

    CryptoParameters *cryptoParams = [[CryptoParameters alloc] initFromHeaders:headerEntries];
    if (!cryptoParams) {
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Could not get all required Crypto parameters. Cannot open." errorCode:-2];
        }
        return nil;
    }
    
    Keys *keys = getKeys(password, keyFileDigest, cryptoParams.kdfParameters, cryptoParams.masterSeed, ppError);
    //NSLog(@"DESERIALIZE KEYS: [%@]", keys);

    if (!keys) {
        return nil;
    }
    
    if(!checkHeaderHash(safeData, endOfHeadersOffset)) {
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Actual Header HMAC or Hash does not match expected. Header has been corrupted." errorCode:-3];
        }
        
        return nil;
    }

    if(!checkHeaderHmac(safeData, endOfHeadersOffset, keys.hmacKey)) {
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Incorrect Passphrase/Key File (Composite Key)" errorCode:kStrongboxErrorCodeIncorrectCredentials];
        }
        
        return nil;
    }
    
    uint8_t *eof = (uint8_t*)safeData.bytes + safeData.length;
    HmacBlockHeader* blockHeader = (HmacBlockHeader*)(((uint8_t*)safeData.bytes) +
                                                      endOfHeadersOffset +
                                                      CC_SHA256_DIGEST_LENGTH +
                                                      CC_SHA256_DIGEST_LENGTH);

    NSData* decrypted = decryptBlocks(blockHeader, keys, cryptoParams, eof);
    if(!decrypted){
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Could not decrypt this database, either due to corruption or unknown Cipher." errorCode:-4];
        }

        return nil;
    }
    
    NSData* decompressed = cryptoParams.compressionFlags == 1 ? [decrypted gunzippedData] : decrypted;
    
    Kdbx4SerializationData* ret = readInnerSafeData(decompressed);
    
    if(kLogVerbose) {
        NSLog(@"Got Inner Safe Serialization Data: [%@]", ret);
    }
    
    // Misc Extra  Serialization Info
    
    KeepassFileHeader keePassFileHeader = getKeePassFileHeader(safeData);

    ret.fileVersion = [NSString stringWithFormat:@"%hu.%hu", keePassFileHeader.major, keePassFileHeader.minor];
    ret.kdfParameters = cryptoParams.kdfParameters;
    ret.compressionFlags = cryptoParams.compressionFlags;
    ret.extraUnknownHeaders = getUnknownHeaders(headerEntries);
    ret.cipherUuid = cryptoParams.cipherUuid;
    
    return ret;
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
        [binary appendData:attachment.data];
        
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

static Kdbx4SerializationData* readInnerSafeData(NSData* innerSafeData) {
    InnerHeaderEntryHeader *innerHeader = (InnerHeaderEntryHeader*)innerSafeData.bytes;
    uint8_t* eof = (uint8_t*) innerSafeData.bytes + innerSafeData.length;
    
    if((uint8_t*)innerSafeData.bytes + SIZE_OF_INNER_HEADER_ENTRY_HEADER > eof) {
        NSLog(@"Not enough data to read even initial inner header.");
        return nil;
    }
    
    NSData* innerRandomStreamId = nil;
    NSData* innerRandomStreamKey = nil;
    NSMutableArray *attachments = [NSMutableArray array];
    
    while (innerHeader->type != kInnerHeaderTypeEnd) {
        size_t headerLength = littleEndian4BytesToUInt32(innerHeader->lengthBytes);
        
        if (innerHeader->data + headerLength > eof) {
            NSLog(@"Not enough data to read even inner header data.");
            return nil;
        }
        
        if (innerHeader->type == kInnerHeaderTypeInnerRandomStreamId) { // Inner Random Stream Id
            NSData* headerData = [NSData dataWithBytes:innerHeader->data length:headerLength];
            innerRandomStreamId = headerData;
        }
        else if (innerHeader->type == kInnerHeaderTypeInnerRandomStreamKey) { // Inner Random Stream Key
            NSData* headerData = [NSData dataWithBytes:innerHeader->data length:headerLength];
            innerRandomStreamKey = headerData;
        }
        else if(innerHeader->type == kInnerHeaderTypeBinary) { // Binary
            if(kLogVerbose) {
                NSLog(@"Found Binary %lu bytes", headerLength - 1);
            }
            BOOL protectedInMemory = innerHeader->data[0] == 1;
            NSData* binary = [NSData dataWithBytes:&innerHeader->data[1] length:headerLength-1];
            
            DatabaseAttachment *attachment = [[DatabaseAttachment alloc] init];
            attachment.compressed = YES;
            attachment.protectedInMemory = protectedInMemory;
            attachment.data = binary;
            
            [attachments addObject:attachment];
        }
        else {
            NSLog(@"Unknown inner header type! [%d]", innerHeader->type);
        }
        
        innerHeader = (InnerHeaderEntryHeader*)(innerHeader->data + headerLength);
        
        if (innerHeader->data + SIZE_OF_INNER_HEADER_ENTRY_HEADER > eof) {
            NSLog(@"Not enough data to read next inner header.");
            return nil;
        }
    }
    
    size_t xmlLength = eof - innerHeader->data;
    if (xmlLength < 0) {
        NSLog(@"Negative data to read XML.");
        return nil;
    }
    
    NSString* xml = [[NSString alloc] initWithBytes:innerHeader->data length:xmlLength encoding:NSUTF8StringEncoding];

    if(kLogVerbose) {
        NSLog(@"\n\n%@\n\n", xml);
    }
    
    Kdbx4SerializationData* ret = [[Kdbx4SerializationData alloc] init];
    
    ret.innerRandomStreamId = innerRandomStreamId ? littleEndian4BytesToUInt32((uint8_t*)innerRandomStreamId.bytes) : kInnerStreamPlainText;
    ret.innerRandomStreamKey = innerRandomStreamKey;
    ret.attachments = attachments;
    ret.xml = xml;

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

static NSData* decryptBlocks(HmacBlockHeader *blockHeader, Keys *keys, CryptoParameters *cryptoParams, uint8_t* eof) {
    int i=0;
    size_t blockLength = littleEndian4BytesToInt32(blockHeader->lengthBytes);
    NSMutableData *dec = [[NSMutableData alloc] init];
    
    while (blockLength > 0) {
        //NSLog(@"Decrypting Block %d of length [%zu]", i, blockLength);
        if(blockHeader->data + blockLength > eof) {
            NSLog(@"Not enough data to decrypt Block!");
            return nil;
        }
        
        NSData* block = [NSData dataWithBytes:blockHeader->data length:blockLength];
        
        NSData *actualHmac = getBlockHmac(block, keys.hmacKey, i);
        NSData *expectedHmac = [NSData dataWithBytes:blockHeader->hmacSha256 length:CC_SHA256_DIGEST_LENGTH];
        
        if(![actualHmac isEqual:expectedHmac]) {
            NSLog(@"Actual Block HMAC does not match expected. Block has been corrupted.");
            return nil;
        }
    
        [dec appendData:block];
        
        blockHeader = (HmacBlockHeader*)(((uint8_t*)blockHeader) + SIZE_OF_HMAC_BLOCK_HEADER + blockLength);
        blockLength = littleEndian4BytesToInt32(blockHeader->lengthBytes);
        i++;
    }
    
    id<Cipher> cipher = getCipher(cryptoParams.cipherUuid);
    
    if(!cipher) {
        NSLog(@"Unknown Cipher ID: [%@]. Do not know how to decrypt.", [cryptoParams.cipherUuid UUIDString]);
        return nil;
    }
    
    return [cipher decrypt:dec iv:cryptoParams.iv key:keys.masterKey];
}

static Keys* getKeys(NSString* password, NSData* keyFileDigest, KdfParameters *kdfParameters, NSData* masterSeed, NSError** error) {
    Keys *ret = [[Keys alloc] init];
    id<KeyDerivationCipher> kdf = getKeyDerivationCipher(kdfParameters, error);
    
    if(!kdf) {
        NSLog(@"Could not create KDF Cipher with KDFPARAMS: [%@]", kdfParameters);
        return nil;
    }
    
    ret.compositeKey = getCompositeKey(password, keyFileDigest);
    ret.transformKey = [kdf deriveKey:ret.compositeKey];
    ret.masterKey = getMasterKey(masterSeed, ret.transformKey);

    // FUTURE: Need to handle different size master keys for different ciphers...
    // Code in KdbxFile.cs ComputeKeys provides example.
    
    ret.hmacKey = getHmacKey(masterSeed, ret.transformKey);

    return ret;
}

static BOOL checkHeaderHash(NSData* safeData, size_t offset) {
    // Hash Header for corruption check
    
    NSMutableData* actualHeaderHash = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(safeData.bytes, (CC_LONG)offset, actualHeaderHash.mutableBytes);
    
    if(kLogVerbose) {
        NSLog(@"HEADERHASH (ACTUAL): %@", [actualHeaderHash base64EncodedStringWithOptions:kNilOptions]);
    }
    
    NSData* expectedHash = [safeData subdataWithRange:NSMakeRange(offset, CC_SHA256_DIGEST_LENGTH)];
    
    if(![actualHeaderHash isEqual:expectedHash]) {
        NSLog(@"Actual Header Hash does not match expected. Header has been corrupted.");
        return NO;
    }
    
    return YES;
}

static BOOL checkHeaderHmac(NSData* safeData, size_t offset, NSData* hmacKey) {
    // Header HMAC
    
    NSData *headerDataSubRange = [safeData subdataWithRange:NSMakeRange(0, offset)];
    NSData *actualHmac256 = getHeaderHmac(headerDataSubRange, hmacKey);
    
    if(kLogVerbose) {
        NSLog(@"HEADER HMAC (ACTUAL): %@", [actualHmac256 base64EncodedStringWithOptions:kNilOptions]);
    }
    NSData* expectHmac = [safeData subdataWithRange:NSMakeRange(offset + CC_SHA256_DIGEST_LENGTH, CC_SHA256_DIGEST_LENGTH)];
    
    if(![actualHmac256 isEqual:expectHmac]) {
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

static NSData* getHmacKeyForBlock(NSData* key, uint64_t blockIndex)
{
    NSData* index = Uint64ToLittleEndianData(blockIndex);
    
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA512_DIGEST_LENGTH];
    
    CC_SHA512_CTX ctx;
    CC_SHA512_Init(&ctx);
    CC_SHA512_Update(&ctx, index.bytes, (CC_LONG)index.length);
    CC_SHA512_Update(&ctx, key.bytes, (CC_LONG)key.length);
    CC_SHA512_Final(hash.mutableBytes, &ctx);
    
    return hash;
}

static NSData* getHeaderHmac(NSData *header, NSData* hmacKey)
{
    NSData* blockKey = getHmacKeyForBlock(hmacKey, 0xFFFFFFFFFFFFFFFF);
   
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, blockKey.bytes, blockKey.length, header.bytes, (CC_LONG)header.length, hmac.mutableBytes);

    return hmac;
}

static NSData* getBlockHmac(NSData *data, NSData* hmacKey, uint64_t blockIndex)
{
    NSData* blockKey = getHmacKeyForBlock(hmacKey, blockIndex);
    NSData* index = Uint64ToLittleEndianData(blockIndex);
    NSData* blockSizeData = Uint32ToLittleEndianData((uint32_t)data.length);

    CCHmacContext ctx;
    CCHmacInit(&ctx, kCCHmacAlgSHA256, blockKey.bytes, blockKey.length);
    CCHmacUpdate(&ctx, index.bytes, index.length);
    CCHmacUpdate(&ctx, blockSizeData.bytes, blockSizeData.length);

    if(data.length){
        CCHmacUpdate(&ctx, data.bytes, data.length);
    }

    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmacFinal(&ctx, hmac.mutableBytes);
    
    return hmac;
}

static NSDictionary<NSNumber *,NSObject *>* getHeaderEntries(uint8_t * const buffer, size_t bufferLength, size_t* finalOffset) {
    NSMutableDictionary<NSNumber *,NSObject *> *headerEntries = [NSMutableDictionary dictionary];
    
    int offset = SIZE_OF_KEEPASS_HEADER;
    
    while (offset + SIZE_OF_HEADER_ENTRY_HEADER <= bufferLength) {
        HeaderEntryHeader *headerEntry = (HeaderEntryHeader*)&buffer[offset];
        
        int32_t length = littleEndian4BytesToInt32(headerEntry->lengthBytes);
        if(kLogVerbose) {
            NSLog(@"Found Header Entry of Type %d and length %d", headerEntry->id, length);
        }
        
        if(offset + SIZE_OF_HEADER_ENTRY_HEADER + length > bufferLength) {
            NSLog(@"This safe appears to be corrupt. Header entry found at [%d] with length of [%d] but only [%lu] data bytes total.", offset, length, bufferLength);
            return nil;
        }
        
        uint8_t* data = &buffer[offset + SIZE_OF_HEADER_ENTRY_HEADER];
        NSData* headerData = [NSData dataWithBytes:data length:length];
        offset += SIZE_OF_HEADER_ENTRY_HEADER + length;
        
        if(END_OF_ENTRIES == headerEntry->id) {
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
    
    if(![Kdbx4Serialization verifyRequiredHeadersPresent:headerEntries]) {
        return nil;
    }
    
    *finalOffset = offset;
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

@end
