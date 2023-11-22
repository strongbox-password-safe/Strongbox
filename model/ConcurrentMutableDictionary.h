//
//  ConcurrentMutableDictionary.h
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentMutableDictionary<KeyType, ValueType> : NSObject

+ (instancetype)mutableDictionary;

- (void)setObject:(ValueType)object forKey:(nonnull id<NSCopying>)forKey;
- (nullable ValueType)objectForKey:(nonnull KeyType)key;
- (nullable ValueType)objectForKeyedSubscript:(KeyType)key;
- (void)setObject:(ValueType)obj forKeyedSubscript:(KeyType)key;

- (void)removeObjectForKey:(nonnull id<NSCopying>)forKey;
- (void)removeObjectsForKeys:(NSArray<KeyType> *)keyArray;

- (void)removeAllObjects;

@property (readonly) NSArray<KeyType>* allKeys;
@property (readonly) NSArray<ValueType>* allValues;
@property (readonly) NSUInteger count;

@end

NS_ASSUME_NONNULL_END
