#ifndef _DatabaseModel_h
#define _DatabaseModel_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseMetadata.h"
#import "AbstractPasswordDatabase.h"
#import "DatabaseAttachment.h"

@interface DatabaseModel : NSObject

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;
+ (NSString*_Nonnull)getLikelyFileExtension:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword:(DatabaseFormat)format;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password format:(DatabaseFormat)format;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) id<AbstractDatabaseMetadata> metadata;
@property (nonatomic, readonly, nonnull) NSMutableArray<DatabaseAttachment*> *attachments;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID*, NSData*>* customIcons;

@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allGroups;
@property (nonatomic, retain, nullable) NSString *masterPassword;
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
