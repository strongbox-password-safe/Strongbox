//
//  SafeStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageBrowserItem.h"
#import "StorageProviderReadOptions.h"
#import "StorageProviderReadResult.h"
#import "StorageProviderUpdateResult.h"
#import "StorageProvider.h"
#import "CrossPlatform.h"

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    typedef UIViewController* VIEW_CONTROLLER_PTR;
    typedef UIImage* IMAGE_TYPE_PTR;
#else
    #import <Cocoa/Cocoa.h>
    typedef NSViewController* VIEW_CONTROLLER_PTR;
    typedef NSImage* IMAGE_TYPE_PTR;
#endif

NS_ASSUME_NONNULL_BEGIN

typedef void (^StorageProviderReadCompletionBlock)(StorageProviderReadResult result, NSData *_Nullable data, NSDate*_Nullable dateModified, const NSError *_Nullable error);
typedef void (^StorageProviderUpdateCompletionBlock)(StorageProviderUpdateResult result, NSDate*_Nullable newRemoteModDate, const NSError *_Nullable error);
typedef void (^StorageProviderGetModDateCompletionBlock)(BOOL storageIsAvailable, NSDate*_Nullable modDate, const NSError *_Nullable error);

@protocol SafeStorageProvider <NSObject>

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;
@property (nonatomic, readonly) BOOL defaultForImmediatelyOfferOfflineCache;
@property (nonatomic, readonly) BOOL privacyOptInRequired;

- (void)    create:(NSString *)nickName
          fileName:(NSString *)fileName
              data:(NSData *)data
      parentFolder:(NSObject * _Nullable)parentFolder
    viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController
        completion:(void (^)(METADATA_PTR _Nullable metadata, const NSError * _Nullable error))completion;

- (void)pullDatabase:(METADATA_PTR )safeMetaData
       interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)viewController
             options:(StorageProviderReadOptions*)options
          completion:(StorageProviderReadCompletionBlock)completion;

- (void)pushDatabase:(METADATA_PTR )safeMetaData
       interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)viewController
                data:(NSData *)data
          completion:(StorageProviderUpdateCompletionBlock)completion;

- (void)delete:(METADATA_PTR )safeMetaData completion:(void (^)(const NSError *_Nullable error))completion;

- (void)      list:(NSObject *_Nullable)parentFolder
    viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController
        completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, const NSError * _Nullable error))completion;



- (void)readWithProviderData:(NSObject * _Nullable)providerData
              viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController
                     options:(StorageProviderReadOptions*)options
                  completion:(StorageProviderReadCompletionBlock)completionHandler;

- (void)loadIcon:(NSObject *)providerData 
  viewController:(VIEW_CONTROLLER_PTR )viewController
      completion:(void (^)(IMAGE_TYPE_PTR image))completionHandler;

- (METADATA_PTR _Nullable)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData;



- (void)getModDate:(METADATA_PTR)safeMetaData
        completion:(StorageProviderGetModDateCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
