//
//  BasicOrderedDictionary.m
//  StrongboxTests
//
//  Created by Mark on 24/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BasicOrderedDictionary.h"

@interface BasicOrderedDictionary ()

@property NSMutableArray<NSString*> *keys;
@property NSMutableDictionary<NSString*, NSObject*> *kvps;

@end

@implementation BasicOrderedDictionary

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.keys = [NSMutableArray array];
        self.kvps = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addKey:(id)key andValue:(id)value {
    if(self.kvps[key]) {
        [self.keys removeObject:key];
    }

    [self.keys addObject:key];
    [self.kvps setValue:value forKey:key];
}

- (NSArray<id>*) allKeys {
    return [self.keys copy];
}

- (nullable id)objectForKey:(id)key {
    return [self.kvps objectForKey:key];
}

-(NSUInteger)count {
    return [self.kvps count];
}

- (NSString *)description {
    return [_kvps description];
}

@end
