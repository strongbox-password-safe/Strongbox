//
//  SyncAndMergeSequenceManager.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncParameters.h"
#import "SafeMetaData.h"
#import "SyncStatus.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, SyncAndMergeResult) {
    kSyncAndMergeResultUserCancelled,
    kSyncAndMergeResultUserInteractionRequired,
    kSyncAndMergeError,
    kSyncAndMergeSuccess,
};

typedef void (^SyncAndMergeCompletionBlock)(SyncAndMergeResult result, BOOL conflictAndLocalWasChanged, const NSError*_Nullable error);

@interface SyncAndMergeSequenceManager : NSObject

+ (instancetype _Nullable)sharedInstance;

- (SyncStatus*)getSyncStatus:(SafeMetaData*)database;

- (void)enqueueSync:(SafeMetaData*)database parameters:(SyncParameters*)parameters completion:(SyncAndMergeCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
