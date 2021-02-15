//
//  NSUUID+Zero.m
//  Strongbox
//
//  Created by Mark on 20/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NSUUID+Zero.h"

@implementation NSUUID (Zero)

static NSUUID const *zeroInstance;

+ (void)initialize {
    if(self == [NSUUID class]) {
        zeroInstance = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
    }
}

+ (NSUUID*)zero {
    return (NSUUID*)zeroInstance;
}

@end
