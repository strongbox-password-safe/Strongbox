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

- (instancetype)clone;

- (void)insertKey:(KeyType)key withValue:(ValueType)value atIndex:(NSUInteger)atIndex;
- (void)remove:(KeyType)key;
- (void)removeObjectForKey:(KeyType)key;
- (void)removeAllObjects;
- (ValueType)removeObjectAtIndex:(NSUInteger)atIndex;

@property (readonly) NSArray<KeyType>* keys;

- (NSArray<KeyType>*)allKeys;
- (NSArray<ValueType>*)allValues;

@property (readonly) NSUInteger count;

- (ValueType)objectForKey:(KeyType)key;

- (ValueType)objectForCaseInsensitiveKey:(KeyType)key;

- (ValueType)objectForKeyedSubscript:(KeyType)key;
- (void)setObject:(ValueType _Nullable)obj forKeyedSubscript:(KeyType)key;


@property (readonly) NSDictionary<KeyType, ValueType>* dictionary;

- (BOOL)containsKey:(KeyType)key;

@end

NS_ASSUME_NONNULL_END
