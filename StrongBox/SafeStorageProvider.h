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

@protocol SafeStorageProvider <NSObject>

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL cloudBased;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsable;

- (void)    create:(NSString *)nickName
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

- (void)      read:(SafeMetaData *)safeMetaData
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSData *data, NSError *error))completion;

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion;

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion;

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completionHandler;

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler;

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData;

@end
