//
//  VariantDictionary.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VariantObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface VariantDictionary : NSObject

+ (nullable NSDictionary<NSString*, VariantObject*>*)fromData:(NSData*)data;
+ (NSData*)toData:(NSDictionary<NSString*, VariantObject*>*)dictionary;

@end

NS_ASSUME_NONNULL_END
