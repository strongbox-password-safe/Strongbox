//
//  ConcurrentMutableQueue.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentMutableQueue<ObjectType> : NSObject

+ (instancetype)mutableQueue;

- (ObjectType)dequeue;
- (void)enqueue:(ObjectType)anObject;


@end

NS_ASSUME_NONNULL_END
