#ifndef _DatabaseModel_h
#define _DatabaseModel_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseMetadata.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "DatabaseAttachment.h"
#import "UiAttachment.h"
#import "DatabaseModelConfig.h"

extern const NSUInteger kStreamingSerializationChunkSize;

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModel : NSObject

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;
+ (NSString*_Nonnull)getLikelyFileExtension:(NSData *_Nonnull)candidate;
+ (BOOL)isAutoFillLikelyToCrash:(NSData*)data;
+ (DatabaseFormat)getLikelyDatabaseFormat:(NSData *)candidate;
+ (NSString*)getDefaultFileExtensionForFormat:(DatabaseFormat)format;

+ (nullable id<AbstractDatabaseFormatAdaptor>)getAdaptor:(DatabaseFormat)format;

+ (void)fromData:(NSData *)data
             ckf:(CompositeKeyFactors *)ckf
useLegacyDeserialization:(BOOL)useLegacyDeserialization
      completion:(void(^)(BOOL userCancelled, DatabaseModel* model, NSError* error))completion;

+ (void)fromData:(NSData *)data
             ckf:(CompositeKeyFactors *)ckf
useLegacyDeserialization:(BOOL)useLegacyDeserialization
          config:(DatabaseModelConfig*)config
      completion:(void(^)(BOOL userCancelled, DatabaseModel* model, NSError* error))completion;

- (void)getAsData:(SaveCompletionBlock)completion;

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype)initEmptyForTesting:(CompositeKeyFactors*)compositeKeyFactors;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors;

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                        config:(DatabaseModelConfig*)config;

- (instancetype)initNew:(CompositeKeyFactors *)compositeKeyFactors
                 format:(DatabaseFormat)format;

- (instancetype)initNew:(CompositeKeyFactors *)compositeKeyFactors
                 format:(DatabaseFormat)format
                 config:(DatabaseModelConfig*)config;

- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment;
- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment rationalize:(BOOL)rationalize;

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex;
- (void)setNodeAttachments:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments;
- (void)setNodeCustomIcon:(Node*)node data:(NSData*)data rationalize:(BOOL)rationalize;

//

- (NSSet<Node*>*)getMinimalNodeSet:(const NSArray<Node*>*)nodes;

// Deletions

@property (readonly) NSDictionary<NSUUID*, NSDate*>* deletedObjects;

- (void)deleteItems:(const NSArray<Node *> *)items;
- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)unDelete:(NSArray<NodeHierarchyReconstructionData*>*)undoData;

// Recycle

- (BOOL)canRecycle:(Node*)item;
- (BOOL)recycleItems:(const NSArray<Node *> *)items;
- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData*>*)undoData;

// Move

- (BOOL)validateMoveItems:(const NSArray<Node*>*)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node*>*)items destination:(Node*)destination;
- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination undoData:(NSArray<NodeHierarchyReconstructionData*>*_Nullable*_Nullable)undoData;
- (void)undoMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData;

// Add

- (BOOL)validateAddChild:(Node*)item destination:(Node*)destination;
- (BOOL)addChild:(Node*)item destination:(Node*)destination;
- (void)unAddChild:(Node*)item;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) id<AbstractDatabaseMetadata> metadata;
@property (nonatomic, readonly, nonnull) NSArray<DatabaseAttachment*> *attachments;
@property (nonatomic, readonly, nonnull) NSDictionary<NSUUID*, NSData*>* customIcons;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allGroups;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *activeRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *activeGroups;

@property (nonatomic, nonnull, readonly) CompositeKeyFactors* compositeKeyFactors;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly, nonnull) NSString* fileExtension;

// Helpers

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

// TODO: Combine KP1 and KP2 Recycle Bin / Backup Group?
@property BOOL recycleBinEnabled;
@property (readonly, nullable) Node* recycleBinNode;
@property (nullable, readonly) Node* keePass1BackupNode;

- (NSString *)getGroupPathDisplayString:(Node *)vm;
- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm;

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isTagsMatches:(NSString*)searchText node:(Node*)node;
- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText;

- (NSString*)getHtmlPrintString:(NSString*)databaseName;

@end

#endif // ifndef _DatabaseModel_h

NS_ASSUME_NONNULL_END
