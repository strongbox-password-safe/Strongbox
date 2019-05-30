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

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.uuid = [[NSUUID UUID] UUIDString];
        self.failedPinAttempts = 0;
        self.offlineCacheEnabled = YES;
        self.autoFillCacheEnabled = YES;
        self.useQuickTypeAutoFill = YES;
    }
    
    return self;
}

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier {
    if(self = [self init]) {
        self.nickName = nickName;
        self.storageProvider = storageProvider;
        self.fileName = fileName;
        self.fileIdentifier = fileIdentifier;
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
    
    [encoder encodeBool:self.isEnrolledForConvenience forKey:@"isEnrolledForTouchId"];

    [encoder encodeBool:self.offlineCacheEnabled forKey:@"offlineCacheEnabled"];
    [encoder encodeBool:self.offlineCacheAvailable forKey:@"offlineCacheAvailable"];
    [encoder encodeBool:self.hasUnresolvedConflicts forKey:@"hasUnresolvedConflicts"];
    [encoder encodeBool:self.autoFillCacheEnabled forKey:@"autoFillCacheEnabled"];
    [encoder encodeBool:self.autoFillCacheAvailable forKey:@"autoFillCacheAvailable"];
    [encoder encodeBool:self.readOnly forKey:@"readOnly"];
    
    [encoder encodeInteger:self.duressAction forKey:@"duressAction"];
    [encoder encodeBool:self.hasBeenPromptedForConvenience forKey:@"hasBeenPromptedForConvenience"];
    [encoder encodeInteger:self.failedPinAttempts forKey:@"failedPinAttempts"];

    [encoder encodeBool:self.useQuickTypeAutoFill forKey:@"useQuickTypeAutoFill"];
    [encoder encodeObject:self.keyFileUrl forKey:@"keyFileUrl"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.fileName = [decoder decodeObjectForKey:@"fileName"];
        self.fileIdentifier = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
        self.isEnrolledForConvenience = [decoder decodeBoolForKey:@"isEnrolledForTouchId"];
        
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

        if([decoder containsValueForKey:@"readOnly"]) {
            self.readOnly = [decoder decodeBoolForKey:@"readOnly"];
        }

        if([decoder containsValueForKey:@"duressAction"]) {
            self.duressAction = (int)[decoder decodeIntegerForKey:@"duressAction"];
        }

        if([decoder containsValueForKey:@"hasBeenPromptedForConvenience"]) {
            self.hasBeenPromptedForConvenience = [decoder decodeBoolForKey:@"hasBeenPromptedForConvenience"];
        }
        
        if([decoder containsValueForKey:@"failedPinAttempts"]) {
            self.failedPinAttempts = (int)[decoder decodeIntegerForKey:@"failedPinAttempts"];
        }
        
        if([decoder containsValueForKey:@"useQuickTypeAutoFill"]) {
            self.useQuickTypeAutoFill = [decoder decodeBoolForKey:@"useQuickTypeAutoFill"];
        }
        
        if([decoder containsValueForKey:@"keyFileUrl"]) {
            self.keyFileUrl = [decoder decodeObjectForKey:@"keyFileUrl"];
        }
    }
    
    return self;
}

- (NSString *)convenienceMasterPassword {
    return [JNKeychain loadValueForKey:self.uuid];
}

- (void)setConvenienceMasterPassword:(NSString *)convenienceMasterPassword {
    if(convenienceMasterPassword) {
        [JNKeychain saveValue:convenienceMasterPassword forKey:self.uuid];
    }
    else {
        [JNKeychain deleteValueForKey:self.uuid];
    }
}

- (NSData *)convenenienceKeyFileDigest {
    NSString *key = [NSString stringWithFormat:@"%@-keyFileDigest", self.uuid];
    
    NSData* ret = [JNKeychain loadValueForKey:key];

    return ret;
}

- (void)setConvenenienceKeyFileDigest:(NSData *)convenenienceKeyFileDigest {
    NSString *key = [NSString stringWithFormat:@"%@-keyFileDigest", self.uuid];
    
    if(convenenienceKeyFileDigest) {
        [JNKeychain saveValue:convenenienceKeyFileDigest forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];
    return [JNKeychain loadValueForKey:key];
}

- (void)setConveniencePin:(NSString *)conveniencePin {
    NSString *key = [NSString stringWithFormat:@"%@-convenience-pin", self.uuid];

    if(conveniencePin) {
        [JNKeychain saveValue:conveniencePin forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (NSString *)duressPin {
    NSString *key = [NSString stringWithFormat:@"%@-duress-pin", self.uuid];
    return [JNKeychain loadValueForKey:key];
}

-(void)setDuressPin:(NSString *)duressPin {
    NSString *key = [NSString stringWithFormat:@"%@-duress-pin", self.uuid];
    
    if(duressPin) {
        [JNKeychain saveValue:duressPin forKey:key];
    }
    else {
        [JNKeychain deleteValueForKey:key];
    }
}

- (void)clearKeychainItems {
    self.convenienceMasterPassword = nil;
    self.convenenienceKeyFileDigest = nil;
    self.duressPin = nil;
    self.conveniencePin = nil;
}

@end
