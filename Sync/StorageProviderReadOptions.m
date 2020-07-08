//
//  StorageProviderReadOptions.m
//  Strongbox
//
//  Created by Strongbox on 04/07/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "StorageProviderReadOptions.h"

@implementation StorageProviderReadOptions

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.interactiveAllowed = YES;
        self.isAutoFill = NO;
        self.onlyIfModifiedDifferentFrom = nil;
    }
    return self;
}

@end
