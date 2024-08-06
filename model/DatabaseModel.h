#ifndef _DatabaseModel_h
#define _DatabaseModel_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "KeePassAttachmentAbstractionLayer.h"
#import "DatabaseFormat.h"
#import "UnifiedDatabaseMetadata.h"
#import "NodeHierarchyReconstructionData.h"
#import "CompositeKeyFactors.h"
#import "NSString+Extensions.h"

typedef enum : NSUInteger {
    kDatabaseSearchMatchFieldTitle,
    kDatabaseSearchMatchFieldUsername,
    kDatabaseSearchMatchFieldEmail,
    kDatabaseSearchMatchFieldUrl,
    kDatabaseSearchMatchFieldTag,
    kDatabaseSearchMatchFieldCustomField,
    kDatabaseSearchMatchFieldNotes,
    kDatabaseSearchMatchFieldPassword,
    kDatabaseSearchMatchFieldAttachment,
    kDatabaseSearchMatchFieldPath,
} DatabaseSearchMatchField;

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModel : NSObject

@property (nonatomic, readonly) Node* rootNode;
@property (readonly) BOOL isKeePass2Format;

@property (nonatomic, readonly) DatabaseFormat originalFormat;
@property (nonatomic, readonly) Node* effectiveRootGroup;
@property (nonatomic, readonly, nonnull) UnifiedDatabaseMetadata* meta;
@property (nonatomic, nonnull) CompositeKeyFactors *ckfs;

@property (nonatomic) NSDictionary<NSUUID*, NSDate*> *deletedObjects;

@property (readonly) NSArray<KeePassAttachmentAbstractionLayer*> *attachmentPool;
@property (readonly) NSDictionary<NSUUID*, NodeIcon*>* iconPool;

- (instancetype)init;

- (instancetype)clone;

- (instancetype)initWithFormat:(DatabaseFormat)format;

- (instancetype)initWithCompositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata
                          root:(Node *_Nullable)root;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors
                      metadata:(UnifiedDatabaseMetadata*)metadata
                          root:(Node *_Nullable)root
                deletedObjects:(NSDictionary<NSUUID *, NSDate *> *)deletedObjects
                      iconPool:(NSDictionary<NSUUID *, NodeIcon *> *)iconPool;



- (void)rebuildFastMaps; 

- (BOOL)isInRecycled:(NSUUID *)itemId;
- (void)emptyRecycleBin;



- (void)changeKeePassFormat:(DatabaseFormat)newFormat;

- (void)preSerializationPerformMaintenanceOrMigrations;
- (NSSet<Node*>*)getMinimalNodeSet:items;

- (BOOL)setItemTitle:(Node*)item title:(NSString*)title;

- (NSURL*_Nullable)launchableUrlForItem:(Node*)item;
- (NSURL*_Nullable)launchableUrlForUrlString:(NSString*)urlString;



- (void)deleteItems:(const NSArray<Node *> *)items;
- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)unDelete:(NSArray<NodeHierarchyReconstructionData*>*)undoData;



@property BOOL recycleBinEnabled;
@property (nullable, readonly) NSUUID* recycleBinNodeUuid;   
@property (nullable, readonly) NSDate* recycleBinChanged;
@property (nullable, readonly) Node* recycleBinNode;
@property (nullable, readonly) Node* keePass1BackupNode;

- (BOOL)canRecycle:(NSUUID*)itemId;
- (BOOL)recycleItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData*>*)undoData;



- (BOOL)validateMoveItems:(const NSArray<Node*>*)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node*>*)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData;



- (NSInteger)reorderItem:(Node*)item to:(NSInteger)to; 
- (NSInteger)reorderItem:(NSUUID*)nodeId idx:(NSInteger)idx;
- (NSInteger)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:parentGroup;



- (BOOL)validateAddChildren:(NSArray<Node *>*)items destination:(Node *)destination;

- (BOOL)addChildren:(NSArray<Node *>*)items destination:(Node *)destination;
- (BOOL)addChildren:(NSArray<Node *>*)items destination:(Node *)destination suppressFastMapsRebuild:(BOOL)suppressFastMapsRebuild;

- (BOOL)insertChildren:(NSArray<Node *>*)items
           destination:(Node *)destination
            atPosition:(NSInteger)position;

- (void)removeChildren:(NSArray<NSUUID *>*)itemIds;



- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory;



- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;
- (NSString *)getPathDisplayString:(Node *)vm;
- (NSString *)getPathDisplayString:(Node *)vm
                  includeRootGroup:(BOOL)includeRootGroup
       rootGroupNameInsteadOfSlash:(BOOL)rootGroupNameInsteadOfSlash
                includeFolderEmoji:(BOOL)includeFolderEmoji
                          joinedBy:(NSString*)joinedBy;

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm;
- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm prependSlash:(BOOL)prependSlash;

- (StringSearchMatchType)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (StringSearchMatchType)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (StringSearchMatchType)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin;
- (StringSearchMatchType)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin includeAssociatedDomains:(BOOL)includeAssociatedDomains;
- (StringSearchMatchType)isTagsMatches:(NSString*)searchText node:(Node*)node checkPinYin:(BOOL)checkPinYin;
- (StringSearchMatchType)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin includeAssociatedDomains:(BOOL)includeAssociatedDomains;
- (StringSearchMatchType)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin includeAssociatedDomains:(BOOL)includeAssociatedDomains matchField:(DatabaseSearchMatchField* _Nullable)matchField;

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText;

- (NSString*)getHtmlPrintString:(NSString*)databaseName;
- (NSString*)getHtmlPrintStringForItems:(NSString*)databaseName items:(NSArray<Node*>*)items;



@property (nonatomic, readonly, nonnull) NSArray<Node*> *expirySetEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *expiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *nearlyExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *totpEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *attachmentEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *keeAgentSSHKeyEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *passkeyEntries;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *excludedFromAuditItems;
- (BOOL)isExcludedFromAudit:(NSUUID*)nodeId;
- (void)excludeFromAudit:(NSUUID*)nodeId exclude:(BOOL)exclude;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchable;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableTrueRoot;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableIncludingRecycled;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableTrueRootIncludingRecycled;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableNoneExpiredEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActive;

@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull urlSet;

@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull customFieldKeySet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull tagSet;

@property (nonatomic, readonly, nullable) NSString* mostPopularUsername;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularUsernames;

@property (nonatomic, readonly, nullable) NSString* mostPopularEmail;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularEmails;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularTags;

@property (nonatomic, readonly) NSInteger fastEntryTotalCount;
@property (nonatomic, readonly) NSInteger fastGroupTotalCount;

@property (readonly) BOOL isUsingKeePassGroupTitleRules;



- (NSString*_Nullable)getCrossSerializationFriendlyIdId:(NSUUID *)nodeId;
- (Node *_Nullable)getItemByCrossSerializationFriendlyId:(NSString*)serializationId;

- (Node*_Nullable)getItemById:(NSUUID*)uuid;
- (NSArray<Node*>*)getItemsById:(NSArray<NSUUID*>*)ids;

- (NSArray<NSUUID*>*)getItemIdsForTag:(NSString*)tag;

- (BOOL)addTag:(NSUUID*)itemId tag:(NSString*)tag;
- (BOOL)removeTag:(NSUUID*)itemId tag:(NSString*)tag;
- (void)deleteTag:(NSString*)tag;
- (void)renameTag:(NSString*)from to:(NSString*)to;
- (BOOL)addTagToItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag;
- (BOOL)removeTagFromItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag;

- (BOOL)preOrderTraverse:(BOOL (^)(Node* node))function; 

@end

#endif 

NS_ASSUME_NONNULL_END
