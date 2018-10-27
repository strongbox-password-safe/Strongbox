//
//  KdbxSerializationCommon.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KdbxSerializationCommon.h"
#import "BinaryParsingHelper.h"
#import "VariantDictionary.h"
#import "SafeTools.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

static const BOOL kLogVerbose = YES;

@implementation KdbxSerializationCommon

BOOL keePassSignatureAndVersionMatch(NSData * candidate, uint32_t majorVersion, uint32_t minorVersion) {
    if(candidate.length < SIZE_OF_KEEPASS_HEADER) {
        return NO;
    }
    
    KeepassFileHeader header = getKeePassFileHeader(candidate);
    
    // https://gist.github.com/msmuenchen/9318327
    
    //[0x03,0xD9,0xA2,0x9A];
    
    if (header.signature1[0] != 0x03 ||
        header.signature1[1] != 0xD9 ||
        header.signature1[2] != 0xA2 ||
        header.signature1[3] != 0x9A) {
        NSLog(@"No Keepass magic");
        return NO;
    }
    
    // 0xB54BFB67 - * for kdbx file of KeePass 2.x pre-release (alpha & beta) : 0xB54BFB66 ,
    // * for kdbx file of KeePass post-release : 0xB54BFB67 .
    
    if (header.signature2[0] != 0x67 ||
        header.signature2[1] != 0xFB ||
        header.signature2[2] != 0x4B ||
        header.signature2[3] != 0xB5) {
        NSLog(@"No Keepass magic 2");
        return NO;
    }
    
    if(header.major != majorVersion || header.minor != minorVersion) {
        return NO;
    }

    return YES;
}

KeepassFileHeader getKeePassFileHeader(NSData* data) {
    KeepassFileHeader ret;
    [data getBytes:&ret length:SIZE_OF_KEEPASS_HEADER];
    return ret;
}

NSObject* getHeaderEntryObject(uint8_t identifier, NSData* data) {
    size_t length = data.length;
    switch(identifier) {
        case ENCRYPTIONIV:
        case PROTECTEDSTREAMKEY:
        case STREAMSTARTBYTES:
        case TRANSFORMSEED:
        case COMMENT:
            return data;
            break;
        case CIPHERID:
            if(length != 16) {
                NSLog(@"WARN: CIPHERID entry length != 4. Unexpected. Skipping.");
                return nil;
            }
            else {
                if(kLogVerbose) {
                    NSLog(@"CIPHERID UUIDString: [%@]", [[NSUUID alloc] initWithUUIDBytes:data.bytes].UUIDString);
                }
                return data;
            }
            break;
        case COMPRESSIONFLAGS:
            if(length != 4) {
                NSLog(@"WARN: COMPRESSIONFLAGS entry length != 4. Unexpected. Skipping.");
                return nil;
            }
            else {
                NSNumber *compressionFlags = [NSNumber numberWithInt:littleEndian4BytesToInt32((uint8_t*)data.bytes)];
                return compressionFlags;
            }
            break;
        case MASTERSEED:
            if(length != 32) {
                // TODO: Is this true for Kdbx4?
                NSLog(@"WARN: MASTERSEED entry length != 32. Unexpected. Skipping. Almost certainly lead to issues.");
                return nil;
            }
            else {
                return data;
            }
            break;
        case TRANSFORMROUNDS:
            if(length != 8) {
                NSLog(@"WARN: TRANSFORMROUNDS entry length != 8. Unexpected. Skipping.");
                return nil;
            }
            else {
                NSNumber *transformRounds = [NSNumber numberWithLongLong:littleEndian8BytesToInt64((uint8_t*)data.bytes)];
                return transformRounds;
            }
            break;
        case INNERRANDOMSTREAMID:
            if(length != 4) {
                NSLog(@"WARN: INNERRANDOMSTREAMID entry length != 4. Unexpected. Skipping.");
                return nil;
            }
            else {
                NSNumber *innerRandomStreamId = [NSNumber numberWithInt:littleEndian4BytesToInt32((uint8_t*)data.bytes)];
                return innerRandomStreamId;
            }
            break;
        case KDFPARAMETERS:
            return [VariantDictionary fromData:data];
            break;
        default:
            NSLog(@"Found unknown header entry type: [%d] of length [%zu]", identifier, length);
            return data;
            break;
    }
}

void dumpHeaderEntries(NSDictionary *headerEntries) {
    for (NSNumber* identifier in headerEntries.allKeys) {
        NSLog(@"HDR: [%@] => [%@]", headerEntryIdentifierString(identifier.integerValue), [headerEntries objectForKey:identifier]);
    }
}

NSString* headerEntryIdentifierString(HeaderEntryIdentifier identifier) {
    switch(identifier) {
        case END_OF_ENTRIES:
            return @"END_OF_ENTRIES";
            break;
        case COMMENT:
            return @"COMMENT";
            break;
        case CIPHERID:
            return @"CIPHERID";
            break;
        case COMPRESSIONFLAGS:
            return @"COMPRESSIONFLAGS";
            break;
        case MASTERSEED:
            return @"MASTERSEED";
            break;
        case TRANSFORMSEED:
            return @"TRANSFORMSEED";
            break;
        case TRANSFORMROUNDS:
            return @"TRANSFORMROUNDS";
            break;
        case ENCRYPTIONIV:
            return @"ENCRYPTIONIV";
            break;
        case PROTECTEDSTREAMKEY:
            return @"PROTECTEDSTREAMKEY";
            break;
        case STREAMSTARTBYTES:
            return @"STREAMSTARTBYTES";
            break;
        case INNERRANDOMSTREAMID:
            return @"INNERRANDOMSTREAMID";
            break;
        case KDFPARAMETERS:
            return @"KDFPARAMETERS";
        default:
            return [NSString stringWithFormat:@"Unknown Header [%d]", (int)identifier];
    }
}

NSData *getCompositeKey(NSString * _Nonnull password) {
    //////////////////////////////////////
    // Get Composite Key
    // To generate the composite key for a .kdbx file :
    // 1. You must hash (with SHA-256) all credentials needed (passphrase, key of the keyfile, Windows User Account),
    // 2. You must then concatenate ALL hashed credentials in this order : passphrase, keyfile, Windows User Account,
    // 3. You must then hash the result of the concatenation. Even though you have just one credential (for example,
    //    just a passphrase), you still need to hash it twice (a first one for the step 1, and second one for the step 3).
    //    The result of the hash is the composite key
    
    //NSData *keyFileData = [NSData data];
    
    NSData *hashedPassword = [SafeTools sha256: [password dataUsingEncoding:NSUTF8StringEncoding]];
    //NSData *hashedKeyFileData = [SafeTools sha256: keyFileData];
    
    // Concatenate together in one big sha256...
    
    NSMutableData *compositeKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, hashedPassword.bytes, (CC_LONG)hashedPassword.length);
    //CC_SHA256_Update(&context, hashedKeyFileData.bytes, (CC_LONG)hashedKeyFileData.length);
    CC_SHA256_Final(compositeKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        NSLog(@"COMPOSITE KEY: %@", [compositeKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return compositeKey;
}

// TODO: May not be common... todo

NSData *getAesTransformKey(NSData *compositeKey, NSData* transformSeed, uint64_t transformRounds) {
    ///////////////////////////////////////////////////////////////////////////////////////////
    //    1. create an AES cipher, taking Transform Seed as its key/seed,
    //    2. initialize the transformed key value with the composite key value (transformed_key = composite_key),
    //    3. use this cipher to encrypt the transformed_key N times ( transformed_key = AES(transformed_key), N times),
    //    4. hash (with SHA-256) the transformed_key (transformed_key = sha256(transformed_key) ),
    //    5. concatenate the Master Seed to the transformed_key (transformed_key = concat(Master Seed, transformed_key) ),
    //    6. hash (with SHA-256) the transformed_key to get the final master key (final_master_key = sha256(transformed_key) ).
    //    You now have the final master key, you can finally decrypt the database (the part of the file after the header for .kdb, and after the End of Header field for .kdbx).
    
    CCCryptorRef cryptorRef;
    CCCryptorStatus status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES, kCCOptionECBMode, transformSeed.bytes, transformSeed.length, NULL, &cryptorRef);
    if(kCCSuccess != status) {
        CCCryptorRelease(cryptorRef);
        return nil;
    }
    
    uint8_t derivedData[32];
    [compositeKey getBytes:derivedData length:32];
    
    size_t tmp;
    uint64_t rounds = transformRounds;
    while(rounds--) {
        status = CCCryptorUpdate(cryptorRef, derivedData, 32, derivedData, 32, &tmp);
        if(kCCSuccess != status) {
            CCCryptorRelease(cryptorRef);
            return nil;
        }
    }
    
    status = CCCryptorFinal(cryptorRef,derivedData, 32, &tmp);
    if(kCCSuccess != status) {
        CCCryptorRelease(cryptorRef);
        return nil;
    }
    CCCryptorRelease(cryptorRef);
    
    /* Hash the result */
    
    uint8_t hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(derivedData, 32, hash);
    
    NSData *transformKey = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
    
    if(kLogVerbose) {
        NSLog(@"TRANSFORM KEY: %@", transformKey);
    }
    
    return transformKey;
}

NSData *getMasterKey(NSData* masterSeed, NSData *transformKey) {
    NSMutableData *masterKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, masterSeed.bytes, (CC_LONG)masterSeed.length);
    CC_SHA256_Update(&context, transformKey.bytes, (CC_LONG)transformKey.length);
    CC_SHA256_Final(masterKey.mutableBytes, &context);
    
    if(kLogVerbose) {
        NSLog(@"MASTER KEY: %@", [masterKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return [masterKey copy];
}

@end