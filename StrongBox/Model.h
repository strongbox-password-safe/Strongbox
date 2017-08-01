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

@property (readonly)    SafeMetaData *metadata;
@property (nonatomic)   SafesCollection *safes; 
@property (readonly)    BOOL isCloudBasedStorage;
@property (readonly)    BOOL isUsingOfflineCache;
@property (readonly)    BOOL isReadOnly;

/////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSafeDatabase:(SafeDatabase *)safe
                            metaData:(SafeMetaData *)metaData
                     storageProvider:(id <SafeStorageProvider>)provider
                   usingOfflineCache:(BOOL)usingOfflineCache
                          isReadOnly:(BOOL)isReadOnly
                localStorageProvider:(LocalDeviceStorageProvider *)local
                               safes:(SafesCollection *)safes NS_DESIGNATED_INITIALIZER;

- (void)update:(void (^)(NSError *error))handler;

// Offline Cache Stuff

- (void)updateOfflineCacheWithData:(NSData *)data;
- (void)updateOfflineCache:(void (^)())handler;
- (void)disableAndClearOfflineCache;
- (void)enableOfflineCache;
- (void)addRecord:(Record *)newRecord;

- (Group *)addSubgroupWithUIString:(Group *)parent title:(NSString *)title;

@property (readonly) NSDate *lastUpdateTime;
@property (readonly) NSString *lastUpdateUser;
@property (readonly) NSString *lastUpdateHost;
@property (readonly) NSString *lastUpdateApp;
@property (NS_NONATOMIC_IOSONLY, getter = getSafeAsData, readonly, copy) NSData *asData;
@property (NS_NONATOMIC_IOSONLY, getter = getMasterPassword, setter=setMasterPassword:) NSString *masterPassword;

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
- (void)deleteItem:(SafeItemViewModel *)item;

// Auto complete helpers

@property (NS_NONATOMIC_IOSONLY, getter = getAllExistingUserNames, readonly, copy) NSSet *allExistingUserNames;
@property (NS_NONATOMIC_IOSONLY, getter = getAllExistingPasswords, readonly, copy) NSSet *allExistingPasswords;
@property (NS_NONATOMIC_IOSONLY, getter = getMostPopularUsername, readonly, copy) NSString *mostPopularUsername;
@property (NS_NONATOMIC_IOSONLY, getter = getMostPopularPassword, readonly, copy) NSString *mostPopularPassword;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *generatePassword;

@end
