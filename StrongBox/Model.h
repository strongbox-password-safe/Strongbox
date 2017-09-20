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
#import "SafesCollection.h"
#import "PasswordDatabase.h"

@interface Model : NSObject

@property (nonatomic, readonly, nonnull)    SafeMetaData *metadata;
@property (nonatomic, readonly)             BOOL isCloudBasedStorage;
@property (nonatomic, readonly)             BOOL isUsingOfflineCache;
@property (nonatomic, readonly)             BOOL isReadOnly;

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithSafeDatabase:(PasswordDatabase *_Nonnull)passwordDatabase
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
- (void)defaultLastUpdateFieldsToNow;

// Get/Query

@property (nonatomic, readonly, nonnull) Node * rootGroup;
@property (nonatomic, readonly) NSDate * _Nullable lastUpdateTime;
@property (nonatomic, readonly) NSString * _Nullable lastUpdateUser;
@property (nonatomic, readonly) NSString * _Nullable lastUpdateHost;
@property (nonatomic, readonly) NSString * _Nullable lastUpdateApp;
@property (nonatomic) NSString * _Nonnull masterPassword;

-(void)encrypt:(void (^_Nullable)(NSData* _Nullable data, NSError* _Nullable error))completion;

// Convenience  / Helpers

@property (nonatomic, readonly, copy) NSSet<NSString*> *_Nonnull usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> *_Nonnull passwordSet;
@property (nonatomic, readonly) NSString *_Nonnull mostPopularUsername;
@property (nonatomic, readonly) NSString *_Nonnull mostPopularPassword;
@property (nonatomic, readonly) NSString * _Nonnull generatePassword;

@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;
@property (nonatomic, readonly) NSInteger keyStretchIterations;
@property (nonatomic, readonly) NSString * _Nonnull version;

@end
