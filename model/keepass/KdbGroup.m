//
//  KdbGroup.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KdbGroup.h"

@implementation KdbGroup

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.groupId = 0;
        self.name = @"<Untitled>";
        self.creation = [NSDate date];
        self.modification = [NSDate date];
        self.lastAccess = [NSDate date];
        self.imageId = @(48); 
        self.level = 0;
        self.flags = 0;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"id=%u, name=%@, level=%d, flags=%d", self.groupId, self.name, self.level, self.flags];
}
@end
