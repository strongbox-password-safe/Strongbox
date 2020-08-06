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
#import "ConcurrentMutableDictionary.h"
#import "SyncOperationInfo.h"
#import "SharedAppAndAutoFillSettings.h"

NSString* const kSyncManagerDatabaseSyncStatusChanged = @"syncManagerDatabaseSyncStatusChanged";

@interface SyncManager ()

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) dispatch_source_t source;
@property ConcurrentMutableDictionary<NSString*, SyncOperationInfo*>* syncOperations;

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

- (instancetype)init {
    self = [super init];
    if (self) {
        self.syncOperations = ConcurrentMutableDictionary.mutableDictionary;
    }
    return self;
}

- (void)backgroundSyncAll {
    for (SafeMetaData* database in SafesList.sharedInstance.snapshot) {
        [self backgroundSyncDatabase:database];
    }
}

- (void)backgroundSyncLocalDeviceDatabasesOnly {
    for (SafeMetaData* database in SafesList.sharedInstance.snapshot) {
        if (database.storageProvider == kLocalDevice) {
            [self backgroundSyncDatabase:database];
        }
    }
}

- (void)backgroundSyncDatabase:(SafeMetaData*)database {
    SyncReadOptions* readOptions = [[SyncReadOptions alloc] init];
    readOptions.isAutoFill = NO; // TODO: ?! No background sync done from autofill component?
    readOptions.vc = nil; // Indicates to provider this is a background sync

    [self queuePullFromRemote:database readOptions:readOptions completion:^(NSURL * _Nullable url, BOOL previousSyncAlreadyInProgress, const NSError * _Nullable error) {
        NSLog(@"Background Sync Done - [%@] - previousSyncAlreadyInProgress [%d] - error: [%@]", database.nickName, previousSyncAlreadyInProgress, error);
    }];
}

//////////////////////

- (void)queuePullFromRemote:(SafeMetaData *)database
                readOptions:(SyncReadOptions *)options
                 completion:(SyncManagerReadCompletionBlock)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self pullFromRemote:database readOptions:options completion:completion];
    });
}

- (void)pullFromRemote:(SafeMetaData *)database
           readOptions:(SyncReadOptions *)options
            completion:(SyncManagerReadCompletionBlock)completion {
    // TODO: Have a separate queue per database?
    // and queue the sync instead - max one outstanding sync to do from local / remote
    // This might be optional, like a read sync, pull from remote doesn't need to be queued
    // but a write from the model/UI should definitely be queued... (Max 1 outstanding in queue)
    
    SyncOperationInfo* info = [self.syncOperations objectForKey:database.uuid];
    
    if (info != nil && info.state == kSyncOperationStateInProgress) {
        NSLog(@"Database [%@] is already undergoing a sync operation...", database.nickName);

        if (options.joinInProgressSync) {
            NSLog(@"XXXXXX - Joining in progress sync...");
            
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L);
            
            dispatch_group_notify(info.inProgressDispatchGroup, queue, ^{
                NSURL* url = [self getLocalWorkingCache:database];

                NSLog(@"XXXXXX - In Progress Sync Done with [%@]... Calling waiting completion...", info);

                completion(info.error ? nil : url, NO, info.error);
            });
        }
        else {
            NSLog(@"XXXXXX - NOT Joining in progress sync...");

            completion(nil, YES, nil);
        }
        return;
    }

    info = [[SyncOperationInfo alloc] initWithDatabaseId:database.uuid];
    info.state = kSyncOperationStateInProgress;
    info.inProgressDispatchGroup = dispatch_group_create();

    dispatch_group_enter(info.inProgressDispatchGroup);

    [self.syncOperations setObject:info forKey:database.uuid];

    [self publishSyncStatusChangeNotification:info];

    [self pullDatabase:database info:info readOptions:options completion:completion];
}

- (void)pullDatabase:(SafeMetaData *)database
                info:(SyncOperationInfo*)info
         readOptions:(SyncReadOptions *)options
          completion:(SyncManagerReadCompletionBlock)completion {
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
    
    StorageProviderReadOptions* opts = [[StorageProviderReadOptions alloc] init];
    opts.isAutoFill = options.isAutoFill;
    opts.onlyIfModifiedDifferentFrom = SharedAppAndAutoFillSettings.sharedInstance.syncPullEvenIfModifiedDateSame ? nil : localModDate;
    
    [provider pullDatabase:database
             interactiveVC:options.vc
                   options:opts
                completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        NSLog(@"syncFromRemoteOverwriteLocal done with: [%@]", error);
                
        info.state = result == kReadResultError ? kSyncOperationStateError : (result == kReadResultBackgroundReadButUserInteractionRequired) ? kSyncOperationStateBackgroundButUserInteractionRequired : kSyncOperationStateDone;
        info.error = (NSError*)error;
        
        if (result == kReadResultError) {
            NSLog(@"SyncManager::syncFromRemoteOverwriteLocal - [%@] - Could not read data from provider: [%@]", provider.displayName, error);
        
            [self publishSyncStatusChangeNotification:info];
            
            completion(nil, NO, error);
        }
        else if (result == kReadResultBackgroundReadButUserInteractionRequired) {
            NSLog(@"SyncManager::syncFromRemoteOverwriteLocal - [%@] remote modified equal to [%@] using local copy", provider.displayName, localModDate);

            [self publishSyncStatusChangeNotification:info];
            
            completion(localWorkingCacheUrl, NO, nil);
        }
        else if (result == kReadResultModifiedIsSameAsLocal) {
            NSLog(@"SyncManager::syncFromRemoteOverwriteLocal - [%@] remote modified equal to [%@] using local copy", provider.displayName, localModDate);

            [self publishSyncStatusChangeNotification:info];
            
            completion(localWorkingCacheUrl, NO, nil);
        }
        else {
            NSLog(@"SyncManager::syncFromRemoteOverwriteLocal - [%@] Got [%lu] bytes - modified [%@]", provider.displayName, (unsigned long)data.length, dateModified);

            NSError* error;
            
            NSURL* localWorkingCacheUrl = [self setWorkingCacheWithData:data dateModified:dateModified database:database error:&error];
         
            [self publishSyncStatusChangeNotification:info]; // Don't call until working cache has been set
            
            completion(error ? nil : localWorkingCacheUrl, NO, error);
        }
        
        dispatch_group_leave(info.inProgressDispatchGroup);
    }];
}

- (void)syncFromLocalAndOverwriteRemote:(SafeMetaData *)database
                                   data:(NSData *)data
                          updateOptions:(SyncReadOptions *)updateOptions
                             completion:(SyncManagerUpdateCompletionBlock)completion {
    if (database.readOnly) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1];
        completion(error);
        return;
    }

    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    [provider pushDatabase:database
      interactiveVC:updateOptions.vc
                data:data
          isAutoFill:updateOptions.isAutoFill
          completion:^(NSError * _Nullable error) {
        if (error) {
            completion(error);
        }

        [self onUpdatedRemoteSuccessfully:database data:data completion:completion];
    }];
}

- (void)onUpdatedRemoteSuccessfully:(SafeMetaData *)database
                               data:(NSData *)data
                         completion:(SyncManagerUpdateCompletionBlock)completion {
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

//////////////////////

- (void)publishSyncStatusChangeNotification:(SyncOperationInfo*)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSyncManagerDatabaseSyncStatusChanged object:info];
    });
}

- (SyncOperationInfo*)getSyncStatus:(SafeMetaData *)database {
    SyncOperationInfo *ret = [self.syncOperations objectForKey:database.uuid];

    return ret ? ret : [[SyncOperationInfo alloc] initWithDatabaseId:database.uuid];
}

- (NSURL*)setWorkingCacheWithData:(NSData*)data dateModified:(NSDate*)dateModified database:(SafeMetaData*)database error:(NSError**)error {
    if (!data || !dateModified) {
        if (error) {
            *error = [Utils createNSError:@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache" errorCode:-1];
        }
        
        NSLog(@"SyncManager::setWorkingCacheWithData - WARNWARN data or dateModified nil - not setting working cache [%@][%@]", data, dateModified);
        return nil;
    }
    
    NSURL* localWorkingCacheUrl = [self getLocalWorkingCacheUrlForDatabase:database];

    [data writeToURL:localWorkingCacheUrl options:NSDataWritingAtomic error:error];
    
    NSLog(@"SyncManager::setWorkingCacheWithData - Wrote to working file [%@]-[%@]", localWorkingCacheUrl, *error);

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
        
        NSURL *url = [FileManager.sharedInstance.documentsDirectory URLByAppendingPathComponent:item.name];
        NSData* snapshot = [NSData dataWithContentsOfURL:url];
        
        NSError* error;
        NSDictionary *att = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        
        [[SafesList sharedInstance] addWithDuplicateCheck:safe initialCache:snapshot initialCacheModDate:att.fileModificationDate];
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
    
    // Pick up any updates and notify...
    
    [SyncManager.sharedInstance backgroundSyncLocalDeviceDatabasesOnly];
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
    return [self getLocalWorkingCache:database modified:modified fileSize:nil];
}

- (NSURL*)getLocalWorkingCache:(SafeMetaData*)database modified:(NSDate**)modified fileSize:(unsigned long long*_Nullable)fileSize {
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

    if (fileSize) {
        *fileSize = attributes.fileSize;
    }
    
    return url;
}

@end
