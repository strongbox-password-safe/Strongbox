//
//  SyncParameters.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    typedef UIViewController* VIEW_CONTROLLER_PTR;
#else
#import <Cocoa/Cocoa.h>
    typedef NSViewController* VIEW_CONTROLLER_PTR;
    #import <Cocoa/Cocoa.h>
#endif

#import "CompositeKeyFactors.h"


NS_ASSUME_NONNULL_BEGIN
 
typedef NS_ENUM (NSUInteger, SyncInProgressBehaviour) {
    kInProgressBehaviourEnqueueAnotherSync,
    kInProgressBehaviourJoin,
};
    
@interface SyncParameters : NSObject

@property (nullable) VIEW_CONTROLLER_PTR interactiveVC; 
@property (nullable) CompositeKeyFactors* key; 
@property SyncInProgressBehaviour inProgressBehaviour; 
@property BOOL syncPullEvenIfModifiedDateSame; 
@property BOOL syncForcePushDoNotCheckForConflicts; 
@property BOOL testForRemoteChangesOnly; 

@end

NS_ASSUME_NONNULL_END
