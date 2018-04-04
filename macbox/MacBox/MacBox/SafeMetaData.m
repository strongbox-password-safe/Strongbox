//
//  SafeMetaData.m
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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
    }
    
    return self;
}

- (void)removeTouchIdPassword {
//    [JNKeychain deleteValueForKey:self.uuid];
}

- (NSString*)touchIdPassword {
//    return [JNKeychain loadValueForKey:self.uuid];
    return @"";
}

- (void)setTouchIdPassword:(NSString *)touchIdPassword {
//    [JNKeychain saveValue:touchIdPassword forKey:self.uuid];
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
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.uuid = [decoder decodeObjectForKey:@"uuid"];
        self.nickName = [decoder decodeObjectForKey:@"nickName"];
        self.fileName = [decoder decodeObjectForKey:@"fileName"];
        self.fileIdentifier = [decoder decodeObjectForKey:@"fileIdentifier"];
        self.storageProvider = (int)[decoder decodeIntegerForKey:@"storageProvider"];
        
        self.isTouchIdEnabled = [decoder decodeBoolForKey:@"isTouchIdEnabled"];
    }
    
    return self;
}

@end
