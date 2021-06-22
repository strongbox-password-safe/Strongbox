//
//  SyncAndMergeSequenceManager.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncAndMergeSequenceManager.h"
#import "ConcurrentMutableDictionary.h"
#import "SafeStorageProvider.h"
#import "SafeStorageProviderFactory.h"
#import "Utils.h"
#import "SyncDatabaseRequest.h"
#import "ConcurrentMutableQueue.h"
#import "DatabaseSyncOperationalData.h"
#import "NSDate+Extensions.h"
#import "FileManager.h"
#import "DatabaseModel.h"
#import "DatabaseMerger.h"
#import "Serializator.h"
#import "ConflictResolutionStrategy.h"
#import "WorkingCopyManager.h"

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

#import "ConflictResolutionWizard.h"
#import "DatabaseDiffAndMergeViewController.h"
#import "SVProgressHUD.h"
#import "BackupsManager.h"
#import "Alerts.h"
#import "SafeMetaData.h"
#import "SafesList.h"
#import "SyncManager.h"

typedef VIEW_CONTROLLER_PTR VIEW_CONTROLLER_PTR;
typedef SafeMetaData* METADATA_PTR;

#else

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"
#import "DatabasesManager.h"
#import "ProgressWindow.h"
#import "MacAlerts.h"
#import "BackupsManager.h"

typedef NSViewController* VIEW_CONTROLLER_PTR;
typedef DatabaseMetadata* METADATA_PTR;

#endif

NSString* const kSyncManagerDatabaseSyncStatusChanged = @"syncManagerDatabaseSyncStatusChanged";



@interface SyncAndMergeSequenceManager ()

@property ConcurrentMutableDictionary<NSString*, DatabaseSyncOperationalData*>* operationalStateForDatabase;
@property NSDictionary<NSNumber*, dispatch_queue_t>* storageProviderSerializedQueues; 

#if TARGET_OS_IPHONE

#else

@property ProgressWindow* progressWindow;

#endif

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
        
#if TARGET_OS_IPHONE
        for (int i=0;i<kStorageProviderCount;i++) {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:i];
            NSString* queueName = [NSString stringWithFormat:@"SB-SProv-Queue-%@", [SafeStorageProviderFactory getStorageDisplayNameForProvider:i]];
            md[@(i)] = dispatch_queue_create(queueName.UTF8String, provider.supportsConcurrentRequests ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
        }
#else
        NSArray<NSNumber*> *supportedProvidersOnMac = @[@(kSFTP), @(kWebDAV), @(kMacFile)];
        for (NSNumber* providerIdNum in supportedProvidersOnMac) {
            int i = providerIdNum.intValue;
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:i];
            NSString* queueName = [NSString stringWithFormat:@"SB-SProv-Queue-%@", [SafeStorageProviderFactory getStorageDisplayNameForProvider:i]];
            md[providerIdNum] = dispatch_queue_create(queueName.UTF8String, provider.supportsConcurrentRequests ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
        }
#endif
        
        self.storageProviderSerializedQueues = md.copy;
    }
    return self;
}

- (void)dismissProgressSpinner {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD dismiss];
#else
        [self.progressWindow hide];
#endif
    });
}

- (void)showProgressSpinner:(NSString*)message viewController:(VIEW_CONTROLLER_PTR)viewController {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        if (viewController) {
            [SVProgressHUD showWithStatus:message];
        }
#else
        if ( self.progressWindow ) {
            [self.progressWindow hide];
        }
        
        if (viewController) {
            self.progressWindow = [ProgressWindow newProgress:message];
            [viewController.view.window beginSheet:self.progressWindow.window completionHandler:nil];
        }
#endif
    });
}

- (DatabaseSyncOperationalData*)getOperationData:(NSString*)databaseUuid {
    DatabaseSyncOperationalData *ret = [self.operationalStateForDatabase objectForKey:databaseUuid];
    
    if (!ret) {
        DatabaseSyncOperationalData* info = [[DatabaseSyncOperationalData alloc] initWithDatabaseId:databaseUuid];
        [self.operationalStateForDatabase setObject:info forKey:databaseUuid];
    }

    return [self.operationalStateForDatabase objectForKey:databaseUuid];
}

- (SyncStatus *)getSyncStatusForDatabaseId:(NSString *)databaseUuid {
    return [self getOperationData:databaseUuid].status;
}

- (void)enqueueSyncForDatabaseId:(NSString *)databaseUuid
                      parameters:(SyncParameters *)parameters
                      completion:(SyncAndMergeCompletionBlock)completion {
    SyncDatabaseRequest* request = [[SyncDatabaseRequest alloc] init];
    request.databaseId = databaseUuid;
    request.parameters = parameters;
    request.completion = completion;

    DatabaseSyncOperationalData* opData = [self getOperationData:databaseUuid];
    [opData enqueueSyncRequest:request];
    
    dispatch_async(opData.dispatchSerialQueue, ^{
        [self processSyncRequestQueue:databaseUuid];
    });
}

- (void)processSyncRequestQueue:(NSString*)databaseUuid {
    DatabaseSyncOperationalData* opData = [self getOperationData:databaseUuid];
    
    SyncDatabaseRequest* request = [opData dequeueSyncRequest];
    
    if (request) {
        NSUUID* syncId = NSUUID.UUID;
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        
        
        METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

        dispatch_queue_t storageProviderQueue = self.storageProviderSerializedQueues[@(database.storageProvider)];
        dispatch_async(storageProviderQueue, ^{
            __block BOOL done = NO; 
            
            [self syncOrPoll:databaseUuid syncId:syncId parameters:request.parameters completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
                if ( done ) {
                    NSLog(@"WARNWARN: Completion Called when already completed! - NOP - WARNWARN");
                    return;
                }
                done = YES;
                
                NSArray<SyncDatabaseRequest*>* alsoWaiting = [opData dequeueAllJoinRequests];
                if (alsoWaiting.count) {
                    NSLog(@"SYNC: Also found %@ requests waiting on sync for this DB - Completing those also now...", @(alsoWaiting.count));
                }
                
                NSMutableArray<SyncDatabaseRequest*> *allRequestsFulfilledByThisSync = [NSMutableArray arrayWithObject:request];
                [allRequestsFulfilledByThisSync addObjectsFromArray:alsoWaiting];
                
                for (SyncDatabaseRequest* request in allRequestsFulfilledByThisSync) {
                    NSLog(@"SYNC [%@-%@]: Calling Completion", databaseUuid, syncId);
                    request.completion(result, localWasChanged, error);
                }
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        });
    }
}

- (METADATA_PTR)databaseMetadataFromDatabaseId:(NSString*)databaseUuid {
#if TARGET_OS_IPHONE
    return [SafesList.sharedInstance getById:databaseUuid];
#else
    return [DatabasesManager.sharedInstance getDatabaseById:databaseUuid];
#endif
}

- (void)updateDatabaseMetadata:(NSString *_Nonnull)uuid touch:(void (^_Nonnull)(METADATA_PTR metadata))touch {
#if TARGET_OS_IPHONE
    [SafesList.sharedInstance atomicUpdate:uuid touch:touch];
#else
    [DatabasesManager.sharedInstance atomicUpdate:uuid touch:touch];
#endif
}

- (void)syncOrPoll:(NSString*)databaseUuid syncId:(NSUUID*)syncId parameters:(SyncParameters*)parameters completion:(SyncAndMergeCompletionBlock)completion {
    if ( parameters.testForRemoteChangesOnly ) {
        [self poll:databaseUuid syncId:syncId parameters:parameters completion:completion];
    }
    else {
        [self sync:databaseUuid syncId:syncId parameters:parameters completion:completion];
    }
}

- (void)poll:(NSString*)databaseUuid syncId:(NSUUID*)syncId parameters:(SyncParameters*)parameters completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    if ( !database ) {
        NSLog(@"Could not get Database for id [%@].", databaseUuid);
        completion(kSyncAndMergeError, NO, nil);
        return;
    }
    
    NSDate* localModDate;
    [self getExistingLocalCopy:databaseUuid modified:&localModDate];
    if (!localModDate) {
        NSLog(@"Could not get local Mod Date. Cannot test for remote changes.");
        completion(kSyncAndMergeError, NO, nil);
        return;
    }
    
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    
    NSLog(@"Getting remote mod date.");
    [provider getModDate:database completion:^(NSDate * _Nonnull modDate, NSError * _Nullable error) {
        NSLog(@"Got remote mod date. %@ : %@", modDate, error);

        if (!modDate) {
            completion(kSyncAndMergeError, NO, error);
        }
        else {
            BOOL changed = ![modDate isEqualToDateWithinEpsilon:localModDate];
            completion(kSyncAndMergeSuccess, changed, nil);
        }
    }];
}

- (void)sync:(NSString*)databaseUuid syncId:(NSUUID*)syncId parameters:(SyncParameters*)parameters completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    if ( !database ) {
        NSLog(@"Could not get Database for id [%@].", databaseUuid);
        completion(kSyncAndMergeError, NO, nil);
        return;
    }
    [self updateDatabaseMetadata:databaseUuid touch:^(METADATA_PTR metadata) {
        metadata.lastSyncAttempt = NSDate.date;
    }];

    BOOL syncPullEvenIfModifiedDateSame = parameters.syncPullEvenIfModifiedDateSame;
    NSDate* localModDate;
    [self getExistingLocalCopy:databaseUuid modified:&localModDate];

    StorageProviderReadOptions* opts = [[StorageProviderReadOptions alloc] init];
    
    
    
    
    
    
    
    opts.onlyIfModifiedDifferentFrom = syncPullEvenIfModifiedDateSame || (database.outstandingUpdateId != nil) ? nil : localModDate;
    
    NSString* providerDisplayName = [SafeStorageProviderFactory getStorageDisplayName:database];

    NSString* initialLog = [NSString stringWithFormat:@"Begin Sync [Interactive=%@, outstandingUpdate=%@, forcePull=%d, provider=%@, localMod=%@, lastRemoteSyncMod=%@]",
                            (parameters.interactiveVC ? @"YES" : @"NO"),
                            (database.outstandingUpdateId != nil ? @"YES" : @"NO"),
                            syncPullEvenIfModifiedDateSame,
                            providerDisplayName,
                            localModDate.friendlyDateTimeStringBothPrecise,
                            database.lastSyncRemoteModDate.friendlyDateTimeStringBothPrecise];
    
    [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateInProgress message:initialLog];

    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    [provider pullDatabase:database
             interactiveVC:parameters.interactiveVC
                   options:opts
                completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        if (result == kReadResultError || (result == kReadResultSuccess && (data == nil || dateModified == nil))) {
            [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
            completion(kSyncAndMergeError, NO, (NSError*)error);
        }
        else if (result == kReadResultBackgroundReadButUserInteractionRequired) {
            [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateBackgroundButUserInteractionRequired error:error];
            completion(kSyncAndMergeResultUserInteractionRequired, NO, (NSError*)error);
        }
        else if (result == kReadResultModifiedIsSameAsLocal) {
            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Pull Database - Modified same as Local"]];
            [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateDone error:error];
            completion(kSyncAndMergeSuccess, NO, nil);
        }
        else if (result == kReadResultSuccess) {
            [self onPulledRemoteDatabase:databaseUuid syncId:syncId localModDate:localModDate remoteData:data remoteModified:dateModified parameters:parameters completion:completion];
        }
        else { 
            [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError message:@"Unknown status returned by Storage Provider"];
            completion(kSyncAndMergeError, NO, nil);
        }
    }];
}

- (void)onPulledRemoteDatabase:(NSString*)databaseUuid
                        syncId:(NSUUID*)syncId
                  localModDate:(NSDate*)localModDate
                    remoteData:(NSData*)remoteData
                remoteModified:(NSDate*)remoteModified
                    parameters:(SyncParameters*)parameters
                    completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Got Remote OK [remoteMod=%@]", remoteModified.friendlyDateTimeStringBothPrecise]];
      
    
    
    
    
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

    if (!database.outstandingUpdateId || localModDate == nil) {
        [self logMessage:databaseUuid syncId:syncId message:@"No Updates to Push, syncing local from remote."];
        [self setLocalAndComplete:remoteData dateModified:remoteModified database:databaseUuid syncId:syncId localWasChanged:YES takeABackup:YES completion:completion];
    }
    else {
        [self handleOutstandingUpdate:databaseUuid syncId:syncId remoteData:remoteData remoteModified:remoteModified parameters:parameters completion:completion];
    }
}

- (void)handleOutstandingUpdate:(NSString*)databaseUuid
                         syncId:(NSUUID*)syncId
                     remoteData:(NSData*)remoteData
                 remoteModified:(NSDate*)remoteModified
                     parameters:(SyncParameters*)parameters
                     completion:(SyncAndMergeCompletionBlock)completion {
    
    NSDate* localModDate;
    NSURL* localCopy = [self getExistingLocalCopy:databaseUuid modified:&localModDate];
    NSData* localData;
    NSError* error;
    if (localCopy) {
        localData = [NSData dataWithContentsOfFile:localCopy.path options:kNilOptions error:&error];
    }
    
    if (!localCopy || !localData) {
        [self logMessage:databaseUuid syncId:syncId message:@"Could not read local copy but Update Outstanding..."];
        
        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
        
        completion(kSyncAndMergeError, NO, error);
    }
    else {
        
        
        BOOL forcePush = parameters.syncForcePushDoNotCheckForConflicts;
        
        METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

        BOOL noRemoteChange = (database.lastSyncRemoteModDate && [database.lastSyncRemoteModDate isEqualToDateWithinEpsilon:remoteModified]);
        
        if (forcePush || noRemoteChange) { 
            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Update to Push - [Simple Push because Force=%@, Remote Changed=%@]", forcePush ? @"YES" : @"NO", noRemoteChange ? @"NO" : @"YES"]];
            [self setRemoteAndComplete:localData database:databaseUuid syncId:syncId localWasChanged:NO interactiveVC:parameters.interactiveVC completion:completion];
        }
        else {
            [self doConflictResolution:databaseUuid syncId:syncId localData:localData localModDate:localModDate remoteData:remoteData remoteModified:remoteModified parameters:parameters completion:completion];
        }
    }
}




- (void)doConflictResolution:(NSString*)databaseUuid
                      syncId:(NSUUID*)syncId
                   localData:(NSData*)localData
                localModDate:(NSDate*)localModDate
                  remoteData:(NSData*)remoteData
              remoteModified:(NSDate*)remoteModified
                  parameters:(SyncParameters*)parameters
                  completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

    [self logMessage:databaseUuid
              syncId:syncId
             message:[NSString stringWithFormat:@"Remote has changed since last sync. Last Sync Remote Mod was [%@]", database.lastSyncRemoteModDate.friendlyDateTimeStringBothPrecise]];

    ConflictResolutionStrategy strategy = database.conflictResolutionStrategy;

#if TARGET_OS_IPHONE 
    
    

    if ( database.storageProvider == kLocalDevice && database.conflictResolutionStrategy == kConflictResolutionStrategyAsk ) {
        strategy = (database.likelyFormat == kKeePass || database.likelyFormat == kKeePass4) ? kConflictResolutionStrategyAutoMerge : kConflictResolutionStrategyForcePushLocal;
    }
#endif
    
    if ( !parameters.interactiveVC && strategy == kConflictResolutionStrategyAsk ) {
        
        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateBackgroundButUserInteractionRequired
                                  message:@"Sync Conflict - User Interaction Required"];
        
        completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
        return;
    }
    
    

    if ( strategy == kConflictResolutionStrategyAutoMerge ) {
        [self conflictResolutionMerge:databaseUuid syncId:syncId parameters:parameters localData:localData remoteData:remoteData compareFirst:NO completion:completion];
    }
    else if (strategy == kConflictResolutionStrategyForcePushLocal) { 
        [self conflictResolutionForcePushLocal:databaseUuid syncId:syncId localData:localData interactiveVC:parameters.interactiveVC completion:completion];
    }
    else if (strategy == kConflictResolutionStrategyForcePullRemote) { 
        [self conflictResolutionForcePullRemote:databaseUuid syncId:syncId remoteData:remoteData remoteModified:remoteModified interactiveVC:parameters.interactiveVC completion:completion];
    }
#if TARGET_OS_IPHONE
    else if (strategy == kConflictResolutionStrategyAsk) {
        
        [self conflictResolutionAsk:databaseUuid syncId:syncId localData:localData localModDate:localModDate remoteData:remoteData remoteModified:remoteModified parameters:parameters completion:completion];
    }
#endif
    else {
        NSLog(@"WARNWARN: doConflictResolution - Unknown Conflict Resolution Strategy");
    }
}

#if TARGET_OS_IPHONE



- (void)conflictResolutionAsk:(NSString*)databaseUuid
                       syncId:(NSUUID*)syncId
                    localData:(NSData*)localData
                 localModDate:(NSDate*)localModDate
                   remoteData:(NSData*)remoteData
               remoteModified:(NSDate*)remoteModified
                   parameters:(SyncParameters*)parameters
                   completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:databaseUuid syncId:syncId message:@"Update to Push but Remote has also changed. Requesting User Advice..."];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"ConflictResolutionWizard" bundle:nil];
        UINavigationController* nav = [storyboard instantiateInitialViewController];
        ConflictResolutionWizard* wiz = (ConflictResolutionWizard*)nav.topViewController;
        
        wiz.localModDate = localModDate;
        wiz.remoteModified = remoteModified;
        
        METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
        wiz.remoteStorage = [SafeStorageProviderFactory getStorageDisplayName:database];
        
        wiz.completion = ^(ConflictResolutionWizardResult result) {
            [parameters.interactiveVC dismissViewControllerAnimated:YES completion:^{
                [self doConflictResolutionWizardChoice:databaseUuid
                                                syncId:syncId
                                          wizardResult:result
                                             localData:localData
                                          localModDate:localModDate
                                            remoteData:remoteData
                                        remoteModified:remoteModified
                                            parameters:parameters
                                            completion:completion];
            }];
        };
        
        [parameters.interactiveVC presentViewController:nav animated:YES completion:nil];
    });
}

- (void)doConflictResolutionWizardChoice:(NSString*)databaseUuid
                                  syncId:(NSUUID*)syncId
                            wizardResult:(ConflictResolutionWizardResult)wizardResult
                               localData:(NSData*)localData
                            localModDate:(NSDate*)localModDate
                              remoteData:(NSData*)remoteData
                          remoteModified:(NSDate*)remoteModified
                              parameters:(SyncParameters*)parameters
                              completion:(SyncAndMergeCompletionBlock)completion {
    if (wizardResult == kConflictWizardResultAutoMerge) {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Auto-Merge"];
        [self conflictResolutionMerge:databaseUuid syncId:syncId parameters:parameters localData:localData remoteData:remoteData compareFirst:NO completion:completion];
    }
    else if ( wizardResult == kConflictWizardResultAlwaysAutoMerge ) {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Always Auto-Merge"];

        [Alerts areYouSure:parameters.interactiveVC
                   message:NSLocalizedString(@"sync_are_you_sure_always_auto_merge", @"Are you sure you want to always Auto-Merge when you have a Sync Conflict like this?")
                    action:^(BOOL response) {
            if (response) {
                [self updateDatabaseMetadata:databaseUuid touch:^(METADATA_PTR metadata) {
                    metadata.conflictResolutionStrategy = kConflictResolutionStrategyAutoMerge;
                }];

                [self conflictResolutionMerge:databaseUuid syncId:syncId parameters:parameters localData:localData remoteData:remoteData compareFirst:NO completion:completion];
            }
            else {
                [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
            }
        }];
    }
    else if ( wizardResult == kConflictWizardResultCompare ) {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Compare"];

        [self conflictResolutionMerge:databaseUuid syncId:syncId parameters:parameters localData:localData remoteData:remoteData compareFirst:YES completion:completion];
    }
    else if ( wizardResult == kConflictWizardResultForcePushLocal ) {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Force Push"];

        [self conflictResolutionForcePushLocal:databaseUuid syncId:syncId localData:localData interactiveVC:parameters.interactiveVC completion:completion];
    }
    else if ( wizardResult == kConflictWizardResultForcePullRemote ) {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Force Pull"];

        [self conflictResolutionForcePullRemote:databaseUuid syncId:syncId remoteData:remoteData remoteModified:remoteModified interactiveVC:parameters.interactiveVC completion:completion];
    }
    else if ( wizardResult == kConflictWizardResultSyncLater ) {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Sync Later"];

        [self conflictResolutionPostponeSyncAndUnlockLocalOnly:databaseUuid syncId:syncId completion:completion];
    }
    else {
        [self logMessage:databaseUuid syncId:syncId message:@"User chose Cancel"];

        [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
    }
}

- (void)conflictResolutionPostponeSyncAndUnlockLocalOnly:(NSString*)databaseUuid syncId:(NSUUID*)syncId completion:(SyncAndMergeCompletionBlock)completion {
    
    
    [self logAndPublishStatusChange:databaseUuid
                             syncId:syncId
                              state:kSyncOperationStateDone
                            message:@"Sync Conflict - User postponed sync. Working with local copy only."];

    completion(kSyncAndMergeUserPostponedSync, NO, nil);
}

#endif

- (void)conflictResolutionForcePushLocal:(NSString*)databaseUuid
                                  syncId:(NSUUID*)syncId
                               localData:(NSData*)localData
                           interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                              completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:databaseUuid syncId:syncId message:@"Sync Conflict Resolution: Use Local - Pushing Local and overwriting Remote."];
    [self setRemoteAndComplete:localData database:databaseUuid syncId:syncId localWasChanged:NO interactiveVC:interactiveVC completion:completion];
}

- (void)conflictResolutionForcePullRemote:(NSString*)databaseUuid
                                   syncId:(NSUUID*)syncId
                               remoteData:(NSData*)remoteData
                           remoteModified:(NSDate*)remoteModified
                            interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                               completion:(SyncAndMergeCompletionBlock)completion {
    [self updateDatabaseMetadata:databaseUuid touch:^(METADATA_PTR metadata) {
        metadata.outstandingUpdateId = nil;
    }];
    
    [self logMessage:databaseUuid syncId:syncId message:@"Sync Conflict Resolution: Use Theirs/Remote - Pulling from Remote and overwriting Local."];
    [self setLocalAndComplete:remoteData dateModified:remoteModified database:databaseUuid syncId:syncId localWasChanged:YES takeABackup:YES completion:completion];
}

- (void)conflictResolutionCancel:(NSString*)databaseUuid syncId:(NSUUID*)syncId completion:(SyncAndMergeCompletionBlock)completion {
    [self logAndPublishStatusChange:databaseUuid
                             syncId:syncId
                              state:kSyncOperationStateUserCancelled
                            message:@"Sync Conflict Manual Resolution cancelled. Finishing Sync with [User Cancelled]"];

    completion(kSyncAndMergeResultUserCancelled, NO, nil);
}

- (void)conflictResolutionMerge:(NSString*)databaseUuid
                         syncId:(NSUUID*)syncId
                     parameters:(SyncParameters*)parameters
                      localData:(NSData*)localData
                     remoteData:(NSData*)remoteData
                   compareFirst:(BOOL)compareFirst
                     completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:databaseUuid syncId:syncId message:@"Update to Push but Remote has also changed. Conflict. Auto Merging..."];

    if ( !parameters.key ) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_cannot_merge_in_background", @"Cannot merge without Master Credentials.") errorCode:-1];
        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
        
        completion(kSyncAndMergeError, NO, error);
        return;
    }
    
    NSUUID* syncMergeId = NSUUID.UUID;
    NSString* dirPath = FileManager.sharedInstance.syncManagerMergeWorkingDirectory.path;
    NSString* local = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.local", syncMergeId.UUIDString]];
    NSString* remote = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.remote", syncMergeId.UUIDString]];
        
    BOOL writeOk = [localData writeToFile:local atomically:YES] && [remoteData writeToFile:remote atomically:YES];
    if ( !writeOk ) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_could_not_write_local_merge", @"Technical Error - Could not write local copies for comparison/merge.") errorCode:-1];
        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
        
        completion(kSyncAndMergeError, NO, error);
        return;
    }
        
    NSURL* localUrl = [NSURL fileURLWithPath:local];
    NSURL* remoteUrl = [NSURL fileURLWithPath:remote];
    [self mergeLocalAndRemoteUrls:databaseUuid syncId:syncId localUrl:localUrl remoteUrl:remoteUrl parameters:parameters compareFirst:compareFirst completion:completion];
}






- (void)mergeLocalAndRemoteUrls:(NSString*)databaseUuid
                         syncId:(NSUUID*)syncId
                       localUrl:(NSURL*)localUrl
                      remoteUrl:(NSURL*)remoteUrl
                     parameters:(SyncParameters*)parameters
                   compareFirst:(BOOL)compareFirst
                     completion:(SyncAndMergeCompletionBlock)completion {
    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:parameters.interactiveVC];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [Serializator fromUrl:localUrl
                          ckf:parameters.key
                   completion:^(BOOL userCancelled, DatabaseModel * _Nullable mine, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissProgressSpinner];

                if ( userCancelled ) {
                    [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Local Merge Unlock."];
                    [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                }
                else if ( error || !mine ) {
                    [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                    completion(kSyncAndMergeError, NO, error);
                }
                else {
                    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:parameters.interactiveVC];
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
                        [Serializator fromUrl:remoteUrl
                                          ckf:parameters.key
                                   completion:^(BOOL userCancelled, DatabaseModel * _Nullable theirs, NSError * _Nullable error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self dismissProgressSpinner];

                                if ( userCancelled ) {
                                    [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Remote Merge Unlock."];
                                    [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                                }
                                else if ( error || !theirs ) {
                                    [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                                    completion(kSyncAndMergeError, NO, error);
                                }
                                else {
                                    [self synchronizeModels:databaseUuid syncId:syncId localUrl:localUrl remoteUrl:remoteUrl parameters:parameters compareFirst:compareFirst mine:mine theirs:theirs completion:completion];
                                }
                            });
                        }];
                    });
                }
            });
        }];
    });
}

- (void)synchronizeModels:(NSString*)databaseUuid
                   syncId:(NSUUID*)syncId
                 localUrl:(NSURL*)localUrl
                remoteUrl:(NSURL*)remoteUrl
               parameters:(SyncParameters*)parameters
             compareFirst:(BOOL)compareFirst
                     mine:(DatabaseModel*)mine
                   theirs:(DatabaseModel*)theirs
               completion:(SyncAndMergeCompletionBlock)completion {
    DatabaseModel* merged = [mine clone];
    DatabaseMerger* syncer= [DatabaseMerger mergerFor:merged theirs:theirs];

    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:parameters.interactiveVC];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        BOOL success = [syncer merge];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissProgressSpinner];
            
            if ( success ) {
                [self logMessage:databaseUuid syncId:syncId message:@"Pre-Merge Succeeded..."];
                [self compareOrMerge:databaseUuid mine:mine merged:merged syncId:syncId compareFirst:compareFirst interactiveVC:parameters.interactiveVC completion:completion];
            }
            else {
                [self logMessage:databaseUuid syncId:syncId message:@"Merge Failed"];
                NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_could_not_merge_local_remote", @"Technical Error - Could not merge local and remote databases.") errorCode:-1];
                
#if TARGET_OS_IPHONE
                
                
                if ( parameters.interactiveVC ) {
                    [Alerts error:parameters.interactiveVC error:error completion:^{
                        [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                        completion(kSyncAndMergeError, NO, error);
                    }];
                }
                else {
                    [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                    completion(kSyncAndMergeError, NO, error);
                }
#else
                

                if ( parameters.interactiveVC ) {
                    [MacAlerts error:error window:parameters.interactiveVC.view.window completion:^{
                        [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                        completion(kSyncAndMergeError, NO, error);
                    }];
                }
                else {
                    [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                    completion(kSyncAndMergeError, NO, error);
                }
#endif
            }
        });
    });
}

- (void)compareOrMerge:(NSString*)databaseUuid
                  mine:(DatabaseModel*)mine
                merged:(DatabaseModel*)merged
                syncId:(NSUUID*)syncId
          compareFirst:(BOOL)compareFirst
         interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
            completion:(SyncAndMergeCompletionBlock)completion {
    if (compareFirst) {
#if TARGET_OS_IPHONE 
        UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"CompareDatabases" bundle:nil];
        DatabaseDiffAndMergeViewController* vc = (DatabaseDiffAndMergeViewController*)[storyboard instantiateInitialViewController];

        vc.isMergeDiff = YES;
        
        METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
        
        vc.firstDatabase = [[Model alloc] initWithDatabase:mine metaData:database forcedReadOnly:NO isAutoFill:NO];
        vc.secondDatabase = [[Model alloc] initWithDatabase:merged metaData:database forcedReadOnly:YES isAutoFill:NO];
        vc.onDone = ^(BOOL mergeRequested, Model * _Nullable first, Model * _Nullable second) {
            [interactiveVC dismissViewControllerAnimated:YES completion:^{
                if (mergeRequested) {
                    [self mergeLocalAndRemote:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
                }
                else {
                    [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Compare & Merge"];
                    [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                }
            }];
        };

        UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [interactiveVC presentViewController:nav animated:YES completion:nil];
#endif
    }
    else {
        [self mergeLocalAndRemote:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
    }
}

- (void)mergeLocalAndRemote:(NSString*)databaseUuid merged:(DatabaseModel*)merged interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC syncId:(NSUUID*)syncId completion:(SyncAndMergeCompletionBlock)completion {
    if (merged.originalFormat != kKeePass && merged.originalFormat != kKeePass4) {     
#if TARGET_OS_IPHONE
        if ( interactiveVC ) {
            [Alerts areYouSure:interactiveVC
                       message:NSLocalizedString(@"merge_are_you_sure_less_than_ideal_format", @"Your database format does not support advanced synchronization features (available in KeePass 2). This means the merge may be less than ideal.\n\nAre you sure you want to continue with the merge?")
                        action:^(BOOL response) {
                if (response) {
                    [self mergeLocalAndRemoteAfterWarn:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
                }
                else {
                    [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                }
            }];
        }
        else {
            [self logAndPublishStatusChange:databaseUuid
                                     syncId:syncId
                                      state:kSyncOperationStateBackgroundButUserInteractionRequired
                                      message:@"Sync Conflict - User Interaction Required"];
            
            completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
            return;
        }
#else
        if ( interactiveVC ) {
            [MacAlerts areYouSure:NSLocalizedString(@"merge_are_you_sure_less_than_ideal_format", @"Your database format does not support advanced synchronization features (available in KeePass 2). This means the merge may be less than ideal.\n\nAre you sure you want to continue with the merge?")
                           window:interactiveVC.view.window
                       completion:^(BOOL response) {
                if (response) {
                    [self mergeLocalAndRemoteAfterWarn:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
                }
                else {
                    [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                }
            }];
        }
        else {
            [self logAndPublishStatusChange:databaseUuid
                                     syncId:syncId
                                      state:kSyncOperationStateBackgroundButUserInteractionRequired
                                      message:@"Sync Conflict - User Interaction Required"];
            
            completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
            return;
        }
#endif
    }
    else {
        [self mergeLocalAndRemoteAfterWarn:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
    }
}

- (void)mergeLocalAndRemoteAfterWarn:(NSString*)databaseUuid merged:(DatabaseModel*)merged interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC syncId:(NSUUID*)syncId completion:(SyncAndMergeCompletionBlock)completion {
    [self showProgressSpinner:NSLocalizedString(@"generic_encrypting", @"Encrypting") viewController:interactiveVC];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [Serializator getAsData:merged format:merged.originalFormat completion:^(BOOL userCancelled, NSData * _Nullable mergedData, NSString * _Nullable debugXml, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissProgressSpinner];
                
                if (userCancelled) {
                    [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                }
                else if (error) {
                    [self logAndPublishStatusChange:databaseUuid
                                             syncId:syncId
                                              state:kSyncOperationStateError
                                              error:error];
                    
                    completion(kSyncAndMergeError, NO, error);
                }
                else {
                    [self logMessage:databaseUuid syncId:syncId message:@"Encrypted Merge Result... pushing remote and setting local..."];
                    [self setRemoteAndComplete:mergedData database:databaseUuid syncId:syncId localWasChanged:YES interactiveVC:interactiveVC completion:completion];
                }
            });
        }];
    });
}



- (void)setRemoteAndComplete:(NSData*)data
                    database:(NSString*)databaseUuid
                      syncId:(NSUUID*)syncId
             localWasChanged:(BOOL)localWasChanged
               interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                  completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

    if (database.readOnly) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1];
        [self logAndPublishStatusChange:databaseUuid
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
            [self logAndPublishStatusChange:databaseUuid
                                     syncId:syncId
                                      state:kSyncOperationStateError
                                      error:error];
            
            completion(kSyncAndMergeError, NO, (NSError*)error);
        }
        else if (result == kUpdateResultUserInteractionRequired) {
            [self logAndPublishStatusChange:databaseUuid
                                     syncId:syncId
                                      state:kSyncOperationStateBackgroundButUserInteractionRequired
                                      message:@"Sync Conflict - User Interaction Required"];

            completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
        }
        else {
            [self updateDatabaseMetadata:databaseUuid touch:^(METADATA_PTR metadata) {
                metadata.outstandingUpdateId = nil;
            }];
            
            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Outstanding Update successfully pushed to Remote. [New Remote Mod Date=%@]. Making Local Copy Match Remote...", newRemoteModDate.friendlyDateTimeStringBothPrecise]];

            if (!newRemoteModDate) {
                NSLog(@"WARNWARN: No new remote mod date returned from storage provider! Setting to NOW.");
                newRemoteModDate = NSDate.date;
            }
            
            
            
            [self setLocalAndComplete:data
                         dateModified:newRemoteModDate
                             database:databaseUuid
                               syncId:syncId
                      localWasChanged:localWasChanged
                          takeABackup:localWasChanged
                           completion:completion];
        }
    }];
}

- (void)setLocalAndComplete:(NSData*)data
               dateModified:(NSDate*)dateModified
                   database:(NSString*)databaseUuid
                     syncId:(NSUUID*)syncId
            localWasChanged:(BOOL)localWasChanged
                takeABackup:(BOOL)takeABackup
                 completion:(SyncAndMergeCompletionBlock)completion {
    NSError* error;
    if(![self setLocalCopy:data dateModified:dateModified database:databaseUuid takeABackup:takeABackup error:&error]) {
        [self logMessage:databaseUuid syncId:syncId message:@"Could not sync local copy from remote."];

        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
    
        completion(kSyncAndMergeError, NO, error);
    }
    else {
        [self logMessage:databaseUuid syncId:syncId message:@"Local copy successfully synced with remote."];
        [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateDone error:nil];

        
        
        [self updateDatabaseMetadata:databaseUuid touch:^(METADATA_PTR metadata) {
            metadata.lastSyncRemoteModDate = dateModified;
        }];
        
        completion(kSyncAndMergeSuccess, localWasChanged, nil);
    }
}




- (NSURL*_Nullable)getExistingLocalCopy:(NSString*)databaseUuid modified:(NSDate**)modified {
    return [WorkingCopyManager.sharedInstance getLocalWorkingCache2:databaseUuid modified:modified];
}

- (NSURL*)setLocalCopy:(NSData*)data
          dateModified:(NSDate*)dateModified
              database:(NSString*)databaseUuid
           takeABackup:(BOOL)takeABackup
                 error:(NSError**)error {
    if ( takeABackup ) {
        NSURL* localWorkingCache = [self getExistingLocalCopy:databaseUuid modified:nil];
        if (localWorkingCache) {
            METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

            if( ![BackupsManager.sharedInstance writeBackup:localWorkingCache metadata:database] ) {
                NSString* em = NSLocalizedString(@"model_error_cannot_write_backup", @"Could not write backup, will not proceed with write of database!");
                
                if(error) {
                    *error = [Utils createNSError:em errorCode:-1];
                }
                return nil;
            }
        }
        else {
            
            NSLog(@"WARNWARN: Local Working Cache unavailable or could not write backup: [%@]", localWorkingCache);
        }
    }
    
    return [WorkingCopyManager.sharedInstance setWorkingCacheWithData2:data dateModified:dateModified database:databaseUuid error:error];
}

- (void)publishSyncStatusChangeNotification:(SyncStatus*)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSyncManagerDatabaseSyncStatusChanged object:info.databaseId];
    });
}

- (void)logMessage:(NSString*)databaseUuid syncId:(NSUUID*)syncId message:(NSString*)message {
    DatabaseSyncOperationalData* operationalData = [self getOperationData:databaseUuid];
    [operationalData.status addLogMessage:message syncId:syncId];
}

- (void)logAndPublishStatusChange:(NSString*)databaseUuid syncId:(NSUUID*)syncId state:(SyncOperationState)state message:(NSString*)message {
    DatabaseSyncOperationalData* operationalData = [self getOperationData:databaseUuid];
    [operationalData.status updateStatus:state syncId:syncId message:message];
    [self publishSyncStatusChangeNotification:operationalData.status];
}

- (void)logAndPublishStatusChange:(NSString*)databaseUuid syncId:(NSUUID*)syncId state:(SyncOperationState)state error:(const NSError*)error {
    DatabaseSyncOperationalData* operationalData = [self getOperationData:databaseUuid];
    [operationalData.status updateStatus:state syncId:syncId error:(NSError*)error];
    
    [self publishSyncStatusChangeNotification:operationalData.status];
}

NSString* syncResultToString(SyncAndMergeResult result) {
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
        case kSyncAndMergeUserPostponedSync:
            return @"User Postponed Sync";
            break;
        case kSyncAndMergeResultUserCancelled:
            return @"User Cancelled";
            break;
        default:
            return @"Unknown!";
    }
}

@end
