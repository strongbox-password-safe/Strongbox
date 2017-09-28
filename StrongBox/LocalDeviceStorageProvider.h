//
//  LocalDeviceStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SafeMetaData.h"

@interface LocalDeviceStorageProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL cloudBased;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsable;

- (void)createOfflineCacheFile:(NSString *)uniqueIdentifier
                          data:(NSData *)data
                    completion:(void (^)(NSError *error))completion;

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
               viewController:(UIViewController *)viewController
                   completion:(void (^)(NSData *, NSError *error))completion;

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData
                           data:(NSData *)data
                 viewController:(UIViewController *)viewController
                     completion:(void (^)(NSError *error))completion;

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion;

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion;

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata;

- (NSURL *)getFileUrl:(SafeMetaData *)safeMetaData;

@end
