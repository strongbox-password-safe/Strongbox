#ifndef _DatabaseModel_h
#define _DatabaseModel_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "DatabaseAttachment.h"
#import "DatabaseFormat.h"
#import "UnifiedDatabaseMetadata.h"
#import "NodeHierarchyReconstructionData.h"
#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModel : NSObject

@property (nonatomic, readonly) Node* rootNode;

@property (nonatomic, readonly) DatabaseFormat originalFormat;
@property (nonatomic, readonly) Node* effectiveRootGroup;
@property (nonatomic, readonly, nonnull) UnifiedDatabaseMetadata* meta;
@property (nonatomic, nonnull) CompositeKeyFactors *ckfs;

@property (nonatomic) NSDictionary<NSUUID*, NSDate*> *deletedObjects;

@property (readonly) NSArray<DatabaseAttachment*> *attachmentPool;
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



- (void)performPreSerializationTidy;
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



- (BOOL)reorderItem:(Node*)item to:(NSInteger)to; 
- (BOOL)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:parentGroup;



- (BOOL)validateAddChild:(Node*)item destination:(Node*)destination;
- (BOOL)addChild:(Node*)item destination:(Node*)destination;
- (BOOL)insertChild:(Node*)item destination:(Node*)destination atPosition:(NSInteger)position;
- (void)removeChildFromParent:(Node*)item;



- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory;



- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;
- (NSString *)getPathDisplayString:(Node *)vm;

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm;

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isTagsMatches:(NSString*)searchText node:(Node*)node;
- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText;

- (NSString*)getHtmlPrintString:(NSString*)databaseName;



@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchable;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableTrueRoot;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveEntries;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActiveGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allSearchableGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allActive;

@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull urlSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull passwordSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull tagSet;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularUsername;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularEmail;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularPassword;
@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;

@property (readonly) BOOL isUsingKeePassGroupTitleRules;



- (NSString*_Nullable)getCrossSerializationFriendlyIdId:(NSUUID *)nodeId;
- (Node *_Nullable)getItemByCrossSerializationFriendlyId:(NSString*)serializationId;

- (Node*_Nullable)getItemById:(NSUUID*)uuid;
- (BOOL)preOrderTraverse:(BOOL (^)(Node* node))function; 

@end

#endif 

NS_ASSUME_NONNULL_END
