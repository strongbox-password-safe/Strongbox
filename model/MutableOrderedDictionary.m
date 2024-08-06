//
//  BasicOrderedDictionary.m
//  StrongboxTests
//
//  Created by Mark on 24/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MutableOrderedDictionary.h"
#import "NSDictionary+Extensions.h"
#import "NSArray+Extensions.h"
#import "SBLog.h"

@interface MutableOrderedDictionary ()

@property NSMutableArray<NSString*> *orderedKeys;
@property NSMutableDictionary<NSString*, NSObject*> *kvps;

@end

@implementation MutableOrderedDictionary

- (instancetype)init {
    self = [super init];
    if (self) {
        self.orderedKeys = [NSMutableArray array];
        self.kvps = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)copy {
    return [self clone];
}

- (id)mutableCopy {
    return [self clone];
}

- (instancetype)clone {
    MutableOrderedDictionary *ret = [[MutableOrderedDictionary alloc] init];
    
    for (id key in self.allKeys) {
        id value = self.kvps[key];
        [ret addKey:key andValue:value];
    }
    
    return ret;
}

- (void)remove:(id)key {
    self[key] = nil;
}

- (id)removeObjectAtIndex:(NSUInteger)atIndex {
    if ( atIndex >= 0 && atIndex < self.orderedKeys.count ) {
        id key = self.orderedKeys[atIndex];
        id value = self.kvps[key];
        
        [self.orderedKeys removeObjectAtIndex:atIndex];
        [self.kvps removeObjectForKey:key];
        
        return value;
    }
    else {
        slog(@"⚠️ WARN attempt to remove object at non existent index");
        return nil;
    }
}

- (void)removeObjectForKey:(id)key {
    self[key] = nil;
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    [self updateOrAddKey:key andValue:obj];
}

- (void)updateOrAddKey:(id)key andValue:(id)value {
    if ( self.kvps[key] ) {
        if(value != nil) {
            [self.kvps setValue:value forKey:key];
        }
        else {
            [self.orderedKeys removeObject:key];
            [self.kvps removeObjectForKey:key];
        }
    }
    else {
        if(value != nil) {
            [self.orderedKeys addObject:key];
            [self.kvps setValue:value forKey:key];
        }
    }
}

- (void)addKey:(id)key andValue:(id)value {
    if(self.kvps[key]) {
        [self.orderedKeys removeObject:key];
        [self.kvps removeObjectForKey:key];
    }

    if(value != nil) {
        [self.orderedKeys addObject:key];
        [self.kvps setValue:value forKey:key];
    }
}

- (void)insertKey:(id)key withValue:(id)value atIndex:(NSUInteger)atIndex {
    if ( self.kvps[key] ) {
        slog(@"🔴 insertKey - Key already exists");
        return;
    }

    if ( value != nil ) {
        [self.orderedKeys insertObject:key atIndex:atIndex];
        [self.kvps setValue:value forKey:key];
    }
}

- (NSArray<id>*)keys {
    return self.allKeys;
}

- (NSArray<id>*)allKeys {
    return [self.orderedKeys copy];
}

- (NSArray<id>*)allValues {
    return [self.allKeys map:^id _Nonnull(id  _Nonnull obj, NSUInteger idx) {
        return self.kvps[obj];
    }];
}

- (id)objectForKey:(id)key {
    return [self.kvps objectForKey:key];
}

- (id)objectForCaseInsensitiveKey:(id)key {
    return [self.kvps objectForCaseInsensitiveKey:key];
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

- (void)removeAllObjects {
    [self.orderedKeys removeAllObjects];
    [self.kvps removeAllObjects];
}

- (BOOL)containsKey:(id)key {
    return [self.kvps objectForKey:key] != nil;
}

- (NSUInteger)count {
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
    
    BOOL ret = [self.kvps isEqualToDictionary:other.kvps];
    
    if ( ret ) {
        return YES;
    }
    
    return NO;
}

@end
