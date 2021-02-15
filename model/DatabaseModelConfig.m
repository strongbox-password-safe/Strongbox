//
//  DatabaseModelConfig.m
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseModelConfig.h"

@implementation DatabaseModelConfig

+ (instancetype)defaults {
    return [DatabaseModelConfig withSanityCheckInnerStream:YES];
}

+ (instancetype)withSanityCheckInnerStream:(BOOL)sanityCheckInnerStream {
    DatabaseModelConfig* config = [[DatabaseModelConfig alloc] initWithSanityCheckInnerStream:sanityCheckInnerStream];
        
    return config;
}

- (instancetype)initWithSanityCheckInnerStream:(BOOL)sanityCheckInnerStream {
    self = [super init];
    if (self) {
        _sanityCheckInnerStream = sanityCheckInnerStream;
    }
    return self;
}

@end
