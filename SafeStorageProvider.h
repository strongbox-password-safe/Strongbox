//
//  SafeStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SafeMetaData.h"
#import "StorageBrowserItem.h"
#import "StorageProviderReadOptions.h"
#import "StorageProviderReadResult.h"
#import "StorageProviderUpdateResult.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^StorageProviderReadCompletionBlock)(StorageProviderReadResult result, NSData *_Nullable data, NSDate*_Nullable dateModified, const NSError *_Nullable error);
typedef void (^StorageProviderUpdateCompletionBlock)(StorageProviderUpdateResult result, NSDate*_Nullable newRemoteModDate, const NSError *_Nullable error);

@protocol SafeStorageProvider <NSObject>

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;















@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline; 

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject * _Nullable)parentFolder
    viewController:(UIViewController *_Nullable)viewController
        completion:(void (^)(SafeMetaData *metadata, const NSError *error))completion;

- (void)pullDatabase:(SafeMetaData *)safeMetaData
       interactiveVC:(UIViewController *_Nullable)viewController
             options:(StorageProviderReadOptions*)options
          completion:(StorageProviderReadCompletionBlock)completion;

- (void)pushDatabase:(SafeMetaData *)safeMetaData
       interactiveVC:(UIViewController *_Nullable)viewController
                data:(NSData *)data
          completion:(StorageProviderUpdateCompletionBlock)completion;

- (void)delete:(SafeMetaData*)safeMetaData completion:(void (^)(const NSError *_Nullable error))completion;

- (void)      list:(NSObject *_Nullable)parentFolder
    viewController:(UIViewController *_Nullable)viewController
        completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, const NSError *error))completion;

- (void)readWithProviderData:(NSObject * _Nullable)providerData
              viewController:(UIViewController *_Nullable)viewController
                     options:(StorageProviderReadOptions*)options
                  completion:(StorageProviderReadCompletionBlock)completionHandler;

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler;

- (SafeMetaData *_Nullable)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData;

@end

NS_ASSUME_NONNULL_END
