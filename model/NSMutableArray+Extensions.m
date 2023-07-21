//
//  NSMutableArray_Extensions.m
//  Strongbox
//
//  Created by Mark on 17/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NSMutableArray+Extensions.h"

@implementation NSMutableArray (Extensions)

- (void)mutableFilter:(BOOL (^)(id _Nonnull))block {
    NSIndexSet* indices = [self indexesOfObjectsWithOptions:NSEnumerationConcurrent
                                                passingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return !block(obj);
    }];
    
    [self removeObjectsAtIndexes:indices];
}

@end
