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

- (NSURL *)setWorkingCacheWithFile:(NSString *)file dateModified:(NSDate *)dateModified database:(NSString *)databaseUuid error:(NSError *__autoreleasing  _Nullable *)error {
    return [self setWorkingCache:file data:nil dateModified:dateModified database:databaseUuid error:error];
}

- (NSURL*)setWorkingCacheWithData2:(NSData*)data
                     dateModified:(NSDate*)dateModified
                         database:(NSString*)databaseUuid
                            error:(NSError**)error {
    return [self setWorkingCache:nil data:data dateModified:dateModified database:databaseUuid error:error];
}

- (NSURL*)setWorkingCache:(NSString*)file
                     data:(NSData*)data
             dateModified:(NSDate*)dateModified
                 database:(NSString*)databaseUuid
                    error:(NSError**)error {
    if ( (!data && !file) || !dateModified) {
        if (error) {
            *error = [Utils createNSError:@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache" errorCode:-1];
        }
        
        NSLog(@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache [%@][%@]", data, dateModified);
        return nil;
    }
    
    
    
    NSURL* localWorkingCacheUrl = [self getLocalWorkingCacheUrlForDatabase2:databaseUuid];
    
    if ( file ) {
        NSURL* fileUrl = [NSURL fileURLWithPath:file];
    
        BOOL success = [NSFileManager.defaultManager replaceItemAtURL:localWorkingCacheUrl withItemAtURL:fileUrl backupItemName:nil options:kNilOptions resultingItemURL:nil error:error];
        if ( !success ) {
            NSLog(@"SyncManager::replaceItemAtURL - failed with %@", error ? *error : nil);
            return nil;
        }
    }
    else {
        [data writeToURL:localWorkingCacheUrl options:NSDataWritingAtomic error:error];
    }
    


    if (*error) {
        return nil;
    }
    else {
        NSError *err2;
        [NSFileManager.defaultManager setAttributes:@{ NSFileModificationDate : dateModified }
                                       ofItemAtPath:localWorkingCacheUrl.path
                                              error:&err2];
        
        NSLog(@"Set Working Cache Attributes for [%@] to [%@] with error = [%@]", databaseUuid, dateModified, err2);
        
        if (err2 && error) {
            *error = err2;
        }
        
        return err2 ? nil : localWorkingCacheUrl;
    }
}

- (void)deleteLocalWorkingCache2:(NSString*)databaseUuid {
    NSURL* localCache = [self getLocalWorkingCache2:databaseUuid];
    
    if (localCache) {
        NSError* error;
        [NSFileManager.defaultManager removeItemAtURL:localCache error:&error];
        
        if (error) {
            NSLog(@"Error delete local working cache: [%@]", error);
        }
    }
}

- (BOOL)isLocalWorkingCacheAvailable2:(NSString*)databaseUuid modified:(NSDate**)modified {
    return [self getLocalWorkingCache2:databaseUuid modified:modified] != nil;
}

- (NSURL*)getLocalWorkingCacheUrlForDatabase2:(NSString*)databaseUuid {
    return [FileManager.sharedInstance.syncManagerLocalWorkingCachesDirectory URLByAppendingPathComponent:databaseUuid];
}

- (NSURL*)getLocalWorkingCache2:(NSString*)databaseUuid {
    return [self getLocalWorkingCache2:databaseUuid modified:nil];
}

- (NSURL*)getLocalWorkingCache2:(NSString*)databaseUuid modified:(NSDate**)modified {
    return [self getLocalWorkingCache2:databaseUuid modified:modified fileSize:nil];
}

- (NSURL*)getLocalWorkingCache2:(NSString*)databaseUuid modified:(NSDate**)modified fileSize:(unsigned long long*_Nullable)fileSize {
    NSURL* url = [self getLocalWorkingCacheUrlForDatabase2:databaseUuid];

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
