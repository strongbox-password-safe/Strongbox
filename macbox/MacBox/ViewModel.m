
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
#import "PasswordGenerator.h"
#import "Settings.h"
#import "Node+OtpToken.h"
#import "OTPToken+Serialization.h"

NSString* const kModelUpdateNotificationCustomFieldsChanged = @"kModelUpdateNotificationCustomFieldsChanged";
NSString* const kModelUpdateNotificationPasswordChanged = @"kModelUpdateNotificationPasswordChanged";
NSString* const kModelUpdateNotificationTitleChanged = @"kModelUpdateNotificationTitleChanged";
NSString* const kModelUpdateNotificationUsernameChanged = @"kModelUpdateNotificationUsernameChanged";
NSString* const kModelUpdateNotificationEmailChanged = @"kModelUpdateNotificationEmailChanged";
NSString* const kModelUpdateNotificationUrlChanged = @"kModelUpdateNotificationUrlChanged";
NSString* const kModelUpdateNotificationNotesChanged = @"kModelUpdateNotificationNotesChanged";
NSString* const kModelUpdateNotificationIconChanged = @"kModelUpdateNotificationIconChanged";
NSString* const kModelUpdateNotificationAttachmentsChanged = @"kModelUpdateNotificationAttachmentsChanged";
NSString* const kModelUpdateNotificationTotpChanged = @"kModelUpdateNotificationTotpChanged";

NSString* const kNotificationUserInfoKeyNode = @"node";
static NSString* const kDefaultNewTitle = @"Untitled";

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

- (instancetype)initUnlockedWithDatabase:(Document *)document database:(DatabaseModel*)database selectedItem:(NSString*)selectedItem {
    if (self = [super init]) {
        _document = document;
        self.passwordDatabase = database;
        self.selectedItem = selectedItem;
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

- (void)reloadAndUnlock:(NSString*)password
 keyFileDigest:(NSData*)keyFileDigest
    completion:(void (^)(BOOL success, NSError* error))completion {
    [self.document revertWithUnlock:password
                      keyFileDigest:keyFileDigest
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
        return !(self.passwordDatabase.masterPassword == nil && self.passwordDatabase.keyFileDigest == nil);
    }
    
    return NO;
}

- (NSData*)getPasswordDatabaseAsData:(NSError**)error {
    if (self.locked) {
        NSLog(@"Attempt to get safe data while locked?");
        return nil;
    }
    
    return [self.passwordDatabase getAsData:error];
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

-(NSString*)masterPassword {
    return self.locked ? nil : self.passwordDatabase.masterPassword;
}

-(NSData *)masterKeyFileDigest {
    return self.locked ? nil : self.passwordDatabase.keyFileDigest;
}

- (void)setMasterCredentials:(NSString *)masterPassword masterKeyFileDigest:(NSData *)masterKeyFileDigest {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSString* original = self.passwordDatabase.masterPassword;
    NSData* originalKey = self.passwordDatabase.keyFileDigest;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setMasterCredentials:original masterKeyFileDigest:originalKey];
    [self.document.undoManager setActionName:@"Change Master Credentials"];
    
    [self.passwordDatabase setMasterPassword:masterPassword];
    [self.passwordDatabase setKeyFileDigest:masterKeyFileDigest];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title
{
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

- (void)setItemIcon:(Node *)item index:(NSNumber*)index existingCustom:(NSUUID*)existingCustom custom:(NSData*)custom {
    [self setItemIcon:item index:index existingCustom:existingCustom custom:custom modified:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSString* old = item.title;
    NSDate* oldModified = item.fields.modified;
    
    Node* cloneForHistory = [item cloneForHistory];
    if([item setTitle:title allowDuplicateGroupTitles:self.format != kPasswordSafe]) {
        item.fields.modified = modified ? modified : [[NSDate alloc] init];
        
        if(self.document.undoManager.isUndoing) {
            if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
        }
        else {
            [item.fields.keePassHistory addObject:cloneForHistory];
        }
        
        [[self.document.undoManager prepareWithInvocationTarget:self] setItemTitle:item title:old modified:oldModified];
        [self.document.undoManager setActionName:@"Title Change"];
        
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
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemEmail:item email:old modified:oldModified];
    [self.document.undoManager setActionName:@"Email Change"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationEmailChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
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
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemUsername:item username:old modified:oldModified];
    [self.document.undoManager setActionName:@"Username Change"];
    
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
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemUrl:item url:old modified:oldModified];
    [self.document.undoManager setActionName:@"URL Change"];
    
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
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    item.fields.passwordModified = item.fields.modified;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemPassword:item password:old modified:oldModified];
    [self.document.undoManager setActionName:@"Password Change"];
    
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
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemNotes:item notes:old modified:oldModified];
    [self.document.undoManager setActionName:@"Notes Change"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationNotesChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setItemIcon:(Node *)item index:(NSNumber*)index existingCustom:(NSUUID*)existingCustom custom:(NSData*)custom modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSNumber *oldIndex = item.iconId;
    NSData* oldCustom = nil;
    if(item.customIconUuid) {
        oldCustom = self.passwordDatabase.customIcons[item.customIconUuid];
    }
    NSDate* oldModified = item.fields.modified;
    
    if(index && index.intValue == -1) {
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
        [self.passwordDatabase setNodeCustomIcon:item data:custom];
    }
    
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    // Save data rather than existing custom icon here, as custom icon could be rationalized away, holding data guarantees we can undo...
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemIcon:item index:oldIndex existingCustom:nil custom:oldCustom modified:oldModified];
    [self.document.undoManager setActionName:@"Icon Change"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationIconChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
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
    
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
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
    
    [self.document.undoManager setActionName:@"Delete History Item"];
    
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

    item.fields.modified = modified ? modified : [[NSDate alloc] init];

    // Record History
    
    [item.fields.keePassHistory addObject:originalNode];
    
    // Make Changes
    
    item.fields.accessed = [[NSDate alloc] init];
    item.fields.modified = [[NSDate alloc] init];
    
    // TODO: This should be a function on Node - copyFromNode(Node* node) or something - also find it iOS app...
    
    [item setTitle:historicalItem.title allowDuplicateGroupTitles:YES];
    item.iconId = historicalItem.iconId;
    item.customIconUuid = historicalItem.customIconUuid;
    
    item.fields.username = historicalItem.fields.username;
    item.fields.url = historicalItem.fields.url;
    item.fields.password = historicalItem.fields.password;
    item.fields.notes = historicalItem.fields.notes;
    item.fields.passwordModified = historicalItem.fields.passwordModified;
    item.fields.attachments = [historicalItem.fields cloneAttachments];
    item.fields.customFields = [historicalItem.fields cloneCustomFields];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] restoreHistoryItem:item
                                                                      historicalItem:originalNode
                                                                            modified:oldModified];
    
    [self.document.undoManager setActionName:@"Restore History Item"];
    
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
        [self.document.undoManager setActionName:@"Remove Attachment"];
    }

    [self.passwordDatabase removeNodeAttachment:item atIndex:atIndex];
    item.fields.modified = modified ? modified : [[NSDate alloc] init];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationAttachmentsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment {
    [self addItemAttachment:item attachment:attachment modified:nil];
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment modified:(NSDate*)modified {
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

    [self.passwordDatabase addNodeAttachment:item attachment:attachment];
    item.fields.modified = modified ? modified : [[NSDate alloc] init];

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
        [self.document.undoManager setActionName:@"Add Attachment"];
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
    
    [item.fields.customFields setObject:value forKey:key];
    item.fields.modified = modified ? modified : [[NSDate alloc] init];

    if(oldValue) {
        [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue modified:oldModified];
        [self.document.undoManager setActionName:@"Set Custom Field"];
    }
    else {
        [[self.document.undoManager prepareWithInvocationTarget:self] removeCustomField:item key:key modified:oldModified];
        [self.document.undoManager setActionName:@"Add Custom Field"];
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

    [item.fields.customFields removeObjectForKey:key];
    item.fields.modified = modified ? modified : [[NSDate alloc] init];

    [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue modified:oldModified];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Remove Custom Field"];
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
    
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    [item setTotpWithString:otp
           appendUrlToNotes:self.format == kPasswordSafe || self.format == kKeePass1
                 forceSteam:steam];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] clearTotp:item];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Set TOTP"];
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
    
    OTPToken* oldOtpToken = item.otpToken;
    if(oldOtpToken == nil) { // NOP
        NSLog(@"Attempt to clear non existent OTP token");
        return;
    }
    
    NSURL* oldOtpTokenUrl = [oldOtpToken url:YES];
    Node* cloneForHistory = [item cloneForHistory];
    [item.fields.keePassHistory addObject:cloneForHistory];
    
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    [item clearTotp];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setTotp:item otp:oldOtpTokenUrl.absoluteString steam:oldOtpToken.algorithm == OTPAlgorithmSteam];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Clear TOTP"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationTotpChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (BOOL)addNewRecord:(Node *_Nonnull)parentGroup {
    AutoFillNewRecordSettings *autoFill = Settings.sharedInstance.autoFillNewRecordSettings;
    
    // Title
    
    NSString *actualTitle = autoFill.titleAutoFillMode == kDefault ? kDefaultNewTitle :
            autoFill.titleAutoFillMode == kSmartUrlFill ? getSmartFillTitle() : autoFill.titleCustomAutoFill;
    
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
    
    if(![parentGroup validateAddChild:record allowDuplicateGroupTitles:YES]) {
        return NO;
    }
    
    [self addItem:record parent:parentGroup newRecord:YES];
    
    return YES;
}

- (void)addNewGroup:(Node *)parentGroup title:(NSString *)title {
    NSInteger i = 0;
    BOOL success = NO;
    Node* newGroup;
    do {
        newGroup = [[Node alloc] initAsGroup:title parent:parentGroup allowDuplicateGroupTitles:self.format != kPasswordSafe uuid:nil];
        success =  newGroup && [parentGroup validateAddChild:newGroup allowDuplicateGroupTitles:self.format != kPasswordSafe];
        i++;
        title = [NSString stringWithFormat:@"%@ %ld", title, i];
    } while (!success);
    
    [self addItem:newGroup parent:parentGroup newRecord:NO];
}

- (void)addItem:(Node*)item parent:(Node*)parent newRecord:(BOOL)newRecord {
    [parent addChild:item allowDuplicateGroupTitles:YES];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteItem:item];
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Add Item"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onNewItemAdded(item, newRecord);
    });
}

- (BOOL)deleteItem:(Node *_Nonnull)child {
    if([self deleteWillRecycle:child]) {
        // UUID is NIL/Non Existent or Zero? - Create
        if(self.passwordDatabase.recycleBinNode == nil) {
            [self.passwordDatabase createNewRecycleBinNode];
        }

        return [self changeParent:self.passwordDatabase.recycleBinNode node:child isRecycleOp:YES];
    }
    else {
        [child.parent removeChild:child];
        
        [[self.document.undoManager prepareWithInvocationTarget:self] addItem:child parent:child.parent newRecord:NO];
        if(!self.document.undoManager.isUndoing) {
            [self.document.undoManager setActionName:@"Delete Item"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.onDeleteItem(child);
        });
    }
    
    return YES;
}

- (BOOL)deleteWillRecycle:(Node *)child {
    BOOL willRecycle = self.passwordDatabase.recycleBinEnabled;
    if(self.passwordDatabase.recycleBinEnabled && self.passwordDatabase.recycleBinNode) {
        if([self.passwordDatabase.recycleBinNode contains:child] || self.passwordDatabase.recycleBinNode == child) {
            willRecycle = NO;
        }
    }
    
    return willRecycle;
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [self changeParent:parent node:node isRecycleOp:NO];
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node isRecycleOp:(BOOL)isRecycleOp {
    if(![node validateChangeParent:parent allowDuplicateGroupTitles:self.format != kPasswordSafe]) {
        return NO;
    }

    Node* old = node.parent;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] changeParent:old node:node isRecycleOp:isRecycleOp];
    [self.document.undoManager setActionName:isRecycleOp ? @"Delete Item" : @"Move Item"];
    
    BOOL ret = [node changeParent:parent allowDuplicateGroupTitles:self.format != kPasswordSafe];

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
        
        [self addItem:record parent:self.passwordDatabase.rootGroup newRecord:NO];
    }
    
    [self.document.undoManager setActionName:@"Import Entries from CSV"];
    [self.document.undoManager endUndoGrouping];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [node validateChangeParent:parent allowDuplicateGroupTitles:self.format != kPasswordSafe];
}

NSString* getSmartFillTitle() {
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
    
    return kDefaultNewTitle;
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
    PasswordGenerationParameters *params = [[Settings sharedInstance] passwordGenerationParameters];
    
    return [PasswordGenerator generatePassword:params];
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

@end
