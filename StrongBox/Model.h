//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafesList.h"
#import "DatabaseModel.h"
#import "AbstractDatabaseMetadata.h"
#import "DatabaseAuditor.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kAuditNodesChangedNotificationKey;
extern NSString* const kAuditProgressNotificationKey;
extern NSString* const kAuditCompletedNotificationKey;
extern NSString* const kProStatusChangedNotificationKey; // TODO: Dismiss the Free Trial Onboarding if this is received
extern NSString* const kAppStoreSaleNotificationKey; 
extern NSString* const kCentralUpdateOtpUiNotification;
extern NSString* const kDatabaseViewPreferencesChangedNotificationKey;
extern NSString *const kWormholeAutoFillUpdateMessageId;

@interface Model : NSObject

@property (nonatomic, readonly, nonnull) SafeMetaData *metadata;
@property (readonly, strong, nonatomic, nonnull) DatabaseModel *database;   
@property (nonatomic, readonly) BOOL isReadOnly;

@property (nullable, nonatomic) NSString* openedWithYubiKeySecret; // Used for Convenience Setting if this database was opened with a Yubikey workaround

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithSafeDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                                       metaData:(SafeMetaData *_Nonnull)metaData
                                 forcedReadOnly:(BOOL)forcedReadOnly
                                     isAutoFill:(BOOL)isAutoFillOpen;

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen templateMetaData:(SafeMetaData*)templateMetaData;

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
- (NSSet<Node*>*)getSimilarPasswordNodeSet:(Node*)node;
- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(Node*)node;
- (void)setItemAuditExclusion:(Node*)item exclude:(BOOL)exclude;
- (BOOL)isExcludedFromAudit:(Node*)item;
- (NSArray<Node*>*)getExcludedAuditItems;
- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion;

- (void)closeAndCleanup;

// Operations

- (Node* _Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*_Nonnull)title;

- (void)deleteItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items;
- (BOOL)canRecycle:(Node*_Nonnull)child;

- (BOOL)isPinned:(Node*)item;
- (void)togglePin:(Node*)item;
@property (readonly) NSSet<NSString*>* pinnedSet;

-(void)encrypt:(void (^)(BOOL userCancelled, NSData*_Nullable data, NSError*_Nullable error))completion;

- (NSString *_Nonnull)generatePassword;

// Auto Fill

- (void)disableAndClearAutoFill;
- (void)enableAutoFill;

@end

NS_ASSUME_NONNULL_END
