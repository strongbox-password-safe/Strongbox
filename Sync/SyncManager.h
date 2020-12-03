//
//  SyncManager.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncParameters.h"
#import "SafeMetaData.h"
#import "SyncStatus.h"
#import "SyncAndMergeSequenceManager.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kSyncManagerDatabaseSyncStatusChanged;

@interface SyncManager : NSObject

+ (instancetype _Nullable)sharedInstance;

- (SyncStatus*)getSyncStatus:(SafeMetaData*)database;

- (void)backgroundSyncAll;
- (void)backgroundSyncOutstandingUpdates;
- (void)backgroundSyncLocalDeviceDatabasesOnly;
- (void)sync:(SafeMetaData*)database interactiveVC:(UIViewController*)interactiveVC join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion;
- (BOOL)updateLocalCopyMarkAsRequiringSync:(SafeMetaData *)database data:(NSData *)data error:(NSError**)error;



- (NSString*)getPrimaryStorageDisplayName:(SafeMetaData*)database;
- (void)removeDatabaseAndLocalCopies:(SafeMetaData*)database;

- (void)startMonitoringDocumentsDirectory;

#ifndef IS_APP_EXTENSION
- (BOOL)toggleLocalDatabaseFilesVisibility:(SafeMetaData*)metadata error:(NSError**)error;
#endif

- (BOOL)isLegacyImmediatelyOfferLocalCopyIfOffline:(SafeMetaData*)database;

- (BOOL)isLocalWorkingCacheAvailable:(SafeMetaData*)database modified:(NSDate*_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache:(SafeMetaData*)database;
- (NSURL*_Nullable)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate *_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate *_Nullable*_Nullable)modified fileSize:(unsigned long long*_Nullable)fileSize;


- (NSURL*_Nullable)setWorkingCacheWithData:(NSData*)data dateModified:(NSDate*)dateModified database:(SafeMetaData*)database error:(NSError**)error;

- (NSURL*)getLocalWorkingCacheUrlForDatabase:(SafeMetaData*)database;

@end

NS_ASSUME_NONNULL_END
