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

+ (id<AbstractDatabaseFormatAdaptor>)getAdaptor:(DatabaseFormat)format;

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype)initNewWithPassword:(nullable NSString *)password keyFileDigest:(nullable NSData*)keyFileDigest format:(DatabaseFormat)format;

- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data
                                                  password:(NSString *_Nonnull)password
                                                     error:(NSError *_Nonnull*_Nonnull)ppError;

- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data
                                                  password:(NSString *__nullable)password
                                             keyFileDigest:(NSData* __nullable)keyFileDigest
                                                     error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment;
- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex;
- (void)setNodeAttachments:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments;
- (void)setNodeCustomIcon:(Node*)node data:(NSData*)data;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) id<AbstractDatabaseMetadata> metadata;
@property (nonatomic, readonly, nonnull) NSArray<DatabaseAttachment*> *attachments;
@property (nonatomic, readonly, nonnull) NSDictionary<NSUUID*, NSData*>* customIcons;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allGroups;
@property (nonatomic, retain, nullable) NSString *masterPassword;
@property (nonatomic, retain, nullable) NSData *keyFileDigest;
@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly, nonnull) NSString* fileExtension;

// Helpers

@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull passwordSet;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularUsername;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularEmail;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularPassword;
@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;

@end

#endif // ifndef _DatabaseModel_h

NS_ASSUME_NONNULL_END
