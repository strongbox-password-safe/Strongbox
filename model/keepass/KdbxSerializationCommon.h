//
//  KdbxSerializationCommon.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

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

BOOL keePassSignatureAndVersionMatch(NSData * candidate, uint32_t majorVersion, uint32_t minorVersion);
KeepassFileHeader getKeePassFileHeader(NSData* data);

void dumpHeaderEntries(NSDictionary *headerEntries);
NSObject* getHeaderEntryObject(uint8_t identifier, NSData* data);

NSData *getCompositeKey(NSString *password);
NSData *getMasterKey(NSData* masterSeed, NSData *transformKey);

NSData *getAesTransformKey(NSData *compositeKey, NSData* transformSeed, uint64_t transformRounds);

@end

NS_ASSUME_NONNULL_END
