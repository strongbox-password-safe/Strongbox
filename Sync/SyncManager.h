//
//  SyncManager.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncReadOptions.h"
#import "SafeMetaData.h"
#import "SyncOperationInfo.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kSyncManagerDatabaseSyncStatusChanged;

typedef void (^SyncManagerReadCompletionBlock)(NSURL*_Nullable url, BOOL previousSyncAlreadyInProgress, const NSError*_Nullable error);
typedef void (^SyncManagerUpdateCompletionBlock)(const NSError*_Nullable error);

@interface SyncManager : NSObject

+ (instancetype _Nullable)sharedInstance;

/////////////

- (SyncOperationInfo*)getSyncStatus:(SafeMetaData*)database;

- (void)backgroundSyncAll;
- (void)backgroundSyncLocalDeviceDatabasesOnly;

// TODO: These should be merged so there is only one "sync" method which syncs local & remote

- (void)queuePullFromRemote:(SafeMetaData*)database
                         readOptions:(SyncReadOptions*)readOptions
                          completion:(SyncManagerReadCompletionBlock)completion;

- (void)syncFromLocalAndOverwriteRemote:(SafeMetaData*)database
                                   data:(NSData*)data
                          updateOptions:(SyncReadOptions*)updateOptions
                             completion:(SyncManagerUpdateCompletionBlock)completion; // TODO: Sync Read Options probabaly should just be called SyncOptions and read/update should just be sync?

///////////////////

- (NSString*)getPrimaryStorageDisplayName:(SafeMetaData*)database;
- (void)removeDatabaseAndLocalCopies:(SafeMetaData*)database;

- (void)startMonitoringDocumentsDirectory;
- (BOOL)toggleLocalDatabaseFilesVisibility:(SafeMetaData*)metadata error:(NSError**)error;

// Legacy - Remove eventually

- (BOOL)isLegacyAutoFillBookmarkSet:(SafeMetaData*)database;
- (void)setLegacyAutoFillBookmark:(SafeMetaData*)database bookmark:(NSData*)bookmark;

- (BOOL)isLegacyImmediatelyOfferCacheIfOffline:(SafeMetaData*)database;

- (BOOL)isLocalWorkingCacheAvailable:(SafeMetaData*)database modified:(NSDate*_Nullable*_Nullable)modified;
- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database;
- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate *_Nullable*_Nullable)modified;
- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate *_Nullable*_Nullable)modified fileSize:(unsigned long long*_Nullable)fileSize;

// Used to set the initial cache when DB is newly added...
- (NSURL*_Nullable)setWorkingCacheWithData:(NSData*)data dateModified:(NSDate*)dateModified database:(SafeMetaData*)database error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
