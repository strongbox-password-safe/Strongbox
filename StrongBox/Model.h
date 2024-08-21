//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OnboardingDatabaseChangeRequests.h"
#import "SearchScope.h"
#import "BrowseSortField.h"
#import "BrowseSortConfiguration.h"
#import "BrowseViewType.h"
#import "ItemMetadataEntry.h"

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

typedef UIViewController* VIEW_CONTROLLER_PTR;

#else

#import <Cocoa/Cocoa.h>

typedef NSViewController* VIEW_CONTROLLER_PTR;

#endif

#import "DatabaseModel.h"
#import "DatabaseAuditor.h"
#import "AsyncJobResult.h"
#import "CommonDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^AsyncUpdateCompletion)(AsyncJobResult *result);

extern NSString* const kAuditNodesChangedNotificationKey;
extern NSString* const kAuditProgressNotification;
extern NSString* const kBeginImport2FAOtpAuthUrlNotification;
extern NSString* const kAuditCompletedNotification;
extern NSString* const kAuditNewSwitchedOffNotificationKey;

extern NSString* const kAppStoreSaleNotificationKey;
extern NSString* const kCentralUpdateOtpUiNotification;
extern NSString *const kModelEditedNotification;
extern NSString* const kMasterDetailViewCloseNotification;
extern NSString* const kDatabaseViewPreferencesChangedNotificationKey;
extern NSString* const kWormholeAutoFillUpdateMessageId;
extern NSString* const kDatabaseReloadedNotification;
extern NSString* const kTabsMayHaveChangedDueToModelEdit;
extern NSString* const kAsyncUpdateDoneNotification;
extern NSString* const kAsyncUpdateStartingNotification;

@interface Model : NSObject

@property (readonly) BOOL isKeePass2Format;
@property (nonatomic, readonly) NSString *databaseUuid;
@property (nonatomic, readonly, nonnull) METADATA_PTR metadata;
@property (readonly, strong, nonatomic, nonnull) DatabaseModel *database;
@property (nonatomic, readonly) BOOL isReadOnly;
@property (readonly) BOOL isInOfflineMode;

@property (readonly) BOOL formatSupportsCustomIcons;
@property (readonly) BOOL formatSupportsTags;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableNoneExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableEntries;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *keeAgentSSHKeyEntries;

@property (nonatomic, nonnull) CompositeKeyFactors *ckfs;



- (instancetype)init NS_UNAVAILABLE;

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

- (instancetype)initAsDuressDummy:(BOOL)isNativeAutoFillAppExtensionOpen
                 templateMetaData:(METADATA_PTR)templateMetaData;

#endif

- (void)reloadDatabaseFromLocalWorkingCopy:(VIEW_CONTROLLER_PTR(^)(void))onDemandViewController 
                         noProgressSpinner:(BOOL)noProgressSpinner
                                completion:(void(^)(BOOL success))completion;





- (void)restartBackgroundAudit;


- (Node*_Nullable)getItemById:(NSUUID*)uuid;
- (NSArray<Node*>*)getItemsById:(NSArray<NSUUID*>*)ids;

@property (nonatomic, readonly) NSInteger fastEntryTotalCount;
@property (nonatomic, readonly) NSInteger fastGroupTotalCount;

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(NSUUID*)item;
- (BOOL)isFlaggedByAudit:(NSUUID*)item;
- (NSString*)getQuickAuditSummaryForNode:(NSUUID*)item;
- (NSString*)getQuickAuditVeryBriefSummaryForNode:(NSUUID*)item;
- (NSArray<NSString *>*)getQuickAuditAllIssuesVeryBriefSummaryForNode:(NSUUID *)item;
- (NSArray<NSString *>*)getQuickAuditAllIssuesSummaryForNode:(NSUUID *)item;

- (void)replaceEntireUnderlyingDatabaseWith:(DatabaseModel*)newDatabase; 

@property (readonly, nullable) DatabaseAuditReport* auditReport;

- (NSSet<Node*>*)getSimilarPasswordNodeSet:(NSUUID*)node;
- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(NSUUID*)node;

- (void)toggleAuditExclusion:(NSUUID *)uuid;
- (void)excludeFromAudit:(Node*)node exclude:(BOOL)exclude;
- (BOOL)isExcludedFromAudit:(NSUUID*)item;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *excludedFromAuditItems;

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion;

- (void)closeAndCleanup;



- (BOOL)toggleAutoFillExclusion:(NSUUID*)uuid;
- (BOOL)setItemsExcludedFromAutoFill:(NSArray<NSUUID *>*)uuids exclude:(BOOL)exclude;
- (BOOL)isExcludedFromAutoFill:(NSUUID*)item;



- (NSInteger)reorderItem:(NSUUID*)nodeId idx:(NSInteger)idx;
- (NSInteger)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:(Node*)parentGroup;

- (Node*_Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title;

- (BOOL)validateAddChildren:(NSArray<Node *>*)items destination:(Node *)destination;

- (BOOL)addChildren:(NSArray<Node *>*)items destination:(Node *)destination;

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData;

- (void)deleteItems:(const NSArray<Node *> *)items;
- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)unDelete:(NSArray<NodeHierarchyReconstructionData*>*)undoData;

- (BOOL)recycleItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items
            undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData*>*)undoData;

- (void)emptyRecycleBin;

- (BOOL)isInRecycled:(NSUUID *)itemId; 
- (BOOL)canRecycle:(NSUUID*_Nonnull)itemId;

- (BOOL)isFavourite:(NSUUID*)itemId;
- (BOOL)toggleFavourite:(NSUUID*)itemId;
- (BOOL)addFavourite:(NSUUID*)itemId;
- (BOOL)addFavourites:(NSArray<NSUUID *>*)items;
- (BOOL)removeFavourite:(NSUUID*)itemId;

- (BOOL)launchUrl:(Node*)item;
- (BOOL)launchUrlString:(NSString*)urlString;

- (NSString *_Nonnull)generatePassword;



- (void)disableAndClearAutoFill;
- (void)enableAutoFill;



@property (nullable) AsyncJobResult* lastAsyncUpdateResult;
@property (readonly) BOOL isRunningAsyncUpdate;

- (BOOL)asyncUpdate;
- (BOOL)asyncUpdate:(AsyncUpdateCompletion _Nullable)completion;
- (BOOL)asyncSync;
- (BOOL)asyncSync:(AsyncUpdateCompletion _Nullable)completion;
- (BOOL)asyncUpdateAndSync;
- (BOOL)asyncUpdateAndSync:(AsyncUpdateCompletion _Nullable)completion;

- (void)clearAsyncUpdateState;



@property BOOL isDuressDummyDatabase; 

@property (nullable) OnboardingDatabaseChangeRequests* onboardingDatabaseChangeRequests;



@property (nonatomic, readonly) DatabaseFormat originalFormat;
- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;



- (NSArray<Node*>*)entriesWithTag:(NSString*)tag;

- (NSArray<Node*>*)searchAutoBestMatch:(NSString *)searchText scope:(SearchScope)scope;

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
            includeGroups:(BOOL)includeGroups;

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups
          browseSortField:(BrowseSortField)browseSortField
               descending:(BOOL)descending
        foldersSeparately:(BOOL)foldersSeparately;

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups
                 trueRoot:(BOOL)trueRoot
          browseSortField:(BrowseSortField)browseSortField
               descending:(BOOL)descending
        foldersSeparately:(BOOL)foldersSeparately;

- (NSArray<Node *> *)filterAndSortForBrowse:(NSMutableArray<Node *> *)nodes
                              includeGroups:(BOOL)includeGroups;

- (NSArray<Node*>*)filterAndSortForBrowse:(NSMutableArray<Node*>*)nodes
                    includeKeePass1Backup:(BOOL)includeKeePass1Backup
                        includeRecycleBin:(BOOL)includeRecycleBin
                           includeExpired:(BOOL)includeExpired
                            includeGroups:(BOOL)includeGroups
                          browseSortField:(BrowseSortField)browseSortField
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately;

- (NSArray<Node*>*)sortItemsForBrowse:(NSArray<Node*>*)items
                      browseSortField:(BrowseSortField)browseSortField
                           descending:(BOOL)descending
                    foldersSeparately:(BOOL)foldersSeparately;

- (NSComparisonResult)compareNodesForSort:(Node*)node1
                                    node2:(Node*)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately;

- (void)refreshCaches; 

#ifndef IS_APP_EXTENSION 
#if !TARGET_OS_IPHONE 
- (NSArray<Node *> *)getAutoFillMatchingNodesForUrl:(NSString *)urlString;
#endif
#endif

#if TARGET_OS_IPHONE

- (BrowseSortConfiguration*)getDefaultSortConfiguration;
- (BrowseSortConfiguration*)getSortConfigurationForViewType:(BrowseViewType)viewType;
- (void)setSortConfigurationForViewType:(BrowseViewType)viewType configuration:(BrowseSortConfiguration*)configuration;

#endif



- (NSArray<NSUUID*>*)getItemIdsForTag:(NSString*)tag;
- (BOOL)addTag:(NSUUID*)itemId tag:(NSString*)tag;
- (BOOL)removeTag:(NSUUID*)itemId tag:(NSString*)tag;
- (void)deleteTag:(NSString*)tag;
- (void)renameTag:(NSString*)from to:(NSString*)to;

- (BOOL)addTagToItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag;
- (BOOL)removeTagFromItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag;

@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull tagSet;



- (NSArray<ItemMetadataEntry*>*)getMetadataFromItem:(Node*)item; 
- (NSString*)getAllFieldsKeyValuesString:(NSUUID*)uuid;

@property (readonly) NSInteger auditEntryCount;
@property (readonly) NSArray<Node*>* auditEntries;
@property (readonly) NSArray<Node*>* expiredEntries;
@property (readonly) NSArray<Node*>* nearlyExpired;
@property (readonly) NSArray<Node*>* favourites;
@property (readonly) NSArray<Node*>* totpEntries;



- (BOOL)setItemTitle:(NSUUID*)uuid title:(NSString*)title;

@property (readonly) BOOL isAuditEnabled;
@property (readonly) CGFloat auditProgress;
@property (readonly) AuditState auditState;
@property (readonly, nullable) NSNumber* auditIssueCount;
@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditHibpErrorCount;

- (Node*)duplicateWithOptions:(NSUUID*)itemId
                        title:(NSString*)title
            preserveTimestamp:(BOOL)preserveTimestamp
            referencePassword:(BOOL)referencePassword
            referenceUsername:(BOOL)referenceUsername;

@end

NS_ASSUME_NONNULL_END
