//
//  SafeMetaData.m
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabaseMetadata.h"
#import "SecretStore.h"

@implementation DatabaseMetadata

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo {
    if(self = [super init]) {
        _nickName = nickName;
        _uuid = [[NSUUID UUID] UUIDString];
        self.storageProvider = storageProvider;
        self.fileUrl = fileUrl;
        self.storageInfo = storageInfo;
        self.isTouchIdEnabled = YES;
        self.touchIdPasswordExpiryPeriodHours = -1; // No expiry
    }
    
    return self;
}

- (NSString*)touchIdPassword {
    NSString* account = [NSString stringWithFormat:@"convenience-pw-%@", self.uuid];
    return [SecretStore.sharedInstance getSecureString:account];
}

- (void)setTouchIdPassword:(NSString *)touchIdPassword {
    NSString* account = [NSString stringWithFormat:@"convenience-pw-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:touchIdPassword forIdentifier:account];
}

- (NSString *)keyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"keyFileBookmark-%@", self.uuid];
    return [SecretStore.sharedInstance getSecureString:account];
}

- (void)setKeyFileBookmark:(NSString *)keyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"keyFileBookmark-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:keyFileBookmark forIdentifier:account];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%u] - [%@-%@]", self.nickName, self.storageProvider, self.fileUrl, self.storageInfo];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.uuid forKey:@"uuid"];
    [encoder encodeObject:self.nickName forKey:@"nickName"];
    [encoder encodeObject:self.fileUrl forKey:@"fileUrl"];
    [encoder encodeObject:self.storageInfo forKey:@"fileIdentifier"];
    [encoder encodeInteger:self.storageProvider forKey:@"storageProvider"];
    [encoder encodeBool:self.isTouchIdEnabled forKey:@"isTouchIdEnabled"];
    [encoder encodeBool:self.hasPromptedForTouchIdEnrol forKey:@"hasPromptedForTouchIdEnrol"];
    [encoder encodeInteger:self.touchIdPasswordExpiryPeriodHours forKey:@"touchIdPasswordExpiryPeriodHours"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.fileUrl = [decoder decodeObjectForKey:@"fileUrl"];
        self.storageInfo = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
        
        if([decoder containsValueForKey:@"hasPromptedForTouchIdEnrol"]) {
            self.hasPromptedForTouchIdEnrol = [decoder decodeBoolForKey:@"hasPromptedForTouchIdEnrol"];
        }

        if([decoder containsValueForKey:@"touchIdPasswordExpiryPeriodHours"]) {
            self.touchIdPasswordExpiryPeriodHours = [decoder decodeIntegerForKey:@"touchIdPasswordExpiryPeriodHours"];
        }
    }
    
    return self;
}

@end
