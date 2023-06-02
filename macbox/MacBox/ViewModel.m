    
//
//  ViewModel.m
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewModel.h"
#import "Model.h"
#import "PasswordMaker.h"
#import "Settings.h"
#import "OTPToken+Serialization.h"
#import "FavIconManager.h"
#import "NSArray+Extensions.h"
#import "NSString+Extensions.h"
#import "AutoFillManager.h"
#import "Serializator.h"
#import "Utils.h"
#import "Document.h"

#import "Strongbox-Swift.h"

NSString* const kModelUpdateNotificationCustomFieldsChanged = @"kModelUpdateNotificationCustomFieldsChanged";
NSString* const kModelUpdateNotificationPasswordChanged = @"kModelUpdateNotificationPasswordChanged";
NSString* const kModelUpdateNotificationTitleChanged = @"kModelUpdateNotificationTitleChanged";
NSString* const kModelUpdateNotificationUsernameChanged = @"kModelUpdateNotificationUsernameChanged";
NSString* const kModelUpdateNotificationEmailChanged = @"kModelUpdateNotificationEmailChanged";
NSString* const kModelUpdateNotificationUrlChanged = @"kModelUpdateNotificationUrlChanged";
NSString* const kModelUpdateNotificationNotesChanged = @"kModelUpdateNotificationNotesChanged";
NSString* const kModelUpdateNotificationExpiryChanged = @"kModelUpdateNotificationExpiryChanged";
NSString* const kModelUpdateNotificationIconChanged = @"kModelUpdateNotificationIconChanged";
NSString* const kModelUpdateNotificationAttachmentsChanged = @"kModelUpdateNotificationAttachmentsChanged";
NSString* const kModelUpdateNotificationTotpChanged = @"kModelUpdateNotificationTotpChanged";
NSString* const kModelUpdateNotificationItemsDeleted = @"kModelUpdateNotificationItemsDeleted";
NSString* const kModelUpdateNotificationItemsUnDeleted = @"kModelUpdateNotificationItemsUnDeleted";
NSString* const kModelUpdateNotificationItemsMoved = @"kModelUpdateNotificationItemsMoved";
NSString* const kModelUpdateNotificationTagsChanged = @"kModelUpdateNotificationTagsChanged";
NSString* const kModelUpdateNotificationSelectedItemChanged = @"kModelUpdateNotificationSelectedItemChanged";
NSString* const kModelUpdateNotificationItemsAdded = @"kModelUpdateNotificationItemsAdded";
NSString* const kModelUpdateNotificationItemEdited = @"kModelUpdateNotificationItemEdited";

NSString* const kModelUpdateNotificationHistoryItemDeleted = @"kModelUpdateNotificationHistoryItemDeleted";
NSString* const kModelUpdateNotificationHistoryItemRestored = @"kModelUpdateNotificationHistoryItemRestored";

NSString* const kModelUpdateNotificationItemReOrdered = @"kModelUpdateNotificationItemReOrdered";

NSString* const kModelUpdateNotificationDatabasePreferenceChanged = @"kModelUpdateNotificationDatabasePreferenceChanged";
NSString* const kModelUpdateNotificationDatabaseUpdateStatusChanged = @"kModelUpdateNotificationDatabaseUpdateStatusChanged";

NSString* const kModelUpdateNotificationNextGenNavigationChanged = @"kModelUpdateNotificationNextGenNavigationChanged";
NSString* const kModelUpdateNotificationNextGenSelectedItemsChanged = @"kModelUpdateNotificationNextGenSelectedItemsChanged";
NSString* const kModelUpdateNotificationNextGenSearchContextChanged = @"kModelUpdateNotificationNextGenSearchContextChanged";

NSString* const kNotificationUserInfoKeyIsBatchIconUpdate = @"kNotificationUserInfoKeyIsBatchIconUpdate";
NSString* const kNotificationUserInfoKeyNode = @"node";
NSString* const kNotificationUserInfoKeyBoolParam = @"boolean";

@interface ViewModel ()

@property (nullable) Model* innerModel;
@property (nullable) NSUUID* internalSelectedItem; 

@end

@implementation ViewModel

- (void)dealloc {
    NSLog(@"=====================================================================");
    NSLog(@"😎 ViewModel DEALLOC...");
    NSLog(@"=====================================================================");
}

- (instancetype)initLocked:(Document*)document
              databaseUuid:(NSString*)databaseUuid {
    if (self = [super init]) {
        _document = document;
        _databaseUuid = databaseUuid;
        
        self.innerModel = nil;
    }
    
    return self;
}

- (instancetype)initUnlocked:(Document *)document
                databaseUuid:(NSString*)databaseUuid
                       model:(Model *)model {
    if ( self = [self initLocked:document databaseUuid:databaseUuid] ) {
        self.innerModel = model;
        
        [self cacheKeeAgentPublicKeysOffline]; 
    }
    
    return self;
}

- (BOOL)locked {
    return self.innerModel == nil;
}




- (MacDatabasePreferences *)databaseMetadata {
    return [MacDatabasePreferences fromUuid:self.databaseUuid];
}



- (BOOL)isInOfflineMode {
    return self.innerModel ? self.innerModel.isInOfflineMode : (self.alwaysOpenOffline || self.databaseMetadata.userRequestOfflineOpenEphemeralFlagForDocument);
}

- (BOOL)isEffectivelyReadOnly {
    return self.innerModel ? self.innerModel.isReadOnly :  self.readOnly;
}

- (Model *)commonModel {
    
    return self.innerModel;
}

- (DatabaseModel *)database {
    if ( self.locked ) {
        NSLog(@"🔴 database called but ViewModel is locked!");
        return nil;
    }
    
    
    return self.innerModel.database;
}

- (Node *)getItemById:(NSUUID *)uuid {
    if ( !self.locked ) {
        return [self.innerModel getItemById:uuid];
    }
    else {
        NSLog(@"🔴 getItemById - Model Locked cannot get item.");
        return nil;
    }
}

- (DatabaseFormat)format {
    return self.database.originalFormat;
}

- (UnifiedDatabaseMetadata*)metadata {
    return self.database.meta;
}

- (BOOL)isKeePass2Format {
    return self.innerModel.isKeePass2Format;
}

- (NSSet<NodeIcon*>*)customIcons {
    return self.database.iconPool.allValues.set;
}

- (NSString *)getGroupPathDisplayString:(Node *)node {
    return [self getGroupPathDisplayString:node rootGroupNameInsteadOfSlash:NO];
}

- (NSString *)getGroupPathDisplayString:(Node *)node rootGroupNameInsteadOfSlash:(BOOL)rootGroupNameInsteadOfSlash {
    return [self.database getPathDisplayString:node includeRootGroup:YES rootGroupNameInsteadOfSlash:rootGroupNameInsteadOfSlash includeFolderEmoji:NO joinedBy:@"/"];
}

- (NSString *)getParentGroupPathDisplayString:(Node *)node {
    return [self.database getSearchParentGroupPathDisplayString:node prependSlash:NO];
}



- (NSArray<Node *> *)expiredEntries {
    if ( !self.locked ) {
        return self.database.expiredEntries;
    }
    else {
        NSLog(@"🔴 expiredEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)nearlyExpiredEntries {
    if ( !self.locked ) {
        return self.database.nearlyExpiredEntries;
    }
    else {
        NSLog(@"🔴 nearlyExpiredEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)totpEntries {
    if ( !self.locked ) {
        return self.database.totpEntries;
    }
    else {
        NSLog(@"🔴 totpEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)attachmentEntries {
    if ( !self.locked ) {
        return self.database.attachmentEntries;
    }
    else {
        NSLog(@"🔴 attachmentEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)keeAgentSshKeyEntries {
    if ( !self.locked ) {
        return self.database.keeAgentSSHKeyEntries;
    }
    else {
        NSLog(@"🔴 keeAgentSSHKeyEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allSearchable {
    if ( !self.locked ) {
        return self.database.allSearchable;
    }
    else {
        NSLog(@"🔴 allSearchable - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allSearchableTrueRoot {
    if ( !self.locked ) {
        return self.database.allSearchableTrueRoot;
    }
    else {
        NSLog(@"🔴 allSearchableTrueRoot - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allSearchableNoneExpiredEntries {
    if ( !self.locked ) {
        return self.database.allSearchableNoneExpiredEntries;
    }
    else {
        NSLog(@"🔴 allSearchableNoneExpiredEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allSearchableEntries{
    if ( !self.locked ) {
        return self.database.allSearchableEntries;
    }
    else {
        NSLog(@"🔴 allSearchableEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allActiveEntries {
    if ( !self.locked ) {
        return self.database.allActiveEntries;
    }
    else {
        NSLog(@"🔴 allActiveEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allActiveGroups {
    if ( !self.locked ) {
        return self.database.allActiveGroups;
    }
    else {
        NSLog(@"🔴 expiredEntries - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allSearchableGroups {
    if ( !self.locked ) {
        return self.database.allSearchableGroups;
    }
    else {
        NSLog(@"🔴 allSearchableGroups - Model Locked cannot get item.");
        return @[];
    }
}

- (NSArray<Node *> *)allActive {
    if ( !self.locked ) {
        return self.database.allActive;
    }
    else {
        NSLog(@"🔴 allActive - Model Locked cannot get item.");
        return @[];
    }
}

-(Node*)rootGroup {
    return self.database.effectiveRootGroup;
}

- (BOOL)masterCredentialsSet {
    if(!self.locked) {
        return !(self.database.ckfs.password == nil &&
                 self.database.ckfs.keyFileDigest == nil &&
                 self.database.ckfs.yubiKeyCR == nil);
    }
    
    return NO;
}

- (void)update:(NSViewController *)viewController handler:(void (^)(BOOL, BOOL, NSError * _Nullable))handler {
    if (self.locked) {
        NSLog(@"🔴 Attempt to get update while locked?");
        return;
    }
    
    [self rebuildMapsAndCaches];
    
    [self.innerModel update:viewController handler:handler];
}



- (NSURL*)fileUrl {
    return [self.document fileURL];
}



- (void)restartBackgroundAudit {
    if ( !self.locked ) {
        return [self.innerModel restartBackgroundAudit];
    }
    else {
        NSLog(@"🔴 restartBackgroundAudit - Model Locked.");
    }
}

- (void)stopAndClearAuditor {
    if ( !self.locked ) {
        return [self.innerModel stopAndClearAuditor];
    }
    else {
        NSLog(@"🔴 stopAndClearAuditor - Model Locked.");
    }
}

- (NSNumber *)auditIssueCount {
    if ( !self.locked ) {
        return self.innerModel.auditIssueCount;
    }
    else {
        NSLog(@"🔴 auditIssueCount - Model Locked.");
        return nil;
    }
}

- (BOOL)isFlaggedByAudit:(NSUUID *)item {
    if ( !self.locked ) {
        return [self.innerModel isFlaggedByAudit:item];
    }
    else {
        NSLog(@"🔴 isFlaggedByAudit - Model Locked.");
        return NO;
    }
}

- (NSArray<NSString *> *)getQuickAuditAllIssuesVeryBriefSummaryForNode:(NSUUID *)item {
    if ( !self.locked ) {
        return [self.innerModel getQuickAuditAllIssuesVeryBriefSummaryForNode:item];
    }
    else {
        NSLog(@"🔴 getQuickAuditAllIssuesVeryBriefSummaryForNode - Model Locked.");
        return @[];
    }
}

- (NSArray<NSString *> *)getQuickAuditAllIssuesSummaryForNode:(NSUUID *)item {
    if ( !self.locked ) {
        return [self.innerModel getQuickAuditAllIssuesSummaryForNode:item];
    }
    else {
        NSLog(@"🔴 getQuickAuditAllIssuesSummaryForNode - Model Locked.");
        return @[];
    }
}

- (NSSet<Node *> *)getDuplicatedPasswordNodeSet:(NSUUID *)node {
    if ( !self.locked ) {
        return [self.innerModel getDuplicatedPasswordNodeSet:node];
    }
    else {
        NSLog(@"🔴 getDuplicatedPasswordNodeSet - Model Locked.");
        return NSSet.set;
    }
}

- (NSSet<Node *> *)getSimilarPasswordNodeSet:(NSUUID *)node {
    if ( !self.locked ) {
        return [self.innerModel getSimilarPasswordNodeSet:node];
    }
    else {
        NSLog(@"🔴 getSimilarPasswordNodeSet - Model Locked.");
        return NSSet.set;
    }
}

- (DatabaseAuditorConfiguration *)auditConfig {
    return self.databaseMetadata.auditConfig;
}

- (void)setAuditConfig:(DatabaseAuditorConfiguration *)auditConfig {
    self.databaseMetadata.auditConfig = auditConfig;
}

- (AuditState)auditState {
    if ( !self.locked ) {
        return self.innerModel.auditState;
    }
    else {
        NSLog(@"🔴 auditState - Model Locked.");
        return kAuditStateInitial;
    }
}

- (NSUInteger)auditHibpErrorCount {
    if ( !self.locked ) {
        return self.innerModel.auditHibpErrorCount;
    }
    else {
        NSLog(@"🔴 auditState - Model Locked.");
        return 0;
    }
}

- (NSUInteger)auditIssueNodeCount {
    if ( !self.locked ) {
        return self.innerModel.auditIssueNodeCount;
    }
    else {
        NSLog(@"🔴 auditState - Model Locked.");
        return 0;
    }
}

- (void)setItemAuditExclusion:(Node*)node exclude:(BOOL)exclude {
    [self setItemAuditExclusion:node exclude:exclude modified:nil];
}

- (void)setItemAuditExclusion:(Node*)node exclude:(BOOL)exclude modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemAuditExclusion - Model is RO!");
        return;
    }
    
    if ( [self isExcludedFromAudit:node.uuid] == exclude ) {
        NSLog(@"✅ NOP - setItemAuditExclusion");
        return;
    }
    
    NSDate* oldModified = node.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if ( node.fields.keePassHistory.count > 0 ) {
            [node.fields.keePassHistory removeLastObject];
        }
    }
    else {
        Node* cloneForHistory = [node cloneForHistory];
        [node.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [self.innerModel excludeFromAudit:node exclude:exclude];
    
    [self touchAndModify:node modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemAuditExclusion:node exclude:!exclude modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"exclude_item_from_audit", @"Exclude Item from Audit");
        [self.document.undoManager setActionName:loc];
    }
    
    [self restartBackgroundAudit];
}

- (BOOL)isExcludedFromAudit:(NSUUID*)item {
    if ( !self.locked ) {
        return [self.innerModel isExcludedFromAudit:item];
    }
    else {
        NSLog(@"🔴 isExcludedFromAudit - Model Locked.");
        return NO;
    }
}

- (NSArray<Node*>*)getExcludedAuditItems {
    if ( !self.locked ) {
        return [self.innerModel getExcludedAuditItems];
    }
    else {
        NSLog(@"🔴 getExcludedAuditItems - Model Locked.");
        return @[];
    }
}

- (DatabaseAuditReport *)auditReport {
    if ( !self.locked ) {
        return self.innerModel.auditReport;
    }
    else {
        NSLog(@"🔴 auditReport - Model Locked.");
        return nil;
    }
}

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion {
    if ( !self.locked ) {
        [self.innerModel oneTimeHibpCheck:password completion:completion];
    }
    else {
        NSLog(@"🔴 oneTimeHibpCheck - Model Locked.");
    }
}



- (BOOL)isDereferenceableText:(NSString *)text {
    return [self.database isDereferenceableText:text];
}

- (NSString *)dereference:(NSString *)text node:(Node *)node {
    return [self.database dereference:text node:node];
}



-(CompositeKeyFactors *)compositeKeyFactors {
    return self.locked ? nil : self.database.ckfs;
}

- (void)setCompositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    CompositeKeyFactors* original = [self.database.ckfs clone];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setCompositeKeyFactors:original];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_change_master_credentials", @"Change Master Credentials");
    [self.document.undoManager setActionName:loc];
    
    self.database.ckfs = compositeKeyFactors;
}



- (BOOL)recycleBinEnabled {
    return self.database.recycleBinEnabled;
}

- (Node *)recycleBinNode {
    return self.database.recycleBinNode;
}

- (Node *)keePass1BackupNode {
    return self.database.keePass1BackupNode;
}



- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title {
    return [self setItemTitle:item title:title modified:nil];
}

- (void)setItemEmail:(Node*_Nonnull)item email:(NSString*_Nonnull)email {
    [self setItemEmail:item email:email modified:nil];
}

- (void)setItemUsername:(Node*_Nonnull)item username:(NSString*_Nonnull)username {
    [self setItemUsername:item username:username modified:nil];
}

- (void)setItemUrl:(Node*_Nonnull)item url:(NSString*_Nonnull)url {
    [self setItemUrl:item url:url modified:nil];
}

- (void)setItemPassword:(Node*_Nonnull)item password:(NSString*_Nonnull)password {
    [self setItemPassword:item password:password modified:nil];
}

- (void)setItemNotes:(Node*)item notes:(NSString*)notes {
    [self setItemNotes:item notes:notes modified:nil];
}

- (void)setItemExpires:(Node *)item expiry:(NSDate *)expiry {
    [self setItemExpires:item expiry:expiry modified:nil];
}



- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemTitle - Model is RO!");
        return NO;
    }
    
    NSString* old = item.title;
    NSDate* oldModified = item.fields.modified;
    
    Node* cloneForHistory = [item cloneForHistory];
    if( [item setTitle:title keePassGroupTitleRules:self.format != kPasswordSafe] ) {
        [self touchAndModify:item modDate:modified];
        
        if(self.document.undoManager.isUndoing) {
            if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
        }
        else {
            [item.fields.keePassHistory addObject:cloneForHistory];
        }
        
        [[self.document.undoManager prepareWithInvocationTarget:self] setItemTitle:item title:old modified:oldModified];
        
        NSString* loc = NSLocalizedString(@"mac_undo_action_title_change", @"Title Change");
        [self.document.undoManager setActionName:loc];
        
        [self rebuildMapsAndCaches];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTitleChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
        });
        
        return YES;
    }
    
    return NO;
}

- (void)setItemEmail:(Node*_Nonnull)item email:(NSString*_Nonnull)email modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemEmail - Model is RO!");
        return;
    }
    
    NSString* old = item.fields.email;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    item.fields.email = email;
    
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemEmail:item email:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_email_change", @"Email Change");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationEmailChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)touchAndModify:(Node*)item modDate:(NSDate*_Nullable)modDate {
    if(modDate) {
        [item touch:YES touchParents:YES date:modDate];
    }
    else {
        [item touch:YES touchParents:YES];
    }
}

- (void)setItemUsername:(Node*_Nonnull)item username:(NSString*_Nonnull)username modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemUsername - Model is RO!");
        return;
    }
    
    NSString* old = item.fields.username;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    item.fields.username = username;
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemUsername:item username:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_username_change", @"Username Change");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationUsernameChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemUrl:(Node*_Nonnull)item url:(NSString*_Nonnull)url modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemUrl - Model is RO!");
        return;
    }
    
    NSString* old = item.fields.url;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    item.fields.url = url;
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemUrl:item url:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_url_change", @"URL Change");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationUrlChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemPassword:(Node*_Nonnull)item password:(NSString*_Nonnull)password modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemPassword - Model is RO!");
        return;
    }
    
    NSString* old = item.fields.password;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) {
            [item.fields.keePassHistory removeLastObject];
        }
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        
        NSLog(@"setItemPassword: %ld / %ld", cloneForHistory.fields.keePassHistory.count, item.fields.keePassHistory.count);
        
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    item.fields.password = password;
    [self touchAndModify:item modDate:modified];
    item.fields.passwordModified = item.fields.modified;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemPassword:item password:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_password_change", @"Password Change");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationPasswordChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemNotes:(Node*)item notes:(NSString*)notes modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemNotes - Model is RO!");
        return;
    }
    
    NSString* old = item.fields.notes;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    item.fields.notes = notes;
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemNotes:item notes:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_notes_change", @"Notes Change");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationNotesChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemExpires:(Node*)item expiry:(NSDate*)expiry modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemExpires - Model is RO!");
        return;
    }
    
    NSDate* old = item.fields.expires;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    item.fields.expires = expiry;
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemExpires:item expiry:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_expiry_change", @"Expiry Date Change");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationExpiryChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setSearchableState:(Node *)item searchable:(NSNumber*)searchable {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setSearchableState - Model is RO!");
        return;
    }
    
    
    
    item.fields.enableSearching = searchable;
    [self touchAndModify:item modDate:NSDate.date];
    [self.document updateChangeCount:NSChangeDone];
}

- (void)setGroupExpandedState:(Node *)item expanded:(BOOL)expanded {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setGroupExpandedState - Model is RO!");
        return;
    }
    
    
    
    item.fields.isExpanded = expanded;
    [self touchAndModify:item modDate:NSDate.date];
    [self.document updateChangeCount:NSChangeDone];
}

- (BOOL)applyModelEditsAndMoves:(EntryViewModel *)editModel toNode:(NSUUID*)nodeId {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 applyModelEditsAndMoves - Model is RO!");
        return NO;
    }
    
    Node* node = [self getItemById:nodeId];
    if ( node == nil ) {
        NSLog(@"🔴 Could not find destination node!");
        return NO;
    }
    
    Node* cloneForApplication = [node clone];
    
    if ( ![editModel applyToNode:cloneForApplication
                  databaseFormat:self.format
         legacySupplementaryTotp:NO
                   addOtpAuthUrl:YES] ) {
        return NO;
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    if ( ![self editNodeFieldsUsingSourceNode:cloneForApplication destination:nodeId] ) {
        [self.document.undoManager endUndoGrouping];
        NSLog(@"🔴 Could not edit node fields using source node!");
        return NO;
    }
    
    
    
    node = [self getItemById:nodeId];
    
    if (!( ( editModel.parentGroupUuid == nil && node.parent.uuid == nil ) || (editModel.parentGroupUuid && [editModel.parentGroupUuid isEqual:node.parent.uuid]) )) {
        Node* parent = [self getItemById:editModel.parentGroupUuid];
        if ( parent == nil || !parent.isGroup ) {
            [self.document.undoManager endUndoGrouping];
            NSLog(@"🔴 Could not find destination node!");
            return NO;
        }
        
        if (! [self move:@[node] destination:parent] ) {
            [self.document.undoManager endUndoGrouping];
            NSLog(@"🔴 Could not move node!");
            return NO;
        }
    }
    
    [self rebuildMapsAndCaches];
    
    NSString* loc = NSLocalizedString(@"browse_prefs_tap_action_edit", @"Edit Item");
    
    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];
    
    return YES;
}

- (BOOL)editNodeFieldsUsingSourceNode:(Node*)sourceNode destination:(NSUUID*)destination {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 editNodeFieldsUsingSourceNode - Model is RO!");
        return NO;
    }
    
    Node* destinationNode = [self getItemById:destination];
    if ( destinationNode == nil ) {
        NSLog(@"🔴 Could not find destination node!");
        return NO;
    }
    
    Node* old = [destinationNode clone];
    Node* cloneForHistory = [destinationNode cloneForHistory];
    
    if ( [destinationNode mergePropertiesInFromNode:sourceNode
                           mergeLocationChangedDate:NO
                                     includeHistory:NO
                             keePassGroupTitleRules:NO] ) {
        if(self.document.undoManager.isUndoing) {
            if(destinationNode.fields.keePassHistory.count > 0) [destinationNode.fields.keePassHistory removeLastObject];
        }
        else {
            [destinationNode.fields.keePassHistory addObject:cloneForHistory];
        }
        
        [[self.document.undoManager prepareWithInvocationTarget:self] editNodeFieldsUsingSourceNode:old destination:destination];
        
        NSString* loc = NSLocalizedString(@"browse_prefs_tap_action_edit", @"Edit Item");
        [self.document.undoManager setActionName:loc];
        
        [self rebuildMapsAndCaches];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemEdited object:self userInfo:@{ kNotificationUserInfoKeyNode : destinationNode }];
        });
        
        return YES;
    }
    
    return NO;
}



- (void)batchSetIcons:(NSArray<Node*>*)items icon:(NodeIcon*)icon {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 batchSetIcons - Model is RO!");
        return;
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for (Node* item in items) {
        [self setItemIcon:item icon:icon batchUpdate:YES];
    }
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_set_icons", @"Set Icon(s)");
    
    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationIconChanged
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyIsBatchIconUpdate : @(YES)}];
    });
}

- (void)batchSetIcons:(NSDictionary<NSUUID *,NSImage *>*)iconMap {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 batchSetIcons - Model is RO!");
        return;
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for (Node* item in self.rootGroup.allChildRecords) {
        NSImage* selectedImage = iconMap[item.uuid];
        if(selectedImage) {
            CGImageRef cgRef = [selectedImage CGImageForProposedRect:NULL context:nil hints:nil];
            
            if (cgRef) { 
                NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
                NSData *selectedImageData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{ }];
                [self setItemIcon:item icon:[NodeIcon withCustom:selectedImageData] batchUpdate:YES];
            }
        }
    }
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_set_icons", @"Set Icon(s)");
    
    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationIconChanged
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyIsBatchIconUpdate : @(YES)}];
    });
}

- (void)setItemIcon:(Node *)item image:(NSImage *)image {
    if(image) {
        CGImageRef cgRef = [image CGImageForProposedRect:NULL context:nil hints:nil];
        
        if (cgRef) { 
            NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
            NSData *selectedImageData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{ }];
            [self setItemIcon:item icon:[NodeIcon withCustom:selectedImageData]];
        }
    }
}

- (void)setItemIcon:(Node *)item icon:(NodeIcon*)icon {
    [self setItemIcon:item icon:icon batchUpdate:NO];
}

- (void)setItemIcon:(Node *)item icon:(NodeIcon*)icon batchUpdate:(BOOL)batchUpdate {
    [self setItemIcon:item icon:icon modified:nil batchUpdate:batchUpdate];
}

- (void)setItemIcon:(Node *)item
               icon:(NodeIcon*_Nullable)icon
           modified:(NSDate*)modified
        batchUpdate:(BOOL)batchUpdate  {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setItemIcon - Model is RO!");
        return;
    }
    
    NodeIcon* oldIcon = item.icon;
    NSDate* oldModified = item.fields.modified;
    
    
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    
    
    item.icon = icon;
    
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemIcon:item icon:oldIcon modified:oldModified batchUpdate:batchUpdate];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_icon_change", @"Icon Change");
    [self.document.undoManager setActionName:loc];
    
    if ( !batchUpdate ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationIconChanged
                                                              object:self
                                                            userInfo:@{ kNotificationUserInfoKeyIsBatchIconUpdate : @(NO)}];
        });
    }
}



- (void)deleteHistoryItem:(Node *)item historicalItem:(Node *)historicalItem {
    [self deleteHistoryItem:item historicalItem:historicalItem index:-1 modified:nil];
}

- (void)deleteHistoryItem:(Node *)item historicalItem:(Node *)historicalItem index:(NSUInteger)index modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 deleteHistoryItem - Model is RO!");
        return;
    }
    
    NSDate* oldModified = item.fields.modified;
    
    [self touchAndModify:item modDate:modified];
    
    if(!self.document.undoManager.isUndoing) {
        index = [item.fields.keePassHistory indexOfObject:historicalItem]; 
        [item.fields.keePassHistory removeObjectAtIndex:index];
    }
    else {
        [item.fields.keePassHistory insertObject:historicalItem atIndex:index];
    }
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteHistoryItem:item
                                                                     historicalItem:historicalItem
                                                                              index:index
                                                                           modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_delete_history_item", @"Delete History Item");
    [self.document.undoManager setActionName:loc];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationHistoryItemDeleted object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)restoreHistoryItem:(Node *)item historicalItem:(Node *)historicalItem {
    [self restoreHistoryItem:item historicalItem:historicalItem modified:nil];
}

- (void)restoreHistoryItem:(Node *)item historicalItem:(Node *)historicalItem modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 deleteHistoryItem - Model is RO!");
        return;
    }
    
    NSDate* oldModified = item.fields.modified;
    Node* originalNode = [item cloneForHistory];
    
    [self touchAndModify:item modDate:modified];
    
    
    
    [item.fields.keePassHistory addObject:originalNode];
    
    
    
    [item touch:YES touchParents:NO date:NSDate.date];
    
    [item restoreFromHistoricalNode:historicalItem];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] restoreHistoryItem:item
                                                                      historicalItem:originalNode
                                                                            modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_restore_history_item", @"Restore History Item");
    [self.document.undoManager setActionName:loc];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationHistoryItemRestored object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)removeItemAttachment:(Node *)item filename:(NSString *)filename {
    [self removeItemAttachment:item filename:filename modified:nil];
}

- (void)removeItemAttachment:(Node *)item filename:(NSString *)filename modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 removeItemAttachment - Model is RO!");
        return;
    }
    
    KeePassAttachmentAbstractionLayer* oldDbAttachment = item.fields.attachments[filename];
    [item.fields.attachments removeObjectForKey:filename];
    
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [[self.document.undoManager prepareWithInvocationTarget:self] addItemAttachment:item filename:filename attachment:oldDbAttachment modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_remove_attachment", @"Remove Attachment");
        [self.document.undoManager setActionName:loc];
    }
    
    [self touchAndModify:item modDate:modified];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationAttachmentsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)addItemAttachment:(Node *)item filename:(NSString *)filename attachment:(KeePassAttachmentAbstractionLayer *)attachment {
    [self addItemAttachment:item filename:filename attachment:attachment modified:nil];
}

- (void)addItemAttachment:(Node *)item filename:(NSString *)filename attachment:(KeePassAttachmentAbstractionLayer *)attachment modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 addItemAttachment - Model is RO!");
        return;
    }
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    NSDate* oldModified = item.fields.modified;
    
    item.fields.attachments[filename] = attachment;
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] removeItemAttachment:item filename:filename modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_add_attachment", @"Add Attachment");
        [self.document.undoManager setActionName:loc];
    }
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationAttachmentsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}




- (void)addCustomField:(Node *)item key:(NSString *)key value:(StringValue *)value {
    [self editCustomField:item existingFieldKey:nil key:key value:value];
}

- (void)removeCustomField:(Node *)item key:(NSString *)key {
    [self editCustomField:item existingFieldKey:key key:nil value:nil];
}



- (void)editCustomField:(Node*)item
       existingFieldKey:(NSString*)existingFieldKey
                    key:(NSString *)key
                  value:(StringValue *)value {
    [self editCustomField:item existingFieldKey:existingFieldKey key:key value:value modified:nil];
}

- (void)editCustomField:(Node*)item
       existingFieldKey:(NSString*)existingFieldKey
                    key:(NSString *)key
                  value:(StringValue *)value
               modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 editCustomField - Model is RO!");
        return;
    }
    
    
    
    
    
    
    
    
    NSString* oldKey = existingFieldKey;
    StringValue* oldValue = existingFieldKey ? [item.fields.customFields objectForKey:existingFieldKey] : nil;
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    BOOL changedSomething = NO;
    if ( oldValue ) {
        changedSomething = YES;
        [item.fields removeCustomField:oldKey];
    }
    
    if ( key && value ) {
        changedSomething = YES;
        [item.fields setCustomField:key value:value];
    }
    
    if ( changedSomething ) {
        [self touchAndModify:item modDate:modified];
        
        [[self.document.undoManager prepareWithInvocationTarget:self] editCustomField:item existingFieldKey:key key:oldKey value:oldValue modified:oldModified];
        
        if(!self.document.undoManager.isUndoing) {
            NSString* loc;
            if ( oldKey == nil ) {
                loc = NSLocalizedString(@"mac_undo_action_add_custom_field", @"Add Custom Field");
            }
            else if ( key == nil ) {
                loc = NSLocalizedString(@"mac_undo_action_remove_custom_field", @"Remove Custom Field");
            }
            else {
                loc = NSLocalizedString(@"mac_undo_action_set_custom_field", @"Set Custom Field");
            }
            
            [self.document.undoManager setActionName:loc];
        }
        
        [self rebuildMapsAndCaches];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationCustomFieldsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
        });
    }
    else {
        NSLog(@"WARNWARN: NOP in editCustomField [%@] - [%@]", existingFieldKey, key);
    }
}



- (void)setTotp:(Node *)item otp:(NSString *)otp steam:(BOOL)steam {
    [self setTotp:item otp:otp steam:steam modified:nil];
}

- (void)setTotp:(Node *)item otp:(NSString *)otp steam:(BOOL)steam modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setTotp - Model is RO!");
        return;
    }
    
    Node* cloneForHistory = [item cloneForHistory];
    [item.fields.keePassHistory addObject:cloneForHistory];
    
    [self touchAndModify:item modDate:modified];
    
    [item setTotpWithString:otp
           appendUrlToNotes:self.format == kPasswordSafe || self.format == kKeePass1
                 forceSteam:steam
            addLegacyFields:Settings.sharedInstance.addLegacySupplementaryTotpCustomFields
              addOtpAuthUrl:Settings.sharedInstance.addOtpAuthUrl];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] clearTotp:item];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_set_totp", @"Set TOTP");
        [self.document.undoManager setActionName:loc];
    }
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTotpChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

-(void)clearTotp:(Node *)item  {
    [self clearTotp:item modified:nil];
}

-(void)clearTotp:(Node *)item modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 clearTotp - Model is RO!");
        return;
    }
    
    OTPToken* oldOtpToken = item.fields.otpToken;
    if(oldOtpToken == nil) { 
        NSLog(@"Attempt to clear non existent OTP token");
        return;
    }
    
    NSURL* oldOtpTokenUrl = [oldOtpToken url:YES];
    Node* cloneForHistory = [item cloneForHistory];
    [item.fields.keePassHistory addObject:cloneForHistory];
    
    [self touchAndModify:item modDate:modified];
    
    [item.fields clearTotp];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setTotp:item otp:oldOtpTokenUrl.absoluteString steam:oldOtpToken.algorithm == OTPAlgorithmSteam];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_clear_totp", @"Clear TOTP");
        [self.document.undoManager setActionName:loc];
    }
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTotpChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}



- (BOOL)isFavourite:(NSUUID *)itemId {
    if ( self.locked ) {
        NSLog(@"🔴 Model is locked. isFavourite");
        return NO;
    }
    else {
        return [self.innerModel isFavourite:itemId];
    }
}

- (void)toggleFavourite:(NSUUID *)itemId {
    [self toggleFavourite:itemId modified:nil];
}

- (void)toggleFavourite:(NSUUID *)itemId modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 toggleFavourite - Model is RO!");
        return;
    }
    
    BOOL fav = ![self isFavourite:itemId];
    
    Node* item = [self getItemById:itemId];
    NSDate* oldModified = item.fields.modified;
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [self.innerModel toggleFavourite:itemId];
    [self touchAndModify:item modDate:modified];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] toggleFavourite:itemId modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = fav ? NSLocalizedString(@"browse_vc_action_pin", @"Favourite") : NSLocalizedString(@"browse_vc_action_unpin", @"Un-Favourite");
        [self.document.undoManager setActionName:loc];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTagsChanged object:self userInfo:nil];
    });
}

- (NSArray<Node *> *)favourites {
    if ( self.locked ) {
        NSLog(@"🔴 Model is locked. Favourites");
        return @[];
    }
    else {
        return self.innerModel.favourites;
    }
}



- (void)addItemTag:(Node *)item tag:(NSString *)tag {
    [self addItemTag:item tag:tag modified:nil];
}

- (void)addItemTag:(Node *)item tag:(NSString *)tag modified:(NSDate*)modified {
    [self addTagToItems:@[item] tag:tag modified:modified];
}

- (void)addTagToItems:(const NSArray<Node *> *)items tag:(NSString *)tag  {
    [self addTagToItems:items tag:tag modified:nil];
}

- (void)addTagToItems:(const NSArray<Node *> *)items tag:(NSString *)tag modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 addTagToItems - Model is RO!");
        return;
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for (Node* item in items) {
        if ( [item.fields.tags containsObject:tag] ) {
            continue;
        }
        
        NSDate* oldModified = item.fields.modified;
        
        if(self.document.undoManager.isUndoing) {
            if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
        }
        else {
            Node* cloneForHistory = [item cloneForHistory];
            [item.fields.keePassHistory addObject:cloneForHistory];
        }
        
        [item.fields.tags addObject:tag];
        
        [self touchAndModify:item modDate:modified];
        
        [[self.document.undoManager prepareWithInvocationTarget:self] removeItemTag:item tag:tag modified:oldModified];
        
        if(!self.document.undoManager.isUndoing) {
            NSString* loc = NSLocalizedString(@"mac_undo_action_add_tag", @"Add Tag");
            [self.document.undoManager setActionName:loc];
        }
    }
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"add_tag_to_items", @"Add Tag to Item(s)");
        [self.document.undoManager setActionName:loc];
    }
    [self.document.undoManager endUndoGrouping];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTagsChanged object:self userInfo:nil];
    });
}

- (void)removeItemTag:(Node *)item tag:(NSString *)tag {
    [self removeItemTag:item tag:tag modified:nil];
}

- (void)removeItemTag:(Node *)item tag:(NSString *)tag modified:(NSDate*)modified {
    [self removeTagFromItems:@[item] tag:tag modified:modified];
}

- (void)removeTagFromItems:(const NSArray<Node *> *)items tag:(NSString *)tag {
    [self removeTagFromItems:items tag:tag modified:nil];
}

- (void)removeTagFromItems:(const NSArray<Node *> *)items tag:(NSString *)tag modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 removeTagFromItems - Model is RO!");
        return;
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for ( Node* item in items ) {
        if ( ![item.fields.tags containsObject:tag] ) {
            continue;
        }
        
        NSDate* oldModified = item.fields.modified;
        
        if(self.document.undoManager.isUndoing) {
            if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
        }
        else {
            Node* cloneForHistory = [item cloneForHistory];
            [item.fields.keePassHistory addObject:cloneForHistory];
        }
        
        [item.fields.tags removeObject:tag];
        
        [self touchAndModify:item modDate:modified];
        
        [[self.document.undoManager prepareWithInvocationTarget:self] addItemTag:item tag:tag modified:oldModified];
        
        if(!self.document.undoManager.isUndoing) {
            NSString* loc = NSLocalizedString(@"mac_undo_action_remove_tag", @"Remove Tag");
            [self.document.undoManager setActionName:loc];
        }
    }
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"remove_tag_from_items", @"Remove Tag from Item(s)");
        [self.document.undoManager setActionName:loc];
    }
    [self.document.undoManager endUndoGrouping];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTagsChanged object:self userInfo:nil];
    });
}

- (void)renameTag:(NSString *)from to:(NSString*)to {
    [self renameTag:from to:to modified:nil];
}

- (void)renameTag:(NSString *)from to:(NSString*)to modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 addTagToItems - Model is RO!");
        return;
    }
    
    if ( to.length == 0 || from.length == 0 || [from isEqualToString:to] ) {
        NSLog(@"🔴 renameTag - invalid to or from");
        return;
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for ( Node* item in [self entriesWithTag:from] ) {
        NSDate* oldModified = item.fields.modified;
        
        if(self.document.undoManager.isUndoing) {
            if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
        }
        else {
            Node* cloneForHistory = [item cloneForHistory];
            [item.fields.keePassHistory addObject:cloneForHistory];
        }
        
        [item.fields.tags removeObject:from];
        [item.fields.tags addObject:to];
        
        [self touchAndModify:item modDate:modified];
        
        [[self.document.undoManager prepareWithInvocationTarget:self] renameTag:to to:from modified:oldModified];
    }
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"action_rename_tag", @"Rename Tag");
        [self.document.undoManager setActionName:loc];
    }
    [self.document.undoManager endUndoGrouping];
    
    [self rebuildMapsAndCaches];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTagsChanged object:self userInfo:nil];
    });
}

- (void)deleteTag:(NSString *)tag {
    NSArray<Node*>* entries = [self entriesWithTag:tag];
    
    [self removeTagFromItems:entries tag:tag];
}



- (NSString*)getDefaultTitle {
    return NSLocalizedString(@"item_details_vc_new_item_title", @"Untitled");
}

- (NSSet<Node *> *)getMinimalNodeSet:(const NSArray<Node *> *)nodes {
    return [self.database getMinimalNodeSet:nodes];
}




- (BOOL)addNewRecord:(Node *_Nonnull)parentGroup {
    Node* record = [self getDefaultNewEntryNode:parentGroup];
    return [self addItem:record parent:parentGroup openEntryDetailsWindowWhenDone:YES];
}

- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString *)title {
    return [self addNewGroup:parentGroup title:title group:nil];
}

- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString *)title group:(Node **)group {
    if ( !parentGroup ) {
        return NO;
    }
    
    Node* newGroup = [self getNewGroupWithSafeName:parentGroup title:title];
    
    BOOL ret = [self addItem:newGroup parent:parentGroup openEntryDetailsWindowWhenDone:NO];
    
    if ( ret && group ) {
        *group = newGroup;
    }
    
    return ret;
}

- (BOOL)addItem:(Node *)item parent:(Node *)parent {
    return [self addItem:item parent:parent openEntryDetailsWindowWhenDone:NO];
}

- (BOOL)addItem:(Node*)item parent:(Node*)parent openEntryDetailsWindowWhenDone:(BOOL)openEntryDetailsWindowWhenDone {
    return [self addChildren:@[item] parent:parent openEntryDetailsWindowWhenDone:openEntryDetailsWindowWhenDone];
}

- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent {
    return [self addChildren:children parent:parent openEntryDetailsWindowWhenDone:NO];
}

- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent openEntryDetailsWindowWhenDone:(BOOL)openEntryDetailsWindowWhenDone {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 addChildren - Model is RO!");
        return NO;
    }
    
    if ( parent == nil ) {
        NSLog(@"🔴 Failed to add child to NIL parent");
        return NO;
    }
    
    if ( ![self.database validateAddChildren:children destination:parent] ) {
        return NO;
    }
    
    [self.database addChildren:children destination:parent];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] unAddChildren:children parent:parent];
    
    NSString* loc = children.count > 1 ? NSLocalizedString(@"mac_undo_action_add_items", @"Add Items") : NSLocalizedString(@"mac_undo_action_add_item", @"Add Item");
    [self.document.undoManager setActionName:loc];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsAdded
                                                      object:self
                                                    userInfo:@{ kNotificationUserInfoKeyNode : children ,
                                                                kNotificationUserInfoKeyBoolParam : @(openEntryDetailsWindowWhenDone)
                                                             }];
    
    [self rebuildMapsAndCaches];
    
    return YES;
}

- (void)unAddChildren:(NSArray<Node *>*)children parent:(Node *)parent {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 unAddChildren - Model is RO!");
        return;
    }
    
    
    
    NSArray<Node*> *originals = [children map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj clone];
    }];
    
    NSArray<NSUUID*> *childIds = [children map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }];
    
    [self.database removeChildren:childIds];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] addChildren:originals parent:parent];
    
    NSString* loc = children.count > 1 ? NSLocalizedString(@"mac_undo_action_add_items", @"Add Items") : NSLocalizedString(@"mac_undo_action_add_item", @"Add Item");
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsDeleted
                                                      object:self
                                                    userInfo:@{ kNotificationUserInfoKeyNode : children }];
}

- (BOOL)canRecycle:(Node *)item {
    return [self.database canRecycle:item.uuid];
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 deleteItems - Model is RO!");
        return;
    }
    
    NSArray<NodeHierarchyReconstructionData*>* undoData;
    [self.database deleteItems:items undoData:&undoData];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] unDeleteItems:undoData];
    
    NSString* loc = items.count > 1 ?   NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
    NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");
    
    [self.document.undoManager setActionName:loc];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsDeleted
                                                      object:self
                                                    userInfo:@{ kNotificationUserInfoKeyNode : items }];
    
    [self rebuildMapsAndCaches];
}

- (void)unDeleteItems:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 unDeleteItems - Model is RO!");
        return;
    }
    
    [self.database unDelete:undoData];
    
    NSArray<Node*>* items = [undoData map:^id _Nonnull(NodeHierarchyReconstructionData * _Nonnull obj, NSUInteger idx) {
        return obj.clonedNode;
    }];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteItems:items];
    
    NSString* loc = items.count > 1 ? NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
    NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");
    
    [self.document.undoManager setActionName:loc];
    
    [self rebuildMapsAndCaches];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsUnDeleted
                                                      object:self
                                                    userInfo:nil];
}



- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 recycleItems - Model is RO!");
        return NO;
    }
    
    NSArray<NodeHierarchyReconstructionData*> *undoData;
    BOOL ret = [self.database recycleItems:items undoData:&undoData];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] unRecycleItems:undoData];
    
    NSString* loc = items.count > 1 ?   NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
    NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");
    [self.document.undoManager setActionName:loc];
    
    if (ret) {
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsDeleted
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyNode : items }];
    }
    
    [self rebuildMapsAndCaches];
    
    return ret;
}

- (void)unRecycleItems:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 unRecycleItems - Model is RO!");
        return;
    }
    
    [self.database undoRecycle:undoData];
    
    NSArray<Node*>* items = [undoData map:^id _Nonnull(NodeHierarchyReconstructionData * _Nonnull obj, NSUInteger idx) {
        return obj.clonedNode;
    }];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] recycleItems:items];
    
    NSString* loc = items.count > 1 ? NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
    NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");
    
    [self.document.undoManager setActionName:loc];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsUnDeleted
                                                      object:self
                                                    userInfo:nil];
    
    [self rebuildMapsAndCaches];
}

- (BOOL)isInRecycled:(NSUUID *)itemId {
    return [self.innerModel isInRecycled:itemId];
}




- (BOOL)validateMove:(const NSArray<Node *> *)items destination:(Node*)destination {
    return [self.database validateMoveItems:items destination:destination];
}

- (BOOL)move:(const NSArray<Node *> *)items destination:(Node*)destination {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 move - Model is RO!");
        return NO;
    }
    
    NSArray<NodeHierarchyReconstructionData*> *undoData;
    BOOL ret = [self.database moveItems:items destination:destination undoData:&undoData];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] unMove:undoData destination:destination];
    
    NSString* loc = items.count > 1 ? NSLocalizedString(@"mac_undo_action_move_items", @"Move Items") :
    NSLocalizedString(@"mac_undo_action_move_item", @"Move Item");
    
    [self.document.undoManager setActionName:loc];
    
    if (ret) {
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsMoved
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyNode : items }];
    }
    
    [self rebuildMapsAndCaches];
    
    return ret;
}

- (void)unMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData destination:(Node*)destination {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 unMove - Model is RO!");
        return;
    }
    
    [self.database undoMove:undoData];
    
    NSArray<Node*>* items = [undoData map:^id _Nonnull(NodeHierarchyReconstructionData * _Nonnull obj, NSUInteger idx) {
        return obj.clonedNode;
    }];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] move:items destination:destination];
    
    NSString* loc = items.count > 1 ? NSLocalizedString(@"mac_undo_action_move_items", @"Move Items") :
    NSLocalizedString(@"mac_undo_action_move_item", @"Move Item");
    
    [self.document.undoManager setActionName:loc];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsMoved
                                                      object:self
                                                    userInfo:nil];
    
    [self rebuildMapsAndCaches];
}

- (BOOL)moveItemsIntoNewGroup:(const NSArray<Node *> *)items parentGroup:(Node *)parentGroup title:(NSString *)title group:(Node **)group {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 moveItemsIntoNewGroup: MODEL is READ-ONLY!");
        return NO;
    }
    
    if ( !parentGroup ) {
        return NO;
    }
    
    
    
    
    
    
    
    
    
    
    
    
    Node* newGroup = [self getNewGroupWithSafeName:parentGroup title:title];
    if ( ![self.innerModel addChildren:@[newGroup] destination:parentGroup] ) {
        NSLog(@"🔴 Failed to add child");
        return NO;
    }
    
    if ( ![self move:items destination:newGroup] ) {
        NSLog(@"🔴 Cannot move these items into this new group");
        return NO;
    }
    
    if ( group ) {
        *group = newGroup;
    }
    
    return YES;
}

- (NSInteger)reorderItem:(NSUUID *)nodeId idx:(NSInteger)idx {
    if ( self.locked ) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 move - Model is RO!");
        return NO;
    }
    
    NSInteger prevIdx = [self.innerModel reorderItem:nodeId idx:idx];
    
    if ( prevIdx != -1 ) {
        [[self.document.undoManager prepareWithInvocationTarget:self] reorderItem:nodeId idx:prevIdx];
        
        [self.document.undoManager setActionName:NSLocalizedString(@"mac_undo_action_move_item", @"Move Item")];
        
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemReOrdered object:self userInfo:@{ }];
    }
    
    return prevIdx;
}



- (void)applyEncryptionSettingsViewModelChanges:(EncryptionSettingsViewModel *)encryptionSettings {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    if ( self.isEffectivelyReadOnly ) {
        NSLog(@"🔴 setGroupExpandedState - Model is RO!");
        return;
    }
    
    [encryptionSettings applyToDatabaseModel:self.database];
    
    [self.document updateChangeCount:NSChangeDone];
}



- (BOOL)launchUrl:(Node *)item {
    return [self.innerModel launchUrl:item];
}

- (BOOL)launchUrlString:(NSString *)urlString {
    return [self.innerModel launchUrlString:urlString];
}


- (Node*)getDefaultNewEntryNode:(Node *_Nonnull)parentGroup {
    AutoFillNewRecordSettings *autoFill = Settings.sharedInstance.autoFillNewRecordSettings;
    BOOL useParentGroupIcon = Settings.sharedInstance.useParentGroupIconOnCreate;
    
    
    
    NSString *actualTitle = autoFill.titleAutoFillMode == kDefault ? [self getDefaultTitle] :
    autoFill.titleAutoFillMode == kSmartUrlFill ? [self getSmartFillTitle] : autoFill.titleCustomAutoFill;
    
    
    
    NSString *actualUsername = autoFill.usernameAutoFillMode == kNone ? @"" :
    autoFill.usernameAutoFillMode == kMostUsed ? [self getAutoFillMostPopularUsername] : autoFill.usernameCustomAutoFill;
    
    
    
    NSString *actualPassword = autoFill.passwordAutoFillMode == kNone ? @"" : autoFill.passwordAutoFillMode == kGenerated ? [self generatePassword] : autoFill.passwordCustomAutoFill;
    
    
    
    NSString *actualEmail = autoFill.emailAutoFillMode == kNone ? @"" :
    autoFill.emailAutoFillMode == kMostUsed ? [self getAutoFillMostPopularEmail] : autoFill.emailCustomAutoFill;
    
    
    
    NSString *actualUrl = autoFill.urlAutoFillMode == kNone ? @"" :
    autoFill.urlAutoFillMode == kSmartUrlFill ? [self getSmartFillUrl] : autoFill.urlCustomAutoFill;
    
    
    
    NSString *actualNotes = autoFill.notesAutoFillMode == kNone ? @"" :
    autoFill.notesAutoFillMode == kClipboard ? [self getSmartFillNotes] : autoFill.notesCustomAutoFill;
    
    
    
    NodeFields* fields = [[NodeFields alloc] initWithUsername:actualUsername
                                                          url:actualUrl
                                                     password:actualPassword
                                                        notes:actualNotes
                                                        email:actualEmail];
    
    Node* record = [[Node alloc] initAsRecord:actualTitle parent:parentGroup fields:fields uuid:nil];
    
    if ( useParentGroupIcon && !parentGroup.isUsingKeePassDefaultIcon ) {
        record.icon = parentGroup.icon;
    }
    
    return record;
}

- (Node*)getNewGroupWithSafeName:(Node *)parentGroup title:(NSString *)title {
    if ( !parentGroup ) {
        return nil;
    }
    
    NSInteger i = 0;
    BOOL success = NO;
    Node* newGroup;
    
    do {
        newGroup = [[Node alloc] initAsGroup:title parent:parentGroup keePassGroupTitleRules:self.format != kPasswordSafe uuid:nil];
        success =  newGroup && [parentGroup validateAddChild:newGroup keePassGroupTitleRules:self.format != kPasswordSafe];
        i++;
        title = [NSString stringWithFormat:@"%@ %ld", title, i];
    } while (!success);
    
    return newGroup;
}

- (NSString*)getSmartFillTitle {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        
        
        NSURL *url = clipboardText.urlExtendedParse;
        
        if (url && url.scheme && url.host)
        {
            return url.host;
        }
    }
    
    return [self getDefaultTitle];
}

- (NSString*)getSmartFillUrl {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        NSURL *url = clipboardText.urlExtendedParse;
        if (url && url.scheme && url.host)
        {
            return clipboardText;
        }
    }
    
    return @"";
}

- (NSString*)getSmartFillNotes {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        return clipboardText;
    }
    
    return @"";
}

- (NSString*)getAutoFillMostPopularUsername {
    return self.database.mostPopularUsername == nil ? @"" : self.database.mostPopularUsername;
}

- (NSString*)getAutoFillMostPopularEmail {
    return self.database.mostPopularEmail == nil ? @"" : self.database.mostPopularEmail;
}

- (Node*)getItemFromSerializationId:(NSString*)serializationId {
    return [self.database getItemByCrossSerializationFriendlyId:serializationId];
}

- (NSString*)generatePassword {
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:Settings.sharedInstance.passwordGenerationConfig];
}

- (NSSet<NSString*> *)customFieldKeySet {
    return self.database.customFieldKeySet;
}

- (NSSet<NSString*> *)emailSet {
    return self.database.emailSet;
}

- (NSSet<NSString *> *)tagSet {
    return self.database.tagSet;
}

- (NSSet<NSString*> *)urlSet {
    return self.database.urlSet;
}

- (NSSet<NSString*> *)usernameSet {
    return self.database.usernameSet;
}





- (NSString *)mostPopularUsername {
    return self.database.mostPopularUsername;
}

- (NSArray<NSString *> *)mostPopularUsernames {
    return self.database.mostPopularUsernames;
}

- (NSString *)mostPopularEmail {
    return self.database.mostPopularEmail;
}

- (NSArray<NSString *> *)mostPopularEmails {
    return self.database.mostPopularEmails;
}

- (NSArray<NSString *> *)mostPopularTags {
    return self.database.mostPopularTags;
}

- (NSInteger)fastEntryTotalCount {
    return self.database.fastEntryTotalCount;
}

- (NSInteger)fastGroupTotalCount {
    return self.database.fastGroupTotalCount;
}

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.database isTitleMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.database isUsernameMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.database isPasswordMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.database isUrlMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.database isAllFieldsMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText {
    return [self.database getSearchTerms:searchText];
}

- (NSString *)getHtmlPrintString:(NSString*)databaseName {
    return [self.database getHtmlPrintString:databaseName];
}



- (BOOL)showTotp {
    return !self.databaseMetadata.doNotShowTotp;
}

- (void)setShowTotp:(BOOL)showTotp {
    self.databaseMetadata.doNotShowTotp = !showTotp;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showAutoCompleteSuggestions {
    return !self.databaseMetadata.doNotShowAutoCompleteSuggestions;
}

- (void)setShowAutoCompleteSuggestions:(BOOL)showAutoCompleteSuggestions {
    self.databaseMetadata.doNotShowAutoCompleteSuggestions = !showAutoCompleteSuggestions;
}

- (BOOL)showChangeNotifications {
    return !self.databaseMetadata.doNotShowChangeNotifications;
}

- (void)setShowChangeNotifications:(BOOL)showChangeNotifications {
    self.databaseMetadata.doNotShowChangeNotifications = !showChangeNotifications;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)concealEmptyProtectedFields {
    return self.databaseMetadata.concealEmptyProtectedFields;
}

- (void)setConcealEmptyProtectedFields:(BOOL)concealEmptyProtectedFields {
    self.databaseMetadata.concealEmptyProtectedFields = concealEmptyProtectedFields;
}

- (BOOL)autoPromptForConvenienceUnlockOnActivate {
    return self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate;
}

- (void)setAutoPromptForConvenienceUnlockOnActivate:(BOOL)autoPromptForConvenienceUnlockOnActivate {
    self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate = autoPromptForConvenienceUnlockOnActivate;
}

- (BOOL)showAdvancedUnlockOptions {
    return self.databaseMetadata.showAdvancedUnlockOptions;
}

- (void)setShowAdvancedUnlockOptions:(BOOL)showAdvancedUnlockOptions {
    self.databaseMetadata.showAdvancedUnlockOptions = showAdvancedUnlockOptions;
}

- (BOOL)showQuickView {
    return self.databaseMetadata.showQuickView;
}

- (void)setShowQuickView:(BOOL)showQuickView {
    self.databaseMetadata.showQuickView = showQuickView;
}

- (BOOL)showAlternatingRows {
    return !self.databaseMetadata.noAlternatingRows;
}

- (void)setShowAlternatingRows:(BOOL)showAlternatingRows {
    self.databaseMetadata.noAlternatingRows = !showAlternatingRows;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showVerticalGrid {
    return self.databaseMetadata.showVerticalGrid;
}

- (void)setShowVerticalGrid:(BOOL)showVerticalGrid {
    self.databaseMetadata.showVerticalGrid = showVerticalGrid;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showHorizontalGrid {
    return self.databaseMetadata.showHorizontalGrid;
}

- (void)setShowHorizontalGrid:(BOOL)showHorizontalGrid {
    self.databaseMetadata.showHorizontalGrid = showHorizontalGrid;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showChildCountOnFolderInSidebar {
    return self.databaseMetadata.showChildCountOnFolderInSidebar;
}

- (void)setShowChildCountOnFolderInSidebar:(BOOL)showChildCountOnFolderInSidebar {
    self.databaseMetadata.showChildCountOnFolderInSidebar = showChildCountOnFolderInSidebar;
    [self publishDatabasePreferencesChangedNotification];
}


- (SideBarChildCountFormat)sideBarChildCountFormat {
    return self.databaseMetadata.sideBarChildCountFormat;
}

- (void)setSideBarChildCountFormat:(SideBarChildCountFormat)sideBarChildCountFormat {
    self.databaseMetadata.sideBarChildCountFormat = sideBarChildCountFormat;
    [self publishDatabasePreferencesChangedNotification];
}

- (NSString *)sideBarChildCountSeparator {
    return self.databaseMetadata.sideBarChildCountSeparator;
}

- (void)setSideBarChildCountSeparator:(NSString *)sideBarChildCountSeparator {
    self.databaseMetadata.sideBarChildCountSeparator = sideBarChildCountSeparator;
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)sideBarChildCountShowZero {
    return self.databaseMetadata.sideBarChildCountShowZero;
}

- (void)setSideBarChildCountShowZero:(BOOL)sideBarChildCountShowZero {
    self.databaseMetadata.sideBarChildCountShowZero = sideBarChildCountShowZero;
    [self publishDatabasePreferencesChangedNotification];
}

- (NSString *)sideBarChildCountGroupPrefix {
    return self.databaseMetadata.sideBarChildCountGroupPrefix;
}

- (void)setSideBarChildCountGroupPrefix:(NSString *)sideBarChildCountGroupPrefix {
    self.databaseMetadata.sideBarChildCountGroupPrefix = sideBarChildCountGroupPrefix;
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)sideBarShowTotalCountOnHierarchy {
    return self.databaseMetadata.sideBarShowTotalCountOnHierarchy;
}

- (void)setSideBarShowTotalCountOnHierarchy:(BOOL)sideBarShowTotalCountOnHierarchy {
    self.databaseMetadata.sideBarShowTotalCountOnHierarchy = sideBarShowTotalCountOnHierarchy;
    [self publishDatabasePreferencesChangedNotification];
}


- (NSArray *)visibleColumns {
    return self.databaseMetadata.visibleColumns;
}

- (void)setVisibleColumns:(NSArray *)visibleColumns {
    self.databaseMetadata.visibleColumns = visibleColumns;
}

- (BOOL)downloadFavIconOnChange {
    return self.databaseMetadata.expressDownloadFavIconOnNewOrUrlChanged;
}

- (void)setDownloadFavIconOnChange:(BOOL)downloadFavIconOnChange {
    self.databaseMetadata.expressDownloadFavIconOnNewOrUrlChanged = downloadFavIconOnChange;
}

- (BOOL)promptedForAutoFetchFavIcon {
    return self.databaseMetadata.promptedForAutoFetchFavIcon;
}

- (void)setPromptedForAutoFetchFavIcon:(BOOL)promptedForAutoFetchFavIcon {
    self.databaseMetadata.promptedForAutoFetchFavIcon = promptedForAutoFetchFavIcon;
}

- (BOOL)startWithSearch {
    return self.databaseMetadata.startWithSearch;
}

- (void)setStartWithSearch:(BOOL)startWithSearch {
    self.databaseMetadata.startWithSearch = startWithSearch;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)outlineViewTitleIsReadonly {
    return self.databaseMetadata.outlineViewTitleIsReadonly;
}

- (void)setOutlineViewTitleIsReadonly:(BOOL)outlineViewTitleIsReadonly {
    self.databaseMetadata.outlineViewTitleIsReadonly = outlineViewTitleIsReadonly;
}

- (BOOL)outlineViewEditableFieldsAreReadonly {
    return self.databaseMetadata.outlineViewEditableFieldsAreReadonly;
}

- (void)setOutlineViewEditableFieldsAreReadonly:(BOOL)outlineViewEditableFieldsAreReadonly {
    self.databaseMetadata.outlineViewEditableFieldsAreReadonly = outlineViewEditableFieldsAreReadonly;
}

- (BOOL)showRecycleBinInSearchResults {
    return self.databaseMetadata.showRecycleBinInSearchResults;
}

- (void)setShowRecycleBinInSearchResults:(BOOL)showRecycleBinInSearchResults {
    self.databaseMetadata.showRecycleBinInSearchResults = showRecycleBinInSearchResults;
}

- (BOOL)showRecycleBinInBrowse {
    return !self.databaseMetadata.doNotShowRecycleBinInBrowse;
}

- (void)setShowRecycleBinInBrowse:(BOOL)showRecycleBinInBrowse {
    self.databaseMetadata.doNotShowRecycleBinInBrowse = !showRecycleBinInBrowse;
}

- (BOOL)monitorForExternalChanges {
    return self.databaseMetadata.monitorForExternalChanges;
    
}

- (void)setMonitorForExternalChanges:(BOOL)monitorForExternalChanges {
    self.databaseMetadata.monitorForExternalChanges = monitorForExternalChanges;
}

- (NSInteger)monitorForExternalChangesInterval {
    return self.databaseMetadata.monitorForExternalChangesInterval;
}

- (void)setMonitorForExternalChangesInterval:(NSInteger)monitorForExternalChangesInterval {
    self.databaseMetadata.monitorForExternalChangesInterval = monitorForExternalChangesInterval;
}

- (BOOL)autoReloadAfterExternalChanges {
    return self.databaseMetadata.autoReloadAfterExternalChanges;
}

- (void)setAutoReloadAfterExternalChanges:(BOOL)autoReloadAfterExternalChanges {
    self.databaseMetadata.autoReloadAfterExternalChanges = autoReloadAfterExternalChanges;
}

- (BOOL)launchAtStartup {
    return self.databaseMetadata.launchAtStartup;
}

- (void)setLaunchAtStartup:(BOOL)launchAtStartup {
    self.databaseMetadata.launchAtStartup = launchAtStartup;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)alwaysOpenOffline {
    return self.databaseMetadata.alwaysOpenOffline;
    
}

- (void)setAlwaysOpenOffline:(BOOL)alwaysOpenOffline {
    self.databaseMetadata.alwaysOpenOffline = alwaysOpenOffline;
}

- (BOOL)readOnly {
    return self.databaseMetadata.readOnly;
}

- (void)setReadOnly:(BOOL)readOnly {
    self.databaseMetadata.readOnly = readOnly;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (NSUUID *)asyncUpdateId {
    return self.databaseMetadata.asyncUpdateId;
}

- (void)setAsyncUpdateId:(NSUUID *)asyncUpdateId {
    self.databaseMetadata.asyncUpdateId = asyncUpdateId;
    
    [self publishDatabaseUpdateStatusChangedNotification];
}



- (KeePassIconSet)iconSet {
    return self.databaseMetadata.iconSet;
}

- (void)setIconSet:(KeePassIconSet)iconSet {
    self.databaseMetadata.iconSet = iconSet;
    
    [self publishDatabasePreferencesChangedNotification];
}



- (void)publishDatabasePreferencesChangedNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationDatabasePreferenceChanged object:self userInfo:@{ }];
    });
}

- (void)publishDatabaseUpdateStatusChangedNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationDatabaseUpdateStatusChanged object:self userInfo:@{ }];
    });
}



- (NSArray<Node *> *)entriesWithTag:(NSString *)tag {
    return [self.innerModel entriesWithTag:tag];
}

- (NSArray<Node *> *)search:(NSString *)searchText
                      scope:(SearchScope)scope
                dereference:(BOOL)dereference
      includeKeePass1Backup:(BOOL)includeKeePass1Backup
          includeRecycleBin:(BOOL)includeRecycleBin
             includeExpired:(BOOL)includeExpired
              includeGroups:(BOOL)includeGroups
            browseSortField:(BrowseSortField)browseSortField
                 descending:(BOOL)descending
          foldersSeparately:(BOOL)foldersSeparately {
    return [self.innerModel search:searchText
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

- (NSArray<Node *> *)filterAndSortForBrowse:(NSMutableArray<Node *> *)nodes
                      includeKeePass1Backup:(BOOL)includeKeePass1Backup
                          includeRecycleBin:(BOOL)includeRecycleBin
                             includeExpired:(BOOL)includeExpired
                              includeGroups:(BOOL)includeGroups
                            browseSortField:(BrowseSortField)browseSortField
                                 descending:(BOOL)descending
                          foldersSeparately:(BOOL)foldersSeparately {
    return [self.innerModel filterAndSortForBrowse:nodes
                             includeKeePass1Backup:includeKeePass1Backup
                                 includeRecycleBin:includeRecycleBin
                                    includeExpired:includeExpired
                                     includeGroups:includeGroups
                                   browseSortField:browseSortField
                                        descending:descending
                                 foldersSeparately:foldersSeparately];
}

- (NSComparisonResult)compareNodesForSort:(Node *)node1
                                    node2:(Node *)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately {
    return [self.innerModel compareNodesForSort:node1 node2:node2 field:field descending:descending foldersSeparately:foldersSeparately];
}




- (OGNavigationContext)nextGenNavigationContext {
    return self.databaseMetadata.sideBarNavigationContext;
}

- (NSUUID *)nextGenNavigationContextSideBarSelectedGroup {
    return self.databaseMetadata.sideBarSelectedGroup;
}

- (NSString *)nextGenNavigationContextSelectedTag {
    return self.databaseMetadata.sideBarSelectedTag;
}

- (OGNavigationSpecial)nextGenNavigationContextSpecial {
    return self.databaseMetadata.sideBarSelectedSpecial;
}

- (OGNavigationAuditCategory)nextGenNavigationContextAuditCategory {
    return self.databaseMetadata.sideBarSelectedAuditCategory;
}

- (NSUUID *)nextGenNavigationSelectedFavouriteId {
    return self.databaseMetadata.sideBarSelectedFavouriteId;
}

- (NSArray<NSUUID *> *)nextGenSelectedItems {
    return self.databaseMetadata.browseSelectedItems;
}

- (void)setNextGenNavigationNone {
    if ( self.nextGenNavigationContext != OGNavigationContextNone ||
        self.databaseMetadata.searchText.length ) {
        self.databaseMetadata.searchText = @""; 
        self.databaseMetadata.sideBarNavigationContext = OGNavigationContextNone;
        
        
        
        [self publishNextGenNavigationContextChanged];
    }
}

- (void)setNextGenNavigation:(OGNavigationContext)context selectedGroup:(NSUUID *)selectedGroup {
    if ( self.nextGenNavigationContext != context ||
        ![self.nextGenNavigationContextSideBarSelectedGroup isEqualTo:selectedGroup] ||
        self.databaseMetadata.searchText.length ) {
        self.databaseMetadata.searchText = @""; 
        self.databaseMetadata.sideBarNavigationContext = context;
        self.databaseMetadata.sideBarSelectedGroup = selectedGroup;
        
        
        
        [self publishNextGenNavigationContextChanged];
    }
    else {
        
    }
}

- (void)setNextGenNavigation:(OGNavigationContext)context tag:(NSString *)tag {
    if ( self.nextGenNavigationContext != context ||
        ![self.nextGenNavigationContextSelectedTag isEqualToString:tag] ||
        self.databaseMetadata.searchText.length ) {
        self.databaseMetadata.searchText = @""; 
        self.databaseMetadata.sideBarNavigationContext = context;
        self.databaseMetadata.sideBarSelectedTag = tag;
        
        
        
        [self publishNextGenNavigationContextChanged];
    }
    else {
        
    }
}

- (void)setNextGenNavigation:(OGNavigationContext)context special:(OGNavigationSpecial)special {
    if ( self.nextGenNavigationContext != context ||
        self.nextGenNavigationContextSpecial != special ||
        self.databaseMetadata.searchText.length ) {
        self.databaseMetadata.searchText = @""; 
        self.databaseMetadata.sideBarNavigationContext = context;
        self.databaseMetadata.sideBarSelectedSpecial = special;
        [self publishNextGenNavigationContextChanged];
    }
    else {
        
    }
}

- (void)setNextGenNavigationToAuditIssues:(OGNavigationAuditCategory)category {
    if ( self.nextGenNavigationContext != OGNavigationContextAuditIssues ||
        self.nextGenNavigationContextAuditCategory != category ||
        self.databaseMetadata.searchText.length ) {
        self.databaseMetadata.searchText = @""; 
        self.databaseMetadata.sideBarNavigationContext = OGNavigationContextAuditIssues;
        self.databaseMetadata.sideBarSelectedAuditCategory = category;
        [self publishNextGenNavigationContextChanged];
    }
    else {
        
    }
}

- (void)setNextGenNavigationFavourite:(NSUUID *)nodeId {
    if ( self.nextGenNavigationContext != OGNavigationContextFavourites ||
        ![self.nextGenNavigationSelectedFavouriteId isEqual:nodeId] ||
        self.databaseMetadata.searchText.length ) {
        self.databaseMetadata.searchText = @""; 
        self.databaseMetadata.sideBarNavigationContext = OGNavigationContextFavourites;
        self.databaseMetadata.sideBarSelectedFavouriteId = nodeId;
        
        [self publishNextGenNavigationContextChanged];
    }
    else {
        
    }
}

- (void)setNextGenSelectedItems:(NSArray<NSUUID *> *)nextGenMasterSelectedItems {
    
    
    NSSet<NSUUID*>* newSelected = nextGenMasterSelectedItems ? [NSSet setWithArray:nextGenMasterSelectedItems] : NSSet.set;
    NSSet<NSUUID*>* oldSelected = [NSSet setWithArray:self.nextGenSelectedItems];
    
    if ( ![newSelected isEqualToSet:oldSelected]) {
        self.databaseMetadata.browseSelectedItems = newSelected.allObjects;
        [self publishNextGenSelectedItemsChanged];
    }
    else {
        
    }
}

- (void)publishNextGenSelectedItemsChanged {

    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationNextGenSelectedItemsChanged object:self userInfo:nil];
    });
}

- (void)publishNextGenNavigationContextChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationNextGenNavigationChanged object:self userInfo:nil];
    });
}



- (NSString *)nextGenSearchText {
    return self.databaseMetadata.searchText;
}

- (void)setNextGenSearchText:(NSString *)nextGenSearchText {
    if ( ![self.nextGenSearchText isEqual:nextGenSearchText] ) {
        self.databaseMetadata.searchText = nextGenSearchText;
        [self publishNextGenSearchContextChanged];
    }
}

- (SearchScope)nextGenSearchScope {
    return self.databaseMetadata.searchScope;
}

- (void)setNextGenSearchScope:(SearchScope)nextGenSearchScope {
    if ( self.nextGenSearchScope != nextGenSearchScope ) {
        self.databaseMetadata.searchScope = nextGenSearchScope;
        [self publishNextGenSearchContextChanged];
    }
}

- (BOOL)nextGenSearchIncludeGroups {
    return self.databaseMetadata.searchIncludeGroups;
}

- (void)setNextGenSearchIncludeGroups:(BOOL)nextGenSearchIncludeGroups {
    if ( self.nextGenSearchIncludeGroups != nextGenSearchIncludeGroups ) {
        self.databaseMetadata.searchIncludeGroups = nextGenSearchIncludeGroups;
        [self publishNextGenSearchContextChanged];
    }
}

- (void)publishNextGenSearchContextChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationNextGenSearchContextChanged object:self userInfo:nil];
    });
}



- (NSArray<HeaderNodeState *> *)headerNodes {
    return self.databaseMetadata.headerNodes;
}

- (void)setHeaderNodes:(NSArray<HeaderNodeState *> *)headerNodes {
    self.databaseMetadata.headerNodes = headerNodes;
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)customSortOrderForFields {
    return self.databaseMetadata.customSortOrderForFields;
}

- (void)setCustomSortOrderForFields:(BOOL)customSortOrderForFields {
    self.databaseMetadata.customSortOrderForFields = customSortOrderForFields;
}

- (BOOL)sortKeePassNodes {
    return !self.databaseMetadata.uiDoNotSortKeePassNodesInBrowseView;
}

- (void)setSortKeePassNodes:(BOOL)sortKeePassNodes {
    self.databaseMetadata.uiDoNotSortKeePassNodesInBrowseView = !sortKeePassNodes;
}

- (ConflictResolutionStrategy)conflictResolutionStrategy {
    return self.databaseMetadata.conflictResolutionStrategy;
}

- (void)setConflictResolutionStrategy:(ConflictResolutionStrategy)conflictResolutionStrategy {
    self.databaseMetadata.conflictResolutionStrategy = conflictResolutionStrategy;
}

- (BOOL)formatSupportsCustomIcons {
    return self.innerModel.formatSupportsCustomIcons;
}



- (void)rebuildMapsAndCaches { 
    [self.innerModel rebuildFastMaps];
    
    [self cacheKeeAgentPublicKeysOffline];
}

- (void)cacheKeeAgentPublicKeysOffline {
    if ( !Settings.sharedInstance.runSshAgent ) {
        
        return;
    }
    
    NSSet<NSData*>* pkBlobs = [self.keeAgentSshKeyEntries map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NSData* pkData = obj.keeAgentEnabledSshPrivateKeyData;
        if ( pkData ) {
            OpenSSHPrivateKey* theKey = [OpenSSHPrivateKey fromData:pkData];
            if ( theKey ) {
                return theKey.publicKeySerializationBlob;
            }
        }
        
        return nil;
    }].set;
    
    [SSHAgentRequestHandler.shared updateOffilnePublicKeysForDatabaseWithPublicKeyBlobs:pkBlobs.allObjects
                                                                           databaseUuid:self.databaseUuid];
}

@end
