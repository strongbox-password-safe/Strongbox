//
//  KeePassXmlSerialization.h
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SerializationData.h"
#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

@interface KdbxSerialization : NSObject

+ (NSData *_Nullable)getYubikeyChallenge:(NSData *)candidate error:(NSError * _Nullable __autoreleasing *)error;
+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;

+ (nullable SerializationData*)deserialize:(NSData*)safeData
                       compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                                   ppError:(NSError**)ppError;

- (instancetype)init:(SerializationData*)serializationData;

- (nullable NSString*)stage1Serialize:(CompositeKeyFactors*)compositeKeyFactors error:(NSError**)error;
- (nullable NSData*)stage2Serialize:xml error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
