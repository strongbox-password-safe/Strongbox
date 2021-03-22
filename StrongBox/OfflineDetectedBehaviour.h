//
//  OfflineDetectedBehaviour.h
//  Strongbox
//
//  Created by Strongbox on 16/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef OfflineDetectedBehaviour_h
#define OfflineDetectedBehaviour_h

typedef NS_ENUM (NSInteger, OfflineDetectedBehaviour) {
    kOfflineDetectedBehaviourAsk,
    kOfflineDetectedBehaviourTryConnectThenAsk,
    kOfflineDetectedBehaviourImmediateOffline
};

#endif /* OfflineDetectedBehaviour_h */
