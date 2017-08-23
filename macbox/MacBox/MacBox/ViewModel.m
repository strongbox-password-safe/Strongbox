//
//  ViewModel.m
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewModel.h"
#import "LockedSafeInfo.h"

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
        
        [self addSampleRecord:nil];
        
        [self.passwordDatabase createGroupWithTitle:nil title:kNewUntitledGroupTitleBase validateOnly:NO];
        
        _document = document;
        
        return self;
    }
    
    return nil;
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

- (NSArray<SafeItemViewModel*> *)getItemsForGroup:(Group *)group {
    return [self.passwordDatabase getItemsForGroup:group];
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

- (SafeItemViewModel*)addSampleRecord:(Group*)group {
    NSString* password = [self.passwordDatabase generatePassword];
    
    return [self.passwordDatabase addRecord:@"New Untitled Record"
                                      group:group
                                   username:@"user123"
                                        url:@"https://strongboxsafe.com"
                                   password:password
                                      notes:@"Sample Database Record. You can have any text here..."];
}


- (BOOL)setMasterPassword:(NSString*)password {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setMasterPassword:password];
    
    self.document.dirty = YES;
    
    return YES;
}

- (SafeItemViewModel*)setItemTitle:(SafeItemViewModel*)item title:(NSString*)title {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    SafeItemViewModel* newItem = [self.passwordDatabase setItemTitle:item title:title];
    
    self.document.dirty = YES;
    
    return newItem;
}

- (void)setItemUsername:(SafeItemViewModel*)item username:(NSString*)username {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setItemUsername:item username:username];
    self.document.dirty = YES;
}

- (void)setItemUrl:(SafeItemViewModel*)item url:(NSString*)url {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setItemUrl:item url: url];
    self.document.dirty = YES;
}

- (void)setItemPassword:(SafeItemViewModel*)item password:(NSString*)password {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setItemPassword:item password:password];
    self.document.dirty = YES;
}

- (void)setItemNotes:(SafeItemViewModel*)item notes:(NSString*)notes {
    if(self.locked) {
        [NSException raise:@"Attempt to alter model while locked." format:@"Attempt to alter model while locked"];
    }
    
    [self.passwordDatabase setItemNotes:item notes:notes];
    self.document.dirty = YES;
}

- (SafeItemViewModel*)addNewRecord:(Group *)group {
    SafeItemViewModel* item = [self addSampleRecord:group];

    self.document.dirty = (item != nil);

    return item;
}

- (SafeItemViewModel*)addNewGroup:(Group *)parentGroup {
    NSString *newGroupName = kNewUntitledGroupTitleBase;
    
    NSInteger i = 0;
    SafeItemViewModel *item;
    
    while(!(item = [self.passwordDatabase createGroupWithTitle:parentGroup title:newGroupName validateOnly:NO])) {
        i++;
        newGroupName = [NSString stringWithFormat:@"%@ %ld", kNewUntitledGroupTitleBase, i];
    }
    
    self.document.dirty = (item != nil);
    
    return item;
}

- (void)deleteItem:(SafeItemViewModel*)item {
    [self.passwordDatabase deleteItem:item];
    
    self.document.dirty = YES;
}

- (BOOL)validateMoveOfItems:(NSArray<SafeItemViewModel *> *)items group:(SafeItemViewModel*)group {
    return [self.passwordDatabase moveOrValidateItems:items destination:group.group validateOnly:YES];
}

- (BOOL)moveItems:(NSArray<SafeItemViewModel *> *)items group:(SafeItemViewModel*)group {
    self.document.dirty = [self.passwordDatabase moveOrValidateItems:items destination:group.group validateOnly:NO];

    return self.document.dirty;
}

- (NSString*)getSerializationIdForItem:(SafeItemViewModel*)item {
    return [self.passwordDatabase getSerializationIdForItem:item];
}

- (SafeItemViewModel*)getItemFromSerializationId:(NSString*)serializationId {
    return [self.passwordDatabase getItemFromSerializationId:serializationId];
}

- (NSString*)generatePassword {
    return [self.passwordDatabase generatePassword];
}

@end
