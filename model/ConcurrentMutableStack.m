//
//  ConcurrentMutableStack.m
//  Strongbox
//
//  Created by Strongbox on 31/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ConcurrentMutableStack.h"

@interface ConcurrentMutableStack ()

@property (strong, nonatomic) NSMutableArray *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

@implementation ConcurrentMutableStack

+ (instancetype)mutableStack {
    return [[ConcurrentMutableStack alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.data = NSMutableArray.array;
        self.dataQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)push:(id)anObject {
    dispatch_barrier_async(self.dataQueue, ^{ 
        [self.data addObject:anObject];
    });
}

- (id)pop {
    __block id topObject = nil;

    dispatch_barrier_sync(self.dataQueue, ^{
        if (self.data.count == 0) {
          return;
        }

        NSUInteger lastIndex = self.data.count - 1;
        topObject = [self.data objectAtIndex:lastIndex];
        
        if (topObject != nil) {
            [self.data removeObjectAtIndex:lastIndex];
        }
    });
    
    return topObject;
}

- (id)popAndClear {
    __block id topObject = nil;

    dispatch_barrier_sync(self.dataQueue, ^{
        if (self.data.count == 0) {
          return;
        }

        NSUInteger lastIndex = self.data.count - 1;
        topObject = [self.data objectAtIndex:lastIndex];
        

        
        [self.data removeAllObjects];
    });
    
    return topObject;
}

- (void)clear {
    dispatch_barrier_async(self.dataQueue, ^{ 
        [self.data removeAllObjects];
    });
}


@end
