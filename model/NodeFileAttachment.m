//
//  NodeFileAttachment.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "NodeFileAttachment.h"

@implementation NodeFileAttachment

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@] index: %d", self.filename, self.index];
}

@end
