//
//  NodeFields.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "NodeFields.h"
#import "NSArray+Extensions.h"

@implementation NodeFields

- (instancetype _Nullable)init {
    return [self initWithUsername:@""
                              url:@""
                         password:@""
                            notes:@""
                            email:@""];
}

- (instancetype _Nullable)initWithUsername:(NSString*_Nonnull)username
                                       url:(NSString*_Nonnull)url
                                  password:(NSString*_Nonnull)password
                                     notes:(NSString*_Nonnull)notes
                                     email:(NSString*_Nonnull)email {
    if (self = [super init]) {
        self.username = username == nil ? @"" : username;
        self.url = url == nil ? @"" : url;
        self.password = password == nil ? @"" : password;
        self.notes = notes == nil ? @"" : notes;
        self.email = email == nil ? @"" : email;
        self.passwordHistory = [[PasswordHistory alloc] init];
        self.created = [NSDate date];
        self.modified = [NSDate date];
        self.accessed = [NSDate date];
        self.passwordModified = [NSDate date];
        self.attachments = [NSMutableArray array];
        self.customFields = [NSMutableDictionary dictionary];
        self.keePassHistory = [NSMutableArray array];
    }
    
    return self;
}

- (NSMutableArray<NodeFileAttachment*>*)cloneAttachments {
    return [[self.attachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        return [NodeFileAttachment attachmentWithName:obj.filename index:obj.index linkedObject:obj.linkedObject];
    }] mutableCopy];
}

- (NSMutableDictionary<NSString*, StringValue*>*)cloneCustomFields {
    NSMutableDictionary<NSString*, StringValue*>* ret = [NSMutableDictionary dictionaryWithCapacity:self.customFields.count];
    
    for (NSString* key in self.customFields.allKeys) {
        StringValue* orig = self.customFields[key];
        ret[key] = [StringValue valueWithString:orig.value protected:orig.protected];
    }
    
    return ret;
}

- (NodeFields *)cloneForHistory {
    NodeFields* ret = [[NodeFields alloc] initWithUsername:self.username url:self.url password:self.password notes:self.notes email:self.email];

    ret.created = self.created;
    ret.modified = self.modified;
    ret.accessed = self.accessed;
    ret.passwordModified = self.passwordModified;

    ret.attachments = [self cloneAttachments];
    ret.customFields = [self cloneCustomFields];
    
    // Empty History
    ret.keePassHistory = [NSMutableArray array];
    
    return ret;
}

- (void)setPassword:(NSString *)password {
    if([password isEqualToString:_password]) {
        return;
    }
    
    _password = password;
    self.passwordModified = [NSDate date];
    
    PasswordHistory *pwHistory = self.passwordHistory;
    
    if (pwHistory.enabled && pwHistory.maximumSize > 0 && password) {
        [pwHistory.entries addObject:[[PasswordHistoryEntry alloc] initWithPassword:password]];
        
        if ((pwHistory.entries).count > pwHistory.maximumSize) {
            NSUInteger count = (pwHistory.entries).count;
            NSArray *slice = [pwHistory.entries subarrayWithRange:(NSRange) {count - pwHistory.maximumSize, pwHistory.maximumSize }];
            [pwHistory.entries removeAllObjects];
            [pwHistory.entries addObjectsFromArray:slice];
        }
    }
}

-(NSString *)description {
    return [NSString stringWithFormat:@"{\n    password = [%@]\n    username = [%@]\n    email = [%@]\n    url = [%@]\n}",
            self.password,
            self.username,
            self.email,
            self.url];
}

@end
