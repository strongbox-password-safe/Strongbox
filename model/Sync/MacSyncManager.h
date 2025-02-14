//
//  MacSyncManager.h
//  MacBox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "MacDatabasePreferences.h"
#import "CompositeKeyFactors.h"
#import "SyncAndMergeSequenceManager.h"
#import "SyncManagement.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacSyncManager : NSObject<SyncManagement>

+ (instancetype)sharedInstance;

- (void)sync:(MacDatabasePreferences *)database
interactiveVC:(NSViewController *_Nullable)interactiveVC
         key:(CompositeKeyFactors*)key
        join:(BOOL)join
  completion:(SyncAndMergeCompletionBlock)completion;

- (BOOL)updateLocalCopyMarkAsRequiringSync:(MacDatabasePreferences *)database data:(NSData *)data error:(NSError**)error;

- (SyncStatus*)getSyncStatus:(MacDatabasePreferences *)database;

- (void)backgroundSyncAll;
- (void)backgroundSyncOutstandingUpdates;
- (void)backgroundSyncDatabase:(MacDatabasePreferences*)database key:(CompositeKeyFactors * _Nullable)key completion:(SyncAndMergeCompletionBlock _Nullable)completion;

- (void)pollForChanges:(MacDatabasePreferences*)database completion:(SyncAndMergeCompletionBlock)completion;

@property (readonly) BOOL syncInProgress;
- (BOOL)syncInProgressForDatabase:(NSString*)databaseId;

@end

NS_ASSUME_NONNULL_END
