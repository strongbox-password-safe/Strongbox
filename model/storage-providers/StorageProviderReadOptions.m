//
//  StorageProviderReadOptions.m
//  Strongbox
//
//  Created by Strongbox on 04/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StorageProviderReadOptions.h"

@implementation StorageProviderReadOptions

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.onlyIfModifiedDifferentFrom = nil;
    }
    return self;
}

@end
