//
//  KeePassXmlSerialization.h
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SerializationData.h"

NS_ASSUME_NONNULL_BEGIN

@interface KdbxSerialization : NSObject

+ (BOOL)isAValidSafe:(NSData *)candidate;

+ (nullable SerializationData*)deserialize:(NSData*)safeData password:(nullable NSString*)password keyFileDigest:(nullable NSData *)keyFileDigest ppError:(NSError**)ppError;

- (instancetype)init:(SerializationData*)serializationData;

- (nullable NSString*)stage1Serialize:(NSString*__nullable)password keyFileDigest:(NSData*__nullable)keyFileDigest error:(NSError**)error;
- (nullable NSData*)stage2Serialize:xml error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
