//
//  OfflineCacheNameDetector.m
//  Strongbox-iOS
//
//  Created by Mark on 27/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OfflineCacheNameDetector.h"

@implementation OfflineCacheNameDetector

static NSString* const kOldOfflineCacheNameSuffix = @"-strongbox-offline-cache";

+ (BOOL)nickNameMatchesOldOfflineCache:(NSString*)nickName {
    if([nickName hasSuffix:kOldOfflineCacheNameSuffix] && nickName.length == 36 + 24) { // UUID + Suffix
        NSString* maybeUuid = [nickName substringToIndex:36];
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:maybeUuid];
        
        return uuid != nil;
    }
    
    return NO;
}

@end
