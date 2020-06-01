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

NS_ASSUME_NONNULL_BEGIN

@protocol SafeStorageProvider <NSObject>

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL allowOfflineCache;
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
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

- (void)      read:(SafeMetaData *)safeMetaData
    viewController:(UIViewController *)viewController
        isAutoFill:(BOOL)isAutoFill
        completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    isAutoFill:(BOOL)isAutoFill
    completion:(void (^)(NSError *_Nullable error))completion;

- (void)delete:(SafeMetaData*)safeMetaData completion:(void (^)(NSError *_Nullable error))completion;

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error))completion;

- (void)readWithProviderData:(NSObject * _Nullable)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completionHandler;

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler;

- (SafeMetaData *_Nullable)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData;

@end

NS_ASSUME_NONNULL_END
