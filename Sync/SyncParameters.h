//
//  LegacySyncReadOptions.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, SyncInProgressBehaviour) {
    kInProgressBehaviourEnqueueAnotherSync,
    kInProgressBehaviourJoin,
};
    
@interface SyncParameters : NSObject

@property BOOL isAutoFill; // TODO: Should be able to get rid of this once Auto-Fill moves to local only

@property (nullable) UIViewController* interactiveVC; // If null -> This is a background sync
@property SyncInProgressBehaviour inProgressBehaviour; // What to do if sync is already in progress

@end

NS_ASSUME_NONNULL_END
