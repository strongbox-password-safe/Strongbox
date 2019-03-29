//
//  NodeFileAttachment.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "NodeFileAttachment.h"

@implementation NodeFileAttachment

+ (instancetype)attachmentWithName:(NSString *)filename index:(uint32_t)index linkedObject:(NSObject *)linkedObject {
    NodeFileAttachment* ret = [[NodeFileAttachment alloc] init];
    
    ret.filename = filename;
    ret.index = index;
    ret.linkedObject = linkedObject;
    
    return ret;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@] index: %d", self.filename, self.index];
}

@end
