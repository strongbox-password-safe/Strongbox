//
//  BasicOrderedDictionary.h
//  StrongboxTests
//
//  Created by Mark on 24/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MutableOrderedDictionary<KeyType, ValueType> : NSObject

- (void)addKey:(KeyType)key andValue:(ValueType _Nullable)value;
- (void)insertKey:(KeyType)key withValue:(ValueType)value atIndex:(NSUInteger)atIndex;
- (void)remove:(KeyType)key;

- (NSArray<KeyType>*)allKeys;
- (NSUInteger)count;

- (id)objectForKeyedSubscript:(KeyType)key;
- (void)setObject:(ValueType _Nullable)obj forKeyedSubscript:(KeyType)key;

- (void)addAll:(MutableOrderedDictionary*)other;

@property (readonly) NSDictionary<KeyType, ValueType>* dictionary;

- (BOOL)containsKey:(KeyType)key;

@end

NS_ASSUME_NONNULL_END
