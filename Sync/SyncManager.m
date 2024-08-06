//
//  SyncManager.m
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncManager.h"
#import "DatabasePreferences.h"
#import "SafeStorageProviderFactory.h"
#import "AppPreferences.h"
#import "OfflineDetector.h"
#import "LocalDeviceStorageProvider.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "StrongboxiOSFilesManager.h"
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

@property (nonatomic, strong) dispatch_queue_t wcDispatchQueue;
@property (nonatomic, strong) dispatch_source_t wcSource;

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
    for (DatabasePreferences* database in DatabasePreferences.allDatabases) {
        if (database.outstandingUpdateId) {
            [self backgroundSyncDatabase:database];
        }
    }
}

- (void)backgroundSyncAll {
    for (DatabasePreferences* database in DatabasePreferences.allDatabases) {
        [self backgroundSyncDatabase:database];
    }
}

- (void)backgroundSyncLocalDeviceDatabasesOnly {
    for (DatabasePreferences* database in DatabasePreferences.allDatabases) {
        if (database.storageProvider == kLocalDevice) {
            [self backgroundSyncDatabase:database];
        }
    }
}

- (void)backgroundSyncDatabase:(DatabasePreferences*)database {
    [self backgroundSyncDatabase:database join:YES];
}

- (void)backgroundSyncDatabase:(DatabasePreferences*)database join:(BOOL)join {
    [self backgroundSyncDatabase:database join:join key:nil completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError *  error) { }];
}

- (void)backgroundSyncDatabase:(DatabasePreferences*)database join:(BOOL)join key:(CompositeKeyFactors*_Nullable)key completion:(SyncAndMergeCompletionBlock)completion {
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.inProgressBehaviour = join ? kInProgressBehaviourJoin : kInProgressBehaviourEnqueueAnotherSync;
    params.syncForcePushDoNotCheckForConflicts = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    params.syncPullEvenIfModifiedDateSame = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;
    params.key = key;
    
    slog(@"🟢 BACKGROUND SYNC Start: [%@]", database.nickName);

    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        slog(@"🟢 BACKGROUND SYNC DONE: [%@] - [%@] - workingCacheWasChanged = %hhd - [%@]", database.nickName, syncResultToString(result), localWasChanged, error);
        completion(result, localWasChanged, error);
    }];
}

- (void)sync:(DatabasePreferences *)database 
interactiveVC:(UIViewController *)interactiveVC
         key:(CompositeKeyFactors*)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion {
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.interactiveVC = interactiveVC;
    params.key = key;
    params.inProgressBehaviour = join ? kInProgressBehaviourJoin : kInProgressBehaviourEnqueueAnotherSync;
    params.syncForcePushDoNotCheckForConflicts = AppPreferences.sharedInstance.syncForcePushDoNotCheckForConflicts;
    params.syncPullEvenIfModifiedDateSame = AppPreferences.sharedInstance.syncPullEvenIfModifiedDateSame;

    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        slog(@"INTERACTIVE SYNC DONE: [%@] - [%@][%@]", database.nickName, syncResultToString(result), error);
        completion(result, localWasChanged, error);
    }];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabasePreferences *)database file:(NSString *)file error:(NSError **)error {
    return [self updateLocalCopyMarkAsRequiringSync:database data:nil file:file error:error];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabasePreferences *)database data:(NSData *)data error:(NSError**)error {
    return [self updateLocalCopyMarkAsRequiringSync:database data:data file:nil error:error];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabasePreferences *)database data:(NSData *)data file:(NSString *)file error:(NSError**)error {
    
    
    NSURL* localWorkingCache = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    if (localWorkingCache) {
        if(![BackupsManager.sharedInstance writeBackup:localWorkingCache metadata:database]) {
            
            slog(@"WARNWARN: Local Working Cache unavailable or could not write backup: [%@]", localWorkingCache);
            NSString* em = NSLocalizedString(@"model_error_cannot_write_backup", @"Could not write backup, will not proceed with write of database!");
            
            if(error) {
                *error = [Utils createNSError:em errorCode:-1];
            }
            return NO;
        }
    }
    
    NSUUID* updateId = NSUUID.UUID;
    database.outstandingUpdateId = updateId;
        
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

- (SyncStatus*)getSyncStatus:(DatabasePreferences *)database {
    return [SyncAndMergeSequenceManager.sharedInstance getSyncStatusForDatabaseId:database.uuid];
}

- (BOOL)syncInProgressForDatabase:(NSString*)databaseId {
    SyncStatus *status = [SyncAndMergeSequenceManager.sharedInstance getSyncStatusForDatabaseId:databaseId];
    
    return status.state == kSyncOperationStateInProgress;
}



- (NSString *)getPrimaryStorageDisplayName:(DatabasePreferences *)database {
    return [SafeStorageProviderFactory getStorageDisplayName:database];
}










- (void)startMonitoringWorkingCacheDirectory {
    NSString * homeDirectory = StrongboxFilesManager.sharedInstance.syncManagerLocalWorkingCachesDirectory.path;
    
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    self.wcDispatchQueue = dispatch_queue_create("WorkingCacheMonitorQueue", 0);
    
    
    self.wcSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, filedes, DISPATCH_VNODE_WRITE, _dispatchQueue);
    
    dispatch_source_set_event_handler(self.wcSource, ^(){
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            slog(@"🚀 Working Cache File Change Detected!");
            



        });
    });
        
    dispatch_source_set_cancel_handler(self.wcSource, ^() {
        close(filedes);
    });
    
    dispatch_resume(self.wcSource);
}

- (void)startMonitoringDocumentsDirectory {
    NSString * homeDirectory = StrongboxFilesManager.sharedInstance.documentsDirectory.path;
    
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    _dispatchQueue = dispatch_queue_create("FileMonitorQueue", 0);
    
    
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, filedes, DISPATCH_VNODE_WRITE, _dispatchQueue);
    
    dispatch_source_set_event_handler(_source, ^(){
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            slog(@"File Change Detected! Scanning for New Safes");
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
    NSArray<DatabasePreferences*> * localSafes = [DatabasePreferences forAllDatabasesOfProvider:kLocalDevice];
    NSMutableSet *existing = [NSMutableSet set];
    for (DatabasePreferences* safe in localSafes) {
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
                NSURL *url = [StrongboxFilesManager.sharedInstance.documentsDirectory URLByAppendingPathComponent:item.name];

                if([Serializator isValidDatabase:url error:&error]) {
                    slog(@"New File: [%@] is a valid database", item.name);
                    [newSafes addObject:item];
                }
                else {
                    
                }
            }
        }
    }
    else {
        slog(@"Error Scanning for New Files. List Root: %@", error);
    }
    
    return newSafes;
}

- (NSArray<StorageBrowserItem*>*)getDocumentFiles:(NSError**)ppError {
    NSError *error;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:StrongboxFilesManager.sharedInstance.documentsDirectory.path
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
        NSString *fullPath = [StrongboxFilesManager.sharedInstance.documentsDirectory.path stringByAppendingPathComponent:file];
        
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
        NSString* name = [DatabasePreferences trimDatabaseNickName:[item.name stringByDeletingPathExtension]];
        DatabasePreferences *safe = [LocalDeviceStorageProvider.sharedInstance getDatabasePreferences:name
                                                                                         providerData:item.providerData];
        
        NSURL *url = [StrongboxFilesManager.sharedInstance.documentsDirectory URLByAppendingPathComponent:item.name];
        NSData* snapshot = [NSData dataWithContentsOfURL:url];
        
        NSError* error;
        NSDictionary *att = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        
        NSError* addError;
        if ( ![safe addWithDuplicateCheck:snapshot initialCacheModDate:att.fileModificationDate error:&addError] ) {
            slog(@"Error adding database - error = [%@]", error);
        }
    }
    
    
    
    NSArray<DatabasePreferences*> *localSafes = [DatabasePreferences forAllDatabasesOfProvider:kLocalDevice];
    
    for (DatabasePreferences* localSafe in localSafes) {
        NSURL* url = [self getLegacyLocalDatabaseFileUrl:localSafe];
        if(![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
            slog(@"WARNWARN: Database [%@] underlying file [%@] no longer exists in Documents Directory.", localSafe.nickName, localSafe.fileName);
            
            
            
            
        }
    }
    
    
    
    [SyncManager.sharedInstance backgroundSyncLocalDeviceDatabasesOnly];
}

- (BOOL)toggleLocalDatabaseFilesVisibility:(DatabasePreferences*)databaseMetadata error:(NSError**)error {
    LocalDatabaseIdentifier* identifier = [self getLegacyLocalDatabaseStorageIdentifier:databaseMetadata];

    NSURL* src = [self getLegacyLocalDatabaseFileUrl:identifier.sharedStorage filename:identifier.filename];
    NSURL* dest = [self getLegacyLocalDatabaseFileUrl:!identifier.sharedStorage filename:identifier.filename];

    int i=0;
    NSString* extension = [identifier.filename pathExtension];
    NSString* baseFileName = [identifier.filename stringByDeletingPathExtension];
    
    
    
    [self stopMonitoringDocumentsDirectory];
    
    while ([[NSFileManager defaultManager] fileExistsAtPath:dest.path]) {
        identifier.filename = [[baseFileName stringByAppendingFormat:@"-%d", i] stringByAppendingPathExtension:extension];
        
        dest = [self getLegacyLocalDatabaseFileUrl:!identifier.sharedStorage filename:identifier.filename];
        
        slog(@"File exists at destination... Trying: [%@]", dest);
    }
    
    if(![NSFileManager.defaultManager moveItemAtURL:src toURL:dest error:error]) {
        slog(@"Error moving local file: [%@]", *error);
        [self startMonitoringDocumentsDirectory];
        return NO;
    }
    else {
        slog(@"OK - Moved local file: [%@] -> [%@]", src, dest);
    }
    
    identifier.sharedStorage = !identifier.sharedStorage;
    
    databaseMetadata.fileIdentifier = [identifier toJson];
    databaseMetadata.fileName = identifier.filename;

    [self startMonitoringDocumentsDirectory];
    
    return YES;
}

- (LocalDatabaseIdentifier*)getLegacyLocalDatabaseStorageIdentifier:(DatabasePreferences*)metaData {
    NSString* json = metaData.fileIdentifier;
    return [LocalDatabaseIdentifier fromJson:json];
}

- (NSURL*)getLegacyLocalDatabaseDirectory:(BOOL)shared {
    return shared ? StrongboxFilesManager.sharedInstance.sharedAppGroupDirectory : StrongboxFilesManager.sharedInstance.documentsDirectory;
}

- (NSURL*)getLegacyLocalDatabaseFileUrl:(DatabasePreferences*)safeMetaData {
    LocalDatabaseIdentifier* identifier = [self getLegacyLocalDatabaseStorageIdentifier:safeMetaData];
    return identifier ? [self getLegacyLocalDatabaseFileUrl:identifier.sharedStorage filename:identifier.filename] : nil;
}

- (NSURL*)getLegacyLocalDatabaseFileUrl:(BOOL)sharedStorage filename:(NSString*)filename {
    NSURL* folder = [self getLegacyLocalDatabaseDirectory:sharedStorage];
    return [folder URLByAppendingPathComponent:filename];
}

@end
