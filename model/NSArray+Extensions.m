//
//  NSArray+Extensions.m
//  Strongbox-iOS
//
//  Created by Mark on 03/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NSArray+Extensions.h"

@implementation NSArray (Extensions)

-(NSArray *)filter:(BOOL(^)(id _Nonnull))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    
    for(id obj in self) {
        if(block(obj)) {
            [result addObject:obj];
        }
    }
    
    return result;
}

- (NSArray *)flatMap:(NSArray* (^)(id obj, NSUInteger idx))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObjectsFromArray:block(obj, idx)];
    }];
    return [result copy];
}

- (NSArray *)map:(id (^)(id obj, NSUInteger idx))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id res = block(obj, idx);
        if ( res ) {
            [result addObject:res];
        }
    }];
    return [result copy];
}

- (BOOL)anyMatch:(BOOL (^)(id obj))block {
    return [self firstOrDefault:block] != nil;
}

- (BOOL)allMatch:(BOOL (^)(id obj))block {
    for(id obj in self) {
        if(!block(obj)) {
            return NO;
        }
    }
    
    return YES;
}

- (id)firstOrDefault:(BOOL (^)(id obj))block {
    for(id obj in self) {
        if(block(obj)) {
            return obj;
        }
    }
    
    return nil;
}


- (NSInteger)indexOfFirstMatch:(BOOL (^)(id obj))block {
    NSInteger i = 0;
    for(id obj in self) {
        if(block(obj)) {
            return i;
        }
        i++;
    }
    
    return NSNotFound;
}

- (NSSet *)set {
    return [NSSet setWithArray:self];
}

- (NSDictionary *)groupBy:(id  _Nonnull (^)(id _Nonnull))block {
    NSMutableDictionary *ret = NSMutableDictionary.dictionary;
    
    for(id obj in self) {
        id key = block(obj);
        
        NSMutableArray* group = ret[key];
        
        if (!group) {
            group = NSMutableArray.array;
            ret[key] =  group;
        }
        
        [group addObject:obj];
    }
    
    return ret.copy;
}

@end
