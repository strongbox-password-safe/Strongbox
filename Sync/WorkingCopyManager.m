//
//  WorkingCopyManager.m
//  Strongbox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "WorkingCopyManager.h"
#import "Utils.h"

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

@implementation WorkingCopyManager

+ (instancetype)sharedInstance {
    static WorkingCopyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WorkingCopyManager alloc] init];
    });
    return sharedInstance;
}

- (NSURL *)setWorkingCacheWithFile:(NSString *)file
                      dateModified:(NSDate *)dateModified
                          database:(NSString *)databaseUuid
                             error:(NSError *__autoreleasing  _Nullable *)error {
    return [self setWorkingCache:file data:nil dateModified:dateModified database:databaseUuid error:error];
}

- (NSURL*)setWorkingCacheWithData:(NSData*)data
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
        
        slog(@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache [%@][%@]", data, dateModified);
        return nil;
    }
    
    
    
    NSURL* localWorkingCacheUrl = [self getLocalWorkingCacheUrlForDatabase:databaseUuid];
    
    if ( file ) {
        NSURL* fileUrl = [NSURL fileURLWithPath:file];
    
        BOOL success = [NSFileManager.defaultManager replaceItemAtURL:localWorkingCacheUrl withItemAtURL:fileUrl backupItemName:nil options:kNilOptions resultingItemURL:nil error:error];
        if ( !success ) {
            slog(@"SyncManager::replaceItemAtURL - failed with %@", error ? *error : nil);
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
        

        
        if (err2 && error) {
            *error = err2;
        }
        
        return err2 ? nil : localWorkingCacheUrl;
    }
}

- (void)deleteLocalWorkingCache:(NSString*)databaseUuid {
    NSURL* localCache = [self getLocalWorkingCache:databaseUuid];
    
    if (localCache) {
        NSError* error;
        [NSFileManager.defaultManager removeItemAtURL:localCache error:&error];
        
        if (error) {
            slog(@"Error delete local working cache: [%@]", error);
        }
    }
}

- (BOOL)isLocalWorkingCacheAvailable:(NSString*)databaseUuid modified:(NSDate**)modified {
    return [self getLocalWorkingCache:databaseUuid modified:modified] != nil;
}

- (NSURL*)getLocalWorkingCacheUrlForDatabase:(NSString*)databaseUuid {
    if ( databaseUuid == nil ) {
        slog(@"🔴 databaseUuid is nil in WorkingCopyManager::getLocalWorkingCacheUrlForDatabase?!");
        return nil;
    }
    
    return [StrongboxFilesManager.sharedInstance.syncManagerLocalWorkingCachesDirectory URLByAppendingPathComponent:databaseUuid];
}

- (NSURL*)getLocalWorkingCache:(NSString*)databaseUuid {
    return [self getLocalWorkingCache:databaseUuid modified:nil];
}

- (NSURL*)getLocalWorkingCache:(NSString*)databaseUuid modified:(NSDate**)modified {
    return [self getLocalWorkingCache:databaseUuid modified:modified fileSize:nil];
}

- (NSURL*)getLocalWorkingCache:(NSString*)databaseUuid modified:(NSDate**)modified fileSize:(unsigned long long*_Nullable)fileSize {
    NSURL* url = [self getLocalWorkingCacheUrlForDatabase:databaseUuid];

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

- (NSDate *)getModDate:(NSString *)databaseUuid {
    NSDate* ret = nil;
    
    [self getLocalWorkingCache:databaseUuid modified:&ret];
    
    return ret;
}

@end
