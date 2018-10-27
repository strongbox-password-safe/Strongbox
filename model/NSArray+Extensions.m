//
//  NSArray+Extensions.m
//  Strongbox-iOS
//
//  Created by Mark on 03/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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

- (NSArray *)map:(id (^)(id obj, NSUInteger idx))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObject:block(obj, idx)];
    }];
    return [result copy];
}

- (id)firstOrDefault:(BOOL (^)(id obj))block {
    for(id obj in self) {
        if(block(obj)) {
            return obj;
        }
    }
    
    return nil;
}

@end
