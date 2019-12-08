//
//  KdbxSerializationCommon.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KdbxSerializationCommon.h"
#import "Utils.h"
#import "VariantDictionary.h"
#import "PwSafeSerialization.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "KeePassConstants.h"
#import "KeePassCiphers.h"
#import "KeePassXmlParser.h"
#include <libxml/parser.h>

static const BOOL kLogVerbose = NO;

@implementation KdbxSerializationCommon

BOOL keePass2SignatureAndVersionMatch(NSData * candidate, uint32_t majorVersion, uint32_t minorVersion, NSError** error) {
    return keePassSignatureAndVersionMatch(candidate, majorVersion, minorVersion, error);
}

BOOL keePassSignatureAndVersionMatch(NSData * candidate, uint32_t majorVersion, uint32_t minorVersion, NSError** error) {
    if(candidate == nil) {
        return NO;
    }
    
    if(candidate.length < SIZE_OF_KEEPASS_HEADER) {
        if(error) {
            *error = [Utils createNSError:@"candidate.length < SIZE_OF_KEEPASS_HEADER" errorCode:-1];
        }

        return NO;
    }
    
    KeepassFileHeader header = getKeePassFileHeader(candidate);
    
    // https://gist.github.com/msmuenchen/9318327
    
    //[0x03,0xD9,0xA2,0x9A];
    
    if (header.signature1[0] != 0x03 ||
        header.signature1[1] != 0xD9 ||
        header.signature1[2] != 0xA2 ||
        header.signature1[3] != 0x9A) {
        //NSLog(@"No Keepass magic");
        if(error) {
            *error = [Utils createNSError:@"No Keepass magic [0x03,0xD9,0xA2,0x9A]" errorCode:-1];
        }
        
        return NO;
    }
    
    // 0xB54BFB67 - * for kdbx file of KeePass 2.x pre-release (alpha & beta) : 0xB54BFB66 ,
    // * for kdbx file of KeePass post-release : 0xB54BFB67 .
    
    if (header.signature2[0] != 0x67 ||
        header.signature2[1] != 0xFB ||
        header.signature2[2] != 0x4B ||
        header.signature2[3] != 0xB5) {
        //NSLog(@"No Keepass magic 2");
        if(error) {
            *error = [Utils createNSError:@"No Keepass magic: 0xB54BFB67" errorCode:-1];
        }
        
        return NO;
    }
    
    if(header.major != majorVersion || header.minor > minorVersion) {
        if(error) {
            NSString* message = [NSString stringWithFormat:@"KeePass(%d.%d) Version MisMatch ", header.major, header.minor];
            *error = [Utils createNSError:message errorCode:-1];
        }
        
        return NO;
    }

    return YES;
}

KeepassFileHeader getNewFileHeader(NSString* version) {
    KeepassFileHeader header;
    
    header.signature1[0] = 0x03;
    header.signature1[1] = 0xD9;
    header.signature1[2] = 0xA2;
    header.signature1[3] = 0x9A;
    header.signature2[0] = 0x67;
    header.signature2[1] = 0xFB;
    header.signature2[2] = 0x4B;
    header.signature2[3] = 0xB5;
    
    NSArray<NSString*> *versionComponents = [version componentsSeparatedByString:@"."];
    header.major = [versionComponents objectAtIndex:0].intValue;
    header.minor = [versionComponents objectAtIndex:1].intValue;
    
    return header;
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
            if(length != kMasterSeedLength) {
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
            //NSLog(@"KDFPARAMS (b64): [%@]", [data base64EncodedStringWithOptions:kNilOptions]);
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//void dumpXml(NSInputStream* lib) {
//    NSInteger read;
//    
//    NSMutableData *d = [NSMutableData data];
//    const int kChunkSize = 32 * 1024;
//    uint8_t chunk[kChunkSize];
//    
//    while ((read = [lib read:chunk maxLength:kChunkSize])) {
//        [d appendBytes:chunk length:read];
//    }
//    
//    NSString* xml = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
//    NSError* error;
//    [xml writeToFile:@"/Users/mark/Desktop/dump.xml" atomically:YES encoding:NSUTF8StringEncoding error:&error];
//    NSLog(@"XML Dumped: [%@]", error);
//}

RootXmlDomainObject* parseXml(uint32_t innerRandomStreamId,
                              NSData* innerRandomStreamKey,
                              XmlProcessingContext* context,
                              NSInputStream* stream,
                              NSError** error) {
    KeePassXmlParser *parser =
        [[KeePassXmlParser alloc] initWithProtectedStreamId:innerRandomStreamId
                                                        key:innerRandomStreamKey
                                                    context:context];
    
    xmlSAXHandler *my_handler = malloc(sizeof(xmlSAXHandler));
    memset(my_handler, 0, sizeof(xmlSAXHandler));
    
    my_handler->startElement = startElement;
    my_handler->endElement = endElement;
    my_handler->characters = characters;
    
    const int kChunkSize = 32 * 1024;
    
    uint8_t chnk[kChunkSize];
    
    NSUInteger read = [stream read:chnk maxLength:kChunkSize];
    if(read <= 0) {
        NSLog(@"Could not read stream");
        if (error) {
           *error = [Utils createNSError:@"Could not read stream" errorCode:-1];
        }
        return nil;
    }
    
    // Find Start of XML
    
    NSInteger xmlMarker = findXmlMarker(chnk, read);
    
    NSLog(@"Found XML marker starting at offset: %ld", (long)xmlMarker);
    
    if(xmlMarker > 0) {
        read -= xmlMarker;

        uint8_t tmp[kChunkSize];
        memset(tmp, 0, kChunkSize);
        memcpy(tmp, &chnk[xmlMarker], read);
        memset(chnk, 0, kChunkSize);
        memcpy(chnk, tmp, read);
    }
    else if (xmlMarker < 0) {
        NSLog(@"Could not find start of XML");
        if (error) {
           *error = [Utils createNSError:@"Could not find start of XML" errorCode:-1];
        }
        return nil;
    }
    
    // Parse XML
    
    xmlParserCtxtPtr ctxt = nil;
    int err = XML_ERR_OK;
    do {
        if(read == -1) {
            NSLog(@"Error reading stream: %d", err);
            if (error) {
                *error = [Utils createNSError:@"Error reading XML Stream" errorCode:err];
            }
            return nil;
        }
        if(!ctxt) {
            ctxt = xmlCreatePushParserCtxt(my_handler, (__bridge void *)(parser), (char*)chnk, (int)read, nil);
        }
        else {
            err = xmlParseChunk(ctxt, (char*)chnk, (int)read, 0);
            if (err != XML_ERR_OK) {
                break;
            }
        }
    } while((read = [stream read:chnk maxLength:kChunkSize]));
    
    if(err != XML_ERR_OK) {
        NSLog(@"XML Error: %d", err);
        if (error) {
            *error = [Utils createNSError:@"Error reading XML" errorCode:err];
        }
        return nil;
    }
    
    err = xmlParseChunk(ctxt, NULL, 0, 1);
    if(err != XML_ERR_OK) {
        NSLog(@"XML Error: %d", err);
        if (error) {
            *error = [Utils createNSError:@"Error reading Final XML" errorCode:err];
        }
        return nil;
    }
    
    xmlFreeParserCtxt(ctxt);
    free(my_handler);
    
    return parser.rootElement;
}

void startElement(void *ctx, const xmlChar *fullname, const xmlChar **atts) {
    NSString* elementName = @((char*)fullname);

    NSMutableDictionary* attributes;
    if(atts) {
        attributes = [NSMutableDictionary dictionaryWithCapacity:8];
        int current = 0;
        while (atts[current * 2] != NULL) {
            const char* key = (char*)atts[(current * 2)];
            const char* value = (char*)atts[(current * 2) + 1];
            attributes[@(key)] = @(value);
            current++;
        }
    }
    
    //NSLog(@"startElement: %s - %@", fullname, attributes);
    KeePassXmlParser* parser = (__bridge KeePassXmlParser*)ctx;
    [parser didStartElement:elementName attributes:attributes];
}

void endElement(void *ctx, const xmlChar *name) {
    NSString* elementName = @((char*)name);
    //NSLog(@"endElement: [%@]", elementName);
    
    KeePassXmlParser* parser = (__bridge KeePassXmlParser*)ctx;
    [parser didEndElement:elementName];
}

void characters (void *ctx, const xmlChar *ch, int len) {
    NSString* text = [[NSString alloc] initWithBytes:ch length:len encoding:NSUTF8StringEncoding];
    //NSLog(@"characters: [%@]", text);

    KeePassXmlParser* parser = (__bridge KeePassXmlParser*)ctx;
    [parser foundCharacters:text];
}

//

static char* const marker = "<?xml";
static NSUInteger const kMarkerSize = 5;
static NSUInteger const kScanLengthForXmlMarker = 64;

NSInteger findXmlMarker(uint8_t* chars, NSUInteger length) {
    NSInteger offset = 0;
    
    while(offset < length && offset < kScanLengthForXmlMarker) {
        if(memcmp(&chars[offset], marker, kMarkerSize) == 0) {
            return offset;
        }
        offset++;
    }
    
    return -1;
}

//BOOL xmlNeedsCleanup(NSString* foo) {
//    return (![foo hasPrefix:kXmlPrefix]);
//}
//
//NSString* xmlCleanupAndTrim(NSString* foo) {
//    // Some apps (KeeWeb) seem to prefix crap to the XML :( NSXMLParser is extremely strict about this, so if the XML
//    // Doesn't being with <?xml we do a quick search for it a small prefix at the start and start there instead if it's
//    // present
//
//    if(xmlNeedsCleanup(foo)) {
//        NSLog(@"WARNING: XML does not conform to XML Standard, does not being with \"<?xml\". Searching short initial prefix for this string for this prefix...");
//
//        NSUInteger bounds = MIN(foo.length, 16);
//        NSRange foundPrefix = [[foo substringWithRange:NSMakeRange(0, bounds)] rangeOfString:kXmlPrefix];
//        if(foundPrefix.location != NSNotFound) {
//            NSLog(@"WARNING: Found prefix at %lu, starting from here instead...", (unsigned long)foundPrefix.location);
//            return [foo substringFromIndex:foundPrefix.location];
//        }
//    }
//
//    return foo;
//}

@end
