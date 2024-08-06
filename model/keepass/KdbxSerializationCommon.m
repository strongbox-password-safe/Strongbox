//
//  KdbxSerializationCommon.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
#import "NSData+Extensions.h"
#import "NSArray+Extensions.h"

static const BOOL kLogVerbose = NO;

@implementation KdbxSerializationCommon

BOOL keePass2SignatureAndVersionMatch(NSData * prefix, uint32_t majorVersion, uint32_t minorVersion, NSError** error) {
    return keePassSignatureAndVersionMatch(prefix, majorVersion, minorVersion, error);
}

BOOL keePassSignatureAndVersionMatch(NSData * prefix, uint32_t majorVersion, uint32_t minorVersion, NSError** error) {
    if(prefix == nil) {
        return NO;
    }
    
    if(prefix.length < SIZE_OF_KEEPASS_HEADER) {
        if(error) {
            *error = [Utils createNSError:@"candidate.length < SIZE_OF_KEEPASS_HEADER" errorCode:-1];
        }

        return NO;
    }
    
    KeepassFileHeader header = getKeePassFileHeader(prefix);
    
    
    
    
    
    if (header.signature1[0] != 0x03 ||
        header.signature1[1] != 0xD9 ||
        header.signature1[2] != 0xA2 ||
        header.signature1[3] != 0x9A) {
        
        if(error) {
            *error = [Utils createNSError:@"No Keepass magic [0x03,0xD9,0xA2,0x9A]" errorCode:-1];
        }
        
        return NO;
    }
    
    
    
    
    if (header.signature2[0] != 0x67 ||
        header.signature2[1] != 0xFB ||
        header.signature2[2] != 0x4B ||
        header.signature2[3] != 0xB5) {
        
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
                slog(@"WARN: CIPHERID entry length != 4. Unexpected. Skipping.");
                return nil;
            }
            else {
                if(kLogVerbose) {
                    slog(@"CIPHERID UUIDString: [%@]", [[NSUUID alloc] initWithUUIDBytes:data.bytes].UUIDString);
                }
                return data;
            }
            break;
        case COMPRESSIONFLAGS:
            if(length != 4) {
                slog(@"WARN: COMPRESSIONFLAGS entry length != 4. Unexpected. Skipping.");
                return nil;
            }
            else {
                NSNumber *compressionFlags = [NSNumber numberWithUnsignedInt:littleEndian4BytesToUInt32((uint8_t*)data.bytes)];
                return compressionFlags;
            }
            break;
        case MASTERSEED:
            if(length != kMasterSeedLength) {
                slog(@"WARN: MASTERSEED entry length != 32. Unexpected. Skipping. Almost certainly lead to issues.");
                return nil;
            }
            else {
                return data;
            }
            break;
        case TRANSFORMROUNDS:
            if(length != 8) {
                slog(@"WARN: TRANSFORMROUNDS entry length != 8. Unexpected. Skipping.");
                return nil;
            }
            else {
                NSNumber *transformRounds = [NSNumber numberWithUnsignedLongLong:littleEndian8BytesToUInt64((uint8_t*)data.bytes)];
                return transformRounds;
            }
            break;
        case INNERRANDOMSTREAMID:
            if(length != 4) {
                slog(@"WARN: INNERRANDOMSTREAMID entry length != 4. Unexpected. Skipping.");
                return nil;
            }
            else {
                NSNumber *innerRandomStreamId = [NSNumber numberWithUnsignedInt:littleEndian4BytesToUInt32((uint8_t*)data.bytes)];
                return innerRandomStreamId;
            }
            break;
        case KDFPARAMETERS:
            
            return [VariantDictionary fromData:data];
            break;
        default:
            slog(@"Found unknown header entry type: [%d] of length [%zu]", identifier, length);
            return data;
            break;
    }
}

void dumpHeaderEntries(NSDictionary *headerEntries) {
    for (NSNumber* identifier in headerEntries.allKeys) {
        slog(@"HDR: [%@] => [%@]", headerEntryIdentifierString(identifier.integerValue), [headerEntries objectForKey:identifier]);
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
        slog(@"TRANSFORM KEY: %@", transformKey);
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
        slog(@"MASTER KEY: %@", [masterKey base64EncodedStringWithOptions:kNilOptions]);
    }
    
    return [masterKey copy];
}



void dumpXml(NSInputStream* lib) {
    NSInteger read;
    
    NSMutableData *d = [NSMutableData data];
    const int kChunkSize = 32 * 1024;
    uint8_t chunk[kChunkSize];
    
    while ((read = [lib read:chunk maxLength:kChunkSize])) {
        [d appendBytes:chunk length:read];
    }
    
    NSString* xml = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NSError* error;
    NSString* file = [NSHomeDirectory() stringByAppendingPathComponent:@"dump.xml"];
    
    
    [xml writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    slog(@"XML Dumped: [%@]", error);
}

RootXmlDomainObject* parseXml(uint32_t innerRandomStreamId,
                              NSData* innerRandomStreamKey,
                              XmlProcessingContext* context,
                              NSInputStream* stream,
                              NSOutputStream* xmlDumpStream,
                              BOOL sanityCheckStreamDecryption,
                              NSError** decryptionError,
                              NSError** error) {
    KeePassXmlParser *parser =
        [[KeePassXmlParser alloc] initWithProtectedStreamId:innerRandomStreamId
                                                        key:innerRandomStreamKey
                                sanityCheckStreamDecryption:sanityCheckStreamDecryption
                                                    context:context];
    
    if (!parser) {
        if (error) {
            NSString* msg = [NSString stringWithFormat:@"Parser Error - Please send this error to support@strongboxsafe.com: [%d]-[%lu]-[%@]", innerRandomStreamId, (unsigned long)innerRandomStreamKey.length, innerRandomStreamKey.upperHexString];
            *error = [Utils createNSError:msg errorCode:-1];
        }
        
        return nil;
    }
    
    xmlSAXHandler *my_handler = malloc(sizeof(xmlSAXHandler));
    memset(my_handler, 0, sizeof(xmlSAXHandler));
    
    my_handler->startElement = startElement;
    my_handler->endElement = endElement;
    my_handler->characters = characters;
    
    const int kChunkSize = 32 * 1024;
    
    uint8_t chnk[kChunkSize];
    
    NSInteger read = [stream read:chnk maxLength:kChunkSize];
    if(read <= 0) {
        slog(@"Could not read stream");
        if (error) {
            *error = stream.streamError ? stream.streamError : [Utils createNSError:@"Could not read stream" errorCode:-1];
        }
        free(my_handler);
        return nil;
    }
    
    
    
    NSInteger xmlMarker = findXmlMarker(chnk, read);
    if(xmlMarker != 0) {
        slog(@"WARN: Found XML marker starting at offset: %ld", (long)xmlMarker);
    }

    if(xmlMarker > 0) {
        read -= xmlMarker;

        uint8_t tmp[kChunkSize];
        memset(tmp, 0, kChunkSize);
        memcpy(tmp, &chnk[xmlMarker], read);
        memset(chnk, 0, kChunkSize);
        memcpy(chnk, tmp, read);
    }
    else if (xmlMarker < 0) {
        slog(@"Could not find start of XML! Will try parse anyway...");
        
    }
    
    
    
    xmlParserCtxtPtr ctxt = nil;
    int err = XML_ERR_OK;
    do {
        if(read < 0) {
            slog(@"Error reading stream: %ld - [%@]", (long)read, stream.streamError);
            if (error) {
                *error = stream.streamError ? stream.streamError : [Utils createNSError:@"Error reading XML from Stream" errorCode:err];
            }

            if (ctxt) {
                xmlFreeParserCtxt(ctxt);
            }
            free(my_handler);
            return nil;
        }
        
        if (xmlDumpStream) {
            [xmlDumpStream write:chnk maxLength:read];
        }

        if(!ctxt) {
            ctxt = xmlCreatePushParserCtxt(my_handler, (__bridge void *)(parser), (char*)chnk, (int)read, nil);
        }
        else {
            err = xmlParseChunk(ctxt, (char*)chnk, (int)read, 0);
            if (err != XML_ERR_OK || parser.error) {
                break;
            }
        }
    } while((read = [stream read:chnk maxLength:kChunkSize]));
    
    if(err != XML_ERR_OK || parser.error) {
        slog(@"XML Error: %d", err);
        if (error) {
            *error = parser.error ? parser.error : [Utils createNSError:@"Error reading XML" errorCode:err];
        }
        
        xmlFreeParserCtxt(ctxt);
        free(my_handler);
        return nil;
    }
    
    err = xmlParseChunk(ctxt, NULL, 0, 1);
    if(err != XML_ERR_OK || parser.error) {
        slog(@"XML Error: %d", err);
        if (error) {
            NSData* foo = [NSData dataWithBytes:chnk length:20];
            NSString* hex = foo.upperHexString;
            
            *error = parser.error ? parser.error : [Utils createNSError:[NSString stringWithFormat:@"Error reading Final XML Hex = [%@]", hex]
                                errorCode:err];
        }

        xmlFreeParserCtxt(ctxt);
        free(my_handler);
        return nil;
    }
    
    xmlFreeParserCtxt(ctxt);
    free(my_handler);
    
    RootXmlDomainObject* ret = parser.rootElement;

    if ( ret == nil && xmlMarker != 0 ) {
        
        
        if (error) {
            NSData* foo = [NSData dataWithBytes:chnk length:20];
            NSString* hex = foo.upperHexString;
            *error = [Utils createNSError:[NSString stringWithFormat:@"Could not find any valid XML. Hex = [%@]", hex]
                               errorCode:-1];
        }
    }
    
    if ( decryptionError != nil ) {
        *decryptionError = parser.decryptionProblem;
    }
    
    return ret;
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
    
    
    KeePassXmlParser* parser = (__bridge KeePassXmlParser*)ctx;
    [parser didStartElement:elementName attributes:attributes];
}

void endElement(void *ctx, const xmlChar *name) {
    NSString* elementName = @((char*)name);
    
    
    KeePassXmlParser* parser = (__bridge KeePassXmlParser*)ctx;
    [parser didEndElement:elementName];
}

void characters (void *ctx, const xmlChar *ch, int len) {
    NSString* text = [[NSString alloc] initWithBytes:ch length:len encoding:NSUTF8StringEncoding];
    

    KeePassXmlParser* parser = (__bridge KeePassXmlParser*)ctx;
    [parser foundCharacters:text];
}



static char* const marker = "<?xml";
static NSUInteger const kMarkerSize = 5;

NSInteger findXmlMarker(uint8_t* chars, NSUInteger length) {
    uint8_t* ptr = memmem(chars, length, marker, kMarkerSize);
    
    if(ptr) {
        return ptr - chars;
    }
    else {
        return -1;
    }
}

@end
