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

@interface Kdbx4Serialization : NSObject

+ (NSData *_Nullable)getYubikeyChallenge:(NSData *)candidate error:(NSError **)error;

+ (nullable CryptoParameters*)getCryptoParams:(NSData*)safeData; // Used to test AutoFill crash likelyhood without full decrypt

+ (nullable Kdbx4SerializationData*)deserialize:(NSData*)safeData compositeKey:(CompositeKeyFactors*)compositeKey ppError:(NSError**)ppError;

+ (nullable NSData*)serialize:(Kdbx4SerializationData*)serializationData compositeKey:(CompositeKeyFactors*)compositeKey ppError:(NSError**)ppError;

@end

NS_ASSUME_NONNULL_END
