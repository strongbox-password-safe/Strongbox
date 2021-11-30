//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OnboardingDatabaseChangeRequests.h"

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

typedef UIViewController* VIEW_CONTROLLER_PTR;
typedef SafeMetaData* METADATA_PTR;

#else

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

typedef NSViewController* VIEW_CONTROLLER_PTR;
typedef DatabaseMetadata* METADATA_PTR;

#endif

#import "DatabaseModel.h"
#import "DatabaseAuditor.h"
#import "AsyncUpdateResult.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kAuditNodesChangedNotificationKey;
extern NSString* const kAuditProgressNotificationKey;
extern NSString* const kAuditCompletedNotificationKey;
extern NSString* const kProStatusChangedNotificationKey;
extern NSString* const kAppStoreSaleNotificationKey; 
extern NSString* const kCentralUpdateOtpUiNotification;
extern NSString* const kMasterDetailViewCloseNotification;
extern NSString* const kDatabaseViewPreferencesChangedNotificationKey;
extern NSString* const kWormholeAutoFillUpdateMessageId;
extern NSString* const kDatabaseReloadedNotificationKey;
extern NSString* const kAsyncUpdateDone;
extern NSString* const kAsyncUpdateStarting;

@interface Model : NSObject

@property (nonatomic, readonly, nonnull) METADATA_PTR metadata;
@property (readonly, strong, nonatomic, nonnull) DatabaseModel *database;   
@property (nonatomic, readonly) BOOL isReadOnly;
@property (readonly) BOOL isInOfflineMode;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allGroups;




- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                                   metaData:(METADATA_PTR _Nonnull)metaData
                             forcedReadOnly:(BOOL)forcedReadOnly
                                 isAutoFill:(BOOL)isAutoFill;

- (instancetype _Nullable )initWithDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                                   metaData:(METADATA_PTR _Nonnull)metaData
                             forcedReadOnly:(BOOL)forcedReadOnly
                                 isAutoFill:(BOOL)isAutoFill
                                offlineMode:(BOOL)offlineMode; 

#if TARGET_OS_IPHONE

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen
                 templateMetaData:(METADATA_PTR)templateMetaData;

#endif

- (void)reloadDatabaseFromLocalWorkingCopy:(VIEW_CONTROLLER_PTR)viewController 
                                completion:(void(^_Nullable)(BOOL success))completion;

- (void)update:(VIEW_CONTROLLER_PTR)viewController handler:(void(^)(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error))handler;

- (void)stopAudit;
- (void)restartBackgroundAudit;
- (void)stopAndClearAuditor;

@property (readonly) AuditState auditState;
@property (readonly, nullable) NSNumber* auditIssueCount;
@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditHibpErrorCount;

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(NSUUID*)item;
- (BOOL)isFlaggedByAudit:(NSUUID*)item;
- (NSString*)getQuickAuditSummaryForNode:(NSUUID*)item;
- (NSString*)getQuickAuditVeryBriefSummaryForNode:(NSUUID*)item;
- (NSSet<Node*>*)getSimilarPasswordNodeSet:(NSUUID*)node;
- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(NSUUID*)node;
- (void)setItemAuditExclusion:(NSUUID*)item exclude:(BOOL)exclude;
- (BOOL)isExcludedFromAudit:(NSUUID*)item;
- (NSArray<Node*>*)getExcludedAuditItems;
- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion;

- (void)closeAndCleanup;



- (Node*_Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title;
- (Node*_Nullable)addItem:(Node *_Nonnull)parent item:(Node*)item;

- (void)deleteItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items;

- (BOOL)canRecycle:(NSUUID*_Nonnull)itemId;

- (BOOL)isPinned:(NSUUID*)itemId;
- (void)togglePin:(NSUUID*)itemId;

- (void)launchUrl:(Node*)item;
- (void)launchUrlString:(NSString*)urlString;

@property (readonly) NSSet<NSString*>* pinnedSet;
@property (readonly) NSArray<Node*>* pinnedNodes;

-(void)encrypt:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(BOOL userCancelled, NSString*_Nullable file, NSString*_Nullable debugXml, NSError*_Nullable error))completion;

- (NSString *_Nonnull)generatePassword;



- (void)disableAndClearAutoFill;
- (void)enableAutoFill;



@property (nullable) AsyncUpdateResult* lastAsyncUpdateResult;
@property (readonly) BOOL isRunningAsyncUpdate;

- (BOOL)asyncUpdateAndSync;
- (void)clearAsyncUpdateState;



@property BOOL isDuressDummyDatabase; 

@property (nullable) OnboardingDatabaseChangeRequests* onboardingDatabaseChangeRequests;

@end

NS_ASSUME_NONNULL_END
