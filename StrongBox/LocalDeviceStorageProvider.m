//
//  LocalDeviceStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "LocalDeviceStorageProvider.h"
#import "IOsUtils.h"

@implementation LocalDeviceStorageProvider

-(StorageProvider) getStorageId
{
    return kLocalDevice;
}

-(BOOL)isCloudBased{
    return NO;
}

- (void)create:(NSString*)desiredFilename data:(NSData*)data parentReference:(NSString*)parentReference viewController:(UIViewController*)viewController completionHandler:(void (^)(NSString *fileName, NSString *fileIdentifier, NSError *error))completion
{
    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:desiredFilename];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        path = [self insertTimestampInFilename:path];
    }
    
    [data writeToFile:path atomically:YES];
    
    completion([path lastPathComponent], [path lastPathComponent], nil);
}

- (void)read:(SafeMetaData*)safeMetaData viewController:(UIViewController*)viewController completionHandler:(void (^)(NSData*, NSError* error))completion
{
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];
    
    NSLog(@"Local Reading at: %@", path);
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    
    completion(data, nil);
}

- (void)readOfflineCachedSafe:(SafeMetaData*)safeMetaData viewController:(UIViewController*)viewController completionHandler:(void (^)(NSData*, NSError* error))completion
{
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];
    
    NSLog(@"Local Reading at: %@", path);
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    
    completion(data, nil);
}

- (void)update:(SafeMetaData*)safeMetaData data:(NSData*)data viewController:(UIViewController*)viewController completionHandler:(void (^)(NSError *error))completion
{
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];
    
    [data writeToFile:path atomically:YES ];
    
    completion(nil);
}

- (void)updateOfflineCachedSafe:(SafeMetaData*)safeMetaData data:(NSData*)data viewController:(UIViewController*)viewController completionHandler:(void (^)(NSError *error))completion
{
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];
    
    [data writeToFile:path atomically:YES ];
    
    completion(nil);
}

- (void)delete:(SafeMetaData*)safeMetaData completionHandler:(void (^)(NSError *error))completion
{
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];
    
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    
    completion(error);
}

- (void)deleteOfflineCachedSafe:(SafeMetaData*)safeMetaData completionHandler:(void (^)(NSError *error))completion
{
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];
    
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    
    completion(error);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)getFilePath:(SafeMetaData *)safeMetaData offlineCache:(BOOL)offlineCache
{
    // MMcG: BUGFIX: Bug in older versions saved full path instead of relative, just chop it out and re-append
    
    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:[
                            (offlineCache ? safeMetaData.offlineCacheFileIdentifier : safeMetaData.fileIdentifier) lastPathComponent]];
    
    return path;
}

-(NSDate*)getOfflineCacheFileModificationDate:(SafeMetaData*)safeMetadata
{
    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:[safeMetadata.offlineCacheFileIdentifier lastPathComponent]];

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    
    return [attributes fileModificationDate];
}

- (NSString *)insertTimestampInFilename:(NSString *)title
{
    NSString *fn=title;
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyyMMdd-HHmmss"];
    NSDate *date = [[NSDate alloc] init];
    
    NSString* extension = [title pathExtension];
    fn = [NSString stringWithFormat:@"%@-%@.%@",title, [dateFormat stringFromDate:date], extension];
    
    return fn;
}

@end
