//
//  HeaderNodeState.m
//  MacBox
//
//  Created by Strongbox on 17/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "HeaderNodeState.h"

@interface HeaderNodeState () <NSCoding>

@end

@implementation HeaderNodeState

+ (instancetype)withHeader:(HeaderNode)header expanded:(BOOL)expanded {
    return [[HeaderNodeState alloc] initWithHeader:header expanded:expanded];
}

- (instancetype)initWithHeader:(HeaderNode)header expanded:(BOOL)expanded {
    self = [super init];
    if (self) {
        self.header = header;
        self.expanded = expanded;
    }
    return self;
}

+ (NSArray<HeaderNodeState *> *)defaults {
    return @[   [HeaderNodeState withHeader:kHeaderNodeFavourites expanded:YES],
                [HeaderNodeState withHeader:kHeaderNodeSpecial expanded:YES],
                [HeaderNodeState withHeader:kHeaderNodeTags expanded:YES],
                [HeaderNodeState withHeader:kHeaderNodeRegularHierarchy expanded:YES],
                [HeaderNodeState withHeader:kHeaderNodeAuditIssues expanded:YES]];
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeInteger:self.header forKey:@"header"];
    [coder encodeBool:self.expanded forKey:@"expanded"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    if (self = [super init]) {
        self.header = [coder decodeIntegerForKey:@"header"];
        self.expanded = [coder decodeBoolForKey:@"expanded"];
    }
    
    return self;
}

@end
