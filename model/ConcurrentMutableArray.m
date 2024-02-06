//
//  ConcurrentMutableArray.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ConcurrentMutableArray.h"
#import "NSArray+Extensions.h"

@interface ConcurrentMutableArray ()

@property (strong, nonatomic) NSMutableArray *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

@implementation ConcurrentMutableArray

+ (instancetype)mutableArray {
    return [[ConcurrentMutableArray alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.data = NSMutableArray.array;
        self.dataQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)addObject:(id)object {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data addObject:object];
    });
}

- (void)addObjectsFromArray:(NSArray *)otherArray {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data addObjectsFromArray:otherArray];
    });
}

- (void)removeObject:(id)object {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data removeObject:object];
    });
}

- (void)removeAllObjects {
    dispatch_barrier_async(self.dataQueue, ^{
        [self.data removeAllObjects];
    });
}


- (id)dequeueHead {
    __block id headObject = nil;

    dispatch_barrier_sync(self.dataQueue, ^{
        if (self.data.count == 0) {
          return;
        }
        
        headObject = [self.data objectAtIndex:0];
        
        if (headObject != nil) {
            [self.data removeObjectAtIndex:0];
        }
    });
    
    return headObject;
}

- (id)dequeueAllMatching:(BOOL (^)(id obj))block {
    __block NSArray* matches = nil;

    dispatch_barrier_sync(self.dataQueue, ^{
        matches = [self.data filter:block];
        [self.data removeObjectsInArray:matches];
    });
    
    return matches;
}

- (NSArray *)snapshot {
    __block NSArray *result;
    
    dispatch_sync(self.dataQueue, ^{
        result = self.data.copy;
    });
    
    return result;
}

@end
