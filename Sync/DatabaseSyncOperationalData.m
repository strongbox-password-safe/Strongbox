//
//  DatabaseSyncOperationalData.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseSyncOperationalData.h"
#import "ConcurrentMutableArray.h"

@interface DatabaseSyncOperationalData ()

@property ConcurrentMutableArray<SyncDatabaseRequest*>* requestQueue;

@property SafeMetaData* database;

@end

@implementation DatabaseSyncOperationalData

- (instancetype)initWithDatabase:(SafeMetaData*)database  {
    self = [super init];
    
    if (self) {
        self.requestQueue = ConcurrentMutableArray.mutableArray;
        
        const char* queuename = [database.nickName cStringUsingEncoding:NSASCIIStringEncoding];
        
        _dispatchSerialQueue = dispatch_queue_create(queuename ? queuename : "database-sync-queue", DISPATCH_QUEUE_SERIAL);
        _status = [[SyncStatus alloc] initWithDatabaseId:database.uuid];
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
