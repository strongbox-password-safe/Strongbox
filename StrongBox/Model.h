//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SafesList.h"
#import "DatabaseModel.h"
#import "AbstractDatabaseMetadata.h"

@interface Model : NSObject

@property (nonatomic, readonly, nonnull) SafeMetaData *metadata;
@property (readonly, strong, nonatomic, nonnull) DatabaseModel *database;
@property (nonatomic, readonly) BOOL isCloudBasedStorage;
@property (nonatomic, readonly) BOOL isUsingOfflineCache;
@property (nonatomic, readonly) BOOL isReadOnly;

@property (nullable, nonatomic) NSString* openedWithYubiKeySecret; // Used for Convenience Setting if this database was opened with a Yubikey workaround

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initWithSafeDatabase:(DatabaseModel *_Nonnull)passwordDatabase
                            metaData:(SafeMetaData *_Nonnull)metaData
                     storageProvider:(id <SafeStorageProvider>_Nonnull)provider
                   cacheMode:(BOOL)usingOfflineCache
                          isReadOnly:(BOOL)isReadOnly NS_DESIGNATED_INITIALIZER;

- (void)update:(BOOL)isAutoFill handler:(void (^_Nonnull)(NSError * _Nullable error))handler;

// Offline Cache Stuff

- (void)updateOfflineCacheWithData:(NSData *_Nonnull)data;
- (void)updateOfflineCache:(void (^_Nonnull)(void))handler;
- (void)disableAndClearOfflineCache;
- (void)enableOfflineCache;

- (void)updateAutoFillCacheWithData:(NSData *_Nonnull)data;
- (void)updateAutoFillCache:(void (^_Nonnull)(void))handler;
- (void)disableAndClearAutoFill;
- (void)enableAutoFill;
     
// Operations

- (Node* _Nullable)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*_Nonnull)title;
- (BOOL)deleteItem:(Node *_Nonnull)child;
- (BOOL)deleteWillRecycle:(Node*_Nonnull)child;

-(void)encrypt:(void (^_Nullable)(NSData* _Nullable data, NSError* _Nullable error))completion;
- (NSString *_Nonnull)generatePassword;

- (void)updateAutoFillQuickTypeDatabase;
     
@end
