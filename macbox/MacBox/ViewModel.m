
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

static NSString* kDefaultNewTitle = @"Untitled";

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
        if([DatabaseModel isAValidSafe:data]) {
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

- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSString* old = item.title;
    NSDate* oldModified = item.fields.modified;
    
    if([item setTitle:title]) {
        item.fields.modified = modified ? modified : [[NSDate alloc] init];
        
        [[self.document.undoManager prepareWithInvocationTarget:self] setItemTitle:item title:old modified:oldModified];
        [self.document.undoManager setActionName:@"Title Change"];

        [self notifyModelChanged];

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

    item.fields.email = email;
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemEmail:item email:old modified:oldModified];
    [self.document.undoManager setActionName:@"Email Change"];
    
    [self notifyModelChanged];
}

- (void)setItemUsername:(Node*_Nonnull)item username:(NSString*_Nonnull)username modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSString* old = item.fields.username;
    NSDate* oldModified = item.fields.modified;

    item.fields.username = username;
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemUsername:item username:old modified:oldModified];
    [self.document.undoManager setActionName:@"Username Change"];
    
    [self notifyModelChanged];
}

- (void)setItemUrl:(Node*_Nonnull)item url:(NSString*_Nonnull)url modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSString* old = item.fields.url;
    NSDate* oldModified = item.fields.modified;

    item.fields.url = url;
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemUrl:item url:old modified:oldModified];
    [self.document.undoManager setActionName:@"URL Change"];
    
    [self notifyModelChanged];
}

- (void)setItemPassword:(Node*_Nonnull)item password:(NSString*_Nonnull)password modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSString* old = item.fields.password;
    NSDate* oldModified = item.fields.modified;

    item.fields.password = password;
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemPassword:item password:old modified:oldModified];
    [self.document.undoManager setActionName:@"Password Change"];
    
    [self notifyModelChanged];
}

- (void)setItemNotes:(Node*)item notes:(NSString*)notes modified:(NSDate*)modified {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSString* old = item.fields.notes;
    NSDate* oldModified = item.fields.modified;

    item.fields.notes = notes;
    item.fields.modified = modified ? modified : [[NSDate alloc] init];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] setItemNotes:item notes:old modified:oldModified];
    [self.document.undoManager setActionName:@"Notes Change"];
    
    [self notifyModelChanged];
}

- (void)removeItemAttachment:(Node *)item atIndex:(NSUInteger)atIndex {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
 
    NodeFileAttachment* nodeAttachment = item.fields.attachments[atIndex];
    DatabaseAttachment* dbAttachment = self.passwordDatabase.attachments[nodeAttachment.index];
    UiAttachment* old = [[UiAttachment alloc] initWithFilename:nodeAttachment.filename data:dbAttachment.data];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] addItemAttachment:item attachment:old];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Remove Attachment"];
    }

    [self.passwordDatabase removeNodeAttachment:item atIndex:atIndex];

    [self notifyModelChanged];
}

- (void)addItemAttachment:(Node *)item attachment:(UiAttachment *)attachment {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
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
    
    [self notifyModelChanged];
}

- (void)setCustomField:(Node *)item key:(NSString *)key value:(NSString *)value {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    NSString* oldValue = [item.fields.customFields objectForKey:key];
    
    [item.fields.customFields setObject:value forKey:key];
    
    if(oldValue) {
        [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue];
        [self.document.undoManager setActionName:@"Set Custom Field"];
    }
    else {
        [[self.document.undoManager prepareWithInvocationTarget:self] removeCustomField:item key:key];
        [self.document.undoManager setActionName:@"Add Custom Field"];
    }
    
    [self notifyModelChanged];
}

- (void)removeCustomField:(Node *)item key:(NSString *)key {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }

    NSString* oldValue = [item.fields.customFields objectForKey:key];
    [item.fields.customFields removeObjectForKey:key];


    [[self.document.undoManager prepareWithInvocationTarget:self] setCustomField:item key:key value:oldValue];
    
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Remove Custom Field"];
    }
    
    [self notifyModelChanged];
}

- (Node*)addNewRecord:(Node *_Nonnull)parentGroup {
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
        return nil;
    }
    
    return [self addItem:record parent:parentGroup];
}

- (Node*)addNewGroup:(Node *_Nonnull)parentGroup {
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
    
    return [self addItem:newGroup parent:parentGroup];
}

- (Node*)addItem:(Node*)item parent:(Node*)parent {
    [parent addChild:item];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] deleteItem:item];
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Add Item"];
    }
    
    [self notifyModelChanged];
    return item;
}

- (void)deleteItem:(Node *_Nonnull)child {
    [child.parent removeChild:child];
    
    [[self.document.undoManager prepareWithInvocationTarget:self] addItem:child parent:child.parent];
    if(!self.document.undoManager.isUndoing) {
        [self.document.undoManager setActionName:@"Delete Item"];
    }

    [self notifyModelChanged];
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    if(![node validateChangeParent:parent]) {
        return NO;
    }

    Node* old = node.parent;
    
    [[self.document.undoManager prepareWithInvocationTarget:self] changeParent:old node:node];
    [self.document.undoManager setActionName:@"Move Item"];
    
    BOOL ret = [node changeParent:parent];

    [self notifyModelChanged];
    
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

- (void)notifyModelChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onModelChanged();
    });
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
