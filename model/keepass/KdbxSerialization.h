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
+ (nullable SerializationData*)deserialize:(NSData*)safeData password:(NSString*)password ppError:(NSError**)ppError;

- (instancetype)init:(SerializationData*)serializationData;
- (NSString*)stage1Serialize:(NSString*)password error:(NSError**)error;
- (nullable NSData*)stage2Serialize:xml error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
