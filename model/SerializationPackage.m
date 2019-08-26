//
//  SerializationPackage.m
//  Strongbox
//
//  Created by Mark on 25/08/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SerializationPackage.h"

@implementation SerializationPackage

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.usedAttachmentIndices = [NSMutableSet set];
        self.usedCustomIcons = [NSMutableSet set];
    }
    return self;
}

@end
