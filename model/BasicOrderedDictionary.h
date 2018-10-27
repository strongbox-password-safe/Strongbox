//
//  BasicOrderedDictionary.h
//  StrongboxTests
//
//  Created by Mark on 24/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BasicOrderedDictionary<KeyType, ValueType> : NSObject

- (void)addKey:(KeyType)key andValue:(ValueType)value;
- (NSArray<KeyType>*) allKeys;
- (nullable ValueType)objectForKey:(KeyType)key;

@end

NS_ASSUME_NONNULL_END
