//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeDatabase.h"
#import "SafeStorageProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesCollection.h"
#import "CoreModel.h"

@interface Model : NSObject

@property (readonly) SafeDatabase *safe;
@property (readonly)    CoreModel *coreModel;
@property (readonly)    SafeMetaData *metadata;
@property (nonatomic)   SafesCollection *safes;
@property (readonly)    BOOL isCloudBasedStorage;
@property (readonly)    BOOL isUsingOfflineCache;

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSafeDatabase:(SafeDatabase *)safe
                            metaData:(SafeMetaData *)metaData
                     storageProvider:(id <SafeStorageProvider>)provider
                   usingOfflineCache:(BOOL)usingOfflineCache
                localStorageProvider:(LocalDeviceStorageProvider *)local
                               safes:(SafesCollection *)safes NS_DESIGNATED_INITIALIZER;

- (void)update:(void (^)(NSError *error))handler;

// Offline Cache Stuff

- (void)updateOfflineCacheWithData:(NSData *)data;

- (void)updateOfflineCache:(void (^)())handler;

- (void)        disableAndClearOfflineCache;

- (void)        enableOfflineCache;

// Search Safe Helpers

@property (NS_NONATOMIC_IOSONLY, getter = getSearchableItems, readonly, copy) NSArray *searchableItems;
- (NSArray *)getItemsForGroup:(Group *)group;
- (NSArray *)getSubgroupsForGroup:(Group *)group;

// Move

- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group;
- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk;
- (void)moveItems:(NSArray *)items destination:(Group *)group;

// Delete

- (void)deleteItems:(NSArray *)items;

// Auto complete helpers

@property (NS_NONATOMIC_IOSONLY, getter = getAllExistingUserNames, readonly, copy) NSSet *allExistingUserNames;
@property (NS_NONATOMIC_IOSONLY, getter = getAllExistingPasswords, readonly, copy) NSSet *allExistingPasswords;
@property (NS_NONATOMIC_IOSONLY, getter = getMostPopularUsername, readonly, copy) NSString *mostPopularUsername;
@property (NS_NONATOMIC_IOSONLY, getter = getMostPopularPassword, readonly, copy) NSString *mostPopularPassword;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *generatePassword;

@end
