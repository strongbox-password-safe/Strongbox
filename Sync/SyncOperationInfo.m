//
//  SyncOperationInfo.m
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SyncOperationInfo.h"

@implementation SyncOperationInfo

- (instancetype)initWithDatabaseId:(NSString *)databaseId {
    self = [super init];
    
    if (self) {
        _databaseId = databaseId;
        self.state = kSyncOperationStateInitial;
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@%@]", @(self.state), self.error ? [NSString stringWithFormat: @" Error: [%@]", self.error.description] : @""];
}

@end
