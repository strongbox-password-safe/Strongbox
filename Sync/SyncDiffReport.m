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
        self.changes = @[];
    }
    
    return self;
}

@end
