//
//  Pair.m
//  Strongbox
//
//  Created by Strongbox on 15/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MMcGPair.h"

@implementation MMcGPair

+ (instancetype)pairOfA:(id)a andB:(id)b {
    return [[MMcGPair alloc] initPairOfA:a andB:b];
}

- (instancetype)initPairOfA:(id)a andB:(id)b {
    self = [super init];
    if (self) {
        _a = a;
        _b = b;
    }
    return self;
}

@end
