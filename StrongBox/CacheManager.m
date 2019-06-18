//
//  CacheManager.m
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CacheManager.h"
#import "FileManager.h"

@implementation CacheManager

+ (instancetype)sharedInstance {
    static CacheManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CacheManager alloc] init];
    });
    
    return sharedInstance;
}

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSURL* url = [self getOfflineCachePath:safeMetaData];
    
    NSError *error;
    
    [[NSFileManager defaultManager] removeItemAtPath:url.path error:&error];
    
    if(completion != nil) {
        completion(error);
    }
}

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata {
    NSURL* url = [self getOfflineCachePath:safeMetadata];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        NSLog(@"Offline cache file does NOT exist!");
        return nil;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
    
    //NSLog(@"Getting modification date for: %@ - %@", path, attributes);
    
    return [attributes fileModificationDate];
}


- (void)createOfflineCacheFile:(SafeMetaData *)safe
                          data:(NSData *)data
                    completion:(void (^)(BOOL success))completion {
    NSURL* url = [self getOfflineCachePath:safe];
    
    //NSLog(@"Creating offline cache file at: %@", path);
    
    if(![data writeToFile:url.path atomically:YES]) {
        NSLog(@"Error Writing offline Cache file.");
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
                   completion:(void (^)(NSData *, NSError *error))completion {
    NSURL* url = [self getOfflineCachePath:safeMetaData];
    
    NSLog(@"readOfflineCachedSafe at: %@", url.path);
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:url.path];
    
    completion(data, nil);
}

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(BOOL success))completion {
    NSURL* url = [self getOfflineCachePath:safeMetaData];
    
    if(![data writeToFile:url.path atomically:YES]) {
        NSLog(@"Error updating offline cache.");
        completion(NO);
    }
    else {
        completion(YES);
    }
}


- (void)readAutoFillCache:(SafeMetaData *)safeMetaData completion:(void (^)(NSData *, NSError *error))completion {
    NSURL *fileUrl = [self getAutoFillFilePath:safeMetaData];
    
    NSLog(@"Reading AutoFill cache file at: %@", fileUrl);
    
    NSError* error;
    NSData *data = [NSData dataWithContentsOfFile:fileUrl.path options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error Reading AutoFill Cache File: [%@]", error);
    }
    
    completion(data, error);
}

- (void)createAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(BOOL success))completion {
    NSURL *fileUrl = [self getAutoFillFilePath:safeMetaData];
    NSLog(@"Creating AutoFill cache file at: %@", fileUrl);
    
    NSError* error;
    if(![data writeToFile:fileUrl.path options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Error Writing AutoFill Cache file. [%@]", error);
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)updateAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(BOOL success))completion {
    NSURL *fileUrl = [self getAutoFillFilePath:safeMetaData];
    
    //NSLog(@"Updating AutoFill cache file at: %@", filePath);
    
    NSError* error;
    if(![data writeToFile:fileUrl.path options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Error updating AutoFill cache. [%@]", error);
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)deleteAutoFillCache:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSURL *fileUrl = [self getAutoFillFilePath:safeMetaData];
    
    NSError *error;
    
    NSLog(@"Deleting AutoFill cache file at: %@", fileUrl.path);
    
    [[NSFileManager defaultManager] removeItemAtPath:fileUrl.path error:&error];
    
    if(completion != nil) {
        completion(error);
    }
}

- (NSDate *)getAutoFillCacheModificationDate:(SafeMetaData *)safeMetadata {
    NSURL *fileUrl = [self getAutoFillFilePath:safeMetadata];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileUrl.path]) {
        NSLog(@"Auto Fill cache file does NOT exist!");
        return nil;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileUrl.path error:nil];
    
    return [attributes fileModificationDate];
}

- (NSURL*)getAutoFillFilePath:(SafeMetaData*)safeMetaData {
    NSString *filename = [NSString stringWithFormat:@"%@-autofill-cache.dat", safeMetaData.uuid];
    NSURL* autoFillCacheDir = FileManager.sharedInstance.autoFillCacheDirectory;
    return [autoFillCacheDir URLByAppendingPathComponent:filename];
}

- (NSURL*)getOfflineCachePath:(SafeMetaData *)safeMetaData {
    NSString *filename = [NSString stringWithFormat:@"%@-offline-cache.dat", safeMetaData.uuid];
    return [FileManager.sharedInstance.offlineCacheDirectory URLByAppendingPathComponent:filename];
}

@end
