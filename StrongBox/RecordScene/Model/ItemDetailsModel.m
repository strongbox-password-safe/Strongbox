//
//  ItemDetailsModel.m
//  test-new-ui
//
//  Created by Mark on 19/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ItemDetailsModel.h"
#import "Utils.h"
#import "OTPToken+Serialization.h"
#import "OTPToken+Generation.h"

@interface ItemDetailsModel()

@property NSMutableArray<CustomFieldViewModel*>* mutableCustomFields;
@property NSMutableArray<UiAttachment*>* mutableAttachments;

@end

@implementation ItemDetailsModel

- (instancetype)initWithTitle:(NSString *)title
                     username:(NSString *)username
                     password:(NSString *)password
                          url:(NSString *)url
                        notes:(NSString *)notes
                        email:(NSString *)email
                      expires:(NSDate*)expires
                         totp:(OTPToken *)totp
                         icon:(SetIconModel*)icon
                 customFields:(NSArray<CustomFieldViewModel *> *)customFields
                  attachments:(NSArray<UiAttachment *> *)attachments
                     metadata:(NSArray<ItemMetadataEntry*> *)metadata
                   hasHistory:(BOOL)hasHistory {
    if (self = [super init]) {
        self.title = title;
        self.username = username;
        self.password = password;
        self.totp = totp ? [OTPToken tokenWithURL:totp.url secret:totp.secret] : nil;
        self.url = url;
        self.email = email;
        self.expires = expires;
        self.notes = notes;
        self.icon = icon;
        self.mutableCustomFields = customFields ? [[customFields sortedArrayUsingComparator:customFieldKeyComparator] mutableCopy] : [NSMutableArray array];
        self.mutableAttachments = attachments ? [[attachments sortedArrayUsingComparator:attachmentNameComparator] mutableCopy] : [NSMutableArray array];
        
        _metadata = metadata;
        
        self.hasHistory = hasHistory;
    }
    
    return self;
}

- (instancetype)clone {
    ItemDetailsModel* model = [[ItemDetailsModel alloc] initWithTitle:self.title
                                                             username:self.username
                                                             password:self.password
                                                                  url:self.url
                                                                notes:self.notes
                                                                email:self.email
                                                              expires:self.expires
                                                                 totp:self.totp
                                                                 icon:self.icon
                                                         customFields:self.customFields
                                                          attachments:self.attachments
                                                             metadata:self.metadata
                                                           hasHistory:self.hasHistory];

    return model;
}

- (BOOL)isValid {
    return self.title.length > 0;
}

- (BOOL)isDifferentFrom:(ItemDetailsModel *)other {
    BOOL simpleEqual =  [self.title isEqualToString:other.title] &&
                        [self.username isEqualToString:other.username] &&
                        [self.password isEqualToString:other.password] &&
                        [self.url isEqualToString:other.url] &&
                        [self.notes isEqualToString:other.notes] &&
                        [self.email isEqualToString:other.email];
   
    if(!simpleEqual) {
        // NSLog(@"Model: Simply Different");
        return YES;
    }
    
    // Expiry
    
    if(!((self.expires == nil && other.expires == nil) || (self.expires && other.expires && [self.expires isEqual:other.expires]))) {
        return YES;
    }
    
    // TOTP
    
    if([OTPToken areDifferent:self.totp b:other.totp]) {
        return YES;
    }

    // Icon
    
    if(self.icon.customImage) {
        return YES; // Any custom image is always new
    }
    
    if(!((self.icon.customUuid == nil && other.icon.customUuid == nil)  || (self.icon.customUuid && other.icon.customUuid && [self.icon.customUuid isEqual:other.icon.customUuid]))) {
        return YES;
    }
    
    if(!((self.icon.index == nil && other.icon.index == nil) || (self.icon.index && other.icon.index && [self.icon.index isEqual:other.icon.index]))) {
        return YES;
    }
    
    // Custom Fields
    
    if(self.customFields.count != other.customFields.count) {
        return YES;
    }
    
    for(int i=0;i<self.customFields.count;i++) {
        CustomFieldViewModel* a = self.customFields[i];
        CustomFieldViewModel* b = other.customFields[i];
        
        if([a isDifferentFrom:b]) {
            return YES;
        }
    }
    
    // Attachments
    
    if(self.attachments.count != other.attachments.count) {
        return YES;
    }
    
    for(int i=0;i<self.attachments.count;i++) {
        UiAttachment* a = self.attachments[i];
        UiAttachment* b = other.attachments[i];
        
        if([a.filename isEqualToString:b.filename]) {
            if(![a.data isEqualToData:b.data]) {
                return YES;
            }
        }
        else {
            return YES;
        }
    }
    
    return NO;
}

- (void)removeAttachmentAtIndex:(NSUInteger)index {
    [self.mutableAttachments removeObjectAtIndex:index];
}

- (NSUInteger)insertAttachment:(UiAttachment*)attachment {
    NSUInteger idx = [self.mutableAttachments indexOfObject:attachment
                                               inSortedRange:NSMakeRange(0, self.mutableAttachments.count)
                                                     options:NSBinarySearchingInsertionIndex
                                             usingComparator:attachmentNameComparator];
    
    [self.mutableAttachments insertObject:attachment atIndex:idx];
    
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

- (NSArray<UiAttachment *> *)attachments {
    return self.mutableAttachments;
}

- (NSArray<CustomFieldViewModel *> *)customFields {
    return self.mutableCustomFields;
}

NSComparator attachmentNameComparator = ^(id  obj1, id  obj2) {
    UiAttachment* a = obj1;
    UiAttachment* b = obj2;
    
    return finderStringCompare(a.filename, b.filename);
};

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

    UiAttachment* a1 = [[UiAttachment alloc] initWithFilename:@"filename.jpg" data:[NSData data]];
    UiAttachment* a2 = [[UiAttachment alloc] initWithFilename:@"document.txt" data:[NSData data]];
    UiAttachment* a3 = [[UiAttachment alloc] initWithFilename:@"abc.pdf" data:[NSData data]];
    UiAttachment* a4 = [[UiAttachment alloc] initWithFilename:@"cool.mpg" data:[NSData data]];
    
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

    ItemDetailsModel* ret = [[ItemDetailsModel alloc] initWithTitle:@"Acme Inc."
                                                           username:@"mark.mc"
                                                           password:@"very very secret that is waaaaaay too long to fit on one line"
                                                                url:@"https://www.strongboxsafe.com"
                                                              notes:notes
                                                              email:@"markmc@gmail.com"
                                                            expires:nil
                                                               totp:token
                                                               icon:[SetIconModel setIconModelWith:@(12) customUuid:nil customImage:nil]
                                                       customFields:@[ c1, c2, c3]
                                                        attachments:@[ a1, a2, a3, a4]
                                                           metadata:metadata
                                                         hasHistory:YES];
    
    return ret;
}

@end
