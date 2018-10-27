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
#import "BinaryParsingHelper.h"
#import "KdfParameters.h"
#import "KeePassCiphers.h"
#import "Argon2KdfCipher.h"
#import "ChaCha20Cipher.h"
#import "GZIP.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCrypto.h>

typedef struct _HeaderEntryHeader {
    uint8_t id;
    uint8_t lengthBytes[4];
} HeaderEntryHeader;
#define SIZE_OF_HEADER_ENTRY_HEADER      5

static const BOOL kLogVerbose = YES;

@implementation Kdbx4Serialization

+ (SerializationData*)deserialize:(NSData*)safeData password:(NSString*)password ppError:(NSError**)ppError {
    size_t offset;
    NSDictionary<NSNumber*, NSObject*> *headerEntries = getHeaderEntries((uint8_t*)safeData.bytes, safeData.length, &offset);
    
    if(!headerEntries) {
        NSLog(@"Error getting header entries. Possibly missing header entry.");
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Error getting header entries. Possibly missing entry." errorCode:-3];
        }
        return nil;
    }

    // TODO: Package required params from Headers into nice struct and verify all present/defaults. Don't do inline like
    // below.
    
    // Get Composite Key from Password and/or Keyfile
    
    NSData* compositeKey = getCompositeKey(password);
    
    // Get Transform Key from key Derivation Function Algo... Which algo are we using?
    
    KdfParameters *kdfParameters = getGetKDFParameters(headerEntries);
    NSData* transformKey;
    
    if([kdfParameters.uuid isEqual:aesCipherUuid()]) {
        // TODO: Is this right?! I think not
    }
    else if([kdfParameters.uuid isEqual:argon2CipherUuid()]) {
        Argon2KdfCipher *kdf = [[Argon2KdfCipher alloc] initWithParametersDictionary:kdfParameters.parameters];
        
        transformKey = [kdf deriveKey:compositeKey];
    }
    else {
        NSLog(@"Unknown CipherId: [%@]", kdfParameters.uuid.UUIDString);
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Unknown KDF Cipher. Cannot open." errorCode:-3];
        }
        return nil;
    }
    
    NSData* masterSeed = (NSData*)[headerEntries objectForKey:@(MASTERSEED)];
    NSData* masterKey = getMasterKey(masterSeed, transformKey);


    // Hash Header for corruption check

    NSMutableData* actualHeaderHash = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(safeData.bytes, (CC_LONG)offset, actualHeaderHash.mutableBytes);

    if(kLogVerbose) {
        NSLog(@"HEADERHASH (ACTUAL): %@", [actualHeaderHash base64EncodedStringWithOptions:kNilOptions]);
    }

    NSData* expectedHash = [safeData subdataWithRange:NSMakeRange(offset, CC_SHA256_DIGEST_LENGTH)];
    
    if(![actualHeaderHash isEqual:expectedHash]) {
        NSLog(@"Actual Header Hash does not match expected. Header has been corrupted.");
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:@"Actual Header Hash does not match expected. Header has been corrupted." errorCode:-3];
        }
        
        return nil;
    }
    
    // TODO: Figure out how to calculate this HMAC Key
    
    NSData* hmacKey = [[NSData alloc] initWithBase64EncodedString:@"JSGAfy8Li7iZtgut71j88IUjT0T7l9qsNUVUlc35rB+PemZ4Gj+yeYkXgplhkk8UYS3fP0uRYyHFBExfvUp09Q==" options:kNilOptions];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, hmacKey.bytes, hmacKey.length, safeData.bytes, (CC_LONG)offset, cHMAC);
    NSData* actualHmac256 = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    NSData* expectHmac = [safeData subdataWithRange:NSMakeRange(offset + CC_SHA256_DIGEST_LENGTH, CC_SHA256_DIGEST_LENGTH)];
    
    if(![actualHmac256 isEqual:expectHmac]) {
        NSLog(@"HMAC incorrect.");
        // TODO: proper errors.
        return nil;
    }
    
    //
    
    //NSLog(@"Start Data Position: %d",  offset + CC_SHA256_DIGEST_LENGTH + CC_SHA256_DIGEST_LENGTH + 32 + 4); // Block Hmac + Block Length
    
    // HMAC'd Blocks start here before the decryption unlike Kdbx3!!
    
    NSData *dataIn = [safeData subdataWithRange:NSMakeRange(offset + CC_SHA256_DIGEST_LENGTH + CC_SHA256_DIGEST_LENGTH + 32 + 4,
                                                            1595)]; //safeData.length - offset - CC_SHA256_DIGEST_LENGTH - CC_SHA256_DIGEST_LENGTH  - 32 - 4)];
                                                                    // 1595
    
    NSData* iv = (NSData*)[headerEntries objectForKey:@(ENCRYPTIONIV)];
    
    // Decrypt

    NSUUID *cipherUuid = getCipherUuid(headerEntries);
    if([cipherUuid isEqual:aesCipherUuid()]) { // TODO: Does this still work with KDBX4?!
        return nil; // TODO:
    }
    else if([cipherUuid isEqual:chaCha20CipherUuid()]) { // TODO: Does this still work with KDBX4?!
        NSLog(@"CIPHER: ChaCha20");
        
        ChaCha20Cipher *cipher = [[ChaCha20Cipher alloc] init];
        NSData *decrypted = [cipher decrypt:dataIn iv:iv key:masterKey];
        //NSLog(@"%@", decrypted);
        
        NSData *dec = [decrypted gunzippedData];
        NSLog(@"%@", dec);
    }
    else {
        NSString *message=[NSString stringWithFormat:@"Unknown Cipher ID: [%@]. Do not know how to decrypt.", [cipherUuid UUIDString]];
        
        if (ppError != nil) {
            *ppError = [Utils createNSError:message errorCode:-5];
        }
        
        return nil;
    }

//    NSData *decrypted = [AesCipher decrypt:dataIn iv:decryptionParameters.encryptionIv key:masterKey];
//
//    // Verify Start Stream - This checks the correct passphrase/keyfile has been used (or we've done something very wrong in the decryption process :/)
//
//    NSData *actualStartStream = [decrypted subdataWithRange:NSMakeRange(0, decryptionParameters.streamStartBytes.length)];
//    if(![decryptionParameters.streamStartBytes isEqualToData:actualStartStream]) {
//        if (ppError != nil) {
//            *ppError = [Utils createNSError:@"Passphrase Incorrect" errorCode:-6];
//        }
//
//        return nil;
//    }
//
//    // Deblockify
//
//    NSData* deblockified = deblockify((uint8_t*)&decrypted.bytes[decryptionParameters.streamStartBytes.length]);
//
//    if(!deblockified) {
//        if (ppError != nil) {
//            *ppError = [Utils createNSError:@"Could not find next block in unordered blocks list. Cannot deblockify" errorCode:-6];
//        }
//
//        return nil;
//    }
//
//    NSData *xmlData;
//    if(decryptionParameters.compressionFlags == kGzipCompressionFlag) {
//        xmlData = [deblockified gunzippedData];
//    }
//    else {
//        xmlData = deblockified;
//    }
//
//    NSString* xml = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];
//
//    SerializationData* ret = [[SerializationData alloc] init];
//    KeepassFileHeader keePassFileHeader = getKeePassFileHeader(safeData);
//
//    ret.fileVersion = [NSString stringWithFormat:@"%hu.%hu", keePassFileHeader.major, keePassFileHeader.minor];
//    ret.transformRounds = decryptionParameters.transformRounds;
//    ret.compressionFlags = decryptionParameters.compressionFlags;
//    ret.innerRandomStreamId = decryptionParameters.innerRandomStreamId;
//    ret.protectedStreamKey = decryptionParameters.protectedStreamKey;
//    ret.extraUnknownHeaders = getUnknownHeaders(headerEntries);
//    ret.headerHash = [headerHash base64EncodedStringWithOptions:kNilOptions];
//    ret.xml = xml;
//
//    return ret;

    return nil;
}

static KdfParameters* getGetKDFParameters(NSDictionary<NSNumber *,NSObject *>* headers) {
    NSDictionary<NSString *,NSObject *>* params = (NSDictionary<NSString *,NSObject *>*)[headers objectForKey:@(KDFPARAMETERS)];
    
    return [KdfParameters fromHeaders:params];
}

static NSUUID* getCipherUuid(NSDictionary<NSNumber *,NSObject *>* headers) {
    NSData* cipherData = (NSData*)[headers objectForKey:@(CIPHERID)];
    return cipherData ? [[NSUUID alloc] initWithUUIDBytes:cipherData.bytes] : aesCipherUuid();
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
    
    if([headerEntries objectForKey:@(INNERRANDOMSTREAMID)] && ![headerEntries objectForKey:@(PROTECTEDSTREAMKEY)]) {
        NSLog(@"Missing required PROTECTEDSTREAMKEY because INNERRANDOMSTREAMID is Present.");
        return NO;
    }
    
    return YES;
}


@end
