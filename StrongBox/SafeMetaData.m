//
//  SafeDetails.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeMetaData.h"

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
    }
    
    return self;
}

- (void)changeNickName:(NSString*)newNickName {
    _nickName = newNickName;
}


- (NSDictionary *)toDictionary {
    NSMutableDictionary *dictionary =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
         self.nickName,                                              @"nickName",
         [NSNumber numberWithInt:self.storageProvider],              @"storageProvider",
         @(self.isEnrolledForTouchId),        @"isEnrolledForTouchId",
         @(self.isTouchIdEnabled),            @"isTouchIdEnabled",
         @(self.offlineCacheEnabled),         @"offlineCacheEnabled",
         @(self.offlineCacheAvailable),       @"offlineCacheAvailable",
         nil];

    // Possibly Nil - Need to check - cannot be used in above initializer...

    if (self.fileName) {
        [dictionary setValue:self.fileName forKey:@"fileName"];
    }

    if (self.fileIdentifier) {
        [dictionary setValue:self.fileIdentifier forKey:@"fileIdentifier"];
    }

    if (self.offlineCacheFileIdentifier) {
        [dictionary setValue:self.offlineCacheFileIdentifier forKey:@"offlineCacheFileIdentifier"];
    }

    return dictionary;
}

+ (SafeMetaData *)fromDictionary:(NSDictionary *)dictionary {
    SafeMetaData *ret = [[SafeMetaData alloc] initWithNickName:dictionary[@"nickName"] storageProvider:-1 fileName:dictionary[@"fileName"] fileIdentifier:dictionary[@"fileIdentifier"]];

    NSNumber *sp = [dictionary valueForKey:@"storageProvider"];
    ret.storageProvider = sp ? sp.intValue : kGoogleDrive;

    NSNumber *isEnrolledForTouchId = [dictionary valueForKey:@"isEnrolledForTouchId"];
    ret.isEnrolledForTouchId = isEnrolledForTouchId ? isEnrolledForTouchId.boolValue : NO;

    NSNumber *isTouchIdEnabled = [dictionary valueForKey:@"isTouchIdEnabled"];
    ret.isTouchIdEnabled = isTouchIdEnabled ? isTouchIdEnabled.boolValue : YES;

    ret.offlineCacheFileIdentifier = dictionary[@"offlineCacheFileIdentifier"];
    ret.offlineCacheFileIdentifier = (ret.offlineCacheFileIdentifier == nil) ? @"" : ret.offlineCacheFileIdentifier;

    NSNumber *offlineCacheEnabled = [dictionary valueForKey:@"offlineCacheEnabled"];
    ret.offlineCacheEnabled = offlineCacheEnabled ? offlineCacheEnabled.boolValue : YES;

    NSNumber *offlineCacheAvailable = [dictionary valueForKey:@"offlineCacheAvailable"];
    ret.offlineCacheAvailable = offlineCacheAvailable ? offlineCacheAvailable.boolValue : NO;

    return ret;
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
    [encoder encodeObject:self.offlineCacheFileIdentifier forKey:@"offlineCacheFileIdentifier"];

    [encoder encodeBool:self.offlineCacheEnabled forKey:@"offlineCacheEnabled"];
    [encoder encodeBool:self.offlineCacheAvailable forKey:@"offlineCacheAvailable"];
    [encoder encodeBool:self.hasUnresolvedConflicts forKey:@"hasUnresolvedConflicts"];
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
        self.offlineCacheFileIdentifier = [decoder decodeObjectForKey:@"offlineCacheFileIdentifier"];
        
        self.offlineCacheEnabled = [decoder decodeBoolForKey:@"offlineCacheEnabled"];
        self.offlineCacheAvailable = [decoder decodeBoolForKey:@"offlineCacheAvailable"];
        self.hasUnresolvedConflicts = [decoder decodeBoolForKey:@"hasUnresolvedConflicts"];
    }
    
    return self;
}

@end
