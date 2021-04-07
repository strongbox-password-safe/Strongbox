//
//  MacSyncManager.h
//  MacBox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "DatabaseMetadata.h"
#import "CompositeKeyFactors.h"
#import "SyncAndMergeSequenceManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacSyncManager : NSObject

+ (instancetype)sharedInstance;

- (void)sync:(DatabaseMetadata *)database interactiveVC:(NSViewController *)interactiveVC key:(CompositeKeyFactors*)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion;
- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabaseMetadata *)database data:(NSData *)data error:(NSError**)error;
- (SyncStatus*)getSyncStatus:(DatabaseMetadata *)database;

- (void)backgroundSyncAll;
- (void)backgroundSyncOutstandingUpdates;
- (void)backgroundSyncDatabase:(DatabaseMetadata*)database;
- (void)backgroundSyncDatabase:(DatabaseMetadata*)database completion:(SyncAndMergeCompletionBlock _Nullable)completion;

- (void)pollForChanges:(DatabaseMetadata*)database completion:(SyncAndMergeCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
