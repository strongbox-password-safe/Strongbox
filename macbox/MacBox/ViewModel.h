//
//  ViewModel.h
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "Model.h"
#import "UnifiedDatabaseMetadata.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "MacDatabasePreferences.h"
#import "EntryViewModel.h"
#import "NextNavigationConstants.h"
#import "EncryptionSettingsViewModel.h"

@class HeaderNodeState;
@class Document;

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kModelUpdateNotificationTitleChanged;
extern NSString* const kModelUpdateNotificationIconChanged;

extern NSString* const kModelUpdateNotificationItemsDeleted;
extern NSString* const kModelUpdateNotificationItemsUnDeleted;
extern NSString* const kModelUpdateNotificationItemsMoved;
extern NSString* const kModelUpdateNotificationTagsChanged;
extern NSString* const kModelUpdateNotificationDatabasePreferenceChanged;
extern NSString* const kModelUpdateNotificationDatabaseUpdateStatusChanged;
extern NSString* const kModelUpdateNotificationNextGenNavigationChanged;
extern NSString* const kModelUpdateNotificationNextGenSelectedItemsChanged;
extern NSString* const kModelUpdateNotificationNextGenSearchContextChanged;
extern NSString* const kModelUpdateNotificationHistoryItemDeleted;
extern NSString* const kModelUpdateNotificationHistoryItemRestored;
extern NSString* const kModelUpdateNotificationItemReOrdered;

extern NSString* const kModelUpdateNotificationItemsAdded;
extern NSString* const kModelUpdateNotificationItemEdited;

@interface ViewModel : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initLocked:(Document*)document databaseUuid:(NSString*)databaseUuid;
- (instancetype)initUnlocked:(Document *)document
                databaseUuid:(NSString*)databaseUuid
                       model:(Model *)model;

@property (nonatomic, readonly) MacDatabasePreferences *databaseMetadata;
@property (nonatomic, readonly) UnifiedDatabaseMetadata *metadata;

@property (nonatomic, readonly) NSString *databaseUuid;

@property (nonatomic, readonly, weak) Document*  document;
@property (nonatomic, readonly) BOOL locked;
@property (nonatomic, readonly) NSURL* fileUrl;
@property (nonatomic, readonly) Node* rootGroup;
@property (nonatomic, readonly) BOOL masterCredentialsSet;
@property (nonatomic, readonly) DatabaseFormat format;

@property (nonatomic, readonly, nonnull) NSSet<NodeIcon*>* customIcons;

@property (nonatomic, nullable) CompositeKeyFactors* compositeKeyFactors;

@property (nullable, readonly) Model* commonModel;
@property (readonly, nonatomic) DatabaseModel* database;

@property (readonly) BOOL formatSupportsCustomIcons;

- (NSArray<Node *>*)getItemsById:(NSArray<NSUUID *>*)uuids;
- (Node*_Nullable)getItemById:(NSUUID*)uuid;

- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;

- (BOOL)applyModelEditsAndMoves:(EntryViewModel *)editModel toNode:(NSUUID*)nodeId;

- (BOOL)setItemTitle:(Node* )item title:(NSString* )title;
- (void)setItemNotes:(Node*)item notes:(NSString*)notes;

- (void)setGroupExpandedState:(Node*)item expanded:(BOOL)expanded;
- (void)setSearchableState:(Node *)item searchable:(NSNumber*_Nullable)searchable;

- (void)setItemIcon:(Node *)item icon:(NodeIcon*_Nullable)icon;
- (void)batchSetIcons:(NSArray<Node*>*)items icon:(NodeIcon*)icon;
- (void)batchSetIcons:(NSDictionary<NSUUID*, NodeIcon*>*)iconMap;

- (void)deleteHistoryItem:(Node*)item historicalItem:(Node*)historicalItem;
- (void)restoreHistoryItem:(Node*)item historicalItem:(Node*)historicalItem;



- (void)addTagToItems:(const NSArray<Node *> *)items tag:(NSString*)tag;
- (void)removeTagFromItems:(const NSArray<Node *> *)items tag:(NSString*)tag;
- (void)renameTag:(NSString *)from to:(NSString*)to;
- (void)deleteTag:(NSString*)tag;



- (BOOL)isFavourite:(NSUUID*)itemId;
- (void)toggleFavourite:(NSUUID*)itemId;
- (void)addFavourites:(NSArray<NSUUID*>*)items;
@property (readonly) NSArray<Node*>* favourites;



- (BOOL)addItem:(Node *)item parent:(Node *)parent;
- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent;
- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString*)title group:(Node* _Nullable * _Nullable)group;



- (void)deleteItems:(const NSArray<Node *>*)items;
- (BOOL)recycleItems:(const NSArray<Node *>*)items;
- (BOOL)canRecycle:(Node*_Nonnull)item;
- (BOOL)isInRecycled:(NSUUID *)itemId;



- (NSInteger)reorderItem:(NSUUID *)nodeId idx:(NSInteger)idx;

- (BOOL)validateMove:(const NSArray<Node *> *)items destination:(Node*)destination;
- (BOOL)move:(const NSArray<Node *> *)items destination:(Node*)destination;
- (BOOL)moveItemsIntoNewGroup:(const NSArray<Node *> *)items parentGroup:(Node *)parentGroup title:(NSString *)title group:(Node *_Nullable*_Nullable)group;

- (BOOL)launchUrl:(Node*)item;
- (BOOL)launchUrlString:(NSString*)urlString;

- (NSSet<Node*>*)getMinimalNodeSet:(const NSArray<Node*>*)nodes;
- (Node*_Nullable)getItemFromSerializationId:(NSString*)serializationId;

- (NSString*)generatePassword;

- (NSString *)getGroupPathDisplayString:(Node *)node;
- (NSString *)getGroupPathDisplayString:(Node *)node rootGroupNameInsteadOfSlash:(BOOL)rootGroupNameInsteadOfSlash;
- (NSString *)getParentGroupPathDisplayString:(Node *)node;

@property (readonly) BOOL recycleBinEnabled; 
@property (readonly, nullable) Node* recycleBinNode;
@property (readonly, nullable) Node* keePass1BackupNode;



@property (readonly) BOOL isKeePass2Format;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *expiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *nearlyExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *excludedFromAuditEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *totpEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *attachmentEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *keeAgentSshKeyEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *passkeyEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchable;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableTrueRoot;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableNoneExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActive;



@property (nonatomic, readonly, copy) NSSet<NSString*> * usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * urlSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * customFieldKeySet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * tagSet;


@property (nonatomic, readonly) NSString * mostPopularUsername;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularUsernames;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularEmail;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularEmails;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularTags;

@property (nonatomic, readonly) NSInteger fastEntryTotalCount;
@property (nonatomic, readonly) NSInteger fastGroupTotalCount;

- (NSString *)getHtmlPrintString:(NSString*)databaseName;
- (NSString*)getHtmlPrintStringForItems:(NSString*)databaseName items:(NSArray<Node*>*)items;



@property BOOL showAutoCompleteSuggestions;
@property BOOL showChangeNotifications;
@property BOOL concealEmptyProtectedFields;
@property BOOL showAdvancedUnlockOptions;
@property BOOL showQuickView;
@property BOOL showAlternatingRows;
@property BOOL showVerticalGrid;
@property BOOL showHorizontalGrid;

@property NSArray<NSString*>* visibleColumns;
@property BOOL downloadFavIconOnChange;
@property BOOL promptedForAutoFetchFavIcon;
@property BOOL startWithSearch;
@property BOOL outlineViewTitleIsReadonly;

@property BOOL showRecycleBinInSearchResults;
@property BOOL showRecycleBinInBrowse;
@property BOOL sortKeePassNodes;

@property BOOL monitorForExternalChanges;
@property NSInteger monitorForExternalChangesInterval;
@property BOOL autoReloadAfterExternalChanges;

@property BOOL launchAtStartup;

@property BOOL alwaysOpenOffline;
@property (readonly) BOOL isInOfflineMode;

@property BOOL readOnly;
@property (readonly) BOOL isEffectivelyReadOnly; 

@property BOOL showChildCountOnFolderInSidebar;
@property SideBarChildCountFormat sideBarChildCountFormat;
@property NSString* sideBarChildCountGroupPrefix;
@property NSString* sideBarChildCountSeparator;
@property BOOL sideBarChildCountShowZero;
@property BOOL sideBarShowTotalCountOnHierarchy;



@property (nullable) NSUUID* asyncUpdateId;

- (NSArray<Node*>*)entriesWithTag:(NSString*)tag;

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

- (NSArray<Node*>*)filterAndSortForBrowse:(NSMutableArray<Node*>*)nodes
                    includeKeePass1Backup:(BOOL)includeKeePass1Backup
                        includeRecycleBin:(BOOL)includeRecycleBin
                           includeExpired:(BOOL)includeExpired
                            includeGroups:(BOOL)includeGroups
                          browseSortField:(BrowseSortField)browseSortField
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately;

- (NSComparisonResult)compareNodesForSort:(Node*)node1
                                    node2:(Node*)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately;

- (void)applyEncryptionSettingsViewModelChanges:(EncryptionSettingsViewModel*)encryptionSettings;

@property KeePassIconSet keePassIconSet;



- (void)restartBackgroundAudit;



- (void)batchExcludeItemsFromAutoFill:(NSArray<Node*>*)items exclude:(BOOL)exclude;
- (BOOL)isExcludedFromAutoFill:(NSUUID*)item;

@property (readonly, nullable) NSNumber* auditIssueCount;
- (BOOL)isFlaggedByAudit:(NSUUID*)item;
- (NSArray<NSString *>*)getQuickAuditAllIssuesVeryBriefSummaryForNode:(NSUUID *)item;
- (NSArray<NSString *>*)getQuickAuditAllIssuesSummaryForNode:(NSUUID *)item;
- (NSSet<Node*>*)getSimilarPasswordNodeSet:(NSUUID*)node;
- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(NSUUID*)node;
@property DatabaseAuditorConfiguration* auditConfig;
@property (readonly) AuditState auditState;
@property (readonly) NSUInteger auditHibpErrorCount;
@property (readonly) NSUInteger auditIssueNodeCount;

- (BOOL)isExcludedFromAudit:(NSUUID*)item;

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError*_Nullable error))completion;

- (void)setItemAuditExclusion:(Node*)node exclude:(BOOL)exclude isPartOfBatch:(BOOL)isPartOfBatch;

- (void)batchExcludeItemsFromAudit:(NSArray<Node*>*)items exclude:(BOOL)exclude;

@property (readonly, nullable) DatabaseAuditReport* auditReport;



@property (readonly) OGNavigationContext nextGenNavigationContext;
@property (readonly) NSUUID* nextGenNavigationContextSideBarSelectedGroup;
@property (readonly) NSString* nextGenNavigationContextSelectedTag;
@property (readonly) OGNavigationSpecial nextGenNavigationContextSpecial;
@property (readonly) OGNavigationAuditCategory nextGenNavigationContextAuditCategory;
@property (readonly) NSUUID* nextGenNavigationSelectedFavouriteId;

- (void)setNextGenNavigationNone;
- (void)setNextGenNavigation:(OGNavigationContext)context selectedGroup:(NSUUID*_Nullable)selectedGroup;
- (void)setNextGenNavigation:(OGNavigationContext)context tag:(NSString*)tag;
- (void)setNextGenNavigation:(OGNavigationContext)context special:(OGNavigationSpecial)special;
- (void)setNextGenNavigationToAuditIssues:(OGNavigationAuditCategory)category;
- (void)setNextGenNavigationFavourite:(NSUUID*)nodeId;



@property NSArray<NSUUID*> *nextGenSelectedItems;



@property NSString* nextGenSearchText;
@property SearchScope nextGenSearchScope;
@property BOOL nextGenSearchIncludeGroups;

@property NSArray<HeaderNodeState*>* headerNodes;

@property BOOL customSortOrderForFields;

@property ConflictResolutionStrategy conflictResolutionStrategy;

- (void)rebuildMapsAndCaches;

- (Node*)duplicateWithOptions:(NSUUID*)itemId
                        title:(NSString*)title
            preserveTimestamp:(BOOL)preserveTimestamp
            referencePassword:(BOOL)referencePassword
            referenceUsername:(BOOL)referenceUsername;

@end

NS_ASSUME_NONNULL_END
