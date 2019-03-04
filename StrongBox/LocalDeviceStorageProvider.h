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
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;

// Used on creation of brand new safe via standard UI
- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

// Used during importation when we have a good idea of what the filename should be - try to maintain it if possible

- (void)        create:(NSString *)nickName
             extension:(NSString *)extension
                  data:(NSData *)data
     suggestedFilename:(NSString*)suggestedFilename
            completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

// Used during importation - we may just want to update the underlying local file (seems to be a common usage pattern)
- (BOOL)writeWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data;

// Used by auto key file detection code in OpenSafeSequenceHelper
//- (NSData*)readWithFilename:(NSString*)filename;
- (NSData*)readWithCaseInsensitiveFilename:(NSString*)filename;
- (BOOL)deleteWithCaseInsensitiveFilename:(NSString*)filename;

- (void)deleteAllInboxItems;

- (void)createOfflineCacheFile:(SafeMetaData *)safe
                          data:(NSData *)data
                     completion:(void (^)(BOOL success))completion;

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
               viewController:(UIViewController *)viewController
                   completion:(void (^)(NSData *, NSError *error))completion;

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData
                           data:(NSData *)data
                 viewController:(UIViewController *)viewController
                     completion:(void (^)(BOOL success))completion;

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion;

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion;

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata;

- (NSURL *)getFileUrl:(SafeMetaData *)safeMetaData;

- (void)startMonitoringDocumentsDirectory:(void (^)(void))completion;
- (void)stopMonitoringDocumentsDirectory;
- (NSArray<StorageBrowserItem *>*)scanForNewSafes;
- (BOOL)fileExists:(SafeMetaData*)metaData;
- (BOOL)fileNameExists:(NSString*)filename;

// Auto Fill Cache

- (void)createAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(BOOL success))completion;
- (void)readAutoFillCache:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *error))completion;
- (void)deleteAutoFillCache:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion;
- (void)updateAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completion:(void (^)(BOOL success))completion;
- (NSDate *)getAutoFillCacheModificationDate:(SafeMetaData *)safeMetadata;

- (void)excludeDirectoriesFromBackup;

@end
