//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafesList.h"
#import "DatabaseModel.h"
#import "DatabaseAuditor.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kAuditNodesChangedNotificationKey;
extern NSString* const kAuditProgressNotificationKey;
extern NSString* const kAuditCompletedNotificationKey;
extern NSString* const kProStatusChangedNotificationKey;
extern NSString* const kAppStoreSaleNotificationKey; 
extern NSString* const kCentralUpdateOtpUiNotification;
extern NSString* const kMasterDetailViewCloseNotification;
extern NSString* const kDatabaseViewPreferencesChangedNotificationKey;
extern NSString *const kWormholeAutoFillUpdateMessageId;

@interface Model : NSObject

@property (nonatomic, readonly, nonnull) SafeMetaData *metadata;
@property (readonly, strong, nonatomic, nonnull) DatabaseModel *database;   
@property (nonatomic, readonly) BOOL isReadOnly;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allGroups;



- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithSafeDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                                       metaData:(SafeMetaData *_Nonnull)metaData
                                 forcedReadOnly:(BOOL)forcedReadOnly
                                     isAutoFill:(BOOL)isAutoFillOpen;

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen templateMetaData:(SafeMetaData*)templateMetaData;

- (void)update:(UIViewController*)viewController handler:(void(^)(BOOL userCancelled, BOOL conflictAndLocalWasChanged, NSError * _Nullable error))handler;
- (void)stopAudit;
- (void)restartBackgroundAudit;
- (void)stopAndClearAuditor;

@property (readonly) AuditState auditState;

@property (readonly, nullable) NSNumber* auditIssueCount;
@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditHibpErrorCount;

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(Node*)item;
- (BOOL)isFlaggedByAudit:(Node*)item;
- (NSString*)getQuickAuditSummaryForNode:(Node*)item;
- (NSString*)getQuickAuditVeryBriefSummaryForNode:(Node*)item;
- (NSSet<Node*>*)getSimilarPasswordNodeSet:(Node*)node;
- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(Node*)node;
- (void)setItemAuditExclusion:(Node*)item exclude:(BOOL)exclude;
- (BOOL)isExcludedFromAudit:(Node*)item;
- (NSArray<Node*>*)getExcludedAuditItems;
- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion;

- (void)closeAndCleanup;



- (Node*_Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title;
- (Node*_Nullable)addItem:(Node *_Nonnull)parent item:(Node*)item;

- (void)deleteItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items;
- (BOOL)canRecycle:(Node*_Nonnull)child;

- (BOOL)isPinned:(Node*)item;
- (void)togglePin:(Node*)item;
@property (readonly) NSSet<NSString*>* pinnedSet;
@property (readonly) NSArray<Node*>* pinnedNodes;

-(void)encrypt:(void (^)(BOOL userCancelled, NSData*_Nullable data, NSString*_Nullable debugXml, NSError*_Nullable error))completion;

- (NSString *_Nonnull)generatePassword;



- (void)disableAndClearAutoFill;
- (void)enableAutoFill;

@end

NS_ASSUME_NONNULL_END
