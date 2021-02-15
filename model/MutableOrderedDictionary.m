//
//  BasicOrderedDictionary.m
//  StrongboxTests
//
//  Created by Mark on 24/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MutableOrderedDictionary.h"

@interface MutableOrderedDictionary ()

@property NSMutableArray<NSString*> *keys;
@property NSMutableDictionary<NSString*, NSObject*> *kvps;

@end

@implementation MutableOrderedDictionary

- (instancetype)init {
    self = [super init];
    if (self) {
        self.keys = [NSMutableArray array];
        self.kvps = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)remove:(id)key {
    self[key] = nil;
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    [self addKey:key andValue:obj];
}

- (void)addKey:(id)key andValue:(id)value {
    if(self.kvps[key]) {
        [self.keys removeObject:key];
        [self.kvps removeObjectForKey:key];
    }

    if(value != nil) {
        [self.keys addObject:key];
        [self.kvps setValue:value forKey:key];
    }
}

- (void)insertKey:(id)key withValue:(id)value atIndex:(NSUInteger)atIndex {
    if(self.kvps[key]) {
        return;
    }

    if(value != nil) {
        [self.keys insertObject:key atIndex:atIndex];
        [self.kvps setValue:value forKey:key];
    }
}

- (NSArray<id>*)allKeys {
    return [self.keys copy];
}

- (id)objectForKeyedSubscript:(id)key {
    return [self.kvps objectForKey:key];
}

- (void)addAll:(MutableOrderedDictionary *)other {
    if (other) {
        for (id key in other.allKeys) {
            self[key] = other[key];
        }
    }
}

- (BOOL)containsKey:(id)key {
    return [self.kvps objectForKey:key] != nil;
}

-(NSUInteger)count {
    return [self.kvps count];
}

- (NSDictionary *)dictionary {
    return self.kvps.copy;
}

- (NSString *)description {
    return [_kvps description];
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[MutableOrderedDictionary class]]) {
        return NO;
    }
    
    MutableOrderedDictionary* other = (MutableOrderedDictionary*)object;
    
    if(![self.allKeys isEqualToArray:other.allKeys]) {
        return NO;
    }
    
    return [self.kvps isEqualToDictionary:other.kvps];
}

@end
