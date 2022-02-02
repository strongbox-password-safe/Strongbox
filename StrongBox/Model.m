//
//  SafeViewModel.m
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Model.h"
#import "Utils.h"
#import "AutoFillManager.h"
#import "PasswordMaker.h"
#import "BackupsManager.h"
#import "NSArray+Extensions.h"
#import "DatabaseAuditor.h"
#import "Serializator.h"
#import "SampleItemsGenerator.h"
#import "DatabaseUnlocker.h"
#import "ConcurrentMutableStack.h"
#import "FileManager.h"
#import "CrossPlatform.h"
#import "AsyncUpdateJob.h"
#import "NSMutableArray+Extensions.h"
#import "WorkingCopyManager.h"

NSString* const kAuditNodesChangedNotificationKey = @"kAuditNodesChangedNotificationKey";
NSString* const kAuditProgressNotificationKey = @"kAuditProgressNotificationKey";
NSString* const kAuditCompletedNotificationKey = @"kAuditCompletedNotificationKey";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";
NSString* const kMasterDetailViewCloseNotification = @"kMasterDetailViewClose";
NSString* const kDatabaseViewPreferencesChangedNotificationKey = @"kDatabaseViewPreferencesChangedNotificationKey";
NSString* const kProStatusChangedNotificationKey = @"proStatusChangedNotification";
NSString* const kAppStoreSaleNotificationKey = @"appStoreSaleNotification";
NSString *const kWormholeAutoFillUpdateMessageId = @"auto-fill-workhole-message-id";

NSString* const kDatabaseReloadedNotificationKey = @"kDatabaseReloadedNotificationKey";
NSString* const kAsyncUpdateDone = @"kAsyncUpdateDone";
NSString* const kAsyncUpdateStarting = @"kAsyncUpdateStarting";

NSString* const kSpecialSearchTermAllEntries = @"strongbox:allEntries";
NSString* const kSpecialSearchTermAuditEntries = @"strongbox:auditEntries";
NSString* const kSpecialSearchTermTotpEntries = @"strongbox:totpEntries";
NSString* const kSpecialSearchTermExpiredEntries = @"strongbox:expiredEntries";
NSString* const kSpecialSearchTermNearlyExpiredEntries = @"strongbox:nearlyExpiredEntries";

@interface Model ()

@property NSSet<NSString*> *cachedPinned;
@property DatabaseAuditor* auditor;
@property BOOL isAutoFillOpen;
@property BOOL forcedReadOnly;
@property BOOL isDuressDummyMode;
@property DatabaseModel* theDatabase;
@property BOOL offlineMode;

@property dispatch_queue_t asyncUpdateEncryptionQueue;
@property ConcurrentMutableStack<AsyncUpdateJob*>* asyncUpdatesStack;

@property (readonly) id<ApplicationPreferences> applicationPreferences;
@property (readonly) id<SyncManagement> syncManagement;
@property (readonly) id<SpinnerUI> spinnerUi;

@end

@implementation Model

- (id<ApplicationPreferences>)applicationPreferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}

- (id<SyncManagement>)syncManagement {
    return CrossPlatformDependencies.defaults.syncManagement;
}

- (id<SpinnerUI>)spinnerUi {
    return CrossPlatformDependencies.defaults.spinnerUi;
}



- (NSData*)getDuressDummyData {
    return self.applicationPreferences.duressDummyData; 
}

- (void)setDuressDummyData:(NSData*)data {
    self.applicationPreferences.duressDummyData = data;
}

- (void)dealloc {
    NSLog(@"=====================================================================");
    NSLog(@"😎 Model DEALLOC...");
    NSLog(@"=====================================================================");
}

- (void)closeAndCleanup { 
    NSLog(@"Model closeAndCleanup...");
    if (self.auditor) {
        [self.auditor stop];
        self.auditor = nil;
    }
}

#if TARGET_OS_IPHONE

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen
                 templateMetaData:(METADATA_PTR)templateMetaData {
    METADATA_PTR meta = [DatabasePreferences templateDummyWithNickName:templateMetaData.nickName
                                                       storageProvider:templateMetaData.storageProvider
                                                              fileName:templateMetaData.fileName
                                                        fileIdentifier:templateMetaData.fileIdentifier];
    self.isDuressDummyDatabase = YES;
    
    NSData* data = [self getDuressDummyData];
    if (!data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];

        DatabaseModel* model = [[DatabaseModel alloc] initWithFormat:kKeePass compositeKeyFactors:cpf];
        
        [SampleItemsGenerator addSampleGroupAndRecordToRoot:model passwordConfig:self.applicationPreferences.passwordGenerationConfig];
        
        data = [Serializator expressToData:model format:model.originalFormat];
        
        [self setDuressDummyData:data];
    }

    DatabaseModel* model = [Serializator expressFromData:data password:@"1234"];
    
    return [self initWithDatabase:model
                         metaData:meta
                   forcedReadOnly:NO
                       isAutoFill:isAutoFillOpen
                      offlineMode:NO
                isDuressDummyMode:YES];
}

#endif

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(METADATA_PTR)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill {
    return [self initWithDatabase:passwordDatabase
                         metaData:metaData
                   forcedReadOnly:forcedReadOnly
                       isAutoFill:isAutoFill
                      offlineMode:NO];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(METADATA_PTR)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill
                     offlineMode:(BOOL)offlineMode {
    return [self initWithDatabase:passwordDatabase
                         metaData:metaData
                   forcedReadOnly:forcedReadOnly
                       isAutoFill:isAutoFill
                      offlineMode:offlineMode
                isDuressDummyMode:NO];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(METADATA_PTR)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill
                     offlineMode:(BOOL)offlineMode
               isDuressDummyMode:(BOOL)isDuressDummyMode {
    if (self = [super init]) {
        if ( !passwordDatabase ) {
            return nil;
        }
        
        _metadata = metaData;
        self.theDatabase = passwordDatabase;
        self.asyncUpdateEncryptionQueue = dispatch_queue_create("Model-AsyncUpdateEncryptionQueue", DISPATCH_QUEUE_SERIAL);
        self.asyncUpdatesStack = ConcurrentMutableStack.mutableStack;
        
        _cachedPinned = [NSSet setWithArray:self.metadata.favourites];
                
        if ( self.applicationPreferences.databasesAreAlwaysReadOnly ) {
            self.forcedReadOnly = YES;
        }
        else {
            self.forcedReadOnly = forcedReadOnly;
        }
        
        self.isAutoFillOpen = isAutoFill;
        self.isDuressDummyMode = isDuressDummyMode;
        self.offlineMode = offlineMode;
        
        [self createNewAuditor];
        
        return self;
    }
    else {
        return nil;
    }
}



- (NSString *)databaseUuid {
    return self.metadata.uuid;
}

- (DatabaseModel *)database {
    return self.theDatabase;
}

- (Node *)getItemById:(NSUUID *)uuid {
    return [self.database getItemById:uuid];
}

- (void)reloadDatabaseFromLocalWorkingCopy:(VIEW_CONTROLLER_PTR)viewController 
                                completion:(void(^)(BOOL success))completion {
    if (self.isDuressDummyMode) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (completion) {
                completion(YES);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotificationKey object:nil];
            });
        });
        return;
    }

    NSLog(@"reloadDatabaseFromLocalWorkingCopy....");

    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:self.metadata
                                                        viewController:viewController
                                                         forceReadOnly:self.forcedReadOnly
                                                        isAutoFillOpen:self.isAutoFillOpen
                                                           offlineMode:self.offlineMode];
    [unlocker unlockLocalWithKey:self.database.ckfs keyFromConvenience:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess) {
            NSLog(@"reloadDatabaseFromLocalWorkingCopy... Success ");

            self.theDatabase = model.database;
            if (completion) {
                completion(YES);
            }
            
            [self restartBackgroundAudit];

            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotificationKey object:nil];
            });
        }
        else {
            NSLog(@"Unlocking local copy for database reload request failed: %@", error);
            
            
            
            

            
            if (completion) {
                completion(NO); 
            }
        }
    }];
}



- (void)clearAsyncUpdateState {
    [self.asyncUpdatesStack clear];
    self.lastAsyncUpdateResult = nil;
}

- (BOOL)asyncUpdateAndSync {
    return [self asyncUpdateAndSync:nil];
}

- (BOOL)asyncUpdateAndSync:(AsyncUpdateCompletion)completion {
    NSLog(@"asyncUpdateAndSync ENTER");

    if(self.isReadOnly) {
        NSLog(@"🔴 WARNWARN - Database is Read Only - Will not UPDATE! Last Resort. - WARNWARN");
        return NO;
    }
    
    AsyncUpdateJob* job = [[AsyncUpdateJob alloc] init];
    job.snapshot = [self.database clone];
    job.completion = completion;
    
    [self.asyncUpdatesStack push:job];
    
    dispatch_async(self.asyncUpdateEncryptionQueue, ^{
        [self dequeueOutstandingAsyncUpdateAndProcess];
    });

    NSLog(@"asyncUpdateAndSync EXIT");

    return YES;
}

- (void)dequeueOutstandingAsyncUpdateAndProcess {
    AsyncUpdateJob* job = [self.asyncUpdatesStack popAndClear]; 
    
    if ( job ) {
        [self queueAsyncUpdateWithDatabaseClone:NSUUID.UUID job:job];
    }
    else {
        NSLog(@"NOP - No outstanding async updates found. All Done.");
    }
}

- (NSString*)getUniqueStreamingFilename {
    NSString* ret;
    
    do {
#if TARGET_OS_IPHONE
        ret = [FileManager.sharedInstance.tmpEncryptionStreamPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
#else
        
        
        NSURL* localWorkingCacheUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCacheUrlForDatabase:self.databaseUuid];
        NSError* error;
        NSURL* url = [NSFileManager.defaultManager URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:localWorkingCacheUrl create:YES error:&error];

        if ( !url ) {
            NSLog(@"getUniqueStreamingFilename: ERROR = [%@]", error);
            return [FileManager.sharedInstance.tmpEncryptionStreamPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        }

        ret = [url URLByAppendingPathComponent:NSUUID.UUID.UUIDString].path;
        NSLog(@"MacOS - getUniqueStreamingFilename [FINAL] = [%@]", ret);
#endif
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}

- (void)queueAsyncUpdateWithDatabaseClone:(NSUUID*)updateId job:(AsyncUpdateJob*)job {
    NSLog(@"queueAsyncUpdateWithDatabaseClone ENTER - [%@]", NSThread.currentThread.name);
    
    _isRunningAsyncUpdate = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateStarting object:nil];
    });
    
    dispatch_group_t mutex = dispatch_group_create();
    dispatch_group_enter(mutex);
    
    NSString* streamingFile = [self getUniqueStreamingFilename];
    NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath:streamingFile append:NO];
    [outputStream open];
    
    [Serializator getAsData:job.snapshot
                     format:job.snapshot.originalFormat
               outputStream:outputStream
                 completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
        [outputStream close];
        
        [self onAsyncUpdateSerializeDone:updateId userCancelled:userCancelled streamingFile:streamingFile updateMutex:mutex job:job error:error]; 
    }];

    dispatch_group_wait(mutex, DISPATCH_TIME_FOREVER);
    
    NSLog(@"queueAsyncUpdateWithDatabaseClone EXIT - [%@]", NSThread.currentThread.name);
}

- (void)onAsyncUpdateSerializeDone:(NSUUID*)updateId
                     userCancelled:(BOOL)userCancelled
                     streamingFile:(NSString*)streamingFile
                       updateMutex:(dispatch_group_t)updateMutex
                               job:(AsyncUpdateJob*)job
                             error:(NSError * _Nullable)error {
    if (userCancelled || error) {
        
        [self onAsyncUpdateDone:updateId job:job success:NO userCancelled:userCancelled userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:error];
        return;
    }
    
    if (self.isDuressDummyMode) {
        NSData* data = [NSData dataWithContentsOfFile:streamingFile];
        [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];
        
        [self setDuressDummyData:data];
        [self onAsyncUpdateDone:updateId job:job success:YES userCancelled:NO userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:nil];
        return;
    }

    NSError* localUpdateError;
    BOOL success = [self.syncManagement updateLocalCopyMarkAsRequiringSync:self.metadata file:streamingFile error:&localUpdateError];
    [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];

    if (!success) { 
        [self onAsyncUpdateDone:updateId job:job success:NO userCancelled:NO userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:localUpdateError];
        return;
    }

    

    if (self.metadata.auditConfig.auditInBackground) {
        [self restartAudit];
    }

    
    
    if ( self.offlineMode ) { 
        [self onAsyncUpdateDone:updateId job:job success:YES userCancelled:NO userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:nil];
        return;
    }

    [self.syncManagement sync:self.metadata
                       interactiveVC:nil
                                 key:self.database.ckfs
                                join:NO
                          completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( result == kSyncAndMergeSuccess ) {
            if(self.metadata.autoFillEnabled && self.metadata.quickTypeEnabled) {
                [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database
                                                                   databaseUuid:self.metadata.uuid
                                                                  displayFormat:self.metadata.quickTypeDisplayFormat
                                                                alternativeUrls:self.metadata.autoFillScanAltUrls
                                                                   customFields:self.metadata.autoFillScanCustomFields
                                                                          notes:self.metadata.autoFillScanNotes
                                                   concealedCustomFieldsAsCreds:self.metadata.autoFillConcealedFieldsAsCreds
                                                 unConcealedCustomFieldsAsCreds:self.metadata.autoFillUnConcealedFieldsAsCreds];
            }

            [self onAsyncUpdateDone:updateId job:job success:YES userCancelled:userCancelled userInteractionRequired:NO localUpdated:localWasChanged updateMutex:updateMutex error:nil];
        }
        else if (result == kSyncAndMergeError) {
            [self onAsyncUpdateDone:updateId job:job success:NO userCancelled:userCancelled userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:error];
        }
        else if ( result == kSyncAndMergeResultUserInteractionRequired ) {
            [self onAsyncUpdateDone:updateId job:job success:NO userCancelled:userCancelled userInteractionRequired:YES localUpdated:NO updateMutex:updateMutex error:error];
        }
        else {
            error = [Utils createNSError:[NSString stringWithFormat:@"Unexpected result returned from async update sync: [%@]", @(result)] errorCode:-1];
            [self onAsyncUpdateDone:updateId job:job success:NO userCancelled:userCancelled userInteractionRequired:NO localUpdated:NO updateMutex:updateMutex error:error];
        }
    }];
}

- (void)onAsyncUpdateDone:(NSUUID*)updateId
                      job:(AsyncUpdateJob*)job
                  success:(BOOL)success
            userCancelled:(BOOL)userCancelled
  userInteractionRequired:(BOOL)userInteractionRequired
             localUpdated:(BOOL)localUpdated
              updateMutex:(dispatch_group_t)updateMutex
                    error:(NSError*)error {
    NSLog(@"onAsyncUpdateDone: updateId=%@ success=%hhd, userInteractionRequired=%hhd, localUpdated=%hhd, error=%@", updateId, success, userInteractionRequired, localUpdated, error);

    AsyncUpdateResult* result;

    result = [[AsyncUpdateResult alloc] init];
    result.success = success;
    result.error = error;
    result.userCancelled = userCancelled;
    result.localWasChanged = localUpdated;
    result.userInteractionRequired = userInteractionRequired;

    self.lastAsyncUpdateResult = result;
    _isRunningAsyncUpdate = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateDone object:nil];
        
        if ( job.completion ) {
            job.completion(result);
        }
    });
    
    dispatch_group_leave(updateMutex);
}



- (void)update:(VIEW_CONTROLLER_PTR)viewController handler:(void(^)(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error))handler {
    if(self.isReadOnly) {
        handler(NO, NO, [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1]);
        return;
    }

    [self encrypt:viewController completion:^(BOOL userCancelled, NSString * _Nullable file, NSString * _Nullable debugXml, NSError * _Nullable error) {
        if (userCancelled || error) {
            handler(userCancelled, NO, error);
            return;
        }

        [self onEncryptionDone:viewController streamingFile:file completion:handler];
    }];
}

- (void)encrypt:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(BOOL userCancelled, NSString* file, NSString*_Nullable debugXml, NSError* error))completion {
    [self.spinnerUi show:NSLocalizedString(@"generic_encrypting", @"Encrypting") viewController:viewController];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSString* tmpFile = [self getUniqueStreamingFilename];
        NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath:tmpFile append:NO];
        [outputStream open];

        [Serializator getAsData:self.database
                         format:self.database.originalFormat
                   outputStream:outputStream
                     completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
            [outputStream close];            

            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.spinnerUi dismiss];

                completion(userCancelled, tmpFile, debugXml, error);
            });
        }];
    });
}

- (void)onEncryptionDone:(VIEW_CONTROLLER_PTR)viewController streamingFile:(NSString*)streamingFile completion:(void(^)(BOOL userCancelled, BOOL localWasChanged, const NSError * _Nullable error))completion {
    if (self.isDuressDummyMode) {
        NSData* data = [NSData dataWithContentsOfFile:streamingFile];
        [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];
        [self setDuressDummyData:data];
        completion(NO, NO, nil);
        return;
    }
    
    
    
    NSError* error;
    BOOL success = [self.syncManagement updateLocalCopyMarkAsRequiringSync:self.metadata file:streamingFile error:&error];
    [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];

    if (!success) {
        completion(NO, NO, error);
        return;
    }
    
    
    
    if (self.metadata.auditConfig.auditInBackground) {
        [self restartAudit];
    }

    if ( self.offlineMode ) { 
        completion(NO, NO, nil);
    }
    else {
        [self.syncManagement sync:self.metadata
                    interactiveVC:viewController
                              key:self.database.ckfs
                             join:NO
                       completion:^(SyncAndMergeResult result, BOOL localWasChanged, const NSError * _Nullable error) {
            if (result == kSyncAndMergeSuccess || result == kSyncAndMergeUserPostponedSync) {
                if(self.metadata.autoFillEnabled && self.metadata.quickTypeEnabled) {
                    [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database
                                                                       databaseUuid:self.metadata.uuid
                                                                      displayFormat:self.metadata.quickTypeDisplayFormat
                                                                    alternativeUrls:self.metadata.autoFillScanAltUrls
                                                                       customFields:self.metadata.autoFillScanCustomFields
                                                                              notes:self.metadata.autoFillScanNotes
                                                       concealedCustomFieldsAsCreds:self.metadata.autoFillConcealedFieldsAsCreds
                                                     unConcealedCustomFieldsAsCreds:self.metadata.autoFillUnConcealedFieldsAsCreds];
                }

                completion(NO, localWasChanged, nil);
            }
            else if (result == kSyncAndMergeError) {
                completion(NO, NO, error);
            }
            else if (result == kSyncAndMergeResultUserCancelled) {
                
                NSString* message = NSLocalizedString(@"sync_could_not_sync_your_changes", @"Strongbox could not sync your changes.");
                error = [Utils createNSError:message errorCode:-1];
                completion(YES, NO, error);
            }
            else { 
                error = [Utils createNSError:[NSString stringWithFormat:@"Unexpected result returned from interactive update sync: [%@]", @(result)] errorCode:-1];
                completion(NO, NO, error);
            }
        }];
    }
}



- (AuditState)auditState {
    return self.auditor.state;
}

- (void)restartBackgroundAudit {
    if (!self.isAutoFillOpen && self.metadata.auditConfig.auditInBackground) {
         [self restartAudit];
    }
    else {
        NSLog(@"Audit not configured to run. Skipping.");
    }
}

- (void)stopAudit {
    if (self.auditor) {
        [self.auditor stop];
    }
}

- (void)stopAndClearAuditor {
    [self stopAudit];
    [self createNewAuditor];
}

- (void)createNewAuditor {
#ifndef IS_APP_EXTENSION
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];

    __weak Model* weakSelf = self;
    self.auditor = [[DatabaseAuditor alloc] initWithPro:self.applicationPreferences.isProOrFreeTrial
                                         strengthConfig:self.applicationPreferences.passwordStrengthConfig
                                             isExcluded:^BOOL(Node * _Nonnull item) {
        return [weakSelf isExcludedFromAuditHelper:set uuid:item.uuid];
    }
                                             saveConfig:^(DatabaseAuditorConfiguration * _Nonnull config) {
        weakSelf.metadata.auditConfig = config;
    }];
#endif
}

- (BOOL)isExcludedFromAudit:(NSUUID *)item {
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];
    
    return [self isExcludedFromAuditHelper:set uuid:item];
}

- (BOOL)isExcludedFromAuditHelper:(NSSet<NSString*> *)set uuid:(NSUUID*)uuid {
    Node* node = [self.database getItemById:uuid];
    if ( !node.fields.qualityCheck ) { 
        return YES;
    }
    
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:uuid];

    return [set containsObject:sid];
}

- (void)restartAudit {
    [self stopAndClearAuditor];

#ifndef IS_APP_EXTENSION
    [self.auditor start:self.database
                 config:self.metadata.auditConfig
            nodesChanged:^{

        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditNodesChangedNotificationKey object:nil];
        });
    }
    progress:^(double progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditProgressNotificationKey object:@(progress)];
        });
    } completion:^(BOOL userStopped) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditCompletedNotificationKey object:@(userStopped)];
        });
    }];
#endif
}

- (NSUInteger)auditHibpErrorCount {
    return self.auditor ? self.auditor.haveIBeenPwnedErrorCount : 0;
}

- (NSNumber*)auditIssueCount {
    return self.auditor ? @(self.auditor.auditIssueCount) : nil;
}

- (NSUInteger)auditIssueNodeCount {
    return self.auditor ? self.auditor.auditIssueNodeCount : 0;
}

- (NSString *)getQuickAuditVeryBriefSummaryForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditVeryBriefSummaryForNode:item];
    }
    
    return @"";
}

- (NSString *)getQuickAuditSummaryForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditSummaryForNode:item];
    }
    
    return @"";
}

- (NSSet<NSNumber *> *)getQuickAuditFlagsForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditFlagsForNode:item];
    }
    
    return NSSet.set;
}

- (BOOL)isFlaggedByAudit:(NSUUID *)item {
    if (self.auditor) {
        NSSet<NSNumber*>* auditFlags = [self.auditor getQuickAuditFlagsForNode:item];
        return auditFlags.count > 0;
    }
    
    return NO;
}

- (NSSet<Node *> *)getSimilarPasswordNodeSet:(NSUUID *)node {
    if (self.auditor) {
        NSSet<NSUUID*>* sims = [self.auditor getSimilarPasswordNodeSet:node];
        
        return [[sims.allObjects filter:^BOOL(NSUUID * _Nonnull obj) {
            return [self.database getItemById:obj] != nil;
        }] map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
            return [self.database getItemById:obj];
        }].set;
    }
    
    return NSSet.set;
}

- (NSSet<Node *> *)getDuplicatedPasswordNodeSet:(NSUUID *)node {
    if (self.auditor) {
        NSSet<NSUUID*>* dupes = [self.auditor getDuplicatedPasswordNodeSet:node];
        
        return [[dupes.allObjects filter:^BOOL(NSUUID * _Nonnull obj) {
            return [self.database getItemById:obj] != nil;
        }] map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
            return [self.database getItemById:obj];
        }].set;
    }
    
    return NSSet.set;
}

- (void)setItemAuditExclusion:(NSUUID *)item exclude:(BOOL)exclude {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:item];
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
        
    NSMutableSet<NSString*> *mutable = [NSMutableSet setWithArray:excluded];
    
    if (exclude) {
        [mutable addObject:sid];
    }
    else {
        [mutable removeObject:sid];
    }
    
    self.metadata.auditExcludedItems = mutable.allObjects;
}

- (NSArray<Node*>*)getExcludedAuditItems {
    NSSet<NSString*> *excludedSet = [NSSet setWithArray:self.metadata.auditExcludedItems];
    return [self getNodesFromSerializationIds:excludedSet];
}

- (void)oneTimeHibpCheck:(NSString *)password completion:(void (^)(BOOL, NSError * _Nonnull))completion {
    if (self.auditor) {
        [self.auditor oneTimeHibpCheck:password completion:completion];
    }
    else {
        completion (NO, [Utils createNSError:@"Auditor Unavailable!" errorCode:-2345]);
    }
}



- (BOOL)isInOfflineMode {
    return self.offlineMode;
}

- (BOOL)isReadOnly {
    return self.metadata.readOnly || self.forcedReadOnly;
}

- (void)disableAndClearAutoFill {
    self.metadata.autoFillEnabled = NO;
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
}

- (void)enableAutoFill {
    self.metadata.autoFillEnabled = YES;
}




- (Node*)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title {
    BOOL keePassGroupTitleRules = self.database.originalFormat != kPasswordSafe;
    
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup keePassGroupTitleRules:keePassGroupTitleRules uuid:nil];
    
    if ( [self.database addChild:newGroup destination:parentGroup] ) {
        return newGroup;
    }

    return nil;
}

- (Node *)addItem:(Node *)parent item:(Node *)item {
    if ( [self.database addChild:item destination:parent] ) {
        return item;
    }
    return nil;
}

- (BOOL)canRecycle:(NSUUID *)itemId {
    return [self.database canRecycle:itemId];
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    [self.database deleteItems:items];

    
    
    for (Node* item in items) {
        if([self isPinned:item.uuid]) {
            [self togglePin:item.uuid];
        }
    }
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    BOOL ret = [self.database recycleItems:items];
    
    if (ret) { 
        for (Node* item in items) {
            if([self isPinned:item.uuid]) {
                [self togglePin:item.uuid];
            }
        }
    }
    
    return ret;
}

- (BOOL)launchUrl:(Node *)item {
    NSURL* launchableUrl = [self.database launchableUrlForItem:item];
        
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for item.");
        return NO;
    }
    
    [self launchLaunchableUrl:launchableUrl];
    
    return YES;
}

- (BOOL)launchUrlString:(NSString*)urlString {
    NSURL* launchableUrl = [self.database launchableUrlForUrlString:urlString];
        
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for string.");
        return NO;
    }
    
    [self launchLaunchableUrl:launchableUrl];
    return YES;
}

- (void)launchLaunchableUrl:(NSURL*)launchableUrl {
#if TARGET_OS_IPHONE
#ifndef IS_APP_EXTENSION
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (@available (iOS 10.0, *)) {
            [UIApplication.sharedApplication openURL:launchableUrl options:@{} completionHandler:^(BOOL success) {
                if (!success) {
                    NSLog(@"Couldn't launch this URL!");
                }
            }];
        }
        else {
            [UIApplication.sharedApplication openURL:launchableUrl];
        }
    });
#endif
#else
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for item.");
        return;
    }
    
    if (@available(macOS 10.15, *)) {
        [[NSWorkspace sharedWorkspace] openURL:launchableUrl
                                 configuration:NSWorkspaceOpenConfiguration.configuration
                             completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
            if ( error ) {
                NSLog(@"Launch URL done. Error = [%@]", error);
            }
        }];
    } else {
        [[NSWorkspace sharedWorkspace] openURL:launchableUrl];
    }
#endif
}



- (NSArray<Node*>*)pinnedNodes {
    return [self getNodesFromSerializationIds:self.pinnedSet];
}

- (NSSet<NSString*>*)pinnedSet {
    return self.cachedPinned;
}

- (BOOL)isPinned:(NSUUID *)itemId {
    if(self.cachedPinned.count == 0) {
        return NO;
    }
    
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];
    
    return [self.cachedPinned containsObject:sid];
}

- (void)togglePin:(NSUUID *)itemId {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];

    NSMutableSet<NSString*>* favs = self.cachedPinned.mutableCopy;
    
    if([self isPinned:itemId]) {
        [favs removeObject:sid];
    }
    else {
        [favs addObject:sid];
    }
    
    
    
    __weak Model* weakSelf = self;
    NSArray<Node*>* pinned = [self.database.effectiveRootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:node.uuid];
        return [favs containsObject:sid];
    }];
    
    NSArray<NSString*>* trimmed = [pinned map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:obj.uuid];
        return sid;
    }];
    self.cachedPinned = [NSSet setWithArray:trimmed];

    self.metadata.favourites = trimmed;
}



- (NSString *)generatePassword {
    PasswordGenerationConfig* config = self.applicationPreferences.passwordGenerationConfig;
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:config];
}



- (NSArray<Node*>*)getNodesFromSerializationIds:(NSSet<NSString*>*)set {
    NSMutableArray<Node*>* ret = @[].mutableCopy;
    
    for (NSString *sid in set) {
        Node* node = [self.database getItemByCrossSerializationFriendlyId:sid];
        
        if (node) {
            [ret addObject:node];
        }
    }
    
    return [ret sortedArrayUsingComparator:finderStyleNodeComparator];
}

- (NSArray<Node *>*)allNodes {
    return self.database.effectiveRootGroup.allChildren;
}

-(NSArray<Node *> *)allRecords {
    return self.database.effectiveRootGroup.allChildRecords;
}

-(NSArray<Node *> *)allGroups {
    return self.database.effectiveRootGroup.allChildGroups;
}



- (DatabaseFormat)originalFormat {
    return self.database.originalFormat;
}

- (BOOL)isDereferenceableText:(NSString *)text {
    return [self.database isDereferenceableText:text];
}

- (NSString *)dereference:(NSString *)text node:(Node *)node {
    return [self.database dereference:text node:node];
}



- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups
          browseSortField:(BrowseSortField)browseSortField
               descending:(BOOL)descending
        foldersSeparately:(BOOL)foldersSeparately {
    return [self search:searchText
                  scope:scope
            dereference:dereference
  includeKeePass1Backup:includeKeePass1Backup
      includeRecycleBin:includeRecycleBin
         includeExpired:includeExpired
          includeGroups:includeGroups
               trueRoot:NO
        browseSortField:browseSortField
             descending:descending
      foldersSeparately:foldersSeparately];
}

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups
                 trueRoot:(BOOL)trueRoot
          browseSortField:(BrowseSortField)browseSortField
               descending:(BOOL)descending
        foldersSeparately:(BOOL)foldersSeparately {
    NSArray<Node*>* nodes = trueRoot ? self.database.allSearchableTrueRoot : self.database.allSearchable;
    
    return [self searchNodes:nodes
                  searchText:searchText
                       scope:scope
                 dereference:dereference
       includeKeePass1Backup:includeKeePass1Backup
           includeRecycleBin:includeRecycleBin
              includeExpired:includeExpired
               includeGroups:includeGroups
             browseSortField:browseSortField
                  descending:descending
           foldersSeparately:foldersSeparately];
}

- (NSArray<Node*>*)searchNodes:(NSArray<Node*>*)nodes
                    searchText:(NSString *)searchText
                         scope:(SearchScope)scope
                   dereference:(BOOL)dereference
         includeKeePass1Backup:(BOOL)includeKeePass1Backup
             includeRecycleBin:(BOOL)includeRecycleBin
                includeExpired:(BOOL)includeExpired
                 includeGroups:(BOOL)includeGroups
               browseSortField:(BrowseSortField)browseSortField
                    descending:(BOOL)descending
             foldersSeparately:(BOOL)foldersSeparately {
    NSMutableArray* results = [nodes mutableCopy]; 
    
    NSArray<NSString*>* terms = [self.database getSearchTerms:searchText];
    
    for (NSString* word in terms) {
        [self filterForWord:results
                 searchText:word
                      scope:scope
                dereference:dereference];
    }
    
    return [self filterAndSortForBrowse:results
                  includeKeePass1Backup:includeKeePass1Backup
                      includeRecycleBin:includeRecycleBin
                         includeExpired:includeExpired
                          includeGroups:includeGroups
                        browseSortField:browseSortField
                             descending:descending
                      foldersSeparately:foldersSeparately];
}

- (NSArray<Node *> *)filterAndSortForBrowse:(NSMutableArray<Node *> *)nodes
                      includeKeePass1Backup:(BOOL)includeKeePass1Backup
                          includeRecycleBin:(BOOL)includeRecycleBin
                             includeExpired:(BOOL)includeExpired
                              includeGroups:(BOOL)includeGroups
                            browseSortField:(BrowseSortField)browseSortField
                                 descending:(BOOL)descending
                          foldersSeparately:(BOOL)foldersSeparately {
    [self filterExcluded:nodes
   includeKeePass1Backup:includeKeePass1Backup
       includeRecycleBin:includeRecycleBin
          includeExpired:includeExpired
           includeGroups:includeGroups];
    
    return [self sortItemsForBrowse:nodes browseSortField:browseSortField descending:descending foldersSeparately:foldersSeparately];
}

- (void)filterForWord:(NSMutableArray<Node*>*)searchNodes
           searchText:(NSString *)searchText
                scope:(NSInteger)scope
          dereference:(BOOL)dereference {
    if ([searchText isEqualToString:kSpecialSearchTermAllEntries]) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return !obj.isGroup;
        }];
    }
    else if ([searchText isEqualToString:kSpecialSearchTermAuditEntries] ) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return [self isFlaggedByAudit:obj.uuid];
        }];
    }
    else if ([searchText isEqualToString:kSpecialSearchTermTotpEntries]) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.otpToken != nil;
        }];
    }
    else if ([searchText isEqualToString:kSpecialSearchTermExpiredEntries]) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.expired;
        }];
    }
    else if ([searchText isEqualToString:kSpecialSearchTermNearlyExpiredEntries]) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.nearlyExpired;
        }];
    }
    else if (scope == kSearchScopeTitle) {
        [self searchTitle:searchNodes searchText:searchText dereference:dereference checkPinYin:self.applicationPreferences.checkPinYin];
    }
    else if (scope == kSearchScopeUsername) {
        [self searchUsername:searchNodes searchText:searchText dereference:dereference checkPinYin:self.applicationPreferences.checkPinYin];
    }
    else if (scope == kSearchScopePassword) {
        [self searchPassword:searchNodes searchText:searchText dereference:dereference checkPinYin:self.applicationPreferences.checkPinYin];
    }
    else if (scope == kSearchScopeUrl) {
        [self searchUrl:searchNodes searchText:searchText dereference:dereference checkPinYin:self.applicationPreferences.checkPinYin];
    }
    else if (scope == kSearchScopeTags) {
        [self searchTags:searchNodes searchText:searchText checkPinYin:self.applicationPreferences.checkPinYin];
    }
    else {
        [self searchAllFields:searchNodes searchText:searchText dereference:dereference checkPinYin:self.applicationPreferences.checkPinYin];
    }
}

- (void)searchTitle:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isTitleMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchUsername:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isUsernameMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchPassword:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isPasswordMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchUrl:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isUrlMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchTags:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isTagsMatches:searchText node:node checkPinYin:checkPinYin];
    }];
}

- (void)searchAllFields:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isAllFieldsMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)filterExcluded:(NSMutableArray<Node*>*)matches
 includeKeePass1Backup:(BOOL)includeKeePass1Backup
     includeRecycleBin:(BOOL)includeRecycleBin
        includeExpired:(BOOL)includeExpired
         includeGroups:(BOOL)includeGroups {
    if(!includeKeePass1Backup) {
        if (self.database.originalFormat == kKeePass1) {
            Node* backupGroup = self.database.keePass1BackupNode;
            if(backupGroup) {
                [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
                    return (obj != backupGroup && ![backupGroup contains:obj]);
                }];
            }
        }
    }

    Node* recycleBin = self.database.recycleBinNode;
    if(!includeRecycleBin && recycleBin) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj != recycleBin && ![recycleBin contains:obj];
        }];
    }

    if(!includeExpired) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return !obj.expired;
        }];
    }
    
    if(!includeGroups) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return !obj.isGroup;
        }];
    }
}

- (NSArray<Node*>*)sortItemsForBrowse:(NSArray<Node*>*)items
                      browseSortField:(BrowseSortField)browseSortField
                           descending:(BOOL)descending
                    foldersSeparately:(BOOL)foldersSeparately {
    BrowseSortField field = browseSortField;
    
    if (field == kBrowseSortFieldEmail && self.database.originalFormat != kPasswordSafe) { 
        field = kBrowseSortFieldTitle;
    }
    else if(field == kBrowseSortFieldNone && self.database.originalFormat == kPasswordSafe) {
        field = kBrowseSortFieldTitle;
    }
    
    if(field != kBrowseSortFieldNone) {
        return [items sortedArrayWithOptions:NSSortStable
                             usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                                 Node* n1 = (Node*)obj1;
                                 Node* n2 = (Node*)obj2;
                                 
                                 return [self compareNodesForSort:n1
                                                            node2:n2
                                                            field:field
                                                       descending:descending
                                                foldersSeparately:foldersSeparately
                                                 tieBreakUseTitle:YES];
                             }];
    }
    else { 
        if ( foldersSeparately ) { 
            
            return [items sortedArrayWithOptions:NSSortStable
                                 usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                Node* node1 = (Node*)obj1;
                Node* node2 = (Node*)obj2;
                
                if ( node1.isGroup == node2.isGroup ) {
                    return NSOrderedSame;
                }
                
                return node1.isGroup ? NSOrderedAscending : NSOrderedDescending;
            }];
        }
        else {
            return items;
        }
    }
}

- (NSComparisonResult)compareNodesForSort:(Node*)node1
                                    node2:(Node*)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately
                         tieBreakUseTitle:(BOOL)tieBreakUseTitle {
    if(foldersSeparately) {
        if(node1.isGroup && !node2.isGroup) {
            return NSOrderedAscending;
        }
        else if(!node1.isGroup && node2.isGroup) {
            return NSOrderedDescending;
        }
    }
    
    
    
    if(node2.isGroup && node1.isGroup && field != kBrowseSortFieldTitle) {
        return finderStringCompare(node1.title, node2.title);
    }
    
    Node* n1 = descending ? node2 : node1;
    Node* n2 = descending ? node1 : node2;
    
    NSComparisonResult result = NSOrderedSame;
    
    if(field == kBrowseSortFieldTitle) {
        result = finderStringCompare(n1.title, n2.title);
    }
    else if(field == kBrowseSortFieldUsername) {
        result = finderStringCompare(n1.fields.username, n2.fields.username);
    }
    else if(field == kBrowseSortFieldPassword) {
        result = finderStringCompare(n1.fields.password, n2.fields.password);
    }
    else if(field == kBrowseSortFieldUrl) {
        result = finderStringCompare(n1.fields.url, n2.fields.url);
    }
    else if(field == kBrowseSortFieldEmail) {
        result = finderStringCompare(n1.fields.email, n2.fields.email);
    }
    else if(field == kBrowseSortFieldNotes) {
        result = finderStringCompare(n1.fields.notes, n2.fields.notes);
    }
    else if(field == kBrowseSortFieldCreated) {
        result = [n1.fields.created compare:n2.fields.created];
    }
    else if(field == kBrowseSortFieldModified) {
        result = [n1.fields.modified compare:n2.fields.modified];
    }
    
    
    
    if( result == NSOrderedSame && field != kBrowseSortFieldTitle && tieBreakUseTitle ) {
        result = finderStringCompare(n1.title, n2.title);
    }
    
    return result;
}

@end
