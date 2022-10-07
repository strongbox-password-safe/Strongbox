//
//  ItemDetailsModel.m
//  test-new-ui
//
//  Created by Mark on 19/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "EntryViewModel.h"
#import "Utils.h"
#import "OTPToken+Serialization.h"
#import "MutableOrderedDictionary.h"
#import "NodeIcon.h"
#import "Constants.h"
#import "NSDictionary+Extensions.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"

@interface EntryViewModel()

@property NSMutableArray<CustomFieldViewModel*>* mutableCustomFields;
@property MutableOrderedDictionary<NSString*, DatabaseAttachment*>* mutableAttachments;
@property NSMutableSet<NSString*>* mutableTags;

@end

@implementation EntryViewModel

+ (instancetype)demoItem {
    NSString* notes = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

    CustomFieldViewModel *c1 = [CustomFieldViewModel customFieldWithKey:@"Foo" value:@"Bar" protected:NO];
    CustomFieldViewModel *c2 = [CustomFieldViewModel customFieldWithKey:@"Key" value:@"Value" protected:NO];
    CustomFieldViewModel *c3 = [CustomFieldViewModel customFieldWithKey:@"Longish Key" value:@"Well this is a very very long thing that is going on here and there and must wrap" protected:YES];

    NSInputStream* dataStream = [NSInputStream inputStreamWithData:NSData.data];
    DatabaseAttachment* dbAttachment = [[DatabaseAttachment alloc] initWithStream:dataStream protectedInMemory:YES compressed:YES];
     
    NSDictionary<NSString*, DatabaseAttachment*>* attachments = @{
        @"filename.jpg" : dbAttachment,
        @"document.txt" : dbAttachment,
        @"abc.pdf" : dbAttachment,
        @"cool.mpg" : dbAttachment
    };
        
    NSArray<ItemMetadataEntry*>* metadata = @[ [ItemMetadataEntry entryWithKey:@"ID" value:NSUUID.UUID.UUIDString copyable:YES],
                                [ItemMetadataEntry entryWithKey:@"Created" value:@"November 21 at 13:21" copyable:NO],
                                [ItemMetadataEntry entryWithKey:@"Accessed" value:@"Yesterday at 08:21" copyable:NO],
                                [ItemMetadataEntry entryWithKey:@"Modified" value:@"Today at 15:53" copyable:NO]];
    
    OTPToken* token;
    NSData* secretData = [NSData secretWithString:@"The Present King of France"];
    if(secretData) {
        token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:secretData name:@"<Unknown>" issuer:@"<Unknown>"];
        token = [token validate] ? token : nil;
    }

    EntryViewModel* ret = [[EntryViewModel alloc] initWithTitle:@"Acme Inc."
                                                       username:@"mark.mc"
                                                       password:@"very very secret that is waaaaaay too long to fit on one line"
                                                            url:@"https:
                                                          notes:notes
                                                          email:@"markmc@gmail.com"
                                                        expires:nil
                                                           tags:nil
                                                           totp:token
                                                           icon:[NodeIcon withPreset:12]
                                                   customFields:@[ c1, c2, c3]
                                                    attachments:attachments
                                                       metadata:metadata
                                                     hasHistory:YES
                                                parentGroupUuid:nil sortCustomFields:YES];
    
    return ret;
}

+ (instancetype)fromNode:(Node *)item
                  format:(DatabaseFormat)format
                   model:(Model *)model
        sortCustomFields:(BOOL)sortCustomFields {
    NSArray<ItemMetadataEntry*>* metadata = [EntryViewModel getMetadataFromItem:item format:format model:model];
    
    
    
    BOOL keePassHistoryAvailable = item.fields.keePassHistory.count > 0 && (format == kKeePass || format == kKeePass4);
    BOOL historyAvailable = format == kPasswordSafe || keePassHistoryAvailable;
   
    
    
    NSMutableArray<CustomFieldViewModel*>* customFieldModels = NSMutableArray.array;
    for ( NSString* key in item.fields.customFieldsNoEmail.allKeys ) {
        StringValue* value = item.fields.customFieldsNoEmail[key];
        [customFieldModels addObject:[CustomFieldViewModel customFieldWithKey:key value:value.value protected:value.protected]];
    }
    
    
    
    EntryViewModel *ret = [[EntryViewModel alloc] initWithTitle:item.title
                                                       username:item.fields.username
                                                       password:item.fields.password
                                                            url:item.fields.url
                                                          notes:item.fields.notes
                                                          email:item.fields.email
                                                        expires:item.fields.expires
                                                           tags:item.fields.tags
                                                           totp:item.fields.otpToken
                                                           icon:item.icon
                                                   customFields:customFieldModels
                                                    attachments:item.fields.attachments
                                                       metadata:metadata
                                                     hasHistory:historyAvailable
                                                parentGroupUuid:item.parent.uuid
                                               sortCustomFields:sortCustomFields];
    
    return ret;
}

+ (NSArray<ItemMetadataEntry*>*)getMetadataFromItem:(Node*)item format:(DatabaseFormat)format model:(Model *)model {
    NSMutableArray<ItemMetadataEntry*>* metadata = [NSMutableArray array];

    [metadata addObject:[ItemMetadataEntry entryWithKey:@"ID" value:keePassStringIdFromUuid(item.uuid) copyable:YES]];

    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_created_field_title", @"Created")
                                                  value:item.fields.created ? item.fields.created.friendlyDateTimeStringPrecise : @""
                                               copyable:NO]];
    




    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_modified_field_title", @"Modified")
                                                  value:item.fields.modified ? item.fields.modified.friendlyDateTimeStringPrecise : @""
                                               copyable:NO]];
        












    NSString* path = [model.database getPathDisplayString:item.parent includeRootGroup:YES rootGroupNameInsteadOfSlash:NO includeFolderEmoji:NO joinedBy:@"/"];
    
    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"generic_fieldname_location", @"Location")
                                                  value:path
                                               copyable:NO]];

    return metadata;
}

- (instancetype)initWithTitle:(NSString *)title
                     username:(NSString *)username
                     password:(NSString *)password
                          url:(NSString *)url
                        notes:(NSString *)notes
                        email:(NSString *)email
                      expires:(NSDate*)expires
                         tags:(NSSet<NSString*>*)tags
                         totp:(OTPToken *)totp
                         icon:(NodeIcon*)icon
                 customFields:(NSArray<CustomFieldViewModel *> *)customFields
                  attachments:(nonnull NSDictionary<NSString *,DatabaseAttachment *> *)attachments
                     metadata:(nonnull NSArray<ItemMetadataEntry *> *)metadata
                   hasHistory:(BOOL)hasHistory
              parentGroupUuid:(NSUUID*_Nullable)parentGroupUuid
             sortCustomFields:(BOOL)sortCustomFields {
    if (self = [super init]) {
        self.title = title;
        self.username = username;
        self.password = password;
        self.totp = totp ? [OTPToken tokenWithURL:totp.url secret:totp.secret] : nil;
        self.url = url;
        self.email = email;
        self.expires = expires;
        self.mutableTags = tags ? tags.mutableCopy : [NSMutableSet set];
        self.notes = notes;
        self.icon = icon;
        
        NSArray<CustomFieldViewModel*>* tmp = customFields ? customFields : @[];
        
        self.sortCustomFields = sortCustomFields;
        if ( sortCustomFields ) {
            tmp = [tmp sortedArrayUsingComparator:customFieldKeyComparator];
        }
        self.mutableCustomFields = tmp.mutableCopy;
        
        self.mutableAttachments = [[MutableOrderedDictionary alloc] init];
        NSArray<NSString*>* sortedFilenames = [attachments.allKeys sortedArrayUsingComparator:finderStringComparator];
        for (NSString* filename in sortedFilenames) {
            self.mutableAttachments[filename] = attachments[filename];
        }
        
        _metadata = metadata;
        
        self.hasHistory = hasHistory;
        self.parentGroupUuid = parentGroupUuid;
    }
    
    return self;
}

- (instancetype)clone {
    EntryViewModel* model = [[EntryViewModel alloc] initWithTitle:self.title
                                                         username:self.username
                                                         password:self.password
                                                              url:self.url
                                                            notes:self.notes
                                                            email:self.email
                                                          expires:self.expires
                                                             tags:self.mutableTags
                                                             totp:self.totp
                                                             icon:self.icon
                                                     customFields:self.customFields
                                                      attachments:self.attachments.dictionary
                                                         metadata:self.metadata
                                                       hasHistory:self.hasHistory
                                                  parentGroupUuid:self.parentGroupUuid
                                                 sortCustomFields:self.sortCustomFields];

    return model;
}

- (BOOL)isDifferentFrom:(EntryViewModel *)other {
    BOOL simpleEqual =  [self.title compare:other.title] == NSOrderedSame &&
                        [self.username compare:other.username] == NSOrderedSame &&
                        [self.password compare:other.password] == NSOrderedSame &&
                        [self.url compare:other.url] == NSOrderedSame &&
                        [self.notes compare:other.notes] == NSOrderedSame &&
                        [self.email compare:other.email] == NSOrderedSame;
   
    if(!simpleEqual) {
        
        return YES;
    }
    
    
    
    if(!((self.expires == nil && other.expires == nil) || (self.expires && other.expires && [self.expires isEqual:other.expires]))) {
        return YES;
    }
    
    
    
    if (![self.mutableTags isEqualToSet:other.mutableTags]) {
        return YES;
    }
    
    
    
    if([OTPToken areDifferent:self.totp b:other.totp]) {
        return YES;
    }

    
    
    if (!( ( self.icon == nil && other.icon == nil ) || (self.icon && [self.icon isEqual:other.icon]) )) { 
        return YES; 
    }
        
    
    
    if ( self.customFields.count != other.customFields.count ) {
        return YES;
    }











    for(int i=0;i<self.customFields.count;i++) {
        CustomFieldViewModel* a = self.customFields[i];
        CustomFieldViewModel* b = other.customFields[i];
        
        if([a isDifferentFrom:b]) {
            return YES;
        }
    }
    
    
    
    if(self.attachments.count != other.attachments.count) {
        return YES;
    }
    
    for (NSString* filename in self.attachments.allKeys) {
        DatabaseAttachment* b = other.attachments[filename];
        DatabaseAttachment* a = self.attachments[filename];
        
        if (!b || ![b.digestHash isEqualToString:a.digestHash]) {
            return YES;
        }
    }
       
    

    if (!( ( self.parentGroupUuid == nil && other.parentGroupUuid == nil ) || (self.parentGroupUuid && [self.parentGroupUuid isEqual:other.parentGroupUuid]) )) {
        return YES;
    }
    
    return NO;
}

- (void)removeAttachment:(NSString*)filename {
    [self.mutableAttachments remove:filename];
}

- (NSUInteger)insertAttachment:(NSString*)filename attachment:(DatabaseAttachment*)attachment {
    NSUInteger idx = [self.mutableAttachments.allKeys indexOfObject:filename
                                                      inSortedRange:NSMakeRange(0, self.mutableAttachments.count)
                                                            options:NSBinarySearchingInsertionIndex
                                                    usingComparator:finderStringComparator];
    
    [self.mutableAttachments insertKey:filename withValue:attachment atIndex:idx];
    
    return idx;
}

- (void)removeCustomFieldAtIndex:(NSUInteger)index {
    [self.mutableCustomFields removeObjectAtIndex:index];
}

- (NSUInteger)addCustomField:(CustomFieldViewModel *)field {
    if ( self.sortCustomFields ) {
        NSUInteger idx = [self.mutableCustomFields indexOfObject:field
                                                   inSortedRange:NSMakeRange(0, self.mutableCustomFields.count)
                                                         options:NSBinarySearchingInsertionIndex
                                                 usingComparator:customFieldKeyComparator];
        
        [self.mutableCustomFields insertObject:field atIndex:idx];
        
        return idx;
    }
    else {
        [self.mutableCustomFields addObject:field];
        return self.mutableCustomFields.count - 1;
    }
}

- (void)moveCustomFieldAtIndex:(NSUInteger)sourceIdx to:(NSUInteger)destinationIdx {
    if ( self.sortCustomFields ) {
        NSLog(@"🔴 moveCustomFieldAtIndex called while sortCustomFields ON");
    }
    else {
        if ( ! ( sourceIdx >= 0 && sourceIdx < self.mutableCustomFields.count && destinationIdx >= 0 && destinationIdx < self.mutableCustomFields.count && sourceIdx != destinationIdx ) ) {
            NSLog(@"🔴 moveCustomFieldAtIndex with invalid indices %ld -> %ld", sourceIdx, destinationIdx);
            return;
        }

        id object = [self.mutableCustomFields objectAtIndex:sourceIdx];
        [self.mutableCustomFields removeObjectAtIndex:sourceIdx];
        [self.mutableCustomFields insertObject:object atIndex:destinationIdx];





    }
}

- (void)resetTags:(NSSet<NSString*>*)tags {
    [self.mutableTags removeAllObjects];
    [self.mutableTags addObjectsFromArray:tags.allObjects];
}

- (void)addTag:(NSString*)tag {
    [self.mutableTags addObject:tag];
}

- (void)removeTag:(NSString*)tag {
    [self.mutableTags removeObject:tag];
}

- (NSArray<NSString*>*)tags {
    return [self.mutableTags.allObjects sortedArrayUsingComparator:finderStringComparator];
}

- (MutableOrderedDictionary<NSString *,DatabaseAttachment *> *)attachments {
    return self.mutableAttachments;
}

- (NSArray<CustomFieldViewModel *> *)customFields {
    return self.mutableCustomFields;
}

NSComparator customFieldKeyComparator = ^(id  obj1, id  obj2) {
    CustomFieldViewModel* a = obj1;
    CustomFieldViewModel* b = obj2;
    
    return finderStringCompare(a.key, b.key);
};

- (BOOL)applyToNode:(Node*)ret
     databaseFormat:(DatabaseFormat)databaseFormat
legacySupplementaryTotp:(BOOL)legacySupplementaryTotp
      addOtpAuthUrl:(BOOL)addOtpAuthUrl {
    if (! [ret setTitle:self.title keePassGroupTitleRules:NO] ) {
        return NO;
    }
    
    [ret touch:YES touchParents:NO];

    ret.fields.username = self.username;
    ret.fields.password = self.password;
    ret.fields.url = self.url;
    ret.fields.notes = self.notes;
    ret.fields.expires = self.expires;

    

    [self applyCustomFieldEdits:ret];

    
    
    ret.fields.email = self.email;
    
    

    if([OTPToken areDifferent:ret.fields.otpToken b:self.totp]) {
        [ret.fields clearTotp]; 

        if(self.totp != nil) {
            [ret.fields setTotp:self.totp
               appendUrlToNotes:databaseFormat == kPasswordSafe || databaseFormat == kKeePass1
                addLegacyFields:legacySupplementaryTotp
                  addOtpAuthUrl:addOtpAuthUrl];
        }
    }

    

    [ret.fields.attachments removeAllObjects];
    [ret.fields.attachments addEntriesFromDictionary:self.attachments.dictionary];

    
    
    [ret.fields.tags removeAllObjects];
    [ret.fields.tags addObjectsFromArray:self.tags];
    
    
    
    
    
    
    
    return YES;
}

- (void)applyCustomFieldEdits:(Node*)ret {
    if ( self.sortCustomFields ) {
        [self applyCustomFieldEditsConservingOrder:ret];
    }
    else {
        [self applyCustomFieldEditsReplacingOrder:ret];
    }
}

- (void)applyCustomFieldEditsConservingOrder:(Node*)ret {
    MutableOrderedDictionary<NSString*, StringValue*> *toBeAppliedMap = [[MutableOrderedDictionary alloc] init];
    for ( CustomFieldViewModel* field in self.customFields ) {
        StringValue *value = [StringValue valueWithString:field.value protected:field.protected];
        [toBeAppliedMap addKey:field.key andValue:value];
    }
    
    NSArray<NSString*> *toBeAppliedKeys = [self.customFields map:^id _Nonnull(CustomFieldViewModel * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }];
    
    NSArray<NSString*>* existingKeys = ret.fields.customFieldsNoEmail.allKeys; 

    NSMutableSet* toBeAppliedSet = toBeAppliedKeys.set.mutableCopy;
    NSMutableSet* deletedSet = existingKeys.set.mutableCopy;
    [deletedSet minusSet:toBeAppliedSet];

    NSMutableSet* addedSet = toBeAppliedKeys.set.mutableCopy;
    NSMutableSet* existingSet = existingKeys.set.mutableCopy;
    [addedSet minusSet:existingSet];

    NSMutableSet* editSet = toBeAppliedKeys.set.mutableCopy;
    [editSet intersectSet:existingSet];
    
    

    for ( NSString* key in deletedSet ) {
        [ret.fields removeCustomField:key];
    }

    
    
    for ( NSString* key in editSet ) {
        StringValue* value = toBeAppliedMap[key];
        [ret.fields setCustomField:key value:value];
    }
    
    
    
    for ( NSString* key in addedSet ) {
        StringValue* value = toBeAppliedMap[key];
        [ret.fields setCustomField:key value:value];
    }
}

- (void)applyCustomFieldEditsReplacingOrder:(Node*)ret {
    [ret.fields removeAllCustomFields];
    
    for (CustomFieldViewModel *field in self.customFields) {
        StringValue *value = [StringValue valueWithString:field.value protected:field.protected];
        [ret.fields setCustomField:field.key value:value];
    }
}

@end
