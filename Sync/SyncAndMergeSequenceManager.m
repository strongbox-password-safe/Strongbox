//
//  SyncAndMergeSequenceManager.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SyncAndMergeSequenceManager.h"
#import "ConcurrentMutableDictionary.h"
#import "SafeStorageProvider.h"
#import "SyncManager.h"
#import "SafeStorageProviderFactory.h"
#import "SharedAppAndAutoFillSettings.h"
#import "Utils.h"
#import "BackupsManager.h"
#import "SyncDatabaseRequest.h"
#import "ConcurrentMutableQueue.h"
#import "DatabaseSyncOperationalData.h"
#import "SafesList.h"
#import "Alerts.h"
#import "NSDate+Extensions.h"
#import "FileManager.h"
#import "DatabaseModel.h"
#import "DatabaseSynchronizer.h"

// Future: Overlapping/Multiple updates not possible, they need to be serialized so the Local copy can be matched with remote - Not a big deal right now

@interface SyncAndMergeSequenceManager ()

@property ConcurrentMutableDictionary<NSString*, DatabaseSyncOperationalData*>* operationalStateForDatabase;
@property NSDictionary<NSNumber*, dispatch_queue_t>* storageProviderSerializedQueues; // Some (Most?) Storage Providers do not take well to multiple simultaneous syncs (reads/writes from different threads so we do one at a time)

@end

@implementation SyncAndMergeSequenceManager

+ (instancetype)sharedInstance {
    static SyncAndMergeSequenceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SyncAndMergeSequenceManager alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.operationalStateForDatabase = ConcurrentMutableDictionary.mutableDictionary;
        
        NSMutableDictionary* md = NSMutableDictionary.dictionary;
        for (int i=0;i<kStorageProviderCount;i++) {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:i];
            NSString* queueName = [NSString stringWithFormat:@"SB-SProv-Queue-%@", [SafeStorageProviderFactory getStorageDisplayNameForProvider:i]];
            md[@(i)] = dispatch_queue_create(queueName.UTF8String, provider.supportsConcurrentRequests ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
        }
        
        self.storageProviderSerializedQueues = md.copy;
    }
    return self;
}

- (DatabaseSyncOperationalData*)getOperationData:(SafeMetaData*)database {
    DatabaseSyncOperationalData *ret = [self.operationalStateForDatabase objectForKey:database.uuid];
    
    if (!ret) {
        DatabaseSyncOperationalData* info = [[DatabaseSyncOperationalData alloc] initWithDatabase:database];
        [self.operationalStateForDatabase setObject:info forKey:database.uuid];
    }

    return [self.operationalStateForDatabase objectForKey:database.uuid];
}

- (SyncStatus *)getSyncStatus:(SafeMetaData *)database {
    return [self getOperationData:database].status;
}

- (void)enqueueSync:(SafeMetaData *)database parameters:(SyncParameters *)parameters completion:(SyncAndMergeCompletionBlock)completion {
    SyncDatabaseRequest* request = [[SyncDatabaseRequest alloc] init];
    request.databaseId = database.uuid;
    request.parameters = parameters;
    request.completion = completion;

    DatabaseSyncOperationalData* opData = [self getOperationData:database];
    [opData enqueueSyncRequest:request];
    
    dispatch_async(opData.dispatchSerialQueue, ^{
        [self processSyncRequestQueue:database];
    });
}

- (void)processSyncRequestQueue:(SafeMetaData*)database {
    DatabaseSyncOperationalData* opData = [self getOperationData:database];
    
    SyncDatabaseRequest* request = [opData dequeueSyncRequest];
    
    if (request) {
        NSUUID* syncId = NSUUID.UUID;
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        // Get Storage Provider Queue -
        
        dispatch_queue_t storageProviderQueue = self.storageProviderSerializedQueues[@(database.storageProvider)];
        dispatch_async(storageProviderQueue, ^{
            [self sync:database syncId:syncId interactiveVC:request.parameters.interactiveVC completion:^(SyncAndMergeResult result, BOOL conflictAndLocalWasChanged, const NSError * _Nullable error) {
                NSArray<SyncDatabaseRequest*>* alsoWaiting = [opData dequeueAllJoinRequests];
                if (alsoWaiting.count) {
                    NSLog(@"SYNC: Also found %@ requests waiting on sync for this DB - Completing those also now...", @(alsoWaiting.count));
                }
                
                NSMutableArray<SyncDatabaseRequest*> *allRequestsFulfilledByThisSync = [NSMutableArray arrayWithObject:request];
                [allRequestsFulfilledByThisSync addObjectsFromArray:alsoWaiting];
                
                for (SyncDatabaseRequest* request in allRequestsFulfilledByThisSync) {
                    NSLog(@"SYNC [%@]: Calling Completion", syncId);
                    request.completion(result, conflictAndLocalWasChanged, error);
                }
                dispatch_group_leave(group);
            }];

            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        });
    }
}

- (void)sync:(SafeMetaData *)database syncId:(NSUUID*)syncId interactiveVC:(UIViewController*)interactiveVC completion:(SyncAndMergeCompletionBlock)completion {
    BOOL syncPullEvenIfModifiedDateSame = SharedAppAndAutoFillSettings.sharedInstance.syncPullEvenIfModifiedDateSame;
    NSDate* localModDate;
    [self getExistingLocalCopy:database modified:&localModDate];

    StorageProviderReadOptions* opts = [[StorageProviderReadOptions alloc] init];
    
    // We should pull data from remote to check/merge if:
    //
    // - 1) Forced
    // - 2) Local and Remote Dates differ
    // - 3) There is an outstanding update (this will almost certainly be handled by 2) above but just in case we include this check)
    
    opts.onlyIfModifiedDifferentFrom = syncPullEvenIfModifiedDateSame || (database.outstandingUpdateId != nil) ? nil : localModDate;
    
    NSString* providerDisplayName = [SafeStorageProviderFactory getStorageDisplayName:database];

    NSString* initialLog = [NSString stringWithFormat:@"Begin Sync [Interactive=%@, outstandingUpdate=%@, forcePull=%d, provider=%@, localMod=%@, lastRemoteSyncMod=%@]",
                            (interactiveVC ? @"YES" : @"NO"),
                            (database.outstandingUpdateId != nil ? @"YES" : @"NO"),
                            syncPullEvenIfModifiedDateSame,
                            providerDisplayName,
                            localModDate.friendlyDateTimeStringBothPrecise,
                            database.lastSyncRemoteModDate.friendlyDateTimeStringBothPrecise];
    
    [self logAndPublishStatusChange:database syncId:syncId state:kSyncOperationStateInProgress message:initialLog];

    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    [provider pullDatabase:database
             interactiveVC:interactiveVC
                   options:opts
                completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        if (result == kReadResultError || (result == kReadResultSuccess && (data == nil || dateModified == nil))) {
            [self logAndPublishStatusChange:database syncId:syncId state:kSyncOperationStateError error:error];
            completion(kSyncAndMergeError, NO, error);
        }
        else if (result == kReadResultBackgroundReadButUserInteractionRequired) {
            [self logAndPublishStatusChange:database syncId:syncId state:kSyncOperationStateBackgroundButUserInteractionRequired error:error];
            completion(kSyncAndMergeResultUserInteractionRequired, NO, error);
        }
        else if (result == kReadResultModifiedIsSameAsLocal) {
            [self logMessage:database syncId:syncId message:[NSString stringWithFormat:@"Pull Database - Modified same as Local"]];
            [self logAndPublishStatusChange:database syncId:syncId state:kSyncOperationStateDone error:error];
            
            // TODO: This is temporary to avoid an initial Conflict on release of 2 way sync where lastSyncRemoteModeDate is null - set it now if our local copy matches the remore
            // TODO: Remove in a few months, say 13-Nov-2020
            database.lastSyncRemoteModDate = localModDate;
            [SafesList.sharedInstance update:database];

            completion(kSyncAndMergeSuccess, NO, nil);
        }
        else if (result == kReadResultSuccess) {
            [self onPulledRemoteDatabase:database syncId:syncId localModDate:localModDate remoteData:data remoteModified:dateModified interactiveVC:interactiveVC completion:completion];
        }
        else { // Some unknown state
            [self logAndPublishStatusChange:database syncId:syncId state:kSyncOperationStateError message:@"Unknown status returned by Storage Provider"];
            completion(kSyncAndMergeError, NO, nil);
        }
    }];
}

- (void)onPulledRemoteDatabase:(SafeMetaData *)database syncId:(NSUUID*)syncId localModDate:(NSDate*)localModDate remoteData:(NSData*)remoteData remoteModified:(NSDate*)remoteModified interactiveVC:(UIViewController*)interactiveVC completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:database syncId:syncId message:[NSString stringWithFormat:@"Got Remote OK [remoteMod=%@]", remoteModified.friendlyDateTimeStringBothPrecise]];
        
    // No Outstanding Update or No Local Copy -> Simple pull and set
    //
    // The check for local copy is to handle weird edge case where a user migrates databases from a backup and Outstanding Update is set but there is no actual update.
    
    if (!database.outstandingUpdateId || localModDate == nil) {
        [self logMessage:database syncId:syncId message:@"No Updates to Push, syncing local from remote."];
        [self setLocalAndComplete:remoteData dateModified:remoteModified database:database syncId:syncId completion:completion];
    }
    else {
        [self handleOutstandingUpdate:database syncId:syncId remoteData:remoteData remoteModified:remoteModified interactiveVC:interactiveVC completion:completion];
    }
}

- (void)handleOutstandingUpdate:(SafeMetaData *)database syncId:(NSUUID*)syncId remoteData:(NSData*)remoteData remoteModified:(NSDate*)remoteModified interactiveVC:(UIViewController*)interactiveVC completion:(SyncAndMergeCompletionBlock)completion {
    NSDate* localModDate;
    NSURL* localCopy = [self getExistingLocalCopy:database modified:&localModDate];
    NSData* localData;
    NSError* error;
    if (localCopy) {
        localData = [NSData dataWithContentsOfFile:localCopy.path options:kNilOptions error:&error];
    }
    
    if (!localCopy || !localData) {
        [self logMessage:database syncId:syncId message:@"Could not read local copy but Update Outstanding..."];
        
        [self logAndPublishStatusChange:database
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
        
        completion(kSyncAndMergeError, NO, error);
    }
    else {
        // It shouldn't be possible for lastSyncRemoteModDate to be nil here but just to be safe, if that happens go to the conflict situation
        
        BOOL forcePush = SharedAppAndAutoFillSettings.sharedInstance.syncForcePushDoNotCheckForConflicts;
        BOOL noRemoteChange = (database.lastSyncRemoteModDate && [database.lastSyncRemoteModDate isEqualToDateWithinEpsilon:remoteModified]);
        
        if (forcePush || noRemoteChange) { // Simple Overwrite
            [self logMessage:database syncId:syncId message:[NSString stringWithFormat:@"Update to Push - [Simple Push because Force=%@, Remote Changed=%@]", forcePush ? @"YES" : @"NO", noRemoteChange ? @"NO" : @"YES"]];
            [self setRemoteAndComplete:localData database:database syncId:syncId interactiveVC:interactiveVC completion:completion];
        }
        else {
            // Merge / Overwrite / Conflict situation!
            [self handleOutstandingUpdateWithRemoteConflict:database syncId:syncId localData:localData localModDate:localModDate remoteData:remoteData remoteModified:remoteModified interactiveVC:interactiveVC completion:completion];
        }
    }
}

- (void)handleOutstandingUpdateWithRemoteConflict:(SafeMetaData *)database
                                           syncId:(NSUUID*)syncId
                                        localData:(NSData*)localData
                                     localModDate:(NSDate*)localModDate
                                       remoteData:(NSData*)remoteData
                                   remoteModified:(NSDate*)remoteModified interactiveVC:(UIViewController*)interactiveVC  completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:database syncId:syncId message:[NSString stringWithFormat:@"Remote has changed since last sync. Last Sync Remote Mod was [%@]", database.lastSyncRemoteModDate.friendlyDateTimeStringBothPrecise]];
    
    const BOOL mergePossible = NO;
    if (mergePossible) {
        [self logMessage:database syncId:syncId message:@"Update to Push but Remote has changed also... Attempting Merge..."];

        // TODO: if format == keepass2
        // TODO: NB: Don't forget to set the conflictAndLocalChanged flag

        [self synchronizeDatabases:localData remoteData:remoteData];
    }
    else {
        if (!interactiveVC) {
            [self logAndPublishStatusChange:database
                                     syncId:syncId
                                      state:kSyncOperationStateBackgroundButUserInteractionRequired
                                      message:@"Sync Conflict - User Interaction Required"];
            
            completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
        }
        else {
            [self logMessage:database syncId:syncId message:@"Update to Push but Remote has changed also. Merge not possible. Requesting User Advice..."];
            [self promptForManualConflictResolutionStrategy:database syncId:syncId localData:localData localModDate:localModDate remoteData:remoteData remoteModified:remoteModified interactiveVC:interactiveVC completion:completion];
        }
    }
}

- (void)promptForManualConflictResolutionStrategy:(SafeMetaData *)database syncId:(NSUUID*)syncId localData:(NSData*)localData localModDate:(NSDate*)localModDate remoteData:(NSData*)remoteData remoteModified:(NSDate*)remoteModified interactiveVC:(UIViewController*)interactiveVC completion:(SyncAndMergeCompletionBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* useMyLocal = [NSString stringWithFormat:NSLocalizedString(@"sync_conflict_option_use_mine_fmt", @"Use Mine/Local (%@)"), localModDate.friendlyDateString];
        NSString* useTheirRemote = [NSString stringWithFormat:NSLocalizedString(@"sync_conflict_option_use_theirs_fmt", @"Use Theirs/Remote (%@)"), remoteModified.friendlyDateString];
        NSString* title = NSLocalizedString(@"sync_conflict_title", @"Sync Conflict");
        NSString* spDisplayName = [SafeStorageProviderFactory getStorageDisplayName:database];
        NSString* message = [NSString stringWithFormat:NSLocalizedString(@"sync_conflict_message_fmt", @"It looks like the remote version of this database on '%@' has changed and so has the local version you've been working on. Which version would you like to use?"), spDisplayName];
        
        [Alerts twoOptionsWithCancel:interactiveVC
                               title:title
                             message:message
                   defaultButtonText:useMyLocal
                    secondButtonText:useTheirRemote action:^(int response) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
                if (response == 0) { // Use Local
                    [self logMessage:database syncId:syncId message:@"Sync Conflict Manual Resolution: Use Local - Pushing Local and overwriting Remote."];
                    [self setRemoteAndComplete:localData database:database syncId:syncId interactiveVC:interactiveVC completion:completion];
                }
                else if (response == 1) { // Use Remote
                    // Don't forget to clear the outstanding flag...
                    database.outstandingUpdateId = nil;
                    [SafesList.sharedInstance update:database];
                    
                    [self logMessage:database syncId:syncId message:@"Sync Conflict Manual Resolution: Use Theirs/Remote - Pulling from Remote and overwriting Local."];
                    [self setLocalAndComplete:remoteData dateModified:remoteModified database:database syncId:syncId conflictAndLocalWasChanged:YES completion:completion];
                }
                else {
                    [self logAndPublishStatusChange:database
                                             syncId:syncId
                                              state:kSyncOperationStateUserCancelled
                                              message:@"Sync Conflict Manual Resolution cancelled. Finishing Sync with [User Cancelled]"];
                    
                    completion(kSyncAndMergeResultUserCancelled, NO, nil);
                }
            });
        }];
    });
}

- (void)setRemoteAndComplete:(NSData*)data database:(SafeMetaData*)database syncId:(NSUUID*)syncId interactiveVC:(UIViewController*)interactiveVC completion:(SyncAndMergeCompletionBlock)completion {
    if (database.readOnly) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1];
        [self logAndPublishStatusChange:database
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
        
        completion(kSyncAndMergeError, NO, error);
        return;
    }
    
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    [provider pushDatabase:database
             interactiveVC:interactiveVC
                      data:data
                completion:^(StorageProviderUpdateResult result, NSDate * _Nullable newRemoteModDate, const NSError * _Nullable error) {
        if (result == kUpdateResultError) {
            [self logAndPublishStatusChange:database
                                     syncId:syncId
                                      state:kSyncOperationStateError
                                      error:error];
            
            completion(kSyncAndMergeError, NO, error);
        }
        else if (result == kUpdateResultUserInteractionRequired) {
            [self logAndPublishStatusChange:database
                                     syncId:syncId
                                      state:kSyncOperationStateBackgroundButUserInteractionRequired
                                      message:@"Sync Conflict - User Interaction Required"];

            completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
        }
        else {
            database.outstandingUpdateId = nil;
            [SafesList.sharedInstance update:database];
            
            [self logMessage:database syncId:syncId message:[NSString stringWithFormat:@"Outstanding Update successfully pushed to Remote. [New Remote Mod Date=%@]. Making Local Copy Match Remote...", newRemoteModDate.friendlyDateTimeStringBothPrecise]];

            if (!newRemoteModDate) {
                NSLog(@"WARNWARN: No new remote mod date returned from storage provider! Setting to NOW.");
                newRemoteModDate = NSDate.date;
            }
            
            [self setLocalAndComplete:data dateModified:newRemoteModDate database:database syncId:syncId completion:completion];
        }
    }];
}

- (void)setLocalAndComplete:(NSData*)data dateModified:(NSDate*)dateModified database:(SafeMetaData*)database syncId:(NSUUID*)syncId completion:(SyncAndMergeCompletionBlock)completion {
    [self setLocalAndComplete:data dateModified:dateModified database:database syncId:syncId conflictAndLocalWasChanged:NO completion:completion];
}

- (void)setLocalAndComplete:(NSData*)data dateModified:(NSDate*)dateModified database:(SafeMetaData*)database syncId:(NSUUID*)syncId conflictAndLocalWasChanged:(BOOL)conflictAndLocalWasChanged completion:(SyncAndMergeCompletionBlock)completion {
    NSError* error;
    if(![self setLocalCopy:data dateModified:dateModified database:database error:&error]) {
        [self logMessage:database syncId:syncId message:@"Could not sync local copy from remote."];

        [self logAndPublishStatusChange:database
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
    
        completion(kSyncAndMergeError, NO, error);
    }
    else {
        [self logMessage:database syncId:syncId message:@"Local copy successfully synced with remote."];
        [self logAndPublishStatusChange:database syncId:syncId state:kSyncOperationStateDone error:nil];

        // Mark last Sync with Remote
        
        database.lastSyncRemoteModDate = dateModified;
        [SafesList.sharedInstance update:database];
        
        completion(kSyncAndMergeSuccess, conflictAndLocalWasChanged, nil);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Helpers

- (NSURL*_Nullable)getExistingLocalCopy:(SafeMetaData*)database modified:(NSDate**)modified {
    return [SyncManager.sharedInstance getLocalWorkingCache:database modified:modified];
}

- (NSURL*)getLocalCopyUrl:(SafeMetaData*)database {
    return [SyncManager.sharedInstance getLocalWorkingCacheUrlForDatabase:database];
}

- (NSURL*)setLocalCopy:(NSData*)data dateModified:(NSDate*)dateModified database:(SafeMetaData*)database error:(NSError**)error {
    return [SyncManager.sharedInstance setWorkingCacheWithData:data dateModified:dateModified database:database error:error];
}

- (void)publishSyncStatusChangeNotification:(SyncStatus*)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSyncManagerDatabaseSyncStatusChanged object:info.databaseId];
    });
}

- (void)logMessage:(SafeMetaData*)database syncId:(NSUUID*)syncId message:(NSString*)message {
    DatabaseSyncOperationalData* operationalData = [self getOperationData:database];
    [operationalData.status addLogMessage:message syncId:syncId];
}

- (void)logAndPublishStatusChange:(SafeMetaData*)database syncId:(NSUUID*)syncId state:(SyncOperationState)state message:(NSString*)message {
    DatabaseSyncOperationalData* operationalData = [self getOperationData:database];
    [operationalData.status updateStatus:state syncId:syncId message:message];
    [self publishSyncStatusChangeNotification:operationalData.status];
}

- (void)logAndPublishStatusChange:(SafeMetaData*)database syncId:(NSUUID*)syncId state:(SyncOperationState)state error:(const NSError*)error {
    DatabaseSyncOperationalData* operationalData = [self getOperationData:database];
    [operationalData.status updateStatus:state syncId:syncId error:(NSError*)error];
    
    [self publishSyncStatusChangeNotification:operationalData.status];
}

- (void)synchronizeDatabases:(NSData*)localData remoteData:(NSData*)remoteData {
    NSUUID* syncMergeId = NSUUID.UUID;
    
    NSString* local = [FileManager.sharedInstance.tmpEncryptedAttachmentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.local", syncMergeId.UUIDString]];
    NSString* remote = [FileManager.sharedInstance.tmpEncryptedAttachmentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.local", syncMergeId.UUIDString]];
    
    BOOL writeOk = [localData writeToFile:local atomically:YES] && [remoteData writeToFile:remote atomically:YES]; // TODO: Deal with failure

    NSURL* localUrl = [NSURL fileURLWithPath:local];
    NSURL* remoteUrl = [NSURL fileURLWithPath:remote];
    
    // TODO: interactive required?
    // TODO: use convenience CKFs?
    // TODO: different CKFs?
    
    [DatabaseModel fromUrl:localUrl
                       ckf:nil // TODO: ?
                    config:DatabaseModelConfig.defaults
                completion:^(BOOL userCancelled, DatabaseModel * _Nullable mine, const NSError * _Nullable error) {
        // TODO: Check errors
        
        [DatabaseModel fromUrl:remoteUrl
                           ckf:nil // TODO: ?
                        config:DatabaseModelConfig.defaults
                    completion:^(BOOL userCancelled, DatabaseModel * _Nullable theirs, const NSError * _Nullable error) {
            // TODO: Check errors

//            [self sync]
            
            [self synchronizeModels:mine theirs:theirs];
        }];
    }];
}

- (void)synchronizeModels:(DatabaseModel*)mine theirs:(DatabaseModel*)theirs {
    DatabaseSynchronizer *synchronzier = [DatabaseSynchronizer newSynchronizerFor:mine theirs:theirs];
    
    // TODO:
}

@end
