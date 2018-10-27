//
//  VariantDictionary.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VariantDictionary : NSObject

+ (NSDictionary<NSString*, NSObject*>*)fromData:(NSData*)data;

@end

NS_ASSUME_NONNULL_END
