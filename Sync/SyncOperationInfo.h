//
//  SyncOperationInfo.h
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, SyncOperationState) {
    kSyncOperationStateInitial,
    kSyncOperationStateInProgress,
    kSyncOperationStateBackgroundButUserInteractionRequired,
    kSyncOperationStateError,
    kSyncOperationStateDone,
};

@interface SyncOperationInfo : NSObject


@property (readonly) NSString* databaseId;
@property SyncOperationState state;
@property NSError* error;
@property dispatch_group_t inProgressDispatchGroup;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDatabaseId:(NSString*)databaseId NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
