//
//  SafeMetaData.m
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabaseMetadata.h"
#import "SecretStore.h"

const NSInteger kDefaultPasswordExpiryHours = -1; // Forever 14 * 24; // 2 weeks

@implementation DatabaseMetadata

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo {
    if(self = [super init]) {
        _nickName = nickName ? nickName : @"<Unknown>";
        _uuid = [[NSUUID UUID] UUIDString];
        self.storageProvider = storageProvider;
        self.fileUrl = fileUrl;
        self.storageInfo = storageInfo;
        self.touchIdPasswordExpiryPeriodHours = kDefaultPasswordExpiryHours;
    }
    
    return self;
}

- (void)clearSecureItems {
    [self setConveniencePassword:nil expiringAfterHours:-1];
    self.keyFileBookmark = nil;
    self.autoFillKeyFileBookmark = nil;
}

- (NSString*)getConveniencePasswordIdentifier {
    return [NSString stringWithFormat:@"convenience-pw-%@", self.uuid];
}

- (NSString *)conveniencePassword {
    return [self getConveniencePassword:nil];
}

- (NSString*)getConveniencePassword:(BOOL*_Nullable)expired {
    return [SecretStore.sharedInstance getSecureObject:[self getConveniencePasswordIdentifier] expired:expired];
}

- (void)setConveniencePassword:(NSString*)password expiringAfterHours:(NSInteger)expiringAfterHours {
    NSString* identifier = [self getConveniencePasswordIdentifier];
    if(expiringAfterHours == -1) {
        [SecretStore.sharedInstance setSecureString:password forIdentifier:identifier];
    }
    else if(expiringAfterHours == 0) {
        [SecretStore.sharedInstance setSecureEphemeralObject:password forIdentifer:identifier];
    }
    else {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *date = [cal dateByAddingUnit:NSCalendarUnitHour value:expiringAfterHours toDate:[NSDate date] options:0];
        [SecretStore.sharedInstance setSecureObject:password forIdentifier:identifier expiresAt:date];
    }
}

- (void)resetConveniencePasswordWithCurrentConfiguration:(NSString*)password {
    if(self.isTouchIdEnabled) {
        if(self.touchIdPasswordExpiryPeriodHours == -1) {
            [self setConveniencePassword:password expiringAfterHours:-1];
        }
        else {
            [self setConveniencePassword:password
                      expiringAfterHours:self.touchIdPasswordExpiryPeriodHours];
        }
    }
    else {
        [self setConveniencePassword:nil expiringAfterHours:-1];
    }
}

- (SecretExpiryMode)getConveniencePasswordExpiryMode {
    NSString* identifier = [self getConveniencePasswordIdentifier];
    return [SecretStore.sharedInstance getSecureObjectExpiryMode:identifier];
}

- (NSDate *)getConveniencePasswordExpiryDate {
    NSString* identifier = [self getConveniencePasswordIdentifier];
    return [SecretStore.sharedInstance getSecureObjectExpiryDate:identifier];
}

- (NSString *)autoFillKeyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"autoFill-keyFileBookmark-%@", self.uuid];
    return [SecretStore.sharedInstance getSecureString:account];
}

- (void)setAutoFillKeyFileBookmark:(NSString *)autoFillKeyFileBookmark {
    NSString* account = [NSString stringWithFormat:@"autoFill-keyFileBookmark-%@", self.uuid];
    [SecretStore.sharedInstance setSecureString:autoFillKeyFileBookmark forIdentifier:account];
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
    return [NSString stringWithFormat:@"%@ [%lu] - [%@-%@]", self.nickName, (unsigned long)self.storageProvider, self.fileUrl, self.storageInfo];
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
    [encoder encodeBool:self.isTouchIdEnrolled forKey:@"isTouchIdEnrolled"];
    [encoder encodeObject:self.yubiKeyConfiguration forKey:@"yubiKeyConfiguration"];
    [encoder encodeObject:self.autoFillStorageInfo forKey:@"autoFillStorageInfo"];
    [encoder encodeBool:self.autoFillEnabled forKey:@"autoFillEnabled"];
    [encoder encodeBool:self.quickTypeEnabled forKey:@"quickTypeEnabled"];
    [encoder encodeBool:self.hasPromptedForAutoFillEnrol forKey:@"hasPromptedForAutoFillEnrol"];
    [encoder encodeBool:self.quickWormholeFillEnabled forKey:@"quickWormholeFillEnabled"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.nickName = self.nickName ? self.nickName : @"<Unknown>";
        
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
    
        if([decoder containsValueForKey:@"isTouchIdEnrolled"]) {
            self.isTouchIdEnrolled = [decoder decodeBoolForKey:@"isTouchIdEnrolled"];
        }
        else {
            self.isTouchIdEnrolled = self.conveniencePassword != nil;
        }
        
        if ([decoder containsValueForKey:@"yubiKeyConfiguration"]) {
            self.yubiKeyConfiguration = [decoder decodeObjectForKey:@"yubiKeyConfiguration"];
        }
        
        if ( [decoder containsValueForKey:@"autoFillStorageInfo"] ) {
            self.autoFillStorageInfo = [decoder decodeObjectForKey:@"autoFillStorageInfo"];
        }

        if([decoder containsValueForKey:@"quickTypeEnabled"]) {
            self.quickTypeEnabled = [decoder decodeBoolForKey:@"quickTypeEnabled"];
        }

        if([decoder containsValueForKey:@"autoFillEnabled"]) {
            self.autoFillEnabled = [decoder decodeBoolForKey:@"autoFillEnabled"];
        }
        
        if([decoder containsValueForKey:@"hasPromptedForAutoFillEnrol"]) {
            self.hasPromptedForAutoFillEnrol = [decoder decodeBoolForKey:@"hasPromptedForAutoFillEnrol"];
        }

        if([decoder containsValueForKey:@"quickWormholeFillEnabled"]) {
            self.quickWormholeFillEnabled = [decoder decodeBoolForKey:@"quickWormholeFillEnabled"];
        }
    }
    
    return self;
}

@end
