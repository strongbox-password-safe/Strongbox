
//
//  ViewModel.m
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewModel.h"
#import "LockedSafeInfo.h"
#import "Utils.h"
#import "DatabaseModel.h"
#import "PasswordGenerator.h"
#import "Settings.h"

#define kNewUntitledGroupTitleBase @"New Untitled Group"

@interface ViewModel ()

@property (strong, nonatomic) DatabaseModel* passwordDatabase;
@property (strong, nonatomic) LockedSafeInfo* lockedSafeInfo;

@end

@implementation ViewModel

- (instancetype)initNewWithSampleData:(Document*)document; {
    if (self = [super init]) {
        self.passwordDatabase = [[DatabaseModel alloc] initNewWithoutPassword];
        self.lockedSafeInfo = nil;
        
        [self addSampleRecord:self.rootGroup];
        
        Node* newGroup = [[Node alloc] initAsGroup:kNewUntitledGroupTitleBase parent:self.rootGroup];

        [self.passwordDatabase.rootGroup addChild:newGroup];
        
        _document = document;
        
        return self;
    }
    
    return nil;
}

-(Node*)rootGroup {
    return self.passwordDatabase.rootGroup;
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
    
    self.lockedSafeInfo = [[LockedSafeInfo alloc] initWithEncryptedData:data selectedItem:selectedItem];
    self.passwordDatabase = nil;
    
    return YES;
}

- (BOOL)unlock:(NSString*)password selectedItem:(NSString**)selectedItem error:(NSError**)error {
    if(!self.locked) {
        return YES;
    }
    
    DatabaseModel *model = [[DatabaseModel alloc] initExistingWithDataAndPassword:self.lockedSafeInfo.encryptedData password:password error:error];
    *selectedItem = self.lockedSafeInfo.selectedItem;
    
    if(model != nil) {
        self.passwordDatabase = model;
        self.lockedSafeInfo = nil;
        return YES;
    }
    
    return NO;
}

-(NSString*)masterPassword {
    return self.locked ? nil : self.passwordDatabase.masterPassword;
}

- (void)setMasterPassword:(NSString *)masterPassword {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setMasterPassword:masterPassword];
    
    self.document.dirty = YES;
}

- (BOOL)masterPasswordIsSet {
    if(!self.locked) {
        return self.passwordDatabase.masterPassword != nil;
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

- (BOOL)dirty {
    return self.document.dirty;
}

- (Node*)addSampleRecord:(Node* _Nonnull)group {
    NSString* password = [self generatePassword];
    
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"user123"
                                              url:@"https://strongboxsafe.com"
                                         password:password
                                            notes:@""
                                            email:@"user@gmail.com"];
    
    Node* record = [[Node alloc] initAsRecord:@"New Untitled Record" parent:group fields:fields];
    
    NSDate* date = [NSDate date];
    record.fields.created = date;
    record.fields.accessed = date;
    record.fields.modified = date;
    
    if([group addChild:record]) {
        return record;
    }
    
    return nil;
}

- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    if([item setTitle:title]) {
        self.document.dirty = YES;
        return YES;
    }
    
    return NO;
}

- (void)setItemEmail:(Node*_Nonnull)item email:(NSString*_Nonnull)email {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    item.fields.email = email;
    self.document.dirty = YES;
}

- (void)setItemUsername:(Node*_Nonnull)item username:(NSString*_Nonnull)username {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    item.fields.username = username;
    self.document.dirty = YES;
}

- (void)setItemUrl:(Node*_Nonnull)item url:(NSString*_Nonnull)url {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    item.fields.url = url;
    self.document.dirty = YES;
}

- (void)setItemPassword:(Node*_Nonnull)item password:(NSString*_Nonnull)password
{
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    item.fields.password = password;
    self.document.dirty = YES;
}

- (void)setItemNotes:(Node*_Nullable)item notes:(NSString*_Nonnull)notes {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    item.fields.notes = notes;
    self.document.dirty = YES;
}

- (Node*)addNewRecord:(Node *_Nonnull)parentGroup {
    NSString *actualTitle = @"New Untitled Record";
    NSString *actualNotes = @"";
    NSString *actualUrl = @"";
    NSString *actualUsername = @"";
    NSString *actualEmail = @"";
    
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];

    if(clipboardText) {
        if(!Settings.sharedInstance.doNotAutoFillNotesFromClipboard) {
            actualNotes = clipboardText;
        }
        
        if(!Settings.sharedInstance.doNotAutoFillUrlFromClipboard) {
            // h/t: https://stackoverflow.com/questions/3811996/how-to-determine-if-a-string-is-a-url-in-objective-c
        
            NSURL *url = [NSURL URLWithString:clipboardText];
            if (url && url.scheme && url.host)
            {
                actualUrl = clipboardText;
                actualTitle = url.host;
            }
        }
    }
    
    if(!Settings.sharedInstance.doNotAutoFillFromMostPopularFields) {
        actualUsername = self.passwordDatabase.mostPopularUsername == nil ? @"" : self.passwordDatabase.mostPopularUsername;
        actualEmail = self.passwordDatabase.mostPopularEmail == nil ? @"" : self.passwordDatabase.mostPopularEmail;
    }
    
    NodeFields* fields = [[NodeFields alloc] initWithUsername:actualUsername
                                                          url:actualUrl
                                                     password:[self generatePassword]
                                                        notes:actualNotes
                                                        email:actualEmail];
    

    Node* record = [[Node alloc] initAsRecord:actualTitle parent:parentGroup fields:fields];
    
    NSDate* date = [NSDate date];
    record.fields.created = date;
    record.fields.accessed = date;
    record.fields.modified = date;
    
    [parentGroup addChild:record];
    
    self.document.dirty = YES;

    return record;
}

- (void)importRecordsFromCsvRows:(NSArray<CHCSVOrderedDictionary*>*)rows {
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
        
        
        Node* record = [[Node alloc] initAsRecord:actualTitle parent:self.passwordDatabase.rootGroup fields:fields];
        
        NSDate* date = [NSDate date];
        record.fields.created = date;
        record.fields.accessed = date;
        record.fields.modified = date;
        
        [self.passwordDatabase.rootGroup addChild:record];
    }
    
    self.document.dirty = YES;
}

- (Node*)addNewGroup:(Node *_Nonnull)parentGroup {
    NSString *newGroupName = kNewUntitledGroupTitleBase;
    
    NSInteger i = 0;
    BOOL success = NO;
    Node* newGroup;
    do {
        newGroup = [[Node alloc] initAsGroup:newGroupName parent:parentGroup];
        success =  newGroup && [parentGroup addChild:newGroup];
        i++;
        newGroupName = [NSString stringWithFormat:@"%@ %ld", kNewUntitledGroupTitleBase, i];
    }while (!success);
    
    self.document.dirty = YES;
    
    return newGroup;
}

- (void)deleteItem:(Node *_Nonnull)child {
    [child.parent removeChild:child];
    
    self.document.dirty = YES;
}

- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [node validateChangeParent:parent];
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    if(![node validateChangeParent:parent]) {
        return NO;
    }

    self.document.dirty = [node changeParent:parent];
    
    return self.document.dirty;
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

- (NSString*_Nonnull)getDiagnosticDumpString {
    return [self.passwordDatabase getDiagnosticDumpString:YES];
}

- (void)defaultLastUpdateFieldsToNow {
    [self.passwordDatabase defaultLastUpdateFieldsToNow];
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

- (NSInteger)keyStretchIterations {
    return self.passwordDatabase.keyStretchIterations;
}

- (NSString *)version {
    return self.passwordDatabase.version;
}

-(NSDate*)lastUpdateTime {
    return self.passwordDatabase.lastUpdateTime;
}

-(NSString*)lastUpdateUser {
    return self.passwordDatabase.lastUpdateUser;
}

-(NSString*)lastUpdateHost {
    return self.passwordDatabase.lastUpdateHost;
}

-(NSString*)lastUpdateApp {
    return self.passwordDatabase.lastUpdateApp;
}

@end
