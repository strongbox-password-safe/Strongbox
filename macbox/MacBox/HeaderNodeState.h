//
//  HeaderNodeState.h
//  MacBox
//
//  Created by Strongbox on 17/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum HeaderNode : NSInteger{
    kHeaderNodeFavourites,
    kHeaderNodeRegularHierarchy,
    kHeaderNodeTags,
    kHeaderNodeAuditIssues,
    kHeaderNodeSpecial,
} HeaderNode;

@interface HeaderNodeState : NSObject

+ (instancetype)withHeader:(HeaderNode)header expanded:(BOOL)expanded;
- (instancetype)initWithHeader:(HeaderNode)header expanded:(BOOL)expanded;

@property (readonly, class) NSArray<HeaderNodeState*>* defaults;
@property BOOL expanded;
@property HeaderNode header;

@end

NS_ASSUME_NONNULL_END
