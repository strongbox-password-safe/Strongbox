//
//  SyncManager.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncParameters.h"
#import "DatabasePreferences.h"
#import "SyncStatus.h"
#import "SyncManagement.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncManager : NSObject<SyncManagement>

+ (instancetype)sharedInstance;

- (SyncStatus*)getSyncStatus:(DatabasePreferences*)database;

- (void)backgroundSyncDatabase:(DatabasePreferences*)database join:(BOOL)join key:(CompositeKeyFactors*_Nullable)key completion:(SyncAndMergeCompletionBlock)completion;
- (void)backgroundSyncAll;

- (void)backgroundSyncOutstandingUpdates;
- (void)backgroundSyncLocalDeviceDatabasesOnly;

- (void)sync:(DatabasePreferences *)database interactiveVC:(UIViewController *_Nullable)interactiveVC key:(CompositeKeyFactors*)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion;

- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabasePreferences *)database data:(NSData *)data error:(NSError**)error;
- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabasePreferences *)database file:(NSString *)file error:(NSError**)error;



- (NSString*)getPrimaryStorageDisplayName:(DatabasePreferences*)database;

- (void)startMonitoringDocumentsDirectory;
- (void)startMonitoringWorkingCacheDirectory;

#ifndef IS_APP_EXTENSION
- (BOOL)toggleLocalDatabaseFilesVisibility:(DatabasePreferences*)metadata error:(NSError**)error;
#endif

- (BOOL)syncInProgressForDatabase:(NSString*)databaseId;

@end

NS_ASSUME_NONNULL_END
