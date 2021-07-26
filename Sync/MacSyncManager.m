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
#import "DatabasesManager.h"
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
    
    for (DatabaseMetadata* database in DatabasesManager.sharedInstance.snapshot) {
        if ( database.outstandingUpdateId && !database.offlineMode ) {
            [self backgroundSyncDatabase:database];
        }
    }
}

- (BOOL)isLegacyFileUrl:(NSURL*)url {
    return ( url && url.scheme.length && [url.scheme isEqualToString:kStrongboxFileUrlScheme] );
}

- (void)backgroundSyncAll {
    NSLog(@"backgroundSyncOutstandingUpdates START");
    
    for (DatabaseMetadata* database in DatabasesManager.sharedInstance.snapshot) {
        if ( ![self isLegacyFileUrl:database.fileUrl] )
            [self backgroundSyncDatabase:database];
        }
    }

- (void)backgroundSyncDatabase:(DatabaseMetadata*)database {
    [self backgroundSyncDatabase:database completion:nil];
}

- (void)backgroundSyncDatabase:(DatabaseMetadata*)database
                    completion:(SyncAndMergeCompletionBlock _Nullable)completion {
    NSLog(@"backgroundSyncDatabase enter [%@]", database);
    
    if ( [self isLegacyFileUrl:database.fileUrl] ) {
        NSLog(@"WARNWARN: Attempt to Sync a Local Device database?!");
        if (completion) {
            completion(kSyncAndMergeSuccess, NO, nil);
        }
        return;
    }
    
    if ( database.offlineMode ) {
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

    NSLog(@"BACKGROUND SYNC Start: [%@]", database.nickName);

    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        NSLog(@"BACKGROUND SYNC DONE: [%@] - [%@][%@]", database.nickName, syncResultToString(result), error);
        
        if (completion) {
            completion(result, localWasChanged, error);
        }
    }];
}

- (void)sync:(DatabaseMetadata *)database interactiveVC:(NSViewController *)interactiveVC key:(CompositeKeyFactors *)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion {
    NSLog(@"Sync ENTER - [%@]", database.nickName);
    

    if ( database.offlineMode ) {
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
        NSLog(@"INTERACTIVE SYNC DONE: [%@] [%@] - Local Changed: [%@] - [%@]", database.nickName, syncResultToString(result), localizedYesOrNoFromBool(localWasChanged), error);
        completion(result, localWasChanged, error);
    }];
}

- (BOOL)updateLocalCopyMarkAsRequiringSync:(DatabaseMetadata *)database data:(NSData *)data error:(NSError**)error {
    if ( database.readOnly ) {
        NSLog(@"WARNWARN: Attempt to update a Read Only database?!");
        return NO;
    }
    
    
    
    NSURL* localWorkingCache = [WorkingCopyManager.sharedInstance getLocalWorkingCache2:database.uuid];
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
    
    [DatabasesManager.sharedInstance atomicUpdate:database.uuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        NSUUID* updateId = NSUUID.UUID;
        metadata.outstandingUpdateId = updateId;
    }];
        
    NSURL* url = [WorkingCopyManager.sharedInstance setWorkingCacheWithData2:data
                                                               dateModified:NSDate.date
                                                                   database:database.uuid
                                                                      error:error];
    
    return url != nil;
}

- (SyncStatus*)getSyncStatus:(DatabaseMetadata *)database {
    return [SyncAndMergeSequenceManager.sharedInstance getSyncStatusForDatabaseId:database.uuid];
}

- (void)pollForChanges:(DatabaseMetadata *)database completion:(SyncAndMergeCompletionBlock)completion {
    NSLog(@"pollForChanges ENTER - [%@]", database.nickName);
    
    SyncParameters* params = [[SyncParameters alloc] init];
    
    params.inProgressBehaviour = kInProgressBehaviourEnqueueAnotherSync;
    params.testForRemoteChangesOnly = YES;
    
    [SyncAndMergeSequenceManager.sharedInstance enqueueSyncForDatabaseId:database.uuid
                                                              parameters:params
                                                              completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        NSLog(@"pollForChanges DONE: [%@] [%@] - Local Changed: [%@] - [%@]", database.nickName, syncResultToString(result), localizedYesOrNoFromBool(localWasChanged), error);
        completion(result, localWasChanged, error);
    }];
}

@end
