//
//  Kdbx4Serialization.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Kdbx4SerializationData.h"
#import "CryptoParameters.h"
#import "CompositeKeyFactors.h"

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

typedef void (^Deserialize4CompletionBlock)(BOOL userCancelled, Kdbx4SerializationData *_Nullable serializationData, NSError*_Nullable error);
typedef void (^Serialize4CompletionBlock)(BOOL userCancelled, NSData *_Nullable data, NSError*_Nullable error);

@interface Kdbx4Serialization : NSObject

+ (nullable CryptoParameters*)getCryptoParams:(NSData*)safeData; // Used to test AutoFill crash likelyhood without full decrypt

+ (void)deserialize:(NSData*)safeData
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
useLegacyDeserialization:(BOOL)useLegacyDeserialization
         completion:(Deserialize4CompletionBlock)completion;

+ (void)serialize:(Kdbx4SerializationData*)serializationData
              xml:(NSString*)xml
              ckf:(CompositeKeyFactors*)ckf
       completion:(Serialize4CompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
