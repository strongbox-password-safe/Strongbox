#ifndef _DatabaseModel_h
#define _DatabaseModel_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseMetadata.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "DatabaseAttachment.h"
#import "UiAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModel : NSObject

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;
+ (NSString*_Nonnull)getLikelyFileExtension:(NSData *_Nonnull)candidate;
+ (BOOL)isAutoFillLikelyToCrash:(NSData*)data;
+ (DatabaseFormat)getLikelyDatabaseFormat:(NSData *)candidate;
+ (NSString*)getDefaultFileExtensionForFormat:(DatabaseFormat)format;

+ (nullable id<AbstractDatabaseFormatAdaptor>)getAdaptor:(DatabaseFormat)format;


+ (void)fromData:(NSData *)data ckf:(CompositeKeyFactors *)ckf completion:(void(^)(BOOL userCancelled, DatabaseModel* model, NSError* error))completion;
- (void)getAsData:(SaveCompletionBlock)completion;


- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype)initNew:(CompositeKeyFactors*)compositeKeyFactors format:(DatabaseFormat)format;
- (instancetype)initWithDatabase:(StrongboxDatabase*)database adaptor:(id<AbstractDatabaseFormatAdaptor>)adaptor;

- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment;
- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment rationalize:(BOOL)rationalize;

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex;
- (void)setNodeAttachments:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments;
- (void)setNodeCustomIcon:(Node*)node data:(NSData*)data rationalize:(BOOL)rationalize;

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

@property (readonly) BOOL recycleBinEnabled; // Read-Only until we allow config
@property (readonly) Node* recycleBinNode;
- (void)createNewRecycleBinNode;

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
