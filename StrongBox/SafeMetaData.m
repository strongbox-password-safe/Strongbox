//
//  SafeDetails.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeMetaData.h"
#import "JNKeychain.h"

@implementation SafeMetaData

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier {
    if(self = [super init]) {
        _nickName = nickName;
        _uuid = [[NSUUID UUID] UUIDString];
        self.storageProvider = storageProvider;
        self.fileName = fileName;
        self.fileIdentifier = fileIdentifier;
    
        self.isTouchIdEnabled = YES;
        self.offlineCacheEnabled = YES;
        self.autoFillCacheEnabled = YES;
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%u] - [%@-%@]", self.nickName, self.storageProvider, self.fileName, self.fileIdentifier];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.uuid forKey:@"uuid"];
    [encoder encodeObject:self.nickName forKey:@"nickName"];
    [encoder encodeObject:self.fileName forKey:@"fileName"];
    [encoder encodeObject:self.fileIdentifier forKey:@"fileIdentifier"];
    [encoder encodeInteger:self.storageProvider forKey:@"storageProvider"];

    [encoder encodeBool:self.isTouchIdEnabled forKey:@"isTouchIdEnabled"];
    [encoder encodeBool:self.isEnrolledForTouchId forKey:@"isEnrolledForTouchId"];

    [encoder encodeBool:self.offlineCacheEnabled forKey:@"offlineCacheEnabled"];
    [encoder encodeBool:self.offlineCacheAvailable forKey:@"offlineCacheAvailable"];
    [encoder encodeBool:self.hasUnresolvedConflicts forKey:@"hasUnresolvedConflicts"];
    [encoder encodeBool:self.autoFillCacheEnabled forKey:@"autoFillCacheEnabled"];
    [encoder encodeBool:self.autoFillCacheAvailable forKey:@"autoFillCacheAvailable"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.fileName = [decoder decodeObjectForKey:@"fileName"];
        self.fileIdentifier = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
        self.isEnrolledForTouchId = [decoder decodeBoolForKey:@"isEnrolledForTouchId"];
        
        self.offlineCacheEnabled = [decoder decodeBoolForKey:@"offlineCacheEnabled"];
        self.offlineCacheAvailable = [decoder decodeBoolForKey:@"offlineCacheAvailable"];
        self.hasUnresolvedConflicts = [decoder decodeBoolForKey:@"hasUnresolvedConflicts"];
        
        if([decoder containsValueForKey:@"autoFillCacheEnabled"]) {
            self.autoFillCacheEnabled = [decoder decodeBoolForKey:@"autoFillCacheEnabled"];
        }
        else {
            self.autoFillCacheEnabled = YES;
        }

        if([decoder containsValueForKey:@"autoFillCacheAvailable"]) {
            self.autoFillCacheAvailable = [decoder decodeBoolForKey:@"autoFillCacheAvailable"];
        }
    }
    
    return self;
}

- (void)removeTouchIdPassword {
    [JNKeychain deleteValueForKey:self.uuid];
}

- (NSString*)touchIdPassword {
    return [JNKeychain loadValueForKey:self.uuid];
}

- (void)setTouchIdPassword:(NSString *)touchIdPassword {
    [JNKeychain saveValue:touchIdPassword forKey:self.uuid];
}

@end
