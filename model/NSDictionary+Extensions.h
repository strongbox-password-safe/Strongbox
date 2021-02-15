//
//  NSDictionary+Extensions.h
//  Strongbox
//
//  Created by Mark on 08/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary<KeyType, ValueType> (Extensions)

- (id _Nullable)objectForCaseInsensitiveKey:(NSString *)key;
-(NSArray*)map:(id (^)(KeyType key, ValueType value))block;
-(NSDictionary<KeyType, ValueType>*)filter:(BOOL (^)(KeyType key, ValueType value))block;

@end

NS_ASSUME_NONNULL_END
