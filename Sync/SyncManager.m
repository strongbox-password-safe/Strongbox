//
//  SyncManager.m
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncManager.h"
#import "SafesList.h"
#import "SafeStorageProviderFactory.h"
#import "AppPreferences.h"
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
#import "AppPreferences.h"
#import "Serializator.h"
#import "WorkingCopyManager.h"

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
    [self backgroundSyncDatabase:database join:YES];
}

- (void)backgroundSyncDatabase:(SafeMetaData*)database join:(BOOL)join {
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.inProgressBehaviour = join ? kInProgressBehaviourJoin : kInProgressBehaviourEnqueueAnotherSync;
    params.syncForcePushDoNotCheckForConflicts = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    params.syncPullEvenIfModifiedDateSame = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;

    NSLog(@"BACKGROUND SYNC Start: [%@]", database.nickName);

    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        NSLog(@"BACKGROUND SYNC DONE: [%@] - [%@][%@]", database.nickName, syncResultToString(result), error);
    }];
}

- (void)sync:(SafeMetaData *)database interactiveVC:(UIViewController *)interactiveVC key:(CompositeKeyFactors*)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion {
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.interactiveVC = interactiveVC;
    params.key = key;
    params.inProgressBehaviour = join ? kInProgressBehaviourJoin : kInProgressBehaviourEnqueueAnotherSync;
    params.syncForcePushDoNotCheckForConflicts = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    params.syncPullEvenIfModifiedDateSame = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;

    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        NSLog(@"INTERACTIVE SYNC DONE: [%@] - [%@][%@]", database.nickName, syncResultToString(result), error);
        completion(result, localWasChanged, error);
    }];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(SafeMetaData *)database file:(NSString *)file error:(NSError **)error {
    return [self updateLocalCopyMarkAsRequiringSync:database data:nil file:file error:error];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(SafeMetaData *)database data:(NSData *)data error:(NSError**)error {
    return [self updateLocalCopyMarkAsRequiringSync:database data:data file:nil error:error];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(SafeMetaData *)database data:(NSData *)data file:(NSString *)file error:(NSError**)error {
    
    
    NSURL* localWorkingCache = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    if (localWorkingCache) {
        if(![BackupsManager.sharedInstance writeBackup:localWorkingCache metadata:database]) {
            
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
        
    NSURL* url;
    if ( file ) {
        url = [WorkingCopyManager.sharedInstance setWorkingCacheWithFile:file
                                                            dateModified:NSDate.date
                                                                database:database.uuid
                                                                   error:error];
    }
    else {
        url = [WorkingCopyManager.sharedInstance setWorkingCacheWithData:data
                                                             dateModified:NSDate.date
                                                                 database:database.uuid
                                                                    error:error];
    }
    
    return url != nil;
}

- (SyncStatus*)getSyncStatus:(SafeMetaData *)database {
    return [SyncAndMergeSequenceManager.sharedInstance getSyncStatusForDatabaseId:database.uuid];
}



- (NSString *)getPrimaryStorageDisplayName:(SafeMetaData *)database {
    return [SafeStorageProviderFactory getStorageDisplayName:database];
}

- (void)removeDatabaseAndLocalCopies:(SafeMetaData*)database {
    if (database.storageProvider == kLocalDevice) {
        [[LocalDeviceStorageProvider sharedInstance] delete:database completion:nil];
    }
    else if (database.storageProvider == kiCloud) {
        [[AppleICloudProvider sharedInstance] delete:database completion:nil];
    }

    [WorkingCopyManager.sharedInstance deleteLocalWorkingCache:database.uuid];
    
    [database clearKeychainItems];
}




- (void)startMonitoringDocumentsDirectory {
    NSString * homeDirectory = FileManager.sharedInstance.documentsDirectory.path;
    
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    _dispatchQueue = dispatch_queue_create("FileMonitorQueue", 0);
    
    
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

                if([Serializator isValidDatabase:url error:&error]) {
                    NSLog(@"New File: [%@] is a valid database", item.name);
                    [newSafes addObject:item];
                }
                else {
                    
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
        if ( ppError ) {
            *ppError = error;
        }
        return nil;
    }
    
    NSMutableArray<StorageBrowserItem*>* items = [NSMutableArray array];
    for (NSString* file in directoryContent) {
        BOOL isDirectory;
        NSString *fullPath = [FileManager.sharedInstance.documentsDirectory.path stringByAppendingPathComponent:file];
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        if(exists) {
            LocalDatabaseIdentifier *identifier = [[LocalDatabaseIdentifier alloc] init];
            identifier.sharedStorage = NO;
            identifier.filename = file;
            
            StorageBrowserItem *browserItem = [StorageBrowserItem itemWithName:file identifier:nil folder:isDirectory != 0 providerData:identifier];
            [items addObject:browserItem];
        }
    }
    
    return items;
}

- (void)syncLocalSafesWithFileSystem {
    
    NSArray<StorageBrowserItem*> *items = [self scanForNewDatabases];
    
    for(StorageBrowserItem* item in items) {
        NSString* name = [SafesList trimDatabaseNickName:[item.name stringByDeletingPathExtension]];
        SafeMetaData *safe = [LocalDeviceStorageProvider.sharedInstance getSafeMetaData:name
                                                                           providerData:item.providerData];
        
        NSURL *url = [FileManager.sharedInstance.documentsDirectory URLByAppendingPathComponent:item.name];
        NSData* snapshot = [NSData dataWithContentsOfURL:url];
        
        NSError* error;
        NSDictionary *att = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        
        [[SafesList sharedInstance] addWithDuplicateCheck:safe initialCache:snapshot initialCacheModDate:att.fileModificationDate];
    }
    
    
    
    NSArray<SafeMetaData*> *localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    
    for (SafeMetaData* localSafe in localSafes) {
        NSURL* url = [self getLegacyLocalDatabaseFileUrl:localSafe];
        if(![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
            NSLog(@"WARNWARN: Database [%@] underlying file [%@] no longer exists in Documents Directory.", localSafe.nickName, localSafe.fileName);
            
            
            
            
        }
    }
    
    
    
    [SyncManager.sharedInstance backgroundSyncLocalDeviceDatabasesOnly];
}

- (BOOL)toggleLocalDatabaseFilesVisibility:(SafeMetaData*)metadata error:(NSError**)error {
    LocalDatabaseIdentifier* identifier = [self getLegacyLocalDatabaseStorageIdentifier:metadata];

    NSURL* src = [self getLegacyLocalDatabaseFileUrl:identifier.sharedStorage filename:identifier.filename];
    NSURL* dest = [self getLegacyLocalDatabaseFileUrl:!identifier.sharedStorage filename:identifier.filename];

    int i=0;
    NSString* extension = [identifier.filename pathExtension];
    NSString* baseFileName = [identifier.filename stringByDeletingPathExtension];
    
    
    
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

@end
