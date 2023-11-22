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

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

#import "CrossPlatform.h"
#import "AsyncUpdateJob.h"
#import "NSMutableArray+Extensions.h"
#import "WorkingCopyManager.h"
#import "Constants.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kAuditNodesChangedNotificationKey = @"kAuditNodesChangedNotificationKey";
NSString* const kAuditProgressNotificationKey = @"kAuditProgressNotificationKey";
NSString* const kAuditCompletedNotificationKey = @"kAuditCompletedNotificationKey";
NSString* const kAuditNewSwitchedOffNotificationKey = @"kAuditNewSwitchedOffNotificationKey";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";
NSString* const kMasterDetailViewCloseNotification = @"kMasterDetailViewClose";
NSString* const kDatabaseViewPreferencesChangedNotificationKey = @"kDatabaseViewPreferencesChangedNotificationKey";

NSString* const kAppStoreSaleNotificationKey = @"appStoreSaleNotification";
NSString *const kWormholeAutoFillUpdateMessageId = @"auto-fill-workhole-message-id";

NSString* const kDatabaseReloadedNotificationKey = @"kDatabaseReloadedNotificationKey";
NSString* const kTabsMayHaveChangedDueToModelEdit = @"kTabsMayHaveChangedDueToModelEdit-iOS";

NSString* const kAsyncUpdateDone = @"kAsyncUpdateDone";
NSString* const kAsyncUpdateStarting = @"kAsyncUpdateStarting";

NSString* const kSpecialSearchTermAllEntries = @"strongbox:allEntries";
NSString* const kSpecialSearchTermAuditEntries = @"strongbox:auditEntries";
NSString* const kSpecialSearchTermTotpEntries = @"strongbox:totpEntries";
NSString* const kSpecialSearchTermExpiredEntries = @"strongbox:expiredEntries";
NSString* const kSpecialSearchTermNearlyExpiredEntries = @"strongbox:nearlyExpiredEntries";

@interface Model ()

@property NSSet<NSString*> *cachedLegacyFavourites;
@property DatabaseAuditor* auditor;
@property BOOL isNativeAutoFillAppExtensionOpen;
@property BOOL forcedReadOnly;
@property BOOL isDuressDummyMode;
@property DatabaseModel* theDatabase;
@property BOOL offlineMode;

@property dispatch_queue_t asyncUpdateEncryptionQueue;
@property ConcurrentMutableStack<AsyncUpdateJob*>* asyncUpdatesStack;

@property (readonly) id<ApplicationPreferences> applicationPreferences;
@property (readonly) id<SyncManagement> syncManagement;
@property (readonly) NSArray<Node*>* legacyFavourites;

@property (readonly) NSDictionary<NSString*, NSSet<NSUUID*>*> *domainNodeMap; 

@end

@implementation Model

- (id<ApplicationPreferences>)applicationPreferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}

- (id<SyncManagement>)syncManagement {
    return CrossPlatformDependencies.defaults.syncManagement;
}



- (NSData*)getDuressDummyData {
    return self.applicationPreferences.duressDummyData; 
}

- (void)setDuressDummyData:(NSData*)data {
    self.applicationPreferences.duressDummyData = data;
}

- (void)dealloc {
    
    NSLog(@"😎 Model DEALLOC...");
    
}

- (void)closeAndCleanup { 
    NSLog(@"Model closeAndCleanup...");
    if (self.auditor) {
        [self.auditor stop];
        self.auditor = nil;
    }
}

#if TARGET_OS_IPHONE

- (instancetype)initAsDuressDummy:(BOOL)isNativeAutoFillAppExtensionOpen
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
                       isAutoFill:isNativeAutoFillAppExtensionOpen
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
        
        _domainNodeMap = @{};
        _metadata = metaData;
        self.theDatabase = passwordDatabase;
        self.asyncUpdateEncryptionQueue = dispatch_queue_create("Model-AsyncUpdateEncryptionQueue", DISPATCH_QUEUE_SERIAL);
        self.asyncUpdatesStack = ConcurrentMutableStack.mutableStack;
        
        _cachedLegacyFavourites = [NSSet setWithArray:self.metadata.favourites];
        
        if ( self.applicationPreferences.databasesAreAlwaysReadOnly ) {
            self.forcedReadOnly = YES;
        }
        else {
            self.forcedReadOnly = forcedReadOnly;
        }
        
        self.isNativeAutoFillAppExtensionOpen = isAutoFill;
        self.isDuressDummyMode = isDuressDummyMode;
        self.offlineMode = offlineMode;
        
        [self rebuildAutoFillDomainNodeMap];
        
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

- (NSArray<Node *>*)getItemsById:(NSArray<NSUUID *>*)ids {
    return [self.database getItemsById:ids];
}



- (void)refreshCaches {
    [self.database rebuildFastMaps];
    
    [self refreshAutoFillSuggestions];
    
    [self restartBackgroundAudit];
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kTabsMayHaveChangedDueToModelEdit object:nil];
    });
}

- (void)refreshAutoFillSuggestions {
    [self refreshAutoFillSuggestions:NO];
}

- (void)refreshAutoFillSuggestions:(BOOL)clearFirst {
    [self rebuildAutoFillDomainNodeMap];
    [self refreshAutoFillQuickTypeDatabase:clearFirst];
}

- (void)refreshAutoFillQuickTypeDatabase {
    [self refreshAutoFillQuickTypeDatabase:NO];
}

- (void)refreshAutoFillQuickTypeDatabase:(BOOL)clearFirst {
#ifndef IS_APP_EXTENSION 
    if( self.metadata.autoFillEnabled ) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self clearFirst:clearFirst];
    }
#endif
}



- (void)reloadDatabaseFromLocalWorkingCopy:(VIEW_CONTROLLER_PTR(^)(void))onDemandViewController 
                         noProgressSpinner:(BOOL)noProgressSpinner
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
                                                         forceReadOnly:self.forcedReadOnly
                                      isNativeAutoFillAppExtensionOpen:self.isNativeAutoFillAppExtensionOpen
                                                           offlineMode:self.offlineMode
                                                    onDemandUiProvider:onDemandViewController];
    
    unlocker.noProgressSpinner = noProgressSpinner;
    
    [unlocker unlockLocalWithKey:self.database.ckfs keyFromConvenience:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess) {
            NSLog(@"reloadDatabaseFromLocalWorkingCopy... Success ");
            
            self.theDatabase = model.database;
            
            if (completion) {
                completion(YES);
            }
            
            [self refreshCaches];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotificationKey object:self.databaseUuid];
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



- (CompositeKeyFactors *)ckfs {
    return self.database.ckfs;
}

- (void)setCkfs:(CompositeKeyFactors *)ckfs {
    self.database.ckfs = ckfs;
}

- (void)replaceEntireUnderlyingDatabaseWith:(DatabaseModel*)newDatabase {
    self.theDatabase = newDatabase;
    
    [self restartBackgroundAudit];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotificationKey object:nil];
    });
}

- (void)clearAsyncUpdateState {
    [self.asyncUpdatesStack clear];
    self.lastAsyncUpdateResult = nil;
}

- (BOOL)asyncUpdateAndSync {
    return [self asyncUpdateAndSync:nil];
}

- (BOOL)asyncUpdateAndSync:(AsyncUpdateCompletion)completion {
    return [self asyncJob:kAsyncJobTypeBoth completion:completion];
}

- (BOOL)asyncUpdate {
    return [self asyncUpdate:nil];
}

- (BOOL)asyncUpdate:(AsyncUpdateCompletion)completion {
    return [self asyncJob:kAsyncJobTypeSerializeOnly completion:completion];
}

- (BOOL)asyncSync {
    return [self asyncSync:nil];
}

- (BOOL)asyncSync:(AsyncUpdateCompletion)completion {
    return [self asyncJob:kAsyncJobTypeSyncOnly completion:completion];
}

- (BOOL)asyncJob:(AsyncJobType)jobType
      completion:(AsyncUpdateCompletion _Nullable)completion {
    
    
    if ( self.isReadOnly && jobType != kAsyncJobTypeSyncOnly ) {
        NSLog(@"🔴 WARNWARN - Database is Read Only - Will not UPDATE! Last Resort. - WARNWARN");
        return NO;
    }
    
    AsyncUpdateJob* job = [[AsyncUpdateJob alloc] init];
    job.snapshot = [self.database clone];
    job.jobType = jobType;
    job.completion = completion;
    
    [self.asyncUpdatesStack push:job];
    
    dispatch_async(self.asyncUpdateEncryptionQueue, ^{
        [self dequeueOutstandingAsyncUpdateAndProcess];
    });
    
    
    
    return YES;
}

- (void)dequeueOutstandingAsyncUpdateAndProcess {
    AsyncUpdateJob* job = [self.asyncUpdatesStack popAndClear]; 
    
    if ( job ) {
        [self beginJobWithDatabaseClone:NSUUID.UUID job:job];
    }
    else {
        NSLog(@"NOP - No outstanding async updates found. All Done.");
    }
}

- (void)beginJobWithDatabaseClone:(NSUUID*)updateId job:(AsyncUpdateJob*)job {
    
    
    _isRunningAsyncUpdate = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateStarting object:self.databaseUuid];
    });
    
    dispatch_group_t mutex = dispatch_group_create();
    dispatch_group_enter(mutex);
    
    if ( job.jobType == kAsyncJobTypeBoth || job.jobType == kAsyncJobTypeSerializeOnly ) {
        [self beginAsyncUpdate:NSUUID.UUID updateMutex:mutex job:job];
    }
    else if ( job.jobType == kAsyncJobTypeSyncOnly ) {
        [self beginAsyncSync:NSUUID.UUID updateMutex:mutex job:job];
    }
    
    dispatch_group_wait(mutex, DISPATCH_TIME_FOREVER);
    
    NSLog(@"queueAsyncUpdateWithDatabaseClone EXIT - [%@]", NSThread.currentThread.name);
}

- (void)beginAsyncUpdate:(NSUUID*)updateId updateMutex:(dispatch_group_t)mutex job:(AsyncUpdateJob*)job {
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
}

- (void)onAsyncUpdateSerializeDone:(NSUUID*)updateId
                     userCancelled:(BOOL)userCancelled
                     streamingFile:(NSString*)streamingFile
                       updateMutex:(dispatch_group_t)updateMutex
                               job:(AsyncUpdateJob*)job
                             error:(NSError * _Nullable)error {
    
    
    [self refreshCaches];
    
    if (userCancelled || error) {
        
        [self onAsyncJobDone:updateId job:job success:NO userCancelled:userCancelled userInteractionRequired:NO localWasChanged:NO updateMutex:updateMutex error:error];
        return;
    }
    
    if (self.isDuressDummyMode) {
        NSData* data = [NSData dataWithContentsOfFile:streamingFile];
        [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];
        
        [self setDuressDummyData:data];
        [self onAsyncJobDone:updateId job:job success:YES userCancelled:NO userInteractionRequired:NO localWasChanged:NO updateMutex:updateMutex error:nil];
        return;
    }
    
    NSError* localUpdateError;
    BOOL success = [self.syncManagement updateLocalCopyMarkAsRequiringSync:self.metadata file:streamingFile error:&localUpdateError];
    [NSFileManager.defaultManager removeItemAtPath:streamingFile error:nil];
    
    if (!success) { 
        [self onAsyncJobDone:updateId job:job success:NO userCancelled:NO userInteractionRequired:NO localWasChanged:NO updateMutex:updateMutex error:localUpdateError];
        return;
    }
    
    
    
    if ( self.offlineMode || job.jobType == kAsyncJobTypeSerializeOnly ) {
        NSLog(@"ℹ️ Offline or Update ONLY mode - AsyncUpdateAndSync DONE");
        
        [self onAsyncJobDone:updateId job:job success:YES userCancelled:NO userInteractionRequired:NO localWasChanged:NO updateMutex:updateMutex error:nil];
        
        return;
    }
    
    [self beginAsyncSync:updateId updateMutex:updateMutex job:job];
}

- (void)beginAsyncSync:(NSUUID*)updateId
           updateMutex:(dispatch_group_t)updateMutex
                   job:(AsyncUpdateJob*)job {
    [self.syncManagement sync:self.metadata
                interactiveVC:nil
                          key:self.database.ckfs
                         join:NO
                   completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( result == kSyncAndMergeSuccess ) {
            [self onAsyncJobDone:updateId job:job success:YES userCancelled:NO userInteractionRequired:NO localWasChanged:localWasChanged updateMutex:updateMutex error:nil];
        }
        else if (result == kSyncAndMergeError) {
            [self onAsyncJobDone:updateId job:job success:NO userCancelled:NO userInteractionRequired:NO localWasChanged:NO updateMutex:updateMutex error:error];
        }
        else if ( result == kSyncAndMergeResultUserInteractionRequired ) {
            [self onAsyncJobDone:updateId job:job success:NO userCancelled:NO userInteractionRequired:YES localWasChanged:NO updateMutex:updateMutex error:error];
        }
        else {
            error = [Utils createNSError:[NSString stringWithFormat:@"Unexpected result returned from async update sync: [%@]", @(result)] errorCode:-1];
            BOOL userCancelled = result == kSyncAndMergeResultUserCancelled;
            [self onAsyncJobDone:updateId job:job success:NO userCancelled:userCancelled userInteractionRequired:NO localWasChanged:NO updateMutex:updateMutex error:error];
        }
    }];
}

- (void)onAsyncJobDone:(NSUUID*)updateId
                   job:(AsyncUpdateJob*)job
               success:(BOOL)success
         userCancelled:(BOOL)userCancelled
userInteractionRequired:(BOOL)userInteractionRequired
       localWasChanged:(BOOL)localWasChanged
           updateMutex:(dispatch_group_t)updateMutex
                 error:(NSError*)error {
    NSLog(@"onAsyncUpdateDone: updateId=%@ success=%hhd, userInteractionRequired=%hhd, localWasChanged=%hhd, error=%@", updateId, success, userInteractionRequired, localWasChanged, error);
    
    AsyncJobResult* result = [[AsyncJobResult alloc] init];
    
    result.databaseUuid = self.databaseUuid;
    result.success = success;
    result.error = error;
    result.userCancelled = userCancelled;
    result.localWasChanged = localWasChanged;
    result.userInteractionRequired = userInteractionRequired;
    
    self.lastAsyncUpdateResult = result;
    _isRunningAsyncUpdate = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{ 
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateDone object:result];
        
        if ( job.completion ) {
            job.completion(result);
        }
    });
    
    dispatch_group_leave(updateMutex);
}

- (NSString*)getUniqueStreamingFilename {
    NSString* ret;
    
    do {
#if TARGET_OS_IPHONE
        ret = [StrongboxFilesManager.sharedInstance.tmpEncryptionStreamPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
#else
        
        
        NSURL* localWorkingCacheUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCacheUrlForDatabase:self.databaseUuid];
        NSError* error;
        NSURL* url = [NSFileManager.defaultManager URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:localWorkingCacheUrl create:YES error:&error];
        
        if ( !url ) {
            NSLog(@"getUniqueStreamingFilename: ERROR = [%@]", error);
            return [StrongboxFilesManager.sharedInstance.tmpEncryptionStreamPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        }
        
        ret = [url URLByAppendingPathComponent:NSUUID.UUID.UUIDString].path;
        
#endif
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}



- (AuditState)auditState {
    return self.auditor.state;
}

- (void)restartBackgroundAudit {
    if (!self.isNativeAutoFillAppExtensionOpen && self.metadata.auditConfig.auditInBackground) {
        [self restartAudit];
    }
    else {
        NSLog(@"Audit not configured to run. Skipping.");
        [self stopAndClearAuditor]; 
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
    self.auditor = [[DatabaseAuditor alloc] initWithPro:self.applicationPreferences.isPro
                                         strengthConfig:self.applicationPreferences.passwordStrengthConfig
                                             isExcluded:^BOOL(Node * _Nonnull item) {
        return [weakSelf isExcludedFromAuditHelper:set uuid:item.uuid];
    }
                                             saveConfig:^(DatabaseAuditorConfiguration * _Nonnull config) {
        weakSelf.metadata.auditConfig = config;
    }];
#endif
}

- (void)restartAudit {
    [self stopAndClearAuditor];
    
#ifndef IS_APP_EXTENSION
    __weak Model* weakSelf = self;
    
    [self.auditor start:self.database
                 config:self.metadata.auditConfig
           nodesChanged:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( weakSelf ) {
                [NSNotificationCenter.defaultCenter postNotificationName:kAuditNodesChangedNotificationKey object:@{ @"model" : weakSelf }];
            }
        });
    }
               progress:^(double progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditProgressNotificationKey object:@(progress)];
        });
    } completion:^(BOOL userStopped) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( weakSelf ) {
                [NSNotificationCenter.defaultCenter postNotificationName:kAuditCompletedNotificationKey object:@{ @"userStopped" : @(userStopped), @"model" : weakSelf }];
            }
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

- (NSArray<NSString *> *)getQuickAuditAllIssuesVeryBriefSummaryForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditAllIssuesVeryBriefSummaryForNode:item];
    }
    
    return @[];
}

- (NSArray<NSString *> *)getQuickAuditAllIssuesSummaryForNode:(NSUUID *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditAllIssuesSummaryForNode:item];
    }
    
    return @[];
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

- (DatabaseAuditReport *)auditReport {
    if (self.auditor) {
        return [self.auditor getAuditReport];
    }
    
    return nil;
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



- (BOOL)isExcludedFromAudit:(NSUUID *)item {
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];
    
    return [self isExcludedFromAuditHelper:set uuid:item];
}

- (NSArray<Node*>*)getExcludedAuditItems {
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];
    
    return [self.database.allActiveEntries filter:^BOOL(Node * _Nonnull obj) {
        if ( !obj.fields.qualityCheck ) {
            return YES;
        }
        
        NSString* sid = [self.database getCrossSerializationFriendlyIdId:obj.uuid];
        
        return [set containsObject:sid];
    }];
}

- (BOOL)isExcludedFromAuditHelper:(NSSet<NSString*> *)set uuid:(NSUUID*)uuid {
    Node* node = [self.database getItemById:uuid];
    if ( !node.fields.qualityCheck ) { 
        return YES;
    }
    
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:uuid];
    
    return [set containsObject:sid];
}

- (void)excludeFromAudit:(Node *)node exclude:(BOOL)exclude {
    node.fields.qualityCheck = !exclude;
    
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:node.uuid];
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    
    NSMutableSet<NSString*> *mutable = [NSMutableSet setWithArray:excluded];
    
    if (exclude) {
        if ( self.originalFormat != kKeePass4 ) { 
            [mutable addObject:sid];
        }
    }
    else {
        [mutable removeObject:sid];
    }
    
    self.metadata.auditExcludedItems = mutable.allObjects;
}

- (void)oneTimeHibpCheck:(NSString *)password completion:(void (^)(BOOL, NSError * _Nonnull))completion {
    if (self.auditor) {
        [self.auditor oneTimeHibpCheck:password completion:completion];
    }
    else {
        completion (NO, [Utils createNSError:@"Auditor Unavailable!" errorCode:-2345]);
    }
}

- (void)toggleAuditExclusion:(NSUUID *)uuid {
    BOOL isExcluded = [self isExcludedFromAudit:uuid];
    Node* node = [self getItemById:uuid];
    
    if ( node ) {
        [self excludeFromAudit:node exclude:!isExcluded];
    }
    else {
        NSLog(@"🔴 WARNWARN Attempt to exclude none existent node from Audit?!");
    }
}





- (BOOL)isExcludedFromAutoFill:(NSUUID *)uuid {
    if ( self.isKeePass2Format ) {
        Node* node = [self.database getItemById:uuid];
        return node.fields.isAutoFillExcluded;
    }
    else {
        NSSet<NSString*> *set = self.metadata.autoFillExcludedItems.set;
        
        NSString* sid = [self.database getCrossSerializationFriendlyIdId:uuid];
        
        return [set containsObject:sid];
    }
}

- (BOOL)toggleAutoFillExclusion:(NSUUID *)uuid {
    BOOL isExcluded = [self isExcludedFromAutoFill:uuid];
    return [self setExcludedFromAutoFill:uuid exclude:!isExcluded];
}

- (BOOL)setExcludedFromAutoFill:(NSUUID *)uuid exclude:(BOOL)exclude {
    Node* node = [self getItemById:uuid];
    
    if ( self.isKeePass2Format ) {
        node.fields.isAutoFillExcluded = exclude;
    }
    else {
        NSString* sid = [self.database getCrossSerializationFriendlyIdId:node.uuid];
        NSArray<NSString*> *excluded = self.metadata.autoFillExcludedItems;
        
        NSMutableSet<NSString*> *mutable = [NSMutableSet setWithArray:excluded];
        
        if ( exclude ) {
            [mutable addObject:sid];
        }
        else {
            [mutable removeObject:sid];
        }
        
        self.metadata.autoFillExcludedItems = mutable.allObjects;
    }
    
    if ( self.metadata.autoFillEnabled && exclude ) {
        [self removeItemsFromAutoFillQuickType:@[node]];
    }
    
    [self refreshAutoFillSuggestions];
    
    return self.isKeePass2Format;
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
    
    return [self addItem:parentGroup item:newGroup];
}

- (Node *)addItem:(Node *)parent item:(Node *)item {
    if ( [self addChildren:@[item] destination:parent] ) {
        return item;
    }
    
    return nil;
}

- (BOOL)addChildren:(NSArray<Node *> *)items destination:(Node *)destination {
    return [self.database addChildren:items destination:destination];
}

- (BOOL)validateAddChildren:(NSArray<Node *> *)items destination:(Node *)destination {
    return [self.database validateAddChildren:items destination:destination];
}

- (NSInteger)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:(Node *)parentGroup {
    return [self.database reorderChildFrom:from to:to parentGroup:parentGroup];
}

- (NSInteger)reorderItem:(NSUUID *)nodeId idx:(NSInteger)idx {
    return [self.database reorderItem:nodeId idx:idx];
}



- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node *)destination {
    return [self moveItems:items destination:destination undoData:nil];
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node *)destination undoData:(NSArray<NodeHierarchyReconstructionData *> * _Nullable __autoreleasing *)undoData {
    BOOL ret = [self.database moveItems:items destination:destination undoData:undoData];
    
    if ( self.metadata.autoFillEnabled ) {
        [self removeItemsFromAutoFillQuickType:items];
        
        [self refreshAutoFillSuggestions];
    }
    
    return ret;
}

- (void)undoMove:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.database undoMove:undoData];
}



- (BOOL)isInRecycled:(NSUUID *)itemId {
    return [self.database isInRecycled:itemId];
}

- (BOOL)canRecycle:(NSUUID *)itemId {
    return [self.database canRecycle:itemId];
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    [self deleteItems:items undoData:nil];
}

- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData *> * _Nullable __autoreleasing *)undoData {
    [self.database deleteItems:items undoData:undoData];
    
    if ( self.metadata.autoFillEnabled ) {
        [self removeItemsFromAutoFillQuickType:items];
    }
}

- (void)unDelete:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.database unDelete:undoData];
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    return [self recycleItems:items undoData:nil];
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData *> * _Nullable __autoreleasing *)undoData {
    BOOL ret = [self.database recycleItems:items undoData:undoData];
    
    if ( ret ) {
        if ( self.metadata.autoFillEnabled ) {
            [self removeItemsFromAutoFillQuickType:items];
        }
    }
    
    return ret;
}

- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.database undoRecycle:undoData];
}

- (void)removeItemsFromAutoFillQuickType:(const NSArray<Node *> *)items {
    [AutoFillManager.sharedInstance removeItemsFromQuickType:items database:self];
}

- (void)emptyRecycleBin {
    [self.database emptyRecycleBin];
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
        [UIApplication.sharedApplication openURL:launchableUrl options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                NSLog(@"Couldn't launch this URL!");
            }
        }];
    });
#endif
#else
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for item.");
        return;
    }
    
    [[NSWorkspace sharedWorkspace] openURL:launchableUrl
                             configuration:NSWorkspaceOpenConfiguration.configuration
                         completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if ( error ) {
            NSLog(@"Launch URL done. Error = [%@]", error);
        }
    }];
#endif
}




- (NSArray<Node *> *)legacyFavourites {
    return [self getNodesFromSerializationIds:self.cachedLegacyFavourites];
}

- (NSSet<NSUUID *> *)favouriteIdsSet {
    NSArray<Node*>* filtered = [self.legacyFavourites filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];

    NSSet<NSUUID*>* legacySet = [filtered map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
    
    NSMutableSet<NSUUID*>* unionTagged = legacySet.mutableCopy;
    if ( self.formatSupportsTags ) {
        [unionTagged addObjectsFromArray:[self getItemIdsForTag:kCanonicalFavouriteTag]];
    }
    
    return unionTagged;
}

- (BOOL)isFavourite:(NSUUID *)itemId {
    return [self.favouriteIdsSet containsObject:itemId];
}

- (NSArray<Node *> *)favourites {
    return [self getItemsById:self.favouriteIdsSet.allObjects];
}

- (BOOL)toggleFavourite:(NSUUID *)itemId {
    if ( ![self isFavourite:itemId] ) {
        return [self addFavourite:itemId];
    }
    else {
        return [self removeFavourite:itemId];
    }
}

- (BOOL)addFavourite:(NSUUID*)itemId {
    if ( self.formatSupportsTags ) {
        BOOL added = [self addTag:itemId tag:kCanonicalFavouriteTag];
        return added;
    }
    else {
        [self legacyAddFavourite:itemId];
        return NO;
    }
}

- (BOOL)removeFavourite:(NSUUID*)itemId {
    BOOL needsSave = NO;
    if ( self.formatSupportsTags ) {
        BOOL removed = [self removeTag:itemId tag:kCanonicalFavouriteTag];
        needsSave = removed;
    }

    [self legacyRemoveFavourite:itemId];
    
    return needsSave;
}

- (void)legacyAddFavourite:(NSUUID*)itemId {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];
    if ( sid ) {
        NSMutableSet<NSString*>* favs = self.cachedLegacyFavourites.mutableCopy;
        
        [favs addObject:sid];
        
        [self resetLegacyFavourites:favs];
    }
    else {
        NSLog(@"🔴 legacyAddFavourite - Could not get sid");
    }
}

- (void)legacyRemoveFavourite:(NSUUID*)itemId {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];
    if ( sid ) {
        NSMutableSet<NSString*>* favs = self.cachedLegacyFavourites.mutableCopy;
        
        [favs removeObject:sid];
        
        [self resetLegacyFavourites:favs];
    }
    else {
        NSLog(@"🔴 legacyRemoveFavourite - Could not get sid");
    }
}

- (void)resetLegacyFavourites:(NSSet<NSString*>*)favs {
    
    
    __weak Model* weakSelf = self;
    NSArray<Node*>* pinned = [self.database.effectiveRootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:node.uuid];
        return [favs containsObject:sid];
    }];
    
    NSArray<NSString*>* trimmed = [pinned map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:obj.uuid];
        return sid;
    }];
    self.cachedLegacyFavourites = [NSSet setWithArray:trimmed];
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

- (NSArray<Node *> *)allItems {
    return self.database.effectiveRootGroup.allChildren;
}

-(NSArray<Node *> *)allEntries {
    return self.database.effectiveRootGroup.allChildRecords;
}

- (NSArray<Node *> *)keeAgentSSHKeyEntries {
    return self.database.keeAgentSSHKeyEntries;
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
            includeGroups:(BOOL)includeGroups {
    return [self search:searchText
                  scope:scope
            dereference:self.metadata.searchDereferencedFields
  includeKeePass1Backup:self.metadata.showKeePass1BackupGroup
      includeRecycleBin:self.metadata.showRecycleBinInSearchResults
         includeExpired:self.metadata.showExpiredInSearch
          includeGroups:includeGroups
        browseSortField:kBrowseSortFieldTitle
             descending:NO
      foldersSeparately:YES];
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
    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
        
    NSArray<Node*>* nodes = trueRoot ? self.database.allSearchableTrueRootIncludingRecycled : self.database.allSearchableIncludingRecycled;
    
    NSMutableArray* results = [nodes mutableCopy]; 
    
    NSArray<NSString*>* terms = [self.database getSearchTerms:searchText];
    
    for (NSString* word in terms) {
        [self filterForWord:results
                 searchText:word
                      scope:scope
                dereference:dereference];
    }
    
    NSTimeInterval searchTime = NSDate.timeIntervalSinceReferenceDate - startTime;

    NSTimeInterval startBrowseFilterTime = NSDate.timeIntervalSinceReferenceDate;

    NSArray<Node*>* ret = [self filterAndSortForBrowse:results
                                 includeKeePass1Backup:includeKeePass1Backup
                                     includeRecycleBin:includeRecycleBin
                                        includeExpired:includeExpired
                                         includeGroups:includeGroups
                                       browseSortField:browseSortField
                                            descending:descending
                                     foldersSeparately:foldersSeparately];

    
#ifdef DEBUG
    NSString* searchTerm = searchText;
#else
    NSString* searchTerm = @"<REDACTED>";
#endif
    
    NSLog(@"✅ SEARCH for [%@] done in [%f] seconds then Filter/Sort for return took [%f] seconds", searchTerm, searchTime, NSDate.timeIntervalSinceReferenceDate - startBrowseFilterTime);

    return ret;
}


- (NSArray<Node *> *)filterAndSortForBrowse:(NSMutableArray<Node *> *)nodes
                              includeGroups:(BOOL)includeGroups {
    return [self filterAndSortForBrowse:nodes 
                  includeKeePass1Backup:self.metadata.showKeePass1BackupGroup
                      includeRecycleBin:self.metadata.showRecycleBinInSearchResults
                         includeExpired:self.metadata.showExpiredInSearch
                          includeGroups:includeGroups
                        browseSortField:kBrowseSortFieldTitle
                             descending:NO
                      foldersSeparately:YES];
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
    DatabaseFormat format = self.database.originalFormat;
    Node* backupGroup = (!includeKeePass1Backup && format == kKeePass1) ? self.database.keePass1BackupNode : nil;
    Node* recycleBin = (!includeRecycleBin && (format == kKeePass || format == kKeePass4 )) ? self.database.recycleBinNode : nil;

    if ( !backupGroup && !recycleBin && includeExpired && includeGroups ) {
        
        return;
    }

    [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
        if ( backupGroup ) {
            if (obj == backupGroup || [backupGroup contains:obj]) {
                return NO;
            }
        }

        if ( recycleBin ) {
            if (obj == recycleBin || [recycleBin contains:obj]) {
                return NO;
            }
        }

        if ( !includeExpired ) {
            if ( obj.expired ) {
                return NO;
            }
        }
        
        if ( !includeGroups ) {
            if ( obj.isGroup ) {
                return NO;
            }
        }

        return YES;
    }];
}

- (NSArray<Node*>*)sortItemsForBrowse:(NSArray<Node*>*)items
                      browseSortField:(BrowseSortField)browseSortField
                           descending:(BOOL)descending
                    foldersSeparately:(BOOL)foldersSeparately {
    BrowseSortField field = browseSortField;
    
    if( field == kBrowseSortFieldNone && self.database.originalFormat == kPasswordSafe ) {
        field = kBrowseSortFieldTitle;
    }
    
    if ( field != kBrowseSortFieldNone ) {
        NSArray<Node*> *ret = [items sortedArrayWithOptions:NSSortStable
                                            usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [self compareNodesForSort:(Node*)obj1 node2:(Node*)obj2 field:field descending:descending foldersSeparately:foldersSeparately];
        }];
        
        

        if ( self.database.recycleBinEnabled && self.database.recycleBinNode ) {
            NSUInteger idx = [ret indexOfObject:self.database.recycleBinNode];
            
            if ( idx != NSNotFound ) {
                NSMutableArray* mut = ret.mutableCopy;
                [mut removeObjectAtIndex:idx];
                
                if ( foldersSeparately ) {
                    NSUInteger folderCount = [mut filter:^BOOL(Node * _Nonnull obj) {
                        return obj.isGroup;
                    }].count;
                    [mut insertObject:self.database.recycleBinNode atIndex:folderCount];
                }
                else {
                    [mut addObject:self.database.recycleBinNode];
                }
                
                return mut;
            }
        }
        
        return ret;
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

- (NSComparisonResult)compareGroupsForSort:(BrowseSortField)field n1:(Node *)n1 n2:(Node *)n2 {
    NSComparisonResult result = NSOrderedSame;

    if ( field == kBrowseSortFieldCreated ) {
        result = [n1.fields.created compare:n2.fields.created];
    }
    else if ( field == kBrowseSortFieldModified ) {
        result = [n1.fields.modified compare:n2.fields.modified];
    }
    else {
        return finderStringCompare(n1.title, n2.title);
    }
    
    
    
    if( result == NSOrderedSame ) {
        result = finderStringCompare(n1.title, n2.title);
    }
    
    return result;
}

- (NSComparisonResult)compareEntryOrGroupsForSort:(BrowseSortField)field n1:(Node *)n1 n2:(Node *)n2 {
    NSComparisonResult result = NSOrderedSame;

    if (field == kBrowseSortFieldTitle) {
        return finderStringCompare([self dereference:n1.title node:n1], [self dereference:n2.title node:n2]);
    }
    else if(field == kBrowseSortFieldUsername) {
        result = finderStringCompare([self dereference:n1.fields.username node:n1], [self dereference:n2.fields.username node:n2]);
    }
    else if(field == kBrowseSortFieldPassword) {
        result = finderStringCompare([self dereference:n1.fields.password node:n1], [self dereference:n2.fields.password node:n2]);
    }
    else if(field == kBrowseSortFieldUrl) {
        result = finderStringCompare([self dereference:n1.fields.url node:n1], [self dereference:n2.fields.url node:n2]);
    }
    else if(field == kBrowseSortFieldEmail) {
        result = finderStringCompare([self dereference:n1.fields.email node:n1], [self dereference:n2.fields.email node:n2]);
    }
    else if(field == kBrowseSortFieldNotes) {
        result = finderStringCompare([self dereference:n1.fields.notes node:n1], [self dereference:n2.fields.notes node:n2]);
    }
    else if(field == kBrowseSortFieldCreated) {
        result = [n1.fields.created compare:n2.fields.created];
    }
    else if(field == kBrowseSortFieldModified) {
        result = [n1.fields.modified compare:n2.fields.modified];
    }
    
    
    
    if( result == NSOrderedSame ) {
        result = finderStringCompare([self dereference:n1.title node:n1], [self dereference:n2.title node:n2]);
    }
    
    return result;
}

- (NSComparisonResult)compareNodesForSort:(Node*)node1
                                    node2:(Node*)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately {
    if ( foldersSeparately ) {
        if ( node1.isGroup && !node2.isGroup ) {
            return NSOrderedAscending;
        }
        else if ( !node1.isGroup && node2.isGroup ) {
            return NSOrderedDescending;
        }
    }
    
    Node* n1 = descending ? node2 : node1;
    Node* n2 = descending ? node1 : node2;

    
    
    if ( n1.isGroup && n2.isGroup ) {
        return [self compareGroupsForSort:field n1:n1 n2:n2];
    }
    else {
        return [self compareEntryOrGroupsForSort:field n1:n1 n2:n2];
    }
}

- (BOOL)formatSupportsCustomIcons {
    return self.originalFormat == kKeePass || self.originalFormat == kKeePass4;
}

- (BOOL)formatSupportsTags {
    return self.originalFormat == kKeePass || self.originalFormat == kKeePass4;
}



#if !TARGET_OS_IPHONE 
- (NSArray<Node *> *)getAutoFillMatchingNodesForUrl:(NSString *)urlString {
#ifndef IS_APP_EXTENSION 
    if ( self.metadata.autoFillEnabled ) {
        NSSet<NSUUID*>* matches = [BrowserAutoFillManager getMatchingNodesWithUrl:urlString 
                                                                    domainNodeMap:self.domainNodeMap];
        
        NSArray<Node*> *ret = [self getItemsById:matches.allObjects];
        
        return [ret sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [BrowserAutoFillManager compareMatchesWithNode1:obj1
                                                             node2:obj2
                                                               url:urlString
                                                       isFavourite:^BOOL(Node * _Nonnull node) {
                return [self isFavourite:node.uuid];
            }];
        }];
    }
    else {
        return @[];
    }
#else
    NSLog(@"🔴 getAutoFillMatchingNodesForUrl called in AutoFill mode?!");
    return @[];
#endif
}
#endif

- (void)rebuildAutoFillDomainNodeMap {

    _domainNodeMap = @{};
    
#if !TARGET_OS_IPHONE 
    if ( self.metadata.autoFillEnabled ) {
        _domainNodeMap = [BrowserAutoFillManager loadDomainNodeMap:self];
    }
#else
    _domainNodeMap = @{};
#endif
}


#if TARGET_OS_IPHONE

- (BrowseSortConfiguration*)getDefaultSortConfiguration {
    BrowseSortConfiguration* ret = [[BrowseSortConfiguration alloc] init];
    
    
    
    ret.field = kBrowseSortFieldTitle;
    ret.descending = NO;
    ret.foldersOnTop = YES;
    ret.showAlphaIndex = NO;
    
    return ret;
}

- (BrowseSortConfiguration*)getSortConfigurationForViewType:(BrowseViewType)viewType {
    BrowseSortConfiguration* config = self.metadata.sortConfigurations[@(viewType).stringValue];

    if ( config == nil ) { 
        config = [BrowseSortConfiguration defaults];
        config.showAlphaIndex = viewType == kBrowseViewTypeList || viewType == kBrowseViewTypeTotpList;
    }
    
    return config;
}

- (void)setSortConfigurationForViewType:(BrowseViewType)viewType
                          configuration:(BrowseSortConfiguration *)configuration {
    NSMutableDictionary* mut = self.metadata.sortConfigurations.mutableCopy;

    mut[@(viewType).stringValue] = configuration;
    
    self.metadata.sortConfigurations = mut;
}

#endif

- (BOOL)isKeePass2Format {
    return self.database.isKeePass2Format;
}




- (NSArray<Node *> *)itemsWithTag:(NSString *)tag {
    return [[self.database getItemIdsForTag:tag] map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return [self getItemById:obj];
    }];
}

- (NSArray<Node *> *)entriesWithTag:(NSString *)tag {
    return [[self itemsWithTag:tag] filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];
}

- (NSArray<NSUUID*>*)getItemIdsForTag:(NSString*)tag {
    return [self.database getItemIdsForTag:tag];
}

- (BOOL)addTag:(NSUUID*)itemId tag:(NSString*)tag {
    return [self.database addTag:itemId tag:tag];
}

- (BOOL)removeTag:(NSUUID*)itemId tag:(NSString*)tag {
    return [self.database removeTag:itemId tag:tag];
}

- (void)deleteTag:(NSString*)tag {
    return [self.database deleteTag:tag];
}

- (void)renameTag:(NSString*)from to:(NSString*)to {
    return [self.database renameTag:from to:to];
}

- (BOOL)addTagToItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag {
    return [self.database addTagToItems:ids tag:tag];
}

- (BOOL)removeTagFromItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag {
    return [self.database removeTagFromItems:ids tag:tag];
}

- (NSArray<ItemMetadataEntry*>*)getMetadataFromItem:(Node*)item {
    NSMutableArray<ItemMetadataEntry*>* metadata = [NSMutableArray array];

    [metadata addObject:[ItemMetadataEntry entryWithKey:@"ID" value:keePassStringIdFromUuid(item.uuid) copyable:YES]];

    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_created_field_title", @"Created")
                                                  value:item.fields.created ? item.fields.created.friendlyDateTimeStringPrecise : @""
                                               copyable:NO]];
    




    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_modified_field_title", @"Modified")
                                                  value:item.fields.modified ? item.fields.modified.friendlyDateTimeStringPrecise : @""
                                               copyable:NO]];
        












    NSString* path = [self.database getPathDisplayString:item.parent includeRootGroup:YES rootGroupNameInsteadOfSlash:NO includeFolderEmoji:NO joinedBy:@"/"];
    
    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"generic_fieldname_location", @"Location")
                                                  value:path
                                               copyable:NO]];

    return metadata;
}

@end
