//
//  DatabaseSyncOperationalData.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncStatus.h"
#import "SyncDatabaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseSyncOperationalData : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDatabaseId:(NSString*)databaseUuid NS_DESIGNATED_INITIALIZER;

@property (readonly) SyncStatus* status;
@property (readonly) dispatch_queue_t dispatchSerialQueue;

- (void)enqueueSyncRequest:(SyncDatabaseRequest*)request;
- (SyncDatabaseRequest*_Nullable)dequeueSyncRequest;
- (NSArray*)dequeueAllJoinRequests;

@end

NS_ASSUME_NONNULL_END
