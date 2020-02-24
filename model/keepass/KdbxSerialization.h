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

typedef void (^SerializeCompletionBlock)(BOOL userCancelled, NSString*_Nullable hash, NSError*_Nullable error);

typedef void (^DeserializeCompletionBlock)(BOOL userCancelled, SerializationData*_Nullable serializationData, NSError*_Nullable error);

@interface KdbxSerialization : NSObject

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;

+ (void)deserialize:(NSData*)safeData
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
         completion:(DeserializeCompletionBlock)completion;

- (instancetype)init:(SerializationData*)serializationData;

- (void)stage1Serialize:(CompositeKeyFactors *)compositeKeyFactors
             completion:(SerializeCompletionBlock)completion;

- (nullable NSData*)stage2Serialize:(NSString*)xml error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
