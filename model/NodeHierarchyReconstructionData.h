//
//  NodeAndIndex.h
//  MacBox
//
//  Created by Strongbox on 22/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface NodeHierarchyReconstructionData : NSObject

@property NSUInteger index;
@property Node* clonedNode;

@end

NS_ASSUME_NONNULL_END
