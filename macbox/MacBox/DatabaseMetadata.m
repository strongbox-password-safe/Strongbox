//
//  SafeMetaData.m
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabaseMetadata.h"
#import <SAMKeychain/SAMKeychain.h>

static NSString* kKeychainService = @"Strongbox";

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
    }
    
    return self;
}

- (NSString*)touchIdPassword {
    NSError *error;
    
    NSData * ret = [SAMKeychain passwordDataForService:kKeychainService account:self.uuid error:&error];
    
    if(ret) {
        return [[NSString alloc] initWithData:ret encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (void)setTouchIdPassword:(NSString *)touchIdPassword {
    if(touchIdPassword) {
        NSData* data = [touchIdPassword dataUsingEncoding:NSUTF8StringEncoding];
        [SAMKeychain setPasswordData:data forService:kKeychainService account:self.uuid];
    }
    else {
        [SAMKeychain deletePasswordForService:kKeychainService account:self.uuid];
    }
}

- (NSData *)touchIdKeyFileDigest {
    NSString* account = [NSString stringWithFormat:@"keyFileDigest-%@", self.uuid];
    
    return [SAMKeychain passwordDataForService:kKeychainService account:account];
}

- (void)setTouchIdKeyFileDigest:(NSData *)touchIdKeyFileDigest {
    NSString* account = [NSString stringWithFormat:@"keyFileDigest-%@", self.uuid];
    
    if(touchIdKeyFileDigest) {
        [SAMKeychain setPasswordData:touchIdKeyFileDigest forService:kKeychainService account:account];
    }
    else {
        [SAMKeychain deletePasswordForService:kKeychainService account:account];
    }

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
    }
    
    return self;
}

@end
