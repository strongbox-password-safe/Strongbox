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

@interface EntryViewModel()

@property NSMutableArray<CustomFieldViewModel*>* mutableCustomFields;
@property MutableOrderedDictionary<NSString*, DatabaseAttachment*>* mutableAttachments;
@property NSMutableSet<NSString*>* mutableTags;

@end

@implementation EntryViewModel

- (instancetype)initWithTitle:(NSString *)title
                     username:(NSString *)username
                     password:(NSString *)password
                          url:(NSString *)url
                        notes:(NSString *)notes
                        email:(NSString *)email
         keePassEmailFieldKey:(NSString *_Nullable)keePassEmailFieldKey
                      expires:(NSDate*)expires
                         tags:(NSSet<NSString*>*)tags
                         totp:(OTPToken *)totp
                         icon:(NodeIcon*)icon
                 customFields:(NSArray<CustomFieldViewModel *> *)customFields
                  attachments:(nonnull NSDictionary<NSString *,DatabaseAttachment *> *)attachments
                     metadata:(nonnull NSArray<ItemMetadataEntry *> *)metadata
                   hasHistory:(BOOL)hasHistory {
    if (self = [super init]) {
        self.title = title;
        self.username = username;
        self.password = password;
        self.totp = totp ? [OTPToken tokenWithURL:totp.url secret:totp.secret] : nil;
        self.url = url;
        self.email = email;
        self.keePassEmailFieldKey = keePassEmailFieldKey;
        self.expires = expires;
        self.mutableTags = tags ? tags.mutableCopy : [NSMutableSet set];
        self.notes = notes;
        self.icon = icon;
        self.mutableCustomFields = customFields ? [[customFields sortedArrayUsingComparator:customFieldKeyComparator] mutableCopy] : [NSMutableArray array];
        
        self.mutableAttachments = [[MutableOrderedDictionary alloc] init];
        NSArray<NSString*>* sortedFilenames = [attachments.allKeys sortedArrayUsingComparator:finderStringComparator];
        for (NSString* filename in sortedFilenames) {
            self.mutableAttachments[filename] = attachments[filename];
        }
        
        _metadata = metadata;
        
        self.hasHistory = hasHistory;
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
                                             keePassEmailFieldKey:self.keePassEmailFieldKey
                                                          expires:self.expires
                                                             tags:self.mutableTags
                                                             totp:self.totp
                                                             icon:self.icon
                                                     customFields:self.customFields
                                                      attachments:self.attachments.dictionary
                                                         metadata:self.metadata
                                                       hasHistory:self.hasHistory];

    return model;
}

- (BOOL)isValid {
    return YES;
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

- (NSUInteger)insertCustomField:(CustomFieldViewModel*)field {
    NSUInteger idx = [self.mutableCustomFields indexOfObject:field
                                               inSortedRange:NSMakeRange(0, self.mutableCustomFields.count)
                                                     options:NSBinarySearchingInsertionIndex
                                             usingComparator:customFieldKeyComparator];
    
    [self.mutableCustomFields insertObject:field atIndex:idx];
    
    return idx;
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
                                           keePassEmailFieldKey:@"Email"
                                                        expires:nil
                                                           tags:nil
                                                           totp:token
                                                           icon:[NodeIcon withPreset:12]
                                                   customFields:@[ c1, c2, c3]
                                                    attachments:attachments
                                                       metadata:metadata
                                                     hasHistory:YES];
    
    return ret;
}

@end
