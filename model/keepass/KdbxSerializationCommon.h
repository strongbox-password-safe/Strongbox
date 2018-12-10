//
//  KdbxSerializationCommon.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Cipher.h"
#import "RootXmlDomainObject.h"
#import "XmlProcessingContext.h"

typedef struct _KeepassHeader {
    uint8_t signature1[4];
    uint8_t signature2[4];
    uint16_t minor;
    uint16_t major;
} KeepassFileHeader;
#define SIZE_OF_KEEPASS_HEADER      12

typedef NS_ENUM (NSUInteger, HeaderEntryIdentifier) {
    END_OF_ENTRIES = 0,
    COMMENT = 1,
    CIPHERID = 2,
    COMPRESSIONFLAGS = 3,
    MASTERSEED = 4,
    TRANSFORMSEED = 5,
    TRANSFORMROUNDS = 6,
    ENCRYPTIONIV = 7,
    PROTECTEDSTREAMKEY = 8,
    STREAMSTARTBYTES = 9,
    INNERRANDOMSTREAMID = 10,
    KDFPARAMETERS = 11,
};

NS_ASSUME_NONNULL_BEGIN

@interface KdbxSerializationCommon : NSObject

BOOL keePass2SignatureAndVersionMatch(NSData * candidate, uint32_t majorVersion, uint32_t minorVersion);

KeepassFileHeader getKeePassFileHeader(NSData* data);
KeepassFileHeader getNewFileHeader(NSString* version);

void dumpHeaderEntries(NSDictionary *headerEntries);
NSObject*__nullable getHeaderEntryObject(uint8_t identifier, NSData* data);

NSData *getCompositeKey(NSString*__nullable password, NSData*__nullable keyFileDigest);
NSData *getMasterKey(NSData* masterSeed, NSData *transformKey);

NSData*__nullable getAesTransformKey(NSData *compositeKey, NSData* transformSeed, uint64_t transformRounds);

RootXmlDomainObject*__nullable parseKeePassXml(uint32_t innerRandomStreamId, NSData* innerRandomStreamKey, XmlProcessingContext* context, NSString* xml, NSError** error);

@end

NS_ASSUME_NONNULL_END
