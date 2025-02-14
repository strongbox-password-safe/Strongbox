//
//  SyncOperationState.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef SyncOperationState_h
#define SyncOperationState_h

typedef NS_ENUM (NSUInteger, SyncOperationState) {
    kSyncOperationStateInitial,
    kSyncOperationStateInProgress,
    kSyncOperationStateUserCancelled,
    kSyncOperationStateBackgroundButUserInteractionRequired,
    kSyncOperationStateError,
    kSyncOperationStateDone,
};

NSString* syncOperationStateToString(SyncOperationState state);

#endif /* SyncOperationState_h */
