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

#define kNewUntitledGroupTitleBase @"New Untitled Group"

@interface ViewModel ()

@property (strong, nonatomic) PasswordDatabase* passwordDatabase;
@property (strong, nonatomic) LockedSafeInfo* lockedSafeInfo;

@end

@implementation ViewModel

- (instancetype)initNewWithSampleData:(Document*)document; {
    if (self = [super init]) {
        self.passwordDatabase = [[PasswordDatabase alloc] initNewWithoutPassword];
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
        if([PasswordDatabase isAValidSafe:data]) {
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
    
    PasswordDatabase *model = [[PasswordDatabase alloc] initExistingWithDataAndPassword:self.lockedSafeInfo.encryptedData password:password error:error];
    *selectedItem = self.lockedSafeInfo.selectedItem;
    
    if(model != nil) {
        self.passwordDatabase = model;
        self.lockedSafeInfo = nil;
        return YES;
    }
    
    return NO;
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
                                            notes:@"Sample Database Record. You can have any text here..."];
    
    Node* record = [[Node alloc] initAsRecord:@"New Untitled Record" parent:group fields:fields];
    
    if([group addChild:record]) {
        return record;
    }
    
    return nil;
}

- (BOOL)setMasterPassword:(NSString*)password {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setMasterPassword:password];
    
    self.document.dirty = YES;
    
    return YES;
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
    Node* item = [self addSampleRecord:parentGroup];

    self.document.dirty = (item != nil);

    return item;
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
    return [Utils generatePassword];
}

- (NSString*_Nonnull)getDiagnosticDumpString {
    return [self.passwordDatabase getDiagnosticDumpString:YES];
}

- (void)defaultLastUpdateFieldsToNow {
    [self.passwordDatabase defaultLastUpdateFieldsToNow];
}

@end
