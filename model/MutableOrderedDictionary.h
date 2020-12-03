//
//  BasicOrderedDictionary.h
//  StrongboxTests
//
//  Created by Mark on 24/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MutableOrderedDictionary<KeyType, ValueType> : NSObject

- (void)addKey:(KeyType)key andValue:(ValueType)value;
- (NSArray<KeyType>*)allKeys;
- (NSUInteger)count;

- (id)objectForKeyedSubscript:(KeyType)key;
- (void)setObject:(ValueType)obj forKeyedSubscript:(KeyType)key;

- (void)addAll:(MutableOrderedDictionary*)other;

@end

NS_ASSUME_NONNULL_END
