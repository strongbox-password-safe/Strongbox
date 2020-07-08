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
#import "SharedAppAndAutoFillSettings.h"
#import "SyncManager.h"

NSString* const kAuditNodesChangedNotificationKey = @"kAuditNodesChangedNotificationKey";
NSString* const kAuditProgressNotificationKey = @"kAuditProgressNotificationKey";
NSString* const kAuditCompletedNotificationKey = @"kAuditCompletedNotificationKey";
NSString* const kCentralUpdateOtpUiNotification = @"kCentralUpdateOtpUiNotification";
NSString* const kDatabaseViewPreferencesChangedNotificationKey = @"kDatabaseViewPreferencesChangedNotificationKey";
NSString* const kProStatusChangedNotificationKey = @"proStatusChangedNotification";
NSString* const kAppStoreSaleNotificationKey = @"appStoreSaleNotification";
NSString *const kWormholeAutoFillUpdateMessageId = @"auto-fill-workhole-message-id";

@interface Model ()

@property NSSet<NSString*> *cachedPinned;
@property DatabaseAuditor* auditor;
@property BOOL isAutoFillOpen;
@property BOOL forcedReadOnly;
@property BOOL isDuressDummyMode;

@end

@implementation Model

- (instancetype)initAsDuressDummy:(BOOL)isAutoFillOpen templateMetaData:(SafeMetaData*)templateMetaData {
    SafeMetaData* meta = [[SafeMetaData alloc] initWithNickName:templateMetaData.nickName
                                                storageProvider:templateMetaData.storageProvider
                                                       fileName:templateMetaData.fileName
                                                 fileIdentifier:templateMetaData.fileIdentifier];
    meta.autoFillEnabled = NO;
    
    NSData* data = [self getDuressDummyData];
    DatabaseModelConfig* config = [DatabaseModelConfig withPasswordConfig:SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig];
    if (!data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];
        DatabaseModelConfig* config = [DatabaseModelConfig withPasswordConfig:SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig];
        DatabaseModel* model = [[DatabaseModel alloc] initNew:cpf format:kKeePass config:config];
    
        data = [model expressToData];
        [self setDuressDummyData:data];
    }

    DatabaseModel* model = [DatabaseModel expressFromData:data password:@"1234" config:config];
    
    return [self initWithSafeDatabase:model metaData:meta forcedReadOnly:NO isAutoFill:isAutoFillOpen isDuressDummyMode:YES];
}

- (instancetype)initWithSafeDatabase:(DatabaseModel *)passwordDatabase
                            metaData:(SafeMetaData *)metaData
                      forcedReadOnly:(BOOL)forcedReadOnly
                          isAutoFill:(BOOL)isAutoFill {
    return [self initWithSafeDatabase:passwordDatabase metaData:metaData forcedReadOnly:forcedReadOnly isAutoFill:isAutoFill isDuressDummyMode:NO];
}

- (instancetype)initWithSafeDatabase:(DatabaseModel *)passwordDatabase
                            metaData:(SafeMetaData *)metaData
                      forcedReadOnly:(BOOL)forcedReadOnly
                          isAutoFill:(BOOL)isAutoFill
                   isDuressDummyMode:(BOOL)isDuressDummyMode {
    if (self = [super init]) {
        _database = passwordDatabase;
        _metadata = metaData;
        _cachedPinned = [NSSet setWithArray:self.metadata.favourites];
        
        self.forcedReadOnly = forcedReadOnly;
        self.isAutoFillOpen = isAutoFill;
        self.isDuressDummyMode = isDuressDummyMode;
        
        [self createNewAuditor];

        [self restartBackgroundAudit];
        
        return self;
    }
    else {
        return nil;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData*)getDuressDummyData {
    return SharedAppAndAutoFillSettings.sharedInstance.duressDummyData; // Less than ideal place to store?
}

- (void)setDuressDummyData:(NSData*)data {
    SharedAppAndAutoFillSettings.sharedInstance.duressDummyData = data;
}

//
- (void)dealloc {
    NSLog(@"=====================================================================");
    NSLog(@"Model DEALLOC...");
    NSLog(@"=====================================================================");
}

- (void)closeAndCleanup { // Called when user is done/finised with model... // TODO: Call on Exit Mac!
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

    self.auditor = [[DatabaseAuditor alloc] initWithPro:SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial
                                             isExcluded:^BOOL(Node * _Nonnull item) {
        NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];
        return [set containsObject:sid];
    }
                                             saveConfig:^(DatabaseAuditorConfiguration * _Nonnull config) {
        // We can ignore the actual passed in config because we know it's part of the overall Database SafeMetaData;
        
        [SafesList.sharedInstance update:self.metadata];
    }];
}

- (void)restartAudit {
    [self stopAndClearAuditor];

    [self.auditor start:self.database.activeRecords
                 config:self.metadata.auditConfig
      isDereferenceable:^BOOL(NSString * _Nonnull string) {
        return [self.database isDereferenceableText:string];
    }
            nodesChanged:^{
        NSLog(@"Audit Nodes Changed Callback...");
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditNodesChangedNotificationKey object:nil];
        });
    }
               progress:^(CGFloat progress) {
//        NSLog(@"Audit Progress Callback: %f", progress);
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kAuditProgressNotificationKey object:@(progress)];
        });
    } completion:^(BOOL userStopped) {
        NSLog(@"Audit Completed - User Cancelled: %d", userStopped);
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

- (NSString *)getQuickAuditVeryBriefSummaryForNode:(Node *)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditVeryBriefSummaryForNode:item];
    }
    
    return @"";
}

- (NSString*)getQuickAuditSummaryForNode:(Node*)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditSummaryForNode:item];
    }
    
    return @"";
}

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(Node*)item {
    if (self.auditor) {
        return [self.auditor getQuickAuditFlagsForNode:item];
    }
    
    return NSSet.set;
}

- (BOOL)isFlaggedByAudit:(Node*)item {
    if (self.auditor) {
        NSSet<NSNumber*>* auditFlags = [self.auditor getQuickAuditFlagsForNode:item];
        return auditFlags.count > 0;
    }
    
    return NO;
}

- (NSSet<Node *> *)getSimilarPasswordNodeSet:(Node *)node {
    if (self.auditor) {
        return [self.auditor getSimilarPasswordNodeSet:node];
    }
    
    return NSSet.set;
}

- (NSSet<Node *> *)getDuplicatedPasswordNodeSet:(Node *)node {
    if (self.auditor) {
        return [self.auditor getDuplicatedPasswordNodeSet:node];
    }
    
    return NSSet.set;
}

- (BOOL)isExcludedFromAudit:(Node *)item {
    NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];
    
    NSArray<NSString*> *excluded = self.metadata.auditExcludedItems;
    NSSet<NSString*> *set = [NSSet setWithArray:excluded];
    
    return [set containsObject:sid];
}

- (void)setItemAuditExclusion:(Node *)item exclude:(BOOL)exclude {
    NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isReadOnly {
    return self.metadata.readOnly || self.forcedReadOnly;
}

- (void)update:(BOOL)isAutoFill handler:(void(^)(BOOL userCancelled, NSError * _Nullable error))handler {
    if(self.isReadOnly) {
        handler(NO, [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1]);
        return;
    }

    [self encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if (userCancelled || data == nil || error) {
            handler(userCancelled, error);
            return;
        }

        [self onUpdateWithEncryptedDone:data completion:handler];
    }];
}

- (void)onUpdateWithEncryptedDone:(NSData*)data completion:(void(^)(BOOL userCancelled, NSError * _Nullable error))completion {
    if (self.isDuressDummyMode) {
        [self setDuressDummyData:data];
        completion(NO, nil);
        return;
    }
    else {
        LegacySyncReadOptions* legacyOptions = [[LegacySyncReadOptions alloc] init];
        legacyOptions.isAutoFill = self.isAutoFillOpen;

        [SyncManager.sharedInstance updateLegacy:self.metadata data:data legacyOptions:legacyOptions completion:^(NSError *error) {
            if(!error) {
                if(self.metadata.autoFillEnabled) {
                    [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database databaseUuid:self.metadata.uuid];
                }

                // Re-audit - FUTURE - Make this more incremental?
                if (!self.isAutoFillOpen && self.metadata.auditConfig.auditInBackground) {
                    [self restartAudit];
                }
            }
            
            completion(NO, error);
        }];
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

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Operations

- (Node*)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title {
    BOOL keePassGroupTitleRules = self.database.format != kPasswordSafe;
    
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup keePassGroupTitleRules:keePassGroupTitleRules uuid:nil];
    if([parentGroup addChild:newGroup keePassGroupTitleRules:keePassGroupTitleRules]) {
        return newGroup;
    }

    return nil;
}

- (BOOL)canRecycle:(Node*_Nonnull)item {
    return [self.database canRecycle:item];
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    [self.database deleteItems:items];

    // Also Unpin
    
    for (Node* item in items) {
        if([self isPinned:item]) {
            [self togglePin:item];
        }
    }
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    BOOL ret = [self.database recycleItems:items];
    
    if (ret) { // Also Unpin
        for (Node* item in items) {
            if([self isPinned:item]) {
                [self togglePin:item];
            }
        }
    }
    
    return ret;
}

// Pinned or Not?

- (NSSet<NSString*>*)pinnedSet {
    return self.cachedPinned;
}

- (BOOL)isPinned:(Node*)item {
    if(self.cachedPinned.count == 0) {
        return NO;
    }
    
    NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];
    
    return [self.cachedPinned containsObject:sid];
}

- (void)togglePin:(Node*)item {
    NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];

    NSMutableSet<NSString*>* favs = self.cachedPinned.mutableCopy;
    
    if([self isPinned:item]) {
        [favs removeObject:sid];
    }
    else {
        [favs addObject:sid];
    }
    
    // Trim - by search DB and mapping back...
    
    NSArray<Node*>* pinned = [self.database.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [node getSerializationId:self.database.format != kPasswordSafe];
        return [favs containsObject:sid];
    }];
    
    NSArray<NSString*>* trimmed = [pinned map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj getSerializationId:self.database.format != kPasswordSafe];
    }];
    self.cachedPinned = [NSSet setWithArray:trimmed];

    self.metadata.favourites = trimmed;
    
    [SafesList.sharedInstance update:self.metadata];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)encrypt:(void (^)(BOOL userCancelled, NSData* data, NSError* error))completion {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_encrypting", @"Encrypting")];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self.database getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [SVProgressHUD dismiss];
                completion(userCancelled, data, error);
            });
        }];
    });
}

- (NSString *)generatePassword {
    PasswordGenerationConfig* config = SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig;
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:config];
}

//

- (NSArray<Node*>*)getNodesFromSerializationIds:(NSSet<NSString*>*)set {
    // Got to be a better way to do things than this full search... FUTURE
    
    NSArray<Node*>* ret = [self.database.rootGroup filterChildren:YES
                                                        predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [node getSerializationId:self.database.format != kPasswordSafe];
        return [set containsObject:sid];
    }];

    return [ret sortedArrayUsingComparator:finderStyleNodeComparator];
}

@end
