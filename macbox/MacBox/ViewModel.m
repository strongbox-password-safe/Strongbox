
//
//  ViewModel.m
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewModel.h"
#import "LockedSafeInfo.h"
#import "Csv.h"
#import "DatabaseModel.h"
#import "PasswordGenerator.h"
#import "Settings.h"
#import "Node+OtpToken.h"
#import "OTPToken+Serialization.h"

static NSString* kDefaultNewTitle = @"Untitled";

NSString* const kModelUpdateNotificationCustomFieldsChanged = @"kModelUpdateNotificationCustomFieldsChanged";
NSString* const kNotificationUserInfoKeyNode = @"node";

@interface ViewModel ()

@property (strong, nonatomic) DatabaseModel* passwordDatabase;
@property (strong, nonatomic) LockedSafeInfo* lockedSafeInfo;

@end

@implementation ViewModel

- (instancetype)initNewWithSampleData:(Document *)document format:(DatabaseFormat)format password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest {
    if (self = [super init]) {
        self.passwordDatabase = [[DatabaseModel alloc] initNewWithPassword:password keyFileDigest:keyFileDigest format:format];
        self.lockedSafeInfo = nil;
        
        _document = document;
        
        return self;
    }
    
    return nil;
}

- (instancetype)initWithData:(NSData*)data document:(Document*)document {
    if (self = [super init]) {
        NSError* error;
        if([DatabaseModel isAValidSafe:data error:&error]) {
            self.lockedSafeInfo = [[LockedSafeInfo alloc] initWithEncryptedData:data selectedItem:nil];
            _document = document;
            return self;
        }
    }
    
    return nil;
}

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

-(Node*)rootGroup {
    return self.passwordDatabase.rootGroup;
}

- (BOOL)locked {
    return self.lockedSafeInfo != nil;
}

- (BOOL)lock:(NSError**)error selectedItem:(NSString*)selectedItem {
    if(self.locked) {
        return YES;
    }
    
    NSData* data = [self.passwordDatabase getAsData:error];
    if(!data) {
        return NO;
    }
    
    // Clear the UNDO stack otherwise the operations will fail
    [self.document.undoManager removeAllActions];
    
    self.lockedSafeInfo = [[LockedSafeInfo alloc] initWithEncryptedData:data selectedItem:selectedItem];
    self.passwordDatabase = nil;
    
    return YES;
}

- (BOOL)unlock:(NSString*)password selectedItem:(NSString**)selectedItem error:(NSError**)error {
    return [self unlock:password keyFileDigest:nil selectedItem:selectedItem error:error];
}

- (BOOL)unlock:(NSString*)password keyFileDigest:(NSData*)keyFileDigest selectedItem:(NSString**)selectedItem error:(NSError**)error {
    if(!self.locked) {
        return YES;
    }
    
    DatabaseModel *model = [[DatabaseModel alloc] initExistingWithDataAndPassword:self.lockedSafeInfo.encryptedData password:password keyFileDigest:keyFileDigest error:error];
    *selectedItem = self.lockedSafeInfo.selectedItem;
    
    if(model != nil) {
        self.passwordDatabase = model;
        self.lockedSafeInfo = nil;
        return YES;
    }
    
    return NO;
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
    if([item setTitle:title]) {
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
            self.onItemTitleChanged(item);
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
        self.onItemEmailChanged(item);
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
        self.onItemUsernameChanged(item);
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
        self.onItemUrlChanged(item);
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
        self.onItemPasswordChanged(item);
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
        self.onItemNotesChanged(item);
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
        self.onItemIconChanged(item);
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
    
    item.title = historicalItem.title;
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
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
 
    NodeFileAttachment* nodeAttachment = item.fields.attachments[atIndex];
    DatabaseAttachment* dbAttachment = self.passwordDatabase.attachments[nodeAttachment.index];
    UiAttachment* old = [[UiAttachment alloc] initWithFilename:nodeAttachment.filename data:dbAttachment.data];
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [[self.document.undoManager prepareWithInvocationTarget:self] addItemAttachment:item attachment:old];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Remove Attachment"];
    }

    [self.passwordDatabase removeNodeAttachment:item atIndex:atIndex];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.onAttachmentsChanged(item);
    });
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment {
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
    
    [self.passwordDatabase addNodeAttachment:item attachment:attachment];

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
    
    [[self.document.undoManager prepareWithInvocationTarget:self] removeItemAttachment:item atIndex:foundIndex];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Add Attachment"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onAttachmentsChanged(item);
    });
}

- (void)setCustomField:(Node *)item key:(NSString *)key value:(StringValue *)value {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    StringValue* oldValue = [item.fields.customFields objectForKey:key];
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }
    
    [item.fields.customFields setObject:value forKey:key];
    
    if(oldValue) {
        [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue];
        [self.document.undoManager setActionName:@"Set Custom Field"];
    }
    else {
        [[self.document.undoManager prepareWithInvocationTarget:self] removeCustomField:item key:key];
        [self.document.undoManager setActionName:@"Add Custom Field"];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationCustomFieldsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)removeCustomField:(Node *)item key:(NSString *)key {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    StringValue* oldValue = item.fields.customFields[key];
    
    if(self.document.undoManager.isUndoing) {
        if(item.fields.keePassHistory.count > 0) [item.fields.keePassHistory removeLastObject];
    }
    else {
        Node* cloneForHistory = [item cloneForHistory];
        [item.fields.keePassHistory addObject:cloneForHistory];
    }

    [item.fields.customFields removeObjectForKey:key];

    [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Remove Custom Field"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationCustomFieldsChanged object:self userInfo:@{ kNotificationUserInfoKeyNode : item }];
    });
}

- (void)setTotp:(Node *)item otp:(NSString *)otp {
    [self setTotp:item otp:otp modified:nil];
}
- (void)setTotp:(Node *)item otp:(NSString *)otp modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    Node* cloneForHistory = [item cloneForHistory];
    [item.fields.keePassHistory addObject:cloneForHistory];
    
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    [item setTotpWithString:otp appendUrlToNotes:self.format == kPasswordSafe];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] clearTotp:item];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Set TOTP"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onSetItemTotp(item);
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
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setTotp:item otp:oldOtpTokenUrl.absoluteString];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Clear TOTP"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onClearItemTotp(item);
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
    
    NSDate* date = [NSDate date];
    record.fields.created = date;
    record.fields.accessed = date;
    record.fields.modified = date;
    
    if(![parentGroup validateAddChild:record]) {
        return NO;
    }
    
    [self addItem:record parent:parentGroup];
    
    return YES;
}

- (void)addNewGroup:(Node *_Nonnull)parentGroup {
    NSString *newGroupName = kDefaultNewTitle;
    
    NSInteger i = 0;
    BOOL success = NO;
    Node* newGroup;
    do {
        newGroup = [[Node alloc] initAsGroup:newGroupName parent:parentGroup uuid:nil];
        success =  newGroup && [parentGroup validateAddChild:newGroup];
        i++;
        newGroupName = [NSString stringWithFormat:@"%@ %ld", kDefaultNewTitle, i];
    }while (!success);
    
    [self addItem:newGroup parent:parentGroup];
}

- (void)addItem:(Node*)item parent:(Node*)parent {
    [parent addChild:item];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteItem:item];
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Add Item"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onNewItemAdded(item);
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
        
        [[self.document.undoManager prepareWithInvocationTarget:self] addItem:child parent:child.parent];
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
    if(![node validateChangeParent:parent]) {
        return NO;
    }

    Node* old = node.parent;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] changeParent:old node:node isRecycleOp:isRecycleOp];
    [self.document.undoManager setActionName:isRecycleOp ? @"Delete Item" : @"Move Item"];
    
    BOOL ret = [node changeParent:parent];

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
        
        [self addItem:record parent:self.passwordDatabase.rootGroup];
    }
    
    [self.document.undoManager setActionName:@"Import Entries from CSV"];
    [self.document.undoManager endUndoGrouping];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [node validateChangeParent:parent];
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
    return [self.rootGroup findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
        return [node.serializationId isEqualToString:serializationId];
    }];
}

- (NSString*)generatePassword {
    PasswordGenerationParameters *params = [[Settings sharedInstance] passwordGenerationParameters];
    
    return [PasswordGenerator generatePassword:params];
}

- (NSSet<NSString*> *)emailSet {
    return self.passwordDatabase.emailSet;
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

@end
