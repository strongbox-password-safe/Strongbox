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

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

#import "DatabaseModel.h"
#import "DatabaseMerger.h"
#import "Serializator.h"
#import "ConflictResolutionStrategy.h"
#import "WorkingCopyManager.h"
#import "StrongboxErrorCodes.h"
#import "DatabaseUnlocker.h"
#import "BackupsManager.h"
#import "CompositeKeyDeterminer.h"
#import "CommonDatabasePreferences.h"

#if TARGET_OS_IPHONE

#import "ConflictResolutionWizard.h"
#import "DatabaseDiffAndMergeViewController.h"
#import "IOSCompositeKeyDeterminer.h"

#else

#import "MacCompositeKeyDeterminer.h"
#import "MacConflictResolutionWizard.h"

#endif

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kSyncManagerDatabaseSyncStatusChangedNotification = @"syncManagerDatabaseSyncStatusChanged";

@interface SyncAndMergeSequenceManager ()

@property ConcurrentMutableDictionary<NSString*, DatabaseSyncOperationalData*>* operationalStateForDatabase;
@property NSDictionary<NSNumber*, dispatch_queue_t>* storageProviderSerializedQueues; 

@property (readonly) id<ApplicationPreferences> applicationPreferences;
@property (readonly) id<SyncManagement> syncManagement;
@property (readonly) id<SpinnerUI> spinnerUi;
@property (readonly) id<AlertingUI> alertingUi;

@end

@implementation SyncAndMergeSequenceManager

- (id<ApplicationPreferences>)applicationPreferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}

- (id<SyncManagement>)syncManagement {
    return CrossPlatformDependencies.defaults.syncManagement;
}

- (id<SpinnerUI>)spinnerUi {
    return CrossPlatformDependencies.defaults.spinnerUi;
}

- (id<AlertingUI>)alertingUi {
    return CrossPlatformDependencies.defaults.alertingUi;
}



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
        NSArray<NSNumber*> *supported = @[@(kGoogleDrive),
                                          @(kDropbox),
                                          @(kLocalDevice),
                                          @(kiCloud),
                                          @(kFilesAppUrlBookmark),
                                          @(kSFTP),
                                          @(kWebDAV),
                                          @(kOneDrive),
                                          @(kWiFiSync),
                                          @(kCloudKit),
        ];
#else
        NSArray<NSNumber*> *supported = @[@(kSFTP),
                                          @(kWebDAV),
                                          @(kLocalDevice),
                                          @(kOneDrive),
                                          @(kGoogleDrive),
                                          @(kDropbox),
                                          @(kWiFiSync),
                                          @(kCloudKit),
        ];
#endif

        for (NSNumber* providerIdNum in supported) {
            int i = providerIdNum.intValue;

            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:i];
            NSString* queueName = [NSString stringWithFormat:@"SB-SProv-Queue-%@", [SafeStorageProviderFactory getStorageDisplayNameForProvider:i]];
            md[providerIdNum] = dispatch_queue_create(queueName.UTF8String, provider.supportsConcurrentRequests ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
        }

        self.storageProviderSerializedQueues = md.copy;
    }
    return self;
}

- (DatabaseSyncOperationalData*)getOperationData:(NSString*)databaseUuid {
    if ( databaseUuid == nil ) {
        slog(@"🔴 getOperationData called with NIL!");
        return [[DatabaseSyncOperationalData alloc] initWithDatabaseId:databaseUuid];
    }
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
        
        if ( storageProviderQueue == nil ) {
            slog(@"🔴 No Storage Provider Queue for this Provider!");
            request.completion(kSyncAndMergeError, NO, [Utils createNSError:@"No Storage Provider Queue for this Provider!" errorCode:-1]);
            return;
        }
        
        dispatch_async(storageProviderQueue, ^{
            __block BOOL done = NO; 
            
            [self syncOrPoll:databaseUuid syncId:syncId parameters:request.parameters completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
                if ( done ) {
                    slog(@"🔴 WARNWARN: Completion Called when already completed! - NOP - WARNWARN");
                    return;
                }
                done = YES;
                
                NSArray<SyncDatabaseRequest*>* alsoWaiting = [opData dequeueAllJoinRequests];
                if (alsoWaiting.count) {
                    slog(@"SYNC: Also found %@ requests waiting on sync for this DB - Completing those also now...", @(alsoWaiting.count));
                }
                
                NSMutableArray<SyncDatabaseRequest*> *allRequestsFulfilledByThisSync = [NSMutableArray arrayWithObject:request];
                [allRequestsFulfilledByThisSync addObjectsFromArray:alsoWaiting];
                
                for (SyncDatabaseRequest* request in allRequestsFulfilledByThisSync) {

                    request.completion(result, localWasChanged, error);
                }
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        });
    }
}

- (METADATA_PTR)databaseMetadataFromDatabaseId:(NSString*)databaseUuid { 
    return [CommonDatabasePreferences fromUuid:databaseUuid];
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
        slog(@"Could not get Database for id [%@].", databaseUuid);
        completion(kSyncAndMergeError, NO, nil);
        return;
    }
    
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
    
    [provider getModDate:database completion:^(BOOL storageIsAvailable, NSDate * _Nullable modDate, NSError * _Nullable error) {


        if ( storageIsAvailable ) { 
            if (!modDate) {
                completion(kSyncAndMergeError, NO, error);
            }
            else {
                BOOL changed = ![modDate isEqualToDateWithinEpsilon:database.lastSyncRemoteModDate]; 
                
                completion(kSyncAndMergeSuccess, changed, nil);
            }
        }
        else {
            completion(kSyncAndMergeSuccess, NO, nil); 
        }
    }];
}

- (void)sync:(NSString*)databaseUuid syncId:(NSUUID*)syncId parameters:(SyncParameters*)parameters completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    if ( !database ) {
        slog(@"Could not get Database for id [%@].", databaseUuid);
        completion(kSyncAndMergeError, NO, nil);
        return;
    }
        
    database.lastSyncAttempt = NSDate.date;
    
    BOOL forcePull = parameters.syncPullEvenIfModifiedDateSame;
    NSDate* localModDate;
    [self getExistingWorkingCache:databaseUuid modified:&localModDate];

    StorageProviderReadOptions* opts = [[StorageProviderReadOptions alloc] init];
    
    
    
    
    
    
    
    
    
        
    BOOL localCopyInitialized = ( database.lastSyncRemoteModDate != nil && localModDate != nil );
    if ( !forcePull && ( database.outstandingUpdateId || localCopyInitialized )) {
        opts.onlyIfModifiedDifferentFrom = database.lastSyncRemoteModDate;
    }
    

















    NSString* providerDisplayName = [SafeStorageProviderFactory getStorageDisplayName:database];

    NSString* initialLog = [NSString stringWithFormat:@"Begin Sync [Interactive=%@, outstandingUpdate=%@, forcePull=%d, provider=%@, localModDate=%@, onlyIfModifiedDifferentFrom=%@, lastCheckedSourceMod=%@]",
                            (parameters.interactiveVC ? @"YES" : @"NO"),
                            (database.outstandingUpdateId != nil ? @"YES" : @"NO"),
                            forcePull,
                            providerDisplayName,
                            localModDate.friendlyDateTimeStringBothPrecise,
                            opts.onlyIfModifiedDifferentFrom.friendlyDateTimeStringBothPrecise,
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
            if ( database.outstandingUpdateId != nil ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Pull Database - Source Mod Date same as Last Time we Checked, no source updates to worry about - Outstanding Update Express Scenario..."]];
                [self handleOutstandingUpdate:databaseUuid syncId:syncId expressUpdateMode:YES remoteData:nil remoteModified:opts.onlyIfModifiedDifferentFrom parameters:parameters completion:completion];
            }
            else {
                [self logMessage:databaseUuid syncId:syncId message:@"Pull Database - Source Mod same as Working Copy Mod"];
                [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateDone error:error];
                completion(kSyncAndMergeSuccess, NO, nil);
            }
        }
        else if (result == kReadResultUnavailable ) {
            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Pull Database - Database is currently unavailable, will not read or update but safe to ignore/postpone this sync request."]];
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
    [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Got Source DB OK [Mod=%@]", remoteModified.friendlyDateTimeStringBothPrecise]];
      
    
    
    
    
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

    if (!database.outstandingUpdateId || localModDate == nil) {
        [self logMessage:databaseUuid syncId:syncId message:@"No Updates to Push, syncing working copy from source."];
        [self setLocalAndComplete:remoteData 
                     dateModified:remoteModified
                         database:databaseUuid
                           syncId:syncId
                  localWasChanged:YES
                      takeABackup:YES
                       completion:completion];
    }
    else {
        [self handleOutstandingUpdate:databaseUuid syncId:syncId expressUpdateMode:NO remoteData:remoteData remoteModified:remoteModified parameters:parameters completion:completion];
    }
}

- (void)handleOutstandingUpdate:(NSString*)databaseUuid
                         syncId:(NSUUID*)syncId
              expressUpdateMode:(BOOL)expressUpdateMode
                     remoteData:(NSData*)remoteData
                 remoteModified:(NSDate*)remoteModified
                     parameters:(SyncParameters*)parameters
                     completion:(SyncAndMergeCompletionBlock)completion {
    NSDate* localModDate;
    NSURL* localCopy = [self getExistingWorkingCache:databaseUuid modified:&localModDate];
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
        
        if ( forcePush || noRemoteChange || expressUpdateMode ) { 
            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Update to Push - [Simple Push because Force=%@, Source Changed=%@, Express Update Mode = %@]", forcePush ? @"YES" : @"NO", noRemoteChange ? @"NO" : @"YES", expressUpdateMode ? @"YES" : @"NO"]];
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
    slog(@"⚠️ Sync - Conflict Resolution Begin...");
    
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

    [self logMessage:databaseUuid
              syncId:syncId
             message:[NSString stringWithFormat:@"Source DB has changed since last sync. Last Sync Source Mod was [%@]", database.lastSyncRemoteModDate.friendlyDateTimeStringBothPrecise]];

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
    else if (strategy == kConflictResolutionStrategyAsk) {
        [self conflictResolutionAsk:databaseUuid
                             syncId:syncId
                          localData:localData
                       localModDate:localModDate
                         remoteData:remoteData
                     remoteModified:remoteModified
                         parameters:parameters
                         completion:completion];
    }
    else {
        slog(@"WARNWARN: doConflictResolution - Unknown Conflict Resolution Strategy");
    }
}

- (void)conflictResolutionAsk:(NSString*)databaseUuid
                       syncId:(NSUUID*)syncId
                    localData:(NSData*)localData
                 localModDate:(NSDate*)localModDate
                   remoteData:(NSData*)remoteData
               remoteModified:(NSDate*)remoteModified
                   parameters:(SyncParameters*)parameters
                   completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:databaseUuid syncId:syncId message:@"Update to Push but Source DB has also changed. Requesting User Advice..."];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showConflictResolutionWizard:databaseUuid
                                    syncId:syncId
                                 localData:localData
                              localModDate:localModDate
                                remoteData:remoteData
                            remoteModified:remoteModified
                                parameters:parameters
                                completion:completion];
    });
}

- (void)showConflictResolutionWizard:(NSString*)databaseUuid
                              syncId:(NSUUID*)syncId
                           localData:(NSData*)localData
                        localModDate:(NSDate*)localModDate
                          remoteData:(NSData*)remoteData
                      remoteModified:(NSDate*)remoteModified
                          parameters:(SyncParameters*)parameters
                          completion:(SyncAndMergeCompletionBlock)completion {
#if TARGET_OS_IPHONE
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"ConflictResolutionWizard" bundle:nil];
    UINavigationController* nav = [storyboard instantiateInitialViewController];
    ConflictResolutionWizard* wiz = (ConflictResolutionWizard*)nav.topViewController;
#else
    MacConflictResolutionWizard* wiz = [MacConflictResolutionWizard fromStoryboard];
#endif
    wiz.localModDate = localModDate;
    wiz.remoteModified = remoteModified;
    
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    wiz.remoteStorage = [SafeStorageProviderFactory getStorageDisplayName:database];
    wiz.completion = ^(ConflictResolutionWizardResult result) {
#if TARGET_OS_IPHONE
        [parameters.interactiveVC dismissViewControllerAnimated:YES completion:^{
#endif
            [self doConflictResolutionWizardChoice:databaseUuid
                                            syncId:syncId
                                      wizardResult:result
                                         localData:localData
                                      localModDate:localModDate
                                        remoteData:remoteData
                                    remoteModified:remoteModified
                                        parameters:parameters
                                        completion:completion];
#if TARGET_OS_IPHONE
        }];
#endif
    };
    
#if TARGET_OS_IPHONE
    [parameters.interactiveVC presentViewController:nav animated:YES completion:nil];
#else
    [parameters.interactiveVC presentViewControllerAsSheet:wiz];
#endif
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

        [self.alertingUi areYouSure:parameters.interactiveVC
                   message:NSLocalizedString(@"sync_are_you_sure_always_auto_merge", @"Are you sure you want to always Auto-Merge when you have a Sync Conflict like this?")
                    action:^(BOOL response) {
            if (response) {
                METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
                database.conflictResolutionStrategy = kConflictResolutionStrategyAutoMerge;
                
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

- (void)conflictResolutionPostponeSyncAndUnlockLocalOnly:(NSString*)databaseUuid
                                                  syncId:(NSUUID*)syncId
                                              completion:(SyncAndMergeCompletionBlock)completion {
    
    
    [self logAndPublishStatusChange:databaseUuid
                             syncId:syncId
                              state:kSyncOperationStateDone
                            message:@"Sync Conflict - User postponed sync. Working with local copy only."];

    completion(kSyncAndMergeUserPostponedSync, NO, nil);
}

- (void)conflictResolutionForcePushLocal:(NSString*)databaseUuid
                                  syncId:(NSUUID*)syncId
                               localData:(NSData*)localData
                           interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                              completion:(SyncAndMergeCompletionBlock)completion {
    [self logMessage:databaseUuid syncId:syncId message:@"Sync Conflict Resolution: Use Local - Pushing Working Copy and overwriting Source DB."];
    [self setRemoteAndComplete:localData database:databaseUuid syncId:syncId localWasChanged:NO interactiveVC:interactiveVC completion:completion];
}

- (void)conflictResolutionForcePullRemote:(NSString*)databaseUuid
                                   syncId:(NSUUID*)syncId
                               remoteData:(NSData*)remoteData
                           remoteModified:(NSDate*)remoteModified
                            interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                               completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    database.outstandingUpdateId = nil;
    
    [self logMessage:databaseUuid syncId:syncId message:@"Sync Conflict Resolution: Use Theirs/Source DB - Pulling from Source DB and overwriting Working Copy."];
    [self setLocalAndComplete:remoteData dateModified:remoteModified database:databaseUuid syncId:syncId localWasChanged:YES takeABackup:YES completion:completion];
}

- (void)conflictResolutionCancel:(NSString*)databaseUuid
                          syncId:(NSUUID*)syncId
                      completion:(SyncAndMergeCompletionBlock)completion {
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
    slog(@"⚠️ Sync - conflictResolutionMerge...");

    [self logMessage:databaseUuid syncId:syncId message:@"Update to Push but Source DB has also changed. Conflict. Auto Merging..."];

    
    
    
    
    
    
    if ( !parameters.key ||
        ( parameters.key.yubiKeyCR != nil && parameters.interactiveVC == nil ) ||
        (compareFirst && parameters.interactiveVC == nil ) ) { 
        
        
        
        
        

        
        [self logMessage:databaseUuid syncId:syncId message:@"Cannot Merge either because we don't have credentials or we are in non interactive mode and a compare is requested..."];

        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateBackgroundButUserInteractionRequired
                                  error:nil];
        
        completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);

        return;
    }
    
    NSUUID* syncMergeId = NSUUID.UUID;
    NSString* dirPath = StrongboxFilesManager.sharedInstance.syncManagerMergeWorkingDirectory.path;
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

- (void)requestCredentials:(VIEW_CONTROLLER_PTR)vc
                  database:(METADATA_PTR)database
                completion:(void (^)(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, NSError * _Nullable error))completion {
#if TARGET_OS_IPHONE
    IOSCompositeKeyDeterminer *determiner = [IOSCompositeKeyDeterminer determinerWithViewController:vc
                                                                                           database:database
                                                                                     isAutoFillOpen:NO
                                                         transparentAutoFillBackgroundForBiometrics:NO
                                                                                biometricPreCleared:NO
                                                                                noConvenienceUnlock:YES]; 
    
    [determiner getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        completion(result, factors, error);
    }];
#else
    MacCompositeKeyDeterminer *determiner = [MacCompositeKeyDeterminer determinerWithViewController:vc database:database isNativeAutoFillAppExtensionOpen:NO];
    
    [determiner getCkfsManually:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        completion(result, factors, error);
    }];
#endif
}

- (void)mergeLocalAndRemoteUrls:(NSString*)databaseUuid
                         syncId:(NSUUID*)syncId
                       localUrl:(NSURL*)localUrl
                      remoteUrl:(NSURL*)remoteUrl
                     parameters:(SyncParameters*)parameters
                   compareFirst:(BOOL)compareFirst
                     completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:database
                                                        viewController:parameters.interactiveVC
                                                         forceReadOnly:NO
                                      isNativeAutoFillAppExtensionOpen:NO
                                                           offlineMode:NO];
    unlocker.noProgressSpinner = parameters.interactiveVC == nil;
    
    if ( parameters.interactiveVC ) {
        [self.spinnerUi show:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")
              viewController:parameters.interactiveVC];
    }
    
    [unlocker unlockAtUrl:localUrl
                      key:parameters.key
       keyFromConvenience:NO
               completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( parameters.interactiveVC ) {
                [self.spinnerUi dismiss];
            }

            if ( result == kUnlockDatabaseResultSuccess ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Merge Working Copy and Source: Unlock of Working copy successful. Unlocking Source..."]];

                [self mergeLocalAndRemoteUrlsUnlockSecondDatabaseContinuation:databaseUuid
                                                                       syncId:syncId
                                                                     localUrl:localUrl
                                                                    remoteUrl:remoteUrl
                                                                   parameters:parameters
                                                                 compareFirst:compareFirst
                                                                         mine:model.database
                                                                   completion:completion];
            }
            else if ( result == kUnlockDatabaseResultError ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Could not unlock working copy."]];
                [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                completion(kSyncAndMergeError, NO, error);
            }
            else if ( result == kUnlockDatabaseResultIncorrectCredentials ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Incorrect Credentials unlocking working copy... requesting credentials manually."]];
                
                if ( !parameters.interactiveVC ) {
                    [self logAndPublishStatusChange:databaseUuid
                                             syncId:syncId
                                              state:kSyncOperationStateBackgroundButUserInteractionRequired
                                              error:nil];
                    
                    completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
                }
                else {
                    [self requestCredentials:parameters.interactiveVC
                                    database:database
                                  completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, NSError * _Nullable error) {
                        if ( result == kGetCompositeKeyResultError ) {
                            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Could not get credentials for working copy."]];
                            [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                            completion(kSyncAndMergeError, NO, error);
                        }
                        else if ( result == kGetCompositeKeyResultSuccess ) {
                            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Successfully got manual credentials for working copy. Will try unlock working copy again..."]];
                            parameters.key = factors;
                            
                            [self mergeLocalAndRemoteUrls:databaseUuid
                                                   syncId:syncId
                                                 localUrl:localUrl
                                                remoteUrl:remoteUrl
                                               parameters:parameters
                                             compareFirst:compareFirst
                                               completion:completion];
                        }
                        else {
                            
                            [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Working Copy Merge Get Credentials."];
                            [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                        }
                        
                    }];
                }
            }
            else {

                [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Working Copy Merge Unlock."];
                [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
            }
        });
    }];
}

- (void)mergeLocalAndRemoteUrlsUnlockSecondDatabaseContinuation:(NSString*)databaseUuid
                                                         syncId:(NSUUID*)syncId
                                                       localUrl:(NSURL*)localUrl
                                                      remoteUrl:(NSURL*)remoteUrl
                                                     parameters:(SyncParameters*)parameters
                                                   compareFirst:(BOOL)compareFirst
                                                           mine:(DatabaseModel*)mine
                                                     completion:(SyncAndMergeCompletionBlock)completion {
    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:database
                                                        viewController:parameters.interactiveVC
                                                         forceReadOnly:NO
                                      isNativeAutoFillAppExtensionOpen:NO
                                                           offlineMode:NO];
    unlocker.noProgressSpinner = parameters.interactiveVC == nil;
    
    if ( parameters.interactiveVC ) {
        [self.spinnerUi show:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")
              viewController:parameters.interactiveVC];
    }
    
    [unlocker unlockAtUrl:remoteUrl
                      key:parameters.key
       keyFromConvenience:NO
               completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( parameters.interactiveVC ) {
                [self.spinnerUi dismiss];
            }
            
            if ( result == kUnlockDatabaseResultSuccess ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Merge Working Copy and Source: Unlock of Source successful. Merging Models..."]];
                [self synchronizeModels:databaseUuid syncId:syncId localUrl:localUrl remoteUrl:remoteUrl parameters:parameters compareFirst:compareFirst mine:mine theirs:model.database completion:completion];
            }
            else if ( result == kUnlockDatabaseResultError ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Could not unlock Source copy."]];
                [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                completion(kSyncAndMergeError, NO, error);
            }
            else if ( result == kUnlockDatabaseResultIncorrectCredentials ) {
                [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Incorrect Credentials unlocking source copy... requesting credentials manually."]];
                
                if ( !parameters.interactiveVC ) {
                    [self logAndPublishStatusChange:databaseUuid
                                             syncId:syncId
                                              state:kSyncOperationStateBackgroundButUserInteractionRequired
                                              error:nil];
                    
                    completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
                }
                else {
                    [self requestCredentials:parameters.interactiveVC
                                    database:database
                                  completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, NSError * _Nullable error) {
                        if ( result == kGetCompositeKeyResultError ) {
                            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Could not get credentials for source copy."]];
                            [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                            completion(kSyncAndMergeError, NO, error);
                        }
                        else if ( result == kGetCompositeKeyResultSuccess ) {
                            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Merge: Successfully got manual credentials for source copy. Will try unlock source copy again..."]];
                            parameters.key = factors;
                            
                            [self mergeLocalAndRemoteUrlsUnlockSecondDatabaseContinuation:databaseUuid
                                                                                   syncId:syncId
                                                                                 localUrl:localUrl
                                                                                remoteUrl:remoteUrl
                                                                               parameters:parameters
                                                                             compareFirst:compareFirst
                                                                                     mine:mine
                                                                               completion:completion];
                        }
                        else {
                            
                            [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Source Copy Merge Get Credentials."];
                            [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
                        }
                    }];
                }
            }
            else {

                [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Source DB Merge Unlock."];
                [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
            }
        });
    }];
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

    if ( parameters.interactiveVC ) {
        [self.spinnerUi show:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:parameters.interactiveVC];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        BOOL success = [syncer merge];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( parameters.interactiveVC ) {
                [self.spinnerUi dismiss];
            }
            
            if ( success ) {
                [self logMessage:databaseUuid syncId:syncId message:@"Pre-Merge Succeeded..."];
                [self compareOrMerge:databaseUuid mine:mine merged:merged syncId:syncId compareFirst:compareFirst interactiveVC:parameters.interactiveVC completion:completion];
            }
            else {
                [self logMessage:databaseUuid syncId:syncId message:@"Merge Failed"];
                NSError* error = [Utils createNSError:NSLocalizedString(@"model_error_could_not_merge_local_remote", @"Technical Error - Could not merge local and remote databases.") errorCode:-1];

                

                METADATA_PTR metadata = [self databaseMetadataFromDatabaseId:databaseUuid]; 
                metadata.conflictResolutionStrategy = kConflictResolutionStrategyAsk;
                
                if ( parameters.interactiveVC ) {
                    [self.alertingUi error:parameters.interactiveVC
                                     error:error
                                completion:^{
                        [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                        completion(kSyncAndMergeError, NO, error);
                    }];
                }
                else {
                    [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateError error:error];
                    completion(kSyncAndMergeError, NO, error);
                }
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
    if ( compareFirst ) {
        if ( interactiveVC == nil ) {
            [self logMessage:databaseUuid syncId:syncId message:@"Cannot Merge either because we are in non interactive mode and a compare is requested..."];
            
            [self logAndPublishStatusChange:databaseUuid
                                     syncId:syncId
                                      state:kSyncOperationStateBackgroundButUserInteractionRequired
                                      error:nil];
            
            completion(kSyncAndMergeResultUserInteractionRequired, NO, nil);
        }
        else {
            [self compare:databaseUuid mine:mine merged:merged syncId:syncId interactiveVC:interactiveVC completion:completion];
        }
    }
    else {
        [self mergeLocalAndRemote:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
    }
}

#if TARGET_OS_IPHONE

- (void)compare:(NSString*)databaseUuid
           mine:(DatabaseModel*)mine
         merged:(DatabaseModel*)merged
         syncId:(NSUUID*)syncId
  interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
     completion:(SyncAndMergeCompletionBlock)completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"CompareDatabases" bundle:nil];
    DatabaseDiffAndMergeViewController* vc = (DatabaseDiffAndMergeViewController*)[storyboard instantiateInitialViewController];

    vc.isCompareForMerge = YES;
    vc.isSyncInitiated = YES;
    
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
}

#else

- (void)compare:(NSString*)databaseUuid
           mine:(DatabaseModel*)mine
         merged:(DatabaseModel*)merged
         syncId:(NSUUID*)syncId
  interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
     completion:(SyncAndMergeCompletionBlock)completion {
    CompareDatabasesViewController* vc = [CompareDatabasesViewController fromStoryboard];

    vc.isCompareForMerge = YES;
    vc.isSyncInitiated = YES;

    METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];

    vc.firstModel = [[Model alloc] initWithDatabase:mine metaData:database forcedReadOnly:NO isAutoFill:NO];
    vc.secondModel = merged;

    vc.onDone = ^(BOOL mergeRequested, BOOL synchronize) {
        if (mergeRequested) {
            [self mergeLocalAndRemote:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
        }
        else {
            [self logMessage:databaseUuid syncId:syncId message:@"User Cancelled Compare & Merge"];
            [self conflictResolutionCancel:databaseUuid syncId:syncId completion:completion];
        }
    };

    [interactiveVC presentViewControllerAsSheet:vc];
}

#endif
    
- (void)mergeLocalAndRemote:(NSString*)databaseUuid
                     merged:(DatabaseModel*)merged
              interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                     syncId:(NSUUID*)syncId
                 completion:(SyncAndMergeCompletionBlock)completion {
    if (merged.originalFormat != kKeePass && merged.originalFormat != kKeePass4) {
        if ( interactiveVC ) {
            [self.alertingUi areYouSure:interactiveVC
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
    }
    else {
        [self mergeLocalAndRemoteAfterWarn:databaseUuid merged:merged interactiveVC:interactiveVC syncId:syncId completion:completion];
    }
}

- (void)mergeLocalAndRemoteAfterWarn:(NSString*)databaseUuid
                              merged:(DatabaseModel*)merged
                       interactiveVC:(VIEW_CONTROLLER_PTR)interactiveVC
                              syncId:(NSUUID*)syncId
                          completion:(SyncAndMergeCompletionBlock)completion {
    if ( interactiveVC ) {
        [self.spinnerUi show:NSLocalizedString(@"generic_encrypting", @"Encrypting") viewController:interactiveVC];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory]; 
        [outputStream open];
        
        [Serializator getAsData:merged
                         format:merged.originalFormat
                   outputStream:outputStream
                     completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
            
            [outputStream close];
            NSData* mergedData = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];

            dispatch_async(dispatch_get_main_queue(), ^{
                if ( interactiveVC ) {
                    [self.spinnerUi dismiss];
                }
                
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
                    [self logMessage:databaseUuid syncId:syncId message:@"Encrypted Merge Result... pushing to Source DB and setting local..."];
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
        else if ( result == kUpdateResultUnavailable ) {
            [self logAndPublishStatusChange:databaseUuid
                                     syncId:syncId
                                      state:kSyncOperationStateDone
                                      error:error];
            
            completion(kSyncAndMergeSuccess, NO, nil);
        }
        else {
            database.outstandingUpdateId = nil;
            
            [self logMessage:databaseUuid syncId:syncId message:[NSString stringWithFormat:@"Outstanding Update successfully pushed to Source DB. [New Source DB Mod Date=%@]. Making Working Copy Match Source...", newRemoteModDate.friendlyDateTimeStringBothPrecise]];

            if (!newRemoteModDate) {
                slog(@"WARNWARN: No new remote mod date returned from storage provider! Setting to NOW.");
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
    if(![self setWorkingCache:data dateModified:dateModified database:databaseUuid takeABackup:takeABackup error:&error]) {
        [self logMessage:databaseUuid syncId:syncId message:@"Could not sync working copy from source."];

        [self logAndPublishStatusChange:databaseUuid
                                 syncId:syncId
                                  state:kSyncOperationStateError
                                  error:error];
    
        completion(kSyncAndMergeError, NO, error);
    }
    else {
        NSDate* localModDate;
        [self getExistingWorkingCache:databaseUuid modified:&localModDate];

        [self logMessage:databaseUuid syncId:syncId
                 message:[NSString stringWithFormat:@"Working copy successfully synced with source db. Expected = [%@], Actual [%@]", dateModified.friendlyDateTimeStringBothPrecise, localModDate.friendlyDateTimeStringBothPrecise]];
        
        [self logAndPublishStatusChange:databaseUuid syncId:syncId state:kSyncOperationStateDone error:nil];

        

        METADATA_PTR database = [self databaseMetadataFromDatabaseId:databaseUuid];
        database.lastSyncRemoteModDate = dateModified;
                
        completion(kSyncAndMergeSuccess, localWasChanged, nil);
    }
}




- (NSURL*_Nullable)getExistingWorkingCache:(NSString*)databaseUuid modified:(NSDate**)modified {
    return [WorkingCopyManager.sharedInstance getLocalWorkingCache:databaseUuid modified:modified];
}

- (NSURL*)setWorkingCache:(NSData*)data
             dateModified:(NSDate*)dateModified
                 database:(NSString*)databaseUuid
              takeABackup:(BOOL)takeABackup
                    error:(NSError**)error {
    if ( takeABackup ) {
        NSURL* localWorkingCache = [self getExistingWorkingCache:databaseUuid modified:nil];
        
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
    }
    
    return [WorkingCopyManager.sharedInstance setWorkingCacheWithData:data dateModified:dateModified database:databaseUuid error:error];
}

- (void)publishSyncStatusChangeNotification:(SyncStatus*)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kSyncManagerDatabaseSyncStatusChangedNotification object:info.databaseId];
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
