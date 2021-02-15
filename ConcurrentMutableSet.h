//
//  ConcurrentMutableSet.h
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentMutableSet<ObjectType> : NSObject

+ (instancetype)mutableSet;
- (void)addObject:(ObjectType)object;

- (void)addObjectsFromArray:(NSArray<ObjectType>*)array;
- (void)removeObject:(ObjectType)object;
- (NSSet<ObjectType>*)snapshot;
- (NSArray<ObjectType>*)arraySnapshot;

- (NSUInteger)count;
- (BOOL)containsObject:(ObjectType)object;

@property (readonly, nullable) id anyObject;

@end

NS_ASSUME_NONNULL_END
