//
//  PasswordSafeDocument.m
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PasswordSafeDocument.h"

@implementation PasswordSafeDocument

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.format = kPasswordSafe;
    }
    return self;
}

@end
