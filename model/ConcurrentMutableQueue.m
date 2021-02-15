//
//  ConcurrentMutableQueue.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ConcurrentMutableQueue.h"

@interface ConcurrentMutableQueue ()

@property (strong, nonatomic) NSMutableArray *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

@implementation ConcurrentMutableQueue

+ (instancetype)mutableQueue {
    return [[ConcurrentMutableQueue alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.data = NSMutableArray.array;
        self.dataQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (id)dequeue {
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

- (void)enqueue:(id)anObject {
    dispatch_barrier_async(self.dataQueue, ^{ 
        [self.data addObject:anObject];
    });
}

@end
