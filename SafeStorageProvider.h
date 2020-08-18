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

// MMcG: 25-May-2020 - NB re immediatelyOfferCacheIfOffline
//
// Sometimes we don't want to try to read if we know we're offline because of a long delay (Dropbox)
//
// or
//
// Sometimes we don't know if the provider can offer it's own cached version (iOS Files via Third Party) or (iOS Files Local files)
// even if we're offline so we should try to read even if we know we're offline - This switch allows us to customize how quickly we offer
// a cached version if it's available
//
// or
//
// Our Offline Detector detects Internet connectivity (DuckDuckGo) but user could be using database on local LAN which could work fine (WebDAV, SFTP, maybe even iOS Files?)

@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline; // TODO: This is also something we probably want to allow user to override per safe (e.g. Dropbox via Files sucks when this is off, but local device files via Files works well)

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
