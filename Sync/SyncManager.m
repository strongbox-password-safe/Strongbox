//
//  SyncManager.m
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SyncManager.h"
#import "SafesList.h"
#import "SafeStorageProviderFactory.h"
#import "SharedAppAndAutoFillSettings.h"
#import "OfflineDetector.h"
#import "LocalDeviceStorageProvider.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "AppleICloudProvider.h"
#import "FileManager.h"
#import "LocalDatabaseIdentifier.h"
#import "DatabaseModel.h"
#import "Constants.h"
#import "Utils.h"
#import "BackupsManager.h"

@interface SyncManager ()

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) dispatch_source_t source;

@end

@implementation SyncManager

+ (instancetype)sharedInstance {
    static SyncManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SyncManager alloc] init];
    });
    return sharedInstance;
}

//- (void)read:(SafeMetaData *)database completion:(SyncManagerReadCompletionBlock)completion {
//    // Things to think about -
//      Duress Dummy
//
//    NSURL* localCopyUrl = [self getLocalCopyUrl:database];
//
//    if ([NSFileManager.defaultManager fileExistsAtPath:localCopyUrl.path]) {
//         // if this file has a remote then check the date modified, if it's same then immediately return
//        // otherwise pull latest? optional?
//
//        NSInputStream* localStream = [NSInputStream inputStreamWithURL:localCopyUrl];
//        completion(localStream, nil);
//    }
//    else {
//        // Pull from remote / storage provider
//    }
//}

- (void)readLegacy:(SafeMetaData *)database
     legacyOptions:(LegacySyncReadOptions *)legacyOptions
        completion:(SyncManagerReadLegacyCompletionBlock)completion {
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    NSURL* localWorkingCacheUrl = [self getLocalWorkingCacheUrlForDatabase:database];
    NSDate* localModDate = nil;
    if (localWorkingCacheUrl) {
        NSError* error;
        NSDictionary* localAttr = [NSFileManager.defaultManager attributesOfItemAtPath:localWorkingCacheUrl.path error:&error];
        if (!error) {
            localModDate = localAttr.fileModificationDate;
        }
    }
    
    StorageProviderReadOptions* options = [[StorageProviderReadOptions alloc] init];
    options.isAutoFill = legacyOptions.isAutoFill;
    options.onlyIfModifiedDifferentFrom = SharedAppAndAutoFillSettings.sharedInstance.uberSync ? localModDate : nil;
    
    [provider readLegacy:database
          viewController:legacyOptions.vc
                 options:options
              completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        if (result == kReadResultError) {
            NSLog(@"SyncManager::readLegacy - [%@] - Could not read data from provider: [%@]", provider.displayName, error);
            completion(nil, error);
        }
        else if (result == kReadResultModifiedIsSameAsLocal) {
            NSLog(@"SyncManager::readLegacy - [%@] remote modified equal to [%@] using local copy", provider.displayName, localModDate);
            completion(localWorkingCacheUrl, nil);
        }
        else {
            NSLog(@"SyncManager::readLegacy - [%@] Got [%lu] bytes - modified [%@]", provider.displayName, (unsigned long)data.length, dateModified);
            [self onReadWithData:database data:data dateModified:dateModified completion:completion];
        }
    }];
}

- (void)onReadWithData:(SafeMetaData *)database
                  data:(NSData*)data
          dateModified:(NSDate*)dateModified
            completion:(SyncManagerReadLegacyCompletionBlock)completion {
    NSURL* localWorkingCacheUrl = [self getLocalWorkingCacheUrlForDatabase:database];

    NSError* error;
    [data writeToURL:localWorkingCacheUrl options:NSDataWritingAtomic error:&error];
    
    NSLog(@"SyncManager::onReadWithData - Wrote to working file [%@]-[%@]", localWorkingCacheUrl, error);

    if (error) {
        completion(nil, error);
    }
    else {
        [NSFileManager.defaultManager setAttributes:@{ NSFileModificationDate : dateModified }
                                       ofItemAtPath:localWorkingCacheUrl.path
                                              error:&error];
        
        completion(error? nil : localWorkingCacheUrl, error);
    }
}

- (NSString *)getPrimaryStorageDisplayName:(SafeMetaData *)database {
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    return provider.displayName;
}

- (BOOL)isLegacyImmediatelyOfferCacheIfOffline:(SafeMetaData *)database {
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    return provider.immediatelyOfferCacheIfOffline;
}

- (BOOL)isLegacyAutoFillBookmarkSet:(SafeMetaData *)database {
    FilesAppUrlBookmarkProvider* fp = [SafeStorageProviderFactory getStorageProviderFromProviderId:kFilesAppUrlBookmark];
    return [fp autoFillBookMarkIsSet:database];
}

- (void)setLegacyAutoFillBookmark:(SafeMetaData *)database bookmark:(NSData *)bookmark {
    FilesAppUrlBookmarkProvider* fp = [SafeStorageProviderFactory getStorageProviderFromProviderId:kFilesAppUrlBookmark];
    
    database = [fp setAutoFillBookmark:bookmark metadata:database];
    
    [SafesList.sharedInstance update:database];
}

- (void)update:(SafeMetaData *)database data:(NSData *)encrypted {
    // Check is database is readonly and bail early - definitely no writing
    // Duress Dummy
}

- (void)updateLegacy:(SafeMetaData *)database
                data:(NSData *)data
       legacyOptions:(LegacySyncReadOptions *)legacyOptions
          completion:(SyncManagerUpdateLegacyCompletionBlock)completion {
    if (database.readOnly) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1];
        completion(error);
        return;
    }

    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    [provider update:database data:data isAutoFill:legacyOptions.isAutoFill completion:^(NSError * _Nullable error) {
        if (error) {
            completion(error);
        }

        [self onUpdatedRemoteSuccessfully:database data:data completion:completion];
    }];
}

- (void)onUpdatedRemoteSuccessfully:(SafeMetaData *)database
                               data:(NSData *)data
                         completion:(SyncManagerUpdateLegacyCompletionBlock)completion {
    NSURL* localWorkingCache = [self getLocalWorkingCache:database];
    
    // Perform local Backups
    
    if (localWorkingCache == nil ||
        ![BackupsManager.sharedInstance writeBackup:localWorkingCache metadata:database]) {
        // This should not be possible, something is very wrong if it is, because we will have loaded model
        NSLog(@"WARNWARN: Local Working Cache unavailable or could not write backup: [%@]", localWorkingCache);
        NSString* em = NSLocalizedString(@"model_error_cannot_write_backup", @"Could not write backup, will not proceed with write of database!");
        NSError* error = [Utils createNSError:em errorCode:-1];
        completion(error);
        return;
    }

    // Update Local Working Cache
    
    NSError* error;
    [data writeToURL:localWorkingCache options:NSDataWritingAtomic error:&error];
    if (error) {
        NSLog(@"ERROR: Could not update local working cache: [%@]", localWorkingCache);
        completion(error);
        return;
    }
 
    completion(nil); // Done
}

- (void)removeDatabaseAndLocalCopies:(SafeMetaData*)database {
    if (database.storageProvider == kLocalDevice) {
        [[LocalDeviceStorageProvider sharedInstance] delete:database completion:nil];
    }
    else if (database.storageProvider == kiCloud) {
        [[AppleICloudProvider sharedInstance] delete:database completion:nil];
    }

    [self deleteLocalWorkingCache:database];
}

///////////////////////////////

// TODO: can this model be used to pick up Auto-Fill writes in new uber sync system?! DISPATCH_VNODE_ATTRIB?

- (void)startMonitoringDocumentsDirectory {
    NSString * homeDirectory = FileManager.sharedInstance.documentsDirectory.path;
    
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    _dispatchQueue = dispatch_queue_create("FileMonitorQueue", 0);
    
    // Write covers - adding a file, renaming a file and deleting a file...
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, filedes, DISPATCH_VNODE_WRITE, _dispatchQueue);
    
    dispatch_source_set_event_handler(_source, ^(){
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            NSLog(@"File Change Detected! Scanning for New Safes");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self syncLocalSafesWithFileSystem];
            });
        });
    });
        
    dispatch_source_set_cancel_handler(_source, ^() {
        close(filedes);
    });
    
    dispatch_resume(_source);
        
    [self syncLocalSafesWithFileSystem];
}

- (void)stopMonitoringDocumentsDirectory {
    dispatch_source_cancel(_source);
}

- (NSArray<StorageBrowserItem *>*)scanForNewDatabases {
    NSArray<SafeMetaData*> * localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    NSMutableSet *existing = [NSMutableSet set];
    for (SafeMetaData* safe in localSafes) {
        LocalDatabaseIdentifier* identifier = [self getLegacyLocalDatabaseStorageIdentifier:safe];
        if(identifier && !identifier.sharedStorage) {
            [existing addObject:identifier.filename];
        }
    }
    
    NSError* error;
    NSArray<StorageBrowserItem *> *items = [self getDocumentFiles:&error];
    NSMutableArray<StorageBrowserItem *> *newSafes = [NSMutableArray array];
    
    if(items) {
        for (StorageBrowserItem *item in items) {
            if(!item.folder && ![existing containsObject:item.name]) {
                NSURL *url = [FileManager.sharedInstance.documentsDirectory URLByAppendingPathComponent:item.name];

                if([DatabaseModel isValidDatabase:url error:&error]) {
                    NSLog(@"New File: [%@] is a valid database", item.name);
                    [newSafes addObject:item];
                }
                else {
                    //NSLog(@"None Safe File:%@ is a not valid safe", item.name);
                }
            }
        }
    }
    else {
        NSLog(@"Error Scanning for New Files. List Root: %@", error);
    }
    
    return newSafes;
}

- (NSArray<StorageBrowserItem*>*)getDocumentFiles:(NSError**)ppError {
    NSError *error;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:FileManager.sharedInstance.documentsDirectory.path
                                                                                    error:&error];
    
    if (error) {
        *ppError = error;
        return nil;
    }
    
    NSMutableArray<StorageBrowserItem*>* items = [NSMutableArray array];
    for (NSString* file in directoryContent) {
        StorageBrowserItem* browserItem = [[StorageBrowserItem alloc] init];
        
        BOOL isDirectory;
        NSString *fullPath = [FileManager.sharedInstance.documentsDirectory.path stringByAppendingPathComponent:file];
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        if(exists) {
            browserItem.folder = isDirectory != 0;
            browserItem.name = file;
            
            LocalDatabaseIdentifier *identifier = [[LocalDatabaseIdentifier alloc] init];
            identifier.sharedStorage = NO;
            identifier.filename = file;
            
            browserItem.providerData = identifier;
            
            [items addObject:browserItem];
        }
    }
    
    return items;
}

- (void)syncLocalSafesWithFileSystem {
    // Add any new
    NSArray<StorageBrowserItem*> *items = [self scanForNewDatabases];
    
    for(StorageBrowserItem* item in items) {
        NSString* name = [SafesList sanitizeSafeNickName:[item.name stringByDeletingPathExtension]];
        SafeMetaData *safe = [LocalDeviceStorageProvider.sharedInstance getSafeMetaData:name
                                                                           providerData:item.providerData];
        [[SafesList sharedInstance] addWithDuplicateCheck:safe];
    }
    
    // Remove deleted
    
    NSArray<SafeMetaData*> *localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    
    for (SafeMetaData* localSafe in localSafes) {
        NSURL* url = [self getLegacyLocalDatabaseFileUrl:localSafe];
        if(![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
            NSLog(@"Removing Safe [%@] because underlying file [%@] no longer exists in Documents Directory.", localSafe.nickName, localSafe.fileName);
            [SafesList.sharedInstance remove:localSafe.uuid];
        }
    }
}

- (BOOL)toggleLocalDatabaseFilesVisibility:(SafeMetaData*)metadata error:(NSError**)error {
    LocalDatabaseIdentifier* identifier = [self getLegacyLocalDatabaseStorageIdentifier:metadata];

    NSURL* src = [self getLegacyLocalDatabaseFileUrl:identifier.sharedStorage filename:identifier.filename];
    NSURL* dest = [self getLegacyLocalDatabaseFileUrl:!identifier.sharedStorage filename:identifier.filename];

    int i=0;
    NSString* extension = [identifier.filename pathExtension];
    NSString* baseFileName = [identifier.filename stringByDeletingPathExtension];
    
    // Avoid Race Conditions
    
    [self stopMonitoringDocumentsDirectory];
    
    while ([[NSFileManager defaultManager] fileExistsAtPath:dest.path]) {
        identifier.filename = [[baseFileName stringByAppendingFormat:@"-%d", i] stringByAppendingPathExtension:extension];
        
        dest = [self getLegacyLocalDatabaseFileUrl:!identifier.sharedStorage filename:identifier.filename];
        
        NSLog(@"File exists at destination... Trying: [%@]", dest);
    }
    
    if(![NSFileManager.defaultManager moveItemAtURL:src toURL:dest error:error]) {
        NSLog(@"Error moving local file: [%@]", *error);
        [self startMonitoringDocumentsDirectory];
        return NO;
    }
    else {
        NSLog(@"OK - Moved local file: [%@] -> [%@]", src, dest);
    }
    
    identifier.sharedStorage = !identifier.sharedStorage;
    
    metadata.fileIdentifier = [identifier toJson];
    metadata.fileName = identifier.filename;

    [SafesList.sharedInstance update:metadata];
    
    [self startMonitoringDocumentsDirectory];
    
    return YES;
}

- (LocalDatabaseIdentifier*)getLegacyLocalDatabaseStorageIdentifier:(SafeMetaData*)metaData {
    NSString* json = metaData.fileIdentifier;
    return [LocalDatabaseIdentifier fromJson:json];
}

- (NSURL*)getLegacyLocalDatabaseDirectory:(BOOL)shared {
    return shared ? FileManager.sharedInstance.sharedAppGroupDirectory : FileManager.sharedInstance.documentsDirectory;
}

- (NSURL*)getLegacyLocalDatabaseFileUrl:(SafeMetaData*)safeMetaData {
    LocalDatabaseIdentifier* identifier = [self getLegacyLocalDatabaseStorageIdentifier:safeMetaData];
    return identifier ? [self getLegacyLocalDatabaseFileUrl:identifier.sharedStorage filename:identifier.filename] : nil;
}

- (NSURL*)getLegacyLocalDatabaseFileUrl:(BOOL)sharedStorage filename:(NSString*)filename {
    NSURL* folder = [self getLegacyLocalDatabaseDirectory:sharedStorage];
    return [folder URLByAppendingPathComponent:filename];
}

///////////////////////////////////////////////////////////////////////

- (void)deleteLocalWorkingCache:(SafeMetaData*)database {
    NSURL* localCache = [self getLocalWorkingCache:database];
    
    if (localCache) {
        NSError* error;
        [NSFileManager.defaultManager removeItemAtURL:localCache error:&error];
        
        if (error) {
            NSLog(@"Error delete local working cache: [%@]", error);
        }
    }
}

- (BOOL)isLocalWorkingCacheAvailable:(SafeMetaData *)database modified:(NSDate**)modified {
    return [self getLocalWorkingCache:database modified:modified] != nil;
}

- (NSURL*)getLocalWorkingCacheUrlForDatabase:(SafeMetaData*)database {
    return [FileManager.sharedInstance.syncManagerLocalWorkingCachesDirectory URLByAppendingPathComponent:database.uuid];
}

- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database {
    return [self getLocalWorkingCache:database modified:nil];
}

- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate**)modified {
    NSURL* url = [self getLocalWorkingCacheUrlForDatabase:database];

    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error) {
        //NSLog(@"Could not get local working cache at [%@]-[%@]", url, error);
        if (modified) {
            *modified = nil;
        }
        return nil;
    }

    if (modified) {
        *modified = attributes.fileModificationDate;
    }

    return url;
}

/////////////////////////////////////////////////////////////////////////
// Migration

@end



    
    //    if (provider.storageId == kLocalDevice) {
    //        NSURL* directCopyUrl = [LocalDeviceStorageProvider.sharedInstance getDirectUrlDeleteMe:database]; //  Errors and make conventional
    //
    //        [self deleteLocalWorkingCache:database];
    //
    //        NSError* error;
    //        [NSFileManager.defaultManager copyItemAtURL:directCopyUrl toURL:localWorkingCacheUrl error:&error]; //  Check error
    //
    //        NSLog(@"SyncManager::readLegacy - [%@] Copied to working file [%@]-[%@]", provider.displayName, localWorkingCacheUrl, error);
    //
    //        if (error) {
    //            completion(nil, error);
    //        }
    //        else {
    //            completion(localWorkingCacheUrl, nil);
    //        }
    //    }
    //    else {
//      }
