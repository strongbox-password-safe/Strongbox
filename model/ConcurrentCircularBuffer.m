//
//  CircularBuffer.m
//  Strongbox
//
//  Created by Strongbox on 14/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ConcurrentCircularBuffer.h"

@interface ConcurrentCircularBuffer ()

@property NSMutableArray *data;
@property NSUInteger headIndex;
@property NSUInteger capacity;

@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

@implementation ConcurrentCircularBuffer

- (instancetype)initWithCapacity:(NSUInteger)bufferSize {
    self = [super init];
    if (self) {
        self.dataQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT);
        self.capacity = bufferSize;
        
        [self resetBuffer];
    }
    return self;
}

- (void)addObject:(id)object {
    dispatch_barrier_async(self.dataQueue, ^{ 
        if (self.headIndex < self.data.count) {
            [self.data replaceObjectAtIndex:self.headIndex withObject:object];
        }
        else {
            [self.data addObject:object];
        }
        
        self.headIndex = (self.headIndex + 1) % self.capacity;
    });
}

- (NSArray *)allObjects {
    __block NSArray* matches = nil;

    dispatch_barrier_sync(self.dataQueue, ^{
        if (self.data.count < self.capacity) {
            matches = self.data.copy;
        }
        else {
            NSArray *arrHead = [self.data objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.headIndex)]];
            NSArray *arrTail = [self.data objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.headIndex, self.capacity - self.headIndex)]];

            matches = [arrTail arrayByAddingObjectsFromArray:arrHead];
        }
    });
    
    return matches;
}

- (void)removeAllObjects {
    [self resetBuffer];
}

- (void)resetBuffer {
    dispatch_barrier_async(self.dataQueue, ^{ 
        self.data = [NSMutableArray arrayWithCapacity:self.capacity];
        self.headIndex = 0;
    });
}

@end
