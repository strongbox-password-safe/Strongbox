//
//  SyncAndMergeSequenceManager.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncParameters.h"
#import "SyncStatus.h"

#if TARGET_OS_IPHONE
//    #import <UIKit/UIKit.h>
    #import "SafeMetaData.h"
//    typedef UIViewController* VIEW_CONTROLLER_PTR;

    typedef SafeMetaData* METADATA_PTR;
#else

    #import "DatabaseMetadata.h"


    typedef DatabaseMetadata* METADATA_PTR;
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, SyncAndMergeResult) {
    kSyncAndMergeResultUserCancelled,
    kSyncAndMergeResultUserInteractionRequired,
    kSyncAndMergeError,
    kSyncAndMergeUserPostponedSync,
    kSyncAndMergeSuccess,
};

typedef void (^SyncAndMergeCompletionBlock)(SyncAndMergeResult result, BOOL localWasChanged, NSError*_Nullable error);

NSString* syncResultToString(SyncAndMergeResult result);

@interface SyncAndMergeSequenceManager : NSObject

+ (instancetype _Nullable)sharedInstance;

- (SyncStatus*)getSyncStatus:(METADATA_PTR)database;

- (void)enqueueSync:(METADATA_PTR)database parameters:(SyncParameters*)parameters completion:(SyncAndMergeCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
