//
//  SyncDiffReport.m
//  Strongbox
//
//  Created by Strongbox on 20/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SyncDiffReport.h"

@implementation SyncDiffReport

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.theirNewEntries = [NSSet set];
        self.theirNewGroups = [NSSet set];
        self.theirEditedEntries = [NSSet set];
        self.theirEditedGroups = [NSSet set];
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"theirNewGroups = [%@], theirNewEntries = [%@], theirEditedGroups = [%@], theirEditedEntries = [%@]", self.theirNewGroups, self.theirNewEntries, self.theirEditedGroups, self.theirEditedEntries];
}

@end
