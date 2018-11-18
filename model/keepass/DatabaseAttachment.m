//
//  Attachment.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabaseAttachment.h"

@implementation DatabaseAttachment

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.compressed = YES;
        self.protectedInMemory = YES;
        self.data = [NSData data];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Compressed: %d, Protected: %d, Size: %lu", self.compressed, self.protectedInMemory, (unsigned long)self.data.length];
}

@end
