//
//  WorkingCopyManager.m
//  Strongbox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "WorkingCopyManager.h"
#import "Utils.h"
#import "FileManager.h"

@implementation WorkingCopyManager

+ (instancetype)sharedInstance {
    static WorkingCopyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WorkingCopyManager alloc] init];
    });
    return sharedInstance;
}

- (NSURL*)setWorkingCacheWithData:(NSData*)data dateModified:(NSDate*)dateModified database:(METADATA_PTR)database error:(NSError**)error {
    if (!data || !dateModified) {
        if (error) {
            *error = [Utils createNSError:@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache" errorCode:-1];
        }
        
        NSLog(@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache [%@][%@]", data, dateModified);
        return nil;
    }
    
    
    
    NSURL* localWorkingCacheUrl = [self getLocalWorkingCacheUrlForDatabase:database];
    [data writeToURL:localWorkingCacheUrl options:NSDataWritingAtomic error:error];
    


    if (*error) {
        return nil;
    }
    else {
        NSError *err2;
        [NSFileManager.defaultManager setAttributes:@{ NSFileModificationDate : dateModified }
                                       ofItemAtPath:localWorkingCacheUrl.path
                                              error:&err2];
        
        NSLog(@"Set Working Cache Attributes for [%@] to [%@] with error = [%@]", database.nickName, dateModified, err2);
        
        if (err2 && error) {
            *error = err2;
        }
        
        return err2 ? nil : localWorkingCacheUrl;
    }
}

- (void)deleteLocalWorkingCache:(METADATA_PTR)database {
    NSURL* localCache = [self getLocalWorkingCache:database];
    
    if (localCache) {
        NSError* error;
        [NSFileManager.defaultManager removeItemAtURL:localCache error:&error];
        
        if (error) {
            NSLog(@"Error delete local working cache: [%@]", error);
        }
    }
}

- (BOOL)isLocalWorkingCacheAvailable:(METADATA_PTR)database modified:(NSDate**)modified {
    return [self getLocalWorkingCache:database modified:modified] != nil;
}

- (NSURL*)getLocalWorkingCacheUrlForDatabase:(METADATA_PTR)database {
    return [FileManager.sharedInstance.syncManagerLocalWorkingCachesDirectory URLByAppendingPathComponent:database.uuid];
}

- (NSURL*)getLocalWorkingCache:(METADATA_PTR)database {
    return [self getLocalWorkingCache:database modified:nil];
}

- (NSURL*)getLocalWorkingCache:(METADATA_PTR)database modified:(NSDate**)modified {
    return [self getLocalWorkingCache:database modified:modified fileSize:nil];
}

- (NSURL*)getLocalWorkingCache:(METADATA_PTR)database modified:(NSDate**)modified fileSize:(unsigned long long*_Nullable)fileSize {
    NSURL* url = [self getLocalWorkingCacheUrlForDatabase:database];

    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error) {
        
        if (modified) {
            *modified = nil;
        }
        return nil;
    }

    if (modified) {
        *modified = attributes.fileModificationDate;
    }

    if (fileSize) {
        *fileSize = attributes.fileSize;
    }
    
    return url;
}

@end
