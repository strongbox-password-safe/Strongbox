//
//  ConflictResolutionStrategy.h
//  Strongbox
//
//  Created by Strongbox on 05/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef ConflictResolutionStrategy_h
#define ConflictResolutionStrategy_h

typedef NS_ENUM (NSUInteger, ConflictResolutionStrategy) {
    kConflictResolutionStrategyAsk,
    kConflictResolutionStrategyAutoMerge,
    kConflictResolutionStrategyForcePushLocal,
    kConflictResolutionStrategyForcePullRemote,
};

#endif /* ConflictResolutionStrategy_h */
