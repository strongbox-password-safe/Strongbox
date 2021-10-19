//
//  ConcurrentMutableDictionary.m
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ConcurrentMutableDictionary.h"

@interface ConcurrentMutableDictionary ()

@property (strong, nonatomic) NSMutableDictionary *data;
@property (strong, nonatomic) dispatch_queue_t dataQueue;

@end

@implementation ConcurrentMutableDictionary

+ (instancetype)mutableDictionary {
    return [[ConcurrentMutableDictionary alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.data = NSMutableDictionary.dictionary;
        self.dataQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)setObject:(id)object forKey:(nonnull id<NSCopying>)forKey {
    dispatch_barrier_async(self.dataQueue, ^{ 
        [self.data setObject:object forKey:forKey];
    });
}

- (void)removeObjectForKey:(nonnull id<NSCopying>)forKey {
    dispatch_barrier_async(self.dataQueue, ^{ 
        [self.data removeObjectForKey:forKey];
    });
}

- (id)objectForKey:(id)key {
    __block id result;

    dispatch_sync(self.dataQueue, ^{  
        result = [self.data objectForKey:key];
    });
    
    return result;
}

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    [self setObject:obj forKey:key];
}

- (void)removeAllObjects {
    dispatch_barrier_async(self.dataQueue, ^{ 
        [self.data removeAllObjects];
    });
}

@end
