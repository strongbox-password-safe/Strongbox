//
//  KdbSerialization.h
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KdbSerializationData.h"

NS_ASSUME_NONNULL_BEGIN

@interface KdbSerialization : NSObject

+ (BOOL)isAValidSafe:(NSData *)candidate;

+ (nullable KdbSerializationData*)deserialize:(NSData*)safeData password:(NSString*)password ppError:(NSError**)ppError;
+ (nullable NSData*)serialize:(KdbSerializationData*)serializationData password:(NSString*)password ppError:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
