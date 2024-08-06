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
#import "Node+Passkey.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface EntryViewModel()

@property NSMutableArray<CustomFieldViewModel*>* mutableCustomFields;
@property MutableOrderedDictionary<NSString*, KeePassAttachmentAbstractionLayer*>* mutableAttachments;
@property NSMutableSet<NSString*>* mutableTags;
@property (readonly) NSArray<CustomFieldViewModel*> *customFieldsUnfiltered;
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
            
    OTPToken* token;
    NSData* secretData = [NSData secretWithString:@"The Present King of France"];
    if(secretData) {
        token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:secretData name:@"Demo" issuer:@"Strongbox"];
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
                                                      favourite:NO
                                                   customFields:@[ c1, c2, c3]
                                                    attachments:attachments
                                                parentGroupUuid:nil
                                                 keeAgentSshKey:nil
                                               sortCustomFields:YES
                                        reservedAttachmentNames:NSSet.set
                                                        passkey:nil];
    
    return ret;
}

+ (instancetype)newEmptyEntry {
    return [[EntryViewModel alloc] initEmpty];
}

+ (instancetype)newEntryWithDefaults:(AutoFillNewRecordSettings *)settings
                 mostPopularUsername:(NSString*)mostPopularUsername
                   generatedPassword:(NSString*)generatedPassword
                    mostPopularEmail:(NSString*)mostPopularEmail {
    NSString *title = settings.titleAutoFillMode == kDefault ?
    NSLocalizedString(@"item_details_vc_new_item_title", @"Untitled") :
    settings.titleCustomAutoFill;
    
    NSString* username = settings.usernameAutoFillMode == kNone ? @"" :
    settings.usernameAutoFillMode == kMostUsed ? mostPopularUsername : settings.usernameCustomAutoFill;
    
    NSString *password =
    settings.passwordAutoFillMode == kNone ? @"" :
    settings.passwordAutoFillMode == kGenerated ? generatedPassword : settings.passwordCustomAutoFill;
    
    NSString* email =
    settings.emailAutoFillMode == kNone ? @"" :
    settings.emailAutoFillMode == kMostUsed ? mostPopularEmail : settings.emailCustomAutoFill;
    
    NSString* url = settings.urlAutoFillMode == kNone ? @"" : settings.urlCustomAutoFill;
    
    NSString* notes = settings.notesAutoFillMode == kNone ? @"" : settings.notesCustomAutoFill;
        
    return [[EntryViewModel alloc] initWithTitle:title
                                        username:username
                                        password:password
                                             url:url
                                           notes:notes
                                           email:email];
}

- (instancetype)initEmpty {
    return [self initWithTitle:@""
                      username:@""
                      password:@""
                           url:@""
                         notes:@""
                         email:@""];
}

- (instancetype)initWithTitle:(NSString *)title
                     username:(NSString *)username
                     password:(NSString *)password
                          url:(NSString *)url
                        notes:(NSString *)notes
                        email:(NSString *)email {
    return [self initWithTitle:title
                      username:username
                      password:password
                           url:url
                         notes:notes
                         email:email
                       expires:nil
                          tags:NSSet.set
                          totp:nil
                          icon:nil
                     favourite:NO
                  customFields:@[]
                   attachments:@{}
               parentGroupUuid:nil
                keeAgentSshKey:nil
              sortCustomFields:NO
       reservedAttachmentNames:NSSet.set
                       passkey:nil];
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
                    favourite:(BOOL)favourite
                 customFields:(NSArray<CustomFieldViewModel *> *)customFields
                  attachments:(nonnull NSDictionary<NSString *,KeePassAttachmentAbstractionLayer *> *)attachments
              parentGroupUuid:(NSUUID*_Nullable)parentGroupUuid
               keeAgentSshKey:(KeeAgentSshKeyViewModel*)keeAgentSshKey
             sortCustomFields:(BOOL)sortCustomFields
      reservedAttachmentNames:(NSSet<NSString*>*)reservedAttachmentNames 
                      passkey:(Passkey* _Nullable)passkey {
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
        self.favourite = favourite;
        
        NSArray<CustomFieldViewModel*>* tmp = customFields ? customFields : @[];
        
        _sortCustomFields = sortCustomFields;
        
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
        
        self.parentGroupUuid = parentGroupUuid;
        self.keeAgentSshKey = keeAgentSshKey;
        self.passkey = passkey;
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
                                                        favourite:self.favourite
                                                     customFields:self.customFieldsUnfiltered
                                                      attachments:self.filteredAttachments.dictionary
                                                  parentGroupUuid:self.parentGroupUuid
                                                   keeAgentSshKey:self.keeAgentSshKey  
                                                 sortCustomFields:self.sortCustomFields
                                          reservedAttachmentNames:self.supplementaryReservedAttachmentFilenames
                                                          passkey:self.passkey]; 

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

    
    
    if ( self.favourite != other.favourite ) {
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
    
    
    
    if (!( ( self.passkey == nil && other.passkey == nil ) || (self.passkey && [self.passkey isSameAs:other.passkey]) )) {
        return YES;
    }
    
    return NO;
}



- (BOOL)resetTags:(NSSet<NSString*>*)tags {
    NSArray<NSString*>* splitByDelimiter = [tags.allObjects flatMap:^NSArray * _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [Utils getTagsFromTagString:obj];
    }];

    if ( [self.mutableTags isEqualToSet:splitByDelimiter.set] ) {
        return NO;
    }
    
    [self.mutableTags removeAllObjects];
    [self.mutableTags addObjectsFromArray:splitByDelimiter];
    
    return YES;
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
    NSArray* filtered = self.customFieldsFiltered;
    
    if ( ! ( index >= 0 && index < filtered.count ) ) {
        slog(@"🔴 removeCustomFieldAtIndex with invalid indices %ld", index);
        return;
    }
    
    CustomFieldViewModel* field = [filtered objectAtIndex:index];
    
    [self.mutableCustomFields removeObject:field];
}

- (void)addCustomField:(CustomFieldViewModel *)field {
    [self addCustomField:field atIndex:-1];
}

- (void)addCustomField:(CustomFieldViewModel *)field atIndex:(NSUInteger)atIndex {
    NSUInteger idx;
    
    if ( self.sortCustomFields ) { 
        if ( atIndex != -1 ) {
            slog(@"🔴 WARN: Attempt to add custom field at a specific index when in sort custom fields mode. Ignoring and inserting in sorted position.");
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
            idx = [self translateFilteredIndex:atIndex];
        }
    }
    
    [self.mutableCustomFields insertObject:field atIndex:idx];
    
    
}

- (void)moveCustomFieldAtIndex:(NSUInteger)sourceIdx to:(NSUInteger)destinationIdx {
    if ( self.sortCustomFields ) {
        slog(@"🔴 moveCustomFieldAtIndex called while sortCustomFields ON");
        return;
    }
    
    NSArray* filtered = self.customFieldsFiltered;
    
    if ( ! ( sourceIdx >= 0 && sourceIdx < filtered.count && destinationIdx >= 0 && destinationIdx < filtered.count && sourceIdx != destinationIdx ) ) {
        slog(@"🔴 moveCustomFieldAtIndex with invalid indices %ld -> %ld", sourceIdx, destinationIdx);
        return;
    }
    
    
    
    NSUInteger unfilterDestIdx = [self translateFilteredIndex:destinationIdx];
    
    CustomFieldViewModel* field = [filtered objectAtIndex:sourceIdx]; 
    [self.mutableCustomFields removeObject:field];
    [self.mutableCustomFields insertObject:field atIndex:unfilterDestIdx];
}

- (NSArray<CustomFieldViewModel *> *)customFieldsUnfiltered {
    return self.mutableCustomFields;
}

- (NSArray<CustomFieldViewModel *> *)customFieldsFiltered {
    return [self.customFieldsUnfiltered filter:^BOOL(CustomFieldViewModel * _Nonnull obj) {
        return ![NodeFields isTotpCustomFieldKey:obj.key] && ![NodeFields isPasskeyCustomFieldKey:obj.key]; 
    }];
}

- (NSUInteger)translateFilteredIndex:(NSUInteger)atIndex {
    NSUInteger fallbackIdx = self.mutableCustomFields.count;
    NSArray* filtered = self.customFieldsFiltered;
    
    if ( ! ( atIndex >= 0 && atIndex < filtered.count ) ) {
        slog(@"🔴 addCustomField with invalid indices %ld", atIndex);
        return fallbackIdx;
    }
    
    CustomFieldViewModel* field = [filtered objectAtIndex:atIndex];
    
    NSUInteger found = [self.mutableCustomFields indexOfObject:field];
    
    if ( found == NSNotFound ) {
        slog(@"🔴 addCustomField filter custom fields -> could not find field in unfiltered %ld", atIndex);
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




+ (instancetype)fromNode:(Node *)item model:(Model*)model {
    
    
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
     
    
    
    BOOL favourite = [model isFavourite:item.uuid];
    NSMutableSet<NSString*>* filteredTags = item.fields.tags.mutableCopy;
    [filteredTags removeObject:kCanonicalFavouriteTag];
    
    
    
    BOOL sortFields = !model.metadata.customSortOrderForFields;

    EntryViewModel *ret = [[EntryViewModel alloc] initWithTitle:item.title
                                                       username:item.fields.username
                                                       password:item.fields.password
                                                            url:item.fields.url
                                                          notes:item.fields.notes
                                                          email:item.fields.email
                                                        expires:item.fields.expires
                                                           tags:filteredTags
                                                           totp:item.fields.otpToken
                                                           icon:item.icon
                                                      favourite:favourite
                                                   customFields:customFieldModels
                                                    attachments:attachmentsNoKeeAgent
                                                parentGroupUuid:item.parent.uuid
                                                 keeAgentSshKey:item.keeAgentSshKeyViewModel
                                               sortCustomFields:sortFields  
                                        reservedAttachmentNames:reservedAttachmentNames
                                                        passkey:item.passkey];
    
    return ret;
}

- (BOOL)applyToNode:(Node*)ret
              model:(Model*)model
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
            DatabaseFormat databaseFormat = model.originalFormat;
            
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
    
    if ( model.formatSupportsTags ) {
        if ( self.favourite ) {
            [ret.fields.tags addObject:kCanonicalFavouriteTag];
        }
        else {
            [ret.fields.tags removeObject:kCanonicalFavouriteTag];
        }
    }
    else { 
        
        
        
        
        if ( self.favourite ) {
            [model addFavourite:ret.uuid];
        }
        else {
            [model removeFavourite:ret.uuid];
        }
    }
    
    
    
    if ( ![self.passkey isSameAs:ret.passkey] ) { 
        ret.passkey = self.passkey;
    }
    
    
    
    
    
    
    
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
        slog(@"🔴 setKeeAgentSshKeyEnabled when no key is set!");
    }
}

@end
