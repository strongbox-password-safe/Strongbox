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
#import "SyncStatus.h"
#import "SharedAppAndAutoFillSettings.h"

NSString* const kSyncManagerDatabaseSyncStatusChanged = @"syncManagerDatabaseSyncStatusChanged";

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

- (void)backgroundSyncOutstandingUpdates {
    for (SafeMetaData* database in SafesList.sharedInstance.snapshot) {
        if (database.outstandingUpdateId) {
            [self backgroundSyncDatabase:database];
        }
    }
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
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.inProgressBehaviour = kInProgressBehaviourJoin;
    [SyncAndMergeSequenceManager.sharedInstance enqueueSync:database parameters:params completion:^(SyncAndMergeResult result, BOOL conflictAndLocalWasChanged, const NSError * _Nullable error) {
        NSLog(@"BACKGROUND SYNC DONE: [%@] - [%@][%@]", database.nickName, syncResultToString(result), error);
    }];
}

- (void)sync:(SafeMetaData *)database interactiveVC:(UIViewController *)interactiveVC join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion {
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.interactiveVC = interactiveVC;
    params.inProgressBehaviour = join ? kInProgressBehaviourJoin : kInProgressBehaviourEnqueueAnotherSync;
    
    [SyncAndMergeSequenceManager.sharedInstance enqueueSync:database parameters:params completion:^(SyncAndMergeResult result, BOOL conflictAndLocalWasChanged, const NSError * _Nullable error) {
        NSLog(@"INTERACTIVE SYNC DONE: [%@] - [%@][%@]", database.nickName, syncResultToString(result), error);
        completion(result, conflictAndLocalWasChanged, error);
    }];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(SafeMetaData *)database data:(NSData *)data error:(NSError**)error {
    NSURL* localWorkingCache = [self getLocalWorkingCache:database];
    
    if (localWorkingCache) {
        if(![BackupsManager.sharedInstance writeBackup:localWorkingCache metadata:database]) {
            // This should not be possible, something is very wrong if it is, because we will have loaded model
            NSLog(@"WARNWARN: Local Working Cache unavailable or could not write backup: [%@]", localWorkingCache);
            NSString* em = NSLocalizedString(@"model_error_cannot_write_backup", @"Could not write backup, will not proceed with write of database!");
            
            if(error) {
                *error = [Utils createNSError:em errorCode:-1];
            }
            return NO;
        }
    }
    
    NSUUID* updateId = NSUUID.UUID;
    database.outstandingUpdateId = updateId;
    [SafesList.sharedInstance update:database];
        
    NSURL* url = [self setWorkingCacheWithData:data dateModified:NSDate.date database:database error:error];
    
    return url != nil;
}

- (SyncStatus*)getSyncStatus:(SafeMetaData *)database {
    return [SyncAndMergeSequenceManager.sharedInstance getSyncStatus:database];
}

//////////////////////

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
    return [SafeStorageProviderFactory getStorageDisplayName:database];
}

- (BOOL)isLegacyImmediatelyOfferLocalCopyIfOffline:(SafeMetaData *)database { // TODO: This should be a database property - smart set initially based on provider but ultimately configurable... and doesn't belogn in here but in the OpenSequenceManager
#ifndef IS_APP_EXTENSION
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    return provider.immediatelyOfferCacheIfOffline;
#else
    return NO; // TODO: Remove this from SafeStorageProvider
#endif
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

//////////

static NSString* syncResultToString(SyncAndMergeResult result) {
    switch(result) {
        case kSyncAndMergeError:
            return @"Error";
            break;
        case kSyncAndMergeSuccess:
            return @"Success";
            break;
        case kSyncAndMergeResultUserInteractionRequired:
            return @"User Interaction Required";
            break;
        case kSyncAndMergeResultUserCancelled:
            return @"User Cancelled";
            break;
        default:
            return @"Unknown!";
    }
}

@end
