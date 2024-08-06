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

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kSyncManagerDatabaseSyncStatusChangedNotification;

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

- (SyncStatus*)getSyncStatusForDatabaseId:(NSString*)databaseUuid;

- (void)enqueueSyncForDatabaseId:(NSString*)databaseUuid
                      parameters:(SyncParameters*)parameters
                      completion:(SyncAndMergeCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
