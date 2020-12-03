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

@property (nullable) UIViewController* interactiveVC; 
@property SyncInProgressBehaviour inProgressBehaviour; 

@end

NS_ASSUME_NONNULL_END
