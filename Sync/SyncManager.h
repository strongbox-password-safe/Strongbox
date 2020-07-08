//
//  SyncManager.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LegacySyncReadOptions.h"
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

//typedef void (^SyncManagerReadCompletionBlock)(NSURL*_Nullable localCopyUrl, NSError*_Nullable error);

typedef void (^SyncManagerReadLegacyCompletionBlock)(NSURL*_Nullable url, const NSError*_Nullable error);
typedef void (^SyncManagerUpdateLegacyCompletionBlock)(const NSError*_Nullable error);

@interface SyncManager : NSObject

+ (instancetype _Nullable)sharedInstance;

- (void)update:(SafeMetaData*)database data:(NSData*)data;
- (void)updateLegacy:(SafeMetaData*)database data:(NSData*)data legacyOptions:(LegacySyncReadOptions*)legacyOptions completion:(SyncManagerUpdateLegacyCompletionBlock)completion;

- (NSString*)getPrimaryStorageDisplayName:(SafeMetaData*)database;
- (void)removeDatabaseAndLocalCopies:(SafeMetaData*)database;

- (void)startMonitoringDocumentsDirectory;
- (BOOL)toggleLocalDatabaseFilesVisibility:(SafeMetaData*)metadata error:(NSError**)error;

// Legacy - Remove eventually

- (BOOL)isLegacyAutoFillBookmarkSet:(SafeMetaData*)database;
- (void)setLegacyAutoFillBookmark:(SafeMetaData*)database bookmark:(NSData*)bookmark;

- (void)readLegacy:(SafeMetaData*)database
     legacyOptions:(LegacySyncReadOptions*)legacyOptions
        completion:(SyncManagerReadLegacyCompletionBlock)completion;

- (BOOL)isLegacyImmediatelyOfferCacheIfOffline:(SafeMetaData*)database;

- (BOOL)isLocalWorkingCacheAvailable:(SafeMetaData*)database modified:(NSDate*_Nullable*_Nullable)modified;
- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database;
- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate *_Nullable*_Nullable)modified;

@end

NS_ASSUME_NONNULL_END
