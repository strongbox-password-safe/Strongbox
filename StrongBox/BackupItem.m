//
//  BackupItem.m
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BackupItem.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

@implementation BackupItem

+ (instancetype)withUrl:(NSURL *)url backupCreatedDate:(NSDate *)backupCreatedDate modDate:(NSDate *)modDate fileSize:(NSNumber *)fileSize {
    return [[BackupItem alloc] initWithUrl:url backupCreatedDate:backupCreatedDate modDate:modDate fileSize:fileSize];
}

- (instancetype)initWithUrl:(NSURL *)url backupCreatedDate:(NSDate *)backupCreatedDate modDate:(NSDate *)modDate fileSize:(NSNumber *)fileSize {
    self = [super init];
    if (self) {
        _url = url;
        _backupCreatedDate = backupCreatedDate;
        _modDate = modDate;
        _fileSize = fileSize;
    }
    return self;
}
    
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@-%@", self.backupCreatedDate.friendlyDateTimeString, friendlyFileSizeString(self.fileSize.unsignedIntValue)];
}

@end
