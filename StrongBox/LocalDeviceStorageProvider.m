//
//  LocalDeviceStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "LocalDeviceStorageProvider.h"
#import "IOsUtils.h"
#import "Utils.h"

@implementation LocalDeviceStorageProvider

+ (instancetype)sharedInstance {
    static LocalDeviceStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LocalDeviceStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayName = @"Local Device";
        _icon = @"phone";
        _storageId = kLocalDevice;
        _cloudBased = NO;
        _providesIcons = NO;
        _browsable = NO;

        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", nickName];

    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:desiredFilename];

    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [Utils insertTimestampInFilename:path];
    }

    [data writeToFile:path atomically:YES];

    SafeMetaData *metadata = [[SafeMetaData alloc] initWithNickName:nickName storageProvider:self.storageId fileName:path.lastPathComponent fileIdentifier:path.lastPathComponent];

    metadata.offlineCacheEnabled = NO;

    completion(metadata, nil);
}

- (void)createOfflineCacheFile:(NSString *)uniqueIdentifier
                          data:(NSData *)data
                    completion:(void (^)(NSError *error))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox-offline-cache.dat", uniqueIdentifier];

    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:desiredFilename];
    
    [data writeToFile:path atomically:YES];
    
    completion(nil);
}

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];

    NSLog(@"Local Reading at: %@", path);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

    completion(data, nil);
}

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
               viewController:(UIViewController *)viewController
                   completion:(void (^)(NSData *, NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    NSLog(@"Local Reading at: %@", path);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

    completion(data, nil);
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];

    [data writeToFile:path atomically:YES ];

    completion(nil);
}

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    [data writeToFile:path atomically:YES ];

    completion(nil);
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    completion(error);
}

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    completion(error);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSURL*)getFileUrl:(SafeMetaData*)safeMetaData {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];
    return [NSURL fileURLWithPath:path];
}

- (NSString *)getFilePath:(SafeMetaData *)safeMetaData offlineCache:(BOOL)offlineCache {
    // MMcG: BUGFIX: Bug in older versions saved full path instead of relative, just chop it out and re-append

    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:
                      (offlineCache ? safeMetaData.offlineCacheFileIdentifier : safeMetaData.fileIdentifier).lastPathComponent];

    return path;
}

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata {
    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:(safeMetadata.offlineCacheFileIdentifier).lastPathComponent];

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];

    return [attributes fileModificationDate];
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTIMPL
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    // NOTIMPL
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completionHandler {
    // NOTIMPL
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    // NOTIMPL
    return nil;
}

@end
