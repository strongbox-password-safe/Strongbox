//
//  SafeViewModel.m
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Model.h"
#import "Utils.h"
#import "SVProgressHUD.h"
#import "AutoFillManager.h"
#import "PasswordMaker.h"
#import "BackupsManager.h"
#import "NSArray+Extensions.h"
#import "DatabaseAuditor.h"
#import "AppPreferences.h"
#import "SyncManager.h"
#import "Serializator.h"
#import "SampleItemsGenerator.h"
#import "DatabaseUnlocker.h"

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

@interface Model ()

@property NSSet<NSString*> *cachedPinned;
@property DatabaseAuditor* auditor;
@property BOOL isAutoFillOpen;
@property BOOL forcedReadOnly;
@property BOOL isDuressDummyMode;
@property DatabaseModel* theDatabase;
@property BOOL offlineMode; 

@end

@implementation Model

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen
                 templateMetaData:(SafeMetaData*)templateMetaData {
    SafeMetaData* meta = [[SafeMetaData alloc] initWithNickName:templateMetaData.nickName
                                                storageProvider:templateMetaData.storageProvider
                                                       fileName:templateMetaData.fileName
                                                 fileIdentifier:templateMetaData.fileIdentifier];
    meta.autoFillEnabled = NO;
    meta.hasBeenPromptedForConvenience = YES; 
    meta.hasBeenPromptedForQuickLaunch = YES;
    
    NSData* data = [self getDuressDummyData];
    if (!data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];

        DatabaseModel* model = [[DatabaseModel alloc] initWithFormat:kKeePass compositeKeyFactors:cpf];
        
        [SampleItemsGenerator addSampleGroupAndRecordToRoot:model passwordConfig:AppPreferences.sharedInstance.passwordGenerationConfig];
        
        data = [Serializator expressToData:model format:model.originalFormat];
        
        [self setDuressDummyData:data];
    }

    DatabaseModel* model = [Serializator expressFromData:data password:@"1234"];
    
    return [self initWithDatabase:model metaData:meta forcedReadOnly:NO isAutoFill:isAutoFillOpen offlineMode:NO isDuressDummyMode:YES];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(SafeMetaData *)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill {
    return [self initWithDatabase:passwordDatabase metaData:metaData forcedReadOnly:forcedReadOnly isAutoFill:isAutoFill offlineMode:NO];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase metaData:(SafeMetaData *)metaData forcedReadOnly:(BOOL)forcedReadOnly isAutoFill:(BOOL)isAutoFill offlineMode:(BOOL)offlineMode {
    return [self initWithDatabase:passwordDatabase metaData:metaData forcedReadOnly:forcedReadOnly isAutoFill:isAutoFill offlineMode:offlineMode isDuressDummyMode:NO];
}

- (instancetype)initWithDatabase:(DatabaseModel *)passwordDatabase
                        metaData:(SafeMetaData *)metaData
                  forcedReadOnly:(BOOL)forcedReadOnly
                      isAutoFill:(BOOL)isAutoFill
                     offlineMode:(BOOL)offlineMode
               isDuressDummyMode:(BOOL)isDuressDummyMode {
    if (self = [super init]) {
        if ( !passwordDatabase ) {
            return nil;
        }
        
        self.theDatabase = passwordDatabase;
        _metadata = metaData;
        _cachedPinned = [NSSet setWithArray:self.metadata.favourites];
        
        self.forcedReadOnly = forcedReadOnly;
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



- (DatabaseModel *)database {
    return self.theDatabase;
}

- (void)reloadDatabaseFromLocalWorkingCopy:(UIViewController*)viewController 
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

    NSLog(@"XXXXX - reloadDatabaseFromLocalWorkingCopy....");

    
    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:self.metadata viewController:viewController forceReadOnly:self.forcedReadOnly isAutoFillOpen:self.isAutoFillOpen offlineMode:self.offlineMode];
    [unlocker unlockLocalWithKey:self.database.ckfs keyFromConvenience:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess) {
            NSLog(@"XXXXX - reloadDatabaseFromLocalWorkingCopy... Success ");

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



- (NSData*)getDuressDummyData {
    return AppPreferences.sharedInstance.duressDummyData; 
}

- (void)setDuressDummyData:(NSData*)data {
    AppPreferences.sharedInstance.duressDummyData = data;
}


- (void)dealloc {
    NSLog(@"=====================================================================");
    NSLog(@"Model DEALLOC...");
    NSLog(@"=====================================================================");
}

- (void)closeAndCleanup { 
    NSLog(@"Model closeAndCleanup...");
    if (self.auditor) {
        [self.auditor stop];
        self.auditor = nil;
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
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];

    __weak Model* weakSelf = self;
    self.auditor = [[DatabaseAuditor alloc] initWithPro:AppPreferences.sharedInstance.isProOrFreeTrial
                                             isExcluded:^BOOL(Node * _Nonnull item) {
        NSString* sid = [weakSelf.database getCrossSerializationFriendlyIdId:item.uuid];
        return [weakSelf isExcludedFromAuditHelper:set sid:sid];
    }
                                             saveConfig:^(DatabaseAuditorConfiguration * _Nonnull config) {
        
        [SafesList.sharedInstance update:weakSelf.metadata];
    }];
}

- (BOOL)isExcludedFromAudit:(NSUUID *)item {
    NSString* sid = [self.database getCrossSerializationFriendlyIdId:item];

    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];
    
    return [self isExcludedFromAuditHelper:set sid:sid];
}

- (BOOL)isExcludedFromAuditHelper:(NSSet<NSString*> *)set sid:(NSString*)sid {
    
    
    return [set containsObject:sid];
}

- (void)restartAudit {
    [self stopAndClearAuditor];

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
    
    [SafesList.sharedInstance update:self.metadata];
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

- (void)update:(UIViewController*)viewController handler:(void(^)(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error))handler {
    if(self.isReadOnly) {
        handler(NO, NO, [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1]);
        return;
    }

    [self encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
        if (userCancelled || data == nil || error) {
            handler(userCancelled, NO, error);
            return;
        }

        [self onEncryptionDone:viewController data:data completion:handler];
    }];
}

- (void)onEncryptionDone:(UIViewController*)viewController data:(NSData*)data completion:(void(^)(BOOL userCancelled, BOOL localWasChanged, const NSError * _Nullable error))completion {
    if (self.isDuressDummyMode) {
        [self setDuressDummyData:data];
        completion(NO, NO, nil);
        return;
    }
    else {
        
        
        NSError* error;
        BOOL success = [SyncManager.sharedInstance updateLocalCopyMarkAsRequiringSync:self.metadata data:data error:&error];

        if (!success) {
            completion(NO, NO, error);
            return;
        }

        if ( self.offlineMode ) { 
            completion(NO, NO, nil);
        }
        else {
            CompositeKeyFactors* key = self.database.ckfs;
            
            [SyncManager.sharedInstance sync:self.metadata interactiveVC:viewController key:key join:NO completion:^(SyncAndMergeResult result, BOOL localWasChanged, const NSError * _Nullable error) {
                if (result == kSyncAndMergeSuccess || result == kSyncAndMergeUserPostponedSync) {
                    if(self.metadata.autoFillEnabled && self.metadata.quickTypeEnabled) {
                        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database databaseUuid:self.metadata.uuid displayFormat:self.metadata.quickTypeDisplayFormat];
                    }

                    
                    if (self.metadata.auditConfig.auditInBackground) {
                        [self restartAudit];
                    }

                    completion(NO, localWasChanged, nil);
                    
                    if (localWasChanged) {
                        [self reloadDatabaseFromLocalWorkingCopy:viewController completion:nil];
                    }
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
}

- (void)disableAndClearAutoFill {
    self.metadata.autoFillEnabled = NO;
    [[SafesList sharedInstance] update:self.metadata];
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
}

- (void)enableAutoFill {
    _metadata.autoFillEnabled = YES;
    [[SafesList sharedInstance] update:self.metadata];
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

- (void)launchUrl:(Node *)item {
    NSURL* launchableUrl = [self.database launchableUrlForItem:item];
        
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for item.");
        return;
    }
    
    [self launchLaunchableUrl:launchableUrl];
}

- (void)launchUrlString:(NSString*)urlString {
    NSURL* launchableUrl = [self.database launchableUrlForUrlString:urlString];
        
    if ( !launchableUrl ) {
        NSLog(@"Could not get launchable URL for string.");
        return;
    }
    
    [self launchLaunchableUrl:launchableUrl];
}
- (void)launchLaunchableUrl:(NSURL*)launchableUrl {
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
    
    [SafesList.sharedInstance update:self.metadata];
}



- (void)encrypt:(void (^)(BOOL userCancelled, NSData* data, NSString*_Nullable debugXml, NSError* error))completion {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_encrypting", @"Encrypting")];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [Serializator getAsData:self.database format:self.database.originalFormat completion:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [SVProgressHUD dismiss];
                completion(userCancelled, data, debugXml, error);
            });
        }];
    });
}

- (NSString *)generatePassword {
    PasswordGenerationConfig* config = AppPreferences.sharedInstance.passwordGenerationConfig;
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

@end
