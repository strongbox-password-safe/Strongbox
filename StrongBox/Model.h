//
//  SafeViewModel.h
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "core-model/SafeDatabase.h"
#import "GoogleDriveManager.h"
#import <DropboxSDK/DropboxSDK.h>
#import "SafeStorageProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesCollection.h"
#import "core-model/CoreModel.h"

@interface Model : NSObject

@property (readonly)    SafeDatabase *safe;
@property (readonly)    CoreModel *coreModel;
@property (readonly)    SafeMetaData* metadata;
@property (nonatomic)   SafesCollection* safes;
@property (readonly)    BOOL isCloudBasedStorage;
@property (readonly)    BOOL isUsingOfflineCache;

/////////////////////////////////////////////////////////////////////////////////////////////////////////

-(id) initWithSafeDatabase:(SafeDatabase*)safe
                  metaData:(SafeMetaData*)metaData
           storageProvider:(id <SafeStorageProvider>)provider
         usingOfflineCache:(BOOL)usingOfflineCache
      localStorageProvider:(LocalDeviceStorageProvider*)local
                     safes:(SafesCollection*)safes;

-(void)update:(UIViewController*)viewController completionHandler:(void (^)(NSError* error))handler;

// Offline Cache Stuff

-(void)updateOfflineCacheWithData:(NSData*)data;

-(void)updateOfflineCache:(void (^)())handler;

-(void)disableAndClearOfflineCache;

-(void)enableOfflineCache;

// Search Safe Helpers

-(NSArray*)getSearchableItems;
-(NSArray*)getItemsForGroup:(Group*)group;
-(NSArray*)getSubgroupsForGroup:(Group*)group;

// Move

-(BOOL)validateMoveItems:(NSArray*)items destination:(Group*)group;
-(BOOL)validateMoveItems:(NSArray*)items destination:(Group*)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk;
-(void)moveItems:(NSArray*)items destination:(Group*)group;

// Delete

-(void)deleteItems:(NSArray*)items;

// Auto complete helpers

-(NSSet*)getAllExistingUserNames;
-(NSSet*)getAllExistingPasswords;
-(NSString*)getMostPopularUsername;
-(NSString*)getMostPopularPassword;

-(NSString*)generatePassword;

@end
