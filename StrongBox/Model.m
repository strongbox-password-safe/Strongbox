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
#import "MMcGPair.h"

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

#import "KeyDerivationCipher.h"
#import "Kdbx4Serialization.h"

NSString* const kAuditNodesChangedNotificationKey = @"kAuditNodesChangedNotificationKey";
NSString* const kAuditProgressNotification = @"kAuditProgressNotificationKey";
NSString* const kBeginImport2FAOtpAuthUrlNotification = @"kBeginImport2FAOtpAuthUrlNotification";
NSString* const kAuditCompletedNotification = @"kAuditCompletedNotificationKey";
NSString* const kAuditNewSwitchedOffNotificationKey = @"kAuditNewSwitchedOffNotificationKey";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";
NSString *const kModelEditedNotification = @"kNotificationModelEdited";
NSString* const kMasterDetailViewCloseNotification = @"kMasterDetailViewClose";
NSString* const kDatabaseViewPreferencesChangedNotificationKey = @"kDatabaseViewPreferencesChangedNotificationKey";

NSString* const kAppStoreSaleNotificationKey = @"appStoreSaleNotification";
NSString *const kWormholeAutoFillUpdateMessageId = @"auto-fill-workhole-message-id";

NSString* const kDatabaseReloadedNotification = @"kDatabaseReloadedNotificationKey";
NSString* const kTabsMayHaveChangedDueToModelEdit = @"kTabsMayHaveChangedDueToModelEdit-iOS";

NSString* const kAsyncUpdateDoneNotification = @"kAsyncUpdateDone";
NSString* const kAsyncUpdateStartingNotification = @"kAsyncUpdateStarting";

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
    
    slog(@"😎 Model DEALLOC...");
    
}

- (void)closeAndCleanup { 
    slog(@"Model closeAndCleanup...");
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
        
        _cachedLegacyFavourites = [NSSet setWithArray:self.metadata.legacyFavouritesStore];
        
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



- (NSInteger)fastEntryTotalCount {
    return self.database.fastEntryTotalCount;
}

- (NSInteger)fastGroupTotalCount {
    return self.database.fastGroupTotalCount;
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
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotification object:nil];
            });
        });
        return;
    }
    
    slog(@"reloadDatabaseFromLocalWorkingCopy....");
    
    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:self.metadata
                                                         forceReadOnly:self.forcedReadOnly
                                      isNativeAutoFillAppExtensionOpen:self.isNativeAutoFillAppExtensionOpen
                                                           offlineMode:self.offlineMode
                                                    onDemandUiProvider:onDemandViewController];
    
    unlocker.noProgressSpinner = noProgressSpinner;
    
    [unlocker unlockLocalWithKey:self.database.ckfs keyFromConvenience:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess) {
            slog(@"reloadDatabaseFromLocalWorkingCopy... Success ");
            
            self.theDatabase = model.database;
            
            if (completion) {
                completion(YES);
            }
            
            [self refreshCaches];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotification object:self.databaseUuid];
            });
        }
        else {
            slog(@"Unlocking local copy for database reload request failed: %@", error);
            
            
            
            
            
            
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
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabaseReloadedNotification object:nil]; 
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
        slog(@"🔴 WARNWARN - Database is Read Only - Will not UPDATE! Last Resort. - WARNWARN");
        return NO;
    }
    
    AsyncUpdateJob* job = [[AsyncUpdateJob alloc] init];
    
    if ( self.originalFormat == kKeePass4 ) {
        [self rotateHardwareKeyChallengeIfDue]; 
    }
        
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
        slog(@"NOP - No outstanding async updates found. All Done.");
    }
}

- (void)beginJobWithDatabaseClone:(NSUUID*)updateId job:(AsyncUpdateJob*)job {
    
    
    _isRunningAsyncUpdate = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateStartingNotification object:self.databaseUuid];
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
    
    slog(@"queueAsyncUpdateWithDatabaseClone EXIT - [%@]", NSThread.currentThread.name);
}

- (void)beginAsyncUpdate:(NSUUID*)updateId updateMutex:(dispatch_group_t)mutex job:(AsyncUpdateJob*)job {
    NSString* streamingFile = [self getUniqueStreamingFilename];
    NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath:streamingFile append:NO];
    [outputStream open];
    
    DatabaseModel* snapshot = job.snapshot;
    CompositeKeyFactors* originalCkfs = snapshot.ckfs;
    
    __weak Model* weakSelf = self;
    BOOL useHardwareKeyCaching = self.applicationPreferences.hardwareKeyCachingBeta && snapshot.originalFormat == kKeePass4 && snapshot.ckfs.yubiKeyCR != nil && self.metadata.hardwareKeyCRCaching;
    
    if ( useHardwareKeyCaching ) {
        CompositeKeyFactors* cachedCrCkfsWrapper = [CompositeKeyFactors password:originalCkfs.password
                                                                   keyFileDigest:originalCkfs.keyFileDigest
                                                                       yubiKeyCR:^(NSData * _Nonnull thisChallenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            NSData* response = [weakSelf.metadata getCachedChallengeResponse:thisChallenge];
            
            if ( response ) {
                slog(@"🟢 Got cached response [%@] for challenge [%@], attempting to use...", response.base64String, thisChallenge.base64String);
                completion(NO, response, nil);
            }
            else {
                slog(@"🟢 beginAsyncUpdate - Cached MISS for for challenge [%@], using physical fallback...", thisChallenge.base64String);
                originalCkfs.yubiKeyCR(thisChallenge, completion);
            }
        }];
        
        snapshot.ckfs = cachedCrCkfsWrapper;
    }
    
    [Serializator getAsData:job.snapshot
                     format:job.snapshot.originalFormat
               outputStream:outputStream
                     params:nil
                 completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
        [outputStream close];

        BOOL successful = !userCancelled && error == nil;
        
        if ( successful && useHardwareKeyCaching  ) { 
            slog(@"🐞 Successful Save - Trying to cache CR");
            
            MMcGPair<NSData *,NSData *> *cr = snapshot.ckfs.lastChallengeResponse;
            if ( cr ) {
                NSData* existing = [weakSelf.metadata getCachedChallengeResponse:cr.a]; 
                if ( !existing ) {
                    slog(@"🐞 Caching serialization CR");
                    [weakSelf.metadata addCachedChallengeResponse:cr];
                }
            }
            
            snapshot.ckfs = originalCkfs; 
        }
        
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
        slog(@"ℹ️ Offline or Update ONLY mode - AsyncUpdateAndSync DONE");
        
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
    slog(@"onAsyncUpdateDone: updateId=%@ success=%hhd, userInteractionRequired=%hhd, localWasChanged=%hhd, error=%@", updateId, success, userInteractionRequired, localWasChanged, error);
    
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
        [NSNotificationCenter.defaultCenter postNotificationName:kAsyncUpdateDoneNotification object:result];
        
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
            slog(@"getUniqueStreamingFilename: ERROR = [%@]", error);
            return [StrongboxFilesManager.sharedInstance.tmpEncryptionStreamPath stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        }
        
        ret = [url URLByAppendingPathComponent:NSUUID.UUID.UUIDString].path;
        
#endif
    } while ([NSFileManager.defaultManager fileExistsAtPath:ret]);
    
    return ret;
}



- (CGFloat)auditProgress {
    return self.isAuditEnabled && self.auditor ? self.auditor.calculatedProgress : 0.0;
}

- (BOOL)isAuditEnabled {
    return !self.isNativeAutoFillAppExtensionOpen && self.metadata.auditConfig.auditInBackground;
}

- (AuditState)auditState {
    return self.auditor.state;
}

- (void)restartBackgroundAudit {
    if (!self.isNativeAutoFillAppExtensionOpen && self.metadata.auditConfig.auditInBackground) {
        [self restartAudit];
    }
    else {
        slog(@"Audit not configured to run. Skipping.");
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
    __weak Model* weakSelf = self;
    self.auditor = [[DatabaseAuditor alloc] initWithPro:self.applicationPreferences.isPro
                                         strengthConfig:self.applicationPreferences.passwordStrengthConfig
                                             isExcluded:^BOOL(Node * _Nonnull item) {
        return [weakSelf isExcludedFromAudit:item.uuid];
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
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditProgressNotification object:@(progress)];
        });
    } completion:^(BOOL userStopped, NSTimeInterval duration) {
        
        
        self.metadata.auditConfig.lastDuration = duration;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( weakSelf ) {
                [NSNotificationCenter.defaultCenter postNotificationName:kAuditCompletedNotification object:@{ @"userStopped" : @(userStopped), @"model" : weakSelf }];
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



- (BOOL)isExcludedFromAudit:(NSUUID *)uuid {
    if ( self.originalFormat == kKeePass4 ) {
        return [self.database isExcludedFromAudit:uuid];
    }
    else {
        NSSet<NSString*> *legacyExcluded = [NSSet setWithArray:self.metadata.auditExcludedItems];
        NSString* sid = [self.database getCrossSerializationFriendlyIdId:uuid];
        return [legacyExcluded containsObject:sid];
    }
}

- (NSArray<Node *> *)excludedFromAuditItems {
    if ( self.originalFormat == kKeePass4 ) {
        return self.database.excludedFromAuditItems;
    }
    else {
        NSSet<NSString*> *legacyExcluded = [NSSet setWithArray:self.metadata.auditExcludedItems];
        
        return [self.database.allActiveEntries filter:^BOOL(Node * _Nonnull obj) {
            NSString* sid = [self.database getCrossSerializationFriendlyIdId:obj.uuid];
            return [legacyExcluded containsObject:sid];
        }];
    }
}

- (void)toggleAuditExclusion:(NSUUID *)uuid {
    BOOL isExcluded = [self isExcludedFromAudit:uuid];
    Node* node = [self getItemById:uuid];
    
    if ( node ) {
        [self excludeFromAudit:node exclude:!isExcluded];
    }
    else {
        slog(@"🔴 WARNWARN Attempt to exclude none existent node from Audit?!");
    }
}

- (void)excludeFromAudit:(Node *)node exclude:(BOOL)exclude {
    if ( self.originalFormat == kKeePass4 ) {
        [self.database excludeFromAudit:node.uuid exclude:exclude];
    }
    else {
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
    
    [self notifyEdited];
}



- (void)oneTimeHibpCheck:(NSString *)password completion:(void (^)(BOOL, NSError * _Nonnull))completion {
    if (self.auditor) {
        [self.auditor oneTimeHibpCheck:password completion:completion];
    }
    else {
        completion (NO, [Utils createNSError:@"Auditor Unavailable!" errorCode:-2345]);
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
    return [self setItemsExcludedFromAutoFill:@[uuid] exclude:!isExcluded];
}

- (BOOL)setItemsExcludedFromAutoFill:(NSArray<NSUUID *> *)uuids exclude:(BOOL)exclude {
    NSArray<Node*>* nodes = [self getItemsById:uuids];
    
    if ( self.isKeePass2Format ) {
        for ( Node* node in nodes ) {
            node.fields.isAutoFillExcluded = exclude;
        }
    }
    else {
        NSArray<NSString*> *excluded = self.metadata.autoFillExcludedItems;
        NSMutableSet<NSString*> *mutable = [NSMutableSet setWithArray:excluded];
        
        for ( Node* node in nodes ) {
            NSString* sid = [self.database getCrossSerializationFriendlyIdId:node.uuid];
            
            if ( exclude ) {
                [mutable addObject:sid];
            }
            else {
                [mutable removeObject:sid];
            }
        }
        
        self.metadata.autoFillExcludedItems = mutable.allObjects;
    }
    
    if ( self.metadata.autoFillEnabled && exclude ) {
        [self removeItemsFromAutoFillQuickType:nodes];
    }
    
    [self refreshAutoFillSuggestions];
    
    [self notifyEdited];
    
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
    BOOL ret = [self.database addChildren:items destination:destination];
    
    [self notifyEdited];
    
    return ret;
}

- (BOOL)validateAddChildren:(NSArray<Node *> *)items destination:(Node *)destination {
    return [self.database validateAddChildren:items destination:destination];
}

- (NSInteger)reorderChildFrom:(NSUInteger)from to:(NSInteger)to parentGroup:(Node *)parentGroup {
    BOOL ret = [self.database reorderChildFrom:from to:to parentGroup:parentGroup];
    
    [self notifyEdited];
    
    return ret;
}

- (NSInteger)reorderItem:(NSUUID *)nodeId idx:(NSInteger)idx {
    BOOL ret = [self.database reorderItem:nodeId idx:idx];
    
    [self notifyEdited];
    
    return ret;
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
    
    if ( ret ) {
        [self notifyEdited];
    }
    
    return ret;
}

- (void)undoMove:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.database undoMove:undoData];
    
    [self notifyEdited];
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
    
    [self notifyEdited];
}

- (void)unDelete:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.database unDelete:undoData];
    
    [self notifyEdited];
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
    
    [self notifyEdited];
    
    return ret;
}

- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.database undoRecycle:undoData];
    
    [self notifyEdited];
}

- (void)removeItemsFromAutoFillQuickType:(const NSArray<Node *> *)items {
    [AutoFillManager.sharedInstance removeItemsFromQuickType:items database:self];
}

- (void)emptyRecycleBin {
    [self.database emptyRecycleBin];
    
    [self notifyEdited];
}

- (BOOL)launchUrl:(Node *)item {
    NSURL* launchableUrl = [self.database launchableUrlForItem:item];
    
    if ( !launchableUrl ) {
        slog(@"Could not get launchable URL for item.");
        return NO;
    }
    
    [self launchLaunchableUrl:launchableUrl];
    
    return YES;
}

- (BOOL)launchUrlString:(NSString*)urlString {
    NSURL* launchableUrl = [self.database launchableUrlForUrlString:urlString];
    
    if ( !launchableUrl ) {
        slog(@"Could not get launchable URL for string.");
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
                slog(@"Couldn't launch this URL!");
            }
        }];
    });
#endif
#else
    if ( !launchableUrl ) {
        slog(@"Could not get launchable URL for item.");
        return;
    }
    
    [[NSWorkspace sharedWorkspace] openURL:launchableUrl
                             configuration:NSWorkspaceOpenConfiguration.configuration
                         completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if ( error ) {
            slog(@"Launch URL done. Error = [%@]", error);
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

- (BOOL)addFavourites:(NSArray<NSUUID *>*)items {
    if ( self.formatSupportsTags ) {
        return [self addTagToItems:items tag:kCanonicalFavouriteTag];
    }
    else {
        [self legacyAddFavourites:items];
        [self notifyEdited];
        return NO;
    }
}

- (BOOL)addFavourite:(NSUUID*)itemId {
    return [self addFavourites:@[itemId]];
}

- (BOOL)removeFavourite:(NSUUID*)itemId {
    BOOL needsSave = NO;
    if ( self.formatSupportsTags ) {
        BOOL removed = [self removeTag:itemId tag:kCanonicalFavouriteTag];
        needsSave = removed;
        
        [self legacyRemoveFavourite:itemId];
        [self notifyEdited];
    }
    else {
        [self legacyRemoveFavourite:itemId];
        [self notifyEdited];
    }
    
    return needsSave;
}

- (void)legacyAddFavourites:(NSArray<NSUUID *>*)items {
    NSArray<NSString*> *sids = [items map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return [self.database getCrossSerializationFriendlyIdId:obj];
    }];
    
    NSMutableSet<NSString*>* favs = self.cachedLegacyFavourites.mutableCopy;
    
    [favs addObjectsFromArray:sids];
    
    [self resetLegacyFavourites:favs];
}

- (void)legacyRemoveFavourite:(NSUUID*)itemId {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:itemId];
    if ( sid ) {
        NSMutableSet<NSString*>* favs = self.cachedLegacyFavourites.mutableCopy;
        
        [favs removeObject:sid];
        
        [self resetLegacyFavourites:favs];
    }
    else {
        slog(@"🔴 legacyRemoveFavourite - Could not get sid");
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
    self.metadata.legacyFavouritesStore = trimmed;
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

- (NSArray<Node *> *)allSearchableEntries {
    return self.database.allSearchableEntries;
}

- (NSArray<Node *> *)allSearchableNoneExpiredEntries {
    return self.database.allSearchableNoneExpiredEntries;
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
#ifdef DEBUG
    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
#endif
    
    NSArray<Node*>* nodes = trueRoot ? self.database.allSearchableTrueRootIncludingRecycled : self.database.allSearchableIncludingRecycled;
    
    NSMutableArray* results = [nodes mutableCopy]; 
    
    NSArray<NSString*>* terms = [self.database getSearchTerms:searchText];
    
    for (NSString* word in terms) {
        [self filterForWord:results
                 searchText:word
                      scope:scope
                dereference:dereference];
    }
    
#ifdef DEBUG
    NSTimeInterval searchTime = NSDate.timeIntervalSinceReferenceDate - startTime;
    NSTimeInterval startBrowseFilterTime = NSDate.timeIntervalSinceReferenceDate;
#endif
    
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
    slog(@"✅ SEARCH for [%@] done in [%f] seconds then Filter/Sort for return took [%f] seconds", searchTerm, searchTime, NSDate.timeIntervalSinceReferenceDate - startBrowseFilterTime);
#endif
    
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
    if (scope == kSearchScopeTitle) {
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
        return [self.database isTitleMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin] != kStringSearchMatchTypeNoMatch;
    }];
}

- (void)searchUsername:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isUsernameMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin] != kStringSearchMatchTypeNoMatch;
    }];
}

- (void)searchPassword:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isPasswordMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin] != kStringSearchMatchTypeNoMatch;
    }];
}

- (void)searchUrl:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isUrlMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin includeAssociatedDomains:self.metadata.includeAssociatedDomains] != kStringSearchMatchTypeNoMatch;
    }];
}

- (void)searchTags:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isTagsMatches:searchText node:node checkPinYin:checkPinYin] != kStringSearchMatchTypeNoMatch;
    }];
}

- (void)searchAllFields:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isAllFieldsMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin includeAssociatedDomains:self.metadata.includeAssociatedDomains] != kStringSearchMatchTypeNoMatch;
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
        
        NSArray<Node*> *ret2 = [self getItemsById:matches.allObjects];
        
        NSArray<Node*> *filtered = [ret2 filter:^BOOL(Node * _Nonnull obj) {
            return [self dereference:obj.fields.password node:obj].length > 0;
        }];
        
        return [filtered sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
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
    slog(@"🔴 getAutoFillMatchingNodesForUrl called in AutoFill mode?!");
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
        
        
        
        if ( viewType == kBrowseViewTypeList ) {
            config.field = kBrowseSortFieldModified;
            config.descending = true;
        }
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
    BOOL ret = [self.database addTag:itemId tag:tag];
    
    if ( ret ) {
        [self notifyEdited];
    }
    
    return ret;
}

- (BOOL)removeTag:(NSUUID*)itemId tag:(NSString*)tag {
    BOOL ret = [self.database removeTag:itemId tag:tag];
    
    if ( ret ) {
        [self notifyEdited];
    }
    
    return ret;
}

- (void)deleteTag:(NSString*)tag {
    [self.database deleteTag:tag];
    [self notifyEdited];
}

- (void)renameTag:(NSString*)from to:(NSString*)to {
    [self.database renameTag:from to:to];
    [self notifyEdited];
}

- (BOOL)addTagToItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag {
    BOOL ret = [self.database addTagToItems:ids tag:tag];
    [self notifyEdited];
    return ret;
}

- (BOOL)removeTagFromItems:(NSArray<NSUUID *> *)ids tag:(NSString *)tag {
    BOOL ret = [self.database removeTagFromItems:ids tag:tag];
    [self notifyEdited];
    return ret;
}

- (NSSet<NSString *> *)tagSet {
    return self.database.tagSet;
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
    
    
    
    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"group_properties_searchable", @"Searchable")
                                                  value:localizedYesOrNoFromBool(item.isSearchable)
                                               copyable:NO]];
    
    
    
    BOOL autofillable = item.isSearchable && ![self isExcludedFromAutoFill:item.uuid] && !item.expired;
    
    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"generic_autofill_suggestable", @"Suggestable in AutoFill")
                                                  value:localizedYesOrNoFromBool(autofillable)
                                               copyable:NO]];
    
    
    
    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"browse_vc_section_title_expired", @"Expired")
                                                  value:localizedYesOrNoFromBool(item.expired)
                                               copyable:NO]];
    
    return metadata;
}



- (NSArray<Node*>*)searchAutoBestMatch:(NSString *)searchText scope:(SearchScope)scope {
#ifdef DEBUG
    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
#endif
    
    BOOL dereference = self.metadata.searchDereferencedFields;
    BOOL checkPinYin = self.applicationPreferences.checkPinYin;
    BOOL includeAssociatedDomains = self.metadata.includeAssociatedDomains;
    
    NSArray<NSString*>* terms = [self.database getSearchTerms:searchText];
    
    NSMutableDictionary<NSUUID*, NSNumber*> *results = NSMutableDictionary.dictionary;
    NSArray<Node*>* nodes = self.database.allSearchableEntries;
    
    for (NSString* word in terms) {
        for ( Node* node in nodes ) {
            DatabaseSearchMatchField matchField;
            StringSearchMatchType matchType = [self getWordMatchType:word
                                                               scope:scope
                                                                node:node
                                                          matchField:&matchField
                                                         dereference:dereference
                                                         checkPinYin:checkPinYin
                                            includeAssociatedDomains:includeAssociatedDomains];
            
            
            if ( matchType != kStringSearchMatchTypeNoMatch ) {
                NSNumber* matchWeight = @(getMatchWeight(matchType, matchField));
                NSNumber* existingWeight = results[node.uuid];
                
                if ( existingWeight ) {
                    results[node.uuid] = @(matchWeight.doubleValue + existingWeight.doubleValue); 
                }
                else {
                    results[node.uuid] = matchWeight;
                }
            }
            else {
                [results removeObjectForKey:node.uuid];
            }
        }
        
        nodes = [self getItemsById:results.allKeys]; 
    }
    
#ifdef DEBUG
    NSTimeInterval searchTime = NSDate.timeIntervalSinceReferenceDate - startTime;
    NSTimeInterval startBrowseFilterTime = NSDate.timeIntervalSinceReferenceDate;
#endif
    
    NSArray<Node*>* all = [self.database getItemsById:results.allKeys];
    
    NSArray<Node*>* sorted = [all sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        Node* node1 = ((Node*)obj1);
        Node* node2 = ((Node*)obj2);
        NSNumber* weight1 = results[node1.uuid];
        NSNumber* weight2 = results[node2.uuid];
        
        NSComparisonResult result = [weight2 compare:weight1];
        if ( result != NSOrderedSame ) {
            return result;
        }
        
        result = finderStringCompare(node1.title, node2.title);
        if ( result != NSOrderedSame ) {
            return result;
        }

        if ( [self isFavourite:node1.uuid] ) {
            return NSOrderedAscending;
        }
        else if ( [self isFavourite:node2.uuid] ) {
            return NSOrderedDescending;
        }

        return NSOrderedSame;
    }];
    
    
    
    NSMutableArray<Node*>* mutable = sorted.mutableCopy;
    [self filterExcluded:mutable includeKeePass1Backup:NO includeRecycleBin:NO includeExpired:NO includeGroups:NO];
    
#ifdef DEBUG





    
    NSString* searchTerm = searchText;
    slog(@"✅ SEARCH for [%@] done (%ld results) in [%f] seconds then Filter/Sort for return took [%f] seconds", searchTerm, mutable.count, searchTime, NSDate.timeIntervalSinceReferenceDate - startBrowseFilterTime);
#endif
    
    return mutable;
}

- (StringSearchMatchType)getWordMatchType:(NSString*)word
                                    scope:(SearchScope)scope
                                     node:(Node*)node
                               matchField:(DatabaseSearchMatchField *)matchField
                              dereference:(BOOL)dereference
                              checkPinYin:(BOOL)checkPinYin
                 includeAssociatedDomains:(BOOL)includeAssociatedDomains {
    DatabaseSearchMatchField field;
    StringSearchMatchType matchType;
    
    if (scope == kSearchScopeTitle) {
        field = kDatabaseSearchMatchFieldTitle;
        matchType = [self.database isTitleMatches:word node:node dereference:dereference checkPinYin:checkPinYin];
    }
    else if (scope == kSearchScopeUsername) {
        field = kDatabaseSearchMatchFieldTitle;
        matchType = [self.database isUsernameMatches:word node:node dereference:dereference checkPinYin:checkPinYin];
    }
    else if (scope == kSearchScopePassword) {
        field = kDatabaseSearchMatchFieldTitle;
        matchType = [self.database isPasswordMatches:word node:node dereference:dereference checkPinYin:checkPinYin];
    }
    else if (scope == kSearchScopeUrl) {
        field = kDatabaseSearchMatchFieldTitle;
        matchType = [self.database isUrlMatches:word node:node dereference:dereference checkPinYin:checkPinYin includeAssociatedDomains:includeAssociatedDomains];
    }
    else if (scope == kSearchScopeTags) {
        field = kDatabaseSearchMatchFieldTitle;
        matchType = [self.database isTagsMatches:word node:node checkPinYin:checkPinYin];
    }
    else {
        matchType = [self.database isAllFieldsMatches:word node:node dereference:dereference checkPinYin:checkPinYin includeAssociatedDomains:includeAssociatedDomains matchField:&field];
    }
    
    if ( matchField ) {
        *matchField = field;
    }
    
    return matchType;
}

double getMatchWeight ( StringSearchMatchType type, DatabaseSearchMatchField field ) {
    return getMatchTypeWeight(type) * getFieldWeight(field);
}

double getMatchTypeWeight(StringSearchMatchType type) {
    switch ( type ) {
        case kStringSearchMatchTypeExact:
            return 3.0;
        case kStringSearchMatchTypeStartsWith:
            return 2.0;
        case kStringSearchMatchTypeContains:
            return 1.0;
        case kStringSearchMatchTypeNoMatch:
            return CGFLOAT_MIN;
    }
    
    slog(@"🔴 New Search Field? Weight not set!");
    
    return CGFLOAT_MIN;

}

double getFieldWeight ( DatabaseSearchMatchField field ) {
    switch ( field ) {
    case kDatabaseSearchMatchFieldTitle:
        return 5.0;
    case kDatabaseSearchMatchFieldUsername:
        return 4.0;
    case kDatabaseSearchMatchFieldEmail:
        return 3.0;
    case kDatabaseSearchMatchFieldUrl:
        return 3.0;
    case kDatabaseSearchMatchFieldTag:
        return 3.0;
    case kDatabaseSearchMatchFieldCustomField:
        return 2.0;
    case kDatabaseSearchMatchFieldNotes:
        return 2.0;
    case kDatabaseSearchMatchFieldPassword:
        return 2.0;
    case kDatabaseSearchMatchFieldAttachment:
        return 1.0;
    case kDatabaseSearchMatchFieldPath:
        return 1.0;
    }
    
    slog(@"🔴 New Search Field? Weight not set!");
    
    return CGFLOAT_MIN;
}

- (void)notifyEdited {
    __weak Model* weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelEditedNotification object:weakSelf];
    });
}



- (NSString*)getAllFieldsKeyValuesString:(NSUUID*)uuid {
    Node* item = [self getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return @"";
    }

    NSMutableArray<NSString*>* fields = NSMutableArray.array;
    
    if ( item.title.length ) [fields addObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"generic_fieldname_title", @""), [self dereference:item.title node:item]]];
    if ( item.fields.username.length ) [fields addObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"generic_fieldname_username", @""), [self dereference:item.fields.username node:item]]];
    if ( item.fields.password.length ) [fields addObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"generic_fieldname_password", @""), [self dereference:item.fields.password node:item]]];
    if ( item.fields.email.length ) [fields addObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"generic_fieldname_email", @""), [self dereference:item.fields.email node:item]]];
    if ( item.fields.url.length ) [fields addObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"generic_fieldname_url", @""), [self dereference:item.fields.url node:item]]];
    if ( item.fields.notes.length ) [fields addObject:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"generic_fieldname_notes", @""), [self dereference:item.fields.notes node:item]]];
    
    
    
    NSArray* allKeys = self.metadata.customSortOrderForFields ? item.fields.customFieldsFiltered.allKeys : [item.fields.customFieldsFiltered.allKeys sortedArrayUsingComparator:finderStringComparator];
    
    for(NSString* key in allKeys) {
        StringValue* sv = item.fields.customFields[key];
        NSString *val = [self dereference:sv.value node:item];
        
        if ( val.length != 0 ) {
            [fields addObject:[NSString stringWithFormat:@"%@: %@", key, val]];
        }
    }
    
    return [fields componentsJoinedByString:@"\n"];
}

- (NSInteger)auditEntryCount {
    if ( !self.auditReport ) {
        return 0;
    }
    else {
        return self.auditReport.allEntries.count;
    }
}

- (NSArray<Node*>*)auditEntries {
    if ( !self.auditReport ) {
        return 0;
    }
    else {
        return [self getItemsById:self.auditReport.allEntries.allObjects];
    }
}

- (NSArray<Node *> *)totpEntries {
    return self.database.totpEntries;
}

- (NSArray<Node*>*)expiredEntries {
    return self.database.expiredEntries;
}

- (NSArray<Node*>*)nearlyExpired {
    return self.database.nearlyExpiredEntries;
}



- (BOOL)setItemTitle:(NSUUID *)uuid title:(NSString *)title {
    Node* node = [self getItemById:uuid];
    
    if ( node ) {
        if ( ![title isEqualToString:node.title] ) {
            BOOL ret = [self.database setItemTitle:node title:title];
            
            [self notifyEdited];
            
            return ret;
        }
        else {
            return YES;
        }
    }
    else {
        return NO;
    }
}



- (void)rotateHardwareKeyChallengeIfDue {
    NSDate* lastRefresh = self.metadata.lastChallengeRefreshAt;
    NSInteger interval = self.metadata.challengeRefreshIntervalSecs;
        
    BOOL rotateHardwareKeyChallenge = YES;
    if ( lastRefresh != nil && interval > 0 ) {
        rotateHardwareKeyChallenge = [lastRefresh isMoreThanXSecondsAgo:interval];
        slog(@"🐞 Saving: rotateHardwareKeyChallenge = %hhd. r=%@, i=%d", rotateHardwareKeyChallenge, lastRefresh.friendlyDateTimeStringBothPrecise, interval);
    }
    
#ifdef IS_APP_EXTENSION
    BOOL suppressForAF = self.metadata.doNotRefreshChallengeInAF;
    rotateHardwareKeyChallenge = !suppressForAF;
#endif

    if ( rotateHardwareKeyChallenge ) {
        slog(@"✅ Rotating KDBX4 Hardware Key Challenge");
        
        NSError* error;
        id<KeyDerivationCipher> kdf = getKeyDerivationCipher(self.database.meta.kdfParameters, &error);
        if(!kdf) {
            return; 
        }

        
        
        [kdf rotateHardwareKeyChallenge];
        self.database.meta.kdfParameters = kdf.kdfParameters;
        self.metadata.lastChallengeRefreshAt = NSDate.date;
    }
    else {
        slog(@"✅ Not Rotating KDBX4 Hardware Key Challenge as directed.");
    }
}



- (Node*)duplicateWithOptions:(NSUUID*)itemId
                        title:(NSString*)title
            preserveTimestamp:(BOOL)preserveTimestamp
            referencePassword:(BOOL)referencePassword
            referenceUsername:(BOOL)referenceUsername {
    Node* item = [self getItemById:itemId];
    if (!item) {
        return nil;
    }
    
    Node* dupe = [item duplicate:title preserveTimestamps:preserveTimestamp];
    
    if ( self.database.originalFormat != kPasswordSafe ) {
        if ( referencePassword ) {
            NSString *fieldReference = [NSString stringWithFormat:@"{REF:P@I:%@}", keePassStringIdFromUuid(item.uuid)];
            dupe.fields.password = fieldReference;
        }
        
        if ( referenceUsername ) {
            NSString *fieldReference = [NSString stringWithFormat:@"{REF:U@I:%@}", keePassStringIdFromUuid(item.uuid)];
            dupe.fields.username = fieldReference;
        }
    }
    
    [item touch:NO touchParents:YES];

    return dupe;
}

@end
