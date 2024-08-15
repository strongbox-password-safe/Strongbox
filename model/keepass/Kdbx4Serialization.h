//
//  Kdbx4Serialization.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Kdbx4SerializationData.h"
#import "CryptoParameters.h"
#import "CompositeKeyFactors.h"
#import "InnerRandomStream.h"
#import "KeyDerivationCipher.h"

NS_ASSUME_NONNULL_BEGIN

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

typedef void (^Deserialize4CompletionBlock)(BOOL userCancelled, Kdbx4SerializationData *_Nullable serializationData, NSError*_Nullable innerStreamError, NSError*_Nullable error);
typedef void (^Serialize4CompletionBlock)(BOOL userCancelled, NSError*_Nullable error);

id<KeyDerivationCipher> getKeyDerivationCipher(KdfParameters *kdfParameters, NSError** error);
    
@interface Kdbx4Serialization : NSObject

+ (nullable CryptoParameters*)getCryptoParams:(NSInputStream*)stream; 

+ (NSData*)getYubiKeyChallenge:(NSInputStream *)stream;
+ (NSData *)getYubiKeyChallenge:(KdfParameters *)kdfParameters error:(NSError * _Nullable __autoreleasing *)error;

+ (void)deserialize:(NSInputStream*)stream
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
      xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
         completion:(Deserialize4CompletionBlock)completion;

+ (void)serialize:(Kdbx4SerializationData*)serializationData
  rootXmlDocument:(RootXmlDomainObject *)rootXmlDocument
      innerStream:(id<InnerRandomStream>)innerStream
              ckf:(CompositeKeyFactors*)ckf
     outputStream:(NSOutputStream*)outputStream
       completion:(Serialize4CompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
