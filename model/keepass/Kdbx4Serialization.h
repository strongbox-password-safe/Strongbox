//
//  Kdbx4Serialization.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SerializationData.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdbx4Serialization : NSObject

+ (nullable SerializationData*)deserialize:(NSData*)safeData password:(NSString*)password ppError:(NSError**)ppError;

@end

NS_ASSUME_NONNULL_END
