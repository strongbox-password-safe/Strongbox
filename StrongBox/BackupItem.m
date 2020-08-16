//
//  BackupItem.m
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BackupItem.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

@implementation BackupItem

+ (instancetype)withUrl:(NSURL *)url date:(NSDate *)date fileSize:(NSNumber *)fileSize {
    return [[BackupItem alloc] initWithUrl:url date:date fileSize:fileSize];
}

- (instancetype)initWithUrl:(NSURL *)url date:(NSDate *)date fileSize:(NSNumber *)fileSize {
    self = [super init];
    if (self) {
        _url = url;
        _date = date;
        _fileSize = fileSize;
    }
    return self;
}
    
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@-%@", self.date.friendlyDateString, friendlyFileSizeString(self.fileSize.unsignedIntValue)];
}

@end
