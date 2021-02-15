//
//  NodeAndIndex.m
//  MacBox
//
//  Created by Strongbox on 22/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NodeHierarchyReconstructionData.h"

@implementation NodeHierarchyReconstructionData

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@] - %lu", self.clonedNode.debugDescription, (unsigned long)self.index];
}

@end
