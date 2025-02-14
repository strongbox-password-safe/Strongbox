//
//  SyncOperationState.m
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncOperationState.h"

NSString* syncOperationStateToString(SyncOperationState state) {
    switch(state) {
        case kSyncOperationStateInProgress:
            return NSLocalizedString(@"generic_in_progress", @"In Progress");
            break;
        case kSyncOperationStateUserCancelled:
            return NSLocalizedString(@"sync_status_user_interaction_cancelled", @"User Cancelled");
            break;
        case kSyncOperationStateBackgroundButUserInteractionRequired:
            return NSLocalizedString(@"sync_status_user_interaction_required_title", @"User Interaction Required");
            break;
        case kSyncOperationStateError:
            return NSLocalizedString(@"generic_error", @"Error");
            break;
        case kSyncOperationStateInitial:
            return NSLocalizedString(@"generic_initial_state", @"Initial");
            break;
        case kSyncOperationStateDone:
            return NSLocalizedString(@"generic_done", @"Done");
            break;
        default:
            break;
    }
}
