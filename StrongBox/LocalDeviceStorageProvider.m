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
#import "SafesList.h"

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
        _browsableNew = NO;
        _browsableExisting = YES;
        _rootFolderOnly = YES;
        
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

- (NSString*)getOfflineCacheFileName:(SafeMetaData*)safe {
    return [NSString stringWithFormat:@"%@-offline-cache.dat", safe.uuid];
}

- (void)createOfflineCacheFile:(SafeMetaData *)safe
                          data:(NSData *)data
                    completion:(void (^)(BOOL success))completion {
    NSString* appSupportDir = [IOsUtils applicationSupportDirectory].path;

    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
        NSError *error = nil;
        
        NSLog(@"Creating Application Support Directory.");
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"%@", error.localizedDescription);
        }
    }
    
    NSString *desiredFilename = [self getOfflineCacheFileName:safe];
    NSString *path = [appSupportDir stringByAppendingPathComponent:desiredFilename];
    
    NSLog(@"Creating offline cache file at: %@", path);
    
    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Error Writing offline Cache file.");
        completion(NO);
    }
    else {
        completion(YES);
    }
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

    NSLog(@"readOfflineCachedSafe at: %@", path);

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

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completion:(void (^)(BOOL success))completion {
    NSLog(@"updateOfflineCachedSafe");
    
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Error updating offline cache.");
        completion(NO);
    }
    else {
        completion(YES);
    }
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
    if(offlineCache) {
        NSString *filename = [self getOfflineCacheFileName:safeMetaData];

        NSString *path = [[IOsUtils applicationSupportDirectory].path
                          stringByAppendingPathComponent:filename];
        
        return path;
    }
    else {
        NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                          stringByAppendingPathComponent:
                          safeMetaData.fileIdentifier.lastPathComponent];
        
        return path;
    }
}

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata {
    NSString *path = [self getFilePath:safeMetadata offlineCache:YES];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"Offline cache file does NOT exist!");
        return nil;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];

    NSLog(@"Getting modification date for: %@ - %@", path, attributes);

    return [attributes fileModificationDate];
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTIMPL
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    
    NSError *error;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[IOsUtils applicationDocumentsDirectory].path
                                                                                    error:&error];
    
    if (error) {
        completion(nil, error);
        return;
    }
    
    NSMutableArray<StorageBrowserItem*>* files = [NSMutableArray array];
    for (int count = 0; count < (int)[directoryContent count]; count++)
    {
        NSString *file = [directoryContent objectAtIndex:count];
        
        //NSLog(@"File %d: %@", (count + 1), file);
     
        StorageBrowserItem* browserItem = [[StorageBrowserItem alloc] init];
        
        BOOL isDirectory;
        NSString *fullPath = [NSString pathWithComponents:@[[IOsUtils applicationDocumentsDirectory].path, file]];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];

        if(exists) {
            browserItem.folder = isDirectory != 0;
            browserItem.name = file;
            browserItem.providerData = file;
            [files addObject:browserItem];
        }
    }
    
    completion(files, error);
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completionHandler {
    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:
                      (NSString*)providerData];
    
    NSLog(@"readWithProviderData at: %@", path);
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    
    completionHandler(data, nil);
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:(NSString*)providerData
                                   fileIdentifier:(NSString*)providerData];
}

@end
