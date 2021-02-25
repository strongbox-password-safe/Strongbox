//
//  SyncManager.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncParameters.h"
#import "SafeMetaData.h"
#import "SyncStatus.h"
#import "SyncAndMergeSequenceManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncManager : NSObject

+ (instancetype _Nullable)sharedInstance;

- (SyncStatus*)getSyncStatus:(SafeMetaData*)database;

- (void)backgroundSyncAll;
- (void)backgroundSyncOutstandingUpdates;
- (void)backgroundSyncLocalDeviceDatabasesOnly;

- (void)sync:(SafeMetaData *)database interactiveVC:(UIViewController *)interactiveVC key:(CompositeKeyFactors*)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion;

- (BOOL)updateLocalCopyMarkAsRequiringSync:(SafeMetaData *)database data:(NSData *)data error:(NSError**)error;



- (NSString*)getPrimaryStorageDisplayName:(SafeMetaData*)database;
- (void)removeDatabaseAndLocalCopies:(SafeMetaData*)database;

- (void)startMonitoringDocumentsDirectory;

#ifndef IS_APP_EXTENSION
- (BOOL)toggleLocalDatabaseFilesVisibility:(SafeMetaData*)metadata error:(NSError**)error;
#endif

@end

NS_ASSUME_NONNULL_END
