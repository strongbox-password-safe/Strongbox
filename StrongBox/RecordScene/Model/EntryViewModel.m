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
#import "Node+KeeAgentSSH.h"

@interface EntryViewModel()

@property NSMutableArray<CustomFieldViewModel*>* mutableCustomFields;
@property MutableOrderedDictionary<NSString*, KeePassAttachmentAbstractionLayer*>* mutableAttachments;
@property NSMutableSet<NSString*>* mutableTags;

@property (readonly) NSArray<CustomFieldViewModel*> *customFieldsUnfiltered;
@property DatabaseFormat format;

@property (readonly) NSSet<NSString*>* supplementaryReservedAttachmentFilenames;

@end

@implementation EntryViewModel

NSComparator customFieldKeyComparator = ^(id  obj1, id  obj2) {
    CustomFieldViewModel* a = obj1;
    CustomFieldViewModel* b = obj2;
    
    return finderStringCompare(a.key, b.key);
};

+ (instancetype)demoItem {
    NSString* notes = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

    CustomFieldViewModel *c1 = [CustomFieldViewModel customFieldWithKey:@"Foo" value:@"Bar" protected:NO];
    CustomFieldViewModel *c2 = [CustomFieldViewModel customFieldWithKey:@"Key" value:@"Value" protected:NO];
    CustomFieldViewModel *c3 = [CustomFieldViewModel customFieldWithKey:@"Longish Key" value:@"Well this is a very very long thing that is going on here and there and must wrap" protected:YES];

    NSInputStream* dataStream = [NSInputStream inputStreamWithData:NSData.data];
    KeePassAttachmentAbstractionLayer* dbAttachment = [[KeePassAttachmentAbstractionLayer alloc] initWithStream:dataStream length:0 protectedInMemory:YES compressed:YES];
     
    NSDictionary<NSString*, KeePassAttachmentAbstractionLayer*>* attachments = @{
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
                                                parentGroupUuid:nil
                                                 keeAgentSshKey:nil
                                               sortCustomFields:YES
                                             filterCustomFields:YES
                                                         format:kKeePass4
                                        reservedAttachmentNames:NSSet.set];
    
    return ret;
}

+ (instancetype)fromNode:(Node *)item
                  format:(DatabaseFormat)format
                   model:(Model *)model
        sortCustomFields:(BOOL)sortCustomFields {
    NSArray<ItemMetadataEntry*>* metadata = [EntryViewModel getMetadataFromItem:item model:model];
    
    
    
    BOOL keePassHistoryAvailable = item.fields.keePassHistory.count > 0 && (format == kKeePass || format == kKeePass4);
    BOOL historyAvailable = format == kPasswordSafe || keePassHistoryAvailable;
   
    
    
    NSMutableArray<CustomFieldViewModel*>* customFieldModels = NSMutableArray.array;
    for ( NSString* key in item.fields.customFieldsNoEmail.allKeys ) {
        StringValue* value = item.fields.customFieldsNoEmail[key];
        [customFieldModels addObject:[CustomFieldViewModel customFieldWithKey:key value:value.value protected:value.protected]];
    }
    
    
    
    NSSet<NSString*>* reservedAttachmentNames = NSSet.set;
    NSMutableDictionary* attachmentsNoKeeAgent = item.fields.attachments.mutableCopy;
    if ( item.keeAgentSshKeyViewModel ) {
        [attachmentsNoKeeAgent removeObjectForKey:kKeeAgentSettingsAttachmentName];
        [attachmentsNoKeeAgent removeObjectForKey:item.keeAgentSshKeyViewModel.filename];
        reservedAttachmentNames =  @[kKeeAgentSettingsAttachmentName, item.keeAgentSshKeyViewModel.filename].set;
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
                                                    attachments:attachmentsNoKeeAgent
                                                       metadata:metadata
                                                     hasHistory:historyAvailable
                                                parentGroupUuid:item.parent.uuid
                                                 keeAgentSshKey:item.keeAgentSshKeyViewModel
                                               sortCustomFields:sortCustomFields
                                             filterCustomFields:YES
                                                         format:format
                                        reservedAttachmentNames:reservedAttachmentNames];
    
    return ret;
}

+ (NSArray<ItemMetadataEntry*>*)getMetadataFromItem:(Node*)item
                                              model:(Model *)model {
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
                  attachments:(nonnull NSDictionary<NSString *,KeePassAttachmentAbstractionLayer *> *)attachments
                     metadata:(nonnull NSArray<ItemMetadataEntry *> *)metadata
                   hasHistory:(BOOL)hasHistory
              parentGroupUuid:(NSUUID*_Nullable)parentGroupUuid
               keeAgentSshKey:(KeeAgentSshKeyViewModel*)keeAgentSshKey
             sortCustomFields:(BOOL)sortCustomFields
           filterCustomFields:(BOOL)filterCustomFields
                       format:(DatabaseFormat)format
      reservedAttachmentNames:(NSSet<NSString*>*)reservedAttachmentNames {
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
        
        _sortCustomFields = sortCustomFields;
        _filterCustomFields = filterCustomFields;
        
        if ( sortCustomFields ) {
            tmp = [tmp sortedArrayUsingComparator:customFieldKeyComparator];
        }
        self.mutableCustomFields = tmp.mutableCopy;
        
        self.mutableAttachments = [[MutableOrderedDictionary alloc] init];
        NSArray<NSString*>* sortedFilenames = [attachments.allKeys sortedArrayUsingComparator:finderStringComparator];
        for (NSString* filename in sortedFilenames) {
            self.mutableAttachments[filename] = attachments[filename];
        }
        _supplementaryReservedAttachmentFilenames = reservedAttachmentNames;

        _metadata = metadata;
        
        self.hasHistory = hasHistory;
        self.parentGroupUuid = parentGroupUuid;
        self.keeAgentSshKey = keeAgentSshKey;
        self.format = format;
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
                                                     customFields:self.customFieldsUnfiltered
                                                      attachments:self.filteredAttachments.dictionary
                                                         metadata:self.metadata
                                                       hasHistory:self.hasHistory
                                                  parentGroupUuid:self.parentGroupUuid
                                                   keeAgentSshKey:self.keeAgentSshKey
                                                 sortCustomFields:self.sortCustomFields
                                               filterCustomFields:YES
                                                           format:self.format
                                          reservedAttachmentNames:self.supplementaryReservedAttachmentFilenames];

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
        
    
    
    if ( self.customFieldsUnfiltered.count != other.customFieldsUnfiltered.count ) {
        return YES;
    }











    for(int i=0;i<self.customFieldsUnfiltered.count;i++) {
        CustomFieldViewModel* a = self.customFieldsUnfiltered[i];
        CustomFieldViewModel* b = other.customFieldsUnfiltered[i];
        
        if([a isDifferentFrom:b]) {
            return YES;
        }
    }
    
    
    
    if(self.filteredAttachments.count != other.filteredAttachments.count) {
        return YES;
    }
    
    for (NSString* filename in self.filteredAttachments.allKeys) {
        KeePassAttachmentAbstractionLayer* b = other.filteredAttachments[filename];
        KeePassAttachmentAbstractionLayer* a = self.filteredAttachments[filename];
        
        if (!b || ![b.digestHash isEqualToString:a.digestHash]) {
            return YES;
        }
    }
       
    

    if (!( ( self.parentGroupUuid == nil && other.parentGroupUuid == nil ) || (self.parentGroupUuid && [self.parentGroupUuid isEqual:other.parentGroupUuid]) )) {
        return YES;
    }
    
    
    
    if ( !(self.keeAgentSshKey == nil && other.keeAgentSshKey == nil ) &&
        (![self.keeAgentSshKey isEqualTo:other.keeAgentSshKey] )) {
        return YES;
    }
            
    return NO;
}



- (void)resetTags:(NSSet<NSString*>*)tags {
    [self.mutableTags removeAllObjects];
    
    NSArray<NSString*>* splitByDelimiter = [tags.allObjects flatMap:^NSArray * _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [Utils getTagsFromTagString:obj];
    }];
    
    [self.mutableTags addObjectsFromArray:splitByDelimiter];
}

- (void)addTag:(NSString*)tag {
    NSArray<NSString*>* tags = [Utils getTagsFromTagString:tag]; 
    [self.mutableTags addObjectsFromArray:tags];
}

- (void)removeTag:(NSString*)tag {
    [self.mutableTags removeObject:tag];
}

- (NSArray<NSString*>*)tags {
    return [self.mutableTags.allObjects sortedArrayUsingComparator:finderStringComparator];
}



- (MutableOrderedDictionary<NSString *,KeePassAttachmentAbstractionLayer *> *)filteredAttachments {
    return self.mutableAttachments;
}

- (void)removeAttachment:(NSString*)filename {
    [self.mutableAttachments remove:filename];
}

- (void)insertAttachment:(NSString*)filename attachment:(KeePassAttachmentAbstractionLayer*)attachment {
    NSUInteger idx = [self.mutableAttachments.allKeys indexOfObject:filename
                                                      inSortedRange:NSMakeRange(0, self.mutableAttachments.count)
                                                            options:NSBinarySearchingInsertionIndex
                                                    usingComparator:finderStringComparator];
    
    [self.mutableAttachments insertKey:filename withValue:attachment atIndex:idx];
    

}

- (NSSet<NSString *> *)reservedAttachmentNames {
    NSMutableSet<NSString*>* ret = self.supplementaryReservedAttachmentFilenames.mutableCopy; 
    
    [ret addObjectsFromArray:self.mutableAttachments.allKeys];
    
    return ret;
}







- (void)removeCustomFieldAtIndex:(NSUInteger)index {
    if ( self.filterCustomFields ) {
        NSArray* filtered = self.customFieldsFiltered;
        
        if ( ! ( index >= 0 && index < filtered.count ) ) {
            NSLog(@"🔴 removeCustomFieldAtIndex with invalid indices %ld", index);
            return;
        }
        
        CustomFieldViewModel* field = [filtered objectAtIndex:index];
        
        [self.mutableCustomFields removeObject:field];
    }
    else {
        [self.mutableCustomFields removeObjectAtIndex:index];
    }
}

- (void)addCustomField:(CustomFieldViewModel *)field {
    [self addCustomField:field atIndex:-1];
}

- (void)addCustomField:(CustomFieldViewModel *)field atIndex:(NSUInteger)atIndex {
    NSUInteger idx;
    
    if ( self.sortCustomFields ) { 
        if ( atIndex != -1 ) {
            NSLog(@"🔴 WARN: Attempt to add custom field at a specific index when in sort custom fields mode. Ignoring and inserting in sorted position.");
        }
        
        idx = [self.mutableCustomFields indexOfObject:field
                                        inSortedRange:NSMakeRange(0, self.mutableCustomFields.count)
                                              options:NSBinarySearchingInsertionIndex
                                      usingComparator:customFieldKeyComparator];
    }
    else {
        NSUInteger fallbackIdx = self.mutableCustomFields.count;

        if ( atIndex < 0  || atIndex > fallbackIdx ){
            idx = fallbackIdx;
        }
        else {
            if ( self.filterCustomFields ) {
                idx = [self translateFilteredIndex:atIndex];
            }
            else {
                idx = atIndex;
            }
        }
    }
    
    [self.mutableCustomFields insertObject:field atIndex:idx];
    
    
}

- (void)moveCustomFieldAtIndex:(NSUInteger)sourceIdx to:(NSUInteger)destinationIdx {
    if ( self.sortCustomFields ) {
        NSLog(@"🔴 moveCustomFieldAtIndex called while sortCustomFields ON");
        return;
    }
    
    if ( self.filterCustomFields ) {
        NSArray* filtered = self.customFieldsFiltered;
        
        if ( ! ( sourceIdx >= 0 && sourceIdx < filtered.count && destinationIdx >= 0 && destinationIdx < filtered.count && sourceIdx != destinationIdx ) ) {
            NSLog(@"🔴 moveCustomFieldAtIndex with invalid indices %ld -> %ld", sourceIdx, destinationIdx);
            return;
        }

        

        NSUInteger unfilterDestIdx = [self translateFilteredIndex:destinationIdx];

        CustomFieldViewModel* field = [filtered objectAtIndex:sourceIdx]; 
        [self.mutableCustomFields removeObject:field];
        [self.mutableCustomFields insertObject:field atIndex:unfilterDestIdx];
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

- (NSArray<CustomFieldViewModel *> *)customFieldsUnfiltered {
    return self.mutableCustomFields;
}

- (NSArray<CustomFieldViewModel *> *)customFieldsFiltered {
    if ( self.filterCustomFields ) {
        return [self.customFieldsUnfiltered filter:^BOOL(CustomFieldViewModel * _Nonnull obj) {
            return ![NodeFields isTotpCustomFieldKey:obj.key]; 
        }];
    }
    else {
        return self.customFieldsUnfiltered;
    }
}

- (NSUInteger)translateFilteredIndex:(NSUInteger)atIndex {
    NSUInteger fallbackIdx = self.mutableCustomFields.count;
    NSArray* filtered = self.customFieldsFiltered;
    
    if ( ! ( atIndex >= 0 && atIndex < filtered.count ) ) {
        NSLog(@"🔴 addCustomField with invalid indices %ld", atIndex);
        return fallbackIdx;
    }
    
    CustomFieldViewModel* field = [filtered objectAtIndex:atIndex];
    
    NSUInteger found = [self.mutableCustomFields indexOfObject:field];
    
    if ( found == NSNotFound ) {
        NSLog(@"🔴 addCustomField filter custom fields -> could not find field in unfiltered %ld", atIndex);
        return fallbackIdx;
    }
    else {
        return found;
    }
}

- (NSSet<NSString *> *)existingCustomFieldsKeySet {
    return [NSSet setWithArray:[self.customFieldsUnfiltered map:^id _Nonnull(CustomFieldViewModel * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }]];
}




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

    

    if ( ret.keeAgentSshKeyViewModel &&
        self.keeAgentSshKey &&
        [ret.keeAgentSshKeyViewModel isEqualToEx:self.keeAgentSshKey testEnabled:NO] ) { 
        
        
        
        NSMutableArray<NSString*>* allFilenames = ret.fields.attachments.allKeys.mutableCopy;
        
        
        [allFilenames removeObject:kKeeAgentSettingsAttachmentName];
        [allFilenames removeObject:ret.keeAgentSshKeyViewModel.filename];
        [ret.fields.attachments removeObjectsForKeys:allFilenames];
        
        
        
        [ret.fields.attachments addEntriesFromDictionary:self.filteredAttachments.dictionary];
        
        
        
        ret.keeAgentSshKeyViewModel = self.keeAgentSshKey;
    }
    else {
        
        
        [ret.fields.attachments removeAllObjects];
        [ret.fields.attachments addEntriesFromDictionary:self.filteredAttachments.dictionary];
        ret.keeAgentSshKeyViewModel = self.keeAgentSshKey;
    }

    
    
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
    for ( CustomFieldViewModel* field in self.customFieldsUnfiltered ) {
        StringValue *value = [StringValue valueWithString:field.value protected:field.protected];
        [toBeAppliedMap addKey:field.key andValue:value];
    }
    
    NSArray<NSString*> *toBeAppliedKeys = [self.customFieldsUnfiltered map:^id _Nonnull(CustomFieldViewModel * _Nonnull obj, NSUInteger idx) {
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
    
    for (CustomFieldViewModel *field in self.customFieldsUnfiltered) {
        StringValue *value = [StringValue valueWithString:field.value protected:field.protected];
        [ret.fields setCustomField:field.key value:value];
    }
}



- (void)setKeeAgentSshKeyEnabled:(BOOL)enabled {
    if ( self.keeAgentSshKey ) {
        if ( self.keeAgentSshKey.enabled != enabled ) {
            
            
            self.keeAgentSshKey = [KeeAgentSshKeyViewModel withKey:self.keeAgentSshKey.openSshKey
                                                          filename:self.keeAgentSshKey.filename
                                                           enabled:enabled];
        }
    }
    else {
        NSLog(@"🔴 setKeeAgentSshKeyEnabled when no key is set!");
    }
}

- (BOOL)supportsCustomFields {
    return (self.format == kKeePass || self.format == kKeePass4);
}

@end
