//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesList.h"
#import "DatabaseModel.h"
#import "AbstractDatabaseMetadata.h"

@interface Model : NSObject

@property (nonatomic, readonly, nonnull)    SafeMetaData *metadata;
@property (nonatomic, readonly)             BOOL isCloudBasedStorage;
@property (nonatomic, readonly)             BOOL isUsingOfflineCache;
@property (nonatomic, readonly)             BOOL isReadOnly;

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithSafeDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                            metaData:(SafeMetaData *_Nonnull)metaData
                     storageProvider:(id <SafeStorageProvider>_Nonnull)provider
                   usingOfflineCache:(BOOL)usingOfflineCache
                          isReadOnly:(BOOL)isReadOnly NS_DESIGNATED_INITIALIZER;

- (void)update:(void (^_Nonnull)(NSError * _Nullable error))handler;

// Offline Cache Stuff

- (void)updateOfflineCacheWithData:(NSData *_Nonnull)data;
- (void)updateOfflineCache:(void (^_Nonnull)(void))handler;
- (void)disableAndClearOfflineCache;
- (void)enableOfflineCache;

// Operations

- (Node* _Nullable)addNewRecord:(Node *_Nonnull)parentGroup;
- (Node* _Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*_Nonnull)title;
- (void)deleteItem:(Node *_Nonnull)child;
- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node;
- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node;

// Get/Query

@property (nonatomic, readonly, nonnull) Node * rootGroup;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allRecords;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allGroups;
@property (nonatomic, readonly, nonnull) id<AbstractDatabaseMetadata> databaseMetadata;
@property (nonatomic) NSString * _Nonnull masterPassword;

-(void)encrypt:(void (^_Nullable)(NSData* _Nullable data, NSError* _Nullable error))completion;

// Convenience  / Helpers

@property (nonatomic, readonly, copy) NSSet<NSString*> *_Nonnull usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> *_Nonnull passwordSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> *_Nonnull emailSet;
@property (nonatomic, readonly) NSString *_Nonnull mostPopularUsername;
@property (nonatomic, readonly) NSString *_Nonnull mostPopularEmail;
@property (nonatomic, readonly) NSString *_Nonnull mostPopularPassword;
@property (nonatomic, readonly) NSString * _Nonnull generatePassword;
@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;

@end
