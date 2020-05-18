
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
NSString* const kNotificationUserInfoKeyIsBatchIconUpdate = @"kNotificationUserInfoKeyIsBatchIconUpdate";

NSString* const kNotificationUserInfoKeyNode = @"node";

@interface ViewModel ()

// This is the initial load of an existing db uses encryptedDatabase. A new Database uses passwordDatabase
// It will be decrypted and released on unlock. A lock discards the database and a full revert is required to unlock
// again (loading the file from the original location)

@property (strong, nonatomic) DatabaseModel* passwordDatabase;

@end

@implementation ViewModel

- (instancetype)initLocked:(Document *)document {
    return [self initUnlockedWithDatabase:document database:nil selectedItem:nil];
}

- (instancetype)initUnlockedWithDatabase:(Document *)document
                                database:(DatabaseModel*)database
                            selectedItem:(NSString*)selectedItem {
    if (self = [super init]) {
        _document = document;
        self.passwordDatabase = database;
        self.selectedItem = selectedItem;
        
        if(self.document.fileURL) { // When we create a new database this can be null... 
            _databaseMetadata = [DatabasesManager.sharedInstance addOrGet:self.document.fileURL];
            
            if(self.databaseMetadata == nil) {
                NSLog(@"WARN: Could not add or get metadata for [%@]", document.fileURL);
            }
        }
    }
    
    return self;
}

- (BOOL)locked {
    return self.passwordDatabase == nil;
}

- (void)lock:(NSString*)selectedItem {
    if(self.document.isDocumentEdited) {
        NSLog(@"Cannot lock document with edits!");
        return;
    }
    // Clear the UNDO stack otherwise the operations will fail
    
    [self.document.undoManager removeAllActions];
    self.passwordDatabase = nil;
    self.selectedItem = selectedItem;
}

- (void)reloadAndUnlock:(CompositeKeyFactors *)compositeKeyFactors
             completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self.document revertWithUnlock:compositeKeyFactors
                       selectedItem:self.selectedItem
                         completion:completion]; // Full Reload from Disk to get latest version
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<DatabaseAttachment *> *)attachments {
    return self.passwordDatabase.attachments;
}

- (DatabaseFormat)format {
    return self.passwordDatabase.format;
}

-(id<AbstractDatabaseMetadata>)metadata {
    return self.passwordDatabase.metadata;
}

- (NSDictionary<NSUUID *,NSData *> *)customIcons {
    return self.passwordDatabase.customIcons;
}

- (NSArray<Node*>*)activeRecords {
    return self.passwordDatabase.activeRecords;
}

- (NSString *)getGroupPathDisplayString:(Node *)node {
    return [self.passwordDatabase getGroupPathDisplayString:node];
}

- (NSArray<Node*>*)activeGroups {
    return self.passwordDatabase.activeGroups;
}

-(Node*)rootGroup {
    return self.passwordDatabase.rootGroup;
}

- (BOOL)masterCredentialsSet {
    if(!self.locked) {
        return !(self.passwordDatabase.compositeKeyFactors.password == nil &&
                 self.passwordDatabase.compositeKeyFactors.keyFileDigest == nil &&
                 self.passwordDatabase.compositeKeyFactors.yubiKeyCR == nil);
    }
    
    return NO;
}

- (void)getPasswordDatabaseAsData:(SaveCompletionBlock)completion {
    if (self.locked) {
        NSLog(@"Attempt to get safe data while locked?");
        completion(NO, nil, nil);
    }
    
    [self.passwordDatabase getAsData:completion];
}

- (NSURL*)fileUrl {
    return [self.document fileURL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isDereferenceableText:(NSString *)text {
    return [self.passwordDatabase isDereferenceableText:text];
}

- (NSString *)dereference:(NSString *)text node:(Node *)node {
    return [self.passwordDatabase dereference:text node:node];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(CompositeKeyFactors *)compositeKeyFactors {
    return self.locked ? nil : self.passwordDatabase.compositeKeyFactors;
}

- (void)setCompositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    CompositeKeyFactors* original = [self.passwordDatabase.compositeKeyFactors clone];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setCompositeKeyFactors:original];
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_change_master_credentials", @"Change Master Credentials");
    [self.document.undoManager setActionName:loc];
    
    self.passwordDatabase.compositeKeyFactors.password = compositeKeyFactors.password;
    self.passwordDatabase.compositeKeyFactors.keyFileDigest = compositeKeyFactors.keyFileDigest;
    self.passwordDatabase.compositeKeyFactors.yubiKeyCR = compositeKeyFactors.yubiKeyCR;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setItemIcon:(Node *)item index:(NSNumber*)index existingCustom:(NSUUID*)existingCustom custom:(NSData*)custom {
    [self setItemIcon:item index:index existingCustom:existingCustom custom:custom rationalize:NO batchUpdate:NO];
}

- (void)setItemIcon:(Node *)item
              index:(NSNumber*)index
     existingCustom:(NSUUID*)existingCustom
             custom:(NSData*)custom
        rationalize:(BOOL)rationalize
        batchUpdate:(BOOL)batchUpdate {
    [self setItemIcon:item
                index:index
       existingCustom:existingCustom
               custom:custom
             modified:nil
          rationalize:rationalize
          batchUpdate:batchUpdate];
}

- (void)batchSetIcons:(NSDictionary<NSUUID *,NSImage *>*)iconMap {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.document.undoManager beginUndoGrouping];
            
    for (Node* item in self.rootGroup.allChildRecords) {
        NSImage* selectedImage = iconMap[item.uuid];
        if(selectedImage) {
            [self setItemIcon:item customImage:selectedImage rationalize:NO batchUpdate:YES];
        }
    }

    NSString* loc = NSLocalizedString(@"mac_undo_action_set_icons", @"Set Icon(s)");

    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
        [item touchWithExplicitModifiedDate:modDate touchParents:YES];
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

- (void)setItemIcon:(Node *)item customImage:(NSImage *)customImage {
    [self setItemIcon:item customImage:customImage rationalize:NO batchUpdate:NO];
}

- (void)setItemIcon:(Node *)item customImage:(NSImage *)customImage rationalize:(BOOL)rationalize batchUpdate:(BOOL)batchUpdate {
    CGImageRef cgRef = [customImage CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    NSData *selectedImageData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{ }];
    
    [self setItemIcon:item index:nil existingCustom:nil custom:selectedImageData modified:nil rationalize:rationalize batchUpdate:batchUpdate];
}

- (void)setItemIcon:(Node *)item
              index:(NSNumber*)index
     existingCustom:(NSUUID*)existingCustom
             custom:(NSData*)custom
           modified:(NSDate*)modified
        rationalize:(BOOL)rationalize
        batchUpdate:(BOOL)batchUpdate  {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSNumber *oldIndex = item.iconId;
    NSData* oldCustom = nil;
    if(item.customIconUuid) {
        oldCustom = self.passwordDatabase.customIcons[item.customIconUuid];
    }
    NSDate* oldModified = item.fields.modified;
    
    if(index != nil && index.intValue == -1) {
        index = item.isGroup ? @(48) : @(0);
    }
    
    // Manage History
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }

    // Change...
    
    item.iconId = index;
    if(existingCustom) {
        item.customIconUuid = existingCustom;
    }
    else {
        [self.passwordDatabase setNodeCustomIcon:item data:custom rationalize:rationalize];
    }
    
    [self touchAndModify:item modDate:modified];
    
    // Save data rather than existing custom icon here, as custom icon could be rationalized away, holding data guarantees we can undo...
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemIcon:item
                                                                        index:oldIndex
                                                               existingCustom:nil
                                                                       custom:oldCustom
                                                                     modified:oldModified
                                                                  rationalize:NO
                                                                  batchUpdate:batchUpdate];
    
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
        index = [item.fields.keePassHistory indexOfObject:historicalItem]; // removeObjectAtIndex:index];
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
    
    // Record History
    
    [item.fields.keePassHistory addObject:originalNode];
    
    // Make Changes
    
    item.fields.accessed = [[NSDate alloc] init];
    item.fields.modified = [[NSDate alloc] init];
    
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

- (void)removeItemAttachment:(Node *)item atIndex:(NSUInteger)atIndex {
    [self removeItemAttachment:item atIndex:atIndex modified:nil];
}

- (void)removeItemAttachment:(Node *)item atIndex:(NSUInteger)atIndex modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
 
    NodeFileAttachment* nodeAttachment = item.fields.attachments[atIndex];
    DatabaseAttachment* dbAttachment = self.passwordDatabase.attachments[nodeAttachment.index];
    UiAttachment* old = [[UiAttachment alloc] initWithFilename:nodeAttachment.filename data:dbAttachment.data];
    NSDate* oldModified = item.fields.modified;

    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [[self.document.undoManager prepareWithInvocationTarget:self] addItemAttachment:item attachment:old modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_remove_attachment", @"Remove Attachment");
        [self.document.undoManager setActionName:loc];
    }

    [self.passwordDatabase removeNodeAttachment:item atIndex:atIndex];
    
    [self touchAndModify:item modDate:modified];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationAttachmentsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment {
    [self addItemAttachment:item attachment:attachment modified:nil];
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment modified:(NSDate*)modified {
    [self addItemAttachment:item attachment:attachment rationalize:YES modified:modified];
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment rationalize:(BOOL)rationalize {
    [self addItemAttachment:item attachment:attachment rationalize:rationalize modified:nil];
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment rationalize:(BOOL)rationalize modified:(NSDate*)modified {
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

    [self.passwordDatabase addNodeAttachment:item attachment:attachment rationalize:rationalize];
    
    [self touchAndModify:item modDate:modified];
    
    // To Undo we need to find this attachment's index!
    
    int i=0;
    NSUInteger foundIndex = -1;
    for (NodeFileAttachment* nodeAttachment in item.fields.attachments) {
        if([nodeAttachment.filename isEqualToString:attachment.filename]) {
            DatabaseAttachment* dbAttachment = self.passwordDatabase.attachments[nodeAttachment.index];
            if([dbAttachment.data isEqualToData:attachment.data]) {
                foundIndex = i;
                break;
            }
        }
        i++;
    }
    
    if(foundIndex == -1) {
        NSLog(@"WARN: Could not find added Attachment index!");
        // Something very wrong...
        return;
    }
    
    NSLog(@"found attachment added at: %lu", (unsigned long)foundIndex);
    
    [[self.document.undoManager prepareWithInvocationTarget:self] removeItemAttachment:item atIndex:foundIndex modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_add_attachment", @"Add Attachment");
        [self.document.undoManager setActionName:loc];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationAttachmentsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setCustomField:(Node *)item key:(NSString *)key value:(StringValue *)value {
    [self setCustomField:item key:key value:value modified:nil];
}

- (void)setCustomField:(Node *)item key:(NSString *)key value:(StringValue *)value modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    StringValue* oldValue = [item.fields.customFields objectForKey:key];
    NSDate* oldModified = item.fields.modified;

    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [item.fields setCustomField:key value:value];
    
    [self touchAndModify:item modDate:modified];
    
    if(oldValue) {
        [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue modified:oldModified];
        
        NSString* loc = NSLocalizedString(@"mac_undo_action_set_custom_field", @"Set Custom Field");
        [self.document.undoManager setActionName:loc];
    }
    else {
        [[self.document.undoManager prepareWithInvocationTarget:self] removeCustomField:item key:key modified:oldModified];
        NSString* loc = NSLocalizedString(@"mac_undo_action_add_custom_field", @"Add Custom Field");
        [self.document.undoManager setActionName:loc];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationCustomFieldsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)removeCustomField:(Node *)item key:(NSString *)key {
    [self removeCustomField:item key:key modified:nil];
}

- (void)removeCustomField:(Node *)item key:(NSString *)key modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    StringValue* oldValue = item.fields.customFields[key];
    NSDate* oldModified = item.fields.modified;

    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }

    [item.fields removeCustomField:key];
    
    [self touchAndModify:item modDate:modified];

    [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_remove_custom_field", @"Remove Custom Field");
        [self.document.undoManager setActionName:loc];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationCustomFieldsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
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
                 forceSteam:steam];
    
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
    if(oldOtpToken == nil) { // NOP
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

- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    for (Node* child in children) {
        if(![parent validateAddChild:child keePassGroupTitleRules:YES]) {
            return NO;
        }
    }
    
    [self.document.undoManager beginUndoGrouping];
    
    for (Node* child in children) {
        [self addItem:child parent:parent newItemCreated:NO];
    }
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_add_items", @"Add Items");
    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];

    return YES;
}

- (NSString*)getDefaultTitle {
    return NSLocalizedString(@"item_details_vc_new_item_title", @"Untitled");
}

- (BOOL)addNewRecord:(Node *_Nonnull)parentGroup {
    AutoFillNewRecordSettings *autoFill = Settings.sharedInstance.autoFillNewRecordSettings;
    
    // Title
    
    NSString *actualTitle = autoFill.titleAutoFillMode == kDefault ? [self getDefaultTitle] :
            autoFill.titleAutoFillMode == kSmartUrlFill ? [self getSmartFillTitle] : autoFill.titleCustomAutoFill;
    
    // Username
    
    NSString *actualUsername = autoFill.usernameAutoFillMode == kNone ? @"" :
            autoFill.usernameAutoFillMode == kMostUsed ? [self getAutoFillMostPopularUsername] : autoFill.usernameCustomAutoFill;
    
    // Password
    
    NSString *actualPassword = autoFill.passwordAutoFillMode == kNone ? @"" : autoFill.passwordAutoFillMode == kGenerated ? [self generatePassword] : autoFill.passwordCustomAutoFill;
    
    // Email
    
    NSString *actualEmail = autoFill.emailAutoFillMode == kNone ? @"" :
            autoFill.emailAutoFillMode == kMostUsed ? [self getAutoFillMostPopularEmail] : autoFill.emailCustomAutoFill;
    
    // URL
    
    NSString *actualUrl = autoFill.urlAutoFillMode == kNone ? @"" :
        autoFill.urlAutoFillMode == kSmartUrlFill ? getSmartFillUrl(): autoFill.urlCustomAutoFill;
    
    // Notes

    NSString *actualNotes = autoFill.notesAutoFillMode == kNone ? @"" :
        autoFill.notesAutoFillMode == kClipboard ? getSmartFillNotes() : autoFill.notesCustomAutoFill;
    
    /////////////////////////////////////
    
    NodeFields* fields = [[NodeFields alloc] initWithUsername:actualUsername
                                                          url:actualUrl
                                                     password:actualPassword
                                                        notes:actualNotes
                                                        email:actualEmail];

    Node* record = [[Node alloc] initAsRecord:actualTitle parent:parentGroup fields:fields uuid:nil];
    
    if(![parentGroup validateAddChild:record keePassGroupTitleRules:YES]) {
        return NO;
    }
    
    [self addItem:record parent:parentGroup newItemCreated:YES];
    
    return YES;
}

- (void)addNewGroup:(Node *)parentGroup title:(NSString *)title {
    NSInteger i = 0;
    BOOL success = NO;
    Node* newGroup;
    do {
        newGroup = [[Node alloc] initAsGroup:title parent:parentGroup keePassGroupTitleRules:self.format != kPasswordSafe uuid:nil];
        success =  newGroup && [parentGroup validateAddChild:newGroup keePassGroupTitleRules:self.format != kPasswordSafe];
        i++;
        title = [NSString stringWithFormat:@"%@ %ld", title, i];
    } while (!success);
    
    [self addItem:newGroup parent:parentGroup newItemCreated:NO];
}

- (void)addItem:(Node*)item parent:(Node*)parent newItemCreated:(BOOL)newItemCreated {
    [parent addChild:item keePassGroupTitleRules:YES];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteItem:item];
    if(!self.document.undoManager.isUndoing) {
        NSString* loc = NSLocalizedString(@"mac_undo_action_add_item", @"Add Item");
        [self.document.undoManager setActionName:loc];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onNewItemAdded(item, newItemCreated);
    });
}

- (BOOL)deleteItem:(Node *_Nonnull)child {
    BOOL wasRecycled;
    BOOL ret = [self.passwordDatabase deleteOrRecycleItem:child wasRecycled:&wasRecycled];

    if (wasRecycled) {
            // Needs to be undoable
        //    [self changeParent:self.passwordDatabase.recycleBinNode node:child isRecycleOp:YES];

        // TODO: How to properly undo this?!
    }
    else {
        // TODO: How to properly undo this?!
        
        [[self.document.undoManager prepareWithInvocationTarget:self] unDeleteItem:child];
        if(!self.document.undoManager.isUndoing) {
            NSString* loc = NSLocalizedString(@"mac_undo_action_delete_item", @"Delete Item");
            [self.document.undoManager setActionName:loc];
        }
    }

    if (ret) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onDeleteItem(child);
        });
    }
    
    return ret;
}

- (BOOL)unDeleteItem:(Node *)item {
    // TODO: Need to notify UI
    
    return [self.passwordDatabase unDeleteItem:item];
}

- (BOOL)deleteWillRecycle:(Node *)child {
    return [self.passwordDatabase deleteWillRecycle:child];
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [self changeParent:parent node:node isRecycleOp:NO];
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node isRecycleOp:(BOOL)isRecycleOp {
    if(![node validateChangeParent:parent keePassGroupTitleRules:self.format != kPasswordSafe]) {
        return NO;
    }

    Node* old = node.parent;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] changeParent:old node:node isRecycleOp:isRecycleOp];
    
    NSString* loc = isRecycleOp ?
        NSLocalizedString(@"mac_undo_action_delete_item", @"Delete Item") :
        NSLocalizedString(@"mac_undo_action_move_item", @"Move Item");

    [self.document.undoManager setActionName:loc];
    
    BOOL ret = [node changeParent:parent keePassGroupTitleRules:self.format != kPasswordSafe];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.onChangeParent(node);
    });
    
    return ret;
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
        
        
        Node* record = [[Node alloc] initAsRecord:actualTitle parent:self.passwordDatabase.rootGroup fields:fields uuid:nil];
        
        NSDate* date = [NSDate date];
        record.fields.created = date;
        record.fields.accessed = date;
        record.fields.modified = date;
        
        [self addItem:record parent:self.passwordDatabase.rootGroup newItemCreated:NO];
    }
    
    NSString* loc = NSLocalizedString(@"mac_undo_action_import_entries_from_csv", @"Import Entries from CSV");

    [self.document.undoManager setActionName:loc];
    [self.document.undoManager endUndoGrouping];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [node validateChangeParent:parent keePassGroupTitleRules:self.format != kPasswordSafe];
}

- (NSString*)getSmartFillTitle {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        // h/t: https://stackoverflow.com/questions/3811996/how-to-determine-if-a-string-is-a-url-in-objective-c
        
        NSURL *url = [NSURL URLWithString:clipboardText];
        
        if (url && url.scheme && url.host)
        {
            return url.host;
        }
    }
    
    return [self getDefaultTitle];
}

NSString* getSmartFillUrl() {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        NSURL *url = [NSURL URLWithString:clipboardText];
        if (url && url.scheme && url.host)
        {
            return clipboardText;
        }
    }
    
    return @"";
}

NSString* getSmartFillNotes() {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        return clipboardText;
    }
    
    return @"";
}

-(NSString*) getAutoFillMostPopularUsername {
    return self.passwordDatabase.mostPopularUsername == nil ? @"" : self.passwordDatabase.mostPopularUsername;
}

-(NSString*) getAutoFillMostPopularEmail {
    return self.passwordDatabase.mostPopularEmail == nil ? @"" : self.passwordDatabase.mostPopularEmail;
}

- (Node*)getItemFromSerializationId:(NSString*)serializationId {
    if(!serializationId) {
        return nil;
    }
    
    return [self.rootGroup findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [node getSerializationId:self.format != kPasswordSafe];
        return [sid isEqualToString:serializationId];
    }];
}

- (NSString*)generatePassword {
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:Settings.sharedInstance.passwordGenerationConfig];
}

- (NSSet<NSString*> *)emailSet {
    return self.passwordDatabase.emailSet;
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
    return [self.passwordDatabase isTitleMatches:searchText node:node dereference:dereference];
}

- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isUsernameMatches:searchText node:node dereference:dereference];
}

- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isPasswordMatches:searchText node:node dereference:dereference];
}

- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isUrlMatches:searchText node:node dereference:dereference];
}

- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    return [self.passwordDatabase isAllFieldsMatches:searchText node:node dereference:dereference];
}

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText {
    return [self.passwordDatabase getSearchTerms:searchText];
}

- (NSString *)getHtmlPrintString:(NSString*)databaseName {
    return [self.passwordDatabase getHtmlPrintString:databaseName];
}

- (void)setDatabaseMetadata:(DatabaseMetadata *)databaseMetadata {
    _databaseMetadata = databaseMetadata;
}

@end
