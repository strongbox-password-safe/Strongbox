//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SafesList.h"
#import "DatabaseModel.h"
#import "AbstractDatabaseMetadata.h"
#import "DatabaseAuditor.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kAuditNodesChangedNotificationKey;
extern NSString* const kAuditProgressNotificationKey;
extern NSString* const kAuditCompletedNotificationKey;

@interface Model : NSObject

@property (nonatomic, readonly, nonnull) SafeMetaData *metadata;
@property (readonly, strong, nonatomic, nonnull) DatabaseModel *database;
@property (nonatomic, readonly) BOOL isCloudBasedStorage;
@property (nonatomic, readonly) BOOL isUsingOfflineCache;
@property (nonatomic, readonly) BOOL isReadOnly;

@property (nullable, nonatomic) NSString* openedWithYubiKeySecret; // Used for Convenience Setting if this database was opened with a Yubikey workaround

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithSafeDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                          originalDataForBackup:(NSData*_Nullable)originalDataForBackup // Can be null in case of Duress Dummy
                                       metaData:(SafeMetaData *_Nonnull)metaData
                                storageProvider:(id <SafeStorageProvider>_Nonnull)provider
                                      cacheMode:(BOOL)usingOfflineCache
                                     isReadOnly:(BOOL)isReadOnly
                                 isAutoFillOpen:(BOOL)isAutoFillOpen NS_DESIGNATED_INITIALIZER;

- (void)update:(BOOL)isAutoFill handler:(void (^)(BOOL userCancelled, NSError*_Nullable error))handler;

- (void)stopAudit;
- (void)restartBackgroundAudit;
- (void)stopAndClearAuditor;

@property (readonly) AuditState auditState;

@property (readonly) NSNumber* auditIssueCount;
@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditHibpErrorCount;

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(Node*)item;
- (BOOL)isFlaggedByAudit:(Node*)item;
- (NSString*)getQuickAuditSummaryForNode:(Node*)item;
- (NSString*)getQuickAuditVeryBriefSummaryForNode:(Node*)item;

- (void)closeAndCleanup;

// Cache Stuff

- (void)updateOfflineCacheWithData:(NSData *_Nonnull)data;

- (void)updateAutoFillCacheWithData:(NSData *_Nonnull)data;
- (void)updateAutoFillCache:(void (^_Nonnull)(void))handler;
- (void)disableAndClearAutoFill;
- (void)enableAutoFill;
     
// Operations

- (Node* _Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*_Nonnull)title;
- (BOOL)deleteOrRecycleItem:(Node *_Nonnull)child;
- (BOOL)deleteWillRecycle:(Node*_Nonnull)child;

- (BOOL)isPinned:(Node*)item;
- (void)togglePin:(Node*)item;
@property (readonly) NSSet<NSString*>* pinnedSet;

-(void)encrypt:(void (^)(BOOL userCancelled, NSData*_Nullable data, NSError*_Nullable error))completion;

- (NSString *_Nonnull)generatePassword;

- (void)updateAutoFillQuickTypeDatabase;
     
@end

NS_ASSUME_NONNULL_END
