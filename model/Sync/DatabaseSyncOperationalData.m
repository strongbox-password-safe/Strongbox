//
//  DatabaseSyncOperationalData.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseSyncOperationalData.h"
#import "ConcurrentMutableArray.h"

@interface DatabaseSyncOperationalData ()

@property ConcurrentMutableArray<SyncDatabaseRequest*>* requestQueue;

@end

@implementation DatabaseSyncOperationalData

- (instancetype)initWithDatabaseId:(NSString *)databaseUuid {
    self = [super init];
    
    if (self) {
        self.requestQueue = ConcurrentMutableArray.mutableArray;
        
        const char* queuename = [databaseUuid cStringUsingEncoding:NSASCIIStringEncoding];
        
        _dispatchSerialQueue = dispatch_queue_create(queuename ? queuename : "database-sync-queue", DISPATCH_QUEUE_SERIAL);
        _status = [[SyncStatus alloc] initWithDatabaseId:databaseUuid];
    }
    
    return self;
}

- (void)enqueueSyncRequest:(SyncDatabaseRequest *)request {
    [self.requestQueue addObject:request];
}

- (SyncDatabaseRequest*)dequeueSyncRequest {
    return [self.requestQueue dequeueHead];
}

- (NSArray*)dequeueAllJoinRequests {
    return [self.requestQueue dequeueAllMatching:^BOOL(SyncDatabaseRequest * _Nonnull obj) {
        return obj.parameters.inProgressBehaviour == kInProgressBehaviourJoin;
    }];
}

@end
