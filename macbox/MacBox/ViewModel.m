    
//
//  ViewModel.m
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewModel.h"
#import "Csv.h"
#import "DatabaseModel.h"
#import "PasswordMaker.h"
#import "Settings.h"
#import "OTPToken+Serialization.h"
#import "FavIconManager.h"
#import "DatabasesManager.h"
#import "NSArray+Extensions.h"
#import "NSString+Extensions.h"
#import "AutoFillManager.h"
#import "Serializator.h"
#import "Utils.h"
#import "Document.h"

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

NSString* const kModelUpdateNotificationDatabasePreferenceChanged = @"kModelUpdateNotificationDatabasePreferenceChanged";

NSString* const kNotificationUserInfoKeyIsBatchIconUpdate = @"kNotificationUserInfoKeyIsBatchIconUpdate";
NSString* const kNotificationUserInfoKeyNode = @"node";

@interface ViewModel ()

@property (nullable) DatabaseModel* passwordDatabase;
@property (nullable) NSUUID* internalSelectedItem;

@end

@implementation ViewModel

- (instancetype)initLocked:(NSDocument *)document
                  metadata:(DatabaseMetadata *)metadata {
    return [self initUnlockedWithDatabase:document
                                 metadata:metadata
                                database:nil];
}

- (instancetype)initUnlockedWithDatabase:(NSDocument *)document
                                metadata:(DatabaseMetadata *)metadata
                                database:(DatabaseModel *)database {
    if (self = [super init]) {
        _document = document;
        self.passwordDatabase = database;
    }
    
    return self;
}

- (BOOL)locked {
    return self.passwordDatabase == nil;
}






- (NSString *)databaseUuid {
    return self.databaseMetadata.uuid;
}

- (DatabaseMetadata *)databaseMetadata {
    Document* doc = (Document*)self.document;
    return doc.databaseMetadata;
}

- (void)updateDatabaseMetadata:(void (^)(DatabaseMetadata * _Nonnull metadata))touch {
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseUuid
                                            touch:touch];
}



- (BOOL)isEffectivelyReadOnly {
    return self.readOnly || self.offlineMode;
}

- (DatabaseModel *)database {
    return self.passwordDatabase;
}

- (DatabaseFormat)format {
    return self.passwordDatabase.originalFormat;
}

- (UnifiedDatabaseMetadata*)metadata {
    return self.passwordDatabase.meta;
}

- (NSSet<NodeIcon*>*)customIcons {
    return self.passwordDatabase.iconPool.allValues.set;
}

- (NSArray<Node*>*)activeRecords {
    return self.passwordDatabase.allActiveEntries;
}

- (NSString *)getGroupPathDisplayString:(Node *)node {
    return [self.passwordDatabase getPathDisplayString:node includeRootGroup:YES rootGroupNameInsteadOfSlash:NO includeFolderEmoji:NO joinedBy:@"/"];
}

- (NSArray<Node*>*)activeGroups {
    return self.passwordDatabase.allActiveGroups;
}

-(Node*)rootGroup {
    return self.passwordDatabase.effectiveRootGroup;
}

- (BOOL)masterCredentialsSet {
    if(!self.locked) {
        return !(self.passwordDatabase.ckfs.password == nil &&
                 self.passwordDatabase.ckfs.keyFileDigest == nil &&
                 self.passwordDatabase.ckfs.yubiKeyCR == nil);
    }
    
    return NO;
}

- (void)getPasswordDatabaseAsData:(void (^)(BOOL userCancelled, NSData *data, NSError *error))completion {
    if (self.locked) {
        NSLog(@"Attempt to get safe data while locked?");
        completion(NO, nil, nil);
    }
    
    NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory]; 
    [outputStream open];
    
    [Serializator getAsData:self.passwordDatabase format:self.passwordDatabase.originalFormat outputStream:outputStream completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
        [outputStream close];
                
        if ( !userCancelled && !error ) {
            NSData* data = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
            completion(userCancelled, data, error);
        }
        else {
            completion(userCancelled, nil, error);
        }
    }];
}

- (NSURL*)fileUrl {
    return [self.document fileURL];
}



- (BOOL)isDereferenceableText:(NSString *)text {
    return [self.passwordDatabase isDereferenceableText:text];
}

- (NSString *)dereference:(NSString *)text node:(Node *)node {
    return [self.passwordDatabase dereference:text node:node];
}



-(CompositeKeyFactors *)compositeKeyFactors {
    return self.locked ? nil : self.passwordDatabase.ckfs;
}

- (void)setCompositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    CompositeKeyFactors* original = [self.passwordDatabase.ckfs clone];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setCompositeKeyFactors:original];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_change_master_credentials", @"Change Master Credentials");
    [self.document.undoManager setActionName:loc];
    
    self.passwordDatabase.ckfs = compositeKeyFactors;
}



- (BOOL)recycleBinEnabled {
    return self.passwordDatabase.recycleBinEnabled;
}

- (Node *)recycleBinNode {
    return self.passwordDatabase.recycleBinNode;
}

- (void)createNewRecycleBinNode {
    [self createNewRecycleBinNode];
}

- (Node *)keePass1BackupNode {
    return self.passwordDatabase.keePass1BackupNode;
}



- (NSUUID *)selectedItem {
    return self.internalSelectedItem;
}

- (void)setSelectedItem:(NSUUID *)selectedItem {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
        
    self.internalSelectedItem = selectedItem;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationSelectedItemChanged object:self userInfo:@{ }];
    });
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

    NSString* old = item.title;
    NSDate* oldModified = item.fields.modified;
    
    Node* cloneForHistory = [item cloneForHistory];
    if([item setTitle:title keePassGroupTitleRules:self.format != kPasswordSafe]) {
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationUsernameChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemUrl:(Node*_Nonnull)item url:(NSString*_Nonnull)url modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationUrlChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemPassword:(Node*_Nonnull)item password:(NSString*_Nonnull)password modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSString* old = item.fields.password;
    NSDate* oldModified = item.fields.modified;

    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }

    item.fields.password = password;
    [self touchAndModify:item modDate:modified];
    item.fields.passwordModified = item.fields.modified;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemPassword:item password:old modified:oldModified];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_password_change", @"Password Change");
    [self.document.undoManager setActionName:loc];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationPasswordChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemNotes:(Node*)item notes:(NSString*)notes modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationNotesChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemExpires:(Node*)item expiry:(NSDate*)expiry modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationExpiryChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}





- (void)batchSetIcons:(NSDictionary<NSUUID *,NSImage *>*)iconMap {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationIconChanged
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyNode : item,
                                                                    kNotificationUserInfoKeyIsBatchIconUpdate : @(batchUpdate)}];
    });
}



- (void)deleteHistoryItem:(Node *)item historicalItem:(Node *)historicalItem {
    [self deleteHistoryItem:item historicalItem:historicalItem index:-1 modified:nil];
}

- (void)deleteHistoryItem:(Node *)item historicalItem:(Node *)historicalItem index:(NSUInteger)index modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
        self.onDeleteHistoryItem(item, historicalItem);
    });
}

- (void)restoreHistoryItem:(Node *)item historicalItem:(Node *)historicalItem {
    [self restoreHistoryItem:item historicalItem:historicalItem modified:nil];
}

- (void)restoreHistoryItem:(Node *)item historicalItem:(Node *)historicalItem modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
        self.onRestoreHistoryItem(item, historicalItem);
    });
}

- (void)removeItemAttachment:(Node *)item filename:(NSString *)filename {
    [self removeItemAttachment:item filename:filename modified:nil];
}

- (void)removeItemAttachment:(Node *)item filename:(NSString *)filename modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    DatabaseAttachment* oldDbAttachment = item.fields.attachments[filename];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationAttachmentsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)addItemAttachment:(Node *)item filename:(NSString *)filename attachment:(DatabaseAttachment *)attachment {
    [self addItemAttachment:item filename:filename attachment:attachment modified:nil];
}

- (void)addItemAttachment:(Node *)item filename:(NSString *)filename attachment:(DatabaseAttachment *)attachment modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
    
    Node* cloneForHistory = [item cloneForHistory];
    [item.fields.keePassHistory addObject:cloneForHistory];
    
    [self touchAndModify:item modDate:modified];
    
    [item setTotpWithString:otp
           appendUrlToNotes:self.format == kPasswordSafe || self.format == kKeePass1
                 forceSteam:steam
            addLegacyFields:NO
              addOtpAuthUrl:YES]; 
    
    [[self.document.undoManager prepareWithInvocationTarget:self] clearTotp:item];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_set_totp", @"Set TOTP");
        [self.document.undoManager setActionName:loc];
    }
    
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTotpChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)addItemTag:(Node *)item tag:(NSString *)tag {
    [self addItemTag:item tag:tag modified:nil];
}

- (void)removeItemTag:(Node *)item tag:(NSString *)tag {
    [self removeItemTag:item tag:tag modified:nil];
}

- (void)addItemTag:(Node *)item tag:(NSString *)tag modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    if ( [item.fields.tags containsObject:tag] ) {
        return;
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTagsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)removeItemTag:(Node *)item tag:(NSString *)tag modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    if ( ![item.fields.tags containsObject:tag] ) {
        return;
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTagsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (NSString*)getDefaultTitle {
    return NSLocalizedString(@"item_details_vc_new_item_title", @"Untitled");
}

- (NSSet<Node *> *)getMinimalNodeSet:(const NSArray<Node *> *)nodes {
    return [self.passwordDatabase getMinimalNodeSet:nodes];
}




- (BOOL)addNewRecord:(Node *_Nonnull)parentGroup {
    Node* record = [self getDefaultNewEntryNode:parentGroup];
    return [self addItem:record parent:parentGroup openEntryDetailsWindowWhenDone:YES];
}

- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString *)title {
    if ( !parentGroup ) {
        return NO;
    }
    
    Node* newGroup = [self getNewGroupWithSafeName:parentGroup title:title];
    return [self addItem:newGroup parent:parentGroup openEntryDetailsWindowWhenDone:NO];
}

- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent {
    for (Node* child in children) {
        if ( ![self.passwordDatabase validateAddChild:child destination:parent] ) {
            return NO;
        }
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for (Node* child in children) {
        [self addItem:child parent:parent openEntryDetailsWindowWhenDone:NO];
    }
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_add_items", @"Add Items");
    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];

    return YES;
}

- (BOOL)addItem:(Node*)item parent:(Node*)parent openEntryDetailsWindowWhenDone:(BOOL)openEntryDetailsWindowWhenDone {
    if (![self.passwordDatabase addChild:item destination:parent]) {
        return NO;
    }
    
    [[self.document.undoManager prepareWithInvocationTarget:self] unAddItem:item];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_add_item", @"Add Item");
    [self.document.undoManager setActionName:loc];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onNewItemAdded(item, openEntryDetailsWindowWhenDone);
    });
    
    return YES;
}

- (void)unAddItem:(Node*)item {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    [self.passwordDatabase removeChildFromParent:item];

    [[self.document.undoManager prepareWithInvocationTarget:self] addItem:item parent:item.parent openEntryDetailsWindowWhenDone:NO];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_add_item", @"Add Item");
    [self.document.undoManager setActionName:loc];

    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsDeleted
                                                      object:self
                                                    userInfo:@{ kNotificationUserInfoKeyNode : @[item] }];
}

- (BOOL)canRecycle:(Node *)item {
    return [self.passwordDatabase canRecycle:item.uuid];
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSArray<NodeHierarchyReconstructionData*>* undoData;
    [self.passwordDatabase deleteItems:items undoData:&undoData];

    [[self.document.undoManager prepareWithInvocationTarget:self] unDeleteItems:undoData];
    
    NSString* loc = items.count > 1 ?   NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
                                        NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");

    [self.document.undoManager setActionName:loc];

    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsDeleted
                                                      object:self
                                                    userInfo:@{ kNotificationUserInfoKeyNode : items }];
}

- (void)unDeleteItems:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase unDelete:undoData];
    
    NSArray<Node*>* items = [undoData map:^id _Nonnull(NodeHierarchyReconstructionData * _Nonnull obj, NSUInteger idx) {
        return obj.clonedNode;
    }];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteItems:items];
    
    NSString* loc = items.count > 1 ? NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
                                      NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");

    [self.document.undoManager setActionName:loc];

    [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsUnDeleted
                                                      object:self
                                                    userInfo:nil];
}



- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSArray<NodeHierarchyReconstructionData*> *undoData;
    BOOL ret = [self.passwordDatabase recycleItems:items undoData:&undoData];

    [[self.document.undoManager prepareWithInvocationTarget:self] unRecycleItems:undoData];
    
    NSString* loc = items.count > 1 ?   NSLocalizedString(@"mac_menu_item_delete_items", "Delete Items") :
                                        NSLocalizedString(@"mac_menu_item_delete_item", "Delete Item");
    [self.document.undoManager setActionName:loc];

    if (ret) {
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsDeleted
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyNode : items }];
    }

    return ret;
}

- (void)unRecycleItems:(NSArray<NodeHierarchyReconstructionData*>*)undoData {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase undoRecycle:undoData];
    
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
}




- (BOOL)validateMove:(const NSArray<Node *> *)items destination:(Node*)destination {
    return [self.passwordDatabase validateMoveItems:items destination:destination];
}

- (BOOL)move:(const NSArray<Node *> *)items destination:(Node*)destination {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSArray<NodeHierarchyReconstructionData*> *undoData;
    BOOL ret = [self.passwordDatabase moveItems:items destination:destination undoData:&undoData];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] unMove:undoData destination:destination];
    
    NSString* loc = items.count > 1 ? NSLocalizedString(@"mac_undo_action_move_items", @"Move Items") :
                                      NSLocalizedString(@"mac_undo_action_move_item", @"Move Item");
    
    [self.document.undoManager setActionName:loc];

    if (ret) {
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationItemsMoved
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoKeyNode : items }];
    }

    return ret;
}

- (void)unMove:(NSArray<NodeHierarchyReconstructionData*>*)undoData destination:(Node*)destination {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase undoMove:undoData];
    
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
}

- (void)importRecordsFromCsvRows:(NSArray<CHCSVOrderedDictionary*>*)rows {
    [self.document.undoManager beginUndoGrouping];
    
    for (CHCSVOrderedDictionary* row  in rows) {
        NSString* actualTitle = [row objectForKey:kCSVHeaderTitle];
        NSString* actualUsername = [row objectForKey:kCSVHeaderUsername];
        NSString* actualUrl = [row objectForKey:kCSVHeaderUrl];
        NSString* actualEmail = [row objectForKey:kCSVHeaderEmail];
        NSString* actualPassword = [row objectForKey:kCSVHeaderPassword];
        NSString* actualNotes = [row objectForKey:kCSVHeaderNotes];
        
        actualTitle = actualTitle ? actualTitle : @"Unknown Title (Imported)";
        actualUsername = actualUsername ? actualUsername : @"";
        actualUrl = actualUrl ? actualUrl : @"";
        actualEmail = actualEmail ? actualEmail : @"";
        actualPassword = actualPassword ? actualPassword : @"";
        actualNotes = actualNotes ? actualNotes : @"";
        
        NodeFields* fields = [[NodeFields alloc] initWithUsername:actualUsername
                                                              url:actualUrl
                                                         password:actualPassword
                                                            notes:actualNotes
                                                            email:actualEmail];
        
        
        Node* record = [[Node alloc] initAsRecord:actualTitle parent:self.passwordDatabase.effectiveRootGroup fields:fields uuid:nil];
        [self addItem:record parent:self.passwordDatabase.effectiveRootGroup openEntryDetailsWindowWhenDone:NO];
    }
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_import_entries_from_csv", @"Import Entries from CSV");

    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];
}



- (void)launchUrl:(Node*)item {
    NSURL* launchableUrl = [self.database launchableUrlForItem:item];
        
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
}


- (Node*)getDefaultNewEntryNode:(Node *_Nonnull)parentGroup {
    AutoFillNewRecordSettings *autoFill = Settings.sharedInstance.autoFillNewRecordSettings;
    
    
    
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
    return self.passwordDatabase.mostPopularUsername == nil ? @"" : self.passwordDatabase.mostPopularUsername;
}

- (NSString*)getAutoFillMostPopularEmail {
    return self.passwordDatabase.mostPopularEmail == nil ? @"" : self.passwordDatabase.mostPopularEmail;
}

- (Node*)getItemFromSerializationId:(NSString*)serializationId {
    return [self.passwordDatabase getItemByCrossSerializationFriendlyId:serializationId];
}

- (NSString*)generatePassword {
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:Settings.sharedInstance.passwordGenerationConfig];
}

- (NSSet<NSString*> *)emailSet {
    return self.passwordDatabase.emailSet;
}

- (NSSet<NSString *> *)tagSet {
    return self.passwordDatabase.tagSet;
}

- (NSSet<NSString*> *)urlSet {
    return self.passwordDatabase.urlSet;
}

- (NSSet<NSString*> *)usernameSet {
    return self.passwordDatabase.usernameSet;
}

- (NSSet<NSString*> *)passwordSet {
    return self.passwordDatabase.passwordSet;
}

- (NSString *)mostPopularUsername {
    return self.passwordDatabase.mostPopularUsername;
}

- (NSString *)mostPopularPassword {
    return self.passwordDatabase.mostPopularPassword;
}

- (NSInteger)numberOfRecords {
    return self.passwordDatabase.numberOfRecords;
}

- (NSInteger)numberOfGroups {
    return self.passwordDatabase.numberOfGroups;
}

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isTitleMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isUsernameMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isPasswordMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isUrlMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isAllFieldsMatches:searchText node:node dereference:dereference checkPinYin:NO];
}

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText {
    return [self.passwordDatabase getSearchTerms:searchText];
}

- (NSString *)getHtmlPrintString:(NSString*)databaseName {
    return [self.passwordDatabase getHtmlPrintString:databaseName];
}



- (BOOL)showTotp {
    return !self.databaseMetadata.doNotShowTotp;
}

- (void)setShowTotp:(BOOL)showTotp {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowTotp = !showTotp;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showAutoCompleteSuggestions {
    return !self.databaseMetadata.doNotShowAutoCompleteSuggestions;
}

- (void)setShowAutoCompleteSuggestions:(BOOL)showAutoCompleteSuggestions {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowAutoCompleteSuggestions = !showAutoCompleteSuggestions;
    }];
}

- (BOOL)showChangeNotifications {
    return !self.databaseMetadata.doNotShowChangeNotifications;
}

- (void)setShowChangeNotifications:(BOOL)showChangeNotifications {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowChangeNotifications = !showChangeNotifications;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)concealEmptyProtectedFields {
    return self.databaseMetadata.concealEmptyProtectedFields;
}

- (void)setConcealEmptyProtectedFields:(BOOL)concealEmptyProtectedFields {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.concealEmptyProtectedFields = concealEmptyProtectedFields;
    }];
}

- (BOOL)lockOnScreenLock {
    return self.databaseMetadata.lockOnScreenLock;
}

- (void)setLockOnScreenLock:(BOOL)lockOnScreenLock {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.lockOnScreenLock = lockOnScreenLock;
    }];
}

- (BOOL)autoPromptForConvenienceUnlockOnActivate {
    return self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate;
}

- (void)setAutoPromptForConvenienceUnlockOnActivate:(BOOL)autoPromptForConvenienceUnlockOnActivate {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoPromptForConvenienceUnlockOnActivate = autoPromptForConvenienceUnlockOnActivate;
    }];
}

- (BOOL)showAdvancedUnlockOptions {
    return self.databaseMetadata.showAdvancedUnlockOptions;
}

- (void)setShowAdvancedUnlockOptions:(BOOL)showAdvancedUnlockOptions {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showAdvancedUnlockOptions = showAdvancedUnlockOptions;
    }];
}

- (BOOL)showQuickView {
    return self.databaseMetadata.showQuickView;
}

- (void)setShowQuickView:(BOOL)showQuickView {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showQuickView = showQuickView;
    }];
}

- (BOOL)showAlternatingRows {
    return !self.databaseMetadata.noAlternatingRows;
}

- (void)setShowAlternatingRows:(BOOL)showAlternatingRows {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.noAlternatingRows = !showAlternatingRows;
    }];

    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showVerticalGrid {
    return self.databaseMetadata.showVerticalGrid;
}

- (void)setShowVerticalGrid:(BOOL)showVerticalGrid {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showVerticalGrid = showVerticalGrid;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)showHorizontalGrid {
    return self.databaseMetadata.showHorizontalGrid;
}

- (void)setShowHorizontalGrid:(BOOL)showHorizontalGrid {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showHorizontalGrid = showHorizontalGrid;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (NSArray *)visibleColumns {
    return self.databaseMetadata.visibleColumns;
}

- (void)setVisibleColumns:(NSArray *)visibleColumns {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.visibleColumns = visibleColumns;
    }];
}

- (BOOL)downloadFavIconOnChange {
    return self.databaseMetadata.expressDownloadFavIconOnNewOrUrlChanged;
}

- (void)setDownloadFavIconOnChange:(BOOL)downloadFavIconOnChange {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.expressDownloadFavIconOnNewOrUrlChanged = downloadFavIconOnChange;
    }];
}

- (BOOL)startWithSearch {
    return self.databaseMetadata.startWithSearch;
}

- (void)setStartWithSearch:(BOOL)startWithSearch {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.startWithSearch = startWithSearch;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)outlineViewTitleIsReadonly {
    return self.databaseMetadata.outlineViewTitleIsReadonly;
}

- (void)setOutlineViewTitleIsReadonly:(BOOL)outlineViewTitleIsReadonly {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.outlineViewTitleIsReadonly = outlineViewTitleIsReadonly;
    }];
}

- (BOOL)outlineViewEditableFieldsAreReadonly {
    return self.databaseMetadata.outlineViewEditableFieldsAreReadonly;
}

- (void)setOutlineViewEditableFieldsAreReadonly:(BOOL)outlineViewEditableFieldsAreReadonly {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.outlineViewEditableFieldsAreReadonly = outlineViewEditableFieldsAreReadonly;
    }];
}

- (BOOL)showRecycleBinInSearchResults {
    return self.databaseMetadata.showRecycleBinInSearchResults;
}

- (void)setShowRecycleBinInSearchResults:(BOOL)showRecycleBinInSearchResults {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.showRecycleBinInSearchResults = showRecycleBinInSearchResults;
    }];
}

- (BOOL)sortKeePassNodes {
    return !self.databaseMetadata.uiDoNotSortKeePassNodesInBrowseView;
}

- (void)setSortKeePassNodes:(BOOL)sortKeePassNodes {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.uiDoNotSortKeePassNodesInBrowseView = !sortKeePassNodes;
    }];
}

- (BOOL)showRecycleBinInBrowse {
    return !self.databaseMetadata.doNotShowRecycleBinInBrowse;
}

- (void)setShowRecycleBinInBrowse:(BOOL)showRecycleBinInBrowse {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.doNotShowRecycleBinInBrowse = !showRecycleBinInBrowse;
    }];
}

- (BOOL)monitorForExternalChanges {
    return self.databaseMetadata.monitorForExternalChanges;

}

- (void)setMonitorForExternalChanges:(BOOL)monitorForExternalChanges {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.monitorForExternalChanges = monitorForExternalChanges;
    }];
}

- (NSInteger)monitorForExternalChangesInterval {
    return self.databaseMetadata.monitorForExternalChangesInterval;
}

- (void)setMonitorForExternalChangesInterval:(NSInteger)monitorForExternalChangesInterval {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.monitorForExternalChangesInterval = monitorForExternalChangesInterval;
    }];
}

- (BOOL)autoReloadAfterExternalChanges {
    return self.databaseMetadata.autoReloadAfterExternalChanges;
}

- (void)setAutoReloadAfterExternalChanges:(BOOL)autoReloadAfterExternalChanges {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoReloadAfterExternalChanges = autoReloadAfterExternalChanges;
    }];
}

- (BOOL)launchAtStartup {
    return self.databaseMetadata.launchAtStartup;

}

- (void)setLaunchAtStartup:(BOOL)launchAtStartup {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.launchAtStartup = launchAtStartup;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)alwaysOpenOffline {
    return self.databaseMetadata.alwaysOpenOffline;

}

- (void)setAlwaysOpenOffline:(BOOL)alwaysOpenOffline {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.alwaysOpenOffline = alwaysOpenOffline;
    }];
}

- (BOOL)readOnly {
    return self.databaseMetadata.readOnly;
}

- (void)setReadOnly:(BOOL)readOnly {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.readOnly = readOnly;
    }];
    
    [self publishDatabasePreferencesChangedNotification];
}

- (BOOL)offlineMode {
    return self.databaseMetadata.offlineMode;
}

- (void)setOfflineMode:(BOOL)offlineMode {
    [self updateDatabaseMetadata:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.offlineMode = offlineMode;
    }];

    [self publishDatabasePreferencesChangedNotification];
}

- (void)publishDatabasePreferencesChangedNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationDatabasePreferenceChanged object:self userInfo:@{ }];
    });
}

@end
