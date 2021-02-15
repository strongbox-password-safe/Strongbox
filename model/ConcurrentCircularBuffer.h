//
//  CircularBuffer.h
//  Strongbox
//
//  Created by Strongbox on 14/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentCircularBuffer<ObjectType> : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCapacity:(NSUInteger)bufferSize NS_DESIGNATED_INITIALIZER;

- (void)addObject:(ObjectType)object;
- (NSArray<ObjectType>*)allObjects;
- (void)removeAllObjects;

@end

NS_ASSUME_NONNULL_END
