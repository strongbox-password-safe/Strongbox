//
//  MacSyncManager.m
//  MacBox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacSyncManager.h"
#import "WorkingCopyManager.h"
#import "Utils.h"
#import "Settings.h"
#import "MacUrlSchemes.h"
#import "BackupsManager.h"

@implementation MacSyncManager

+ (instancetype)sharedInstance {
    static MacSyncManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MacSyncManager alloc] init];
    });
    return sharedInstance;
}

- (void)backgroundSyncOutstandingUpdates {
    NSLog(@"backgroundSyncOutstandingUpdates START");
    
    for (MacDatabasePreferences* database in MacDatabasePreferences.allDatabases) {
        if ( database.outstandingUpdateId ) {
            [self backgroundSyncDatabase:database];
        }
    }
}

- (void)backgroundSyncAll {
    NSLog(@"backgroundSyncOutstandingUpdates START");
    
    for (MacDatabasePreferences* database in MacDatabasePreferences.allDatabases) {
        [self backgroundSyncDatabase:database];
    }
}

- (void)backgroundSyncDatabase:(MacDatabasePreferences*)database {
    [self backgroundSyncDatabase:database key:nil completion:nil];
}


- (void)backgroundSyncDatabase:(MacDatabasePreferences*)database
                           key:(CompositeKeyFactors * _Nullable)key 
                    completion:(SyncAndMergeCompletionBlock _Nullable)completion {

        
    if ( database.alwaysOpenOffline ) {
        NSLog(@"WARNWARN: Attempt to Sync an Offline Mode database?!");
        if (completion) {
            completion(kSyncAndMergeError, NO, nil);
        }
        return;
    }
    
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.inProgressBehaviour = kInProgressBehaviourJoin;
    params.syncForcePushDoNotCheckForConflicts = NO;
    params.syncPullEvenIfModifiedDateSame = NO;
    params.key = key;
    


    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {

        
        if (completion) {
            completion(result, localWasChanged, error);
        }
    }];
}

- (void)sync:(MacDatabasePreferences *)database
interactiveVC:(NSViewController *)interactiveVC
         key:(CompositeKeyFactors *)key
        join:(BOOL)join
  completion:(SyncAndMergeCompletionBlock)completion {
    NSLog(@"Sync ENTER - [%@]", database.nickName);
    

    if ( database.alwaysOpenOffline ) {
        NSLog(@"WARNWARN: Attempt to Sync an Offline Mode database?!");
        if (completion) {
            completion(kSyncAndMergeError, NO, nil);
        }
        return;
    }

    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.interactiveVC = interactiveVC;
    
    params.key = key;
    params.inProgressBehaviour = join ? kInProgressBehaviourJoin : kInProgressBehaviourEnqueueAnotherSync;
    params.syncForcePushDoNotCheckForConflicts = NO;
    params.syncPullEvenIfModifiedDateSame = NO;

    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        NSLog(@"SYNC DONE: [%@] [%@] - Local Changed: [%@] - [%@]", database.nickName, syncResultToString(result), localizedYesOrNoFromBool(localWasChanged), error);
        completion(result, localWasChanged, error);
    }];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(nonnull METADATA_PTR)database file:(nonnull NSString *)file error:(NSError *__autoreleasing  _Nullable * _Nullable)error {
    return [self updateLocalCopyMarkAsRequiringSync:database data:nil file:file error:error];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(MacDatabasePreferences *)database data:(NSData *)data error:(NSError**)error {
    return [self updateLocalCopyMarkAsRequiringSync:database data:data file:nil error:error];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(nonnull METADATA_PTR)database
                                      data:(NSData *)data
                                      file:(NSString *)file
                                     error:(NSError**)error {
    if ( database.readOnly ) {
        if ( error ) {
            *error = [Utils createNSError:NSLocalizedString(@"warn_database_is_ro_no_update", @"Your database is in Read Only mode and cannot be updated.") errorCode:-1];
        }
        NSLog(@"🔴 WARNWARN: Attempt to update a Read Only database?!");
        return NO;
    }

    
    
    NSURL* localWorkingCache = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    if ( localWorkingCache && Settings.sharedInstance.makeLocalRollingBackups ) {
        if(![BackupsManager.sharedInstance writeBackup:localWorkingCache metadata:database]) {
            
            NSLog(@"⚠️ WARNWARN: Could not write backup: [%@]", localWorkingCache);
            NSString* em = NSLocalizedString(@"model_error_cannot_write_backup", @"Could not write backup, will not proceed with write of database!");
            
            if(error) {
                *error = [Utils createNSError:em errorCode:-1];
            }
            return NO;
        }
    }
    
    database.outstandingUpdateId = NSUUID.UUID;
    
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

- (SyncStatus*)getSyncStatus:(MacDatabasePreferences *)database {
    return [SyncAndMergeSequenceManager.sharedInstance getSyncStatusForDatabaseId:database.uuid];
}

- (void)pollForChanges:(MacDatabasePreferences *)database completion:(SyncAndMergeCompletionBlock)completion {

    
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.inProgressBehaviour = kInProgressBehaviourEnqueueAnotherSync;
    params.testForRemoteChangesOnly = YES;
    
    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {

        completion(result, localWasChanged, error);
    }];
}

- (BOOL)syncInProgress {
    for (MacDatabasePreferences* database in MacDatabasePreferences.allDatabases) {
        SyncStatus *status = [SyncAndMergeSequenceManager.sharedInstance getSyncStatusForDatabaseId:database.uuid];
        
        if ( status.state == kSyncOperationStateInProgress ) {

            return YES;
        }
    }

    return NO;
}

- (void)removeDatabaseAndLocalCopies:(MacDatabasePreferences*)database {
    [WorkingCopyManager.sharedInstance deleteLocalWorkingCache:database.uuid];
}

@end
