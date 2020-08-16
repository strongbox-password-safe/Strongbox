//
//  ConcurrentMutableArray.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentMutableArray<ObjectType> : NSObject

+ (instancetype)mutableArray;

- (void)addObject:(ObjectType)object;


- (id _Nullable)dequeueHead;
- (NSArray<ObjectType>*)dequeueAllMatching:(BOOL (^)(ObjectType obj))block;

@property (nonatomic, nonnull, readonly) NSArray<ObjectType> *snapshot;

@end

NS_ASSUME_NONNULL_END
