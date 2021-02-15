//
//  NSDictionary+Extensions.m
//  Strongbox
//
//  Created by Mark on 08/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NSDictionary+Extensions.h"

@implementation NSDictionary (Extensions)

- (id)objectForCaseInsensitiveKey:(NSString *)key {
    NSArray *allKeys = [self allKeys];
    for (NSString *str in allKeys) {
        if ([key caseInsensitiveCompare:str] == NSOrderedSame) {
            return [self objectForKey:str];
        }
    }
    return nil;
}

- (NSArray *)map:(id  _Nonnull (^)(id _Nonnull, id _Nonnull))block {
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:self.count];
    
    NSArray *allKeys = [self allKeys];
    for (id key in allKeys) {
        id value = [self objectForKey:key];
        id mapped = block(key, value);
        [ret addObject:mapped];
    }
    
    return ret;
}

- (NSDictionary *)filter:(BOOL (^)(id _Nonnull, id _Nonnull))block {
    NSMutableDictionary *ret = @{}.mutableCopy;
    
    NSArray *allKeys = [self allKeys];
    for (id key in allKeys) {
        id value = [self objectForKey:key];
        BOOL go = block(key, value);
        
        if (go) {
            ret[key] = value;
        }
    }
    
    return ret.copy;
}










@end
